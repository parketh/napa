use core::zeroable::Zeroable;
#[starknet::contract]
mod Manager {

    use starknet::ContractAddress;
    use starknet::info::{get_block_timestamp, get_caller_address, get_contract_address};
    use cmp::max;

    use napa::libraries::id;
    use napa::libraries::math::{ONE, mul_div};
    use napa::interfaces::IManager::IManager;
    use napa::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use napa::types::core::{Market, TokenInfo, Order, Limit, Account};
    use napa::types::i256::{i256, I256Trait, I256Zeroable};

    ////////////////////////////////
    // STORAGE
    ////////////////////////////////

    #[storage]
    struct Storage {
        // IMMUTABLE
        usdc_address: ContractAddress, // currently only supports 1 collateral type

        // MUTABLE
        // Indexed by token address
        token_info: LegacyMap::<ContractAddress, TokenInfo>,
        // Indexed by user
        accounts: LegacyMap::<ContractAddress, Account>,
        // Indexed by market_id = hash(pair_id, is_call, expiry, price)
        markets: LegacyMap::<felt252, Market>,
        // Indexed by (market_id, limit)
        limits: LegacyMap::<(felt252, u256), Limit>,
        // Indexed by order_id
        orders: LegacyMap::<felt252, Order>,

        next_order_id: felt252,
        liquidation_fund: u256,

        // TEMP
        // Indexed by (token, timestamp)
        oracle_price: LegacyMap::<(ContractAddress, u64), u256>,
    }

    ////////////////////////////////
    // EVENTS
    ////////////////////////////////

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SetToken: SetToken,
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    #[derive(Drop, starknet::Event)]
    struct SetToken {
        token: ContractAddress,
        strike_price_width: u256,
        expiry_width: u64,
        premium_width: u256,
        liquidation_discount: u16,
        min_collateral_ratio: u16,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        user: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, usdc_address: ContractAddress) {
        self.next_order_id.write(1);
        self.usdc_address.write(usdc_address);
    }

    #[external(v0)]
    impl Manager of IManager<ContractState> {

        ////////////////////////////////
        // VIEW
        ////////////////////////////////

        fn get_market(self: @ContractState, market_id: felt252) -> Market {
            self.markets.read(market_id)
        }

        fn get_token_info(self: @ContractState, token: ContractAddress) -> TokenInfo {
            self.token_info.read(token)
        }

        fn get_oracle_price(self: @ContractState, token: ContractAddress, timestamp: u64) -> u256 {
            self.oracle_price.read((token, timestamp))
        }

        ////////////////////////////////
        // EXTERNAL
        ////////////////////////////////

        // Register a new token or update parameters of an existing one.
        // 
        // # Arguments
        //
        // * `token` - token
        // * `strike_price_width` - width of the pair
        // * `expiry_width` - width of the pair
        // * `premium_width` - width of the pair
        fn set_token(
            ref self: ContractState, 
            token: ContractAddress, 
            strike_price_width: u256,
            expiry_width: u64,
            premium_width: u256,
            liquidation_discount: u16,
            min_collateral_ratio: u16,
        ) {
            // Validate inputs.
            assert(strike_price_width > 0, 'StrikePriceWidthZero');
            assert(expiry_width > 0, 'ExpiryWidthZero');
            assert(premium_width > 0, 'PremiumWidthZero');
            assert(liquidation_discount < 1000, 'LiqDiscountOverflow');
            assert(min_collateral_ratio >= 1000, 'MinColRatioUnderflow');
            
            self.token_info.write(token, TokenInfo { 
                token, strike_price_width, expiry_width, premium_width, liquidation_discount, min_collateral_ratio
            });
            self.emit(Event::SetToken(
                SetToken { token, strike_price_width, expiry_width, premium_width, liquidation_discount, min_collateral_ratio }
            ));
        }

        // Deposits funds into the contract.
        //
        // # Arguments
        // * `amount` - amount to deposit
        fn deposit(ref self: ContractState, amount: u256) {
            assert(amount > 0, 'DepositAmountZero');

            let usdc_address = self.usdc_address.read();
            let caller = get_caller_address();

            IERC20Dispatcher{ contract_address: usdc_address }.transfer_from(caller, get_contract_address(), amount);

            let mut account = self.accounts.read(caller);
            account.balance += amount;
            self.accounts.write(caller, account);

            self.emit(Event::Deposit(Deposit { user: caller, amount }));
        }

        // Withdraws funds from the contract.
        //
        // # Arguments
        // * `amount` - amount to withdraw
        fn withdraw(ref self: ContractState, amount: u256) {
            assert(amount > 0, 'WithdrawAmountZero');

            let usdc_address = self.usdc_address.read();
            let caller = get_caller_address();

            let mut account = self.accounts.read(caller);
            assert(account.balance >= amount, 'InsufficientBalance');
            account.balance -= amount;
            self.accounts.write(caller, account);

            IERC20Dispatcher{ contract_address: usdc_address }.transfer(caller, amount);

            self.emit(Event::Withdraw(Withdraw { user: caller, amount }));
        }

