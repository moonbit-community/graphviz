///|
struct XposConstraintFixtureNode {
  id : Int
  name : String?
  kind : String
  rank : Int
  lw : Double
  rw : Double
}

///|
struct XposConstraintFixtureEdge {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
struct XposConstraintFixtureCluster {
  name : String
  ln : Int?
  rn : Int?
}

///|
struct XposConstraintFixture {
  graph : String
  phase : String
  nodes : Array[XposConstraintFixtureNode]
  edges : Array[XposConstraintFixtureEdge]
  clusters : Array[XposConstraintFixtureCluster]
}

///|
fn require_object_local(json : Json) -> Map[String, Json] raise {
  match json {
    Json::Object(value) => value
    _ => fail("expected JSON object")
  }
}

///|
fn xpos_constraint_int_option(value : Json) -> Int? raise {
  if value == Json::null() {
    None
  } else {
    Some(@json.from_json(value))
  }
}

///|
fn xpos_constraint_string_option(value : Json) -> String? raise {
  if value == Json::null() {
    None
  } else {
    Some(@json.from_json(value))
  }
}

///|
fn parse_constraint_nodes(value : Json) -> Array[XposConstraintFixtureNode] raise {
  let items : Array[Json] = @json.from_json(value)
  let nodes : Array[XposConstraintFixtureNode] = []
  for item in items {
    let obj = require_object_local(item)
    let id : Int = @json.from_json(obj["id"])
    let name : String? = xpos_constraint_string_option(obj["name"])
    let kind : String = @json.from_json(obj["kind"])
    let rank : Int = @json.from_json(obj["rank"])
    let lw : Double = @json.from_json(obj["lw"])
    let rw : Double = @json.from_json(obj["rw"])
    let _ : Double = @json.from_json(obj["ht"])
    nodes.push({ id, name, kind, rank, lw, rw })
  }
  nodes
}

///|
fn parse_constraint_edges(value : Json) -> Array[XposConstraintFixtureEdge] raise {
  let items : Array[Json] = @json.from_json(value)
  let edges : Array[XposConstraintFixtureEdge] = []
  for item in items {
    let obj = require_object_local(item)
    let tail : Int = @json.from_json(obj["tail"])
    let head : Int = @json.from_json(obj["head"])
    let minlen : Int = @json.from_json(obj["minlen"])
    let weight : Int = @json.from_json(obj["weight"])
    edges.push({ tail, head, minlen, weight })
  }
  edges
}

///|
fn parse_constraint_clusters(value : Json) -> Array[XposConstraintFixtureCluster] raise {
  let items : Array[Json] = @json.from_json(value)
  let clusters : Array[XposConstraintFixtureCluster] = []
  for item in items {
    let obj = require_object_local(item)
    let name : String = @json.from_json(obj["name"])
    let ln : Int? = xpos_constraint_int_option(obj["ln"])
    let rn : Int? = xpos_constraint_int_option(obj["rn"])
    let _ : Int = @json.from_json(obj["minrank"])
    let _ : Int = @json.from_json(obj["maxrank"])
    clusters.push({ name, ln, rn })
  }
  clusters
}

///|
fn load_xpos_constraint_fixture(
  graph_name : String,
  phase : String,
) -> XposConstraintFixture raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/xpos.jsonl")
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line)
    let obj = require_object_local(json)
    let event : String = @json.from_json(obj["event"])
    if event != "xpos_input" {
      continue
    }
    let graph : String = @json.from_json(obj["graph"])
    let phase_value : String = @json.from_json(obj["phase"])
    if graph != graph_name || phase_value != phase {
      continue
    }
    let nodes = parse_constraint_nodes(obj["nodes"])
    let edges = parse_constraint_edges(obj["edges"])
    let clusters = parse_constraint_clusters(obj["clusters"])
    return { graph, phase: phase_value, nodes, edges, clusters }
  }
  fail("xpos fixture not found for graph=\{graph_name} phase=\{phase}")
}

///|
fn cluster_node_names(
  clusters : Array[XposConstraintFixtureCluster],
) -> Map[Int, String] {
  let names : Map[Int, String] = Map::new()
  for cluster in clusters {
    match cluster.ln {
      Some(value) => names[value] = "\{CLUSTER_LN_PREFIX}\{cluster.name}"
      None => ()
    }
    match cluster.rn {
      Some(value) => names[value] = "\{CLUSTER_RN_PREFIX}\{cluster.name}"
      None => ()
    }
  }
  names
}

///|
fn fixture_node_key(
  node : XposConstraintFixtureNode,
  cluster_names : Map[Int, String],
) -> String {
  let name = match node.name {
    Some(value) => Some(value)
    None =>
      match cluster_names.get(node.id) {
        Some(value) => Some(value)
        None => None
      }
  }
  match name {
    Some(value) => "N:\{value}"
    None =>
      if node.kind == "slack" {
        "S:\{node.rank}"
      } else {
        "V:\{node.rank}:\{node.lw}:\{node.rw}"
      }
  }
}

