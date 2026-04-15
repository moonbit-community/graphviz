///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for OutputFormat with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for FormatSpec with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for LayoutEngine with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for AttrAssignment with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for CliJob with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for CliAction with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for CliError with output(self, logger) {
  write_debug(self, logger)
}
