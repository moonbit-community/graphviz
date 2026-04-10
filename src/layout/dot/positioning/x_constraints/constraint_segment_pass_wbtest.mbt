// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_constraint_segment_pass updates same-rank invis ordering constraints and skips intercluster edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ordering", "out")
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let inside = graph.edge(b, a)
  inside.set_attr("style", "invis")
  inside.set_attr("minlen", "2")
  inside.set_attr("weight", "7")
  let cross = graph.edge(a, c, name="cross")
  cross.set_attr("minlen", "5")
  cross.set_attr("weight", "11")

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["b"] = [0]
  edge_out_order["a"] = [1]

  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 0 }
  let cluster_keys : Map[String, String] = {
    "a": "cluster0",
    "b": "cluster0",
    "c": "cluster1",
  }
  let order_in_rank : Map[String, Int] = { "a": 0, "b": 1, "c": 2 }
  let rank_adj_constraints : Map[String, ConstraintEdge] = {
    "a|b": {
      tail: "a",
      head: "b",
      minlen: 12,
      weight: 3,
      tail_port: None,
      head_port: None,
    },
  }

  let output = build_constraint_segment_pass({
    edges: [inside, cross],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["b", "a", "c"],
    ranks,
    cluster_keys,
    edge_vnodes: Map::new(),
    order_in_rank,
    nodesep_pt: 10.0,
    sizes: build_constraint_builder_test_sizes(),
    skip_intercluster: true,
    rank_adj_constraints,
    edge_has_mid_label: _ => false,
    edge_degree_increment: _ => 1,
  })

  let merged = match rank_adj_constraints.get("a|b") {
    Some(value) => value
    None => fail("missing merged same-rank constraint")
  }

  assert_eq(merged.tail, "a")
  assert_eq(merged.head, "b")
  assert_eq(merged.minlen, 40)
  assert_eq(merged.weight, 7)
  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 0)
}

///|
test "build_constraint_segment_pass adds synthetic ordering ports on same-rank labeled vnode chains" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ordering", "out")
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("label", "mid")
  edge.set_attr("weight", "3")
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}flat_0"

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [0]
  let ranks : Map[String, Int] = { "a": 0, "b": 0 }
  ranks[vnode] = 0
  let order_in_rank : Map[String, Int] = { "a": 0, "b": 2 }
  order_in_rank[vnode] = 1
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = [vnode]

  let output = build_constraint_segment_pass({
    edges: [edge],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["a", vnode, "b"],
    ranks,
    cluster_keys: Map::new(),
    edge_vnodes,
    order_in_rank,
    nodesep_pt: 10.0,
    sizes: build_constraint_builder_test_sizes(),
    skip_intercluster: false,
    rank_adj_constraints: Map::new(),
    edge_has_mid_label: _ => true,
    edge_degree_increment: _ => 1,
  })

  let head_segments = match output.segments_by_tail.get("a") {
    Some(value) => value
    None => fail("missing first vnode segment")
  }
  let tail_segments = match output.segments_by_tail.get(vnode) {
    Some(value) => value
    None => fail("missing second vnode segment")
  }

  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 2)

  assert_eq(head_segments.length(), 1)
  assert_eq(head_segments[0].tail, "a")
  assert_eq(head_segments[0].head, vnode)
  assert_eq(head_segments[0].weight, 6)
  assert_eq(@edge_identity.port_key(head_segments[0].tail_port), "e")
  assert_eq(@edge_identity.port_key(head_segments[0].head_port), "w")

  assert_eq(tail_segments.length(), 1)
  assert_eq(tail_segments[0].tail, vnode)
  assert_eq(tail_segments[0].head, "b")
  assert_eq(tail_segments[0].weight, 6)
  assert_eq(@edge_identity.port_key(tail_segments[0].tail_port), "")
  assert_eq(@edge_identity.port_key(tail_segments[0].head_port), "")
}

///|
test "build_constraint_segment_pass reverses descending vnode chains and scales sparse segment weights" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("weight", "3")

  let vnode0 = "\{@edge_identity.EDGE_VNODE_PREFIX}desc_0"
  let vnode1 = "\{@edge_identity.EDGE_VNODE_PREFIX}desc_1"
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [0]
  let ranks : Map[String, Int] = { "a": 2, "b": 0 }
  ranks[vnode0] = 1
  ranks[vnode1] = 1
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = [vnode0, vnode1]

  let output = build_constraint_segment_pass({
    edges: [edge],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["a", vnode0, vnode1, "b"],
    ranks,
    cluster_keys: Map::new(),
    edge_vnodes,
    order_in_rank: Map::new(),
    nodesep_pt: 10.0,
    sizes: build_constraint_builder_test_sizes(),
    skip_intercluster: false,
    rank_adj_constraints: Map::new(),
    edge_has_mid_label: _ => false,
    edge_degree_increment: _ => 1,
  })

  let first_segments = match output.segments_by_tail.get("a") {
    Some(value) => value
    None => fail("missing first descending segment")
  }
  let middle_segments = match output.segments_by_tail.get(vnode1) {
    Some(value) => value
    None => fail("missing middle descending segment")
  }
  let last_segments = match output.segments_by_tail.get(vnode0) {
    Some(value) => value
    None => fail("missing last descending segment")
  }

  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 3)

  assert_eq(first_segments.length(), 1)
  assert_eq(first_segments[0].tail, "a")
  assert_eq(first_segments[0].head, vnode1)
  assert_eq(first_segments[0].weight, 6)

  assert_eq(middle_segments.length(), 1)
  assert_eq(middle_segments[0].tail, vnode1)
  assert_eq(middle_segments[0].head, vnode0)
  assert_eq(middle_segments[0].weight, 12)

  assert_eq(last_segments.length(), 1)
  assert_eq(last_segments[0].tail, vnode0)
  assert_eq(last_segments[0].head, "b")
  assert_eq(last_segments[0].weight, 6)
}
