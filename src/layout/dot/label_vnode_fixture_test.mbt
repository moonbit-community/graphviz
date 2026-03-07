///|
fn require_object_local(json : Json) -> Map[String, Json] raise {
  match json {
    Json::Object(obj) => obj
    _ => fail("expected JSON object")
  }
}

///|
struct LabelVnodeFixture {
  tail : String
  head : String
  label : String
  label_rank : Int
  lw : Double
  rw : Double
  ht : Double
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
      tail: @json.from_json(obj["tail"]),
      head: @json.from_json(obj["head"]),
      label: @json.from_json(obj["label"]),
      label_rank: @json.from_json(obj["label_rank"]),
      lw: @json.from_json(obj["lw"]),
      rw: @json.from_json(obj["rw"]),
      ht: @json.from_json(obj["ht"]),
    })
  }
  fixtures
}

///|
fn graph_nodesep_pt(graph : @cgraph.Graph) -> Double {
  let nodesep_in = match graph.get_attr("nodesep") {
    Some(value) => @numeric.parse_first_double(value, @input_stage.DEFAULT_NODESEP_IN)
    None => @input_stage.DEFAULT_NODESEP_IN
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
fn compute_ranks_directed_with_clusters_for_tests(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> Map[String, Int] {
  @rank_assignment.compute_ranks_directed_with_clusters(
    graph,
    nodes,
    edges,
    has_edge_labels,
    @rank_assignment.CL_BACK,
  )
}

///|
fn collect_label_vnode_actuals(
  graph : @cgraph.Graph,
) -> Array[LabelVnodeActual] raise {
  let nodes = graph.nodes()
  let edges = graph.edges()
  let has_edge_labels = @edge_label_metrics.graph_has_edge_labels(edges)
  let ranks = compute_ranks_directed_with_clusters_for_tests(
    graph,
    nodes,
    edges,
    has_edge_labels,
  )
  let edge_cluster_keys : Map[String, String] = Map::new()
  @clustering.collect_edge_cluster_keys(graph, edge_cluster_keys)
  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(graph)
  let cluster_parents = cluster_maps.cluster_parents
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let acyclic_directions =
    @rank_assignment.acyclic_edge_directions_with_order(graph, nodes, edges)
  let edge_tail = acyclic_directions.tail
  let edge_head = acyclic_directions.head
  let out_edges = acyclic_directions.out_edges
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    edge_out_order[name] = out_edges[i].copy()
  }
  let vnode_info = @ordering.build_edge_vnodes(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    graph_nodesep_pt(graph),
    @rankdir.graph_rankdir(graph),
    existing_names,
    edge_cluster_keys,
    cluster_parents,
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
    let label_rank_info = match @edge_label.edge_label_rank_info(
      edge,
      ranks,
      @edge_label_metrics.edge_mid_label_width_pt(edge),
    ) {
      Some(value) => value
      None => continue
    }
    let label_rank = label_rank_info.label_rank
    let mut found = false
    let vnodes = match vnode_info.edge_vnodes.get(@edge_identity.edge_vnode_key(edge)) {
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
///|
/// Graphviz parity: direct vnode_layout tests now cover the small canonical
/// label-vnode behaviors. Keep fixture replay only for larger integrated
/// graphs whose vnode sizing emerges from more coupled rank/order inputs.
test "label vnodes match Graphviz fixtures for integrated graphs" {
  let graphs : Array[(String, String)] = [
    ("edge_vnode_spacing", "tests/layout/dot/edge_vnode_spacing.dot"),
    ("yours_truly", "tests/layout/dot/complex.dot"),
    ("finite_state_machine", "refs/graphviz/graphs/directed/fsm.gv"),
    ("states", "refs/graphviz/graphs/directed/states.gv"),
  ]
  for pair in graphs {
    let (graph_name, path) = pair
    let fixtures = load_label_vnode_fixtures(graph_name)
    guard fixtures.length() > 0 else { fail("missing fixtures for \{graph_name}") }

    let graph = @dot_parser.parse_dot_file(path)
    let actuals = collect_label_vnode_actuals(graph)

    let fixture_map : Map[String, Array[LabelVnodeFixture]] = Map::new()
    for entry in fixtures {
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

    for key, expected in fixture_map {
      let actual = match actual_map.get(key) {
        Some(list) => list
        None => fail("missing label vnode actuals for \{key}")
      }
      assert_eq(actual.length(), expected.length())
      let sorted_actual = sort_label_actuals(actual)
      let sorted_expected = sort_label_fixtures(expected)
      for i in 0..<sorted_expected.length() {
        assert_eq(sorted_actual[i].lw, sorted_expected[i].lw)
        assert_eq(sorted_actual[i].rw, sorted_expected[i].rw)
        assert_eq(sorted_actual[i].ht, sorted_expected[i].ht)
      }
    }

    for key, _ in actual_map {
      if fixture_map.get(key) is None {
        fail("unexpected label vnode actuals for \{key}")
      }
    }
  }
}

