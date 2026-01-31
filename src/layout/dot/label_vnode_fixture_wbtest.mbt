///|
struct LabelVnodeFixture {
  graph : String
  tail : String
  head : String
  label : String
  label_html : Bool
  label_ontop : Bool
  flip : Bool
  nodesep : Double
  tail_rank : Int
  head_rank : Int
  label_rank : Int
  dimen_x : Double
  dimen_y : Double
  lw : Double
  rw : Double
  ht : Double
}

///|
struct FlatLabelNodeFixture {
  graph : String
  tail : String
  head : String
  label : String
  label_html : Bool
  flip : Bool
  rank : Int
  order : Int
  place : Int
  dimen_x : Double
  dimen_y : Double
  lw : Double
  rw : Double
  ht : Double
  coord_y : Double
}

///|
struct LabelVnodeActual {
  tail : String
  head : String
  label : String
  label_rank : Int
  lw : Double
  rw : Double
  ht : Double
}

///|
struct FlatLabelNodeActual {
  tail : String
  head : String
  label : String
  rank : Int
  lw : Double
  rw : Double
  ht : Double
}

///|
fn load_label_vnode_fixtures(
  graph_name : String,
) -> Array[LabelVnodeFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/label_vnode.jsonl")
  let fixtures : Array[LabelVnodeFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let obj = require_object_local(@json.parse(line))
    let event : String = @json.from_json(obj["event"])
    if event != "label_vnode" {
      continue
    }
    let graph : String = @json.from_json(obj["graph"])
    if graph != graph_name {
      continue
    }
    fixtures.push({
      graph,
      tail: @json.from_json(obj["tail"]),
      head: @json.from_json(obj["head"]),
      label: @json.from_json(obj["label"]),
      label_html: @json.from_json(obj["label_html"]),
      label_ontop: @json.from_json(obj["label_ontop"]),
      flip: @json.from_json(obj["flip"]),
      nodesep: @json.from_json(obj["nodesep"]),
      tail_rank: @json.from_json(obj["tail_rank"]),
      head_rank: @json.from_json(obj["head_rank"]),
      label_rank: @json.from_json(obj["label_rank"]),
      dimen_x: @json.from_json(obj["dimen_x"]),
      dimen_y: @json.from_json(obj["dimen_y"]),
      lw: @json.from_json(obj["lw"]),
      rw: @json.from_json(obj["rw"]),
      ht: @json.from_json(obj["ht"]),
    })
  }
  fixtures
}

///|
fn load_flat_label_node_fixtures(
  graph_name : String,
) -> Array[FlatLabelNodeFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/label_vnode.jsonl")
  let fixtures : Array[FlatLabelNodeFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let obj = require_object_local(@json.parse(line))
    let event : String = @json.from_json(obj["event"])
    if event != "flat_label_node" {
      continue
    }
    let graph : String = @json.from_json(obj["graph"])
    if graph != graph_name {
      continue
    }
    fixtures.push({
      graph,
      tail: @json.from_json(obj["tail"]),
      head: @json.from_json(obj["head"]),
      label: @json.from_json(obj["label"]),
      label_html: @json.from_json(obj["label_html"]),
      flip: @json.from_json(obj["flip"]),
      rank: @json.from_json(obj["rank"]),
      order: @json.from_json(obj["order"]),
      place: @json.from_json(obj["place"]),
      dimen_x: @json.from_json(obj["dimen_x"]),
      dimen_y: @json.from_json(obj["dimen_y"]),
      lw: @json.from_json(obj["lw"]),
      rw: @json.from_json(obj["rw"]),
      ht: @json.from_json(obj["ht"]),
      coord_y: @json.from_json(obj["coord_y"]),
    })
  }
  fixtures
}

///|
fn graph_nodesep_pt(graph : @cgraph.Graph) -> Double {
  let nodesep_in = match graph.get_attr("nodesep") {
    Some(value) => parse_first_double(value, default_nodesep_in())
    None => default_nodesep_in()
  }
  nodesep_in * 72.0
}

