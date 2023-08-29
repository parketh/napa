use traits::{Into, TryInto};
use array::ArrayTrait;
use serde::Serde;
use integer::u256_from_felt252;
use starknet::ContractAddress;
use starknet::ContractAddressIntoFelt252;
use poseidon::poseidon_hash_span;

// Compute market id.
//   Poseidon(token, is_call, expiry_block, price)
//
// # Arguments
// * `token` - id of the pair
// * `is_call` - true if call option, false if put
// * `expiry_block` - block number at which option expires
// * `price` - strike price of the option
//
// # Returns
// * `market_id` - market id
fn market_id(
    token: ContractAddress,
    is_call: bool,
    expiry_block: u64,
    price: u256,
) -> felt252 {
    let mut input = ArrayTrait::<felt252>::new();
    token.serialize(ref input);
    is_call.serialize(ref input);
    expiry_block.serialize(ref input);
    price.serialize(ref input);
    poseidon_hash_span(input.span())
}