///|
struct RankFixtureNode {
  id : Int
  name : Json
  kind : String
  rank : Int
} derive(FromJson)

///|
struct RankFixtureEdge {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
  seq : Int
  in_pos : Int
} derive(FromJson)

///|
struct SimplexInput {
  case_id : Int
  balance : Int
  nodes : Array[RankFixtureNode]
  edges : Array[RankFixtureEdge]
}

///|
struct SimplexOutput {
  case_id : Int
  ranks : Array[Int]
}

///|
struct SimplexTree {
  case_id : Int
  edges : Array[Int]
}

///|
struct SimplexPreBalance {
  case_id : Int
  ranks : Array[Int]
}

///|
struct SimplexCase {
  input : SimplexInput
  tree_edges : Array[Int]
  pre_balance : Array[Int]
  output : SimplexOutput
}

///|
fn require_object(json : Json) -> Map[String, Json] raise {
  match json {
    Json::Object(obj) => obj
    _ => fail("expected JSON object")
  }
}

///|
fn parse_simplex_input(obj : Map[String, Json]) -> SimplexInput raise {
  {
    case_id: @json.from_json(obj["case"]),
    balance: @json.from_json(obj["balance"]),
    nodes: @json.from_json(obj["nodes"]),
    edges: @json.from_json(obj["edges"]),
  }
}

///|
fn parse_simplex_output(obj : Map[String, Json]) -> SimplexOutput raise {
  {
    case_id: @json.from_json(obj["case"]),
    ranks: @json.from_json(obj["ranks"]),
  }
}

///|
fn parse_simplex_tree(obj : Map[String, Json]) -> SimplexTree raise {
  {
    case_id: @json.from_json(obj["case"]),
    edges: @json.from_json(obj["edges"]),
  }
}

///|
fn parse_simplex_pre_balance(obj : Map[String, Json]) -> SimplexPreBalance raise {
  {
    case_id: @json.from_json(obj["case"]),
    ranks: @json.from_json(obj["ranks"]),
  }
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
fn parse_acyclic_reverse(obj : Map[String, Json]) -> String raise {
  let graph : Int = @json.from_json(obj["graph"])
  let tail : String = @json.from_json(obj["tail"])
  let head : String = @json.from_json(obj["head"])
  "\{graph}:\{tail}->\{head}"
}

///|
fn load_rank_fixtures(
) -> (Array[SimplexCase], Array[String]) raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/rank.jsonl")
  let cases : Array[SimplexCase] = []
  let reversals : Array[String] = []
  let mut pending : SimplexInput? = None
  let mut pending_tree : SimplexTree? = None
  let mut pending_pre_balance : SimplexPreBalance? = None
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line)
    let obj = require_object(json)
    let event : String = @json.from_json(obj["event"])
    match event {
      "acyclic_start" => ()
      "acyclic_reverse" => {
        reversals.push(parse_acyclic_reverse(obj))
      }
      "simplex_input" => {
        if pending is Some(_) {
          fail("unexpected simplex_input while pending")
        }
        pending = Some(parse_simplex_input(obj))
        pending_tree = None
        pending_pre_balance = None
      }
      "simplex_tree" => {
        let tree = parse_simplex_tree(obj)
        match pending {
          Some(input) =>
            if input.case_id != tree.case_id {
              fail(
                "simplex tree mismatch input=\{input.case_id} tree=\{tree.case_id}",
              )
            }
          None => fail("simplex_tree without simplex_input")
        }
        pending_tree = Some(tree)
      }
      "simplex_pre_balance" => {
        let pre_balance = parse_simplex_pre_balance(obj)
        match pending {
          Some(input) =>
            if input.case_id != pre_balance.case_id {
              fail(
                "simplex pre_balance mismatch input=\{input.case_id} pre_balance=\{pre_balance.case_id}",
              )
            }
          None => fail("simplex_pre_balance without simplex_input")
        }
        pending_pre_balance = Some(pre_balance)
      }
      "simplex_output" => {
        let output = parse_simplex_output(obj)
        match pending {
          Some(input) => {
            if input.case_id != output.case_id {
              fail(
                "simplex case mismatch input=\{input.case_id} output=\{output.case_id}",
              )
            }
            let tree = match pending_tree {
              Some(value) => value
              None => fail("missing simplex_tree for case \{input.case_id}")
            }
            let pre_balance = match pending_pre_balance {
              Some(value) => value
              None =>
                fail("missing simplex_pre_balance for case \{input.case_id}")
            }
            cases.push({
              input,
              tree_edges: tree.edges,
              pre_balance: pre_balance.ranks,
              output,
            })
            pending = None
            pending_tree = None
            pending_pre_balance = None
          }
          None => fail("simplex_output without simplex_input")
        }
      }
      _ => fail("unknown rank fixture event: \{event}")
    }
  }
  match pending {
    Some(_) => fail("missing simplex_output for last case")
    None => ()
  }
  (cases, reversals)
}

