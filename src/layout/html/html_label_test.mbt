///|
fn assert_text_label(label : String, expected : String) -> Unit raise {
  match parse_html_label(label) {
    Some(HtmlLabel::Text(text)) => assert_eq(text, expected)
    Some(_) => fail("expected text label")
    None => fail("missing html label")
  }
}

///|
test "html label unescapes quotes" {
  let label = "<<b>\\\"hi\\\"</b>>"
  match strip_html_wrappers(label) {
    Some(value) => assert_eq(value, "<b>\"hi\"</b>")
    None => fail("expected html wrapper")
  }
  assert_text_label(label, "\"hi\"")
}

///|
test "html label parses table cell" {
  let label = "<<table><tr><td port=\"p1\">Hello</td></tr></table>>"
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
      assert_eq(table.rows.length(), 1)
      let row = table.rows[0]
      assert_eq(row.cells.length(), 1)
      let cell = row.cells[0]
      assert_eq(cell.port, Some("p1"))
      match cell.content {
        HtmlCellContent::Text(text) => assert_eq(text, "Hello")
        _ => fail("expected text cell")
      }
    }
    _ => fail("expected table label")
  }
}
