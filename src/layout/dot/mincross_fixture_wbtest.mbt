///|
struct MincrossNode {
  id : Int
  name : String?
  rank : Int
  order : Int
  cluster : String?
  cluster_skeleton : Bool
  out_neighbors : Array[Int]
  in_neighbors : Array[Int]
  out_all_neighbors : Array[String]
  in_all_neighbors : Array[String]
}

///|
struct MincrossEdge {
  tail : Int
  head : Int
  xpenalty : Int
  seq : Int
  order : Int
  tail_port_x : Double
  head_port_x : Double
  tail_port_order : Double
  head_port_order : Double
}

///|
struct MincrossFlatEdge {
  tail : Int
  head : Int
}

///|
struct MincrossInput {
  case_id : Int
  graph : String
  startpass : Int
  flip : Bool
  minrank : Int
  maxrank : Int
  nodes : Array[MincrossNode]
  edges : Array[MincrossEdge]
  flat_edges : Array[MincrossFlatEdge]
  ranks : Array[Array[Int]]
}

///|
struct MincrossOutput {
  case_id : Int
  ranks : Array[Array[Int]]
}

///|
struct MincrossFixtures {
  cases : Array[(MincrossInput, MincrossOutput)]
  name_order : Map[String, Int]
}

///|
fn parse_mincross_input(obj : Map[String, Json]) -> MincrossInput raise {
  let startpass =
    match obj.get("startpass") {
      Some(value) => @json.from_json(value)
      None => 0
    }
  let flip =
    match obj.get("flip") {
      Some(value) => @json.from_json(value)
      None => false
    }
  {
    case_id: @json.from_json(obj["case"]),
    graph: @json.from_json(obj["graph"]),
    startpass,
    flip,
    minrank: @json.from_json(obj["minrank"]),
    maxrank: @json.from_json(obj["maxrank"]),
    nodes: parse_mincross_nodes(obj["nodes"]),
    edges: parse_mincross_edges(obj["edges"]),
    flat_edges: parse_optional_flat_edges(obj),
    ranks: @json.from_json(obj["ranks"]),
  }
}

///|
fn parse_mincross_output(obj : Map[String, Json]) -> MincrossOutput raise {
  {
    case_id: @json.from_json(obj["case"]),
    ranks: @json.from_json(obj["ranks"]),
  }
}

///|
fn parse_mincross_nodes(value : Json) -> Array[MincrossNode] raise {
  let items : Array[Json] = @json.from_json(value)
  let nodes : Array[MincrossNode] = []
  for item in items {
    let obj = require_object(item)
    let id : Int = @json.from_json(obj["id"])
    let name =
      match obj.get("name") {
        Some(value) =>
          match value {
            Json::Null => (None : String?)
            Json::String(text) => Some(text)
            _ => fail("unexpected node name payload")
          }
        None => (None : String?)
      }
    let rank : Int = @json.from_json(obj["rank"])
    let order =
      match obj.get("order") {
        Some(value) => @json.from_json(value)
        None => id
      }
    let cluster =
      match obj.get("cluster") {
        Some(value) =>
          match value {
            Json::Null => (None : String?)
            Json::String(text) => Some(text)
            _ => fail("unexpected node cluster payload")
          }
        None => (None : String?)
      }
    let cluster_skeleton =
      match obj.get("cluster_skeleton") {
        Some(value) => @json.from_json(value)
        None => false
      }
    let out_neighbors =
      match obj.get("out_neighbors") {
        Some(value) => @json.from_json(value)
        None =>
          match obj.get("out") {
            Some(value) => @json.from_json(value)
            None => []
          }
      }
    let in_neighbors =
      match obj.get("in_neighbors") {
        Some(value) => @json.from_json(value)
        None =>
          match obj.get("in") {
            Some(value) => @json.from_json(value)
            None => []
          }
      }
    let out_all_neighbors =
      match obj.get("out_all") {
        Some(value) => @json.from_json(value)
        None => []
      }
    let in_all_neighbors =
      match obj.get("in_all") {
        Some(value) => @json.from_json(value)
        None => []
      }
    nodes.push(
      {
        id,
        name,
        rank,
        order,
        cluster,
        cluster_skeleton,
        out_neighbors,
        in_neighbors,
        out_all_neighbors,
        in_all_neighbors,
      },
    )
  }
  nodes
}

