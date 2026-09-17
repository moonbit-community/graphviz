///|
test "layer attribute serialization order is independent of insertion order" {
  for
    attrs in [
      [("layers", "a+b"), ("layersep", "+")],
      [("layersep", "+"), ("layers", "a+b")],
    ] {
    let sorted = sort_attrs(attrs)
    assert_true(sorted[0].0 == "layers")
    assert_true(sorted[1].0 == "layersep")
  }
}
