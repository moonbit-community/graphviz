///|
test "parse_splines accepts graphviz aliases" {
  assert_eq(parse_splines("true"), Some(SplinesMode::Spline))
  assert_eq(parse_splines("line"), Some(SplinesMode::Polyline))
  assert_eq(parse_splines(""), Some(SplinesMode::None))
  assert_eq(parse_splines("ortho"), Some(SplinesMode::Ortho))
  assert_eq(parse_splines("curved"), Some(SplinesMode::Curved))
  assert_eq(parse_splines("bogus"), None)
}
