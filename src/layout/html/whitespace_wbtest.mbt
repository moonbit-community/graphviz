///|
test "HTML cells retain spaces but omit formatting controls" {
  guard parse_html_label(
      "<<TABLE><TR><TD> </TD><TD> a  b\n\t </TD></TR></TABLE>>",
    )
    is Some(HtmlLabel::Table(table)) else {
    fail("expected table")
  }
  @test.assert_eq(table.rows[0].cells[0].content, HtmlCellContent::Text(" "))
  @test.assert_eq(
    table.rows[0].cells[1].content,
    HtmlCellContent::Text(" a  b "),
  )
}
