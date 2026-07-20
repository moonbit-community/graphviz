///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for HtmlAlign with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlVAlign with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlTextSpan with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlCellContent with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlCell with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlRow with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlTable with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlLabel with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlCellPlacement with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlTableMetrics with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlCellLayout with fn output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlTableLayout with fn output(self, logger) {
  write_debug(self, logger)
}
