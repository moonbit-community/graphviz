///|
test "oversized rowspan retains its cell and link metadata through layout" {
  guard parse_html_label(
      "<<TABLE PORT=\"outer\"><TR><TD ROWSPAN=\"3\" HREF=\"cell-url\" TOOLTIP=\"help\" TARGET=\"_blank\">x</TD><VR/><TD>y</TD></TR></TABLE>>",
    )
    is Some(HtmlLabel::Table(table)) else {
    fail("expected table")
  }
  @test.assert_eq(table.port, Some("outer"))
  let layout = html_table_layout(
    table,
    { llx: 0.0, lly: 0.0, urx: 60.0, ury: 40.0, },
    _cell => (10.0, 10.0),
  )
  @test.assert_eq(layout.cells.length(), 2)
  let cell = layout.cells[0]
  @test.assert_eq(cell.cell.href, Some("cell-url"))
  @test.assert_eq(cell.cell.tooltip, Some("help"))
  @test.assert_eq(cell.cell.target, Some("_blank"))
  @test.assert_eq(cell.cell.vruled, true)
  assert_true(cell.rect.ury > cell.rect.lly)
}
