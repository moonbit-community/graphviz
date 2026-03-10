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
