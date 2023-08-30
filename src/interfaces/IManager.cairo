use core::zeroable::Zeroable;
use starknet::ContractAddress;
use napa::types::core::{Market, TokenInfo, Order};
use napa::types::i256::i256;

#[starknet::interface]
trait IManager<TContractState> {

    ////////////////////////////////
    // VIEW
    ////////////////////////////////

    fn get_market(self: @TContractState, market_id: felt252) -> Market;

    fn get_token_info(self: @TContractState, token: ContractAddress) -> TokenInfo;

    fn get_oracle_price(self: @TContractState, token: ContractAddress, timestamp: u64) -> u256;

    ////////////////////////////////
    // EXTERNAL
    ////////////////////////////////

    fn set_token(
        ref self: TContractState, 
        token: ContractAddress, 
        strike_price_width: u256,
        expiry_width: u64,
        premium_width: u256,
        min_collateral_ratio: u16,
        init_collateral_ratio: u16,
    );

    fn deposit(ref self: TContractState, amount: u256);

    fn withdraw(ref self: TContractState, amount: u256);

    fn place_limit(
        ref self: TContractState, 
        token: ContractAddress,
        is_call: bool,
        expiry_date: u64,
        strike_price: u256,
        is_buy: bool,
        premium: u256,
        num_contracts: u32,
        margin: u256,
        prev_limit: u256,
        next_limit: u256,
    ) -> felt252;

    fn place_market(
        ref self: TContractState, 
        token: ContractAddress,
        is_call: bool,
        expiry_date: u64,
        strike_price: u256,
        is_buy: bool,
        num_contracts: u32,
    ) -> (felt252, u32);

    // fn cancel_limit(ref self: TContractState, order_id: felt252);

    fn update(ref self: TContractState, user: ContractAddress) -> i256;

    fn settle(ref self: TContractState, user: ContractAddress);

    fn liquidate(ref self: TContractState, user: ContractAddress) -> bool;

    fn transfer_owner(ref self: TContractState, new_owner: ContractAddress);


    ////////////////////////////////
    // TEMP
    ////////////////////////////////

    fn update_oracle_price(ref self: TContractState, token: ContractAddress, timestamp: u64, price: u256);


}