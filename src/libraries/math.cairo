use integer::{u256_wide_mul, u512_safe_div_rem_by_u256, u256_try_as_non_zero};
use integer::BoundedU256;

const ONE: u256 = 10000000000000000000000000000;

// Multiplies two u256 numbers and divides the result by a third. Optionally rounds up to the nearest integer.
//
// # Arguments
// * `a` - first multiplicand
// * `b` - second multiplicand
// * `c` - divisor
//
// # Returns
// * `result` - result
fn mul_div(a: u256, b: u256, c: u256, round_up: bool) -> u256 {
    let product = u256_wide_mul(a, b);
    let (q, r) = u512_safe_div_rem_by_u256(
        product, 
        u256_try_as_non_zero(c).expect('MulDivByZero')
    );
    if round_up && r > 0 {
        let result = u256 { low: q.limb0, high: q.limb1 };
        assert(result != BoundedU256::max() && q.limb2 == 0 && q.limb3 == 0, 'MulDivOverflow');
        u256 { low: q.limb0, high: q.limb1 } + 1
    } else {
        assert(q.limb2 == 0 && q.limb3 == 0, 'MulDivOverflow');
        u256 { low: q.limb0, high: q.limb1 }
    }
}