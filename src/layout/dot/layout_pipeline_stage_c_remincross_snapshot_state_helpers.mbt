///|
/// Extracted from layout_pipeline_helpers.mbt to keep ReMincross snapshot
/// structs/state refs and touch helpers isolated and maintainable.

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

///|
fn touch_root_mincross_input_snapshot_fields(
  snapshot : RootMincrossInputSnapshot,
) -> Unit {
  let _ = snapshot.rank_keys
  let _ = snapshot.groups
  let _ = snapshot.edges
  let _ = snapshot.cluster_keys
  let _ = snapshot.cluster_skeleton
}

///|
fn touch_remincross_input_snapshot_fields(
  snapshot : RemincrossInputSnapshot,
) -> Unit {
  let _ = snapshot.rank_keys
  let _ = snapshot.groups
  let _ = snapshot.edges
  let _ = snapshot.cluster_keys
}

///|
let root_mincross_input_snapshot : Ref[RootMincrossInputSnapshot?] = Ref::new(None)

///|
let remincross_input_snapshot : Ref[RemincrossInputSnapshot?] = Ref::new(None)

///|
let root_mincross_groups_override : Ref[Map[Int, Array[String]]?] = Ref::new(None)

///|
let remincross_root_tail_order_override_snapshot : Ref[Array[String]?] =
  Ref::new(None)

