///|
/// Extracted from layout_pipeline_remincross_helpers.mbt to keep
/// ordering-input snapshot capture helpers isolated and maintainable.

fn should_capture_ordering_inputs() -> Bool {
  @sys.get_env_var("DOT_CAPTURE_ORDERING_INPUTS") is Some(_)
}

///|
fn should_capture_ordering_fixture_mode() -> Bool {
  @sys.get_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE") is Some(_)
}

///|
fn clone_groups_for_ordering_input_snapshot(
  groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  clone_rank_groups(groups)
}

///|
fn clone_string_map_for_ordering_input_snapshot(
  values : Map[String, String],
) -> Map[String, String] {
  let out : Map[String, String] = Map::new()
  for key, value in values {
    out[key] = value
  }
  out
}

///|
fn clone_bool_map_for_ordering_input_snapshot(
  values : Map[String, Bool],
) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map::new()
  for key, value in values {
    out[key] = value
  }
  out
}

///|
fn build_ordering_input_edges_snapshot(
  edges_out : Array[@cgraph.Edge],
  edge_tail_out : Array[String],
  edge_head_out : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
) -> Array[OrderingInputEdgeSnapshot] {
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
      xpenalty: edge_xpenalty(edges_out[idx]),
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
fn coalesce_ordering_input_edges_snapshot(
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
  let coalesced_by_tail = coalesce_order_edges_by_tail(entries_by_tail)
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
fn capture_root_mincross_input_snapshot(
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
    coalesce_ordering_input_edges_snapshot(
      build_ordering_input_edges_snapshot(
        edges_out,
        edge_tail_out,
        edge_head_out,
        edge_tail_port_x,
        edge_head_port_x,
        edge_tail_port_order,
        edge_head_port_order,
      ),
    )
  let snapshot : RootMincrossInputSnapshot = {
    rank_keys: rank_keys.copy(),
    groups: clone_groups_for_ordering_input_snapshot(groups),
    edges,
    cluster_keys: clone_string_map_for_ordering_input_snapshot(cluster_keys),
    cluster_skeleton: clone_bool_map_for_ordering_input_snapshot(
      cluster_skeleton,
    ),
  }
  touch_root_mincross_input_snapshot_fields(snapshot)
  root_mincross_input_snapshot.val = Some(snapshot)
}

///|
fn capture_remincross_input_snapshot(
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
) -> Unit {
  if !should_capture_ordering_inputs() {
    return
  }
  let snapshot : RemincrossInputSnapshot = {
    rank_keys: rank_keys.copy(),
    groups: clone_groups_for_ordering_input_snapshot(groups),
    edges: build_ordering_input_edges_snapshot(
      edges_out,
      edge_tail_out,
      edge_head_out,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
    ),
    cluster_keys: clone_string_map_for_ordering_input_snapshot(cluster_keys),
  }
  touch_remincross_input_snapshot_fields(snapshot)
  remincross_input_snapshot.val = Some(snapshot)
}

