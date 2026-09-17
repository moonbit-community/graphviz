// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "parent class2 view collapses descendant nodes and internal vnodes into a skeleton" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed)
  let parent = graph.subgraph(name="cluster_parent")
  let scope = parent.subgraph()
  let child = scope.subgraph(name="cluster_child")
  let grandchild = child.subgraph(name="cluster_grandchild")
  let a = grandchild.node("a")
  let b = grandchild.node("b")
  let outside = parent.node("outside")
  let incoming = graph.edge(outside, a)
  let internal = grandchild.edge(a, b)
  let vnode = "_mbt_edge_vn_1_1"
  let groups : Map[Int, Array[String]] = {
    -1: ["outside"],
    0: ["a"],
    1: [vnode],
    2: ["b"],
  }
  let dispatch : ClusterLocalReorderDispatchContext = {
    node_order: { "outside": 0, "a": 1, "b": 2 },
    order_edges: [incoming, internal, internal],
    order_edge_tail: ["outside", "a", vnode],
    order_edge_head: ["a", vnode, "b"],
    order_edge_tail_port_x: [3.0, 0.0, 0.0],
    order_edge_head_port_x: [4.0, 0.0, 0.0],
    order_edge_tail_port_order: [0.25, 0.0, 0.0],
    order_edge_head_port_order: [0.75, 0.0, 0.0],
    neighbor_sources: {
      source_out_neighbors: Map([]),
      source_in_neighbors: Map([]),
      raw_out_neighbors: Map([]),
      raw_in_neighbors: Map([]),
    },
    order_sizes: Map([]),
    nodesep_pt: 18.0,
    has_edge_labels: false,
    port_order_positions: Map([]),
    port_order_contrib: Map([]),
    rank_same_groups: Map([]),
    rank_same_order: Map([]),
    intercluster_keys: Map([]),
    flat_constraints: Map([]),
    vnode_clusters: Map([(vnode, "cluster_grandchild")]),
    vnode_sizes: Map([]),
    fixed_ranks: @rank_groups.build_node_ranks(groups),
    order_with_vnodes: true,
  }
  guard build_child_skeleton_view("cluster_parent", parent, groups, dispatch)
    is Some(view) else {
    @test.fail("expected child skeleton")
  }
  let skeleton_0 = @cluster_identity.cluster_skeleton_name("cluster_child", 0)
  let skeleton_1 = @cluster_identity.cluster_skeleton_name("cluster_child", 1)
  let skeleton_2 = @cluster_identity.cluster_skeleton_name("cluster_child", 2)
  @test.assert_eq(view.groups.get(0), Some([skeleton_0]))
  @test.assert_eq(view.groups.get(1), Some([skeleton_1]))
  @test.assert_eq(view.groups.get(2), Some([skeleton_2]))
  @test.assert_eq(view.members.get(skeleton_1), Some([vnode]))
  @test.assert_eq(view.graph.find_node("a") is None, true)
  @test.assert_eq(view.graph.find_node("outside") is Some(_), true)
  @test.assert_eq(view.dispatch.order_edge_tail, [
    skeleton_0, skeleton_1, "outside",
  ])
  @test.assert_eq(view.dispatch.order_edge_head, [
    skeleton_1, skeleton_2, skeleton_0,
  ])
  @test.assert_eq(view.dispatch.order_edge_tail_port_x, [0.0, 0.0, 3.0])
  @test.assert_eq(view.dispatch.order_edge_head_port_x, [0.0, 0.0, 0.0])
  @test.assert_eq(
    view.dispatch.order_edges[0].get_attr("xpenalty"),
    Some("1000"),
  )
  @test.assert_eq(groups.get(1), Some([vnode]))
}

///|
test "cluster expansion replaces its rankleader instead of the first pre-expanded member" {
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_parent", 1)
  let groups : Map[Int, Array[String]] = {
    1: ["left", skeleton, "outside", "a", "b"],
  }
  apply_cluster_rank_reorder_output(
    groups,
    [1],
    { 1: ["b", "a"] },
    { "a": true, "b": true },
    replaced_cluster="cluster_parent",
  )
  @test.assert_eq(groups.get(1), Some(["left", "b", "a", "outside"]))
}

///|
test "active child rankleaders occupy fixed-position slots until expansion" {
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_child", 0)
  let anchors = build_cluster_fixed_positions(
    Map([("left", 0.0), (skeleton, 1.0), ("right", 2.0)]),
    Map([(skeleton, true)]),
    { 0: ["left", skeleton, "right"] },
  )
  @test.assert_eq(anchors.get("left"), Some(-1.0))
  @test.assert_eq(anchors.get("right"), Some(1.0))
}
