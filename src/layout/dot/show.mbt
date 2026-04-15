///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for DotLayoutOptions with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for DotLayoutError with output(self, logger) {
  write_debug(self, logger)
}
