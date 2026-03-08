///|
/// Shared canonicalization/parsing support for the plugin ordering fixture
/// smoke test. The user-facing wbtest file keeps only the capture/compare flow.

///|
struct CanonicalOrderingInput {
  rank_rows : Array[Array[String]]
  edges : Array[OrderingEdgeSnapshotEntry]
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
    let names = groups.get(rank).unwrap_or_default()
    for name in names {
      rank_lookup[name] = rank
    }
  }
  rank_lookup
}

///|
fn canonical_fixture_ordering_input(input : MincrossInput) -> CanonicalOrderingInput raise {
  let node_by_id = build_fixture_node_index(input)
  let rank_rows : Array[Array[String]] = []
  for rank_nodes in input.ranks {
    let names : Array[String] = []
    for node_id in rank_nodes {
      let node = match node_by_id.get(node_id) {
        Some(value) => value
        None => fail("missing fixture node id \{node_id}")
      }
      names.push(canonical_fixture_node_name(node))
    }
    rank_rows.push(names)
  }
  let edges : Array[OrderingEdgeSnapshotEntry] = []
  for edge in input.edges {
    let tail_node = match node_by_id.get(edge.tail) {
      Some(value) => value
      None => fail("missing fixture tail id \{edge.tail}")
    }
    let head_node = match node_by_id.get(edge.head) {
      Some(value) => value
      None => fail("missing fixture head id \{edge.head}")
    }
    edges.push(
      {
        tail: canonical_fixture_node_name(tail_node),
        head: canonical_fixture_node_name(head_node),
        xpenalty: edge.xpenalty,
        tail_port_x: edge.tail_port_x,
        head_port_x: edge.head_port_x,
        tail_port_order: edge.tail_port_order,
        head_port_order: edge.head_port_order,
      },
    )
  }
  { rank_rows, edges }
}

///|
fn canonical_root_snapshot_input(
  snapshot : RootMincrossInputSnapshot,
) -> CanonicalOrderingInput raise {
  let rank_rows : Array[Array[String]] = []
  for rank in snapshot.rank_keys {
    let names = snapshot.groups.get(rank).unwrap_or_default()
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
    rank_rows.push(canonical)
  }

  let rank_lookup = build_rank_lookup(snapshot.rank_keys, snapshot.groups)
  let edges : Array[OrderingEdgeSnapshotEntry] = []
  for edge in snapshot.edges {
    let tail_rank = match rank_lookup.get(edge.tail) {
      Some(value) => value
      None => fail("missing root rank for tail \{edge.tail}")
    }
    let head_rank = match rank_lookup.get(edge.head) {
      Some(value) => value
      None => fail("missing root rank for head \{edge.head}")
    }
    edges.push(
      {
        tail:
          canonical_snapshot_name(
            edge.tail,
            tail_rank,
            snapshot.cluster_keys,
            snapshot.cluster_skeleton,
          ),
        head:
          canonical_snapshot_name(
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
      },
    )
  }
  { rank_rows, edges }
}

///|
fn canonical_remincross_snapshot_input(
  snapshot : RemincrossInputSnapshot,
) -> CanonicalOrderingInput {
  let rank_rows : Array[Array[String]] = []
  for rank in snapshot.rank_keys {
    rank_rows.push(snapshot.groups.get(rank).unwrap_or_default().copy())
  }
  { rank_rows, edges: snapshot.edges.copy() }
}

///|
fn edge_snapshot_summary(edge : OrderingEdgeSnapshotEntry) -> String {
  "\{edge.tail}->\{edge.head} pen=\{edge.xpenalty} tpx=\{edge.tail_port_x} hpx=\{edge.head_port_x} tpo=\{edge.tail_port_order} hpo=\{edge.head_port_order}"
}

///|
fn assert_canonical_ordering_input_eq(
  label : String,
  actual : CanonicalOrderingInput,
  expected : CanonicalOrderingInput,
) -> Unit raise {
  if actual.rank_rows.length() != expected.rank_rows.length() {
    fail(
      "\{label} rank row count mismatch expected=\{expected.rank_rows.length()} actual=\{actual.rank_rows.length()}",
    )
  }
  for i in 0..<expected.rank_rows.length() {
    if actual.rank_rows[i] != expected.rank_rows[i] {
      fail(
        "\{label} rank row[\{i}] mismatch expected=\{expected.rank_rows[i]} actual=\{actual.rank_rows[i]}",
      )
    }
  }
  if actual.edges.length() != expected.edges.length() {
    fail(
      "\{label} edge count mismatch expected=\{expected.edges.length()} actual=\{actual.edges.length()}",
    )
  }
  for i in 0..<expected.edges.length() {
    let actual_edge = actual.edges[i]
    let expected_edge = expected.edges[i]
    if actual_edge.tail != expected_edge.tail ||
      actual_edge.head != expected_edge.head ||
      actual_edge.xpenalty != expected_edge.xpenalty ||
      actual_edge.tail_port_x != expected_edge.tail_port_x ||
      actual_edge.head_port_x != expected_edge.head_port_x ||
      actual_edge.tail_port_order != expected_edge.tail_port_order ||
      actual_edge.head_port_order != expected_edge.head_port_order {
      fail(
        "\{label} edge[\{i}] mismatch expected=\{edge_snapshot_summary(expected_edge)} actual=\{edge_snapshot_summary(actual_edge)}",
      )
    }
  }
}

