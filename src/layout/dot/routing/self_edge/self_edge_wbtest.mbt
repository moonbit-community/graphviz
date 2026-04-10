// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "apply_self_edge_right_space accumulates implicit self-edge padding" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let self1 = graph.edge(a, a)
  let self2 = graph.edge(a, a)
  let other = graph.edge(a, b)
  let size = @node_primitives.vnode_size_from_widths_with_h(10.0, 10.0, 20.0)
  let sizes : Map[String, @node_primitives.NodeSize] = { "a": size, "b": size }

  let adjusted = apply_self_edge_right_space({
    edges: [self1, self2, other],
    sizes,
    rankdir: RankDir::TB,
    self_edge_size_pt: 6.0,
    self_edge_label_width_for: (edge, _rankdir) => {
      if edge.id() == self1.id() {
        4.0
      } else if edge.id() == self2.id() {
        2.0
      } else {
        99.0
      }
    },
    port_side_mask_for: (_node, _port) => 0,
  })

  let a_size = adjusted["a"]
  let b_size = adjusted["b"]
  assert_eq(a_size.left_pt, size.left_pt)
  assert_eq(a_size.right_pt, size.right_pt + (6.0 + 4.0) + (6.0 + 2.0))
  assert_eq(a_size.height_pt, size.height_pt)
  assert_eq(b_size.left_pt, size.left_pt)
  assert_eq(b_size.right_pt, size.right_pt)
  assert_eq(b_size.height_pt, size.height_pt)
}

///|
test "apply_self_edge_right_space skips explicit left-side self-edge ports" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let west_port = @cgraph.Port::{
    name: None,
    compass: Some(@cgraph.Compass::W),
  }
  let self_edge = graph.edge(a, a, tail_port=west_port, head_port=west_port)
  let size = @node_primitives.vnode_size_from_widths_with_h(8.0, 8.0, 20.0)
  let sizes : Map[String, @node_primitives.NodeSize] = { "a": size }

  let adjusted = apply_self_edge_right_space({
    edges: [self_edge],
    sizes,
    rankdir: RankDir::TB,
    self_edge_size_pt: 6.0,
    self_edge_label_width_for: (_edge, _rankdir) => 5.0,
    port_side_mask_for: (_node, _port) => PORT_SIDE_LEFT,
  })

  let adjusted_size = adjusted["a"]
  assert_eq(adjusted_size.left_pt, size.left_pt)
  assert_eq(adjusted_size.right_pt, size.right_pt)
  assert_eq(adjusted_size.height_pt, size.height_pt)
  assert_eq(adjusted_size.width_pt, size.width_pt)
}

///|
test "apply_self_edge_right_space keeps same top-side explicit ports at zero extra" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let north_port = @cgraph.Port::{
    name: None,
    compass: Some(@cgraph.Compass::N),
  }
  let self_edge = graph.edge(a, a, tail_port=north_port, head_port=north_port)
  let size = @node_primitives.vnode_size_from_widths_with_h(8.0, 8.0, 20.0)
  let sizes : Map[String, @node_primitives.NodeSize] = { "a": size }

  let adjusted = apply_self_edge_right_space({
    edges: [self_edge],
    sizes,
    rankdir: RankDir::TB,
    self_edge_size_pt: 6.0,
    self_edge_label_width_for: (_edge, _rankdir) => 5.0,
    port_side_mask_for: (_node, _port) => PORT_SIDE_TOP,
  })

  let adjusted_size = adjusted["a"]
  assert_eq(adjusted_size.left_pt, size.left_pt)
  assert_eq(adjusted_size.right_pt, size.right_pt)
  assert_eq(adjusted_size.height_pt, size.height_pt)
  assert_eq(adjusted_size.width_pt, size.width_pt)
}

///|
test "apply_self_edge_right_space keeps explicit right-side loops in the right-space budget" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let east_port = @cgraph.Port::{
    name: None,
    compass: Some(@cgraph.Compass::E),
  }
  let self_edge = graph.edge(a, a, tail_port=east_port, head_port=east_port)
  let size = @node_primitives.vnode_size_from_widths_with_h(8.0, 8.0, 20.0)
  let sizes : Map[String, @node_primitives.NodeSize] = { "a": size }

  let adjusted = apply_self_edge_right_space({
    edges: [self_edge],
    sizes,
    rankdir: RankDir::TB,
    self_edge_size_pt: 6.0,
    self_edge_label_width_for: (_edge, _rankdir) => 5.0,
    port_side_mask_for: (_node, _port) => PORT_SIDE_RIGHT,
  })

  let adjusted_size = adjusted["a"]
  assert_eq(adjusted_size.left_pt, size.left_pt)
  assert_eq(adjusted_size.right_pt, size.right_pt + 11.0)
  assert_eq(adjusted_size.height_pt, size.height_pt)
}
