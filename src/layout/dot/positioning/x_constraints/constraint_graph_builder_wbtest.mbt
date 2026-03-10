///|
fn require_constraint_builder_index(
  index : Map[String, Int],
  name : String,
) -> Int raise {
  match index.get(name) {
    Some(value) => value
    None => fail("missing index for \{name}")
  }
}

///|
fn make_constraint_builder_test_port(
  name : String,
  compass : @cgraph.Compass,
) -> @cgraph.Port {
  { name: Some(name), compass: Some(compass) }
}

///|
fn build_constraint_builder_test_sizes() -> Map[
  String,
  @node_primitives.NodeSize,
] {
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.vnode_size_from_widths_with_h(3.0, 4.0, 10.0)
  sizes["b"] = @node_primitives.vnode_size_from_widths_with_h(6.0, 7.0, 12.0)
  sizes["c"] = @node_primitives.vnode_size_from_widths_with_h(5.0, 8.0, 8.0)
  sizes["d"] = @node_primitives.vnode_size_from_widths_with_h(2.0, 3.0, 9.0)
  sizes["e"] = @node_primitives.vnode_size_from_widths_with_h(4.0, 5.0, 11.0)
  sizes
}

///|
test "segment_slack_minlen splits positive and negative port deltas" {
  let tail_port = Some(
    make_constraint_builder_test_port("tail", @cgraph.Compass::E),
  )
  let head_port = Some(
    make_constraint_builder_test_port("head", @cgraph.Compass::W),
  )
  let offset_by_key : Map[String, Double] = Map::new()
  offset_by_key["a|tail:e"] = 3.0
  offset_by_key["b|head:w"] = 9.0
  offset_by_key["c|tail:e"] = 11.0
  offset_by_key["d|head:w"] = 7.0
  let edge_port_offset = (name : String, port : @cgraph.Port?) => {
    let key = "\{name}|\{@edge_identity.port_key(port)}"
    offset_by_key.get(key).unwrap_or_default()
  }

  let positive = segment_slack_minlen(
    { tail: "a", head: "b", weight: 1, tail_port, head_port },
    edge_port_offset,
  )
  let negative = segment_slack_minlen(
    { tail: "c", head: "d", weight: 1, tail_port, head_port },
    edge_port_offset,
  )

  assert_eq(positive, (6, 0))
  assert_eq(negative, (0, 4))
}

///|
test "build_constraint_segment_pass updates same-rank invis ordering constraints and skips intercluster edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ordering", "out")
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let inside = graph.edge(b, a)
  inside.set_attr("style", "invis")
  inside.set_attr("minlen", "2")
  inside.set_attr("weight", "7")
  let cross = graph.edge(a, c, name="cross")
  cross.set_attr("minlen", "5")
  cross.set_attr("weight", "11")

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["b"] = [0]
  edge_out_order["a"] = [1]

  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 0 }
  let cluster_keys : Map[String, String] = {
    "a": "cluster0",
    "b": "cluster0",
    "c": "cluster1",
  }
  let order_in_rank : Map[String, Int] = { "a": 0, "b": 1, "c": 2 }
  let rank_adj_constraints : Map[String, ConstraintEdge] = {
    "a|b": {
      tail: "a",
      head: "b",
      minlen: 12,
      weight: 3,
      tail_port: None,
      head_port: None,
    },
  }

  let output = build_constraint_segment_pass({
    edges: [inside, cross],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["b", "a", "c"],
    ranks,
    cluster_keys,
    edge_vnodes: Map::new(),
    order_in_rank,
    nodesep_pt: 10.0,
    sizes: build_constraint_builder_test_sizes(),
    skip_intercluster: true,
    rank_adj_constraints,
    edge_has_mid_label: _ => false,
    edge_degree_increment: _ => 1,
  })

  let merged = match rank_adj_constraints.get("a|b") {
    Some(value) => value
    None => fail("missing merged same-rank constraint")
  }

  assert_eq(merged.tail, "a")
  assert_eq(merged.head, "b")
  assert_eq(merged.minlen, 40)
  assert_eq(merged.weight, 7)
  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 0)
}

