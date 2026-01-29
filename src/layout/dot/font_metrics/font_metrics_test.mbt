///|
test "font metrics arrays sizes" {
  assert_eq(font_metrics.length(), 128)
  assert_eq(font_kerning.length(), 128 * 128)
  assert_eq(font_space_kerning.length(), 128)
}

///|
test "font metrics known glyph width" {
  let idx = 'A'.to_int()
  let width = font_metrics[idx]
  assert_true(Double::is_close(width, 696.4286, absolute_tolerance=0.0001))
}
