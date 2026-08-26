///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for Point with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend Point with Show::{to_string, output}

///|
pub impl Show for Size with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend Size with Show::{to_string, output}

///|
pub impl Show for Rect with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend Rect with Show::{to_string, output}

///|
pub impl Show for Polyline with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend Polyline with Show::{to_string, output}

///|
pub impl Show for Bezier with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend Bezier with Show::{to_string, output}

///|
pub impl Show for Spline with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend Spline with Show::{to_string, output}
