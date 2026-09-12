// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "single-node clusters still participate in expansion" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster_graph = root.subgraph(name="cluster_single")
  ignore(cluster_graph.node("only"))
  guard build_cluster_local_reorder_context({
      cluster: "cluster_single",
      cluster_graph,
      groups: { 2: ["outside", "only"] },
      node_order: { "outside": 0, "only": 1 },
      source_out_neighbors: Map([]),
      vnode_clusters: Map([]),
      fixed_positions: { "outside": 0.0, "only": 1.0 },
      order_with_vnodes: true,
    })
    is Some(context) else {
    @test.fail("missing single-node expansion")
  }
  @test.assert_eq(context.cluster_rank_keys, [2])
  @test.assert_eq(context.cluster_groups.get(2), Some(["only"]))
}

///|
test "external anchors share the extracted cluster rank coordinate system" {
  let anchors = build_cluster_fixed_positions(
    { "left": 0.0, "a": 1.0, "b": 2.0, "right": 3.0, "above": 4.0 },
    { "a": true, "b": true },
    { 0: ["above"], 1: ["left", "a", "b", "right"] },
  )
  @test.assert_eq(anchors.get("left"), Some(-1.0))
  @test.assert_eq(anchors.get("right"), Some(2.0))
  @test.assert_eq(anchors.get("above"), Some(4.0))
  @test.assert_eq(anchors.get("a"), None)
}

///|
test "expanded rank offsets exclude removed skeleton placeholders" {
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_local", 0)
  let anchors = build_cluster_fixed_positions(
    {
      "left": 0.0,
      "_mbt_cluster_skel_cluster_local@0": 1.0,
      "a": 2.0,
      "b": 3.0,
      "right": 4.0,
    },
    { "a": true, "b": true },
    { 0: ["left", skeleton, "a", "b", "right"] },
  )
  @test.assert_eq(anchors.get("left"), Some(-1.0))
  @test.assert_eq(anchors.get("right"), Some(2.0))
}

