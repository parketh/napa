use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing::set_contract_address;

use napa::manager::Manager;
use napa::interfaces::IManager::IManager;
use napa::interfaces::IManager::{IManagerDispatcher, IManagerDispatcherTrait};
use napa::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use napa::tests::helpers::{
    deploy_token, 
    deploy_manager, 
    owner, 
    usdc_params, 
    eth_params, 
    set_token_params,
    to_e6,
};

use debug::PrintTrait;

////////////////////////////////
// SETUP
////////////////////////////////

fn before() -> (IERC20Dispatcher, IERC20Dispatcher, IManagerDispatcher) {
    let usdc = deploy_token(usdc_params());
    let eth = deploy_token(eth_params());
    let manager = deploy_manager(usdc.contract_address);

    (usdc, eth, manager)
}

////////////////////////////////
// TESTS
////////////////////////////////

#[test]
#[available_gas(40000000)]
fn test_set_token_params() {
    let (usdc, eth, manager) = before();
    
    set_contract_address(owner());

    // Set token params
    let mut params = set_token_params();
    manager.set_token_params(
        eth.contract_address,
        params.strike_price_width,
        params.expiry_width,
        params.premium_width,
        params.min_collateral_ratio,
    );

    let mut token_info = manager.get_token_info(eth.contract_address);
    assert(token_info.strike_price_width == params.strike_price_width, 'Set token: wrong strike width');
    assert(token_info.expiry_width == params.expiry_width, 'Set token: wrong expiry width');
    assert(token_info.premium_width == params.premium_width, 'Set token: wrong premium width');
    assert(token_info.min_collateral_ratio == params.min_collateral_ratio, 'Set token: wrong min coll ratio');

    // Change token arams.
    params.strike_price_width = to_e6(100);
    params.expiry_width = 1;
    manager.set_token_params(
        eth.contract_address,
        params.strike_price_width,
        params.expiry_width,
        params.premium_width,
        params.min_collateral_ratio,
    );

    token_info = manager.get_token_info(eth.contract_address);
    assert(token_info.strike_price_width == params.strike_price_width, 'Set token 2: wrong strike width');
    assert(token_info.expiry_width == params.expiry_width, 'Set token 2: wrong expiry width');
    assert(token_info.premium_width == params.premium_width, 'Set token 2: wrong prem width');
    assert(token_info.min_collateral_ratio == params.min_collateral_ratio, 'Set token 2: wrong coll ratio');
}