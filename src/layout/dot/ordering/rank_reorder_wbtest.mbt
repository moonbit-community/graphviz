///|
fn fixed_case_node_key(id : Int) -> String {
  "n\{id}"
}

///|
fn run_fixed_rank_reorder_case(
  input : MincrossInput,
  output : MincrossOutput,
) -> Unit raise {
  let graph =
    @cgraph.Graph::new(@cgraph.GraphKind::Directed, name=input.graph, strict=false)
  let id_to_name : Map[Int, String] = Map::new()
  let name_to_id : Map[String, Int] = Map::new()
  let name_to_rank : Map[String, Int] = Map::new()
  let name_to_node : Map[String, @cgraph.Node] = Map::new()
  let name_to_order : Map[String, Int] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  let nodes : Array[@cgraph.Node] = []
  let default_size = @node_primitives.node_size_from_points(
    @node_primitives.default_node_width_in() * 72.0,
    @node_primitives.default_node_height_in() * 72.0,
  )

  for node in input.nodes {
    let name = fixed_case_node_key(node.id)
    id_to_name[node.id] = name
    name_to_id[name] = node.id
    name_to_rank[name] = node.rank
    name_to_order[name] = node.order
    let cnode = graph.node(name)
    name_to_node[name] = cnode
    nodes.push(cnode)
    sizes[name] = default_size
  }

  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for node in input.nodes {
    let name = fixed_case_node_key(node.id)
    let out_names : Array[String] = []
    for neighbor_id in node.out_neighbors {
      match id_to_name.get(neighbor_id) {
        Some(value) => out_names.push(value)
        None => fail("case \{input.case_id} missing out neighbor id \{neighbor_id}")
      }
    }
    let in_names : Array[String] = []
    for neighbor_id in node.in_neighbors {
      match id_to_name.get(neighbor_id) {
        Some(value) => in_names.push(value)
        None => fail("case \{input.case_id} missing in neighbor id \{neighbor_id}")
      }
    }
    graphviz_out_neighbors[name] = out_names
    graphviz_in_neighbors[name] = in_names
  }

  let edges : Array[@cgraph.Edge] = []
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_tail_port_x : Array[Double] = []
  let edge_head_port_x : Array[Double] = []
  let edge_tail_port_order : Array[Double] = []
  let edge_head_port_order : Array[Double] = []
  for edge in input.edges {
    let tail_name = match id_to_name.get(edge.tail) {
      Some(value) => value
      None => fail("case \{input.case_id} missing tail id \{edge.tail}")
    }
    let head_name = match id_to_name.get(edge.head) {
      Some(value) => value
      None => fail("case \{input.case_id} missing head id \{edge.head}")
    }
    let tail_node = match name_to_node.get(tail_name) {
      Some(value) => value
      None => fail("case \{input.case_id} missing tail node \{tail_name}")
    }
    let head_node = match name_to_node.get(head_name) {
      Some(value) => value
      None => fail("case \{input.case_id} missing head node \{head_name}")
    }
    let edge_obj = graph.edge(tail_node, head_node)
    edge_obj.set_attr("xpenalty", "\{edge.xpenalty}")
    edges.push(edge_obj)
    edge_tail.push(tail_name)
    edge_head.push(head_name)
    edge_tail_port_x.push(edge.tail_port_x)
    edge_head_port_x.push(edge.head_port_x)
    edge_tail_port_order.push(edge.tail_port_order)
    edge_head_port_order.push(edge.head_port_order)
  }

  let rank_keys : Array[Int] = []
  for rank in input.minrank..=input.maxrank {
    rank_keys.push(rank)
  }
  let groups : Map[Int, Array[String]] = Map::new()
  let mut rank = input.minrank
  for rank_nodes in input.ranks {
    let names : Array[String] = []
    for node_id in rank_nodes {
      match id_to_name.get(node_id) {
        Some(value) => names.push(value)
        None => fail("case \{input.case_id} missing node id \{node_id}")
      }
    }
    groups[rank] = names
    rank = rank + 1
  }

  let edge_index_data =
    build_edge_index_for_order(nodes, edges, edge_tail, edge_head, name_to_rank)
  let edge_order = collect_edge_order(edges)
  let nodesep_pt = @input_stage.DEFAULT_NODESEP_IN * 72.0
  let ordered = reorder_rank_groups(
    rank_keys,
    groups,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    edge_index_data.parents,
    edge_index_data.children,
    Map::new(),
    Map::new(),
    Map::new(),
    edge_order,
    name_to_order,
    sizes,
    nodesep_pt,
    false,
    Map::new(),
    Map::new(),
    Map::new(),
    Map::new(),
    Map::new(),
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
    graphviz_flip=input.flip,
    coalesce_parallel_edges=input.startpass > 1,
    startpass=input.startpass,
  )

  let actual : Array[Array[Int]] = []
  for rank_key in rank_keys {
    let names = match ordered.get(rank_key) {
      Some(list) => list
      None => []
    }
    let ids : Array[Int] = []
    for name in names {
      match name_to_id.get(name) {
        Some(value) => ids.push(value)
        None => fail("case \{input.case_id} missing name \{name}")
      }
    }
    actual.push(ids)
  }

  assert_eq(actual, output.ranks)
}

