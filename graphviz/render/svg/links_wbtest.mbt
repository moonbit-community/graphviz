///|
test "SVG edge titles use the final port component" {
  @test.assert_eq(
    port_title_suffix(
      Some({ name: Some("field"), compass: Some(@cgraph.Compass::SE), }),
    ),
    ":se",
  )
  @test.assert_eq(
    port_title_suffix(Some({ name: Some("field"), compass: None, })),
    ":field",
  )
  @test.assert_eq(port_title_suffix(None), "")
}

///|
test "SVG links require a destination or explicit tooltip" {
  assert_true(
    svg_link(None, None, Some("_blank"), Some("label"), Map([])) is None,
  )
  guard svg_link(None, Some("help"), None, Some("label"), Map([])) is Some(link) else {
    fail("explicit tooltip must enable an anchor")
  }
  @test.assert_eq(link.href, None)
  @test.assert_eq(link.title, Some("help"))
}

///|
test "SVG link attributes substitute object names" {
  guard svg_link(Some("\\G/\\N"), None, Some("\\N"), Some("\\L"), {
      'G': "graph",
      'N': "node",
      'L': "label",
    })
    is Some(link) else {
    fail("missing link")
  }
  @test.assert_eq(link.href, Some("graph/node"))
  @test.assert_eq(link.title, Some("label"))
  @test.assert_eq(link.target, Some("node"))
}

///|
test "HTML table links preserve independent destinations and tooltips" {
  guard @html_label.parse_html_label(
      "<<TABLE HREF=\"table-url\" TOOLTIP=\"table-help\" TARGET=\"_blank\"><TR><TD>x</TD></TR></TABLE>>",
    )
    is Some(@html_label.HtmlLabel::Table(table)) else {
    fail("expected table")
  }
  @test.assert_eq(table.href, Some("table-url"))
  @test.assert_eq(table.tooltip, Some("table-help"))
  @test.assert_eq(table.target, Some("_blank"))
}
