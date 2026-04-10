// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn new_test_graph(
  names : Array[String],
) -> (@cgraph.Graph, Map[String, @cgraph.Node]) {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node_map : Map[String, @cgraph.Node] = Map::new()
  for name in names {
    node_map[name] = graph.node(name)
  }
  (graph, node_map)
}

///|
test "edge_endpoints_at prefers override arrays and falls back to edge names" {
  let (graph, node_map) = new_test_graph(["a", "b"])
  let a = match node_map.get("a") {
    Some(value) => value
    None => abort("missing node a")
  }
  let b = match node_map.get("b") {
    Some(value) => value
    None => abort("missing node b")
  }
  let edge = graph.edge(a, b)

  assert_eq(edge_endpoints_at(edge, 0, ["x"], ["y"]), ("x", "y"))
  assert_eq(edge_endpoints_at(edge, 1, ["x"], ["y"]), ("a", "b"))
}

///|
test "build_edge_index_for_names ignores same-rank edges" {
  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 1
  ranks["c"] = 1

  let edge_index = build_edge_index_for_names(
    ["a", "b", "c"],
    ["a", "b", "c"],
    ["b", "c", "a"],
    ranks,
  )

  assert_eq(edge_index.parents.get("a"), Some(["c"]))
  assert_eq(edge_index.parents.get("b"), Some(["a"]))
  assert_eq(edge_index.parents.get("c"), Some([]))
  assert_eq(edge_index.children.get("a"), Some(["b"]))
  assert_eq(edge_index.children.get("b"), Some([]))
  assert_eq(edge_index.children.get("c"), Some(["a"]))
}

///|
test "add_order_edge appends one directed order edge with metadata" {
  let (graph, node_map) = new_test_graph(["a", "b"])
  let edges : Array[@cgraph.Edge] = []
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_tail_port_x : Array[Double] = []
  let edge_head_port_x : Array[Double] = []
  let edge_tail_port_order : Array[Double] = []
  let edge_head_port_order : Array[Double] = []

  add_order_edge(
    graph, node_map, edges, edge_tail, edge_head, edge_tail_port_x, edge_head_port_x,
    edge_tail_port_order, edge_head_port_order, "a", "a", 7, true, 1.0, 2.0, 0.1,
    0.9,
  )
  add_order_edge(
    graph, node_map, edges, edge_tail, edge_head, edge_tail_port_x, edge_head_port_x,
    edge_tail_port_order, edge_head_port_order, "missing", "b", 7, true, 1.0, 2.0,
    0.1, 0.9,
  )
  add_order_edge(
    graph, node_map, edges, edge_tail, edge_head, edge_tail_port_x, edge_head_port_x,
    edge_tail_port_order, edge_head_port_order, "a", "b", 7, false, 1.0, 2.0, 0.1,
    0.9,
  )

  assert_eq(edges.length(), 1)
  assert_eq(edge_tail, ["a"])
  assert_eq(edge_head, ["b"])
  assert_eq(edge_tail_port_x, [1.0])
  assert_eq(edge_head_port_x, [2.0])
  assert_eq(edge_tail_port_order, [0.1])
  assert_eq(edge_head_port_order, [0.9])
  assert_eq(edges[0].get_attr("xpenalty"), Some("7"))
  assert_eq(edges[0].get_attr("constraint"), Some("false"))
}

///|
test "build_order_edges_by_tail expands vnode chains into segment edges" {
  let (graph, node_map) = new_test_graph(["a", "b"])
  let a = match node_map.get("a") {
    Some(value) => value
    None => abort("missing node a")
  }
  let b = match node_map.get("b") {
    Some(value) => value
    None => abort("missing node b")
  }
  let edge = graph.edge(a, b)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = ["v1", "v2"]

  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  edges_by_tail["a"] = [0]

  let output = build_order_edges_by_tail(
    ["a"],
    [edge],
    ["a"],
    ["b"],
    [1.0],
    [3.0],
    [0.2],
    [0.8],
    ranks,
    edge_vnodes,
    true,
    Map::new(),
    false,
    false,
    false,
    edges_by_tail,
  )

  assert_eq(output.vnode_creation_by_tail.get("a"), Some(["v1", "v2"]))
  assert_eq(output.edge_creation_order, [("a", "v1"), ("v1", "v2"), ("v2", "b")])
  assert_eq(
    output.order_edges_by_tail.get("a"),
    Some([("a", "v1", 1, true, 1.0, 0.5, 0.2, 0.0)]),
  )
  assert_eq(
    output.order_edges_by_tail.get("v1"),
    Some([("v1", "v2", 1, true, 0.5, 0.5, 0.0, 0.0)]),
  )
  assert_eq(
    output.order_edges_by_tail.get("v2"),
    Some([("v2", "b", 1, true, 0.5, 3.0, 0.0, 0.8)]),
  )
}

///|
test "build_order_edges_by_tail maps intercluster edges to cluster skeletons" {
  let (graph, node_map) = new_test_graph(["a", "b"])
  let a = match node_map.get("a") {
    Some(value) => value
    None => abort("missing node a")
  }
  let b = match node_map.get("b") {
    Some(value) => value
    None => abort("missing node b")
  }
  let edge = graph.edge(a, b)
  edge.set_attr("xpenalty", "5")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 1

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "left"
  cluster_keys["b"] = "right"

  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  edges_by_tail["a"] = [0]

  let output = build_order_edges_by_tail(
    ["a"],
    [edge],
    ["a"],
    ["b"],
    [],
    [],
    [],
    [],
    ranks,
    Map::new(),
    false,
    cluster_keys,
    true,
    false,
    true,
    edges_by_tail,
  )

  let tail_skeleton = @cluster_identity.cluster_skeleton_name("left", 0)
  let head_skeleton = @cluster_identity.cluster_skeleton_name("right", 1)
  assert_eq(output.edge_creation_order, [(tail_skeleton, head_skeleton)])
  assert_eq(
    output.order_edges_by_tail.get(tail_skeleton),
    Some([(tail_skeleton, head_skeleton, 5, true, 0.5, 0.5, 0.0, 0.0)]),
  )
}

///|
test "build_edge_index_with_vnodes chains through vnodes in rank order" {
  let (graph, node_map) = new_test_graph(["high", "low"])
  let high = match node_map.get("high") {
    Some(value) => value
    None => abort("missing node high")
  }
  let low = match node_map.get("low") {
    Some(value) => value
    None => abort("missing node low")
  }
  let edge = graph.edge(high, low)

  let ranks : Map[String, Int] = Map::new()
  ranks["high"] = 3
  ranks["low"] = 0

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = ["v1", "v2"]

  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v1"] = 1
  vnode_ranks["v2"] = 2

  let edge_index = build_edge_index_with_vnodes(
    [high, low],
    [edge],
    ["high"],
    ["low"],
    ranks,
    edge_vnodes,
    vnode_ranks,
  )

  assert_eq(edge_index.parents.get("v1"), Some(["low"]))
  assert_eq(edge_index.parents.get("v2"), Some(["v1"]))
  assert_eq(edge_index.parents.get("high"), Some(["v2"]))
  assert_eq(edge_index.children.get("low"), Some(["v1"]))
  assert_eq(edge_index.children.get("v1"), Some(["v2"]))
  assert_eq(edge_index.children.get("v2"), Some(["high"]))
}
