///|
/// Stage C Phase C5 split: remincross snapshot
/// helpers for focused ReMincross responsibilities.

fn build_ordering_edges_snapshot(
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
fn capture_root_mincross_snapshot(
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
  if @sys.get_env_var("DOT_CAPTURE_ORDERING_INPUTS") is None {
    return
  }
  let edges =
    coalesce_order_edges_snapshot(
      build_ordering_edges_snapshot(
        edges_out,
        edge_tail_out,
        edge_head_out,
        edge_tail_port_x,
        edge_head_port_x,
        edge_tail_port_order,
        edge_head_port_order,
      ),
    )
  let snapshot_cluster_keys : Map[String, String] = Map::new()
  for key, value in cluster_keys {
    snapshot_cluster_keys[key] = value
  }
  let snapshot_cluster_skeleton : Map[String, Bool] = Map::new()
  for key, value in cluster_skeleton {
    snapshot_cluster_skeleton[key] = value
  }
  let snapshot : RootMincrossInputSnapshot = {
    rank_keys: rank_keys.copy(),
    groups: clone_rank_groups(groups),
    edges,
    cluster_keys: snapshot_cluster_keys,
    cluster_skeleton: snapshot_cluster_skeleton,
  }
  let _ = snapshot.rank_keys
  let _ = snapshot.groups
  let _ = snapshot.edges
  let _ = snapshot.cluster_keys
  let _ = snapshot.cluster_skeleton
  root_mincross_input_snapshot.val = Some(snapshot)
}

///|
fn capture_remincross_snapshot(
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
  if @sys.get_env_var("DOT_CAPTURE_ORDERING_INPUTS") is None {
    return
  }
  let snapshot_cluster_keys : Map[String, String] = Map::new()
  for key, value in cluster_keys {
    snapshot_cluster_keys[key] = value
  }
  let snapshot : RemincrossInputSnapshot = {
    rank_keys: rank_keys.copy(),
    groups: clone_rank_groups(groups),
    edges: build_ordering_edges_snapshot(
      edges_out,
      edge_tail_out,
      edge_head_out,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
    ),
    cluster_keys: snapshot_cluster_keys,
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

///|
let root_mincross_groups_override : Ref[Map[Int, Array[String]]?] = Ref::new(None)

///|
let remincross_root_tail_order_override_snapshot : Ref[Array[String]?] =
  Ref::new(None)
