///|
/// Ordering domain: edge snapshot projections for ordering fixture capture.

///|
/// Graphviz parity: ordering-input snapshot capture gates on the same
/// DOT_CAPTURE_ORDERING_INPUTS env flag used by fixture capture workflows.
/// Do not change behavior without updating fixtures/tests.
pub fn should_capture_ordering_inputs() -> Bool {
  @sys.get_env_var("DOT_CAPTURE_ORDERING_INPUTS") is Some(_)
}

///|
/// Graphviz parity: ordering edge snapshot input keeps edge arrays plus
/// optional port metadata aligned by edge index before projection/coalescing.
pub(all) struct OrderingEdgeSnapshotBuildInput {
  edges_out : Array[@cgraph.Edge]
  edge_tail_out : Array[String]
  edge_head_out : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  edge_xpenalty_for : (@cgraph.Edge) -> Int
}

///|
/// Graphviz parity: ordering edge snapshot entry keeps coalescing keys and
/// edge-port metrics grouped for fixture-stable projection order.
pub(all) struct OrderingEdgeSnapshotEntry {
  tail : String
  head : String
  xpenalty : Int
  tail_port_x : Double
  head_port_x : Double
  tail_port_order : Double
  head_port_order : Double
}

///|
/// Graphviz parity: snapshot edge projection keeps raw edge arrays and optional
/// port metadata aligned by index before coalescing/materialization.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_edge_snapshot_entries(
  input : OrderingEdgeSnapshotBuildInput,
) -> Array[OrderingEdgeSnapshotEntry] {
  let entries : Array[OrderingEdgeSnapshotEntry] = []
  let mut idx = 0
  while idx < input.edges_out.length() {
    let tail = input.edge_tail_out[idx]
    let head = input.edge_head_out[idx]
    let tail_port_x =
      if idx < input.edge_tail_port_x.length() { input.edge_tail_port_x[idx] } else { 0.0 }
    let head_port_x =
      if idx < input.edge_head_port_x.length() { input.edge_head_port_x[idx] } else { 0.0 }
    let tail_port_order =
      if idx < input.edge_tail_port_order.length() {
        input.edge_tail_port_order[idx]
      } else {
        0.0
      }
    let head_port_order =
      if idx < input.edge_head_port_order.length() {
        input.edge_head_port_order[idx]
      } else {
        0.0
      }
    entries.push({
      tail,
      head,
      xpenalty: (input.edge_xpenalty_for)(input.edges_out[idx]),
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
    })
    idx = idx + 1
  }
  entries
}

///|
/// Graphviz parity: ordering edge snapshot coalescing preserves first-tail
/// traversal order while applying Graphviz-aligned duplicate-edge coalescing.
/// Do not change behavior without updating fixtures/tests.
pub fn coalesce_ordering_edge_snapshot_entries(
  entries : Array[OrderingEdgeSnapshotEntry],
) -> Array[OrderingEdgeSnapshotEntry] {
  let entries_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  let tail_order : Array[String] = []
  for entry in entries {
    let tail = entry.tail
    if entries_by_tail.get(tail) is None {
      entries_by_tail[tail] = []
      tail_order.push(tail)
    }
    match entries_by_tail.get(tail) {
      Some(list) =>
        list.push(
          (
            entry.tail,
            entry.head,
            entry.xpenalty,
            true,
            entry.tail_port_x,
            entry.head_port_x,
            entry.tail_port_order,
            entry.head_port_order,
          ),
        )
      None => ()
    }
  }
  let coalesced_by_tail = coalesce_order_edges_by_tail(entries_by_tail)
  let coalesced : Array[OrderingEdgeSnapshotEntry] = []
  for tail in tail_order {
    let tail_entries = coalesced_by_tail.get(tail).unwrap_or_default()
    for item in tail_entries {
      let (tail_name, head_name, xpenalty, _constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
        item
      coalesced.push({
        tail: tail_name,
        head: head_name,
        xpenalty,
        tail_port_x,
        head_port_x,
        tail_port_order,
        head_port_order,
      })
    }
  }
  coalesced
}

///|
/// Graphviz parity: root mincross snapshot payload keeps rank-order groups,
/// coalesced edge snapshots, and cluster overlays for fixture capture checks.
pub(all) struct RootMincrossInputSnapshot {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  edges : Array[OrderingEdgeSnapshotEntry]
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
}

///|
/// Graphviz parity: remincross snapshot payload keeps rank-order groups and
/// edge snapshots for fixture capture checks.
pub(all) struct RemincrossInputSnapshot {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  edges : Array[OrderingEdgeSnapshotEntry]
  cluster_keys : Map[String, String]
}

///|
pub let root_mincross_input_snapshot : Ref[RootMincrossInputSnapshot?] = Ref::new(None)

///|
pub let remincross_input_snapshot : Ref[RemincrossInputSnapshot?] = Ref::new(None)

///|
/// Graphviz parity: root mincross snapshot input keeps order-rank groups,
/// edge arrays, and cluster overlays together before capture materialization.
pub(all) struct RootMincrossSnapshotBuildInput {
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
  cluster_skeleton : Map[String, Bool]
  edge_xpenalty_for : (@cgraph.Edge) -> Int
}

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
fn clone_string_map(source : Map[String, String]) -> Map[String, String] {
  let out : Map[String, String] = Map::new()
  for key, value in source {
    out[key] = value
  }
  out
}

///|
fn clone_bool_map(source : Map[String, Bool]) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map::new()
  for key, value in source {
    out[key] = value
  }
  out
}

