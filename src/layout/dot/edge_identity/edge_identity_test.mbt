// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "unique_virtual_node_name allocates base name then collision suffixes" {
  let existing : Map[String, Bool] = Map::new()

  let first = unique_virtual_node_name("tmp_", 3, 5, existing)
  assert_eq(first, "tmp_3_5")
  assert_eq(existing.get("tmp_3_5"), Some(true))

  let second = unique_virtual_node_name("tmp_", 3, 5, existing)
  let third = unique_virtual_node_name("tmp_", 3, 5, existing)
  assert_eq(second, "tmp_3_5_1")
  assert_eq(third, "tmp_3_5_2")
}

///|
test "port helpers distinguish implicit explicit named and compass ports" {
  let implicit : @cgraph.Port = { name: None, compass: None }
  let named : @cgraph.Port = { name: Some("field"), compass: None }
  let compass : @cgraph.Port = {
    name: None,
    compass: Some(@cgraph.Compass::SW),
  }
  let both : @cgraph.Port = {
    name: Some("field"),
    compass: Some(@cgraph.Compass::N),
  }

  assert_false(port_is_explicit(None))
  assert_false(port_is_explicit(Some(implicit)))
  assert_true(port_is_explicit(Some(named)))
  assert_true(port_is_explicit(Some(compass)))
  assert_true(port_is_explicit(Some(both)))

  assert_eq(port_key(None), "")
  assert_eq(port_key(Some(implicit)), "")
  assert_eq(port_key(Some(named)), "field")
  assert_eq(port_key(Some(compass)), "sw")
  assert_eq(port_key(Some(both)), "field:n")
}

///|
test "edge_key keeps explicit name and both endpoint ports" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let tail_port : @cgraph.Port = {
    name: Some("tail"),
    compass: Some(@cgraph.Compass::E),
  }
  let head_port : @cgraph.Port = {
    name: Some("head"),
    compass: Some(@cgraph.Compass::W),
  }
  let edge = graph.edge(a, b, name="route", tail_port~, head_port~)

  assert_eq(edge_key(edge), "a|b|route|tail:e|head:w")
}

///|
test "edge_vnode_key adds edge id only when the edge has a label" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let port : @cgraph.Port = { name: None, compass: Some(@cgraph.Compass::S) }
  let plain = graph.edge(a, b, tail_port=port, head_port=port)
  let labeled = graph.edge(a, b, name="labeled", tail_port=port, head_port=port)
  labeled.set_attr("label", "mid")

  assert_eq(edge_vnode_key(plain), "a|b|s|s")
  assert_eq(edge_vnode_key(labeled), "a|b|s|s|\{labeled.id()}")
  assert_true(is_edge_vnode_name("\{EDGE_VNODE_PREFIX}12_7"))
  assert_false(is_edge_vnode_name("edge_vn_12_7"))
}
