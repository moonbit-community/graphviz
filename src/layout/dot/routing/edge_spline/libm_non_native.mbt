///|
pub fn libm_cbrt(x : Double) -> Double {
  @math.cbrt(x)
}

///|
pub fn libm_atan2(y : Double, x : Double) -> Double {
  @math.atan2(y, x)
}

///|
pub fn libm_hypot(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}

///|
pub const LIBM_IS_NATIVE : Bool = false

///|
pub fn libm_sqrt(x : Double) -> Double {
  Double::sqrt(x)
}

///|
pub fn libm_cos(x : Double) -> Double {
  @math.cos(x)
}

///|
pub fn libm_sin(x : Double) -> Double {
  @math.sin(x)
}

///|
priv struct FmaTerm {
  sign : Int
  exp : Int
  sig : UInt64
  special : Bool
}

///|
fn fma_term(x : Double) -> FmaTerm {
  let bits = Double::reinterpret_as_uint64(x)
  let sign = if bits >> 63 == 1 { -1 } else { 1 }
  let exp_bits = (bits >> 52) & 0x7ff
  let frac = bits & 0x000f_ffff_ffff_ffff
  if exp_bits == 0x7ff {
    { sign, exp: 0, sig: 0, special: true }
  } else if exp_bits == 0 {
    if frac == 0 {
      { sign, exp: -1074, sig: 0, special: false }
    } else {
      { sign, exp: -1074, sig: frac, special: false }
    }
  } else {
    let implicit : UInt64 = 1
    let exp = exp_bits.to_int() - 1023 - 52
    let sig = frac | (implicit << 52)
    { sign, exp, sig, special: false }
  }
}

///|
fn bigint_pow2(shift : Int) -> @bigint.BigInt {
  @bigint.BigInt::from_uint64(1) << shift
}

///|
fn round_bigint(value : @bigint.BigInt, shift : Int) -> @bigint.BigInt {
  if shift <= 0 {
    return value
  }
  let mant = value >> shift
  let mask = bigint_pow2(shift) - @bigint.BigInt::from_uint64(1)
  let rem = value & mask
  let half = bigint_pow2(shift - 1)
  let cmp = rem.compare(half)
  if cmp > 0 {
    mant + @bigint.BigInt::from_uint64(1)
  } else if cmp == 0 {
    let lsb = mant & @bigint.BigInt::from_uint64(1)
    if !lsb.is_zero() {
      mant + @bigint.BigInt::from_uint64(1)
    } else {
      mant
    }
  } else {
    mant
  }
}

///|
fn fma_zero(sign : Int) -> Double {
  let sign_bit : UInt64 = if sign < 0 { 1 } else { 0 }
  UInt64::reinterpret_as_double(sign_bit << 63)
}

///|
fn fma_inf(sign : Int) -> Double {
  let sign_bit : UInt64 = if sign < 0 { 1 } else { 0 }
  let exp_bits : UInt64 = 0x7ff
  let bits = (sign_bit << 63) | (exp_bits << 52)
  UInt64::reinterpret_as_double(bits)
}

///|
fn fma_round(mag : @bigint.BigInt, exp : Int, sign : Int) -> Double {
  if mag.is_zero() {
    return fma_zero(sign)
  }
  let k = mag.bit_length()
  let mut exp_value = exp + k - 1
  if exp_value > 1023 {
    return fma_inf(sign)
  }
  if exp_value < -1022 {
    return fma_zero(sign)
  }
  let shift = k - 53
  let mut mant = if shift > 0 {
    round_bigint(mag, shift)
  } else if shift < 0 {
    mag << (-shift)
  } else {
    mag
  }
  if mant.bit_length() > 53 {
    mant = mant >> 1
    exp_value = exp_value + 1
    if exp_value > 1023 {
      return fma_inf(sign)
    }
  }
  let mant_u64 = mant.to_uint64()
  let frac_mask : UInt64 = 0x000f_ffff_ffff_ffff
  let frac = mant_u64 & frac_mask
  let exp_bits : UInt64 = (exp_value + 1023).to_uint64()
  let sign_bit : UInt64 = if sign < 0 { 1 } else { 0 }
  let bits = (sign_bit << 63) | (exp_bits << 52) | frac
  UInt64::reinterpret_as_double(bits)
}

///|
/// Graphviz parity: emulate fused multiply-add to match compiler fmadd
/// used in Graphviz Bezier evaluation. Do not change without updating fixtures.
pub fn libm_fma(x : Double, y : Double, z : Double) -> Double {
  let tx = fma_term(x)
  let ty = fma_term(y)
  let tz = fma_term(z)
  if tx.special || ty.special || tz.special {
    return x * y + z
  }
  let prod_sig =
    @bigint.BigInt::from_uint64(tx.sig) * @bigint.BigInt::from_uint64(ty.sig)
  let prod_exp = tx.exp + ty.exp
  let prod_sign = tx.sign * ty.sign
  let z_sig = @bigint.BigInt::from_uint64(tz.sig)
  let exp_min = if prod_sig.is_zero() {
    tz.exp
  } else if z_sig.is_zero() {
    prod_exp
  } else if prod_exp < tz.exp {
    prod_exp
  } else {
    tz.exp
  }
  let prod_scaled = if prod_sig.is_zero() {
    prod_sig
  } else {
    prod_sig << (prod_exp - exp_min)
  }
  let z_scaled = if z_sig.is_zero() {
    z_sig
  } else {
    z_sig << (tz.exp - exp_min)
  }
  let mut sum = if prod_sign < 0 { -prod_scaled } else { prod_scaled }
  if tz.sign < 0 {
    sum = sum - z_scaled
  } else {
    sum = sum + z_scaled
  }
  if sum.is_zero() {
    return fma_zero(0)
  }
  let zero = @bigint.BigInt::from_int(0)
  let sum_sign = if sum < zero { -1 } else { 1 }
  let mag = if sum_sign < 0 { -sum } else { sum }
  fma_round(mag, exp_min, sum_sign)
}
