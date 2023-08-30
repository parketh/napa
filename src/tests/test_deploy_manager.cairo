use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing::set_contract_address;

use napa::manager::Manager;
use napa::interfaces::IManager::IManager;
use napa::interfaces::IManager::{IManagerDispatcher, IManagerDispatcherTrait};
use napa::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use napa::tests::helpers::{deploy_token, deploy_manager, owner, treasury, usdc_params};

use debug::PrintTrait;

////////////////////////////////
// SETUP
////////////////////////////////

fn before() -> IERC20Dispatcher {
    deploy_token(usdc_params())
}

////////////////////////////////
// TESTS
////////////////////////////////

#[test]
#[available_gas(40000000)]
fn test_deploy_manager_initialises_immutables() {
    let usdc = before();

    let manager = deploy_manager(usdc.contract_address);
    
    assert(manager.owner() == owner(), 'Deploy: wrong owner');
    assert(manager.usdc_address() == usdc.contract_address, 'Deploy: wrong usdc addr');
    assert(manager.next_order_id() == 1, 'Deploy: wrong order id');
}