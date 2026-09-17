// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn pow10_int(exp : Int) -> Int {
  if exp <= 0 {
    return 1
  }
  let mut result = 1
  for _ in 0..<exp {
    result = result * 10
  }
  result
}

///|
fn pow10_double(exp : Int) -> Double {
  @math.pow(10.0, exp.to_double())
}

///|
pub fn trim_trailing_zeros(text : String) -> String {
  if !text.contains(".") {
    return text
  }
  let mut result = text
  while result.length() > 0 && result.has_suffix("0") {
    let next_len = result.length() - 1
    result = result.unsafe_substring(start=0, end=next_len)
  }
  if result.has_suffix(".") {
    let next_len = result.length() - 1
    result = result.unsafe_substring(start=0, end=next_len)
  }
  result
}

///|
fn round_half_even(value : Double, decimals : Int) -> Double {
  let digits = if decimals > 0 { decimals } else { 0 }
  let scale = pow10_double(digits)
  let abs_value = if value < 0.0 { -value } else { value }
  let scaled = abs_value * scale
  let floored = scaled.floor()
  let frac = scaled - floored
  let eps = 0.000000000001
  let rounded = if frac < 0.5 - eps {
    floored
  } else if frac > 0.5 + eps {
    floored + 1.0
  } else if decimal_tie_rounds_up(abs_value, digits) {
    floored + 1.0
  } else {
    floored
  }
  if value < 0.0 {
    -rounded / scale
  } else {
    rounded / scale
  }
}

///|
// Multiplication by 10^digits can erase which side of a decimal tie a
// binary64 value occupies. Resolve only that ambiguous case using its exact
// significand, as printf does, rather than treating a tolerance as equality.
fn decimal_tie_rounds_up(abs_value : Double, digits : Int) -> Bool {
  let bits = abs_value.reinterpret_as_uint64()
  let exponent = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0x000fffffffffffffUL
  let (significand, exp2) = if exponent == 0 {
    (fraction, -1074)
  } else {
    (fraction | 0x0010000000000000UL, exponent - 1075)
  }
  guard exp2 < 0 else { return false }
  let numerator = for numerator = @bigint.BigInt::from_uint64(significand), i = 0 {
    guard i < digits else { break numerator }
    continue numerator * @bigint.BigInt::from_int(10), i + 1
  }
  let denominator = @bigint.BigInt::from_int(1) << -exp2
  let remainder = numerator % denominator
  let doubled = remainder + remainder
  guard doubled == denominator else { return doubled > denominator }
  !(numerator / denominator % @bigint.BigInt::from_int(2)).is_zero()
}

///|
pub fn format_fixed(value : Double, decimals : Int) -> String {
  if decimals <= 0 {
    return "\{round_half_even(value, 0).to_int()}"
  }
  let scale = pow10_int(decimals)
  let scaled = round_half_even(value * scale.to_double(), 0).to_int()
  let int_part = scaled / scale
  let mut frac = scaled % scale
  if frac < 0 {
    frac = -frac
  }
  let mut frac_str = frac.to_string()
  while frac_str.length() < decimals {
    frac_str = "0\{frac_str}"
  }
  "\{int_part}.\{frac_str}"
}

///|
pub fn format_fixed_trim(value : Double, decimals : Int) -> String {
  trim_trailing_zeros(format_fixed(value, decimals))
}

///|
pub fn round_to(value : Double, decimals : Int) -> Double {
  round_half_even(value, decimals)
}

///|
fn format_scientific(
  abs : Double,
  exp : Int,
  precision : Int,
  sign : String,
) -> String {
  let mut exp_mut = exp
  let mantissa = abs / pow10_double(exp_mut)
  let decimals = precision - 1
  let mut rounded = round_to(mantissa, decimals)
  if rounded >= 10.0 {
    rounded = rounded / 10.0
    exp_mut = exp_mut + 1
  }
  let mantissa_str = format_fixed_trim(rounded, decimals)
  let exp_sign = if exp_mut < 0 { "-" } else { "+" }
  let exp_abs = if exp_mut < 0 { -exp_mut } else { exp_mut }
  let exp_str = if exp_abs < 10 { "0\{exp_abs}" } else { "\{exp_abs}" }
  "\{sign}\{mantissa_str}e\{exp_sign}\{exp_str}"
}

///|
pub fn format_float(value : Double) -> String {
  if value == 0.0 {
    return "0"
  }
  let sign = if value < 0.0 { "-" } else { "" }
  let abs = if value < 0.0 { -value } else { value }
  let precision = 5
  let exp = @math.log10(abs).floor().to_int()
  if exp < -4 || exp >= precision {
    return format_scientific(abs, exp, precision, sign)
  }
  let decimals = precision - exp - 1
  let rounded = round_to(abs, decimals)
  if rounded != 0.0 {
    let new_exp = @math.log10(rounded).floor().to_int()
    if new_exp >= precision {
      return format_scientific(rounded, new_exp, precision, sign)
    }
  }
  "\{sign}\{format_fixed_trim(rounded, decimals)}"
}

///|
pub fn format_dim(value : Double) -> String {
  format_float(value)
}

///|
pub fn format_point(point : @geom.Point) -> String {
  "\{format_float(point.x)},\{format_float(point.y)}"
}

///|
pub fn format_rect(rect : @geom.Rect) -> String {
  "\{format_float(rect.llx)},\{format_float(rect.lly)},\{format_float(rect.urx)},\{format_float(rect.ury)}"
}

///|
pub fn format_rects(rects : Array[@geom.Rect]) -> String {
  let parts : Array[String] = []
  for rect in rects {
    parts.push(format_rect(rect))
  }
  parts.join(" ")
}
