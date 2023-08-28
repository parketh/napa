use starknet::ContractAddress;
use napa::types::{Market, Pair, Order};

#[starknet::interface]
trait IManager<TContractState> {

    ////////////////////////////////
    // VIEW
    ////////////////////////////////

    fn get_balance(self: @TContractState, user: ContractAddress, asset: ContractAddress) -> u256;

    fn get_market(self: @TContractState, market_id: felt252) -> Market;

    fn get_pair(self: @TContractState, base_token: ContractAddress, quote_token: ContractAddress) -> Pair;

    fn get_oracle_price(self: @TContractState, oracle: ContractAddress) -> u256;

    ////////////////////////////////
    // EXTERNAL
    ////////////////////////////////

    fn place(ref self: TContractState, );

    fn cancel(ref self: TContractState, );

    fn fill(ref self: TContractState, );

    fn deposit(ref self: TContractState, );

    fn withdraw(ref self: TContractState, );

    fn update(ref self: TContractState, );

    fn liquidate(ref self: TContractState, );

    // TEMP

    fn update_oracle_price(ref self: TContractState, )


}

#[starknet::contract]
mod Manager {

    use starknet::ContractAddress;

    use super::IManager;
    use napa::types::{Market, Pair, Order};

    ////////////////////////////////
    // STORAGE
    ////////////////////////////////

    #[storage]
    struct Storage {
        // Indexed by (user: ContractAddress, asset: ContractAddress)
        balances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
        // Indexed by market_id = hash(pair_id, is_call, expiry, strike_price)
        markets: LegacyMap::<felt252, Market>,
        // Indexed by pair_id = hash(base_token, quote_token)
        pairs: LegacyMap::<(ContractAddress, ContractAddress), Pair>,
        // Indexed by (market_id, limit)
        limits: LegacyMap::<(felt252, u256), Limit>,
        // Indexed by order_id
        orders: LegacyMap::<felt252, Order>,
    }

    #[external(v0)]
    impl Manager of IManager<ContractState> {

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
    }

}