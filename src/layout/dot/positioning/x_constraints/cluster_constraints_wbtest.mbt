///|
fn require_cluster_constraint_edge(
  edges : Array[ConstraintEdge],
  tail : String,
  head : String,
) -> ConstraintEdge raise {
  for edge in edges {
    if edge.tail == tail && edge.head == head {
      return edge
    }
  }
  fail("missing constraint edge \{tail}->\{head}")
}

///|
test "build_cluster_constraints adds boundary nodes containment and keepout edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let a = cluster.node("a")
  let b = cluster.node("b")
  let c = graph.node("c")

  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 0 }
  let groups : Map[Int, Array[String]] = { 0: ["c", "a", "b"] }
  let sizes : Map[String, @node_primitives.NodeSize] = {
    "a": @node_primitives.vnode_size_from_widths_with_h(2.0, 3.0, 8.0),
    "b": @node_primitives.vnode_size_from_widths_with_h(4.0, 5.0, 8.0),
    "c": @node_primitives.vnode_size_from_widths_with_h(6.0, 7.0, 8.0),
  }
  let cluster_keys : Map[String, String] = {
    "a": "cluster_0",
    "b": "cluster_0",
  }

  let build = build_cluster_constraints(
    graph,
    [a, b, c],
    [],
    ranks,
    [0],
    groups,
    sizes,
    cluster_keys,
    10.0,
    false,
    Map::new(),
  )

  let left_name = @cluster_identity.cluster_left_boundary_name("cluster_0")
  let right_name = @cluster_identity.cluster_right_boundary_name("cluster_0")
  let extra_node_ranks : Map[String, Int] = Map::new()
  for extra_node in build.extra_nodes {
    extra_node_ranks[extra_node.name] = extra_node.rank
  }

  assert_eq(build.root_ln_targets, [left_name])
  assert_eq(build.root_rn_targets, [right_name])
  assert_eq(extra_node_ranks.get(left_name), Some(9))
  assert_eq(extra_node_ranks.get(right_name), Some(49))
  assert_eq(build.extra_edges.length(), 4)

  let compact = require_cluster_constraint_edge(
    build.extra_edges,
    left_name,
    right_name,
  )
  assert_eq(compact.minlen, 1)
  assert_eq(compact.weight, 128)

  let contain_left = require_cluster_constraint_edge(
    build.extra_edges,
    left_name,
    "a",
  )
  assert_eq(contain_left.minlen, 10)
  assert_eq(contain_left.weight, 0)

  let contain_right = require_cluster_constraint_edge(
    build.extra_edges,
    "b",
    right_name,
  )
  assert_eq(contain_right.minlen, 13)
  assert_eq(contain_right.weight, 0)

  let keepout_left = require_cluster_constraint_edge(
    build.extra_edges,
    "c",
    left_name,
  )
  assert_eq(keepout_left.minlen, 15)
  assert_eq(keepout_left.weight, 0)
}
