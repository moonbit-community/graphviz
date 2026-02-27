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
    graph_has_cluster,
    edge_minlen,
    edge_weight,
    CL_BACK,
  )
}

///|
///|
fn collect_label_vnode_actuals(
  graph : @cgraph.Graph,
) -> Array[LabelVnodeActual] raise {
  let nodes = graph.nodes()
  let edges = graph.edges()
  let has_edge_labels = graph_has_edge_labels(edges)
  let ranks = compute_ranks_directed_with_clusters_for_tests(
    graph,
    nodes,
    edges,
    has_edge_labels,
  )
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let (edge_tail, edge_head, _edge_reversed, out_edges, _in_edges) =
    @rank_assignment.acyclic_edge_directions_with_order(graph, nodes, edges)
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    edge_out_order[name] = out_edges[i].copy()
  }
  let vnode_info = build_edge_vnodes(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    graph_nodesep_pt(graph),
    graph_rankdir(graph),
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
) -> Array[FlatLabelNodeActual] {
  let nodes = graph.nodes()
  let edges = graph.edges()
  let has_edge_labels = graph_has_edge_labels(edges)
  let ranks = compute_ranks_directed_with_clusters_for_tests(
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
    ("finite_state_machine", "refs/graphviz/graphs/directed/fsm.gv"),
    ("states", "refs/graphviz/graphs/directed/states.gv"),
  ]
  for pair in graphs {
    let (graph_name, path) = pair
    let fixture_entries = load_label_vnode_fixtures(graph_name)
    if fixture_entries.length() == 0 {
      fail("missing fixtures for \{graph_name}")
    }
    let graph = @dot_parser.parse_dot_file(path)
    let nodes = graph.nodes()
    let edges = graph.edges()
    let has_edge_labels = graph_has_edge_labels(edges)
    let ranks = compute_ranks_directed_with_clusters_for_tests(
      graph,
      nodes,
      edges,
      has_edge_labels,
    )
    let (
      _edge_tail,
      _edge_head,
      edge_reversed,
      _edge_out_order,
      _edge_in_order,
    ) = @rank_assignment.acyclic_edge_directions_with_order(graph, nodes, edges)
    let edge_reversed_by_key : Map[String, Bool] = Map::new()
    for i in 0..<edges.length() {
      edge_reversed_by_key[edge_key(edges[i])] = edge_reversed[i]
    }
    let rankdir = graph_rankdir(graph)
    let expected_flip =
      rankdir == RankDir::LR || rankdir == RankDir::RL
    let expected_nodesep = graph_nodesep_pt(graph)
    let actuals = collect_label_vnode_actuals(graph)
    let fixture_map : Map[String, Array[LabelVnodeFixture]] = Map::new()
    for entry in fixture_entries {
      assert_eq(entry.graph, graph_name)
      assert_eq(entry.label_html, false)
      assert_eq(entry.label_ontop, false)
      assert_eq(entry.flip, expected_flip)
      assert_eq(entry.nodesep, expected_nodesep)
      let tail_rank = match ranks.get(entry.tail) {
        Some(value) => value
        None => fail("missing tail rank for \{entry.tail}")
      }
      let head_rank = match ranks.get(entry.head) {
        Some(value) => value
        None => fail("missing head rank for \{entry.head}")
      }
      let edge = match find_edge_by_nodes(graph, entry.tail, entry.head) {
        Some(value) => value
        None =>
          fail(
            "missing edge \{entry.tail} -> \{entry.head} for label vnode fixtures",
          )
      }
      let reversed = match edge_reversed_by_key.get(edge_key(edge)) {
        Some(value) => value
        None => false
      }
      let actual_tail_rank = if reversed { head_rank } else { tail_rank }
      let actual_head_rank = if reversed { tail_rank } else { head_rank }
      if actual_tail_rank != entry.tail_rank {
        fail(
          "tail rank mismatch for \{graph_name} \{entry.tail} -> \{entry.head} \{entry.label}: got \{actual_tail_rank} expected \{entry.tail_rank}",
        )
      }
      if actual_head_rank != entry.head_rank {
        fail(
          "head rank mismatch for \{graph_name} \{entry.tail} -> \{entry.head} \{entry.label}: got \{actual_head_rank} expected \{entry.head_rank}",
        )
      }
      let label_rank_info = match edge_label_rank_info(edge, ranks) {
        Some(value) => value
        None => fail("missing label rank info for \{entry.tail} -> \{entry.head}")
      }
      let (label_rank, _span) = label_rank_info
      assert_eq(label_rank, entry.label_rank)
      let (width, height) = match edge_mid_label_metrics(edge) {
        Some(value) => value
        None => fail("missing label metrics for \{entry.tail} -> \{entry.head}")
      }
      assert_eq(width, entry.dimen_x)
      assert_eq(height, entry.dimen_y)
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
  let nodes = graph.nodes()
  let edges = graph.edges()
  let has_edge_labels = graph_has_edge_labels(edges)
  let ranks = compute_ranks_directed_with_clusters_for_tests(
    graph,
    nodes,
    edges,
    has_edge_labels,
  )
  let rankdir = graph_rankdir(graph)
  let expected_flip =
    rankdir == RankDir::LR || rankdir == RankDir::RL
  let record_orientation = record_layout_orientation(rankdir)
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let size = node_size(node, record_orientation)
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      swap_node_size(size)
    } else {
      size
    }
  }
  let groups = build_rank_groups(nodes, ranks)
  let ordered_groups = groups
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  let self_edge_labels = self_edge_label_half_heights(edges)
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_half = 0.0
    for name in names {
      let half_height = node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
  if has_edge_labels {
    for edge in edges {
      if !edge_has_label(edge) {
        continue
      }
      let tail = edge.tail().name()
      let head = edge.head().name()
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => continue
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => continue
      }
      let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
      let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
      if max_rank - min_rank <= 1 {
        continue
      }
      let label_rank = (min_rank + max_rank) / 2
      let half_height = edge_label_height_pt(edge) / 2.0
      let current = match rank_pht.get(label_rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[label_rank] = half_height
      }
    }
  }
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = match rank_pht.get(rank) {
      Some(value) => value
      None => 0.0
    }
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  let _ = apply_cluster_rank_heights(
    graph, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2, rankdir,
  )
  let ranksep_in = match graph.get_attr("ranksep") {
    Some(value) => parse_first_double(value, default_ranksep_in())
    None => default_ranksep_in()
  }
  let mut ranksep_pt_int = round_int(ranksep_in * 72.0)
  if has_edge_labels {
    ranksep_pt_int = (ranksep_pt_int + 1) / 2
  }
  let ranksep_pt = ranksep_pt_int.to_double()
  let actuals = collect_flat_label_node_actuals(graph)
  let fixture_map : Map[String, Array[FlatLabelNodeFixture]] = Map::new()
  for entry in fixtures {
    assert_eq(entry.graph, graph_name)
    assert_eq(entry.label_html, false)
    assert_eq(entry.flip, expected_flip)
    assert_eq(entry.order, 0)
    assert_eq(entry.place, 0)
    let edge = match find_edge_by_nodes(graph, entry.tail, entry.head) {
      Some(value) => value
      None =>
        fail(
          "missing edge \{entry.tail} -> \{entry.head} for flat label fixtures",
        )
    }
    let tail_rank = match ranks.get(entry.tail) {
      Some(value) => value
      None => fail("missing tail rank for \{entry.tail}")
    }
    let head_rank = match ranks.get(entry.head) {
      Some(value) => value
      None => fail("missing head rank for \{entry.head}")
    }
    assert_eq(tail_rank, head_rank)
    assert_eq(entry.rank, tail_rank - 1)
    let (width, height) = match edge_mid_label_metrics(edge) {
      Some(value) => value
      None => fail("missing label metrics for \{entry.tail} -> \{entry.head}")
    }
    assert_eq(width, entry.dimen_x)
    assert_eq(height, entry.dimen_y)
    assert_eq(
      flat_label_adjacent(tail_rank, entry.tail, entry.head, ordered_groups),
      false,
    )
    let half_height = entry.dimen_y / 2.0
    let current = match rank_pht.get(entry.rank) {
      Some(value) => value
      None => 0.0
    }
    if half_height > current {
      rank_pht[entry.rank] = half_height
    }
    let current_ht1 = match rank_ht1.get(entry.rank) {
      Some(value) => value
      None => 0.0
    }
    if half_height > current_ht1 {
      rank_ht1[entry.rank] = half_height
    }
    let current_ht2 = match rank_ht2.get(entry.rank) {
      Some(value) => value
      None => 0.0
    }
    if half_height > current_ht2 {
      rank_ht2[entry.rank] = half_height
    }
    let key = "\{entry.tail}|\{entry.head}|\{entry.label}|\{entry.rank}"
    match fixture_map.get(key) {
      Some(list) => list.push(entry)
      None => fixture_map[key] = [entry]
    }
  }
  let y_all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let mut min_rank = rank_keys[0]
    let mut max_rank = rank_keys[rank_keys.length() - 1]
    for entry in fixtures {
      if entry.rank < min_rank {
        min_rank = entry.rank
      }
      if entry.rank > max_rank {
        max_rank = entry.rank
      }
    }
    for rank in min_rank..=max_rank {
      y_all_ranks.push(rank)
    }
  }
  let y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  fill_rank_positions(
    rank_keys,
    groups,
    y_all_ranks,
    rank_pht,
    rank_ht1,
    rank_ht2,
    ranksep_pt,
    y_positions,
    rank_y,
  )
  for entry in fixtures {
    let rank_y_value = match rank_y.get(entry.rank) {
      Some(value) => value
      None => fail("missing rank y for \{entry.rank}")
    }
    let ht1_value = match rank_ht1.get(entry.rank) {
      Some(value) => value
      None => fail("missing rank ht1 for \{entry.rank}")
    }
    let half_height = entry.dimen_y / 2.0
    let coord_y = rank_y_value - ht1_value + half_height
    assert_eq(coord_y, entry.coord_y)
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
