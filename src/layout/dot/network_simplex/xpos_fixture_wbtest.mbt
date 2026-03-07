///|
fn fixture_require_object(json : Json) -> Map[String, Json] raise {
  match json {
    Json::Object(obj) => obj
    _ => fail("expected JSON object")
  }
}

///|
fn fixture_json_string_option(value : Json) -> String? raise {
  if value == Json::null() {
    None
  } else {
    Some(@json.from_json(value))
  }
}

///|
fn fixture_build_rank_order_map(ranks : Array[Array[Int]]) -> Map[Int, Int] raise {
  let map : Map[Int, Int] = Map::new()
  let mut rank_idx = 0
  for rank_nodes in ranks {
    let mut order = 0
    for id in rank_nodes {
      if map.get(id) is Some(_) {
        fail("duplicate node id \{id} in rank list \{rank_idx}")
      }
      map[id] = order
      order = order + 1
    }
    rank_idx = rank_idx + 1
  }
  map
}

///|
fn fixture_node_kind(kind : String) -> NodeKind raise {
  match kind {
    "normal" => NodeKind::Normal
    "virtual" => NodeKind::Virtual
    "slack" => NodeKind::Slack
    _ => fail("unknown fixture node kind: \{kind}")
  }
}

///|
struct XposNode {
  id : Int
  name : String?
  kind : String
  rank : Int
  order : Int
  lw : Double
  rw : Double
  ht : Double
}

///|
struct XposEdge {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
struct XposInput {
  case_id : Int
  graph : String
  phase : String
  minrank : Int
  maxrank : Int
  flip : Bool
  ranks : Array[Array[Int]]
  nodes : Array[XposNode]
  edges : Array[XposEdge]
}

///|
struct XposOutput {
  case_id : Int
  positions : Array[Int]
}

///|
fn parse_xpos_input(obj : Map[String, Json]) -> XposInput raise {
  let minrank : Int = @json.from_json(obj["minrank"])
  let maxrank : Int = @json.from_json(obj["maxrank"])
  let phase : String = @json.from_json(obj["phase"])
  let flip : Bool = @json.from_json(obj["flip"])
  let ranks : Array[Array[Int]] = @json.from_json(obj["ranks"])
  {
    case_id: @json.from_json(obj["case"]),
    graph: @json.from_json(obj["graph"]),
    phase,
    minrank,
    maxrank,
    flip,
    ranks,
    nodes: parse_xpos_nodes(obj["nodes"]),
    edges: parse_xpos_edges(obj["edges"]),
  }
}

///|
fn parse_xpos_output(obj : Map[String, Json]) -> XposOutput raise {
  {
    case_id: @json.from_json(obj["case"]),
    positions: @json.from_json(obj["positions"]),
  }
}

///|
fn parse_xpos_nodes(value : Json) -> Array[XposNode] raise {
  let items : Array[Json] = @json.from_json(value)
  let nodes : Array[XposNode] = []
  for item in items {
    let obj = fixture_require_object(item)
    let id : Int = @json.from_json(obj["id"])
    let name : String? = fixture_json_string_option(obj["name"])
    let kind : String = @json.from_json(obj["kind"])
    let rank : Int = @json.from_json(obj["rank"])
    let order : Int = @json.from_json(obj["order"])
    let lw : Double = @json.from_json(obj["lw"])
    let rw : Double = @json.from_json(obj["rw"])
    let ht : Double = @json.from_json(obj["ht"])
    nodes.push({ id, name, kind, rank, order, lw, rw, ht })
  }
  nodes
}

///|
fn parse_xpos_edges(value : Json) -> Array[XposEdge] raise {
  let items : Array[Json] = @json.from_json(value)
  let edges : Array[XposEdge] = []
  for item in items {
    let obj = fixture_require_object(item)
    let tail : Int = @json.from_json(obj["tail"])
    let head : Int = @json.from_json(obj["head"])
    let minlen : Int = @json.from_json(obj["minlen"])
    let weight : Int = @json.from_json(obj["weight"])
    edges.push({ tail, head, minlen, weight })
  }
  edges
}

///|
fn load_xpos_fixtures() -> Array[(XposInput, XposOutput)] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/xpos.jsonl")
  let cases : Array[(XposInput, XposOutput)] = []
  let mut pending : XposInput? = None
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line)
    let obj = fixture_require_object(json)
    let event : String = @json.from_json(obj["event"])
    match event {
      "xpos_input" => {
        if pending is Some(_) {
          fail("unexpected xpos_input while pending")
        }
        pending = Some(parse_xpos_input(obj))
      }
      "xpos_output" => {
        let output = parse_xpos_output(obj)
        match pending {
          Some(input) => {
            if input.case_id != output.case_id {
              fail(
                "xpos case mismatch input=\{input.case_id} output=\{output.case_id}",
              )
            }
            cases.push((input, output))
            pending = None
          }
          None => fail("xpos_output without xpos_input")
        }
      }
      _ => fail("unknown xpos fixture event: \{event}")
    }
  }
  match pending {
    Some(_) => fail("missing xpos_output for last case")
    None => ()
  }
  cases
}

