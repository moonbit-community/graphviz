// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Ordering domain: ReMincross snapshot capture stays with the ReMincross
/// cleanup owner so startpass=2 fixture wiring is colocated with the algorithm.

///|
/// Graphviz parity: remincross snapshot payload keeps rank-order groups and
/// edge snapshots for fixture capture checks.
pub(all) struct RemincrossInputSnapshot {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  edges : Array[@root.OrderingEdgeSnapshotEntry]
  cluster_keys : Map[String, String]
}

///|
pub let remincross_input_snapshot : Ref[RemincrossInputSnapshot?] = Ref::new(
  None,
)

///|
/// Graphviz parity: remincross snapshot input keeps order-rank groups,
/// edge arrays, and cluster overlays together before capture materialization.
pub(all) struct RemincrossSnapshotBuildInput {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  edges_out : Array[@cgraph.Edge]
  edge_tail_out : Array[String]
  edge_head_out : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  cluster_keys : Map[String, String]
  edge_xpenalty_for : (@cgraph.Edge) -> Int
}

///|
/// Graphviz parity: remincross snapshot capture keeps raw edge projections
/// (without coalescing) and preserves rank-order overlays.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_input_snapshot(
  input : RemincrossSnapshotBuildInput,
) -> RemincrossInputSnapshot {
  let cloned_cluster_keys : Map[String, String] = Map::new()
  for key, value in input.cluster_keys {
    cloned_cluster_keys[key] = value
  }
  {
    rank_keys: input.rank_keys.copy(),
    groups: @rank_groups.clone_rank_groups(input.groups),
    edges: @root.build_ordering_edge_snapshot_entries({
      edges_out: input.edges_out,
      edge_tail_out: input.edge_tail_out,
      edge_head_out: input.edge_head_out,
      edge_tail_port_x: input.edge_tail_port_x,
      edge_head_port_x: input.edge_head_port_x,
      edge_tail_port_order: input.edge_tail_port_order,
      edge_head_port_order: input.edge_head_port_order,
      edge_xpenalty_for: input.edge_xpenalty_for,
    }),
    cluster_keys: cloned_cluster_keys,
  }
}

///|
/// Graphviz parity: remincross cleanup capture callback records the same
/// rematerialized startpass=2 reorder snapshot into fixture state when enabled.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_snapshot_capture_callback(
  edge_xpenalty_for : (@cgraph.Edge) -> Int,
) -> (ReMincrossCleanupCaptureInputs) -> Unit {
  capture_inputs => {
    if !@root.should_capture_ordering_inputs() {
      return
    }
    let snapshot = build_remincross_input_snapshot({
      rank_keys: capture_inputs.rem_rank_keys,
      groups: capture_inputs.rem_groups,
      edges_out: capture_inputs.rem_edges_out,
      edge_tail_out: capture_inputs.rem_edge_tail_out,
      edge_head_out: capture_inputs.rem_edge_head_out,
      edge_tail_port_x: capture_inputs.rem_edge_tail_port_x,
      edge_head_port_x: capture_inputs.rem_edge_head_port_x,
      edge_tail_port_order: capture_inputs.rem_edge_tail_port_order,
      edge_head_port_order: capture_inputs.rem_edge_head_port_order,
      cluster_keys: capture_inputs.rem_cluster_keys,
      edge_xpenalty_for,
    })
    remincross_input_snapshot.val = Some(snapshot)
  }
}