///|
fn parse_mincross_edges(value : Json) -> Array[MincrossEdge] raise {
  let items : Array[Json] = @json.from_json(value)
  let edges : Array[MincrossEdge] = []
  for idx, item in items {
    let obj = require_object(item)
    let tail : Int = @json.from_json(obj["tail"])
    let head : Int = @json.from_json(obj["head"])
    let xpenalty : Int = @json.from_json(obj["xpenalty"])
    let order = idx
    let seq =
      match obj.get("seq") {
        Some(value) => @json.from_json(value)
        None => order
      }
    let tail_port_x =
      match obj.get("tail_port_x") {
        Some(value) => @json.from_json(value)
        None => 0.0
      }
    let head_port_x =
      match obj.get("head_port_x") {
        Some(value) => @json.from_json(value)
        None => 0.0
      }
    let tail_port_order =
      match obj.get("tail_port_order") {
        Some(value) => @json.from_json(value)
        None => 0.0
      }
    let head_port_order =
      match obj.get("head_port_order") {
        Some(value) => @json.from_json(value)
        None => 0.0
      }
    edges.push(
      {
        tail,
        head,
        xpenalty,
        seq,
        order,
        tail_port_x,
        head_port_x,
        tail_port_order,
        head_port_order,
      },
    )
  }
  edges
}

///|
fn parse_mincross_flat_edges(value : Json) -> Array[MincrossFlatEdge] raise {
  let items : Array[Json] = @json.from_json(value)
  let edges : Array[MincrossFlatEdge] = []
  for item in items {
    let obj = require_object(item)
    let tail : Int = @json.from_json(obj["tail"])
    let head : Int = @json.from_json(obj["head"])
    edges.push({ tail, head })
  }
  edges
}

///|
fn parse_optional_flat_edges(
  obj : Map[String, Json],
) -> Array[MincrossFlatEdge] raise {
  match obj.get("flat_edges") {
    Some(value) => parse_mincross_flat_edges(value)
    None => []
  }
}

///|
fn load_mincross_fixtures_from(path : String) -> MincrossFixtures raise {
  let data = @fs.read_file_to_string(path)
  let cases : Array[(MincrossInput, MincrossOutput)] = []
  let known_name_order : Map[String, Int] = Map::new()
  let ambiguous_name_order : Map[String, Bool] = Map::new()
  let mut pending : MincrossInput? = None
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line)
    let obj = require_object(json)
    let event : String = @json.from_json(obj["event"])
    match event {
      "mincross_input" => {
        if pending is Some(_) {
          fail("unexpected mincross_input while pending")
        }
        let input = parse_mincross_input(obj)
        for node in input.nodes {
          match node.name {
            Some(name) =>
              if name.length() > 0 && ambiguous_name_order.get(name) is None {
                match known_name_order.get(name) {
                  Some(prev_order) =>
                    if prev_order != node.order {
                      ambiguous_name_order[name] = true
                    }
                  None => known_name_order[name] = node.order
                }
              }
            None => ()
          }
        }
        pending = Some(input)
      }
      "mincross_output" => {
        let output = parse_mincross_output(obj)
        match pending {
          Some(input) => {
            if input.case_id != output.case_id {
              fail(
                "mincross case mismatch input=\{input.case_id} output=\{output.case_id}",
              )
            }
            cases.push((input, output))
            pending = None
          }
          None => fail("mincross_output without mincross_input")
        }
      }
      "mincross_rank" => ()
      "mincross_iter" => ()
      _ => fail("unknown mincross fixture event: \{event}")
    }
  }
  match pending {
    Some(_) => fail("missing mincross_output for last case")
    None => ()
  }
  let stable_name_order : Map[String, Int] = Map::new()
  for name, order in known_name_order {
    if ambiguous_name_order.get(name) is None {
      stable_name_order[name] = order
    }
  }
  { cases, name_order: stable_name_order }
}

///|
fn load_mincross_fixtures() -> MincrossFixtures raise {
  load_mincross_fixtures_from("tests/fixtures/graphviz/mincross.jsonl")
}

///|
fn node_key(id : Int) -> String {
  "n\{id}"
}

///|
fn assert_rank_groups(
  case_id : Int,
  graph : String,
  actual : Array[Array[Int]],
  expected : Array[Array[Int]],
) -> Unit raise {
  if actual.length() != expected.length() {
    fail(
      "case \{case_id} graph=\{graph} rank count mismatch actual=\{actual.length()} expected=\{expected.length()}",
    )
  }
  for i in 0..<expected.length() {
    let actual_rank = actual[i]
    let expected_rank = expected[i]
    if actual_rank.length() != expected_rank.length() {
      fail(
        "case \{case_id} graph=\{graph} rank[\{i}] length mismatch actual=\{actual_rank.length()} expected=\{expected_rank.length()}",
      )
    }
    for j in 0..<expected_rank.length() {
      let actual_id = actual_rank[j]
      let expected_id = expected_rank[j]
      if actual_id != expected_id {
        fail(
          "case \{case_id} graph=\{graph} rank[\{i}] index=\{j} expected=\{expected_id} actual=\{actual_id} expected_rank=\{expected_rank} actual_rank=\{actual_rank}",
        )
      }
    }
  }
}

