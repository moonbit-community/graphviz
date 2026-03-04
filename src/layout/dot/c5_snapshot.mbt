///|
/// Stage C Phase C5 split: remincross snapshot
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: snapshot edge projection keeps raw edge arrays and optional
/// port metadata aligned by index before coalescing/materialization.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingEdgeSnapshotBuildInputs {
  edges_out : Array[@cgraph.Edge]
  edge_tail_out : Array[String]
  edge_head_out : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
}

///|
/// Graphviz parity: ordering-input snapshot capture gates on the same
/// DOT_CAPTURE_ORDERING_INPUTS env flag used by fixture capture workflows.
/// Do not change behavior without updating fixtures/tests.
fn should_capture_ordering_inputs() -> Bool {
  @sys.get_env_var("DOT_CAPTURE_ORDERING_INPUTS") is Some(_)
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

fn build_ordering_edges_snapshot(
  build_inputs : OrderingEdgeSnapshotBuildInputs,
) -> Array[OrderingInputEdgeSnapshot] {
  let edges_out = build_inputs.edges_out
  let edge_tail_out = build_inputs.edge_tail_out
  let edge_head_out = build_inputs.edge_head_out
  let edge_tail_port_x = build_inputs.edge_tail_port_x
  let edge_head_port_x = build_inputs.edge_head_port_x
  let edge_tail_port_order = build_inputs.edge_tail_port_order
  let edge_head_port_order = build_inputs.edge_head_port_order
  let edges : Array[OrderingInputEdgeSnapshot] = []
  let mut idx = 0
  while idx < edges_out.length() {
    let tail = edge_tail_out[idx]
    let head = edge_head_out[idx]
    let tail_port_x =
      if idx < edge_tail_port_x.length() { edge_tail_port_x[idx] } else { 0.0 }
    let head_port_x =
      if idx < edge_head_port_x.length() { edge_head_port_x[idx] } else { 0.0 }
    let tail_port_order =
      if idx < edge_tail_port_order.length() {
        edge_tail_port_order[idx]
      } else {
        0.0
      }
    let head_port_order =
      if idx < edge_head_port_order.length() {
        edge_head_port_order[idx]
      } else {
        0.0
      }
    edges.push({
      tail,
      head,
      xpenalty: @dot_shared.edge_xpenalty(edges_out[idx]),
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
    })
    idx = idx + 1
  }
  edges
}

///|
fn coalesce_order_edges_snapshot(
  edges : Array[OrderingInputEdgeSnapshot],
) -> Array[OrderingInputEdgeSnapshot] {
  let entries_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  let tail_order : Array[String] = []
  for edge in edges {
    let tail = edge.tail
    if entries_by_tail.get(tail) is None {
      entries_by_tail[tail] = []
      tail_order.push(tail)
    }
    match entries_by_tail.get(tail) {
      Some(list) =>
        list.push(
          (
            edge.tail,
            edge.head,
            edge.xpenalty,
            true,
            edge.tail_port_x,
            edge.head_port_x,
            edge.tail_port_order,
            edge.head_port_order,
          ),
        )
      None => ()
    }
  }
  let coalesced_by_tail = @ordering.coalesce_order_edges_by_tail(entries_by_tail)
  let coalesced : Array[OrderingInputEdgeSnapshot] = []
  for tail in tail_order {
    let entries = match coalesced_by_tail.get(tail) {
      Some(value) => value
      None => []
    }
    for entry in entries {
      let (tail_name, head_name, xpenalty, _constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
        entry
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
fn capture_root_snapshot(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edges_out : Array[@cgraph.Edge],
  edge_tail_out : Array[String],
  edge_head_out : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
) -> Unit {
  if !should_capture_ordering_inputs() {
    return
  }
  let edges =
    coalesce_order_edges_snapshot(
      build_ordering_edges_snapshot(
        {
          edges_out,
          edge_tail_out,
          edge_head_out,
          edge_tail_port_x,
          edge_head_port_x,
          edge_tail_port_order,
          edge_head_port_order,
        },
      ),
    )
  let snapshot : RootMincrossInputSnapshot = {
    rank_keys: rank_keys.copy(),
    groups: @ordering.clone_rank_groups(groups),
    edges,
    cluster_keys: clone_string_map(cluster_keys),
    cluster_skeleton: clone_bool_map(cluster_skeleton),
  }
  let _ = snapshot.rank_keys
  let _ = snapshot.groups
  let _ = snapshot.edges
  let _ = snapshot.cluster_keys
  let _ = snapshot.cluster_skeleton
  root_mincross_input_snapshot.val = Some(snapshot)
}

///|
/// Graphviz parity: root reorder pass snapshot records the same mincross edge
/// projection and selected rank groups passed to reorder_rank_groups.
fn capture_root_mincross_pass_snapshot(
  result : @ordering.RootMincrossReorderResult,
  inputs : @ordering.RootMincrossReorderInputs,
) -> Unit {
  let reorder_call_data = result.reorder_call_data
  capture_root_snapshot(
    reorder_call_data.order_rank_keys_for_mincross,
    result.order_groups_for_mincross,
    reorder_call_data.mincross_edge_data.order_edges_out_mincross,
    reorder_call_data.mincross_edge_data.order_edge_tail_out_mincross,
    reorder_call_data.mincross_edge_data.order_edge_head_out_mincross,
    reorder_call_data.mincross_edge_data.order_edge_tail_port_x_mincross,
    reorder_call_data.mincross_edge_data.order_edge_head_port_x_mincross,
    reorder_call_data.mincross_edge_data.order_edge_tail_port_order_mincross,
    reorder_call_data.mincross_edge_data.order_edge_head_port_order_mincross,
    inputs.order_cluster_keys,
    inputs.order_cluster_skeleton,
  )
}

///|
fn capture_remincross_snapshot(
  capture_inputs : @ordering.ReMincrossCleanupCaptureInputs,
) -> Unit {
  if !should_capture_ordering_inputs() {
    return
  }
  let snapshot : RemincrossInputSnapshot = {
    rank_keys: capture_inputs.rem_rank_keys.copy(),
    groups: @ordering.clone_rank_groups(capture_inputs.rem_groups),
    edges: build_ordering_edges_snapshot(
      {
        edges_out: capture_inputs.rem_edges_out,
        edge_tail_out: capture_inputs.rem_edge_tail_out,
        edge_head_out: capture_inputs.rem_edge_head_out,
        edge_tail_port_x: capture_inputs.rem_edge_tail_port_x,
        edge_head_port_x: capture_inputs.rem_edge_head_port_x,
        edge_tail_port_order: capture_inputs.rem_edge_tail_port_order,
        edge_head_port_order: capture_inputs.rem_edge_head_port_order,
      },
    ),
    cluster_keys: clone_string_map(capture_inputs.rem_cluster_keys),
  }
  let _ = snapshot.rank_keys
  let _ = snapshot.groups
  let _ = snapshot.edges
  let _ = snapshot.cluster_keys
  remincross_input_snapshot.val = Some(snapshot)
}

///|
priv struct OrderingInputEdgeSnapshot {
  tail : String
  head : String
  xpenalty : Int
  tail_port_x : Double
  head_port_x : Double
  tail_port_order : Double
  head_port_order : Double
}

///|
priv struct RootMincrossInputSnapshot {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  edges : Array[OrderingInputEdgeSnapshot]
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
}

///|
priv struct RemincrossInputSnapshot {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  edges : Array[OrderingInputEdgeSnapshot]
  cluster_keys : Map[String, String]
}

let root_mincross_input_snapshot : Ref[RootMincrossInputSnapshot?] = Ref::new(None)

///|
let remincross_input_snapshot : Ref[RemincrossInputSnapshot?] = Ref::new(None)
