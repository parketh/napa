use traits::{Into, TryInto};
use array::ArrayTrait;
use serde::Serde;
use integer::u256_from_felt252;
use starknet::ContractAddress;
use starknet::ContractAddressIntoFelt252;
use poseidon::poseidon_hash_span;

// Compute pair id.
//   Poseidon(base_token, quote_token)
//
// # Arguments
// * `base_token` - address of the base token
// * `quote_token` - address of the quote token
//
// # Returns
// * `pair_id` - pair id
fn pair_id(
    base_token: ContractAddress,
    quote_token: ContractAddress,
) -> felt252 {
    let mut input = ArrayTrait::<felt252>::new();
    base_token.serialize(ref input);
    quote_token.serialize(ref input);
    poseidon_hash_span(input.span())
}

// Compute market id.
//   Poseidon(pair_id, is_call, expiry_block, price)
//
// # Arguments
// * `pair_id` - id of the pair
// * `is_call` - true if call option, false if put
// * `expiry_block` - block number at which option expires
// * `price` - strike price of the option
//
// # Returns
// * `market_id` - market id
fn market_id(
    pair_id: felt252,
    is_call: bool,
    expiry_block: felt252,
    price: felt252,
) -> felt252 {
    let mut input = ArrayTrait::<felt252>::new();
    pair_id.serialize(ref input);
    is_call.serialize(ref input);
    expiry_block.serialize(ref input);
    price.serialize(ref input);
    poseidon_hash_span(input.span())
}