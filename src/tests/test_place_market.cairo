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

    // Create limit orders.
    set_contract_address(alice());
    manager.place_limit(eth.contract_address, true, 86400, to_e6(1950), true, to_e6(20), 10, to_e6(250), 0, 0);
    manager.place_limit(eth.contract_address, true, 86400, to_e6(1950), true, to_e6(15), 5, to_e6(100), 0, to_e6(20));
    manager.place_limit(eth.contract_address, true, 86400, to_e6(1950), false, to_e6(24), 5, to_e6(150), to_e6(20), 0);
    manager.place_limit(eth.contract_address, true, 86400, to_e6(1950), false, to_e6(26), 10, to_e6(340), to_e6(24), 0);

    (usdc, eth, manager)
}

////////////////////////////////
// TESTS
////////////////////////////////

#[test]
#[available_gas(40000000)]
fn test_place_call_market_buy() {
    let (usdc, eth, manager) = before();

    // Place call market order.
    let user = bob();
    set_contract_address(user);

    // Should be fully filled.
    let (order_id, filled) = manager.place_market(eth.contract_address, true, 86400, to_e6(1950), true, 5);

    // Check order filled.
    let order = manager.get_order(order_id);
    assert(order.filled_contracts == 5, 'Market buy: filled contracts');
    assert(filled == 5, 'Market buy: not fully filled');

    // Check opposing order.
    let filled_order = manager.get_order(3);
    assert(filled_order.filled_contracts == 5, 'Market buy: opposing fill');

    // Check order
    let order = manager.get_order(order_id);
    assert(order.owner == bob(), 'Market buy: owner');
    assert(order.num_contracts == 5, 'Market buy: num ctrcs');
    assert(order.filled_contracts == 5, 'Market buy: filled ctrcs');
    assert(order.premium == to_e6(24), 'Market buy: premium');

    // Check market
    let market = manager.get_market(order.market_id);
    assert(market.bid_limit == to_e6(20), 'Market buy: mkt bid limit');
    assert(market.ask_limit == to_e6(26), 'Market buy: mkt ask limit');

    // Check orderbook limits
    let ask_limit = manager.get_limit(order.market_id, market.ask_limit);
    assert(ask_limit.prev_limit == 0, 'Market buy: prev limit');
    assert(ask_limit.next_limit == 0, 'Market buy: next limit');
    assert(ask_limit.num_contracts == 10, 'Market buy: num ctrcs');
    assert(ask_limit.head_order_id == 4, 'Market buy: head order id');
    assert(ask_limit.tail_order_id == 4, 'Market buy: tail order id');
}
