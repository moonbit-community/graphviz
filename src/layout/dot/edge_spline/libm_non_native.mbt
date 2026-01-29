///|
fn libm_cbrt(x : Double) -> Double {
  @math.cbrt(x)
}

///|
fn libm_atan2(y : Double, x : Double) -> Double {
  @math.atan2(y, x)
}

///|
fn libm_hypot(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}

///|
const LIBM_IS_NATIVE : Bool = false

///|
fn libm_sqrt(x : Double) -> Double {
  Double::sqrt(x)
}

///|
fn libm_cos(x : Double) -> Double {
  @math.cos(x)
}

///|
fn libm_sin(x : Double) -> Double {
  @math.sin(x)
}
