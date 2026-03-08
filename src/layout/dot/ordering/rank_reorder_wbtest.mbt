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
test "rank_reorder preserves opposing edge-vnode ladders when ordering is already stable" {
  let input : MincrossInput = {
    case_id: 1007,
    graph: "edge_vnode_spacing_stable",
    startpass: 0,
    flip: false,
    minrank: 0,
    maxrank: 6,
    nodes: [
      { id: 0, name: Some("a"), rank: 0, order: 0, cluster: None, cluster_skeleton: false, out_neighbors: [1, 7], in_neighbors: [], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 1, name: None, rank: 1, order: 0, cluster: None, cluster_skeleton: false, out_neighbors: [2], in_neighbors: [0], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 2, name: Some("c"), rank: 2, order: 0, cluster: None, cluster_skeleton: false, out_neighbors: [3], in_neighbors: [1], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 3, name: None, rank: 3, order: 0, cluster: None, cluster_skeleton: false, out_neighbors: [4], in_neighbors: [2], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 4, name: Some("e"), rank: 4, order: 0, cluster: None, cluster_skeleton: false, out_neighbors: [5], in_neighbors: [3], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 5, name: None, rank: 5, order: 0, cluster: None, cluster_skeleton: false, out_neighbors: [6], in_neighbors: [4], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 6, name: Some("g"), rank: 6, order: 0, cluster: None, cluster_skeleton: false, out_neighbors: [], in_neighbors: [5], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 7, name: None, rank: 1, order: 1, cluster: None, cluster_skeleton: false, out_neighbors: [8], in_neighbors: [0], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 8, name: None, rank: 2, order: 1, cluster: None, cluster_skeleton: false, out_neighbors: [9], in_neighbors: [7], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 9, name: None, rank: 3, order: 1, cluster: None, cluster_skeleton: false, out_neighbors: [10], in_neighbors: [8], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 10, name: None, rank: 4, order: 1, cluster: None, cluster_skeleton: false, out_neighbors: [11], in_neighbors: [9], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 11, name: None, rank: 5, order: 1, cluster: None, cluster_skeleton: false, out_neighbors: [12], in_neighbors: [10], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 12, name: Some("h"), rank: 6, order: 1, cluster: None, cluster_skeleton: false, out_neighbors: [], in_neighbors: [11, 13], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 13, name: None, rank: 5, order: 2, cluster: None, cluster_skeleton: false, out_neighbors: [12], in_neighbors: [14], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 14, name: Some("f"), rank: 4, order: 2, cluster: None, cluster_skeleton: false, out_neighbors: [13], in_neighbors: [15], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 15, name: None, rank: 3, order: 2, cluster: None, cluster_skeleton: false, out_neighbors: [14], in_neighbors: [16], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 16, name: Some("d"), rank: 2, order: 2, cluster: None, cluster_skeleton: false, out_neighbors: [15], in_neighbors: [17], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 17, name: None, rank: 1, order: 2, cluster: None, cluster_skeleton: false, out_neighbors: [16], in_neighbors: [18], out_all_neighbors: [], in_all_neighbors: [] },
      { id: 18, name: Some("b"), rank: 0, order: 1, cluster: None, cluster_skeleton: false, out_neighbors: [17], in_neighbors: [], out_all_neighbors: [], in_all_neighbors: [] },
    ],
    edges: [
      { tail: 0, head: 1, xpenalty: 1, seq: 1, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 0, head: 7, xpenalty: 1, seq: 7, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 1, head: 2, xpenalty: 1, seq: 1, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 2, head: 3, xpenalty: 1, seq: 2, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 3, head: 4, xpenalty: 1, seq: 2, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 4, head: 5, xpenalty: 1, seq: 3, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 5, head: 6, xpenalty: 1, seq: 3, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 7, head: 8, xpenalty: 1, seq: 7, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 8, head: 9, xpenalty: 1, seq: 7, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 9, head: 10, xpenalty: 1, seq: 7, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 10, head: 11, xpenalty: 1, seq: 7, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 11, head: 12, xpenalty: 1, seq: 7, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 13, head: 12, xpenalty: 1, seq: 6, order: 2, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 14, head: 13, xpenalty: 1, seq: 6, order: 2, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 15, head: 14, xpenalty: 1, seq: 5, order: 2, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 16, head: 15, xpenalty: 1, seq: 5, order: 2, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 17, head: 16, xpenalty: 1, seq: 4, order: 2, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 18, head: 17, xpenalty: 1, seq: 4, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
    ],
    flat_edges: [],
    ranks: [
      [0, 18],
      [1, 7, 17],
      [2, 8, 16],
      [3, 9, 15],
      [4, 10, 14],
      [5, 11, 13],
      [6, 12],
    ],
  }
  let output : MincrossOutput = {
    case_id: 1007,
    ranks: [
      [0, 18],
      [1, 7, 17],
      [2, 8, 16],
      [3, 9, 15],
      [4, 10, 14],
      [5, 11, 13],
      [6, 12],
    ],
  }

  run_fixed_rank_reorder_case(input, output)
}

///|
fn build_exact_layered_rank_reorder_case(
  case_id : Int,
  graph : String,
  startpass : Int,
  flip : Bool,
  minrank : Int,
  input_ranks : Array[Array[Int]],
  output_ranks : Array[Array[Int]],
  node_names : Array[String?],
  node_clusters : Array[String?],
  node_cluster_skeleton : Array[Bool],
  edges : Array[MincrossEdge],
) -> (MincrossInput, MincrossOutput) {
  let out_neighbors : Map[Int, Array[Int]] = Map::new()
  let in_neighbors : Map[Int, Array[Int]] = Map::new()
  let node_rank_by_id : Map[Int, Int] = Map::new()
  let node_order_by_id : Map[Int, Int] = Map::new()
  for rank_offset, rank_nodes in input_ranks {
    let rank = minrank + rank_offset
    for order, id in rank_nodes {
      out_neighbors[id] = []
      in_neighbors[id] = []
      node_rank_by_id[id] = rank
      node_order_by_id[id] = order
    }
  }
  for edge in edges {
    out_neighbors[edge.tail].push(edge.head)
    in_neighbors[edge.head].push(edge.tail)
  }
  let nodes : Array[MincrossNode] = []
  for id in 0..<node_names.length() {
    let rank = match node_rank_by_id.get(id) {
      Some(value) => value
      None => abort("missing rank for node \{id}")
    }
    let order = match node_order_by_id.get(id) {
      Some(value) => value
      None => abort("missing order for node \{id}")
    }
    nodes.push({
      id,
      name: node_names[id],
      rank,
      order,
      cluster: node_clusters[id],
      cluster_skeleton: node_cluster_skeleton[id],
      out_neighbors: out_neighbors.get(id).unwrap_or_default(),
      in_neighbors: in_neighbors.get(id).unwrap_or_default(),
      out_all_neighbors: [],
      in_all_neighbors: [],
    })
  }
  let input : MincrossInput = {
    case_id,
    graph,
    startpass,
    flip,
    minrank,
    maxrank: minrank + input_ranks.length() - 1,
    nodes,
    edges,
    flat_edges: [],
    ranks: input_ranks,
  }
  let output : MincrossOutput = {
    case_id,
    ranks: output_ranks,
  }
  (input, output)
}

///|
/// Graphviz parity: this is the stable wide normal tree behind the L0
/// integrated fixture. Keep exact owner-local coverage so the fixture replay
/// can focus on denser integrated reorder cases.
fn wide_normal_tree_rank_reorder_case() -> (MincrossInput, MincrossOutput) {
  let input_ranks : Array[Array[Int]] = [[3],[0,4,5,39,40],[1,6,16,17,41],[2,7,8,15,18,19,38,42],[9,20,26,27],[10,12,13,21,23,24,28],[11,14,22,25,29,30,37],[31],[32,34,35],[33,36]]
  let output_ranks : Array[Array[Int]] = [[3],[0,4,5,39,40],[1,6,16,17,41],[2,7,8,15,18,19,38,42],[9,20,26,27],[10,12,13,21,23,24,28],[11,14,22,25,29,30,37],[31],[32,34,35],[33,36]]
  let node_names : Array[String?] = []
  let node_clusters : Array[String?] = []
  let node_cluster_skeleton : Array[Bool] = []
  for _ in 0..<43 {
    node_names.push(None)
    node_clusters.push(None)
    node_cluster_skeleton.push(false)
  }
  let edges : Array[MincrossEdge] = [
    { tail: 0, head: 1, xpenalty: 1, seq: 6, order: 0, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 1, head: 2, xpenalty: 1, seq: 7, order: 1, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 3, head: 0, xpenalty: 1, seq: 1, order: 2, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 3, head: 4, xpenalty: 1, seq: 2, order: 3, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 3, head: 5, xpenalty: 1, seq: 3, order: 4, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 3, head: 39, xpenalty: 1, seq: 4, order: 5, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 3, head: 40, xpenalty: 1, seq: 5, order: 6, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 5, head: 6, xpenalty: 1, seq: 8, order: 7, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 5, head: 16, xpenalty: 1, seq: 9, order: 8, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 5, head: 17, xpenalty: 1, seq: 10, order: 9, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 6, head: 7, xpenalty: 1, seq: 11, order: 10, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 6, head: 8, xpenalty: 1, seq: 12, order: 11, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 6, head: 15, xpenalty: 1, seq: 13, order: 12, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 8, head: 9, xpenalty: 1, seq: 14, order: 13, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 9, head: 10, xpenalty: 1, seq: 15, order: 14, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 9, head: 12, xpenalty: 1, seq: 16, order: 15, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 9, head: 13, xpenalty: 1, seq: 17, order: 16, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 10, head: 11, xpenalty: 1, seq: 18, order: 17, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 13, head: 14, xpenalty: 1, seq: 19, order: 18, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 17, head: 18, xpenalty: 1, seq: 20, order: 19, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 17, head: 19, xpenalty: 1, seq: 21, order: 20, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 17, head: 38, xpenalty: 1, seq: 22, order: 21, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 19, head: 20, xpenalty: 1, seq: 23, order: 22, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 19, head: 26, xpenalty: 1, seq: 24, order: 23, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 19, head: 27, xpenalty: 1, seq: 25, order: 24, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 20, head: 21, xpenalty: 1, seq: 26, order: 25, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 20, head: 23, xpenalty: 1, seq: 27, order: 26, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 20, head: 24, xpenalty: 1, seq: 28, order: 27, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 21, head: 22, xpenalty: 1, seq: 29, order: 28, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 24, head: 25, xpenalty: 1, seq: 30, order: 29, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 27, head: 28, xpenalty: 1, seq: 31, order: 30, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 28, head: 29, xpenalty: 1, seq: 32, order: 31, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 28, head: 30, xpenalty: 1, seq: 33, order: 32, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 28, head: 37, xpenalty: 1, seq: 34, order: 33, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 30, head: 31, xpenalty: 1, seq: 35, order: 34, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 31, head: 32, xpenalty: 1, seq: 36, order: 35, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 31, head: 34, xpenalty: 1, seq: 37, order: 36, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 31, head: 35, xpenalty: 1, seq: 38, order: 37, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 32, head: 33, xpenalty: 1, seq: 39, order: 38, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 35, head: 36, xpenalty: 1, seq: 40, order: 39, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 40, head: 41, xpenalty: 1, seq: 41, order: 40, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 41, head: 42, xpenalty: 1, seq: 42, order: 41, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
  ]
  build_exact_layered_rank_reorder_case(
    1011,
    "wide_normal_tree_stable",
    0,
    false,
    0,
    input_ranks,
    output_ranks,
    node_names,
    node_clusters,
    node_cluster_skeleton,
    edges,
  )
}

///|
test "rank_reorder preserves wide normal tree order when layering is already stable" {
  let (input, output) = wide_normal_tree_rank_reorder_case()
  run_fixed_rank_reorder_case(input, output)
}

///|
/// Graphviz parity: this clustered-skeleton tree is the smallest remaining
/// changed integrated mincross case. Keep exact owner-local coverage so the
/// fixture replay can focus on denser clustered reorder interactions.
fn clustered_skeleton_tree_rank_reorder_case() -> (MincrossInput, MincrossOutput) {
  let input_ranks : Array[Array[Int]] = [[29],[28],[7,24],[6,8,23,25,27],[0,5,22,10,26],[1,3,4,21,9,11],[2,12],[13],[14],[15],[16],[17],[18],[19],[20]]
  let output_ranks : Array[Array[Int]] = [[29],[28],[7,24],[8,6,23,27,25],[5,0,10,22,26],[4,1,3,9,11,21],[2,12],[13],[14],[15],[16],[17],[18],[19],[20]]
  let node_names : Array[String?] = []
  let node_clusters : Array[String?] = []
  let node_cluster_skeleton : Array[Bool] = []
  for _ in 0..<30 {
    node_names.push(None)
    node_clusters.push(None)
    node_cluster_skeleton.push(false)
  }
  node_clusters[0] = Some("cluster_clients_mobvm_a")
  node_cluster_skeleton[0] = true
  node_clusters[2] = Some("cluster_machsrv")
  node_cluster_skeleton[2] = true
  node_clusters[5] = Some("cluster_prot_asrv")
  node_cluster_skeleton[5] = true
  node_clusters[7] = Some("cluster_clients_prot_a")
  node_cluster_skeleton[7] = true
  node_clusters[10] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[10] = true
  node_clusters[11] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[11] = true
  node_clusters[12] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[12] = true
  node_clusters[13] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[13] = true
  node_clusters[14] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[14] = true
  node_clusters[16] = Some("cluster_space_ship_a")
  node_cluster_skeleton[16] = true
  node_clusters[17] = Some("cluster_space_ship_a")
  node_cluster_skeleton[17] = true
  node_clusters[18] = Some("cluster_space_ship_a")
  node_cluster_skeleton[18] = true
  node_clusters[19] = Some("cluster_space_ship_a")
  node_cluster_skeleton[19] = true
  node_clusters[20] = Some("cluster_space_ship_a")
  node_cluster_skeleton[20] = true
  node_clusters[22] = Some("cluster_accel")
  node_cluster_skeleton[22] = true
  node_clusters[23] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[23] = true
  node_clusters[24] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[24] = true
  node_clusters[26] = Some("cluster_shapeshifter_misc")
  node_cluster_skeleton[26] = true
  node_clusters[28] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[28] = true
  node_clusters[29] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[29] = true
  let edges : Array[MincrossEdge] = [
    { tail: 0, head: 1, xpenalty: 1, seq: 5, order: 0, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 0, head: 3, xpenalty: 1, seq: 4, order: 1, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 1, head: 2, xpenalty: 1, seq: 5, order: 2, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 3, head: 2, xpenalty: 1, seq: 4, order: 3, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 4, head: 2, xpenalty: 1, seq: 3, order: 4, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 5, head: 4, xpenalty: 1, seq: 3, order: 5, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 6, head: 5, xpenalty: 1, seq: 2, order: 6, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 7, head: 6, xpenalty: 1, seq: 2, order: 7, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 7, head: 8, xpenalty: 1, seq: 1, order: 8, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 8, head: 5, xpenalty: 1, seq: 1, order: 9, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 9, head: 2, xpenalty: 1, seq: 14, order: 10, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 10, head: 11, xpenalty: 1000, seq: 0, order: 11, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 10, head: 9, xpenalty: 1, seq: 14, order: 12, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 11, head: 12, xpenalty: 1000, seq: 0, order: 13, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 12, head: 13, xpenalty: 1000, seq: 0, order: 14, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 13, head: 14, xpenalty: 1000, seq: 0, order: 15, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 14, head: 15, xpenalty: 1, seq: 21, order: 16, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 15, head: 16, xpenalty: 1, seq: 21, order: 17, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 16, head: 17, xpenalty: 1000, seq: 0, order: 18, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 17, head: 18, xpenalty: 1000, seq: 0, order: 19, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 18, head: 19, xpenalty: 1000, seq: 0, order: 20, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 19, head: 20, xpenalty: 1000, seq: 0, order: 21, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 21, head: 12, xpenalty: 1, seq: 8, order: 22, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 22, head: 21, xpenalty: 1, seq: 8, order: 23, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 23, head: 10, xpenalty: 1000, seq: 0, order: 24, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 24, head: 23, xpenalty: 1000, seq: 0, order: 25, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 24, head: 25, xpenalty: 1, seq: 16, order: 26, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 24, head: 27, xpenalty: 1, seq: 15, order: 27, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 25, head: 26, xpenalty: 1, seq: 16, order: 28, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 27, head: 26, xpenalty: 1, seq: 15, order: 29, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 28, head: 24, xpenalty: 1000, seq: 0, order: 30, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 29, head: 28, xpenalty: 1000, seq: 0, order: 31, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
  ]
  build_exact_layered_rank_reorder_case(
    1012,
    "clustered_skeleton_tree_reorder",
    0,
    false,
    0,
    input_ranks,
    output_ranks,
    node_names,
    node_clusters,
    node_cluster_skeleton,
    edges,
  )
}

///|
test "rank_reorder reorders clustered skeleton tree to reduce crossings" {
  let (input, output) = clustered_skeleton_tree_rank_reorder_case()
  run_mincross_case_with_name_order(input, output, Map::new())
}

///|
/// Graphviz parity: this is a stable named multi-cluster slice behind the
/// yours_truly integrated fixture at startpass=2. Keep an exact owner-local
/// test so fixture replay can focus on larger changed reorder cases.
fn stable_named_cluster_rank_reorder_case() -> (MincrossInput, MincrossOutput) {
  let input_ranks : Array[Array[Int]] = [[20],[18,17,19],[30,31,15,14,16],[38,37,13,12,26,43,42],[29,33,32,11,25,27,9,10],[36,34,35,39,24,41],[28,23],[22],[21],[40],[4],[3,2],[1,0],[8,7],[6,5]]
  let output_ranks : Array[Array[Int]] = [[20],[18,17,19],[30,31,15,14,16],[38,37,13,12,26,43,42],[29,33,32,11,25,27,9,10],[36,34,35,39,24,41],[28,23],[22],[21],[40],[4],[3,2],[1,0],[8,7],[6,5]]
  let node_names : Array[String?] = [Some("yyy_worker"), Some("zzz_worker"), None, None, Some("foo_agent"), Some("yyy"), Some("zzz"), None, None, Some("handle_1"), Some("handle_x"), Some("other_xprot"), None, None, Some("front_end_jz"), None, Some("others"), None, None, None, Some("arbiter_vadam"), Some("tunnel_egress"), None, Some("accel"), None, Some("tunnel_ingress"), None, Some("accel_appearance"), Some("machsrv_xprot_gen"), Some("z_shapeshifter"), Some("z_req1"), Some("z_req"), Some("mobvm_a_req1"), Some("mobvm_a_req"), None, None, None, None, None, None, None, None, None, None]
  let node_clusters : Array[String?] = [Some("cluster_piston"), Some("cluster_piston"), Some("cluster_piston"), Some("cluster_piston"), Some("cluster_piston"), Some("cluster_tungsten"), Some("cluster_tungsten"), Some("cluster_space_ship_a"), Some("cluster_space_ship_a"), Some("cluster_shapeshifter_misc"), Some("cluster_shapeshifter_misc"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_frontend"), Some("cluster_tunnel"), Some("cluster_tunnel"), Some("cluster_tunnel"), Some("cluster_tunnel"), Some("cluster_tunnel"), Some("cluster_yours_trulybox"), Some("cluster_accel"), Some("cluster_machsrv"), Some("cluster_prot_asrv"), Some("cluster_clients_prot_a"), Some("cluster_clients_prot_a"), Some("cluster_clients_mobvm_a"), Some("cluster_clients_mobvm_a"), Some("yours_truly"), Some("yours_truly"), Some("yours_truly"), Some("yours_truly"), Some("yours_truly"), Some("yours_truly"), Some("yours_truly"), Some("yours_truly"), Some("yours_truly"), Some("yours_truly")]
  let node_cluster_skeleton : Array[Bool] = [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
  let edges : Array[MincrossEdge] = [
    { tail: 0, head: 7, xpenalty: 1, seq: 20, order: 0, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 1, head: 8, xpenalty: 1, seq: 19, order: 1, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 2, head: 0, xpenalty: 1, seq: 18, order: 2, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 3, head: 1, xpenalty: 1, seq: 17, order: 3, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 4, head: 3, xpenalty: 1, seq: 17, order: 4, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 4, head: 2, xpenalty: 1, seq: 18, order: 5, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 7, head: 5, xpenalty: 1, seq: 20, order: 6, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 8, head: 6, xpenalty: 1, seq: 19, order: 7, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 11, head: 39, xpenalty: 1, seq: 14, order: 8, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 12, head: 11, xpenalty: 1, seq: 13, order: 9, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 13, head: 11, xpenalty: 1, seq: 9, order: 10, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 14, head: 12, xpenalty: 1, seq: 13, order: 11, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 14, head: 26, xpenalty: 1, seq: 12, order: 12, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 15, head: 13, xpenalty: 1, seq: 9, order: 13, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 16, head: 42, xpenalty: 1, seq: 16, order: 14, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 16, head: 43, xpenalty: 1, seq: 15, order: 15, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 17, head: 14, xpenalty: 1, seq: 10, order: 16, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 18, head: 15, xpenalty: 1, seq: 9, order: 17, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 19, head: 16, xpenalty: 1, seq: 11, order: 18, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 20, head: 19, xpenalty: 1, seq: 11, order: 19, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 20, head: 18, xpenalty: 1, seq: 9, order: 20, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 20, head: 17, xpenalty: 1, seq: 10, order: 21, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 21, head: 40, xpenalty: 1, seq: 21, order: 22, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 22, head: 21, xpenalty: 1, seq: 7, order: 23, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 23, head: 22, xpenalty: 1, seq: 7, order: 24, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 24, head: 23, xpenalty: 1, seq: 6, order: 25, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 25, head: 24, xpenalty: 1, seq: 6, order: 26, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 26, head: 25, xpenalty: 1, seq: 12, order: 27, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 27, head: 41, xpenalty: 1, seq: 8, order: 28, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 29, head: 36, xpenalty: 1, seq: 3, order: 29, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 30, head: 38, xpenalty: 1, seq: 1, order: 30, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 31, head: 37, xpenalty: 1, seq: 2, order: 31, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 32, head: 35, xpenalty: 1, seq: 4, order: 32, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 33, head: 34, xpenalty: 1, seq: 5, order: 33, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 34, head: 28, xpenalty: 1, seq: 5, order: 34, tail_port_x: 0, head_port_x: -93.875, tail_port_order: 0, head_port_order: 64 },
    { tail: 35, head: 28, xpenalty: 1, seq: 4, order: 35, tail_port_x: 0, head_port_x: -93.875, tail_port_order: 0, head_port_order: 64 },
    { tail: 36, head: 28, xpenalty: 1, seq: 3, order: 36, tail_port_x: 0, head_port_x: -93.875, tail_port_order: 0, head_port_order: 64 },
    { tail: 37, head: 29, xpenalty: 1, seq: 2, order: 37, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 38, head: 29, xpenalty: 1, seq: 1, order: 38, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 39, head: 28, xpenalty: 1, seq: 14, order: 39, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 40, head: 4, xpenalty: 1, seq: 21, order: 40, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 41, head: 23, xpenalty: 1, seq: 8, order: 41, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 42, head: 10, xpenalty: 1, seq: 16, order: 42, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    { tail: 43, head: 9, xpenalty: 1, seq: 15, order: 43, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
  ]
  build_exact_layered_rank_reorder_case(
    1013,
    "stable_named_cluster_reorder",
    2,
    false,
    0,
    input_ranks,
    output_ranks,
    node_names,
    node_clusters,
    node_cluster_skeleton,
    edges,
  )
}

///|
test "rank_reorder preserves stable named multi-cluster layout at startpass 2" {
  let (input, output) = stable_named_cluster_rank_reorder_case()
  run_mincross_case_with_name_order(input, output, Map::new())
}

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

///|
test "rank_reorder applies external anchor order on both plugin input and output ranks" {
  let input : MincrossInput = {
    case_id: 1009,
    graph: "plugin_bidirectional_anchor_order",
    startpass: 2,
    flip: false,
    minrank: 0,
    maxrank: 2,
    nodes: [
      {
        id: 0,
        name: Some("i_gd"),
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [6],
        in_neighbors: [],
        out_all_neighbors: ["router_gd", "router_lasi", "router_ps"],
        in_all_neighbors: ["fmt_in_gd"],
      },
      {
        id: 1,
        name: Some("i_gd2"),
        rank: 0,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [6],
        in_neighbors: [],
        out_all_neighbors: ["router_gd", "router_lasi", "router_ps"],
        in_all_neighbors: ["fmt_in_gd2"],
      },
      {
        id: 2,
        name: Some("i_gif"),
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [6],
        in_neighbors: [],
        out_all_neighbors: ["router_gd", "router_lasi", "router_ps"],
        in_all_neighbors: ["fmt_in_gif"],
      },
      {
        id: 3,
        name: Some("i_jpg"),
        rank: 0,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [6],
        in_neighbors: [],
        out_all_neighbors: ["router_gd", "router_lasi", "router_ps"],
        in_all_neighbors: ["fmt_in_jpg"],
      },
      {
        id: 4,
        name: Some("i_png"),
        rank: 0,
        order: 4,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [6],
        in_neighbors: [],
        out_all_neighbors: ["router_gd", "router_lasi", "router_ps"],
        in_all_neighbors: ["fmt_in_png"],
      },
      {
        id: 5,
        name: Some("i_xbm"),
        rank: 0,
        order: 5,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [6],
        in_neighbors: [],
        out_all_neighbors: ["router_gd", "router_lasi", "router_ps"],
        in_all_neighbors: ["fmt_in_xbm"],
      },
      {
        id: 6,
        name: Some("router_gd"),
        rank: 1,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [8, 9, 10, 11, 12, 13],
        in_neighbors: [0, 1, 2, 3, 4, 5],
        out_all_neighbors: ["fmt_out_gd", "fmt_out_gd2", "fmt_out_gif", "fmt_out_jpg", "fmt_out_png", "fmt_out_wbmp"],
        in_all_neighbors: ["i_gd", "i_gd2", "i_gif", "i_jpg", "i_png", "i_xbm"],
      },
      {
        id: 7,
        name: Some("router_vrml"),
        rank: 1,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [14],
        in_neighbors: [],
        out_all_neighbors: ["fmt_out_vrml"],
        in_all_neighbors: ["core_gif", "core_jpg", "core_png"],
      },
      {
        id: 8,
        name: Some("o_gd"),
        rank: 2,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["fmt_out_gd"],
        in_all_neighbors: ["router_gd", "router_cairo"],
      },
      {
        id: 9,
        name: Some("o_gd2"),
        rank: 2,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["fmt_out_gd2"],
        in_all_neighbors: ["router_gd", "router_cairo"],
      },
      {
        id: 10,
        name: Some("o_gif"),
        rank: 2,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["fmt_out_gif"],
        in_all_neighbors: ["router_gd", "router_cairo"],
      },
      {
        id: 11,
        name: Some("o_jpg"),
        rank: 2,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["fmt_out_jpg"],
        in_all_neighbors: ["router_gd", "router_cairo"],
      },
      {
        id: 12,
        name: Some("o_png"),
        rank: 2,
        order: 4,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["fmt_out_png"],
        in_all_neighbors: ["router_gd", "router_cairo"],
      },
      {
        id: 13,
        name: Some("o_wbmp"),
        rank: 2,
        order: 5,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["fmt_out_wbmp"],
        in_all_neighbors: ["router_gd", "router_cairo"],
      },
      {
        id: 14,
        name: Some("o_vrml"),
        rank: 2,
        order: 6,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [7],
        out_all_neighbors: ["fmt_out_vrml"],
        in_all_neighbors: ["router_vrml"],
      },
    ],
    edges: [
      { tail: 0, head: 6, xpenalty: 1, seq: 1, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 1, head: 6, xpenalty: 1, seq: 2, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 2, head: 6, xpenalty: 1, seq: 3, order: 2, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 3, head: 6, xpenalty: 1, seq: 4, order: 3, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 4, head: 6, xpenalty: 1, seq: 5, order: 4, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 5, head: 6, xpenalty: 1, seq: 6, order: 5, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 6, head: 8, xpenalty: 1, seq: 7, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 6, head: 9, xpenalty: 1, seq: 8, order: 1, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 6, head: 10, xpenalty: 1, seq: 9, order: 2, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 6, head: 11, xpenalty: 1, seq: 10, order: 3, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 6, head: 12, xpenalty: 1, seq: 11, order: 4, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 6, head: 13, xpenalty: 1, seq: 12, order: 5, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
      { tail: 7, head: 14, xpenalty: 1, seq: 13, order: 0, tail_port_x: 0.0, head_port_x: 0.0, tail_port_order: 0.0, head_port_order: 0.0 },
    ],
    flat_edges: [],
    ranks: [[0, 1, 2, 3, 4, 5], [6, 7], [8, 9, 10, 11, 12, 13, 14]],
  }
  let output : MincrossOutput = {
    case_id: 1009,
    ranks: [[5, 1, 0, 4, 3, 2], [6, 7], [11, 12, 13, 10, 9, 8, 14]],
  }
  let name_order : Map[String, Int] = Map::new()
  name_order["fmt_in_xbm"] = 1
  name_order["fmt_in_gd2"] = 2
  name_order["fmt_in_gd"] = 3
  name_order["fmt_in_png"] = 4
  name_order["fmt_in_jpg"] = 5
  name_order["fmt_in_gif"] = 6
  name_order["fmt_out_jpg"] = 11
  name_order["fmt_out_png"] = 12
  name_order["fmt_out_wbmp"] = 13
  name_order["fmt_out_gif"] = 14
  name_order["fmt_out_gd2"] = 15
  name_order["fmt_out_gd"] = 16
  name_order["fmt_out_vrml"] = 17

  run_mincross_case_with_name_order(input, output, name_order)
}


///|
/// Graphviz parity: cluster_core plugin ordering emerges from external format
/// anchors on both the input and output sides while several routers only have
/// one-sided connectivity. Keep this as an owner-local direct case so the
/// remaining plugin fixture replay can focus on denser integrated graphs.
fn plugin_cluster_core_anchor_order_case() -> (MincrossInput, MincrossOutput, Map[String, Int]) {
  let input : MincrossInput = {
    case_id: 1010,
    graph: "plugin_cluster_core_anchor_order",
    startpass: 2,
    flip: false,
    minrank: 1,
    maxrank: 3,
    nodes: [
      {
        id: 0,
        name: Some("i-core-(lib)"),
        rank: 1,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [6],
        in_neighbors: [],
        out_all_neighbors: ["r-ps"],
        in_all_neighbors: ["i-(lib)"],
      },
      {
        id: 1,
        name: Some("i-core-gif"),
        rank: 1,
        order: 4,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [7, 8, 9, 10],
        in_neighbors: [],
        out_all_neighbors: ["r-dot", "r-fig", "r-svg", "r-xdot", "%0"],
        in_all_neighbors: ["i-gif"],
      },
      {
        id: 2,
        name: Some("i-core-jpg/jpe/jpeg"),
        rank: 1,
        order: 5,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [7, 8, 9, 10],
        in_neighbors: [],
        out_all_neighbors: ["r-dot", "r-fig", "r-svg", "r-xdot", "%0"],
        in_all_neighbors: ["i-jpg/jpe/jpeg"],
      },
      {
        id: 3,
        name: Some("i-core-png"),
        rank: 1,
        order: 6,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [7, 8, 9, 10],
        in_neighbors: [],
        out_all_neighbors: ["r-dot", "r-fig", "r-svg", "r-xdot", "%0"],
        in_all_neighbors: ["i-png"],
      },
      {
        id: 4,
        name: Some("i-core-ps"),
        rank: 1,
        order: 7,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [7, 6, 10],
        in_neighbors: [],
        out_all_neighbors: ["r-dot", "r-ps", "r-xdot", "r-lasi"],
        in_all_neighbors: ["i-ps"],
      },
      {
        id: 5,
        name: Some("i-core-svg"),
        rank: 1,
        order: 8,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [7, 9, 10],
        in_neighbors: [],
        out_all_neighbors: ["r-dot", "r-svg", "r-xdot"],
        in_all_neighbors: ["i-svg"],
      },
      {
        id: 6,
        name: Some("r-ps"),
        rank: 2,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [14, 15, 16],
        in_neighbors: [0, 4],
        out_all_neighbors: ["o-core-eps", "o-core-ps", "o-core-ps2"],
        in_all_neighbors: ["i-core-(lib)", "i-core-ps", "%0", "%0"],
      },
      {
        id: 7,
        name: Some("r-dot"),
        rank: 2,
        order: 4,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [17, 18, 19, 20, 21],
        in_neighbors: [1, 2, 3, 4, 5],
        out_all_neighbors: ["o-core-canon", "o-core-dot", "o-core-gv", "o-core-plain", "o-core-plain-ext"],
        in_all_neighbors: ["i-core-gif", "i-core-jpg/jpe/jpeg", "i-core-png", "i-core-ps", "i-core-svg"],
      },
      {
        id: 8,
        name: Some("r-fig"),
        rank: 2,
        order: 5,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [22],
        in_neighbors: [1, 2, 3],
        out_all_neighbors: ["o-core-fig"],
        in_all_neighbors: ["i-core-gif", "i-core-jpg/jpe/jpeg", "i-core-png"],
      },
      {
        id: 9,
        name: Some("r-svg"),
        rank: 2,
        order: 6,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [23, 24],
        in_neighbors: [1, 2, 3, 5],
        out_all_neighbors: ["o-core-svg", "o-core-svgz"],
        in_all_neighbors: ["i-core-gif", "i-core-jpg/jpe/jpeg", "i-core-png", "i-core-svg"],
      },
      {
        id: 10,
        name: Some("r-xdot"),
        rank: 2,
        order: 7,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [25],
        in_neighbors: [1, 2, 3, 4, 5],
        out_all_neighbors: ["o-core-xdot"],
        in_all_neighbors: ["i-core-gif", "i-core-jpg/jpe/jpeg", "i-core-png", "i-core-ps", "i-core-svg"],
      },
      {
        id: 11,
        name: Some("r-map"),
        rank: 2,
        order: 8,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [26, 27, 28, 29, 30, 31],
        in_neighbors: [],
        out_all_neighbors: ["o-core-cmap", "o-core-cmapx", "o-core-cmapx_np", "o-core-imap", "o-core-imap_np", "o-core-ismap"],
        in_all_neighbors: [],
      },
      {
        id: 12,
        name: Some("r-tk"),
        rank: 2,
        order: 9,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [32],
        in_neighbors: [],
        out_all_neighbors: ["o-core-tk"],
        in_all_neighbors: [],
      },
      {
        id: 13,
        name: Some("r-vml"),
        rank: 2,
        order: 10,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [33, 34],
        in_neighbors: [],
        out_all_neighbors: ["o-core-vml", "o-core-vmlz"],
        in_all_neighbors: [],
      },
      {
        id: 14,
        name: Some("o-core-eps"),
        rank: 3,
        order: 14,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["o-eps"],
        in_all_neighbors: ["r-ps"],
      },
      {
        id: 15,
        name: Some("o-core-ps"),
        rank: 3,
        order: 15,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["o-ps"],
        in_all_neighbors: ["r-ps"],
      },
      {
        id: 16,
        name: Some("o-core-ps2"),
        rank: 3,
        order: 16,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [6],
        out_all_neighbors: ["o-ps2"],
        in_all_neighbors: ["r-ps"],
      },
      {
        id: 17,
        name: Some("o-core-canon"),
        rank: 3,
        order: 17,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [7],
        out_all_neighbors: ["o-canon"],
        in_all_neighbors: ["r-dot"],
      },
      {
        id: 18,
        name: Some("o-core-dot"),
        rank: 3,
        order: 18,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [7],
        out_all_neighbors: ["o-dot"],
        in_all_neighbors: ["r-dot"],
      },
      {
        id: 19,
        name: Some("o-core-gv"),
        rank: 3,
        order: 19,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [7],
        out_all_neighbors: ["o-gv"],
        in_all_neighbors: ["r-dot"],
      },
      {
        id: 20,
        name: Some("o-core-plain"),
        rank: 3,
        order: 20,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [7],
        out_all_neighbors: ["o-plain"],
        in_all_neighbors: ["r-dot"],
      },
      {
        id: 21,
        name: Some("o-core-plain-ext"),
        rank: 3,
        order: 21,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [7],
        out_all_neighbors: ["o-plain-ext"],
        in_all_neighbors: ["r-dot"],
      },
      {
        id: 22,
        name: Some("o-core-fig"),
        rank: 3,
        order: 22,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [8],
        out_all_neighbors: ["o-fig"],
        in_all_neighbors: ["r-fig"],
      },
      {
        id: 23,
        name: Some("o-core-svg"),
        rank: 3,
        order: 23,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [9],
        out_all_neighbors: ["o-svg"],
        in_all_neighbors: ["r-svg"],
      },
      {
        id: 24,
        name: Some("o-core-svgz"),
        rank: 3,
        order: 24,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [9],
        out_all_neighbors: ["o-svgz"],
        in_all_neighbors: ["r-svg"],
      },
      {
        id: 25,
        name: Some("o-core-xdot"),
        rank: 3,
        order: 25,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [10],
        out_all_neighbors: ["o-xdot"],
        in_all_neighbors: ["r-xdot"],
      },
      {
        id: 26,
        name: Some("o-core-cmap"),
        rank: 3,
        order: 26,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [11],
        out_all_neighbors: ["o-cmap"],
        in_all_neighbors: ["r-map"],
      },
      {
        id: 27,
        name: Some("o-core-cmapx"),
        rank: 3,
        order: 27,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [11],
        out_all_neighbors: ["o-cmapx"],
        in_all_neighbors: ["r-map"],
      },
      {
        id: 28,
        name: Some("o-core-cmapx_np"),
        rank: 3,
        order: 28,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [11],
        out_all_neighbors: ["o-cmapx_np"],
        in_all_neighbors: ["r-map"],
      },
      {
        id: 29,
        name: Some("o-core-imap"),
        rank: 3,
        order: 29,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [11],
        out_all_neighbors: ["o-imap"],
        in_all_neighbors: ["r-map"],
      },
      {
        id: 30,
        name: Some("o-core-imap_np"),
        rank: 3,
        order: 30,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [11],
        out_all_neighbors: ["o-imap_np"],
        in_all_neighbors: ["r-map"],
      },
      {
        id: 31,
        name: Some("o-core-ismap"),
        rank: 3,
        order: 31,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [11],
        out_all_neighbors: ["o-ismap"],
        in_all_neighbors: ["r-map"],
      },
      {
        id: 32,
        name: Some("o-core-tk"),
        rank: 3,
        order: 32,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [12],
        out_all_neighbors: ["o-tk"],
        in_all_neighbors: ["r-tk"],
      },
      {
        id: 33,
        name: Some("o-core-vml"),
        rank: 3,
        order: 33,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [13],
        out_all_neighbors: ["o-vml"],
        in_all_neighbors: ["r-vml"],
      },
      {
        id: 34,
        name: Some("o-core-vmlz"),
        rank: 3,
        order: 34,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [13],
        out_all_neighbors: ["o-vmlz"],
        in_all_neighbors: ["r-vml"],
      },
    ],
    edges: [
      { tail: 0, head: 6, xpenalty: 1, seq: 6, order: 0, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 1, head: 7, xpenalty: 1, seq: 8, order: 1, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 1, head: 8, xpenalty: 1, seq: 9, order: 2, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 1, head: 9, xpenalty: 1, seq: 10, order: 3, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 1, head: 10, xpenalty: 1, seq: 12, order: 4, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 2, head: 7, xpenalty: 1, seq: 14, order: 5, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 2, head: 8, xpenalty: 1, seq: 15, order: 6, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 2, head: 9, xpenalty: 1, seq: 16, order: 7, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 2, head: 10, xpenalty: 1, seq: 18, order: 8, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 3, head: 7, xpenalty: 1, seq: 20, order: 9, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 3, head: 8, xpenalty: 1, seq: 21, order: 10, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 3, head: 9, xpenalty: 1, seq: 22, order: 11, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 3, head: 10, xpenalty: 1, seq: 24, order: 12, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 4, head: 7, xpenalty: 1, seq: 26, order: 13, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 4, head: 6, xpenalty: 1, seq: 28, order: 14, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 4, head: 10, xpenalty: 1, seq: 29, order: 15, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 5, head: 7, xpenalty: 1, seq: 31, order: 16, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 5, head: 9, xpenalty: 1, seq: 32, order: 17, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 5, head: 10, xpenalty: 1, seq: 33, order: 18, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 6, head: 14, xpenalty: 1, seq: 78, order: 19, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 6, head: 15, xpenalty: 1, seq: 94, order: 20, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 6, head: 16, xpenalty: 1, seq: 96, order: 21, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 7, head: 17, xpenalty: 1, seq: 68, order: 22, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 7, head: 18, xpenalty: 1, seq: 76, order: 23, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 7, head: 19, xpenalty: 1, seq: 82, order: 24, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 7, head: 20, xpenalty: 1, seq: 90, order: 25, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 7, head: 21, xpenalty: 1, seq: 92, order: 26, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 8, head: 22, xpenalty: 1, seq: 80, order: 27, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 9, head: 23, xpenalty: 1, seq: 98, order: 28, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 9, head: 24, xpenalty: 1, seq: 100, order: 29, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 10, head: 25, xpenalty: 1, seq: 108, order: 30, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 11, head: 26, xpenalty: 1, seq: 70, order: 31, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 11, head: 27, xpenalty: 1, seq: 72, order: 32, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 11, head: 28, xpenalty: 1, seq: 74, order: 33, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 11, head: 29, xpenalty: 1, seq: 84, order: 34, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 11, head: 30, xpenalty: 1, seq: 86, order: 35, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 11, head: 31, xpenalty: 1, seq: 88, order: 36, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 12, head: 32, xpenalty: 1, seq: 102, order: 37, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 13, head: 33, xpenalty: 1, seq: 104, order: 38, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
      { tail: 13, head: 34, xpenalty: 1, seq: 106, order: 39, tail_port_x: 0, head_port_x: 0, tail_port_order: 0, head_port_order: 0 },
    ],
    flat_edges: [],
    ranks: [[0,1,2,3,4,5],[6,7,8,9,10,11,12,13],[14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34]],
  }
  
  let output : MincrossOutput = { case_id: 1010, ranks: [[0,4,5,3,2,1],[6,10,9,13,12,7,8,11],[15,16,14,25,23,24,34,33,32,21,20,19,18,17,22,31,30,29,28,27,26]] }
  
  let name_order : Map[String, Int] = Map::new()
  name_order["r-lasi"] = 1
  name_order["i-svg"] = 3
  name_order["i-png"] = 4
  name_order["i-jpg/jpe/jpeg"] = 5
  name_order["i-gif"] = 6
  name_order["r-svg"] = 6
  name_order["i-ps"] = 7
  name_order["i-(lib)"] = 8
  name_order["o-svg"] = 15
  name_order["o-ps"] = 16
  name_order["o-ps2"] = 17
  name_order["o-eps"] = 18
  name_order["o-xdot"] = 19
  name_order["o-vmlz"] = 20
  name_order["o-vml"] = 21
  name_order["o-tk"] = 22
  name_order["o-svgz"] = 23
  name_order["o-plain-ext"] = 24
  name_order["o-plain"] = 25
  name_order["o-ismap"] = 26
  name_order["o-imap_np"] = 27
  name_order["o-imap"] = 28
  name_order["o-gv"] = 29
  name_order["o-fig"] = 30
  name_order["o-dot"] = 31
  name_order["o-cmapx_np"] = 32
  name_order["o-cmapx"] = 33
  name_order["o-cmap"] = 34
  name_order["o-core-vmlz"] = 34
  name_order["o-canon"] = 35
  (input, output, name_order)
}

///|
test "rank_reorder aligns plugin cluster-core routers and outputs to external anchor order" {
  let (input, output, name_order) = plugin_cluster_core_anchor_order_case()
  run_mincross_case_with_name_order(input, output, name_order)
}
