use core::traits::AddEq;
use core::serde::Serde;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::deploy_syscall;
use starknet::testing::{set_contract_address, set_block_timestamp};
use core::starknet::SyscallResultTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use array::ArrayTrait;

use napa::manager::Manager;
use napa::interfaces::IERC20::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use napa::interfaces::IManager::{IManagerDispatcher, IManagerDispatcherTrait};
use napa::tests::mocks::mock_erc20::ERC20;

use debug::PrintTrait;

////////////////////////////////
// TYPES
////////////////////////////////

#[derive(Drop, Copy)]
struct ERC20Params {
    name: felt252,
    symbol: felt252,
    decimals: u8,
    initial_supply: u256,
    recipient: ContractAddress
}

#[derive(Drop, Copy)]
struct SetTokenParams {
    strike_price_width: u256,
    expiry_width: u64,
    premium_width: u256,
    min_collateral_ratio: u16,
}

////////////////////////////////
// CONSTANTS
////////////////////////////////

fn owner() -> ContractAddress {
    contract_address_const::<0x333333>()
}

fn treasury() -> ContractAddress {
    contract_address_const::<0x123456>()
}

fn alice() -> ContractAddress {
    contract_address_const::<0xaaaaaa>()
}

fn bob() -> ContractAddress {
    contract_address_const::<0xbbbbbb>()
}

fn usdc_params() -> ERC20Params {
    ERC20Params {
        name: 'USDC',
        symbol: 'USDC',
        decimals: 6,
        initial_supply: to_e6(1000000000), // 1B
        recipient: treasury()
    }
}

fn eth_params() -> ERC20Params {
    ERC20Params { 
        name: 'Ethereum',
        symbol: 'ETH',
        decimals: 18,
        initial_supply: to_e18(1000000), // 1M tokens
        recipient: treasury(),
    }
}

fn set_token_params() -> SetTokenParams {
    SetTokenParams {
        // token: not included as it should be the deployed erc20 addr 
        strike_price_width: to_e6(50),
        expiry_width: 86400, // 1 day in seconds
        premium_width: to_e6(1),
        min_collateral_ratio: 1200, // 120%
    }
}

////////////////////////////////
// HELPERS
////////////////////////////////

fn deploy_token(params: ERC20Params) -> IERC20Dispatcher {
    let mut constructor_calldata = ArrayTrait::<felt252>::new();
    params.name.serialize(ref constructor_calldata);
    params.symbol.serialize(ref constructor_calldata);
    params.decimals.serialize(ref constructor_calldata);
    params.initial_supply.serialize(ref constructor_calldata);
    params.recipient.serialize(ref constructor_calldata);

    let (deployed_address, _) = deploy_syscall(
        ERC20::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        constructor_calldata.span(),
        false
    ).unwrap();

    IERC20Dispatcher{ contract_address: deployed_address }
}

fn fund(
    token: IERC20Dispatcher, 
    user: ContractAddress, 
    amount: u256
) {
    set_contract_address(treasury());
    token.transfer(user, amount);
}


fn approve(
    token: IERC20Dispatcher,
    owner: ContractAddress, 
    spender: ContractAddress, 
    amount: u256
) {
    set_contract_address(owner);
    token.approve(spender, amount);
}

fn deploy_manager(
    usdc_addr: ContractAddress,
) -> IManagerDispatcher {
    set_contract_address(owner());

    let mut constructor_calldata = ArrayTrait::<felt252>::new();
    usdc_addr.serialize(ref constructor_calldata);
    let (deployed_address, _) = deploy_syscall(
        Manager::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        constructor_calldata.span(),
        false
    ).unwrap();

    IManagerDispatcher{ contract_address: deployed_address }
}

fn to_e6(amount: u256) -> u256 {
    amount * 1000000
}

fn to_e18(amount: u256) -> u256 {
    amount * 1000000000000000000
}