use core::zeroable::Zeroable;
#[starknet::contract]
mod Manager {

    use starknet::ContractAddress;
    use starknet::info::{get_block_timestamp, get_caller_address, get_contract_address};

    use napa::libraries::id;
    use napa::interfaces::IManager::IManager;
    use napa::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use napa::types::core::{Market, TokenInfo, Order, Limit, Account};

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

        // fn get_oracle_price(self: @ContractState, oracle: ContractAddress) -> u256 {
        //     // TODO
        // }

        ////////////////////////////////
        // EXTERNAL
        ////////////////////////////////

        // Registers a new token or updates its parameters.
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
        ) {
            self.token_info.write(token, TokenInfo { token, strike_price_width, expiry_width, premium_width });
            self.emit(Event::SetToken(SetToken { token, strike_price_width, expiry_width, premium_width }));
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

        // Updates account profit and loss.
        fn update(ref self: ContractState, order_id: felt252) {
            // TODO
        }

    }

}