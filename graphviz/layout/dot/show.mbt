///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for DotLayoutOptions with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend DotLayoutOptions with Show::{to_string, output}

///|
pub impl Show for DotLayoutError with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend DotLayoutError with Show::{to_string, output}