///|
fn label_vnode_key(
  tail : String,
  head : String,
  label : String,
  label_rank : Int,
) -> String {
  "\{tail}|\{head}|\{label}|\{label_rank}"
}

///|
fn collect_label_vnode_actuals(
  graph : @cgraph.Graph,
) -> Array[LabelVnodeActual] raise {
  let nodes = graph.nodes()
  let edges = graph.edges()
  let has_edge_labels = graph_has_edge_labels(edges)
  let ranks = compute_ranks_directed_with_clusters(
    graph,
    nodes,
    edges,
    has_edge_labels,
  )
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let vnode_info = build_edge_vnodes(
    edges,
    ranks,
    graph_nodesep_pt(graph),
    graph_rankdir(graph),
    existing_names,
    edge_cluster_keys,
  )
  let actuals : Array[LabelVnodeActual] = []
  for edge in edges {
    let label = match edge.get_attr("label") {
      Some(value) => value
      None => continue
    }
    if label == "" {
      continue
    }
    let label_rank_info = match edge_label_rank_info(edge, ranks) {
      Some(value) => value
      None => continue
    }
    let (label_rank, _span) = label_rank_info
    let mut found = false
    let vnodes = match vnode_info.edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    for name in vnodes {
      match vnode_info.vnode_ranks.get(name) {
        Some(rank) =>
          if rank == label_rank {
            let size = match vnode_info.vnode_sizes.get(name) {
              Some(value) => value
              None => fail("missing vnode size for \{name}")
            }
            actuals.push({
              tail: edge.tail().name(),
              head: edge.head().name(),
              label,
              label_rank,
              lw: size.left_pt,
              rw: size.right_pt,
              ht: size.height_pt,
            })
            found = true
          }
        None => ()
      }
    }
    if !found {
      fail("missing label vnode for \{edge.tail().name()} -> \{edge.head().name()} (\{label})")
    }
  }
  actuals
}

///|
fn collect_flat_label_node_actuals(
  graph : @cgraph.Graph,
) -> Array[FlatLabelNodeActual] raise {
  let nodes = graph.nodes()
  let edges = graph.edges()
  let has_edge_labels = graph_has_edge_labels(edges)
  let ranks = compute_ranks_directed_with_clusters(
    graph,
    nodes,
    edges,
    has_edge_labels,
  )
  let rankdir = graph_rankdir(graph)
  let actuals : Array[FlatLabelNodeActual] = []
  for edge in edges {
    let label = match edge.get_attr("label") {
      Some(value) => value
      None => continue
    }
    if label == "" {
      continue
    }
    let tail_rank = match ranks.get(edge.tail().name()) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(edge.head().name()) {
      Some(value) => value
      None => continue
    }
    if tail_rank != head_rank {
      continue
    }
    let metrics = match edge_mid_label_metrics(edge) {
      Some(value) => value
      None => continue
    }
    let (metric_width, metric_height) = metrics
    let (width, height) =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      (metric_height, metric_width)
    } else {
      (metric_width, metric_height)
    }
    actuals.push({
      tail: edge.tail().name(),
      head: edge.head().name(),
      label,
      rank: tail_rank - 1,
      lw: width / 2.0,
      rw: width / 2.0,
      ht: height,
    })
  }
  actuals
}

///|
fn sort_label_actuals(entries : Array[LabelVnodeActual]) -> Array[LabelVnodeActual] {
  let sorted = entries.copy()
  sorted.sort_by((a, b) => {
    if a.lw < b.lw {
      -1
    } else if a.lw > b.lw {
      1
    } else if a.rw < b.rw {
      -1
    } else if a.rw > b.rw {
      1
    } else if a.ht < b.ht {
      -1
    } else if a.ht > b.ht {
      1
    } else {
      0
    }
  })
  sorted
}

///|
fn sort_label_fixtures(entries : Array[LabelVnodeFixture]) -> Array[LabelVnodeFixture] {
  let sorted = entries.copy()
  sorted.sort_by((a, b) => {
    if a.lw < b.lw {
      -1
    } else if a.lw > b.lw {
      1
    } else if a.rw < b.rw {
      -1
    } else if a.rw > b.rw {
      1
    } else if a.ht < b.ht {
      -1
    } else if a.ht > b.ht {
      1
    } else {
      0
    }
  })
  sorted
}

