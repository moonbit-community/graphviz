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
pub fn libm_fma(x : Double, y : Double, z : Double) -> Double {
  x * y + z
}
