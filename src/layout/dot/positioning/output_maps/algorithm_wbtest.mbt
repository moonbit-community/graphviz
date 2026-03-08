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

  let positions =
    vnode_positions_from_edges(
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
test "build_cluster_boundary_x collects left and right boundary nodes" {
  let cluster_names : Map[String, Bool] = Map::new()
  cluster_names["cluster0"] = true

  let x_positions : Map[String, Double] = Map::new()
  x_positions[@cluster_identity.cluster_left_boundary_name("cluster0")] = 12.0
  x_positions[@cluster_identity.cluster_right_boundary_name("cluster0")] = 48.0
  x_positions["plain"] = 99.0

  let output =
    build_cluster_boundary_x(
      {
        has_clusters: true,
        x_positions,
        is_cluster_boundary: (name) => @cluster_identity.is_cluster_boundary_name(name),
        boundary_cluster_key:
          (name) => @cluster_identity.cluster_key_from_boundary(name, cluster_names),
        is_left_boundary: (name) => @cluster_identity.is_cluster_left_boundary_name(name),
      },
    )

  assert_eq(output.cluster_ln_x.get("cluster0"), Some(12.0))
  assert_eq(output.cluster_rn_x.get("cluster0"), Some(48.0))
  assert_eq(output.cluster_ln_x.length(), 1)
  assert_eq(output.cluster_rn_x.length(), 1)
}

///|
test "adjust_intercluster_alignment shifts one cluster-rank group toward its shared target" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let target = graph.node("target")
  let a_to_target = graph.edge(a, target)
  let b_to_target = graph.edge(b, target)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["target"] = 1

  let x_positions : Map[String, Double] = Map::new()
  x_positions["a"] = 100.0
  x_positions["b"] = 120.0
  x_positions["target"] = 100.0

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster0"
  intercluster_keys["b"] = "cluster0"
  intercluster_keys["target"] = "cluster1"

  adjust_intercluster_alignment(
    {
      nodes: [a, b, target],
      edges: [a_to_target, b_to_target],
      ranks,
      x_positions,
      cluster_keys,
      intercluster_keys,
      nodesep_pt: 12.0,
      has_edge_labels: false,
    },
  )

  assert_eq(x_positions.get("a"), Some(88.0))
  assert_eq(x_positions.get("b"), Some(108.0))
  assert_eq(x_positions.get("target"), Some(100.0))
}

///|
test "output map env gates read the expected variables" {
  let align_key = "DOT_INTERCLUSTER_ALIGN"
  let rounding_key = "DOT_ADJUST_CLUSTER_ROUNDING"
  let original_align = @sys.get_env_var(align_key)
  let original_rounding = @sys.get_env_var(rounding_key)

  @sys.unset_env_var(align_key)
  @sys.unset_env_var(rounding_key)
  let defaults = (intercluster_alignment_enabled(), cluster_rounding_enabled())

  @sys.set_env_var(align_key, "1")
  @sys.set_env_var(rounding_key, "1")
  let enabled = (intercluster_alignment_enabled(), cluster_rounding_enabled())

  @sys.set_env_var(align_key, "0")
  @sys.set_env_var(rounding_key, "")
  let disabled = (intercluster_alignment_enabled(), cluster_rounding_enabled())

  match original_align {
    Some(value) => @sys.set_env_var(align_key, value)
    None => @sys.unset_env_var(align_key)
  }
  match original_rounding {
    Some(value) => @sys.set_env_var(rounding_key, value)
    None => @sys.unset_env_var(rounding_key)
  }

  assert_eq(defaults, (false, false))
  assert_eq(enabled, (true, true))
  assert_eq(disabled, (false, false))
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

///|
test "build_node_positions_map defaults missing coordinates to zero" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")

  let x_positions : Map[String, Double] = Map::new()
  x_positions["a"] = 10.0
  let y_positions : Map[String, Double] = Map::new()
  y_positions["b"] = 20.0

  let positions = build_node_positions_map([a, b], x_positions, y_positions)

  assert_eq(positions.get("a"), Some({ x: 10.0, y: 0.0 }))
  assert_eq(positions.get("b"), Some({ x: 0.0, y: 20.0 }))
}
