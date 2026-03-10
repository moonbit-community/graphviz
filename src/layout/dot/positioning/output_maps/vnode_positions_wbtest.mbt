///|
test "vnode_positions_from_edges interpolates vnode x by rank span" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 4

  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v1"] = 1
  vnode_ranks["v2"] = 3

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = ["v1", "v2"]

  let node_positions : Map[String, Double] = Map::new()
  node_positions["a"] = 10.0
  node_positions["b"] = 30.0

  let rank_y : Map[Int, Double] = Map::new()
  rank_y[1] = 100.0
  rank_y[3] = 300.0

  let positions = vnode_positions_from_edges(
    [edge],
    ranks,
    vnode_ranks,
    edge_vnodes,
    node_positions,
    rank_y,
  )

  assert_eq(positions.get("v1"), Some({ x: 15.0, y: 100.0 }))
  assert_eq(positions.get("v2"), Some({ x: 25.0, y: 300.0 }))
}

///|
test "build_vnode_positions uses direct xpos ranks or fallback interpolation" {
  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v1"] = 1
  let x_positions : Map[String, Double] = Map::new()
  x_positions["v1"] = 42.0
  let rank_y : Map[Int, Double] = Map::new()
  rank_y[1] = 18.0

  let fallback_calls = Ref::new(0)
  let direct = build_vnode_positions({
    use_vnodes_for_xpos: true,
    vnode_ranks,
    x_positions,
    rank_y,
    fallback_fn: () => {
      fallback_calls.val = fallback_calls.val + 1
      { "fallback": { x: 1.0, y: 2.0 } }
    },
  })

  let fallback = build_vnode_positions({
    use_vnodes_for_xpos: false,
    vnode_ranks,
    x_positions,
    rank_y,
    fallback_fn: () => {
      fallback_calls.val = fallback_calls.val + 1
      { "fallback": { x: 1.0, y: 2.0 } }
    },
  })

  assert_eq(fallback_calls.val, 1)
  assert_eq(direct.get("v1"), Some({ x: 42.0, y: 18.0 }))
  assert_eq(fallback.get("fallback"), Some({ x: 1.0, y: 2.0 }))
}
