///|
fn find_mincross_input_case(path : String, case_id : Int) -> MincrossInput raise {
  let fixtures = load_mincross_fixtures_from(path)
  for pair in fixtures.cases {
    let (input, _output) = pair
    if input.case_id == case_id {
      return input
    }
  }
  fail("missing mincross fixture case \{case_id} in \{path}")
}

///|
fn build_fixture_node_index(input : MincrossInput) -> Map[Int, MincrossNode] {
  let by_id : Map[Int, MincrossNode] = Map::new()
  for node in input.nodes {
    by_id[node.id] = node
  }
  by_id
}

///|
fn canonical_fixture_node_name(node : MincrossNode) -> String raise {
  if node.cluster_skeleton {
    let cluster = match node.cluster {
      Some(value) => value
      None => fail("fixture skeleton node missing cluster")
    }
    return "skeleton:\{cluster}@\{node.rank}"
  }
  match node.name {
    Some(value) => value
    None => fail("fixture non-skeleton node missing name")
  }
}

///|
fn canonical_snapshot_name(
  name : String,
  rank : Int,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
) -> String raise {
  if cluster_skeleton.get(name) == Some(true) {
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => fail("missing cluster key for skeleton node \{name}")
    }
    return "skeleton:\{cluster}@\{rank}"
  }
  name
}

///|
fn build_rank_lookup(rank_keys : Array[Int], groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let rank_lookup : Map[String, Int] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(value) => value
      None => []
    }
    for name in names {
      rank_lookup[name] = rank
    }
  }
  rank_lookup
}

///|
fn edge_snapshot_line(idx : Int, edge : @ordering.OrderingEdgeSnapshotEntry) -> String {
  "edge \{idx}: \{edge.tail} -> \{edge.head} pen=\{edge.xpenalty} tpx=\{edge.tail_port_x} hpx=\{edge.head_port_x} tpo=\{edge.tail_port_order} hpo=\{edge.head_port_order}"
}

///|
fn expected_input_dump(input : MincrossInput) -> String raise {
  let node_by_id = build_fixture_node_index(input)
  let lines : Array[String] = []
  let mut rank = input.minrank
  for rank_nodes in input.ranks {
    let names : Array[String] = []
    for node_id in rank_nodes {
      let node = match node_by_id.get(node_id) {
        Some(value) => value
        None => fail("missing fixture node id \{node_id}")
      }
      names.push(canonical_fixture_node_name(node))
    }
    let rank_names = names.join(" ")
    lines.push("rank \{rank}: \{rank_names}")
    rank = rank + 1
  }
  let mut edge_idx = 0
  for edge in input.edges {
    let tail_node = match node_by_id.get(edge.tail) {
      Some(value) => value
      None => fail("missing fixture tail id \{edge.tail}")
    }
    let head_node = match node_by_id.get(edge.head) {
      Some(value) => value
      None => fail("missing fixture head id \{edge.head}")
    }
    let snapshot : @ordering.OrderingEdgeSnapshotEntry = {
      tail: canonical_fixture_node_name(tail_node),
      head: canonical_fixture_node_name(head_node),
      xpenalty: edge.xpenalty,
      tail_port_x: edge.tail_port_x,
      head_port_x: edge.head_port_x,
      tail_port_order: edge.tail_port_order,
      head_port_order: edge.head_port_order,
    }
    lines.push(edge_snapshot_line(edge_idx, snapshot))
    edge_idx = edge_idx + 1
  }
  lines.join("\n")
}

///|
fn root_snapshot_dump(snapshot : @ordering.RootMincrossInputSnapshot) -> String raise {
  let lines : Array[String] = []
  let rank_lookup = build_rank_lookup(snapshot.rank_keys, snapshot.groups)
  for rank in snapshot.rank_keys {
    let names = match snapshot.groups.get(rank) {
      Some(value) => value
      None => []
    }
    let canonical : Array[String] = []
    for name in names {
      canonical.push(
        canonical_snapshot_name(
          name,
          rank,
          snapshot.cluster_keys,
          snapshot.cluster_skeleton,
        ),
      )
    }
    let rank_names = canonical.join(" ")
    lines.push("rank \{rank}: \{rank_names}")
  }
  let mut edge_idx = 0
  for edge in snapshot.edges {
    let tail_rank = match rank_lookup.get(edge.tail) {
      Some(value) => value
      None => fail("missing root rank for tail \{edge.tail}")
    }
    let head_rank = match rank_lookup.get(edge.head) {
      Some(value) => value
      None => fail("missing root rank for head \{edge.head}")
    }
    let canonical_edge : @ordering.OrderingEdgeSnapshotEntry = {
      tail: canonical_snapshot_name(
        edge.tail,
        tail_rank,
        snapshot.cluster_keys,
        snapshot.cluster_skeleton,
      ),
      head: canonical_snapshot_name(
        edge.head,
        head_rank,
        snapshot.cluster_keys,
        snapshot.cluster_skeleton,
      ),
      xpenalty: edge.xpenalty,
      tail_port_x: edge.tail_port_x,
      head_port_x: edge.head_port_x,
      tail_port_order: edge.tail_port_order,
      head_port_order: edge.head_port_order,
    }
    lines.push(edge_snapshot_line(edge_idx, canonical_edge))
    edge_idx = edge_idx + 1
  }
  lines.join("\n")
}

