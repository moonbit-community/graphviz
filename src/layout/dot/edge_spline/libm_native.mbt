///|
extern "C" fn libm_cbrt(x : Double) -> Double = "cbrt"

///|
extern "C" fn libm_atan2(y : Double, x : Double) -> Double = "atan2"

///|
extern "C" fn libm_hypot(x : Double, y : Double) -> Double = "hypot"

///|
const LIBM_IS_NATIVE : Bool = true

///|
extern "C" fn libm_sqrt(x : Double) -> Double = "sqrt"

///|
extern "C" fn libm_cos(x : Double) -> Double = "cos"

///|
extern "C" fn libm_sin(x : Double) -> Double = "sin"
