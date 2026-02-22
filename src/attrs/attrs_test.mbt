///|
test "attrs parse_double uses fallback" {
  let val1 = parse_double(Some("2.5"), 1.0)
  assert_true(Double::is_close(val1, 2.5, absolute_tolerance=0.001))
  let val2 = parse_double(Some("not-a-number"), 1.5)
  assert_true(Double::is_close(val2, 1.5, absolute_tolerance=0.001))
  let val3 = parse_double(None, 3.0)
  assert_true(Double::is_close(val3, 3.0, absolute_tolerance=0.001))
}

///|
test "attrs font defaults" {
  assert_eq(font_name(None), "Times-Roman")
  assert_eq(font_name(Some("Helvetica")), "Helvetica")
  let size = font_size(None)
  assert_true(Double::is_close(size, 14.0, absolute_tolerance=0.001))
}

///|
test "attrs font size fallback on invalid or non-positive" {
  let invalid = font_size(Some("nope"))
  assert_true(Double::is_close(invalid, 14.0, absolute_tolerance=0.001))
  let negative = font_size(Some("-2"))
  assert_true(Double::is_close(negative, 14.0, absolute_tolerance=0.001))
}

///|
test "attrs color defaults and normalization" {
  assert_eq(color(None), "black")
  assert_eq(normalize_color("pink"), "#ffc0cb")
  assert_eq(normalize_color("maroon1"), "#ff34b3")
  assert_eq(normalize_color("salmon2"), "#ee8262")
  assert_eq(normalize_color("deepskyblue"), "#00bfff")
  assert_eq(normalize_color("darkorchid4"), "#68228b")
  assert_eq(normalize_color("lightblue"), "#add8e6")
  assert_eq(normalize_color("indigo"), "#4b0082")
  assert_eq(normalize_color("indianred"), "#cd5c5c")
  assert_eq(normalize_color("steelblue"), "#4682b4")
  assert_eq(normalize_color("limegreen"), "#32cd32")
  assert_eq(normalize_color("aquamarine"), "#7fffd4")
  assert_eq(normalize_color("grey"), "#c0c0c0")
  assert_eq(normalize_color("gray"), "#c0c0c0")
  assert_eq(normalize_color("gold"), "#ffd700")
  assert_eq(normalize_color("green4"), "#008b00")
  assert_eq(normalize_color("yellow3"), "#cdcd00")
  assert_eq(normalize_color("skyblue"), "#87ceeb")
  assert_eq(normalize_color("0.650 0.200 1.000"), "#ccd1ff")
  assert_eq(normalize_color("HotPink"), "#ff69b4")
  assert_eq(normalize_color("#ABCDEF"), "#abcdef")
}

///|
test "attrs parse_style flags" {
  let style = parse_style(Some("filled,dashed"))
  assert_eq(style.raw, "filled,dashed")
  assert_true(style.filled)
  assert_true(style.dashed)
  assert_true(!style.dotted)
  let default_style = parse_style(None)
  assert_eq(default_style.raw, "solid")
  assert_true(!default_style.filled)
}
