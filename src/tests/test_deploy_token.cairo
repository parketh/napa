use napa::tests::helpers::{deploy_token, treasury, usdc_params};
use napa::interfaces::IERC20::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};

////////////////////////////////
// TESTS
////////////////////////////////

#[test]
#[available_gas(40000000)]
fn test_deploy_token_initialises_immutables() {
    // Deploy token.
    let params = usdc_params();
    let token = deploy_token(params);
    
    // Check immutables.
    assert(token.name() == params.name, 'Deploy token: Wrong name');
    assert(token.symbol() == params.symbol, 'Deploy token: Wrong symbol');
    assert(token.decimals() == params.decimals, 'Deploy token: Wrong decimals');
    assert(token.total_supply() == params.initial_supply, 'Deploy token: Wrong init supply');
    assert(token.balance_of(params.recipient) == params.initial_supply, 'Deploy token: Wrong recipient');
}
