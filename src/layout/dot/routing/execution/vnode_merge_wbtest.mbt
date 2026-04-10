// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "vnode_is_merged stays false for duplicate parallel neighbors but true for distinct neighbors" {
  let duplicate_graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  let duplicate_a = duplicate_graph.node("a")
  let duplicate_b = duplicate_graph.node("b")
  let duplicate_1 = duplicate_graph.edge(duplicate_a, duplicate_b)
  let duplicate_2 = duplicate_graph.edge(duplicate_a, duplicate_b)
  let duplicate_vnodes : Map[String, Array[String]] = Map::new()
  duplicate_vnodes[@edge_identity.edge_vnode_key(duplicate_1)] = ["v"]
  duplicate_vnodes[@edge_identity.edge_vnode_key(duplicate_2)] = ["v"]
  let duplicate_adjacency = @routesplines.build_path_adjacency(
    [duplicate_1, duplicate_2],
    duplicate_vnodes,
    [],
    [],
  )

  let merged_graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  let merged_a = merged_graph.node("a")
  let merged_b = merged_graph.node("b")
  let merged_c = merged_graph.node("c")
  let merged_d = merged_graph.node("d")
  let merged_1 = merged_graph.edge(merged_a, merged_b)
  let merged_2 = merged_graph.edge(merged_c, merged_d)
  let merged_vnodes : Map[String, Array[String]] = Map::new()
  merged_vnodes[@edge_identity.edge_vnode_key(merged_1)] = ["v"]
  merged_vnodes[@edge_identity.edge_vnode_key(merged_2)] = ["v"]
  let merged_adjacency = @routesplines.build_path_adjacency(
    [merged_1, merged_2],
    merged_vnodes,
    [],
    [],
  )

  assert_false(vnode_is_merged("v", duplicate_adjacency))
  assert_true(vnode_is_merged("v", merged_adjacency))
}
