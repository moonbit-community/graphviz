// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
pub extern "C" fn libm_cbrt(x : Double) -> Double = "cbrt"

///|
pub extern "C" fn libm_atan2(y : Double, x : Double) -> Double = "atan2"

///|
pub extern "C" fn libm_hypot(x : Double, y : Double) -> Double = "hypot"

///|
pub const LIBM_IS_NATIVE : Bool = true

///|
pub extern "C" fn libm_sqrt(x : Double) -> Double = "sqrt"

///|
pub extern "C" fn libm_cos(x : Double) -> Double = "cos"

///|
pub extern "C" fn libm_sin(x : Double) -> Double = "sin"

///|
pub extern "C" fn libm_fma(x : Double, y : Double, z : Double) -> Double = "fma"
