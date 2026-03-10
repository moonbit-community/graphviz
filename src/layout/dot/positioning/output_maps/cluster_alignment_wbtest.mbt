///|
test "build_cluster_boundary_x collects left and right boundary nodes" {
  let cluster_names : Map[String, Bool] = Map::new()
  cluster_names["cluster0"] = true

  let x_positions : Map[String, Double] = Map::new()
  x_positions[@cluster_identity.cluster_left_boundary_name("cluster0")] = 12.0
  x_positions[@cluster_identity.cluster_right_boundary_name("cluster0")] = 48.0
  x_positions["plain"] = 99.0

  let output = build_cluster_boundary_x({
    has_clusters: true,
    x_positions,
    is_cluster_boundary: name => {
      @cluster_identity.is_cluster_boundary_name(name)
    },
    boundary_cluster_key: name => {
      @cluster_identity.cluster_key_from_boundary(name, cluster_names)
    },
    is_left_boundary: name => {
      @cluster_identity.is_cluster_left_boundary_name(name)
    },
  })

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

  adjust_intercluster_alignment({
    nodes: [a, b, target],
    edges: [a_to_target, b_to_target],
    ranks,
    x_positions,
    cluster_keys,
    intercluster_keys,
    nodesep_pt: 12.0,
    has_edge_labels: false,
  })

  assert_eq(x_positions.get("a"), Some(88.0))
  assert_eq(x_positions.get("b"), Some(108.0))
  assert_eq(x_positions.get("target"), Some(100.0))
}

///|
test "adjust_intercluster_alignment keeps positions when a cluster-rank group fans out to multiple targets" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let left_target = graph.node("left_target")
  let right_target = graph.node("right_target")
  let a_to_left = graph.edge(a, left_target)
  let b_to_right = graph.edge(b, right_target)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["left_target"] = 1
  ranks["right_target"] = 1

  let x_positions : Map[String, Double] = Map::new()
  x_positions["a"] = 100.0
  x_positions["b"] = 120.0
  x_positions["left_target"] = 100.0
  x_positions["right_target"] = 120.0

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster0"
  intercluster_keys["b"] = "cluster0"
  intercluster_keys["left_target"] = "cluster1"
  intercluster_keys["right_target"] = "cluster2"

  adjust_intercluster_alignment({
    nodes: [a, b, left_target, right_target],
    edges: [a_to_left, b_to_right],
    ranks,
    x_positions,
    cluster_keys,
    intercluster_keys,
    nodesep_pt: 12.0,
    has_edge_labels: false,
  })

  assert_eq(x_positions.get("a"), Some(100.0))
  assert_eq(x_positions.get("b"), Some(120.0))
}

///|
test "adjust_intercluster_alignment keeps positions when no node is already aligned to the shared target" {
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
  x_positions["a"] = 90.0
  x_positions["b"] = 110.0
  x_positions["target"] = 100.0

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster0"
  intercluster_keys["b"] = "cluster0"
  intercluster_keys["target"] = "cluster1"

  adjust_intercluster_alignment({
    nodes: [a, b, target],
    edges: [a_to_target, b_to_target],
    ranks,
    x_positions,
    cluster_keys,
    intercluster_keys,
    nodesep_pt: 12.0,
    has_edge_labels: false,
  })

  assert_eq(x_positions.get("a"), Some(90.0))
  assert_eq(x_positions.get("b"), Some(110.0))
  assert_eq(x_positions.get("target"), Some(100.0))
}

///|
test "adjust_intercluster_alignment uses inclusive epsilon and odd-rank label spacing" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let target = graph.node("target")
  let a_to_target = graph.edge(a, target)
  let b_to_target = graph.edge(b, target)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 1
  ranks["b"] = 1
  ranks["target"] = 2

  let x_positions : Map[String, Double] = Map::new()
  x_positions["a"] = 100.009
  x_positions["b"] = 120.0
  x_positions["target"] = 100.0

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster0"
  intercluster_keys["b"] = "cluster0"
  intercluster_keys["target"] = "cluster1"

  adjust_intercluster_alignment({
    nodes: [a, b, target],
    edges: [a_to_target, b_to_target],
    ranks,
    x_positions,
    cluster_keys,
    intercluster_keys,
    nodesep_pt: 12.0,
    has_edge_labels: true,
  })

  assert_eq(x_positions.get("a"), Some(95.009))
  assert_eq(x_positions.get("b"), Some(115.0))
  assert_eq(x_positions.get("target"), Some(100.0))
}
