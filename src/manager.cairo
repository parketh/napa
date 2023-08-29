use core::zeroable::Zeroable;
#[starknet::contract]
mod Manager {

    use starknet::ContractAddress;
    use starknet::info::{get_block_timestamp, get_caller_address};

    use napa::interfaces::IManager::IManager;
    use napa::types::{Market, Pair, Order};

    ////////////////////////////////
    // STORAGE
    ////////////////////////////////

    #[storage]
    struct Storage {
        // Indexed by pair_id = hash(base_token, quote_token)
        pairs: LegacyMap::<(ContractAddress, ContractAddress), Pair>,
        // Indexed by (user: ContractAddress, asset: ContractAddress)
        balances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
        // Indexed by market_id = hash(pair_id, is_call, expiry, price)
        markets: LegacyMap::<felt252, Market>,
        // Indexed by (market_id, limit)
        limits: LegacyMap::<(felt252, u256), Limit>,
        // Indexed by order_id
        orders: LegacyMap::<felt252, Order>,

        next_order_id: felt252,
        next_fill_id: felt252,
    }

    ////////////////////////////////
    // EVENTS
    ////////////////////////////////

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RegisterPair: RegisterPair,
        ChangeWidths: ChangeWidths,
    }

    #[derive(Drop, starknet::Event)]
    struct RegisterPair {
        base_token: ContractAddress,
        quote_token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ChangeWidths {
        base_token: ContractAddress,
        quote_token: ContractAddress,
        strike_price_width: u256,
        expiry_width: u64,
        premium_width: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_order_id = 1;
    }

    #[external(v0)]
    impl Manager of IManager<ContractState> {

        ////////////////////////////////
        // VIEW
        ////////////////////////////////

        fn get_balance(self: @ContractState, user: ContractAddress, asset: ContractAddress) -> u256 {
            self.balances.read((user, asset))
        }

        fn get_market(self: @ContractState, market_id: felt252) -> Market {
            self.markets.read(market_id)
        }

        fn get_pair(self: @ContractState, base_token: ContractAddress, quote_token: ContractAddress) -> Pair {
            self.pairs.read((base_token, quote_token))
        }

        // fn get_oracle_price(self: @ContractState, oracle: ContractAddress) -> u256 {
        //     // TODO
        // }

        ////////////////////////////////
        // EXTERNAL
        ////////////////////////////////

        // Registers a new pair.
        // 
        // # Arguments
        //
        // * `base_token` - base token of the pair
        // * `quote_token` - quote token of the pair
        // * `width` - width of the pair
        fn register_pair(
            ref self: TContractState, 
            base_token: ContractAddress, 
            quote_token: ContractAddress, 
            strike_price_width: u256,
            expiry_width: u64,
            premium_width: u256,
        ) {
            self.pairs.write((base_token, quote_token), Pair { base_token, quote_token, width });
            self.emit(Event::RegisterPair(RegisterPair { base_token, quote_token }));
            self.emit(
                Event::ChangeWidths(
                    ChangeWidths { base_token, quote_token, strike_price_width, expiry_width, premium_width }
                )
            );
        }

        // Updates the width of a pair.
        //
        // # Arguments
        //
        // * `base_token` - base token of the pair
        // * `quote_token` - quote token of the pair
        // * `width` - new width of the pair
        fn update_pair(
            ref self: TContractState, 
            base_token: ContractAddress, 
            quote_token: ContractAddress, 
            strike_price_width: u256,
            expiry_width: u64,
            premium_width: u256,
        ) {
            self.pairs.write((base_token, quote_token), Pair { base_token, quote_token, width });
            self.emit(
                Event::ChangeWidths(
                    ChangeWidths { base_token, quote_token, strike_price_width, expiry_width, premium_width }
                )
            );
        }
        
        // Place a new order.
        // If option buyer and premium is below highest bid or option seller and premium 
        // is above lowest ask, place aslimit order. Otherwise, fill as market order.
        //
        // # Arguments
        // * `base_token` - base token of the pair
        // * `quote_token` - quote token of the pair
        // * `is_call` - true if call option, false if put option
        // * `expiry_block` - expiry block of the option
        // * `price` - strike price of the option
        // * `is_buy` - true if buy order, false if sell order
        // * `premium` - premium (or price) of the option
        // * `contracts` - order size in number of contracts
        //
        // # Returns
        // * `order_id` - id of the order
        fn place(
            ref self: TContractState, 
            base_token: ContractAddress,
            quote_token: ContractAddress,
            is_call: bool,
            expiry_block: u64,
            strike_price: u256,
            is_buy: bool,
            premium: u256,
            contracts: u256,
        ) -> felt252 {
            // Check pair is registered.
            let pair_id = id::pair_id(base_token, quote_token);
            let pair = self.pairs.read(pair_id);
            assert(pair.base_token.is_non_zero(), 'PairNotRegistered');

            // Validate inputs.
            assert(base_token.is_non_zero(), 'BaseTokenZero');
            assert(quote_token.is_non_zero(), 'QuoteTokenZero');
            assert(expiry_block > get_block_timestamp(), 'Expired');
            assert(expiry_block % pair.expiry_width == 0, 'ExpiryInvalid');
            assert(strike_price != 0 && strike_price % pair.strike_price_width == 0, 'StrikePriceInvalid');
            assert(premium > 0 && premium % premium_width == 0, 'PremiumInvalid');

            // Check if market exists. If it doesn't, create it.
            let order_id = self.next_order_id.read();
            let market_id = id::market_id(pair_id, is_call, expiry_block, price);
            let mut market = self.markets.read(market_id);
            let is_new = market.pair_id.is_zero();
            if is_new {
                market = Market {
                    pair_id,
                    is_call,
                    expiry_block,
                    strike_price,
                    bid_limit: order_id,
                    ask_limit: order_id,
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
                    amount,
                    premium,
                };
                self.orders.write(order_id, order);

                // TODO: insert order into order book of market.

            } else {
                let fill_id = self.next_fill_id.read();

                // TODO: write logic to fetch next eligible order from order book.
                let filled_order_id = 0; // replace with logic
                let mut filled_order = self.orders.read(filled_order_id);
                filled_order.fill_id = fill_id;

                // Fill order.
                let fill = Fill {
                    owner: get_caller_address(),
                    order_id: filled_order_id,
                }
                self.fills.write(fill_id, fill);
                self.next_fill_id.write(fill_id + 1);

                // TODO: anything else needed to fill order.
            }

            // Increment order id.
            self.next_order_id.write(order_id + 1);
        }   



    }

}