///|
fn assert_xpos_input(input : XposInput) -> Map[Int, Int] raise {
  if input.graph == "" {
    fail("missing xpos graph name")
  }
  if input.phase == "" {
    fail("missing xpos phase")
  }
  if input.minrank > input.maxrank {
    fail("minrank \{input.minrank} > maxrank \{input.maxrank}")
  }
  let expected_rank_count = input.maxrank - input.minrank + 1
  if input.ranks.length() != expected_rank_count {
    fail(
      "rank list count mismatch expected=\{expected_rank_count} actual=\{input.ranks.length()}",
    )
  }
  if input.flip {
    let name = input.graph.to_lower()
    if !name.has_suffix("_lr") && !name.has_suffix("_rl") {
      fail("unexpected flip=true for graph \{input.graph}")
    }
  }
  let order_map = fixture_build_rank_order_map(input.ranks)
  let mut non_slack = 0
  for node in input.nodes {
    if node.kind == "slack" {
      if node.order != 0 {
        fail(
          "slack node order mismatch id=\{node.id} expected=0 actual=\{node.order}",
        )
      }
    } else {
      non_slack = non_slack + 1
      let expected_order = match order_map.get(node.id) {
        Some(value) => value
        None => fail("missing node id \{node.id} in rank list")
      }
      if expected_order != node.order {
        fail(
          "node order mismatch id=\{node.id} expected=\{expected_order} actual=\{node.order}",
        )
      }
    }
    match (node.kind, node.name) {
      ("normal", None) =>
        fail("missing name for normal node id=\{node.id}")
      ("normal", Some(value)) =>
        if value == "" {
          fail("empty name for normal node id=\{node.id}")
        }
      (_, Some(_)) => fail("unexpected name for non-normal node id=\{node.id}")
      _ => ()
    }
    if node.kind == "slack" {
      if node.lw != 1.0 || node.rw != 1.0 || node.ht != 1.0 {
        fail(
          "slack node size mismatch id=\{node.id} lw=\{node.lw} rw=\{node.rw} ht=\{node.ht}",
        )
      }
    } else {
      if node.lw <= 0.0 || node.rw <= 0.0 || node.ht <= 0.0 {
        fail(
          "node size not positive id=\{node.id} lw=\{node.lw} rw=\{node.rw} ht=\{node.ht}",
        )
      }
    }
  }
  if order_map.length() != non_slack {
    fail(
      "rank list size mismatch expected=\{non_slack} actual=\{order_map.length()}",
    )
  }
  order_map
}

///|
fn assert_positions(
  case_id : Int,
  graph : String,
  actual : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  if actual.length() != expected.length() {
    fail(
      "case \{case_id} graph=\{graph} position count mismatch actual=\{actual.length()} expected=\{expected.length()}",
    )
  }
  for i in 0..<expected.length() {
    let actual_pos = actual[i]
    let expected_pos = expected[i]
    if actual_pos != expected_pos {
      fail(
        "case \{case_id} graph=\{graph} pos[\{i}] expected=\{expected_pos} actual=\{actual_pos}",
      )
    }
  }
}

///|
fn run_xpos_case(input : XposInput, output : XposOutput) -> Unit raise {
  let _ = assert_xpos_input(input)
  let graph = new_graph()
  for node in input.nodes {
    let idx = add_node(graph, "", kind=fixture_node_kind(node.kind))
    if idx != node.id {
      fail(
        "case \{input.case_id} graph=\{input.graph} node id mismatch expected=\{node.id} actual=\{idx}",
      )
    }
    set_node_rank(graph, idx, node.rank)
  }
  for edge in input.edges {
    if edge.weight < 0 {
      fail(
        "case \{input.case_id} graph=\{input.graph} negative weight \{edge.weight}",
      )
    }
    let _ = add_edge(graph, edge.tail, edge.head, edge.minlen, edge.weight)
  }
  network_simplex(graph, 0x7fffffff, BalanceMode::LR)
  let actual : Array[Int] = []
  for i in 0..<input.nodes.length() {
    actual.push(node_rank(graph, i))
  }
  assert_positions(input.case_id, input.graph, actual, output.positions)
}

///|
test "xpos fixtures match network_simplex LR" {
  let cases = load_xpos_fixtures()
  for pair in cases {
    let (input, output) = pair
    run_xpos_case(input, output)
  }
}