        // Place a new order.
        // If option buyer and premium is below highest bid or option seller and premium 
        // is above lowest ask, place aslimit order. Otherwise, fill as market order.
        //
        // # Arguments
        // * `token` - underlying token
        // * `is_call` - true if call option, false if put option
        // * `expiry_block` - expiry block of the option
        // * `price` - strike price of the option
        // * `is_buy` - true if buy order, false if sell order
        // * `premium` - premium (or price) of the option
        // * `num_contracts` - order size in number of contracts
        //
        // # Returns
        // * `order_id` / `fill_id` - id of the order or fill
        // * `is_limit` - true if order is limit, false if it fills an existing order
        fn place(
            ref self: ContractState, 
            token: ContractAddress,
            is_call: bool,
            expiry_block: u64,
            strike_price: u256,
            is_buy: bool,
            premium: u256,
            num_contracts: u32,
        ) -> (felt252, bool) {
            // Check pair is registered.
            assert(token.is_non_zero(), 'TokenZero');
            let token_info = self.token_info.read(token);
            assert(token_info.token.is_non_zero(), 'TokenNotRegistered');

            // Validate inputs.
            assert(expiry_block > get_block_timestamp(), 'Expired');
            assert(expiry_block % token_info.expiry_width == 0, 'ExpiryInvalid');
            assert(strike_price != 0 && strike_price % token_info.strike_price_width == 0, 'StrikePriceInvalid');
            assert(premium > 0 && premium % token_info.premium_width == 0, 'PremiumInvalid');

            // Check if market exists. If it doesn't, create it.
            let order_id = self.next_order_id.read();
            let market_id = id::market_id(token, is_call, expiry_block, strike_price);
            let mut market = self.markets.read(market_id);
            let is_new = market.token.is_zero();
            if is_new {
                market = Market {
                    token,
                    is_call,
                    expiry_block,
                    strike_price,
                    bid_limit: premium,
                    ask_limit: premium,
                };
                self.markets.write(market_id, market);
            }

            // Check if order is limit or market.
            let is_limit_order = is_new || (
                is_buy && premium < market.ask_limit || !is_buy && premium > market.bid_limit
            );
            if is_limit_order {
                // Create order.
                let order = Order {
                    owner: get_caller_address(),
                    market_id,
                    is_buy,
                    premium,
                    num_contracts,
                    filled_contracts: 0,
                    margin: num_contracts.into() * premium,
                };
                self.orders.write(order_id, order);

                // TODO: insert order into order book of market.

                // TODO: update user account.
            } else {
                // TODO: write logic to fetch next eligible order from order book and update it.

                // TODO: Fill order.

                // TODO: update user account.
            }

            // Increment order id.
            self.next_order_id.write(order_id + 1);

            // Return order id.
            (order_id, is_limit_order)
        }

        // Updates account profit and loss based on latest mark price.
        // 
        // # Arguments
        // * `user` - user to update
        // 
        // # Returns
        // * `profit_loss` - updated profit and loss of the user
        fn update(ref self: ContractState, user: ContractAddress) -> i256 {
            let mut account = self.accounts.read(user);
            assert(account.order_id != 0, 'NoActiveOrder');
            let order = self.orders.read(account.order_id);
            let market = self.markets.read(order.market_id);
            let mark_price = self.oracle_price.read((market.token, get_block_timestamp()));

            // If mark price hasn't changed, return existing profit and loss.
            if account.last_mark_price == mark_price {
                return account.profit_loss;
            }

            // Otherwise, update profit and loss.
            let mark_price: i256 = I256Trait::new(mark_price, false);
            let strike_price: i256 = I256Trait::new(market.strike_price, false);
            let zero: i256 = I256Zeroable::zero();
            let premium: i256 = I256Trait::new(order.premium, false);
            let num_contracts: i256 = I256Trait::new(order.num_contracts.into(), false);

            let profit_loss = if market.is_call && order.is_buy {
                (max(mark_price - strike_price, zero) - premium) * num_contracts
            } 
            else if market.is_call && !order.is_buy {
                (premium - max(mark_price - strike_price, zero)) * num_contracts
            } 
            else if !market.is_call && order.is_buy {
                (max(strike_price - mark_price, zero) - premium) * num_contracts
            } 
            else {
                (premium - max(strike_price - mark_price, zero)) * num_contracts
            };

            account.profit_loss = profit_loss;
            self.accounts.write(user, account);

            profit_loss
        }

        // Settles an expired option position.
        fn settle(ref self: ContractState, order_id: felt252) {

        }

        // Liquidates an account. 
        // Transfers ownership of position to liquidator at a discount if liquidation condition is met.
        fn liquidate(ref self: ContractState, user: ContractAddress, num_contracts: u32) {
            // Update position profit and loss.
            self.update(user);

            // Check liquidation condition. 
            let account = self.accounts.read(user);
            let order = self.orders.read(account.order_id);
            let market = self.markets.read(order.market_id);
            let token_info = self.token_info.read(market.token);
            let is_liquiditable = account.profit_loss.sign && account.balance + order.margin < mul_div(
                account.profit_loss.val, token_info.min_collateral_ratio.into(), 1000, false
            );
            let is_insolvent = account.profit_loss.sign && account.balance + order.margin < account.profit_loss.val;

            // If liquidation condition is below threshold, transfer position to liquidator at discount.
            // If position is still above water, half of discount is transferred to liquidation fund. 

        }


        ////////////////////////////////
        // TEMP
        ////////////////////////////////

        // Updates oracle price.
        // TODO: Remove this once we have a real oracle.
        //
        // # Arguments
        // * `token` - token
        // * `price` - price
        fn update_oracle_price(ref self: ContractState, token: ContractAddress, price: u256) {
            self.oracle_price.write(token, price);
        }

    }

}