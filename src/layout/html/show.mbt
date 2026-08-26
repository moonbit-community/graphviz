///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for HtmlAlign with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlAlign with Show::{to_string, output}

///|
pub impl Show for HtmlVAlign with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlVAlign with Show::{to_string, output}

///|
pub impl Show for HtmlTextSpan with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlTextSpan with Show::{to_string, output}

///|
pub impl Show for HtmlCellContent with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlCellContent with Show::{to_string, output}

///|
pub impl Show for HtmlCell with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlCell with Show::{to_string, output}

///|
pub impl Show for HtmlRow with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlRow with Show::{to_string, output}

///|
pub impl Show for HtmlTable with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlTable with Show::{to_string, output}

///|
pub impl Show for HtmlLabel with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlLabel with Show::{to_string, output}

///|
pub impl Show for HtmlCellPlacement with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlCellPlacement with Show::{to_string, output}

///|
pub impl Show for HtmlTableMetrics with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlTableMetrics with Show::{to_string, output}

///|
pub impl Show for HtmlCellLayout with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlCellLayout with Show::{to_string, output}

///|
pub impl Show for HtmlTableLayout with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub extend HtmlTableLayout with Show::{to_string, output}
