///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for XDotOptions with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend XDotOptions with Show::{to_string, output}