///|
fn remincross_snapshot_dump(snapshot : @ordering.RemincrossInputSnapshot) -> String {
  let lines : Array[String] = []
  for rank in snapshot.rank_keys {
    let names = match snapshot.groups.get(rank) {
      Some(value) => value
      None => []
    }
    let rank_names = names.join(" ")
    lines.push("rank \{rank}: \{rank_names}")
  }
  let mut edge_idx = 0
  for edge in snapshot.edges {
    lines.push(edge_snapshot_line(edge_idx, edge))
    edge_idx = edge_idx + 1
  }
  lines.join("\n")
}

///|
fn split_lines_for_diff(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    lines.push(line.to_string())
  }
  lines
}

///|
fn first_mismatch_detail(expected : String, actual : String) -> String {
  let expected_lines = split_lines_for_diff(expected)
  let actual_lines = split_lines_for_diff(actual)
  let shared =
    if expected_lines.length() < actual_lines.length() {
      expected_lines.length()
    } else {
      actual_lines.length()
    }
  for idx in 0..<shared {
    if expected_lines[idx] != actual_lines[idx] {
      return "line \{idx}: expected=\"\{expected_lines[idx]}\" actual=\"\{actual_lines[idx]}\""
    }
  }
  "line-count expected=\{expected_lines.length()} actual=\{actual_lines.length()}"
}

///|
test "plugins root/remincross mincross inputs match graphviz fixtures" {
  let fixture_path = "tests/fixtures/graphviz/mincross.plugins.jsonl"
  let root_expected = find_mincross_input_case(fixture_path, 1)
  let remincross_expected = find_mincross_input_case(fixture_path, 11)

  @ordering.root_mincross_input_snapshot.val = None
  @ordering.remincross_input_snapshot.val = None

  @sys.set_env_var("DOT_CAPTURE_ORDERING_INPUTS", "1")
  @sys.set_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE", "1")
  let graph = @dot_parser.parse_dot_file("refs/graphviz/doc/infosrc/plugins.gv")
  ignore(layout_dot(graph))
  @sys.unset_env_var("DOT_CAPTURE_ORDERING_INPUTS")
  @sys.unset_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE")

  let root_actual = match @ordering.root_mincross_input_snapshot.val {
    Some(value) => value
    None => fail("missing captured root mincross input snapshot")
  }
  let remincross_actual = match @ordering.remincross_input_snapshot.val {
    Some(value) => value
    None => fail("missing captured remincross input snapshot")
  }

  let root_expected_dump = expected_input_dump(root_expected)
  let root_actual_dump = root_snapshot_dump(root_actual)
  @fs.write_string_to_file("/tmp/mbt-plugins-root-expected.txt", root_expected_dump)
  @fs.write_string_to_file("/tmp/mbt-plugins-root-actual.txt", root_actual_dump)
  if root_actual_dump != root_expected_dump {
    let detail = first_mismatch_detail(root_expected_dump, root_actual_dump)
    fail("root mincross input mismatch for plugins: \{detail}")
  }

  let remincross_expected_dump = expected_input_dump(remincross_expected)
  let remincross_actual_dump = remincross_snapshot_dump(remincross_actual)
  @fs.write_string_to_file(
    "/tmp/mbt-plugins-remincross-expected.txt",
    remincross_expected_dump,
  )
  @fs.write_string_to_file(
    "/tmp/mbt-plugins-remincross-actual.txt",
    remincross_actual_dump,
  )
  if remincross_actual_dump != remincross_expected_dump {
    let detail =
      first_mismatch_detail(remincross_expected_dump, remincross_actual_dump)
    fail("remincross input mismatch for plugins: \{detail}")
  }

  @ordering.root_mincross_input_snapshot.val = None
  @ordering.remincross_input_snapshot.val = None
}