///|
fn snapshot_node_key(
  node : XposConstraintNodeSnapshot,
  real_nodes : Map[String, Bool],
) -> String {
  match node.name {
    Some(value) => {
      if value.has_prefix(CLUSTER_LN_PREFIX) ||
        value.has_prefix(CLUSTER_RN_PREFIX) {
        return "N:\{value}"
      }
      if real_nodes.get(value) is Some(_) {
        return "N:\{value}"
      }
      "V:\{node.rank}:\{node.left_pt}:\{node.right_pt}"
    }
    None =>
      match node.kind {
        NodeKind::Slack => "S:\{node.rank}"
        _ => "V:\{node.rank}:\{node.left_pt}:\{node.right_pt}"
      }
  }
}

///|
fn add_count(counts : Map[String, Int], key : String) -> Unit {
  let current = match counts.get(key) {
    Some(value) => value
    None => 0
  }
  counts[key] = current + 1
}

///|
fn fixture_node_counts(fixture : XposConstraintFixture) -> Map[String, Int] {
  let counts : Map[String, Int] = Map::new()
  let cluster_names = cluster_node_names(fixture.clusters)
  for node in fixture.nodes {
    add_count(counts, fixture_node_key(node, cluster_names))
  }
  counts
}

///|
fn fixture_edge_counts(fixture : XposConstraintFixture) -> Map[String, Int] {
  let counts : Map[String, Int] = Map::new()
  let cluster_names = cluster_node_names(fixture.clusters)
  let node_keys : Array[String] = []
  for node in fixture.nodes {
    node_keys.push(fixture_node_key(node, cluster_names))
  }
  for edge in fixture.edges {
    let tail_key = node_keys[edge.tail]
    let head_key = node_keys[edge.head]
    let key = "\{tail_key}>\{head_key}:\{edge.minlen}:\{edge.weight}"
    add_count(counts, key)
  }
  counts
}

///|
fn snapshot_node_counts(
  snapshot : XposConstraintSnapshot,
  real_nodes : Map[String, Bool],
) -> Map[String, Int] {
  let counts : Map[String, Int] = Map::new()
  for node in snapshot.nodes {
    add_count(counts, snapshot_node_key(node, real_nodes))
  }
  counts
}

///|
fn snapshot_edge_counts(
  snapshot : XposConstraintSnapshot,
  real_nodes : Map[String, Bool],
) -> Map[String, Int] {
  let counts : Map[String, Int] = Map::new()
  let node_keys : Array[String] = []
  for node in snapshot.nodes {
    node_keys.push(snapshot_node_key(node, real_nodes))
  }
  for edge in snapshot.edges {
    let tail_key = node_keys[edge.tail]
    let head_key = node_keys[edge.head]
    let key = "\{tail_key}>\{head_key}:\{edge.minlen}:\{edge.weight}"
    add_count(counts, key)
  }
  counts
}

///|
fn assert_multiset_eq(
  label : String,
  actual : Map[String, Int],
  expected : Map[String, Int],
) -> Unit raise {
  let mismatches : Array[String] = []
  for key, expected_count in expected {
    let actual_count = match actual.get(key) {
      Some(value) => value
      None => 0
    }
    if actual_count != expected_count {
      mismatches.push(
        "\{label} count mismatch key=\{key} expected=\{expected_count} actual=\{actual_count}",
      )
    }
  }
  for key, actual_count in actual {
    match expected.get(key) {
      Some(value) =>
        if value != actual_count {
          mismatches.push(
            "\{label} count mismatch key=\{key} expected=\{value} actual=\{actual_count}",
          )
        }
      None => mismatches.push("\{label} unexpected key=\{key}")
    }
  }
  if mismatches.length() > 0 {
    println("\{label} mismatches (\{mismatches.length()}):")
    for item in mismatches {
      println(item)
    }
    fail("\{label} mismatches found")
  }
}

///|
fn real_node_names(graph : @cgraph.Graph) -> Map[String, Bool] {
  let names : Map[String, Bool] = Map::new()
  for node in graph.nodes() {
    names[node.name()] = true
  }
  names
}

///|
///|
/// TODO: Unskip after constraint graph alignment with Graphviz (graphviz.mbt-ccz.1/2/3).
#skip
test "xpos constraint graph matches Graphviz for complex" {
  let fixture = load_xpos_constraint_fixture("yours_truly", "initial")
  if fixture.phase != "initial" {
    fail("unexpected fixture phase \{fixture.phase}")
  }
  let graph = @dot_parser.parse_dot_file("tests/layout/dot/complex.dot")
  let names = real_node_names(graph)
  xpos_constraint_snapshot.val = None
  @sys.set_env_var("DOT_CAPTURE_XPOS_CONSTRAINTS", fixture.graph)
  let _ = layout_dot(graph)
  @sys.unset_env_var("DOT_CAPTURE_XPOS_CONSTRAINTS")
  let snapshot = match xpos_constraint_snapshot.val {
    Some(value) => value
    None => fail("missing xpos constraint snapshot")
  }
  xpos_constraint_snapshot.val = None
  let expected_nodes = fixture_node_counts(fixture)
  let actual_nodes = snapshot_node_counts(snapshot, names)
  assert_multiset_eq("nodes", actual_nodes, expected_nodes)
  let expected_edges = fixture_edge_counts(fixture)
  let actual_edges = snapshot_edge_counts(snapshot, names)
  assert_multiset_eq("edges", actual_edges, expected_edges)
}