///|
fn run_mincross_case_with_name_order(
  input : MincrossInput,
  output : MincrossOutput,
  fixture_name_order : Map[String, Int],
) -> Unit raise {
  let graph =
    @cgraph.Graph::new(@cgraph.GraphKind::Directed, name=input.graph, strict=false)
  let id_to_name : Map[Int, String] = Map::new()
  let name_to_id : Map[String, Int] = Map::new()
  let name_to_rank : Map[String, Int] = Map::new()
  let name_to_node : Map[String, @cgraph.Node] = Map::new()
  let name_to_order : Map[String, Int] = Map::new()
  let local_name_to_key : Map[String, String] = Map::new()
  let ambiguous_local_names : Map[String, Bool] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  let nodes : Array[@cgraph.Node] = []
  let default_size = @dot_shared.node_size_from_points(
    @dot_shared.default_node_width_in() * 72.0,
    @dot_shared.default_node_height_in() * 72.0,
  )
  for i, node in input.nodes {
    let name = node_key(node.id)
    id_to_name[node.id] = name
    name_to_id[name] = node.id
    name_to_rank[name] = node.rank
    name_to_order[name] = i
    match node.name {
      Some(local_name) =>
        if local_name.length() > 0 {
          match local_name_to_key.get(local_name) {
            Some(_) => ambiguous_local_names[local_name] = true
            None => local_name_to_key[local_name] = name
          }
        }
      None => ()
    }
    let cnode = graph.node(name)
    name_to_node[name] = cnode
    nodes.push(cnode)
    sizes[name] = default_size
  }
  for name, order in fixture_name_order {
    if name_to_order.get(name) is None {
      name_to_order[name] = order
    }
  }
  let edges : Array[@cgraph.Edge] = []
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_tail_port_x : Array[Double] = []
  let edge_head_port_x : Array[Double] = []
  let edge_tail_port_order : Array[Double] = []
  let edge_head_port_order : Array[Double] = []
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  let append_named_neighbor = (
    neighbors : Array[String],
    raw_name : String,
  ) => {
    if raw_name.length() == 0 {
      return ()
    }
    let push_unique = (name : String) => {
      let mut exists = false
      for existing in neighbors {
        if existing == name {
          exists = true
          break
        }
      }
      if !exists {
        neighbors.push(name)
      }
    }
    if ambiguous_local_names.get(raw_name) is Some(_) {
      if name_to_order.get(raw_name) is Some(_) {
        push_unique(raw_name)
      }
      return ()
    }
    match local_name_to_key.get(raw_name) {
      Some(local_name) => push_unique(local_name)
      None => push_unique(raw_name)
    }
  }
  for node in input.nodes {
    let name = node_key(node.id)
    let out_names : Array[String] = []
    for neighbor_id in node.out_neighbors {
      let neighbor = match id_to_name.get(neighbor_id) {
        Some(value) => value
        None => fail("case \{input.case_id} missing out neighbor id \{neighbor_id}")
      }
      out_names.push(neighbor)
    }
    let in_names : Array[String] = []
    for neighbor_id in node.in_neighbors {
      let neighbor = match id_to_name.get(neighbor_id) {
        Some(value) => value
        None => fail("case \{input.case_id} missing in neighbor id \{neighbor_id}")
      }
      in_names.push(neighbor)
    }
    for raw_name in node.out_all_neighbors {
      append_named_neighbor(out_names, raw_name)
    }
    for raw_name in node.in_all_neighbors {
      append_named_neighbor(in_names, raw_name)
    }
    graphviz_out_neighbors[name] = out_names
    graphviz_in_neighbors[name] = in_names
  }
  let edges_input = input.edges.copy()
  for edge in edges_input {
    let _ = edge.seq
    let _ = edge.order
    let tail_name = match id_to_name.get(edge.tail) {
      Some(value) => value
      None => fail("case \{input.case_id} missing tail id \{edge.tail}")
    }
    let head_name = match id_to_name.get(edge.head) {
      Some(value) => value
      None => fail("case \{input.case_id} missing head id \{edge.head}")
    }
    if edge.xpenalty < 0 {
      fail(
        "case \{input.case_id} graph=\{input.graph} negative xpenalty \{edge.xpenalty}",
      )
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
  if input.ranks.length() != rank_keys.length() {
    fail(
      "case \{input.case_id} graph=\{input.graph} rank list length mismatch expected=\{rank_keys.length()} actual=\{input.ranks.length()}",
    )
  }
  let groups : Map[Int, Array[String]] = Map::new()
  let mut rank = input.minrank
  for rank_nodes in input.ranks {
    let names : Array[String] = []
    for node_id in rank_nodes {
      let name = match id_to_name.get(node_id) {
        Some(value) => value
        None => fail("case \{input.case_id} missing node id \{node_id}")
      }
      let node_rank = match name_to_rank.get(name) {
        Some(value) => value
        None => rank
      }
      if node_rank != rank {
        fail(
          "case \{input.case_id} graph=\{input.graph} node \{node_id} rank mismatch expected=\{rank} actual=\{node_rank}",
        )
      }
      names.push(name)
    }
    groups[rank] = names
    rank = rank + 1
  }
  let edge_index_data =
    @ordering.build_edge_index_for_order(nodes, edges, edge_tail, edge_head, name_to_rank)
  let parents = edge_index_data.parents
  let children = edge_index_data.children
  let edge_order = @ordering.collect_edge_order(edges)
  let nodesep_pt = default_nodesep_in() * 72.0
  let cluster_keys : Map[String, String] = Map::new()
  let cluster_skeleton : Map[String, Bool] = Map::new()
  for node in input.nodes {
    let name = node_key(node.id)
    match node.cluster {
      Some(value) =>
        if value != "" {
          cluster_keys[name] = value
        }
      None => ()
    }
    if node.cluster_skeleton {
      cluster_skeleton[name] = true
    }
  }
  let flat_constraints : Map[String, Bool] = Map::new()
  for edge in input.flat_edges {
    let tail_name = match id_to_name.get(edge.tail) {
      Some(value) => value
      None => fail("case \{input.case_id} missing flat tail id \{edge.tail}")
    }
    let head_name = match id_to_name.get(edge.head) {
      Some(value) => value
      None => fail("case \{input.case_id} missing flat head id \{edge.head}")
    }
    flat_constraints["\{tail_name}|\{head_name}"] = true
  }
  if @sys.get_env_var("TRACE_MINCROSS_SEED") == Some(input.graph) {
    let seeded = build_neighbor_rank_groups(
      rank_keys,
      groups,
      edge_tail,
      edge_head,
      name_to_rank,
      name_to_order,
      cluster_keys,
      cluster_skeleton,
      0,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
    )
    let mut idx = 0
    while idx < rank_keys.length() {
      let key = rank_keys[idx]
      let expected_names = match groups.get(key) {
        Some(list) => list
        None => []
      }
      let seeded_names = match seeded.get(key) {
        Some(list) => list
        None => []
      }
      println(
        "trace mincross seed \{input.graph} rank[\{idx}] expected=\{expected_names} seeded=\{seeded_names}",
      )
      idx = idx + 1
    }
  }
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
    parents,
    children,
    cluster_keys,
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
    cluster_skeleton,
    flat_constraints,
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
      let id = match name_to_id.get(name) {
        Some(value) => value
        None => fail("case \{input.case_id} missing name \{name}")
      }
      ids.push(id)
    }
    actual.push(ids)
  }
  if @sys.get_env_var("TRACE_MINCROSS") == Some(input.graph) {
    let mut idx = 0
    while idx < actual.length() {
      println(
        "trace mincross \{input.graph} rank[\{idx}] actual=\{actual[idx]} expected=\{output.ranks[idx]}",
      )
      idx = idx + 1
    }
  }
  assert_rank_groups(input.case_id, input.graph, actual, output.ranks)
}

///|
fn run_mincross_case(input : MincrossInput, output : MincrossOutput) -> Unit raise {
  run_mincross_case_with_name_order(input, output, Map::new())
}

///|
test "mincross fixtures load" {
  let fixtures = load_mincross_fixtures()
  assert_true(fixtures.cases.length() > 0)
}

///|
test "mincross fixtures match reorder_rank_groups" {
  let fixtures = load_mincross_fixtures()
  for pair in fixtures.cases {
    let (input, output) = pair
    run_mincross_case_with_name_order(input, output, fixtures.name_order)
  }
}

///|
test "mincross plugins fixtures match reorder_rank_groups" {
  let fixtures = load_mincross_fixtures_from(
    "tests/fixtures/graphviz/mincross.plugins.jsonl",
  )
  for pair in fixtures.cases {
    let (input, output) = pair
    run_mincross_case_with_name_order(input, output, fixtures.name_order)
  }
}

///|
test "mincross fixed case preserves initial tie order" {
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
  run_mincross_case(input, output)
}

///|
test "mincross fixed case recovers nlist tie order from reversed seed" {
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
  run_mincross_case(input, output)
}
