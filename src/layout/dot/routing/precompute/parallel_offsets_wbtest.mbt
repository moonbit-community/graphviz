// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "collect_parallel_offset_edge_flags respects staged orientation and labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  let labeled = graph.edge(a, b, name="labeled")
  labeled.set_attr("label", "mid")

  let (reversed_by_id, has_label_by_id) = collect_parallel_offset_edge_flags(
    [forward, labeled],
    ["b", "a"],
    ["a", "b"],
  )

  assert_eq(reversed_by_id.get(forward.id()), Some(true))
  assert_eq(reversed_by_id.get(labeled.id()), Some(false))
  assert_eq(has_label_by_id.get(forward.id()), Some(false))
  assert_eq(has_label_by_id.get(labeled.id()), Some(true))
}

///|
test "build_edge_parallel_offsets keeps sameport-marked edges on the outer slot" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let plain = graph.edge(a, b)
  let sameport = graph.edge(a, b, name="sameport")
  let labeled = graph.edge(a, b, name="labeled")
  sameport.set_attr("samehead", "group")
  labeled.set_attr("label", "mid")

  let edge_has_label_by_id : Map[Int, Bool] = Map::new()
  edge_has_label_by_id[plain.id()] = false
  edge_has_label_by_id[sameport.id()] = false
  edge_has_label_by_id[labeled.id()] = true

  let offsets = build_edge_parallel_offsets({
    edges: [plain, sameport, labeled],
    edge_has_label_by_id,
    ranks: { "a": 0, "b": 1 },
    nodesep_pt: 10.0,
    edge_reversed_by_id: Map::new(),
    cluster_keys: Map::new(),
  })

  assert_eq(offsets.get(sameport.id()), Some(5.0))
  assert_eq(offsets.get(plain.id()), Some(-5.0))
  assert_eq(offsets.get(labeled.id()), None)
}

///|
test "build_edge_parallel_offsets prefers the reverse pair whose tail lacks a self loop" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let ab = graph.edge(a, b)
  let ba = graph.edge(b, a)
  ignore(graph.edge(a, a))

  let edge_has_label_by_id : Map[Int, Bool] = Map::new()
  edge_has_label_by_id[ab.id()] = false
  edge_has_label_by_id[ba.id()] = false
  let edge_reversed_by_id : Map[Int, Bool] = Map::new()
  edge_reversed_by_id[ab.id()] = false
  edge_reversed_by_id[ba.id()] = true

  let offsets = build_edge_parallel_offsets({
    edges: [ab, ba],
    edge_has_label_by_id,
    ranks: { "a": 0, "b": 1 },
    nodesep_pt: 12.0,
    edge_reversed_by_id,
    cluster_keys: Map::new(),
  })

  assert_eq(offsets.get(ba.id()), Some(6.0))
  assert_eq(offsets.get(ab.id()), Some(-6.0))
}

///|
test "build_edge_parallel_offsets reverses slot order when parallel edges mix dir attrs" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  let back = graph.edge(a, b, name="back")
  back.set_attr("dir", "back")

  let edge_has_label_by_id : Map[Int, Bool] = Map::new()
  edge_has_label_by_id[forward.id()] = false
  edge_has_label_by_id[back.id()] = false

  let offsets = build_edge_parallel_offsets({
    edges: [forward, back],
    edge_has_label_by_id,
    ranks: { "a": 0, "b": 1 },
    nodesep_pt: 10.0,
    edge_reversed_by_id: Map::new(),
    cluster_keys: Map::new(),
  })

  assert_eq(offsets.get(back.id()), Some(5.0))
  assert_eq(offsets.get(forward.id()), Some(-5.0))
}

///|
test "build_edge_parallel_offsets keeps intercluster reverse pairs in cluster-constrained order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let ab = graph.edge(a, b)
  let ba = graph.edge(b, a)

  let edge_has_label_by_id : Map[Int, Bool] = Map::new()
  edge_has_label_by_id[ab.id()] = false
  edge_has_label_by_id[ba.id()] = false

  let edge_reversed_by_id : Map[Int, Bool] = Map::new()
  edge_reversed_by_id[ab.id()] = false
  edge_reversed_by_id[ba.id()] = true

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster_a"
  cluster_keys["b"] = "cluster_b"

  let offsets = build_edge_parallel_offsets({
    edges: [ab, ba],
    edge_has_label_by_id,
    ranks: { "a": 0, "b": 1 },
    nodesep_pt: 12.0,
    edge_reversed_by_id,
    cluster_keys,
  })

  assert_eq(offsets.get(ab.id()), Some(6.0))
  assert_eq(offsets.get(ba.id()), Some(-6.0))
}
