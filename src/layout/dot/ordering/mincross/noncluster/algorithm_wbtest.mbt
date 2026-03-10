///|
test "build_noncluster_order_node_order seeds from nlist order and only backfills missing names" {
  let node_order : Map[String, Int] = Map::new()
  node_order["a"] = 9
  node_order["c"] = 7

  let order = build_noncluster_order_node_order(["b", "a"], node_order)

  assert_eq(order.get("b"), Some(0))
  assert_eq(order.get("a"), Some(1))
  assert_eq(order.get("c"), Some(7))
}

///|
test "build_noncluster_graphviz_neighbors follows edge out order and node iteration for in-neighbors" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let d = graph.node("d")
  let ab = graph.edge(a, b)
  let ac = graph.edge(a, c)
  let dc = graph.edge(d, c)
  let bc = graph.edge(b, c)

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [1, 0]
  edge_out_order["b"] = [3]
  edge_out_order["d"] = [2]

  let neighbors = build_noncluster_graphviz_neighbors(
    [a, b, c, d],
    [ab, ac, dc, bc],
    ["b", "c"],
    edge_out_order,
  )

  let out_a = match neighbors.out_neighbors.get("a") {
    Some(value) => value
    None => fail("missing out-neighbors for a")
  }
  let out_c = match neighbors.out_neighbors.get("c") {
    Some(value) => value
    None => fail("missing out-neighbors for c")
  }
  let in_b = match neighbors.in_neighbors.get("b") {
    Some(value) => value
    None => fail("missing in-neighbors for b")
  }
  let in_c = match neighbors.in_neighbors.get("c") {
    Some(value) => value
    None => fail("missing in-neighbors for c")
  }
  let in_a = match neighbors.in_neighbors.get("a") {
    Some(value) => value
    None => fail("missing in-neighbors for a")
  }

  assert_eq(out_a, ["c", "b"])
  assert_eq(out_c, [])
  assert_eq(in_b, ["a"])
  assert_eq(in_c, ["a", "b", "d"])
  assert_eq(in_a, [])
}

///|
test "build_noncluster_graphviz_neighbors preserves parallel edges and ignores tails omitted from edge_out_order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let d = graph.node("d")
  let ac1 = graph.edge(a, c)
  let ac2 = graph.edge(a, c)
  let bc = graph.edge(b, c)
  let da = graph.edge(d, a)

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [1, 0]
  edge_out_order["b"] = [2]

  let neighbors = build_noncluster_graphviz_neighbors(
    [a, b, c, d],
    [ac1, ac2, bc, da],
    ["c"],
    edge_out_order,
  )

  assert_eq(neighbors.out_neighbors.get("a"), Some(["c", "c"]))
  assert_eq(neighbors.out_neighbors.get("b"), Some(["c"]))
  assert_eq(neighbors.out_neighbors.get("d"), Some([]))
  assert_eq(neighbors.in_neighbors.get("c"), Some(["a", "a", "b"]))
  assert_eq(neighbors.in_neighbors.get("a"), Some([]))
}

///|
test "build_noncluster_graphviz_neighbors trusts in-range edge_head snapshots and only falls back to live edge heads out of range" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let ab = graph.edge(a, b)
  let ac = graph.edge(a, c)

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [0, 1]

  let neighbors = build_noncluster_graphviz_neighbors(
    [a, b, c],
    [ab, ac],
    ["shadow_head"],
    edge_out_order,
  )

  assert_eq(neighbors.out_neighbors.get("a"), Some(["shadow_head", "c"]))
  assert_eq(neighbors.in_neighbors.get("shadow_head"), Some(["a"]))
  assert_eq(neighbors.in_neighbors.get("c"), Some(["a"]))
  assert_eq(neighbors.in_neighbors.get("b"), Some([]))
}