///|
/// Graphviz parity: root mincross snapshot capture coalesces edge projections
/// and preserves rank-order/cluster overlays for fixture replay checks.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_mincross_input_snapshot(
  input : RootMincrossSnapshotBuildInput,
) -> RootMincrossInputSnapshot {
  let edges =
    coalesce_ordering_edge_snapshot_entries(
      build_ordering_edge_snapshot_entries(
        {
          edges_out: input.edges_out,
          edge_tail_out: input.edge_tail_out,
          edge_head_out: input.edge_head_out,
          edge_tail_port_x: input.edge_tail_port_x,
          edge_head_port_x: input.edge_head_port_x,
          edge_tail_port_order: input.edge_tail_port_order,
          edge_head_port_order: input.edge_head_port_order,
          edge_xpenalty_for: input.edge_xpenalty_for,
        },
      ),
    )
  {
    rank_keys: input.rank_keys.copy(),
    groups: clone_rank_groups(input.groups),
    edges,
    cluster_keys: clone_string_map(input.cluster_keys),
    cluster_skeleton: clone_bool_map(input.cluster_skeleton),
  }
}

///|
/// Graphviz parity: remincross snapshot capture keeps raw edge projections
/// (without coalescing) and preserves rank-order overlays.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_input_snapshot(
  input : RemincrossSnapshotBuildInput,
) -> RemincrossInputSnapshot {
  {
    rank_keys: input.rank_keys.copy(),
    groups: clone_rank_groups(input.groups),
    edges:
      build_ordering_edge_snapshot_entries(
        {
          edges_out: input.edges_out,
          edge_tail_out: input.edge_tail_out,
          edge_head_out: input.edge_head_out,
          edge_tail_port_x: input.edge_tail_port_x,
          edge_head_port_x: input.edge_head_port_x,
          edge_tail_port_order: input.edge_tail_port_order,
          edge_head_port_order: input.edge_head_port_order,
          edge_xpenalty_for: input.edge_xpenalty_for,
        },
      ),
    cluster_keys: clone_string_map(input.cluster_keys),
  }
}

///|
/// Graphviz parity: root mincross pass capture callback records the same
/// pass0-captured reorder snapshot into fixture state when capture is enabled.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_snapshot_capture_callback(
  edge_xpenalty_for : (@cgraph.Edge) -> Int,
) -> (RootMincrossReorderResult, RootMincrossReorderInputs) -> Unit {
  (result, inputs) => {
    if !should_capture_ordering_inputs() {
      return
    }
    let reorder_call_data = result.reorder_call_data
    let snapshot =
      build_root_mincross_input_snapshot(
        {
          rank_keys: reorder_call_data.order_rank_keys_for_mincross,
          groups: result.order_groups_for_mincross,
          edges_out: reorder_call_data.mincross_edge_data.order_edges_out_mincross,
          edge_tail_out: reorder_call_data.mincross_edge_data.order_edge_tail_out_mincross,
          edge_head_out: reorder_call_data.mincross_edge_data.order_edge_head_out_mincross,
          edge_tail_port_x: reorder_call_data.mincross_edge_data.order_edge_tail_port_x_mincross,
          edge_head_port_x: reorder_call_data.mincross_edge_data.order_edge_head_port_x_mincross,
          edge_tail_port_order:
            reorder_call_data.mincross_edge_data.order_edge_tail_port_order_mincross,
          edge_head_port_order:
            reorder_call_data.mincross_edge_data.order_edge_head_port_order_mincross,
          cluster_keys: inputs.order_cluster_keys,
          cluster_skeleton: inputs.order_cluster_skeleton,
          edge_xpenalty_for,
        },
      )
    root_mincross_input_snapshot.val = Some(snapshot)
  }
}

///|
/// Graphviz parity: remincross cleanup capture callback records the same
/// rematerialized startpass=2 reorder snapshot into fixture state when enabled.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_snapshot_capture_callback(
  edge_xpenalty_for : (@cgraph.Edge) -> Int,
) -> (ReMincrossCleanupCaptureInputs) -> Unit {
  (capture_inputs) => {
    if !should_capture_ordering_inputs() {
      return
    }
    let snapshot =
      build_remincross_input_snapshot(
        {
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
        },
      )
    remincross_input_snapshot.val = Some(snapshot)
  }
}