///|
fn assert_ranks(
  case_id : Int,
  actual : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  if actual.length() != expected.length() {
    fail(
      "case \{case_id} rank length mismatch actual=\{actual.length()} expected=\{expected.length()}",
    )
  }
  let base_diff = actual[0] - expected[0]
  let mut uniform_diff = true
  let mut min_diff = base_diff
  let mut max_diff = base_diff
  let mut mismatch_count = 0
  for i in 0..<expected.length() {
    let diff = actual[i] - expected[i]
    if diff != base_diff {
      uniform_diff = false
    }
    if diff != 0 {
      mismatch_count = mismatch_count + 1
    }
    if diff < min_diff {
      min_diff = diff
    }
    if diff > max_diff {
      max_diff = diff
    }
  }
  for i in 0..<expected.length() {
    let actual_rank = actual[i]
    let expected_rank = expected[i]
    if actual_rank != expected_rank {
      fail(
        "case \{case_id} rank[\{i}] expected=\{expected_rank} actual=\{actual_rank} base_diff=\{base_diff} uniform_diff=\{uniform_diff} diff_range=[\{min_diff},\{max_diff}] mismatch_count=\{mismatch_count}",
      )
    }
  }
}

///|
fn build_fixture_graph(input : SimplexInput) -> NsGraph raise {
  let graph = new_graph()
  for node in input.nodes {
    let name = match node.name {
      Json::Null => ""
      Json::String(value) => value
      _ => fail("unexpected node name payload")
    }
    let kind = fixture_node_kind(node.kind)
    let idx = add_node(graph, name, kind=kind)
    if idx != node.id {
      fail(
        "case \{input.case_id} node id mismatch expected=\{node.id} actual=\{idx}",
      )
    }
    set_node_rank(graph, idx, node.rank)
  }
  let in_positions : Array[Int] = []
  for edge in input.edges {
    if edge.seq < 0 {
      fail("case \{input.case_id} negative edge seq \{edge.seq}")
    }
    let _ = add_edge(graph, edge.tail, edge.head, edge.minlen, edge.weight)
    in_positions.push(edge.in_pos)
  }
  for i in 0..<graph.nodes.length() {
    graph.nodes[i].in_edges.sort_by((a, b) => {
      let a_pos = in_positions[a]
      let b_pos = in_positions[b]
      if a_pos < b_pos {
        -1
      } else if a_pos > b_pos {
        1
      } else if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    })
  }
  graph
}

///|
fn run_simplex_case(input : SimplexInput, output : SimplexOutput) -> Unit raise {
  let graph = build_fixture_graph(input)
  match input.balance {
    0 => {
      if !network_simplex_pre_balance(graph, 0x7fffffff) {
        fail("case \{input.case_id} network_simplex_pre_balance failed")
      }
      let _ = normalize_ranks_for_test(graph)
    }
    2 => network_simplex(graph, 0x7fffffff, BalanceMode::LR)
    _ => network_simplex(graph, 0x7fffffff, BalanceMode::TB)
  }
  let actual_ranks : Array[Int] = []
  for i in 0..<input.nodes.length() {
    actual_ranks.push(node_rank(graph, i))
  }
  assert_ranks(input.case_id, actual_ranks, output.ranks)
}

///|
fn assert_tree_edges(
  case_id : Int,
  actual : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  assert_eq(expected.length(), actual.length())
  for i in 0..<expected.length() {
    if actual[i] != expected[i] {
      fail(
        "case \{case_id} tree_edges[\{i}] expected=\{expected[i]} actual=\{actual[i]}",
      )
    }
  }
}

///|
fn run_feasible_tree_case(case_info : SimplexCase) -> Unit raise {
  let input = case_info.input
  let graph = build_fixture_graph(input)
  if !@network_simplex.build_feasible_tree(graph) {
    fail("case \{input.case_id} feasible_tree failed")
  }
  assert_tree_edges(input.case_id, graph.tree_edges, case_info.tree_edges)
}

///|
fn run_pre_balance_case(case_info : SimplexCase) -> Unit raise {
  let input = case_info.input
  let graph = build_fixture_graph(input)
  if !network_simplex_pre_balance(graph, 0x7fffffff) {
    fail("case \{input.case_id} network_simplex_pre_balance failed")
  }
  let actual_ranks : Array[Int] = []
  for i in 0..<input.nodes.length() {
    actual_ranks.push(node_rank(graph, i))
  }
  assert_ranks(input.case_id, actual_ranks, case_info.pre_balance)
}

///|
fn assert_no_acyclic_reversals(reversals : Array[String]) -> Unit raise {
  if reversals.length() != 0 {
    fail(
      "expected no acyclic reversals, got \{reversals.length()} (first=\{reversals[0]})",
    )
  }
}

///|
test "rank fixtures match network_simplex" {
  let (cases, reversals) = load_rank_fixtures()
  assert_no_acyclic_reversals(reversals)
  for case_info in cases {
    run_simplex_case(case_info.input, case_info.output)
  }
}

///|
test "rank fixtures match feasible_tree" {
  let (cases, reversals) = load_rank_fixtures()
  assert_no_acyclic_reversals(reversals)
  for case_info in cases {
    run_feasible_tree_case(case_info)
  }
}

///|
test "rank fixtures match pre_balance" {
  let (cases, reversals) = load_rank_fixtures()
  assert_no_acyclic_reversals(reversals)
  for case_info in cases {
    run_pre_balance_case(case_info)
  }
}