///|
test "compute_desired_positions prefers explicit positions, then port anchors, then neighbor medians" {
  let neighbors : Map[String, Array[String]] = Map::new()
  neighbors["median"] = ["n1", "n2", "n3"]
  neighbors["fallback"] = ["n2", "n3"]

  let x_positions : Map[String, Double] = Map::new()
  x_positions["anchor_left"] = 10.0
  x_positions["anchor_right"] = 30.0
  x_positions["n1"] = 2.0
  x_positions["n2"] = 6.0
  x_positions["n3"] = 100.0

  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  port_order_contrib["preferred"] = [("anchor_left", 99.0)]
  port_order_contrib["ported"] = [
    ("anchor_left", 1.5),
    ("anchor_right", -0.5),
    ("missing_anchor", 5.0),
  ]
  port_order_contrib["fallback"] = [("missing_anchor", 8.0)]

  let preferred_positions : Map[String, Double] = Map::new()
  preferred_positions["preferred"] = 42.0

  let desired =
    compute_desired_positions(
      ["preferred", "ported", "median", "fallback", "missing"],
      neighbors,
      x_positions,
      port_order_contrib,
      preferred_positions,
    )

  assert_eq(desired.get("preferred"), Some(42.0))
  assert_eq(desired.get("ported"), Some(20.5))
  assert_eq(desired.get("median"), Some(6.0))
  assert_eq(desired.get("fallback"), Some(53.0))
  assert_eq(desired.get("missing"), None)
}

///|
test "compute_scaled_medians applies port offsets before Graphviz scaling" {
  let neighbors : Map[String, Array[(String, Double)]] = Map::new()
  neighbors["ported"] = [("left", 0.1), ("right", 0.0), ("missing", 8.0)]

  let x_positions : Map[String, Double] = Map::new()
  x_positions["left"] = 0.0
  x_positions["right"] = 1.0

  let desired = compute_scaled_medians(["ported"], neighbors, x_positions)

  assert_eq(desired.get("ported"), Some(0.546875))
}

///|
test "reorder_by_medians keeps left-to-right constrained pairs pinned" {
  let desired : Map[String, Double] = Map::new()
  desired["a"] = 2.0
  desired["b"] = 1.0
  desired["c"] = 0.0

  let flat_constraints : Map[String, Bool] = Map::new()
  flat_constraints["a|b"] = true

  let reordered =
    reorder_by_medians(
      ["a", "b", "c"],
      desired,
      false,
      false,
      Map::new(),
      Map::new(),
      flat_constraints,
    )

  assert_eq(reordered, ["c", "a", "b"])
}

///|
test "count_rank_crossings_port uses port x offsets to break equal-order ties" {
  let ranks : Map[String, Int] = Map::new()
  ranks["p"] = 0
  ranks["x"] = 1
  ranks["y"] = 1

  let fixed_order : Map[String, Int] = Map::new()

  let edge_in : Map[String, Array[Int]] = Map::new()
  edge_in["x"] = [0]
  edge_in["y"] = [1]

  let edge_out : Map[String, Array[Int]] = Map::new()

  let crossings =
    count_rank_crossings_port(
      1,
      ["x", "y"],
      ranks,
      fixed_order,
      edge_in,
      edge_out,
      ["p", "p"],
      ["x", "y"],
      [2.0, 1.0],
      [],
      [1, 1],
    )

  assert_eq(crossings, 1)
}

///|
test "flat_reorder_rank_groups topologically reorders constrained ranks" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b", "c", "d"]

  let node_ranks : Map[String, Int] = Map::new()
  node_ranks["a"] = 0
  node_ranks["b"] = 0
  node_ranks["c"] = 0
  node_ranks["d"] = 0

  let flat_constraints : Map[String, Bool] = Map::new()
  flat_constraints["a|c"] = true
  flat_constraints["c|b"] = true

  let ordered =
    flat_reorder_rank_groups([0], groups, node_ranks, flat_constraints, false)

  assert_eq(ordered.get(0), Some(["a", "c", "b", "d"]))
}

