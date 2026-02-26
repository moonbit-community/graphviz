///|
struct XposConstraintFixtureNode {
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
struct XposConstraintFixtureEdge {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
struct XposConstraintFixtureCluster {
  name : String
  minrank : Int
  maxrank : Int
  ln : Int?
  rn : Int?
}

///|
struct XposConstraintFixture {
  graph : String
  phase : String
  minrank : Int
  maxrank : Int
  ranks : Array[Array[Int]]
  nodes : Array[XposConstraintFixtureNode]
  edges : Array[XposConstraintFixtureEdge]
  clusters : Array[XposConstraintFixtureCluster]
}

///|
fn parse_constraint_nodes(value : Json) -> Array[XposConstraintFixtureNode] raise {
  let items : Array[Json] = @json.from_json(value)
  let nodes : Array[XposConstraintFixtureNode] = []
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
fn parse_constraint_edges(value : Json) -> Array[XposConstraintFixtureEdge] raise {
  let items : Array[Json] = @json.from_json(value)
  let edges : Array[XposConstraintFixtureEdge] = []
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
fn parse_constraint_clusters(value : Json) -> Array[XposConstraintFixtureCluster] raise {
  let items : Array[Json] = @json.from_json(value)
  let clusters : Array[XposConstraintFixtureCluster] = []
  for item in items {
    let obj = fixture_require_object(item)
    let name : String = @json.from_json(obj["name"])
    let ln : Int? = fixture_json_int_option(obj["ln"])
    let rn : Int? = fixture_json_int_option(obj["rn"])
    let minrank : Int = @json.from_json(obj["minrank"])
    let maxrank : Int = @json.from_json(obj["maxrank"])
    clusters.push({ name, minrank, maxrank, ln, rn })
  }
  clusters
}

///|
fn parse_constraint_ranks(value : Json) -> Array[Array[Int]] raise {
  @json.from_json(value)
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
    let obj = fixture_require_object(json)
    let event : String = @json.from_json(obj["event"])
    if event != "xpos_input" {
      continue
    }
    let graph : String = @json.from_json(obj["graph"])
    let phase_value : String = @json.from_json(obj["phase"])
    if graph != graph_name || phase_value != phase {
      continue
    }
    let minrank : Int = @json.from_json(obj["minrank"])
    let maxrank : Int = @json.from_json(obj["maxrank"])
    let ranks = parse_constraint_ranks(obj["ranks"])
    let nodes = parse_constraint_nodes(obj["nodes"])
    let edges = parse_constraint_edges(obj["edges"])
    let clusters = parse_constraint_clusters(obj["clusters"])
    return {
      graph,
      phase: phase_value,
      minrank,
      maxrank,
      ranks,
      nodes,
      edges,
      clusters,
    }
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
        "S:\{node.rank}:\{node.order}:\{node.lw}:\{node.rw}:\{node.ht}"
      } else {
        "V:\{node.rank}:\{node.lw}:\{node.rw}:\{node.ht}:\{node.order}"
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
      "V:\{node.rank}:\{node.left_pt}:\{node.right_pt}:\{node.height_pt}:\{node.order}"
    }
    None =>
      match node.kind {
        NodeKind::Slack =>
          "S:\{node.rank}:\{node.order}:\{node.left_pt}:\{node.right_pt}:\{node.height_pt}"
        _ =>
          "V:\{node.rank}:\{node.left_pt}:\{node.right_pt}:\{node.height_pt}:\{node.order}"
      }
  }
}

///|
fn fixture_named_nodes(
  fixture : XposConstraintFixture,
) -> Map[String, XposConstraintFixtureNode] {
  let map : Map[String, XposConstraintFixtureNode] = Map::new()
  for node in fixture.nodes {
    match node.name {
      Some(value) => map[value] = node
      None => ()
    }
  }
  map
}

///|
fn snapshot_named_nodes(
  snapshot : XposConstraintSnapshot,
  real_nodes : Map[String, Bool],
) -> Map[String, XposConstraintNodeSnapshot] {
  let map : Map[String, XposConstraintNodeSnapshot] = Map::new()
  for node in snapshot.nodes {
    match node.name {
      Some(value) =>
        if real_nodes.get(value) is Some(_) {
          map[value] = node
        }
      None => ()
    }
  }
  map
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
test "xpos constraint graph matches Graphviz for complex" {
  let fixture = load_xpos_constraint_fixture("yours_truly", "initial")
  if fixture.phase != "initial" {
    fail("unexpected fixture phase \{fixture.phase}")
  }
  if fixture.minrank > fixture.maxrank {
    fail("minrank \{fixture.minrank} > maxrank \{fixture.maxrank}")
  }
  let expected_rank_count = fixture.maxrank - fixture.minrank + 1
  if fixture.ranks.length() != expected_rank_count {
    fail(
      "rank list count mismatch expected=\{expected_rank_count} actual=\{fixture.ranks.length()}",
    )
  }
  let order_map = fixture_build_rank_order_map(fixture.ranks)
  let mut non_slack = 0
  let fixture_ids : Map[Int, Bool] = Map::new()
  for node in fixture.nodes {
    fixture_ids[node.id] = true
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
  }
  if order_map.length() != non_slack {
    fail(
      "rank list size mismatch expected=\{non_slack} actual=\{order_map.length()}",
    )
  }
  for cluster in fixture.clusters {
    if cluster.minrank > cluster.maxrank {
      fail("cluster \{cluster.name} minrank > maxrank")
    }
    if cluster.minrank < fixture.minrank || cluster.maxrank > fixture.maxrank {
      fail("cluster \{cluster.name} rank range out of bounds")
    }
    match cluster.ln {
      Some(id) =>
        if fixture_ids.get(id) is None {
          fail("cluster \{cluster.name} missing ln node id=\{id}")
        }
      None => ()
    }
    match cluster.rn {
      Some(id) =>
        if fixture_ids.get(id) is None {
          fail("cluster \{cluster.name} missing rn node id=\{id}")
        }
      None => ()
    }
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
  let fixture_named = fixture_named_nodes(fixture)
  let snapshot_named = snapshot_named_nodes(snapshot, names)
  for name, expected in fixture_named {
    let actual = match snapshot_named.get(name) {
      Some(value) => value
      None => fail("missing snapshot node for \{name}")
    }
    assert_eq(actual.rank, expected.rank)
    assert_eq(actual.order, expected.order)
    assert_eq(actual.left_pt, expected.lw)
    assert_eq(actual.right_pt, expected.rw)
    assert_eq(actual.height_pt, expected.ht)
  }
}
