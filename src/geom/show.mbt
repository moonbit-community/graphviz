///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for Point with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Size with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Rect with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Polyline with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Bezier with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Spline with output(self, logger) {
  write_debug(self, logger)
}
