///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for OutputFormat with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend OutputFormat with Show::{to_string, output}

///|
pub impl Show for FormatSpec with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend FormatSpec with Show::{to_string, output}

///|
pub impl Show for LayoutEngine with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend LayoutEngine with Show::{to_string, output}

///|
pub impl Show for AttrAssignment with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend AttrAssignment with Show::{to_string, output}

///|
pub impl Show for CliJob with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend CliJob with Show::{to_string, output}

///|
pub impl Show for CliAction with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend CliAction with Show::{to_string, output}

///|
pub impl Show for CliError with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend CliError with Show::{to_string, output}
