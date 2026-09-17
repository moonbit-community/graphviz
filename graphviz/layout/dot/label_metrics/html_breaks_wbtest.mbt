///|
test "HTML breaks justify the preceding line without adding a trailing line" {
  guard @html_label.parse_html_label(
      "<long line 1<BR/>line 2<BR ALIGN=\"LEFT\"/>line 3<BR ALIGN=\"RIGHT\"/>>",
      html=Some(true),
    )
    is Some(@html_label.HtmlLabel::StyledText(spans)) else {
    fail("expected HTML text")
  }
  let metrics = html_styled_text_metrics(spans, "", "Times-Roman", 14.0)
  @test.assert_eq(metrics.lines.length(), 3)
  @test.assert_eq(metrics.lines.map(line => line.alignment), [
    Some(@html_label.HtmlAlign::Center),
    Some(@html_label.HtmlAlign::Left),
    Some(@html_label.HtmlAlign::Right),
  ])
  @test.assert_eq(metrics.width_pt, 58.5)
  @test.assert_eq(metrics.height_pt, 49.5)
  assert_true(@html_label.parse_html_label("<hello>", html=Some(false)) is None)
  @test.assert_eq(
    @html_label.parse_html_label("<hello>", html=Some(true)),
    Some(@html_label.HtmlLabel::Text("hello")),
  )
}
