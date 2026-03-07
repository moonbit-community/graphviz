///|
fn assert_double_close(
  actual : Double,
  expected : Double,
  eps : Double,
) -> Unit raise {
  let ok = Double::is_close(actual, expected, absolute_tolerance=eps)
  if !ok {
    fail("expected \{expected}, got \{actual}")
  }
}

///|
test "numeric parsers extract and clamp doubles" {
  assert_double_close(parse_double_or("12.5", 0.0), 12.5, 0.000001)
  assert_double_close(parse_double_or("oops", 3.5), 3.5, 0.000001)

  assert_double_close(
    parse_first_double("ranksep=1.75 equally", 0.0),
    1.75,
    0.000001,
  )
  assert_double_close(parse_first_double("equally", 2.25), 2.25, 0.000001)

  assert_eq(parse_first_double_optional(" +2.5 equally"), Some(2.5))
  assert_eq(parse_first_double_optional("equally"), None)

  assert_double_close(parse_attr_double("-0.5", 1.0, 0.02), 0.02, 0.000001)
  assert_double_close(parse_attr_double("2.0", 1.0, 0.02), 2.0, 0.000001)
  assert_double_close(parse_attr_double("equally", 1.0, 0.02), 1.0, 0.000001)
}
