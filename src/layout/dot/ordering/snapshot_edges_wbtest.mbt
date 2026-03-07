///|
fn snapshot_edge_summary(edge : OrderingEdgeSnapshotEntry) -> String {
  "\{edge.tail}->\{edge.head} pen=\{edge.xpenalty} tpx=\{edge.tail_port_x} hpx=\{edge.head_port_x} tpo=\{edge.tail_port_order} hpo=\{edge.head_port_order}"
}

///|
fn assert_snapshot_edge_eq(
  label : String,
  actual : OrderingEdgeSnapshotEntry,
  expected : OrderingEdgeSnapshotEntry,
) -> Unit raise {
  if actual.tail != expected.tail ||
    actual.head != expected.head ||
    actual.xpenalty != expected.xpenalty ||
    actual.tail_port_x != expected.tail_port_x ||
    actual.head_port_x != expected.head_port_x ||
    actual.tail_port_order != expected.tail_port_order ||
    actual.head_port_order != expected.head_port_order {
    fail(
      "\{label} mismatch expected=\{snapshot_edge_summary(expected)} actual=\{snapshot_edge_summary(actual)}",
    )
  }
}

///|
fn assert_snapshot_entries_eq(
  label : String,
  actual : Array[OrderingEdgeSnapshotEntry],
  expected : Array[OrderingEdgeSnapshotEntry],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<expected.length() {
    assert_snapshot_edge_eq("\{label}[\{i}]", actual[i], expected[i])
  }
}

///|
fn make_snapshot_penalty_lookup(
  entries : Array[(@cgraph.Edge, Int)],
) -> Map[Int, Int] {
  let penalties : Map[Int, Int] = Map::new()
  for pair in entries {
    let (edge, penalty) = pair
    penalties[edge.id()] = penalty
  }
  penalties
}