///|
test "build_cluster_local_reorder_context keeps cluster members plus local vnodes, seeds later ranks from previous-rank reachability, and excludes local fixed slots" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster_graph = root.subgraph(name="cluster_a")
  ignore(cluster_graph.node("a"))
  ignore(cluster_graph.node("b"))
  ignore(cluster_graph.node("c"))
  ignore(cluster_graph.node("d"))
  ignore(root.node("outside"))

  let groups : Map[Int, Array[String]] = Map([])
  groups[0] = ["b", "outside", "a"]
  groups[1] = ["d", "\{@edge_identity.EDGE_VNODE_PREFIX}0", "c", "outside"]

  let node_order : Map[String, Int] = Map([])
  node_order["a"] = 0
  node_order["b"] = 1
  node_order["c"] = 2
  node_order["d"] = 3
  node_order["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = 4
  node_order["outside"] = 5

  let source_out_neighbors : Map[String, Array[String]] = Map([])
  source_out_neighbors["a"] = ["d"]
  source_out_neighbors["b"] = ["c"]

  let vnode_clusters : Map[String, String] = Map([])
  vnode_clusters["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = "cluster_a"

  let fixed_positions : Map[String, Double] = Map([])
  fixed_positions["a"] = 0.0
  fixed_positions["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = 1.0
  fixed_positions["outside"] = 2.0

  let context = match
    build_cluster_local_reorder_context({
      cluster: "cluster_a",
      cluster_graph,
      groups,
      node_order,
      source_out_neighbors,
      vnode_clusters,
      fixed_positions,
      order_with_vnodes: true,
    }) {
    Some(value) => value
    None => fail("expected cluster local context")
  }

  assert_eq(context.cluster_node_set.get("a"), Some(true))
  assert_eq(context.cluster_node_set.get("b"), Some(true))
  assert_eq(context.cluster_node_set.get("c"), Some(true))
  assert_eq(context.cluster_node_set.get("d"), Some(true))
  assert_eq(
    context.cluster_node_set.get("\{@edge_identity.EDGE_VNODE_PREFIX}0"),
    Some(true),
  )
  assert_eq(context.cluster_node_set.get("outside"), None)
  assert_eq(context.cluster_node_order.get("a"), Some(0))
  assert_eq(context.cluster_node_order.get("b"), Some(1))
  assert_eq(context.cluster_node_order.get("c"), Some(2))
  assert_eq(context.cluster_node_order.get("d"), Some(3))
  assert_eq(
    context.cluster_node_order.get("\{@edge_identity.EDGE_VNODE_PREFIX}0"),
    Some(4),
  )
  assert_eq(context.cluster_groups.get(0), Some(["a", "b"]))
  assert_eq(
    context.cluster_groups.get(1),
    Some(["d", "\{@edge_identity.EDGE_VNODE_PREFIX}0", "c"]),
  )
  assert_eq(context.cluster_rank_keys, [0, 1])
  assert_eq(context.cluster_fixed_positions.length(), 1)
  assert_eq(context.cluster_fixed_positions.get("outside"), Some(2.0))
}

///|
test "apply_cluster_rank_reorder_output installs contiguous blocks and preserves outside order" {
  let groups : Map[Int, Array[String]] = Map([])
  groups[0] = ["left", "a", "middle", "b", "right"]
  groups[1] = ["keep", "c"]

  let ordered_cluster : Map[Int, Array[String]] = Map([])
  ordered_cluster[0] = ["b", "a"]
  ordered_cluster[1] = ["c"]

  let cluster_node_set : Map[String, Bool] = Map([])
  cluster_node_set["a"] = true
  cluster_node_set["b"] = true
  cluster_node_set["c"] = true

  apply_cluster_rank_reorder_output(
    groups,
    [0, 1],
    ordered_cluster,
    cluster_node_set,
  )

  @test.assert_eq(groups.get(0), Some(["left", "b", "a", "middle", "right"]))
  @test.assert_eq(groups.get(1), Some(["keep", "c"]))
}

///|
test "build_local_rank_groups dedupes previous-rank reachability, ignores external heads, falls back by cluster order, and preserves vnode slots" {
  let vnode0 = "\{@edge_identity.EDGE_VNODE_PREFIX}0"
  let vnode1 = "\{@edge_identity.EDGE_VNODE_PREFIX}1"

  let groups : Map[Int, Array[String]] = Map([])
  groups[0] = ["b", vnode0, "a", "outside"]
  groups[1] = ["e", vnode1, "d", "c", "outside"]
  groups[2] = ["solo"]

  let cluster_node_set : Map[String, Bool] = Map([])
  cluster_node_set["a"] = true
  cluster_node_set["b"] = true
  cluster_node_set["c"] = true
  cluster_node_set["d"] = true
  cluster_node_set["e"] = true
  cluster_node_set["solo"] = true
  cluster_node_set[vnode0] = true
  cluster_node_set[vnode1] = true

  let cluster_node_order : Map[String, Int] = Map([])
  cluster_node_order["a"] = 0
  cluster_node_order["b"] = 1
  cluster_node_order["c"] = 2
  cluster_node_order["d"] = 3
  cluster_node_order["e"] = 4
  cluster_node_order["solo"] = 5
  cluster_node_order[vnode0] = 6
  cluster_node_order[vnode1] = 7

  let source_graphviz_out_neighbors : Map[String, Array[String]] = Map([])
  source_graphviz_out_neighbors["a"] = ["d", "outside", "c"]
  source_graphviz_out_neighbors["b"] = ["d"]
  source_graphviz_out_neighbors[vnode0] = ["outside"]

  let cluster_groups = build_local_rank_groups(
    groups, cluster_node_set, cluster_node_order, source_graphviz_out_neighbors,
  )

  assert_eq(cluster_groups.get(0), Some(["a", vnode0, "b"]))
  assert_eq(cluster_groups.get(1), Some(["d", vnode1, "c", "e"]))
  assert_eq(cluster_groups.get(2), Some(["solo"]))
}
