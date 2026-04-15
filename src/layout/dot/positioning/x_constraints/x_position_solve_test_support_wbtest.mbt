// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn require_simplex_test_size(
  sizes : Map[String, @node_primitives.NodeSize],
  name : String,
) -> @node_primitives.NodeSize raise {
  match sizes.get(name) {
    Some(value) => value
    None => fail("missing size for \{name}")
  }
}

///|
fn build_simplex_test_input(
  use_vnodes_for_xpos : Bool,
) -> XPositionPipelineInput {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "b"]
  let x_base_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  x_base_sizes["a"] = @node_primitives.node_size_from_points(10.0, 10.0)
  x_base_sizes["b"] = @node_primitives.node_size_from_points(12.0, 8.0)
  let vnode_name = "\{@edge_identity.EDGE_VNODE_PREFIX}0_1"
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes[vnode_name] = @node_primitives.vnode_size_from_widths_with_h(
    4.0, 6.0, 2.0,
  )
  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks[vnode_name] = 1
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes["edge0"] = [vnode_name]
  {
    use_vnodes_for_xpos,
    x_base_sizes,
    x_groups,
    vnode_sizes,
    vnode_creation_order: [vnode_name],
    vnode_ranks,
    edge_vnodes,
    graph,
    nodes: [a, b],
    edges: [],
    edge_tail: [],
    edge_head: [],
    edge_out_order: Map::new(),
    nlist_order: ["a", "b", vnode_name],
    gdnlist_order: ["a", "b", vnode_name],
    cluster_keys: Map::new(),
    nodesep_pt: 12.0,
    has_edge_labels: false,
    output_sizes: x_base_sizes,
    flat_label_edges: [],
  }
}