///|
test "label vnodes match Graphviz fixtures" {
  let graphs : Array[(String, String)] = [
    ("edge_labels", "tests/layout/dot/edge_label_spacing.dot"),
    ("edge_vnode_spacing", "tests/layout/dot/edge_vnode_spacing.dot"),
    ("yours_truly", "tests/layout/dot/complex.dot"),
  ]
  for pair in graphs {
    let (graph_name, path) = pair
    let fixture_entries = load_label_vnode_fixtures(graph_name)
    if fixture_entries.length() == 0 {
      fail("missing fixtures for \{graph_name}")
    }
    let graph = @dot_parser.parse_dot_file(path)
    let actuals = collect_label_vnode_actuals(graph)
    let fixture_map : Map[String, Array[LabelVnodeFixture]] = Map::new()
    for entry in fixture_entries {
      let key = label_vnode_key(entry.tail, entry.head, entry.label, entry.label_rank)
      match fixture_map.get(key) {
        Some(list) => list.push(entry)
        None => fixture_map[key] = [entry]
      }
    }
    let actual_map : Map[String, Array[LabelVnodeActual]] = Map::new()
    for entry in actuals {
      let key = label_vnode_key(entry.tail, entry.head, entry.label, entry.label_rank)
      match actual_map.get(key) {
        Some(list) => list.push(entry)
        None => actual_map[key] = [entry]
      }
    }
    for key, fixtures in fixture_map {
      let actual_list = match actual_map.get(key) {
        Some(list) => list
        None => fail("missing label vnode actuals for \{key}")
      }
      assert_eq(actual_list.length(), fixtures.length())
      let sorted_actual = sort_label_actuals(actual_list)
      let sorted_expected = sort_label_fixtures(fixtures)
      for i in 0..<sorted_expected.length() {
        assert_eq(sorted_actual[i].lw, sorted_expected[i].lw)
        assert_eq(sorted_actual[i].rw, sorted_expected[i].rw)
        assert_eq(sorted_actual[i].ht, sorted_expected[i].ht)
      }
    }
    for key, _actual_list in actual_map {
      if fixture_map.get(key) is None {
        fail("unexpected label vnode actuals for \{key}")
      }
    }
  }
}

///|
test "flat label node sizes match Graphviz fixtures" {
  let graph_name = "flat_label"
  let fixtures = load_flat_label_node_fixtures(graph_name)
  if fixtures.length() == 0 {
    fail("missing fixtures for \{graph_name}")
  }
  let graph = @dot_parser.parse_dot_file("tests/layout/dot/flat_edge_label.dot")
  let actuals = collect_flat_label_node_actuals(graph)
  let fixture_map : Map[String, Array[FlatLabelNodeFixture]] = Map::new()
  for entry in fixtures {
    let key = "\{entry.tail}|\{entry.head}|\{entry.label}|\{entry.rank}"
    match fixture_map.get(key) {
      Some(list) => list.push(entry)
      None => fixture_map[key] = [entry]
    }
  }
  let actual_map : Map[String, Array[FlatLabelNodeActual]] = Map::new()
  for entry in actuals {
    let key = "\{entry.tail}|\{entry.head}|\{entry.label}|\{entry.rank}"
    match actual_map.get(key) {
      Some(list) => list.push(entry)
      None => actual_map[key] = [entry]
    }
  }
  for key, fixtures_for_key in fixture_map {
    let actual_for_key = match actual_map.get(key) {
      Some(list) => list
      None => fail("missing flat label node actuals for \{key}")
    }
    assert_eq(actual_for_key.length(), fixtures_for_key.length())
    for i in 0..<fixtures_for_key.length() {
      let actual = actual_for_key[i]
      let expected = fixtures_for_key[i]
      assert_eq(actual.rank, expected.rank)
      assert_eq(actual.lw, expected.lw)
      assert_eq(actual.rw, expected.rw)
      assert_eq(actual.ht, expected.ht)
    }
  }
}
