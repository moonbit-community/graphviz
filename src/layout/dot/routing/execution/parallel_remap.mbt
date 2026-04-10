// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn parallel_remap_direction_key(
  edge : @cgraph.Edge,
  tail : String,
  head : String,
) -> String {
  let sameport_tag = if @edge_ops.edge_has_sameport_mark(edge) {
    "sameport"
  } else {
    "plain"
  }
  "\{tail}|\{@edge_identity.port_key(edge.tail_port())}|\{head}|\{@edge_identity.port_key(edge.head_port())}|\{@edge_ops.edge_dir_attr_key(edge)}|\{sameport_tag}"
}

///|
/// Graphviz parity: duplicate regular-edge remap groups follow one-direction
/// parallel classes only.
/// Do not change behavior without updating fixtures/tests.
fn collect_parallel_remap_edge_ids(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
) -> Array[Array[Int]] {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_direction : Map[String, String] = Map::new()
  let group_has_mixed_direction : Map[String, Bool] = Map::new()
  for edge in edges {
    if @edge_semantics.edge_has_label(edge) {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      continue
    }
    let tail_rank = ranks.get(tail).unwrap_or_default()
    let head_rank = ranks.get(head).unwrap_or_default()
    if tail_rank == head_rank {
      continue
    }
    let key = @edge_ops.edge_parallel_group_key(edge)
    let direction_key = parallel_remap_direction_key(edge, tail, head)
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_direction.get(key) {
      Some(first_direction) =>
        if first_direction != direction_key {
          group_has_mixed_direction[key] = true
        }
      None => {
        group_first_direction[key] = direction_key
        group_has_mixed_direction[key] = false
      }
    }
  }
  let remap_groups : Array[Array[Int]] = []
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    let mixed_direction = match group_has_mixed_direction.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_direction {
      continue
    }
    ids.sort()
    remap_groups.push(ids)
  }
  remap_groups
}

///|
/// Graphviz parity: remap groups are applied only when all grouped ids already
/// have routed layouts.
/// Do not change behavior without updating fixtures/tests.
priv struct CompleteParallelRemapGroupsCollectInput {
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  has_layout : (Int) -> Bool
}

///|
fn collect_complete_parallel_remap_groups(
  input : CompleteParallelRemapGroupsCollectInput,
) -> Array[Array[Int]] {
  let complete_groups : Array[Array[Int]] = []
  for ids in collect_parallel_remap_edge_ids(input.edges, input.ranks) {
    let mut all_present = true
    for edge_id in ids {
      if !(input.has_layout)(edge_id) {
        all_present = false
        break
      }
    }
    if all_present {
      complete_groups.push(ids)
    }
  }
  complete_groups
}

///|
priv struct ParallelRemapAssignment {
  target_edge_id : Int
  source_edge_id : Int
}

///|
/// Graphviz parity: each parallel remap group applies reversed source slots
/// to ascending target ids.
/// Do not change behavior without updating fixtures/tests.
priv struct ParallelRemapAssignmentsBuildInput {
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  has_layout : (Int) -> Bool
}

///|
fn build_parallel_remap_assignments(
  input : ParallelRemapAssignmentsBuildInput,
) -> Array[ParallelRemapAssignment] {
  let assignments : Array[ParallelRemapAssignment] = []
  for
    ids in collect_complete_parallel_remap_groups({
      edges: input.edges,
      ranks: input.ranks,
      has_layout: input.has_layout,
    }) {
    let mut out_idx = 0
    let mut src_idx = ids.length()
    while out_idx < ids.length() {
      src_idx = src_idx - 1
      assignments.push({
        target_edge_id: ids[out_idx],
        source_edge_id: ids[src_idx],
      })
      out_idx = out_idx + 1
    }
  }
  assignments
}

///|
/// Graphviz parity: duplicate regular-edge spline slots are assigned in
/// pair order after routing, but only within one-direction parallel classes.
/// Do not change behavior without updating fixtures/tests.
priv struct ParallelEdgeLayoutsRemapInput {
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  edges_out_by_id : Map[Int, DotLayoutEdge]
  edge_port_label_pos_fn : EdgePortLabelPosFn
}

///|
fn remap_parallel_edge_layouts(input : ParallelEdgeLayoutsRemapInput) -> Unit {
  let edges = input.edges
  let ranks = input.ranks
  let edges_out_by_id = input.edges_out_by_id
  let assignments = build_parallel_remap_assignments({
    edges,
    ranks,
    has_layout: edge_id => edges_out_by_id.get(edge_id) is Some(_),
  })
  let remap_snapshot : Map[Int, DotLayoutEdge] = Map::new()
  for assignment in assignments {
    match edges_out_by_id.get(assignment.target_edge_id) {
      Some(layout) => remap_snapshot[assignment.target_edge_id] = layout
      None => ()
    }
    match edges_out_by_id.get(assignment.source_edge_id) {
      Some(layout) => remap_snapshot[assignment.source_edge_id] = layout
      None => ()
    }
  }
  for assignment in assignments {
    let target_layout = match remap_snapshot.get(assignment.target_edge_id) {
      Some(value) => value
      None => continue
    }
    let source_layout = match remap_snapshot.get(assignment.source_edge_id) {
      Some(value) => value
      None => continue
    }
    edges_out_by_id[assignment.target_edge_id] = remap_edge_layout_edge(
      target_layout.edge,
      source_layout,
      input.edge_port_label_pos_fn,
    )
  }
}