///|
test "rank_reorder preserves initial tie order for symmetric fixed case" {
  let input : MincrossInput = {
    case_id: 1001,
    graph: "fixed_case",
    startpass: 0,
    flip: false,
    minrank: 0,
    maxrank: 1,
    nodes: [
      {
        id: 0,
        name: None,
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1, 3],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: None,
        rank: 1,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 2],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: None,
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1, 3],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 3,
        name: None,
        rank: 1,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 2],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [
      {
        tail: 0,
        head: 1,
        xpenalty: 1,
        seq: 3,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 0,
        head: 3,
        xpenalty: 1,
        seq: 4,
        order: 1,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 2,
        head: 1,
        xpenalty: 1,
        seq: 1,
        order: 2,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 2,
        head: 3,
        xpenalty: 1,
        seq: 2,
        order: 3,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
    flat_edges: [],
    ranks: [[0, 2], [1, 3]],
  }
  let output : MincrossOutput = {
    case_id: 1001,
    ranks: [[0, 2], [1, 3]],
  }

  run_fixed_rank_reorder_case(input, output)
}

///|
test "rank_reorder recovers nlist tie order from reversed seed" {
  let input : MincrossInput = {
    case_id: 1002,
    graph: "fixed_case_reversed_seed",
    startpass: 0,
    flip: false,
    minrank: 0,
    maxrank: 1,
    nodes: [
      {
        id: 0,
        name: None,
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1, 3],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: None,
        rank: 1,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 2],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: None,
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1, 3],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 3,
        name: None,
        rank: 1,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 2],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [
      {
        tail: 0,
        head: 1,
        xpenalty: 1,
        seq: 3,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 0,
        head: 3,
        xpenalty: 1,
        seq: 4,
        order: 1,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 2,
        head: 1,
        xpenalty: 1,
        seq: 1,
        order: 2,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 2,
        head: 3,
        xpenalty: 1,
        seq: 2,
        order: 3,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
    flat_edges: [],
    ranks: [[2, 0], [1, 3]],
  }
  let output : MincrossOutput = {
    case_id: 1002,
    ranks: [[0, 2], [1, 3]],
  }

  run_fixed_rank_reorder_case(input, output)
}
///|
test "rank_reorder keeps flip-enabled single chains stable" {
  let input : MincrossInput = {
    case_id: 1003,
    graph: "xlabels_lr_direct",
    startpass: 0,
    flip: true,
    minrank: 0,
    maxrank: 1,
    nodes: [
      {
        id: 0,
        name: Some("a"),
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: Some("b"),
        rank: 1,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [
      {
        tail: 0,
        head: 1,
        xpenalty: 1,
        seq: 1,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
    flat_edges: [],
    ranks: [[0], [1]],
  }
  let output : MincrossOutput = {
    case_id: 1003,
    ranks: [[0], [1]],
  }

  run_mincross_case_with_name_order(input, output, Map::new())
}

///|
test "rank_reorder keeps total flat-label constraints in source order" {
  let input : MincrossInput = {
    case_id: 1004,
    graph: "flat_label_direct",
    startpass: 0,
    flip: false,
    minrank: 0,
    maxrank: 0,
    nodes: [
      {
        id: 0,
        name: Some("a"),
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: Some("b"),
        rank: 0,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: Some("c"),
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [],
    flat_edges: [
      { tail: 0, head: 1 },
      { tail: 0, head: 2 },
      { tail: 1, head: 2 },
    ],
    ranks: [[0, 1, 2]],
  }
  let output : MincrossOutput = {
    case_id: 1004,
    ranks: [[0, 1, 2]],
  }

  run_mincross_case_with_name_order(input, output, Map::new())
}

///|
test "rank_reorder keeps clustered startpass-two fan-in order stable" {
  let input : MincrossInput = {
    case_id: 1005,
    graph: "xlabels_tb_direct",
    startpass: 2,
    flip: false,
    minrank: 0,
    maxrank: 1,
    nodes: [
      {
        id: 0,
        name: Some("b"),
        rank: 0,
        order: 1,
        cluster: Some("cluster_0"),
        cluster_skeleton: false,
        out_neighbors: [2],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: Some("a"),
        rank: 0,
        order: 0,
        cluster: Some("cluster_0"),
        cluster_skeleton: false,
        out_neighbors: [2],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: Some("c"),
        rank: 1,
        order: 0,
        cluster: Some("xlabels_tb"),
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 1],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [
      {
        tail: 0,
        head: 2,
        xpenalty: 1,
        seq: 2,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 2,
        xpenalty: 1,
        seq: 1,
        order: 1,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
    flat_edges: [],
    ranks: [[1, 0], [2]],
  }
  let output : MincrossOutput = {
    case_id: 1005,
    ranks: [[1, 0], [2]],
  }

  run_mincross_case_with_name_order(input, output, Map::new())
}

///|
test "rank_reorder leaves single-node cluster slices unchanged" {
  let input : MincrossInput = {
    case_id: 1006,
    graph: "single_node_cluster_slice",
    startpass: 2,
    flip: false,
    minrank: 0,
    maxrank: 0,
    nodes: [
      {
        id: 0,
        name: Some("solo"),
        rank: 0,
        order: 0,
        cluster: Some("cluster_gtk"),
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [],
    flat_edges: [],
    ranks: [[0]],
  }
  let output : MincrossOutput = {
    case_id: 1006,
    ranks: [[0]],
  }

  run_mincross_case_with_name_order(input, output, Map::new())
}


///|
test "rank_reorder uses external anchor order for plugin-style single-rank slices" {
  let input : MincrossInput = {
    case_id: 1007,
    graph: "plugin_single_rank_anchor_order",
    startpass: 2,
    flip: false,
    minrank: 0,
    maxrank: 0,
    nodes: [
      {
        id: 0,
        name: Some("bmp"),
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_bmp"],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: Some("jpg"),
        rank: 0,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_jpg"],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: Some("png"),
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_png"],
        in_all_neighbors: [],
      },
      {
        id: 3,
        name: Some("tga"),
        rank: 0,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_tga"],
        in_all_neighbors: [],
      },
      {
        id: 4,
        name: Some("tif"),
        rank: 0,
        order: 4,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_tif"],
        in_all_neighbors: [],
      },
      {
        id: 5,
        name: Some("tiff"),
        rank: 0,
        order: 5,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_tiff"],
        in_all_neighbors: [],
      },
    ],
    edges: [],
    flat_edges: [],
    ranks: [[0, 1, 2, 3, 4, 5]],
  }
  let output : MincrossOutput = {
    case_id: 1007,
    ranks: [[5, 4, 0, 3, 1, 2]],
  }
  let name_order : Map[String, Int] = Map::new()
  name_order["fmt_tiff"] = 3
  name_order["fmt_tif"] = 4
  name_order["fmt_bmp"] = 5
  name_order["fmt_tga"] = 6
  name_order["fmt_jpg"] = 7
  name_order["fmt_png"] = 8

  run_mincross_case_with_name_order(input, output, name_order)
}

///|
test "rank_reorder uses external anchor order to break symmetric plugin fanout ties" {
  let input : MincrossInput = {
    case_id: 1008,
    graph: "plugin_fanout_anchor_order",
    startpass: 2,
    flip: false,
    minrank: 0,
    maxrank: 2,
    nodes: [
      {
        id: 0,
        name: Some("input"),
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: Some("router"),
        rank: 1,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [2, 3, 4, 5],
        in_neighbors: [0],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: Some("pdf"),
        rank: 2,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [1],
        out_all_neighbors: ["fmt_pdf"],
        in_all_neighbors: [],
      },
      {
        id: 3,
        name: Some("png"),
        rank: 2,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [1],
        out_all_neighbors: ["fmt_png"],
        in_all_neighbors: [],
      },
      {
        id: 4,
        name: Some("ps"),
        rank: 2,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [1],
        out_all_neighbors: ["fmt_ps"],
        in_all_neighbors: [],
      },
      {
        id: 5,
        name: Some("svg"),
        rank: 2,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [1],
        out_all_neighbors: ["fmt_svg"],
        in_all_neighbors: [],
      },
    ],
    edges: [
      {
        tail: 0,
        head: 1,
        xpenalty: 1,
        seq: 1,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 2,
        xpenalty: 1,
        seq: 2,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 3,
        xpenalty: 1,
        seq: 3,
        order: 1,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 4,
        xpenalty: 1,
        seq: 4,
        order: 2,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 5,
        xpenalty: 1,
        seq: 5,
        order: 3,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
    flat_edges: [],
    ranks: [[0], [1], [2, 3, 4, 5]],
  }
  let output : MincrossOutput = {
    case_id: 1008,
    ranks: [[0], [1], [3, 2, 5, 4]],
  }
  let name_order : Map[String, Int] = Map::new()
  name_order["fmt_png"] = 8
  name_order["fmt_pdf"] = 9
  name_order["fmt_svg"] = 15
  name_order["fmt_ps"] = 16

  run_mincross_case_with_name_order(input, output, name_order)
}
