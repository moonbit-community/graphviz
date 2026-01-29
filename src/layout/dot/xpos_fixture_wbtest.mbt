///|
struct XposNode {
  id : Int
  kind : String
  rank : Int
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
  let _ : Int = @json.from_json(obj["minrank"])
  let _ : Int = @json.from_json(obj["maxrank"])
  let _ : String = @json.from_json(obj["phase"])
  {
    case_id: @json.from_json(obj["case"]),
    graph: @json.from_json(obj["graph"]),
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
    let obj = require_object(item)
    let id : Int = @json.from_json(obj["id"])
    let kind : String = @json.from_json(obj["kind"])
    let rank : Int = @json.from_json(obj["rank"])
    let _ : Int = @json.from_json(obj["order"])
    let _ : Json = @json.from_json(obj["name"])
    let _ : Double = @json.from_json(obj["lw"])
    let _ : Double = @json.from_json(obj["rw"])
    let _ : Double = @json.from_json(obj["ht"])
    nodes.push({ id, kind, rank })
  }
  nodes
}

///|
fn parse_xpos_edges(value : Json) -> Array[XposEdge] raise {
  let items : Array[Json] = @json.from_json(value)
  let edges : Array[XposEdge] = []
  for item in items {
    let obj = require_object(item)
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
    let obj = require_object(json)
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
test "xpos fixtures load" {
  let cases = load_xpos_fixtures()
  assert_true(cases.length() > 0)
}

///|
test "xpos fixtures match network_simplex LR" {
  let cases = load_xpos_fixtures()
  for pair in cases {
    let (input, output) = pair
    run_xpos_case(input, output)
  }
}
