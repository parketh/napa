use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing::{set_contract_address, set_block_timestamp};

use napa::manager::Manager;
use napa::libraries::id;
use napa::interfaces::IManager::IManager;
use napa::interfaces::IManager::{IManagerDispatcher, IManagerDispatcherTrait};
use napa::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use napa::tests::helpers::{
    deploy_token, 
    deploy_manager,
    fund,
    approve,
    owner, 
    alice,
    bob,
    usdc_params, 
    eth_params, 
    set_token_params,
    to_e6
};

use debug::PrintTrait;

////////////////////////////////
// SETUP
////////////////////////////////

fn before() -> (IERC20Dispatcher, IERC20Dispatcher, IManagerDispatcher) {
    // Deloy tokens
    let usdc = deploy_token(usdc_params());
    let eth = deploy_token(eth_params());

    // Deploy manager
    let manager = deploy_manager(usdc.contract_address);

    // Set ETH token params
    set_contract_address(owner());
    let mut params = set_token_params();
    manager.set_token_params(
        eth.contract_address,
        params.strike_price_width,
        params.expiry_width,
        params.premium_width,
        params.min_collateral_ratio,
    );

    // Fund users with usdc from treasury. Approve spend and deposit USD to contract.
    let mut amount = to_e6(1000);
    fund(usdc, alice(), amount);
    approve(usdc, alice(), manager.contract_address, amount);
    manager.deposit(amount);

    amount = to_e6(2000);
    fund(usdc, bob(), amount);
    approve(usdc, bob(), manager.contract_address, amount);
    manager.deposit(amount);

    // Initialise block state
    let now = 1;
    set_block_timestamp(now);
    let curr_price = to_e6(1850);
    manager.set_oracle_price(eth.contract_address, now, curr_price);
    manager.set_latest_oracle_price(eth.contract_address, curr_price);

    (usdc, eth, manager)
}

////////////////////////////////
// TESTS
////////////////////////////////

#[test]
#[available_gas(40000000)]
fn test_place_single_limit_buy_call() {
    let (usdc, eth, manager) = before();

    // Order params
    let token = eth.contract_address;
    let is_call = true;
    let expiry_date = 86400; // in 1 day
    let strike_price = to_e6(2000);
    let is_buy = true;
    let premium = to_e6(1);
    let num_contracts = 10;
    let margin = to_e6(20);
    let prev_limit = 0;
    let next_limit = 0;

    // Place limit order
    set_contract_address(alice());
    let order_id = manager.place_limit(
        token, is_call, expiry_date, strike_price, is_buy, premium, num_contracts, margin, prev_limit, next_limit,
    );

    // Check order
    let order = manager.get_order(order_id);
    assert(order.next_order_id == 0, 'Limit buy call: next order id');
    assert(order.owner == alice(), 'Limit buy call: owner');
    assert(order.market_id == id::market_id(token, is_call, expiry_date, strike_price), 'Limit buy call: market id');
    assert(order.is_buy == is_buy, 'Limit buy call: not buy');
    assert(order.premium == premium, 'Limit buy call: premium');
    assert(order.num_contracts == num_contracts, 'Limit buy call: num ctrcs');
    assert(order.filled_contracts == 0, 'Limit buy call: filled ctrcs');
    assert(order.margin == margin, 'Limit buy call: margin');
    assert(order.settled == false, 'Limit buy call: settled');

    // Check market
    let market = manager.get_market(order.market_id);
    assert(market.token == token, 'Limit buy call: mkt token');
    assert(market.is_call == is_call, 'Limit buy call: mkt is_call');
    assert(market.expiry_date == expiry_date, 'Limit buy call: mkt expiry');
    assert(market.strike_price == strike_price, 'Limit buy call: mkt strike');
    assert(market.bid_limit == premium, 'Limit buy call: mkt bid limit');
    assert(market.ask_limit == 0, 'Limit buy call: mkt ask limit');

    // Check limit
    let bid_limit = manager.get_limit(order.market_id, market.bid_limit);
    assert(bid_limit.prev_limit == 0, 'Limit buy call: prev limit');
    assert(bid_limit.next_limit == 0, 'Limit buy call: next limit');
    assert(bid_limit.num_contracts == num_contracts, 'Limit buy call: num ctrcs');
    assert(bid_limit.head_order_id == 1, 'Limit buy call: head order id');
    assert(bid_limit.tail_order_id == 1, 'Limit buy call: tail order id');

    // Check account
    let balance = manager.get_balance(alice());
    assert(balance == to_e6(1000 - 20), 'Limit buy call: acc balance');
}

