use core::zeroable::Zeroable;
use starknet::ContractAddress;
use napa::types::core::{Market, TokenInfo, Order};

#[starknet::interface]
trait IManager<TContractState> {

    ////////////////////////////////
    // VIEW
    ////////////////////////////////

    fn get_market(self: @TContractState, market_id: felt252) -> Market;

    fn get_token_info(self: @TContractState, token: ContractAddress) -> TokenInfo;

    // fn get_oracle_price(self: @TContractState, oracle: ContractAddress) -> u256;

    ////////////////////////////////
    // EXTERNAL
    ////////////////////////////////

    fn set_token(
        ref self: TContractState, 
        token: ContractAddress, 
        strike_price_width: u256,
        expiry_width: u64,
        premium_width: u256,
    );

    fn deposit(ref self: TContractState, amount: u256);

    fn withdraw(ref self: TContractState, amount: u256);

    fn place(
        ref self: TContractState, 
        token: ContractAddress,
        is_call: bool,
        expiry_block: u64,
        strike_price: u256,
        is_buy: bool,
        premium: u256,
        num_contracts: u32,
    ) -> (felt252, bool);

    // fn cancel(ref self: TContractState, order_id: felt252);

    // fn deposit(ref self: TContractState, );

    // fn withdraw(ref self: TContractState, );

    fn update(ref self: TContractState, order_id: felt252);

    // fn collect(ref self: TContractState, );

    // fn liquidate(ref self: TContractState, );


    // TEMP

    // fn update_oracle_price(ref self: TContractState, );


}