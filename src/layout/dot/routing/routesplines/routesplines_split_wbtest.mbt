///|
fn split_test_vnode_size() -> NodeSize {
  @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0)
}

///|
fn split_test_node_size() -> NodeSize {
  @node_primitives.node_size_from_points(10.0, 10.0)
}

///|
test "edge_pathplan_polyline final split segment starts recover chain at segfirst head" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)

  let vnodes = ["v1", "v2", "v3", "v4", "v5", "v6"]
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = vnodes

  let ranks : Map[String, Int] = { "tail": 0, "head": 7 }
  let vnode_ranks : Map[String, Int] = {
    "v1": 1,
    "v2": 2,
    "v3": 3,
    "v4": 4,
    "v5": 5,
    "v6": 6,
  }
  let rank_y : Map[Int, Double] = {
    0: 700.0,
    1: 600.0,
    2: 500.0,
    3: 400.0,
    4: 300.0,
    5: 200.0,
    6: 100.0,
    7: 0.0,
  }
  let rank_ht1 : Map[Int, Double] = {
    0: 5.0,
    1: 5.0,
    2: 5.0,
    3: 5.0,
    4: 5.0,
    5: 5.0,
    6: 5.0,
    7: 5.0,
  }
  let rank_ht2 = rank_ht1
  let merged_positions : Map[String, @geom.Point] = {
    "tail": { x: 0.0, y: 700.0 },
    "v1": { x: 0.0, y: 600.0 },
    "v2": { x: 0.0, y: 500.0 },
    "v3": { x: 0.0, y: 400.0 },
    "v4": { x: 0.0, y: 300.0 },
    "v5": { x: 0.0, y: 200.0 },
    "v6": { x: 0.0, y: 100.0 },
    "head": { x: 0.0, y: 0.0 },
  }
  let route_sizes : Map[String, NodeSize] = {
    "tail": split_test_node_size(),
    "head": split_test_node_size(),
    "v1": split_test_vnode_size(),
    "v2": split_test_vnode_size(),
    "v3": split_test_vnode_size(),
    "v4": split_test_vnode_size(),
    "v5": split_test_vnode_size(),
    "v6": split_test_vnode_size(),
  }
  let mval_route_sizes = route_sizes
  let vnode_sizes : Map[String, NodeSize] = {
    "v1": split_test_vnode_size(),
    "v2": split_test_vnode_size(),
    "v3": split_test_vnode_size(),
    "v4": split_test_vnode_size(),
    "v5": split_test_vnode_size(),
    "v6": split_test_vnode_size(),
  }
  let x_groups : Map[Int, Array[String]] = {
    0: ["tail"],
    1: ["v1"],
    2: ["v2"],
    3: ["v3"],
    4: ["v4"],
    5: ["v5"],
    6: ["v6"],
    7: ["head"],
  }
  let order_index : Map[String, Int] = {
    "tail": 0,
    "v1": 0,
    "v2": 0,
    "v3": 0,
    "v4": 0,
    "v5": 0,
    "v6": 0,
    "head": 0,
  }
  let adjacency = build_path_adjacency([edge], edge_vnodes, [], [])

  let result = match
    edge_pathplan_polyline(
      edge,
      "tail",
      "head",
      { x: 0.0, y: 700.0 },
      { x: 0.0, y: 0.0 },
      RankDir::TB,
      0,
      0,
      None,
      None,
      72.0,
      ranks,
      vnode_ranks,
      edge_vnodes,
      merged_positions,
      route_sizes,
      mval_route_sizes,
      vnode_sizes,
      Map::new(),
      Map::new(),
      Map::new(),
      x_groups,
      order_index,
      adjacency.out_edges,
      adjacency.in_edges,
      rank_y,
      rank_ht1,
      rank_ht2,
      72.0,
      -50.0,
      50.0,
      false,
    ) {
    Some(value) => value
    None => fail("expected split pathplan result")
  }

  assert_eq(result.segments.length(), 2)
  assert_eq(result.segments[0].vnodes, ["v1", "v2", "v3", "v4", "v5"])
  assert_eq(result.segments[1].vnodes, ["v6"])
}
