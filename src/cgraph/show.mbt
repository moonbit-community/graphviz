///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for GraphKind with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for AttrKind with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Compass with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Port with output(self, logger) {
  write_debug(self, logger)
}
