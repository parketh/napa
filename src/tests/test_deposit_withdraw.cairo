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
    fund,
    approve,
    owner, 
    alice,
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

    (usdc, eth, manager)
}

////////////////////////////////
// TESTS
////////////////////////////////

#[test]
#[available_gas(40000000)]
fn test_deposit_withdraw() {
    let (usdc, eth, manager) = before();

    // Fund user with usdc from treasury
    let user = alice();
    let deposit_amount = to_e6(1000);
    fund(usdc, user, deposit_amount);

    // Approve spend
    approve(usdc, user, manager.contract_address, deposit_amount);

    // Deposit and run checks
    manager.deposit(deposit_amount);
    let balance = manager.get_balance(user);
    assert(balance == deposit_amount, 'Deposit: wrong user balance');
    assert(usdc.balance_of(manager.contract_address) == deposit_amount, 'Deposit: wrong contract bal');
    assert(usdc.balance_of(user) == 0, 'Deposit: wrong user erc20 bal');

    // Withdraw and run checks
    let withdraw_amount = to_e6(500);
    manager.withdraw(withdraw_amount);
    assert(manager.get_balance(user) == deposit_amount - withdraw_amount, 'Withdraw: wrong user balance');
    assert(usdc.balance_of(manager.contract_address) == deposit_amount - withdraw_amount, 'Withdraw: wrong contract bal');
    assert(usdc.balance_of(user) == withdraw_amount, 'Withdraw: wrong user erc20 bal');
}