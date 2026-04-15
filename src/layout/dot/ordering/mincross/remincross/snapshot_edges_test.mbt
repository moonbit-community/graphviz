// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn snapshot_edge_summary(edge : @root.OrderingEdgeSnapshotEntry) -> String {
  "\{edge.tail}->\{edge.head} pen=\{edge.xpenalty} tpx=\{edge.tail_port_x} hpx=\{edge.head_port_x} tpo=\{edge.tail_port_order} hpo=\{edge.head_port_order}"
}

///|
fn assert_snapshot_edge_eq(
  label : String,
  actual : @root.OrderingEdgeSnapshotEntry,
  expected : @root.OrderingEdgeSnapshotEntry,
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
  actual : Array[@root.OrderingEdgeSnapshotEntry],
  expected : Array[@root.OrderingEdgeSnapshotEntry],
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

  let snapshot = build_remincross_input_snapshot({
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
    edge_xpenalty_for: edge => penalties.get(edge.id()).unwrap_or_default(),
  })

  rank_keys.push(2)
  match groups.get(1) {
    Some(list) => list.push("mutated")
    None => fail("missing mutable group")
  }
  cluster_keys["a"] = "changed"

  assert_eq(snapshot.rank_keys, [1])
  assert_eq(snapshot.groups.get(1), Some(["a", "b"]))
  assert_eq(snapshot.cluster_keys.get("a"), Some("cluster_a"))
  assert_snapshot_entries_eq("remincross snapshot edges", snapshot.edges, [
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
  ])
}
