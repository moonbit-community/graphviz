///|
test "HTML font runs inherit nested attributes and restore their parent" {
  guard @html_label.parse_html_label(
      "<<TABLE><TR><TD><FONT FACE=\"Helvetica-Bold\" POINT-SIZE=\"30\">a<FONT COLOR=\"red\">b</FONT>c</FONT>d</TD></TR></TABLE>>",
    )
    is Some(@html_label.HtmlLabel::Table(table)) else {
    fail("expected table")
  }
  guard table.rows[0].cells[0].content
    is @html_label.HtmlCellContent::StyledText(spans) else {
    fail("expected styled text")
  }
  @test.assert_eq(spans.length(), 4)
  @test.assert_eq(spans[1].font_name, Some("Helvetica-Bold"))
  @test.assert_eq(spans[1].font_size_pt, Some(30.0))
  @test.assert_eq(spans[1].color, Some("red"))
  @test.assert_eq(spans[2].color, None)
  @test.assert_eq(spans[3].font_name, None)
  @test.assert_eq(spans[3].font_size_pt, None)
}

///|
test "HTML font measurements flow to run widths and simple baselines" {
  let text = "image attribute (null)"
  let metrics = html_styled_text_metrics(
    [
      {
        text,
        color: None,
        font_name: Some("Helvetica-Bold"),
        font_size_pt: Some(30.0),
        break_alignment: None,
      },
    ],
    "",
    "Times-Roman",
    14.0,
  )
  let (width, height, _, offset) = label_text_metrics(
    text, "Helvetica-Bold", 30.0,
  )
  assert_true(metrics.simple)
  @test.assert_eq(metrics.width_pt, width)
  @test.assert_eq(metrics.height_pt, height)
  @test.assert_eq(metrics.lines[0].baseline_advance, 30.0)
  @test.assert_eq(metrics.lines[0].runs[0].yoffset_centerline, offset)
}

///|
test "HTML mixed font lines use upstream baseline advances" {
  let metrics = html_styled_text_metrics(
    [
      {
        text: "small",
        color: None,
        font_name: None,
        font_size_pt: Some(10.0),
        break_alignment: None,
      },
      {
        text: "large\nnext",
        color: None,
        font_name: None,
        font_size_pt: Some(30.0),
        break_alignment: None,
      },
    ],
    "",
    "Times-Roman",
    14.0,
  )
  assert_false(metrics.simple)
  @test.assert_eq(metrics.lines.length(), 2)
  @test.assert_eq(metrics.height_pt, 60.0)
  let (_, _, _, offset) = label_text_metrics("large", "Times-Roman", 30.0)
  @test.assert_eq(metrics.lines[0].baseline_advance, 30.0 - offset)
  @test.assert_eq(metrics.lines[1].baseline_advance, 30.0)
}
