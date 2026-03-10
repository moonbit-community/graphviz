///|
test "build_constraint_graph assembles seed flat segment boundary and extra edges in stable order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ordering", "out")
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")

  let flat_edge = graph.edge(b, a)
  flat_edge.set_attr("style", "invis")
  flat_edge.set_attr("minlen", "2")
  flat_edge.set_attr("weight", "7")

  let long_edge = graph.edge(a, c, name="long")
  long_edge.set_attr("weight", "5")

  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}graph_0"
  let boundary = @cluster_identity.cluster_left_boundary_name("cluster0")
  let sizes = build_constraint_builder_test_sizes()
  sizes[vnode] = @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 2.0)

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [1]
  edge_out_order["b"] = [0]

  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 2 }
  ranks[vnode] = 1

  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[2] = ["c"]

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(long_edge)] = [vnode]

  let build = build_constraint_graph({
    nodes: [a, b, c],
    edges: [flat_edge, long_edge],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["a", "b", vnode, "c"],
    ranks,
    rank_keys: [0, 2],
    groups,
    sizes,
    cluster_keys: Map::new(),
    nodesep_pt: 10.0,
    has_edge_labels: false,
    extra_nodes: [{ name: vnode, rank: 1 }, { name: boundary, rank: 9 }],
    extra_edges: [
      {
        tail: boundary,
        head: "b",
        minlen: 9,
        weight: 13,
        tail_port: None,
        head_port: None,
      },
    ],
    edge_vnodes,
    root_ln_targets: ["a"],
    root_rn_targets: ["c"],
    compress_width_minlen: None,
    segment_minlen: (_segment, _real_by_name) => (0, 0),
    edge_has_mid_label: _ => false,
    edge_degree_increment: _ => 1,
    root_margin: 3.0,
    root_compress_weight: 128,
  })

  let a_idx = require_constraint_builder_index(build.index, "a")
  let b_idx = require_constraint_builder_index(build.index, "b")
  let vnode_idx = require_constraint_builder_index(build.index, vnode)
  let c_idx = require_constraint_builder_index(build.index, "c")
  let boundary_idx = require_constraint_builder_index(build.index, boundary)

  assert_eq(a_idx, 0)
  assert_eq(b_idx, 1)
  assert_eq(vnode_idx, 2)
  assert_eq(c_idx, 3)
  assert_eq(boundary_idx, 6)

  assert_true(
    build.graph.nodes[vnode_idx].kind == @network_simplex.NodeKind::Virtual,
  )
  assert_eq(@network_simplex.node_rank(build.graph, a_idx), 0)
  assert_eq(@network_simplex.node_rank(build.graph, b_idx), 20)
  assert_eq(@network_simplex.node_rank(build.graph, vnode_idx), 1)
  assert_eq(@network_simplex.node_rank(build.graph, c_idx), 0)

  assert_eq(build.graph.nodes.length(), 9)
  assert_true(build.graph.nodes[4].kind == @network_simplex.NodeKind::Slack)
  assert_true(build.graph.nodes[5].kind == @network_simplex.NodeKind::Slack)
  assert_true(
    build.graph.nodes[boundary_idx].kind == @network_simplex.NodeKind::Slack,
  )
  assert_true(build.graph.nodes[7].kind == @network_simplex.NodeKind::Slack)
  assert_true(build.graph.nodes[8].kind == @network_simplex.NodeKind::Slack)
  assert_eq(@network_simplex.node_rank(build.graph, 4), -1)
  assert_eq(@network_simplex.node_rank(build.graph, 5), -1)
  assert_eq(@network_simplex.node_rank(build.graph, boundary_idx), 0)
  assert_eq(@network_simplex.node_rank(build.graph, 7), 0)
  assert_eq(@network_simplex.node_rank(build.graph, 8), 0)

  assert_eq(build.graph.edges.length(), 8)

  assert_eq(build.graph.edges[0].tail, a_idx)
  assert_eq(build.graph.edges[0].head, b_idx)
  assert_eq(build.graph.edges[0].minlen, 40)
  assert_eq(build.graph.edges[0].weight, 7)

  assert_eq(build.graph.edges[1].tail, 4)
  assert_eq(build.graph.edges[1].head, a_idx)
  assert_eq(build.graph.edges[1].minlen, 1)
  assert_eq(build.graph.edges[1].weight, 5)
  assert_eq(build.graph.edges[2].tail, 4)
  assert_eq(build.graph.edges[2].head, vnode_idx)
  assert_eq(build.graph.edges[2].minlen, 1)
  assert_eq(build.graph.edges[2].weight, 5)

  assert_eq(build.graph.edges[3].tail, 5)
  assert_eq(build.graph.edges[3].head, vnode_idx)
  assert_eq(build.graph.edges[3].minlen, 1)
  assert_eq(build.graph.edges[3].weight, 10)
  assert_eq(build.graph.edges[4].tail, 5)
  assert_eq(build.graph.edges[4].head, c_idx)
  assert_eq(build.graph.edges[4].minlen, 1)
  assert_eq(build.graph.edges[4].weight, 10)

  assert_eq(build.graph.edges[5].tail, 7)
  assert_eq(build.graph.edges[5].head, a_idx)
  assert_eq(build.graph.edges[5].minlen, 3)
  assert_eq(build.graph.edges[5].weight, 0)
  assert_eq(build.graph.edges[6].tail, c_idx)
  assert_eq(build.graph.edges[6].head, 8)
  assert_eq(build.graph.edges[6].minlen, 3)
  assert_eq(build.graph.edges[6].weight, 0)

  assert_eq(build.graph.edges[7].tail, boundary_idx)
  assert_eq(build.graph.edges[7].head, b_idx)
  assert_eq(build.graph.edges[7].minlen, 9)
  assert_eq(build.graph.edges[7].weight, 13)
}