///|
test "build_constraint_segment_pass adds synthetic ordering ports on same-rank labeled vnode chains" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ordering", "out")
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("label", "mid")
  edge.set_attr("weight", "3")
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}flat_0"

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [0]
  let ranks : Map[String, Int] = { "a": 0, "b": 0 }
  ranks[vnode] = 0
  let order_in_rank : Map[String, Int] = { "a": 0, "b": 2 }
  order_in_rank[vnode] = 1
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = [vnode]

  let output = build_constraint_segment_pass({
    edges: [edge],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["a", vnode, "b"],
    ranks,
    cluster_keys: Map::new(),
    edge_vnodes,
    order_in_rank,
    nodesep_pt: 10.0,
    sizes: build_constraint_builder_test_sizes(),
    skip_intercluster: false,
    rank_adj_constraints: Map::new(),
    edge_has_mid_label: _ => true,
    edge_degree_increment: _ => 1,
  })

  let head_segments = match output.segments_by_tail.get("a") {
    Some(value) => value
    None => fail("missing first vnode segment")
  }
  let tail_segments = match output.segments_by_tail.get(vnode) {
    Some(value) => value
    None => fail("missing second vnode segment")
  }

  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 2)

  assert_eq(head_segments.length(), 1)
  assert_eq(head_segments[0].tail, "a")
  assert_eq(head_segments[0].head, vnode)
  assert_eq(head_segments[0].weight, 6)
  assert_eq(@edge_identity.port_key(head_segments[0].tail_port), "e")
  assert_eq(@edge_identity.port_key(head_segments[0].head_port), "w")

  assert_eq(tail_segments.length(), 1)
  assert_eq(tail_segments[0].tail, vnode)
  assert_eq(tail_segments[0].head, "b")
  assert_eq(tail_segments[0].weight, 6)
  assert_eq(@edge_identity.port_key(tail_segments[0].tail_port), "")
  assert_eq(@edge_identity.port_key(tail_segments[0].head_port), "")
}

///|
test "build_constraint_segment_pass reverses descending vnode chains and scales sparse segment weights" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("weight", "3")

  let vnode0 = "\{@edge_identity.EDGE_VNODE_PREFIX}desc_0"
  let vnode1 = "\{@edge_identity.EDGE_VNODE_PREFIX}desc_1"
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [0]
  let ranks : Map[String, Int] = { "a": 2, "b": 0 }
  ranks[vnode0] = 1
  ranks[vnode1] = 1
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = [vnode0, vnode1]

  let output = build_constraint_segment_pass({
    edges: [edge],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["a", vnode0, vnode1, "b"],
    ranks,
    cluster_keys: Map::new(),
    edge_vnodes,
    order_in_rank: Map::new(),
    nodesep_pt: 10.0,
    sizes: build_constraint_builder_test_sizes(),
    skip_intercluster: false,
    rank_adj_constraints: Map::new(),
    edge_has_mid_label: _ => false,
    edge_degree_increment: _ => 1,
  })

  let first_segments = match output.segments_by_tail.get("a") {
    Some(value) => value
    None => fail("missing first descending segment")
  }
  let middle_segments = match output.segments_by_tail.get(vnode1) {
    Some(value) => value
    None => fail("missing middle descending segment")
  }
  let last_segments = match output.segments_by_tail.get(vnode0) {
    Some(value) => value
    None => fail("missing last descending segment")
  }

  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 3)

  assert_eq(first_segments.length(), 1)
  assert_eq(first_segments[0].tail, "a")
  assert_eq(first_segments[0].head, vnode1)
  assert_eq(first_segments[0].weight, 6)

  assert_eq(middle_segments.length(), 1)
  assert_eq(middle_segments[0].tail, vnode1)
  assert_eq(middle_segments[0].head, vnode0)
  assert_eq(middle_segments[0].weight, 12)

  assert_eq(last_segments.length(), 1)
  assert_eq(last_segments[0].tail, vnode0)
  assert_eq(last_segments[0].head, "b")
  assert_eq(last_segments[0].weight, 6)
}

///|
test "constraint node setup delays cluster boundaries and seeds base positions" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let boundary = @cluster_identity.cluster_left_boundary_name("cluster0")
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0_0"
  let base_positions : Map[String, Double] = Map::new()
  base_positions["a"] = 10.0
  base_positions[vnode] = 30.0
  let constraint_graph = @network_simplex.new_graph()

  let setup = build_constraint_nodes_setup({
    graph: constraint_graph,
    nodes: [a, b],
    extra_nodes: [{ name: boundary, rank: 9 }, { name: vnode, rank: 7 }],
    nlist_order: [vnode, "a", boundary],
    base_positions,
  })

  assert_eq(setup.index.get(boundary), None)
  assert_eq(setup.late_extra_nodes.length(), 1)
  assert_eq(setup.late_extra_nodes[0].name, boundary)

  let vnode_idx = require_constraint_builder_index(setup.index, vnode)
  let a_idx = require_constraint_builder_index(setup.index, "a")
  let b_idx = require_constraint_builder_index(setup.index, "b")
  assert_true(
    constraint_graph.nodes[vnode_idx].kind == @network_simplex.NodeKind::Virtual,
  )
  assert_eq(@network_simplex.node_rank(constraint_graph, vnode_idx), 30)
  assert_true(
    constraint_graph.nodes[a_idx].kind == @network_simplex.NodeKind::Normal,
  )
  assert_eq(@network_simplex.node_rank(constraint_graph, a_idx), 10)
  assert_true(
    constraint_graph.nodes[b_idx].kind == @network_simplex.NodeKind::Normal,
  )
  assert_eq(@network_simplex.node_rank(constraint_graph, b_idx), 0)

  append_late_constraint_nodes({
    graph: constraint_graph,
    index: setup.index,
    late_extra_nodes: setup.late_extra_nodes,
  })

  let boundary_idx = require_constraint_builder_index(setup.index, boundary)
  assert_true(
    constraint_graph.nodes[boundary_idx].kind ==
    @network_simplex.NodeKind::Slack,
  )
  assert_eq(@network_simplex.node_rank(constraint_graph, boundary_idx), 0)
}

