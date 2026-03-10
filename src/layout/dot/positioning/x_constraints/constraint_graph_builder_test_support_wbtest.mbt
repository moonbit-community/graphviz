///|
fn require_constraint_builder_index(
  index : Map[String, Int],
  name : String,
) -> Int raise {
  match index.get(name) {
    Some(value) => value
    None => fail("missing index for \{name}")
  }
}

///|
fn make_constraint_builder_test_port(
  name : String,
  compass : @cgraph.Compass,
) -> @cgraph.Port {
  { name: Some(name), compass: Some(compass) }
}

///|
fn build_constraint_builder_test_sizes() -> Map[
  String,
  @node_primitives.NodeSize,
] {
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.vnode_size_from_widths_with_h(3.0, 4.0, 10.0)
  sizes["b"] = @node_primitives.vnode_size_from_widths_with_h(6.0, 7.0, 12.0)
  sizes["c"] = @node_primitives.vnode_size_from_widths_with_h(5.0, 8.0, 8.0)
  sizes["d"] = @node_primitives.vnode_size_from_widths_with_h(2.0, 3.0, 9.0)
  sizes["e"] = @node_primitives.vnode_size_from_widths_with_h(4.0, 5.0, 11.0)
  sizes
}
