use cmp::max;
use napa::types::i256::{i256, I256Trait, I256Zeroable};

fn calc_profit_and_loss(
    is_call: bool,
    is_buy: bool,
    mark_price: u256,
    strike_price: u256,
    premium: u256,
    num_contracts: u32,
) -> i256 {
    let mark_price: i256 = I256Trait::new(mark_price, false);
    let strike_price: i256 = I256Trait::new(strike_price, false);
    let zero: i256 = I256Zeroable::zero();
    let premium: i256 = I256Trait::new(premium, false);
    let num_contracts: i256 = I256Trait::new(num_contracts.into(), false);

    if is_call && is_buy {
        (max(mark_price - strike_price, zero) - premium) * num_contracts
    } 
    else if is_call && !is_buy {
        (premium - max(mark_price - strike_price, zero)) * num_contracts
    } 
    else if !is_call && is_buy {
        (max(strike_price - mark_price, zero) - premium) * num_contracts
    } 
    else {
        (premium - max(strike_price - mark_price, zero)) * num_contracts
    }
}