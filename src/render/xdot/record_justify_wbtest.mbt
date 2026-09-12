///|
test "record nojustify uses field text width for left and right alignment" {
  let text = "bbbbbb\\nddd\\lddd\\r"
  let font : @render.Font = { name: "Times-Roman", size: 14.0, }
  let (_, text_width, _) = record_label_metrics(text, font.name, font.size)
  let layouts : Array[RecordLayout] = [
    {
      rect: { llx: 0.0, lly: 0.0, urx: 100.0, ury: 100.0, },
      node: Field({ text, }),
      children: [],
    },
  ]
  for nojustify in [false, true] {
    let ops : Array[@render.DrawOp] = []
    record_label_ops_from_layout(
      ops, layouts, "n", font, "black", 16.0, nojustify,
    )
    let half_space = if nojustify { text_width / 2.0 } else { 42.0 }
    let mut aligned_lines = 0
    for op in ops {
      if op is @render.DrawOp::Text(pos~, align~, ..) {
        match align {
          Left => {
            assert_true((pos.x - (50.0 - half_space)).abs() < 0.000001)
            aligned_lines += 1
          }
          Right => {
            assert_true((pos.x - (50.0 + half_space)).abs() < 0.000001)
            aligned_lines += 1
          }
          Center => ()
        }
      }
    }
    assert_true(aligned_lines == 2)
  }
}
