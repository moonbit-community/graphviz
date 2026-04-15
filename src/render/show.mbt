///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for TextAlign with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Font with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for GradientStop with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for LinearGradient with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for RadialGradient with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Gradient with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for DrawOp with output(self, logger) {
  write_debug(self, logger)
}
