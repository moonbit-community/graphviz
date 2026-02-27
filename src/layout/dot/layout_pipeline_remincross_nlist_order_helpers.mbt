///|
/// Extracted from layout_pipeline_remincross_materialize_helpers.mbt to keep
/// ReMincross GD_nlist ordering and node-order seeding helpers isolated.

/// Graphviz parity: ReMincross GD_nlist order keeps cluster-local blocks in
/// first-seen cluster sequence and replays each cluster block by rank-desc
/// reverse-order before root-cluster nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_nlist_order(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
) -> Array[String] {
  let rem_order_creation =
    build_rem_order_creation_sequence(creation_order, rem_vnode_creation)
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let debug_names : Array[String] = [
      "i-gd-gd",
      "o-gd-vrml",
      "i-core-ps",
      "i-core-svg",
      "i-svg",
    ]
    for name in debug_names {
      let cluster = match rem_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      let rank = match rem_ranks.get(name) {
        Some(value) => value
        None => -1
      }
      println("remincross cluster_key \{name}=\{cluster} rank=\{rank}")
    }
  }
  let rem_nlist_order =
    if cluster_order_index.length() <= 2 {
      // Graphviz parity: single-cluster/root-only remincross materialization
      // replays tails in reverse rem_order_creation sequence.
      let reversed : Array[String] = []
      let mut idx = rem_order_creation.length()
      while idx > 0 {
        idx = idx - 1
        reversed.push(rem_order_creation[idx])
      }
      reversed
    } else {
      build_remincross_cluster_tail_order(
        rem_order_creation,
        rem_ranks,
        rem_cluster_keys,
        rem_edge_creation,
        cluster_order_index,
      )
    }
  if rem_nlist_order.length() < rem_order_creation.length() {
    let seen : Map[String, Bool] = Map::new()
    for name in rem_nlist_order {
      seen[name] = true
    }
    for name in rem_order_creation {
      if seen.get(name) is None {
        rem_nlist_order.push(name)
        seen[name] = true
      }
    }
  }
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let rem_creation_joined = rem_order_creation.join(" ")
    let rem_nlist_joined = rem_nlist_order.join(" ")
    println("remincross rem_order_creation \{rem_creation_joined}")
    println("remincross rem_nlist_order \{rem_nlist_joined}")
  }
  rem_nlist_order
}

///|
/// Graphviz parity: root/ReMincross node-order seeding follows GD_nlist order
/// and fills missing nodes from current rank-group index.
/// Do not change behavior without updating fixtures/tests.
fn build_order_node_order_from_nlist_and_groups(
  nlist_order : Array[String],
  node_map : Map[String, @cgraph.Node],
  groups : Map[Int, Array[String]],
) -> Map[String, Int] {
  let node_order_out : Map[String, Int] = Map::new()
  let mut node_idx = 0
  for name in nlist_order {
    if node_map.get(name) is Some(_) {
      node_order_out[name] = node_idx
      node_idx = node_idx + 1
    }
  }
  let order_index = build_order_index(groups)
  for name, idx in order_index {
    if node_order_out.get(name) is None {
      node_order_out[name] = idx
    }
  }
  node_order_out
}