///|
test "build_ordering_edge_snapshot_entries projects remapped endpoints and defaults missing port data" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let ab = graph.edge(a, b)
  let ac = graph.edge(a, c)
  let penalties = make_snapshot_penalty_lookup([(ab, 7), (ac, 9)])

  let entries =
    build_ordering_edge_snapshot_entries(
      {
        edges_out: [ab, ac],
        edge_tail_out: ["tail-ab", "tail-ac"],
        edge_head_out: ["head-ab", "head-ac"],
        edge_tail_port_x: [1.5],
        edge_head_port_x: [2.5, 3.5],
        edge_tail_port_order: [4.5],
        edge_head_port_order: [],
        edge_xpenalty_for: (edge) => penalties.get(edge.id()).unwrap_or_default(),
      },
    )

  assert_snapshot_entries_eq(
    "projected entries",
    entries,
    [
      {
        tail: "tail-ab",
        head: "head-ab",
        xpenalty: 7,
        tail_port_x: 1.5,
        head_port_x: 2.5,
        tail_port_order: 4.5,
        head_port_order: 0.0,
      },
      {
        tail: "tail-ac",
        head: "head-ac",
        xpenalty: 9,
        tail_port_x: 0.0,
        head_port_x: 3.5,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
  )
}

///|
test "coalesce_ordering_edge_snapshot_entries preserves first tail order and only sums positive duplicate penalties" {
  let entries : Array[OrderingEdgeSnapshotEntry] = [
    {
      tail: "b",
      head: "x",
      xpenalty: 1,
      tail_port_x: 0.0,
      head_port_x: 0.0,
      tail_port_order: 0.0,
      head_port_order: 0.0,
    },
    {
      tail: "a",
      head: "z",
      xpenalty: 5,
      tail_port_x: 0.0,
      head_port_x: 0.0,
      tail_port_order: 0.0,
      head_port_order: 0.0,
    },
    {
      tail: "b",
      head: "x",
      xpenalty: 2,
      tail_port_x: 9.0,
      head_port_x: 9.0,
      tail_port_order: 0.0,
      head_port_order: 0.0,
    },
    {
      tail: "b",
      head: "x",
      xpenalty: 0,
      tail_port_x: 4.0,
      head_port_x: 5.0,
      tail_port_order: 0.0,
      head_port_order: 0.0,
    },
    {
      tail: "b",
      head: "y",
      xpenalty: 4,
      tail_port_x: 0.0,
      head_port_x: 0.0,
      tail_port_order: 1.0,
      head_port_order: 2.0,
    },
  ]

  let coalesced = coalesce_ordering_edge_snapshot_entries(entries)

  assert_snapshot_entries_eq(
    "coalesced entries",
    coalesced,
    [
      {
        tail: "b",
        head: "x",
        xpenalty: 3,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: "b",
        head: "x",
        xpenalty: 0,
        tail_port_x: 4.0,
        head_port_x: 5.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: "b",
        head: "y",
        xpenalty: 4,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 1.0,
        head_port_order: 2.0,
      },
      {
        tail: "a",
        head: "z",
        xpenalty: 5,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
  )
}

///|
test "build_root_mincross_input_snapshot clones overlays and coalesces duplicate edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let ab1 = graph.edge(a, b)
  let ab2 = graph.edge(a, b)
  let ac = graph.edge(a, c)
  let penalties = make_snapshot_penalty_lookup([(ab1, 2), (ab2, 3), (ac, 5)])

  let rank_keys : Array[Int] = [0, 1]
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "cluster_skel"]
  groups[1] = ["b", "c"]
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_skel"] = "cluster_0"
  let cluster_skeleton : Map[String, Bool] = Map::new()
  cluster_skeleton["cluster_skel"] = true

  let snapshot =
    build_root_mincross_input_snapshot(
      {
        rank_keys,
        groups,
        edges_out: [ab1, ab2, ac],
        edge_tail_out: ["a", "a", "a"],
        edge_head_out: ["b", "b", "c"],
        edge_tail_port_x: [0.0, 8.0, 1.0],
        edge_head_port_x: [0.0, 9.0, 2.0],
        edge_tail_port_order: [0.0, 0.0, 1.0],
        edge_head_port_order: [0.0, 0.0, 2.0],
        cluster_keys,
        cluster_skeleton,
        edge_xpenalty_for: (edge) => penalties.get(edge.id()).unwrap_or_default(),
      },
    )

  rank_keys.push(99)
  match groups.get(0) {
    Some(list) => list.push("mutated")
    None => fail("missing mutable group")
  }
  cluster_keys["cluster_skel"] = "changed"
  cluster_skeleton["cluster_skel"] = false

  assert_eq(snapshot.rank_keys, [0, 1])
  assert_eq(snapshot.groups.get(0), Some(["a", "cluster_skel"]))
  assert_eq(snapshot.cluster_keys.get("cluster_skel"), Some("cluster_0"))
  assert_eq(snapshot.cluster_skeleton.get("cluster_skel"), Some(true))
  assert_snapshot_entries_eq(
    "root snapshot edges",
    snapshot.edges,
    [
      {
        tail: "a",
        head: "b",
        xpenalty: 5,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: "a",
        head: "c",
        xpenalty: 5,
        tail_port_x: 1.0,
        head_port_x: 2.0,
        tail_port_order: 1.0,
        head_port_order: 2.0,
      },
    ],
  )
}

///|
test "build_remincross_input_snapshot preserves duplicate edges without coalescing" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let ab1 = graph.edge(a, b)
  let ab2 = graph.edge(a, b)
  let penalties = make_snapshot_penalty_lookup([(ab1, 2), (ab2, 3)])

  let rank_keys : Array[Int] = [1]
  let groups : Map[Int, Array[String]] = Map::new()
  groups[1] = ["a", "b"]
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster_a"

  let snapshot =
    build_remincross_input_snapshot(
      {
        rank_keys,
        groups,
        edges_out: [ab1, ab2],
        edge_tail_out: ["a", "a"],
        edge_head_out: ["b", "b"],
        edge_tail_port_x: [1.0, 2.0],
        edge_head_port_x: [3.0, 4.0],
        edge_tail_port_order: [5.0, 6.0],
        edge_head_port_order: [7.0, 8.0],
        cluster_keys,
        edge_xpenalty_for: (edge) => penalties.get(edge.id()).unwrap_or_default(),
      },
    )

  rank_keys.push(2)
  match groups.get(1) {
    Some(list) => list.push("mutated")
    None => fail("missing mutable group")
  }
  cluster_keys["a"] = "changed"

  assert_eq(snapshot.rank_keys, [1])
  assert_eq(snapshot.groups.get(1), Some(["a", "b"]))
  assert_eq(snapshot.cluster_keys.get("a"), Some("cluster_a"))
  assert_snapshot_entries_eq(
    "remincross snapshot edges",
    snapshot.edges,
    [
      {
        tail: "a",
        head: "b",
        xpenalty: 2,
        tail_port_x: 1.0,
        head_port_x: 3.0,
        tail_port_order: 5.0,
        head_port_order: 7.0,
      },
      {
        tail: "a",
        head: "b",
        xpenalty: 3,
        tail_port_x: 2.0,
        head_port_x: 4.0,
        tail_port_order: 6.0,
        head_port_order: 8.0,
      },
    ],
  )
}
