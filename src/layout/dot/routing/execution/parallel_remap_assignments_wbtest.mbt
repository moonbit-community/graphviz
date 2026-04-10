// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "collect_parallel_remap_edge_ids keeps plain and sameport duplicate groups separate" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let plain_1 = graph.edge(a, b)
  let plain_2 = graph.edge(a, b)
  let sameport_1 = graph.edge(a, b)
  let sameport_2 = graph.edge(a, b)
  let labeled = graph.edge(a, b)
  let same_rank = graph.edge(a, c)
  let self_edge = graph.edge(c, c)
  sameport_1.set_attr("samehead", "g")
  sameport_2.set_attr("samehead", "g")
  labeled.set_attr("label", "mid")

  let ranks : Map[String, Int] = { "a": 0, "b": 2, "c": 0 }
  let groups = normalize_id_groups(
    collect_parallel_remap_edge_ids(
      [plain_1, plain_2, sameport_1, sameport_2, labeled, same_rank, self_edge],
      ranks,
    ),
  )

  assert_eq(groups, [
    [plain_1.id(), plain_2.id()],
    [sameport_1.id(), sameport_2.id()],
  ])
}

///|
test "collect_parallel_remap_edge_ids drops duplicate classes once directions are mixed" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward_1 = graph.edge(a, b)
  let forward_2 = graph.edge(a, b)
  let reverse = graph.edge(b, a)

  let ranks : Map[String, Int] = { "a": 0, "b": 2 }
  let groups = collect_parallel_remap_edge_ids(
    [forward_1, forward_2, reverse],
    ranks,
  )

  assert_eq(groups, [])
}

///|
test "build_parallel_remap_assignments requires complete groups and reverses source slots" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let edge_3 = graph.edge(a, b)

  let ranks : Map[String, Int] = { "a": 0, "b": 2 }
  let incomplete = collect_complete_parallel_remap_groups({
    edges: [edge_1, edge_2, edge_3],
    ranks,
    has_layout: edge_id => edge_id != edge_2.id(),
  })
  assert_eq(incomplete, [])

  let assignments = build_parallel_remap_assignments({
    edges: [edge_1, edge_2, edge_3],
    ranks,
    has_layout: _ => true,
  })

  assert_eq(
    assignments.map(fn(assignment) {
      "\{assignment.target_edge_id}->\{assignment.source_edge_id}"
    }),
    [
      "\{edge_1.id()}->\{edge_3.id()}",
      "\{edge_2.id()}->\{edge_2.id()}",
      "\{edge_3.id()}->\{edge_1.id()}",
    ],
  )
}
