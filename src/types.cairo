use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Pair {
    base_token: ContractAddress,
    quote_token: ContractAddress,
    strike_price_width: u256,
    expiry_width: u64,
    premium_width: u256,
    // oracle: ContractAddress,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Market {
    pair_id: felt252,
    is_call: bool,
    expiry_block: u64,
    strike_price: u256,
    bid_limit: u256,
    ask_limit: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Limit {
    prev_limit: u256,
    next_limit: u256,
    amount: u256,
    head_order_id: felt252,
    tail_order_id: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Order {
    owner: ContractAddress,
    market_id: felt252,
    is_buy: bool,
    amount: u256,
    premium: u256,
    fill_id: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Fill {
    owner: ContractAddress,
    order_id: felt252,
}