///|
test "add_constraint_edge_if_present only emits edges with both endpoints" {
  let graph = @network_simplex.new_graph()
  let index : Map[String, Int] = Map::new()
  index["a"] = @network_simplex.add_node(graph, "a")
  index["b"] = @network_simplex.add_node(graph, "b")

  add_constraint_edge_if_present(graph, index, {
    tail: "a",
    head: "b",
    minlen: 4,
    weight: 7,
    tail_port: None,
    head_port: None,
  })
  add_constraint_edge_if_present(graph, index, {
    tail: "a",
    head: "missing",
    minlen: 9,
    weight: 9,
    tail_port: None,
    head_port: None,
  })

  assert_eq(graph.edges.length(), 1)
  assert_eq(graph.edges[0].tail, index["a"])
  assert_eq(graph.edges[0].head, index["b"])
  assert_eq(graph.edges[0].minlen, 4)
  assert_eq(graph.edges[0].weight, 7)
}

///|
test "append_missing_rank_boundary_targets adds leftmost and rightmost nodes once per non-empty rank" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[2] = ["c", "d", "e"]

  let root_ln_targets = ["a"]
  let root_rn_targets = ["e"]
  append_missing_rank_boundary_targets(
    [0, 1, 2],
    groups,
    root_ln_targets,
    root_rn_targets,
  )

  assert_eq(root_ln_targets, ["a", "c"])
  assert_eq(root_rn_targets, ["e", "b"])
}

///|
test "add_root_boundary_constraints builds slack nodes for plain and compress modes" {
  let plain_graph = @network_simplex.new_graph()
  let plain_index : Map[String, Int] = Map::new()
  plain_index["a"] = @network_simplex.add_node(plain_graph, "a")
  plain_index["b"] = @network_simplex.add_node(plain_graph, "b")
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.vnode_size_from_widths_with_h(3.0, 4.0, 8.0)
  sizes["b"] = @node_primitives.vnode_size_from_widths_with_h(5.0, 6.0, 8.0)

  add_root_boundary_constraints({
    graph: plain_graph,
    index: plain_index,
    root_ln_targets: ["a"],
    root_rn_targets: ["b"],
    sizes,
    root_margin: 7.0,
    compress_width_minlen: None,
    root_compress_weight: 128,
  })

  assert_eq(plain_graph.nodes.length(), 4)
  assert_true(plain_graph.nodes[2].kind == @network_simplex.NodeKind::Slack)
  assert_true(plain_graph.nodes[3].kind == @network_simplex.NodeKind::Slack)
  assert_eq(@network_simplex.node_rank(plain_graph, 2), 0)
  assert_eq(@network_simplex.node_rank(plain_graph, 3), 0)
  assert_eq(plain_graph.edges.length(), 2)
  assert_eq(plain_graph.edges[0].tail, 2)
  assert_eq(plain_graph.edges[0].head, plain_index["a"])
  assert_eq(plain_graph.edges[0].minlen, 7)
  assert_eq(plain_graph.edges[1].tail, plain_index["b"])
  assert_eq(plain_graph.edges[1].head, 3)
  assert_eq(plain_graph.edges[1].minlen, 7)

  let compress_graph = @network_simplex.new_graph()
  let compress_index : Map[String, Int] = Map::new()
  compress_index["a"] = @network_simplex.add_node(compress_graph, "a")
  compress_index["b"] = @network_simplex.add_node(compress_graph, "b")

  add_root_boundary_constraints({
    graph: compress_graph,
    index: compress_index,
    root_ln_targets: ["a"],
    root_rn_targets: ["b"],
    sizes,
    root_margin: 2.0,
    compress_width_minlen: Some(20),
    root_compress_weight: 128,
  })

  assert_eq(compress_graph.nodes.length(), 4)
  assert_true(compress_graph.nodes[2].kind == @network_simplex.NodeKind::Slack)
  assert_true(compress_graph.nodes[3].kind == @network_simplex.NodeKind::Slack)
  assert_eq(compress_graph.edges.length(), 3)
  assert_eq(compress_graph.edges[0].tail, 2)
  assert_eq(compress_graph.edges[0].head, compress_index["a"])
  assert_eq(compress_graph.edges[0].minlen, 5)
  assert_eq(compress_graph.edges[1].tail, compress_index["b"])
  assert_eq(compress_graph.edges[1].head, 3)
  assert_eq(compress_graph.edges[1].minlen, 8)
  assert_eq(compress_graph.edges[2].tail, 2)
  assert_eq(compress_graph.edges[2].head, 3)
  assert_eq(compress_graph.edges[2].minlen, 20)
  assert_eq(compress_graph.edges[2].weight, 128)
}

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
