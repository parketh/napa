use core::zeroable::Zeroable;
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

    // fn get_oracle_price(self: @TContractState, oracle: ContractAddress) -> u256;

    ////////////////////////////////
    // EXTERNAL
    ////////////////////////////////

    fn register_pair(
        ref self: TContractState, 
        base_token: ContractAddress, 
        quote_token: ContractAddress, 
        strike_price_width: u256,
        expiry_width: u64,
        premium_width: u256,
    );

    fn update_pair(
        ref self: TContractState, 
        base_token: ContractAddress, 
        quote_token: ContractAddress, 
        strike_price_width: u256,
        expiry_width: u64,
        premium_width: u256
    );

    fn place(
        ref self: TContractState, 
        base_token: ContractAddress,
        quote_token: ContractAddress,
        is_call: bool,
        expiry_block: u64,
        strike_price: u256,
        is_buy: bool,
        premium: u256,
        amount: u256,
    ) -> (felt252, bool);

    // fn cancel(ref self: TContractState, order_id: felt252);

    // fn fill(ref self: TContractState, );

    // fn deposit(ref self: TContractState, );

    // fn withdraw(ref self: TContractState, );

    // fn update(ref self: TContractState, );

    // fn liquidate(ref self: TContractState, );

    // TEMP

    // fn update_oracle_price(ref self: TContractState, );


}