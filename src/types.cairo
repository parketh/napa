use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Pair {
    base_token: ContractAddress,
    quote_token: ContractAddress,
    // oracle: ContractAddress,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Market {
    pair_id: felt252,
    is_call: bool,
    expiry: u64,
    strike_price: u256,
    width: u256,
    bid_tick: u256,
    ask_tick: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Limit {
    higher_tick: u256,
    lower_tick: u256,
    amount: u256,
    head_order_id: felt252,
    tail_order_id: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Order {
    market_id: felt252,
    owner: ContractAddress,
    is_bid: bool,
    amount: u256,
    premium: u256,
    fill_id: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Fill {
    order_id: felt252,
    owner: ContractAddress,
}

