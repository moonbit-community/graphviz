///|
test "Graphviz boolean attributes accept names and decimal prefixes" {
  for value in ["true", "TRUE", "Yes", "1", "002tail"] {
    assert_true(graphviz_bool(Some(value)))
  }
  for value in ["", "false", "NO", "0", "000tail", "-1", " true", "unknown"] {
    assert_false(graphviz_bool(Some(value)))
  }
  assert_false(graphviz_bool(None))
}