#[test]
#[available_gas(40000000)]
fn test_place_single_limit_sell_call() {
    let (usdc, eth, manager) = before();

    // Order params
    let token = eth.contract_address;
    let is_call = true;
    let expiry_date = 86400; // in 1 day
    let strike_price = to_e6(1950);
    let is_buy = false;
    let premium = to_e6(20);
    let num_contracts = 5;
    let margin = to_e6(150);
    let prev_limit = 0;
    let next_limit = 0;

    // Place limit order
    set_contract_address(alice());
    let order_id = manager.place_limit(
        token, is_call, expiry_date, strike_price, is_buy, premium, num_contracts, margin, prev_limit, next_limit,
    );

    // Check order
    let order = manager.get_order(order_id);
    assert(order.next_order_id == 0, 'Limit sell call: next order id');
    assert(order.owner == alice(), 'Limit sell call: owner');
    assert(order.market_id == id::market_id(token, is_call, expiry_date, strike_price), 'Limit sell call: market id');
    assert(order.is_buy == is_buy, 'Limit sell call: not buy');
    assert(order.premium == premium, 'Limit sell call: premium');
    assert(order.num_contracts == num_contracts, 'Limit sell call: num ctrcs');
    assert(order.filled_contracts == 0, 'Limit sell call: filled ctrcs');
    assert(order.margin == margin, 'Limit sell call: margin');
    assert(order.settled == false, 'Limit sell call: settled');

    // Check market
    let market = manager.get_market(order.market_id);
    assert(market.token == token, 'Limit sell call: mkt token');
    assert(market.is_call == is_call, 'Limit sell call: mkt is_call');
    assert(market.expiry_date == expiry_date, 'Limit sell call: mkt expiry');
    assert(market.strike_price == strike_price, 'Limit sell call: mkt strike');
    assert(market.bid_limit == 0, 'Limit sell call: mkt bid limit');
    assert(market.ask_limit == premium, 'Limit sell call: mkt ask limit');

    // Check limit
    let ask_limit = manager.get_limit(order.market_id, market.ask_limit);
    assert(ask_limit.prev_limit == 0, 'Limit sell call: prev limit');
    assert(ask_limit.next_limit == 0, 'Limit sell call: next limit');
    assert(ask_limit.num_contracts == num_contracts, 'Limit sell call: num ctrcs');
    assert(ask_limit.head_order_id == 1, 'Limit sell call: head order id');
    assert(ask_limit.tail_order_id == 1, 'Limit sell call: tail order id');

    // Check account
    let balance = manager.get_balance(alice());
    assert(balance == to_e6(1000 - 150), 'Limit sell call: acc balance');
}

#[test]
#[available_gas(40000000)]
fn test_place_multiple_limit_calls() {
    let (usdc, eth, manager) = before();

    // Place first set of limit orders by Alice
    set_contract_address(alice());
    manager.place_limit(eth.contract_address, true, 86400, to_e6(1950), true, to_e6(20), 5, to_e6(150), 0, 0);
    manager.place_limit(eth.contract_address, true, 86400, to_e6(1950), true, to_e6(15), 5, to_e6(150), 0, to_e6(20));

    // Place second set of limit orders by Bob
    set_contract_address(bob());
    manager.place_limit(eth.contract_address, true, 86400, to_e6(1950), false, to_e6(24), 5, to_e6(150), 0, 0);
    // manager.place_limit(eth.contract_address, true, 86400, to_e6(1950), false, to_e6(24), 5, to_e6(150), 0, 0);

    // Check limit list.
    let market_id = id::market_id(eth.contract_address, true, 86400, to_e6(1950));
    let market = manager.get_market(market_id);
    let bid_limit = manager.get_limit(market_id, market.bid_limit);
    assert(market.bid_limit == to_e6(20), 'Limit list: bid limit');
    assert(bid_limit.prev_limit == to_e6(15), 'Limit list: bid prev limit');
    assert(bid_limit.next_limit == 0, 'Limit list: bid next limit');

    let ask_limit = manager.get_limit(market_id, market.ask_limit);
    assert(market.ask_limit == to_e6(24), 'Limit list: ask limit');
    assert(ask_limit.prev_limit == 0, 'Limit list: ask prev limit');
    assert(ask_limit.next_limit == 0, 'Limit list: ask next limit');

    // No time to test cancelling orders, let's leave it for now :)
}