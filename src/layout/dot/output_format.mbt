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
fn trim_trailing_zeros(text : String) -> String {
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
  if decimals <= 0 {
    let floored = value.floor()
    let frac = value - floored
    let eps = 0.000000000001
    if frac < 0.5 - eps {
      return floored
    }
    if frac > 0.5 + eps {
      return floored + 1.0
    }
    let int_floor = floored.to_int()
    if int_floor % 2 == 0 {
      return floored
    } else {
      return floored + 1.0
    }
  }
  let scale = pow10_double(decimals)
  let scaled = value * scale
  let floored = scaled.floor()
  let frac = scaled - floored
  let eps = 0.000000000001
  let rounded = if frac < 0.5 - eps {
    floored
  } else if frac > 0.5 + eps {
    floored + 1.0
  } else {
    let int_floor = floored.to_int()
    if int_floor % 2 == 0 {
      floored
    } else {
      floored + 1.0
    }
  }
  rounded / scale
}

///|
fn format_fixed(value : Double, decimals : Int) -> String {
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
fn format_fixed_trim(value : Double, decimals : Int) -> String {
  trim_trailing_zeros(format_fixed(value, decimals))
}

///|
fn round_to(value : Double, decimals : Int) -> Double {
  round_half_even(value, decimals)
}

///|
fn format_scientific(abs : Double, exp : Int, precision : Int, sign : String) -> String {
  let mut exp_mut = exp
  let mantissa = abs / pow10_double(exp_mut)
  let decimals = precision - 1
  let mut rounded = round_to(mantissa, decimals)
  if rounded >= 10.0 {
    rounded = rounded / 10.0
    exp_mut = exp_mut + 1
  }
  let mantissa_str = format_fixed_trim(rounded, decimals)
  let exp_sign = if exp_mut < 0 {
    "-"
  } else {
    "+"
  }
  let exp_abs = if exp_mut < 0 {
    -exp_mut
  } else {
    exp_mut
  }
  let exp_str =
    if exp_abs < 10 {
    "0\{exp_abs}"
  } else {
    "\{exp_abs}"
  }
  "\{sign}\{mantissa_str}e\{exp_sign}\{exp_str}"
}

///|
fn format_float(value : Double) -> String {
  if value == 0.0 {
    return "0"
  }
  let sign = if value < 0.0 {
    "-"
  } else {
    ""
  }
  let abs = if value < 0.0 {
    -value
  } else {
    value
  }
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
fn format_dim(value : Double) -> String {
  format_float(value)
}

///|
fn format_point(point : @geom.Point) -> String {
  "\{format_float(point.x)},\{format_float(point.y)}"
}

///|
fn format_rect(rect : @geom.Rect) -> String {
  "\{format_float(rect.llx)},\{format_float(rect.lly)},\{format_float(rect.urx)},\{format_float(rect.ury)}"
}

///|
fn format_rects(rects : Array[@geom.Rect]) -> String {
  let parts : Array[String] = []
  for rect in rects {
    parts.push(format_rect(rect))
  }
  parts.join(" ")
}
