///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for TextAlign with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Font with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for GradientStop with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for LinearGradient with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for RadialGradient with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for Gradient with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for DrawOp with fn output(self, logger) {
  write_debug(self, logger)
}
