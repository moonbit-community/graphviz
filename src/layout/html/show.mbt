///|
fn[T : Debug] write_debug(value : T, logger : &Logger) -> Unit {
  logger.write_string(@debug.to_string(value))
}

///|
pub impl Show for HtmlAlign with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlVAlign with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlTextSpan with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlCellContent with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlCell with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlRow with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlTable with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlLabel with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlCellPlacement with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlTableMetrics with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlCellLayout with output(self, logger) {
  write_debug(self, logger)
}

///|
pub impl Show for HtmlTableLayout with output(self, logger) {
  write_debug(self, logger)
}
