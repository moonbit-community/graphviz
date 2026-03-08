///|
fn sample_endpoint_value(
  name : String,
  port : @cgraph.Port?,
  base : Double,
) -> Double {
  let name_value = match name {
    "a" => 10.0
    "b" => 20.0
    "c" => 30.0
    _ => 0.0
  }
  let port_value = match port {
    Some(value) => {
      let name_part = match value.name {
        Some(port_name) =>
          match port_name {
            "p" => 1.0
            "q" => 2.0
            "r" => 3.0
            _ => 0.0
          }
        None => 0.0
      }
      let compass_part = match value.compass {
        Some(@cgraph.Compass::E) => 0.1
        Some(@cgraph.Compass::W) => 0.2
        Some(@cgraph.Compass::S) => 0.3
        _ => 0.0
      }
      name_part + compass_part
    }
    None => 0.0
  }
  base + name_value + port_value
}

///|
fn empty_cluster_meta() -> DotClusterMetadata {
  {
    has_clusters: false,
    cluster_keys: Map::new(),
    cluster_skeleton: Map::new(),
    cluster_min_rank: Map::new(),
    cluster_max_rank: Map::new(),
    cluster_order: [],
    cluster_parents: Map::new(),
    intercluster_keys: Map::new(),
    rank_same_groups: Map::new(),
    rank_same_order: Map::new(),
    flat_constraints: Map::new(),
    ordering_set: false,
  }
}

///|
fn require_array(
  map : Map[String, Array[String]],
  key : String,
) -> Array[String] raise {
  match map.get(key) {
    Some(value) => value
    None => fail("missing array for \{key}")
  }
}

///|
fn require_int(map : Map[String, Int], key : String) -> Int raise {
  match map.get(key) {
    Some(value) => value
    None => fail("missing int for \{key}")
  }
}

///|
test "build_edge_port_sample_bundle follows oriented endpoints and port remapping" {
  let graph = @dot_parser.parse_dot("digraph { a:p:e -> b:q:w; b:r:s -> c; }")
  let edges = graph.edges()
  let bundle = @ordering.build_edge_port_sample_bundle(
    edges,
    ["a", "c"],
    ["b", "b"],
    (name, port) => sample_endpoint_value(name, port, 0.0),
    (name, port) => sample_endpoint_value(name, port, 100.0),
  )

  assert_eq(bundle.tail_port_x, [11.1, 30.0])
  assert_eq(bundle.head_port_x, [22.2, 23.3])
  assert_eq(bundle.tail_port_order, [111.1, 130.0])
  assert_eq(bundle.head_port_order, [122.2, 123.3])
}

///|
test "build_edge_port_sample_bundle returns empty arrays when there are no edges" {
  let bundle = @ordering.build_edge_port_sample_bundle(
    [],
    [],
    [],
    (name, _port) => name.length().to_double(),
    (_name, _port) => 0.0,
  )

  assert_eq(bundle.tail_port_x, [])
  assert_eq(bundle.head_port_x, [])
  assert_eq(bundle.tail_port_order, [])
  assert_eq(bundle.head_port_order, [])
}

///|
test "build_local_cluster_order sorts by min rank then first order then cluster name" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let d = graph.node("d")
  let e = graph.node("e")
  let nodes = [a, b, c, d, e]

  let local_cluster_keys : Map[String, String] = {
    "a": "cluster_b",
    "b": "cluster_a",
    "c": "cluster_b",
    "d": "cluster_c",
    "e": "cluster_a",
  }
  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 2, "d": 1, "e": 3 }
  let node_order : Map[String, Int] = { "a": 0, "b": 0, "c": 4, "d": 0, "e": 5 }

  let order = build_local_cluster_order(
    nodes, local_cluster_keys, ranks, node_order,
  )

  assert_eq(order.get("cluster_a"), Some(0))
  assert_eq(order.get("cluster_b"), Some(1))
  assert_eq(order.get("cluster_c"), Some(2))
}

///|
test "build_vnode_tail_constraints groups same-tail vnodes by edge index order" {
  let rank_vnodes : Map[Int, Array[String]] = {
    1: [
      "\{@edge_identity.EDGE_VNODE_PREFIX}2_1",
      "other",
      "\{@edge_identity.EDGE_VNODE_PREFIX}0_1",
      "\{@edge_identity.EDGE_VNODE_PREFIX}1_1",
    ],
  }

  let constraints = build_vnode_tail_constraints(rank_vnodes, ["a", "b", "a"])

  assert_eq(constraints.length(), 1)
  assert_eq(
    constraints.get(
      "\{@edge_identity.EDGE_VNODE_PREFIX}0_1|\{@edge_identity.EDGE_VNODE_PREFIX}2_1",
    ),
    Some(true),
  )
}

///|
test "build_ordering_runtime_context_from_sources seeds runtime maps and vnode info" {
  let graph = @dot_parser.parse_dot("digraph { a:p:e -> c:q:w }")
  let a = graph.node("a")
  let c = graph.node("c")
  let edges = graph.edges()
  let ranks : Map[String, Int] = { "a": 0, "c": 2 }
  let node_order : Map[String, Int] = { "a": 0, "c": 1 }
  let edge_out_order : Map[String, Array[Int]] = { "a": [0] }

  let runtime_context = build_ordering_runtime_context_from_sources({
    graph,
    nodes: [a, c],
    edges,
    edge_tail: ["a"],
    edge_head: ["c"],
    edge_out_order,
    ranks,
    node_order,
    nodesep_pt: 20.0,
    rankdir: @rankdir.RankDir::TB,
    cluster_meta: empty_cluster_meta(),
  })

  assert_eq(runtime_context.real_nodes.get("a"), Some(true))
  assert_eq(runtime_context.real_nodes.get("c"), Some(true))
  assert_eq(runtime_context.edge_cluster_keys.length(), 0)
  assert_eq(runtime_context.port_edge_nodes.get("a"), Some(true))
  assert_eq(runtime_context.port_edge_nodes.get("c"), Some(true))
  assert_eq(runtime_context.local_cluster_order.length(), 0)
  assert_eq(runtime_context.rank_same_constraints.length(), 0)

  let edge_key = @edge_identity.edge_vnode_key(edges[0])
  let chain = require_array(runtime_context.vnode_info.edge_vnodes, edge_key)
  assert_eq(chain.length(), 1)
  assert_eq(require_int(runtime_context.vnode_info.vnode_ranks, chain[0]), 1)
  assert_eq(runtime_context.vnode_info.vnodes_by_rank.get(1), Some(chain))
}
