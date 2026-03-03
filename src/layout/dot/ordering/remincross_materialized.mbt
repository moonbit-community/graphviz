///|
/// Ordering domain: clustered ReMincross materialization helpers used by
/// Stage C cleanup passes before startpass=2 reorder.

///|
/// Graphviz parity: nested intercluster merge-chain bonuses are applied to the
/// first representative coalesced edge entry for each merge key.
pub fn apply_intercluster_bonus(
  order_edges_by_tail_coalesced : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  intercluster_bonus : Map[String, Int],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  if intercluster_bonus.length() == 0 {
    return order_edges_by_tail_coalesced
  }
  let remaining_bonus : Map[String, Int] = Map::new()
  for key, value in intercluster_bonus {
    remaining_bonus[key] = value
  }
  let adjusted : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  for tail_name, entries in order_edges_by_tail_coalesced {
    let adjusted_entries : Array[(String, String, Int, Bool, Double, Double, Double, Double)] = []
    for entry in entries {
      let (tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
        entry
      let key =
        order_edge_merge_key(
          tail,
          head,
          constraint,
          tail_port_order,
          head_port_order,
        )
      let mut adjusted_penalty = penalty
      match remaining_bonus.get(key) {
        Some(extra) =>
          if extra > 0 {
            adjusted_penalty = adjusted_penalty + extra
            remaining_bonus[key] = 0
          }
        None => ()
      }
      adjusted_entries.push(
        (tail, head, adjusted_penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order),
      )
    }
    adjusted[tail_name] = adjusted_entries
  }
  adjusted
}

///|
/// Graphviz parity: ReMincross creation-order replay starts from tail creation
/// order and appends per-tail vnode sequences with stable dedupe.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_order_creation(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
) -> Array[String] {
  let rem_order_creation : Array[String] = []
  let rem_seen : Map[String, Bool] = Map::new()
  for tail_name in creation_order {
    append_creation_name(
      rem_order_creation,
      rem_seen,
      tail_name,
    )
    let vnodes = rem_vnode_creation.get(tail_name).unwrap_or_default()
    for vnode in vnodes {
      append_creation_name(
        rem_order_creation,
        rem_seen,
        vnode,
      )
    }
  }
  rem_order_creation
}

///|
/// Graphviz parity: remincross GD_nlist tail order appends any creation-order
/// names missing from clustered/single-cluster replay with stable dedupe.
/// Do not change behavior without updating fixtures/tests.
fn append_missing_creation_order_names(
  rem_nlist_order : Array[String],
  rem_order_creation : Array[String],
) -> Unit {
  if rem_nlist_order.length() >= rem_order_creation.length() {
    return ()
  }
  let seen : Map[String, Bool] = Map::new()
  for name in rem_nlist_order {
    seen[name] = true
  }
  for name in rem_order_creation {
    append_creation_name(rem_nlist_order, seen, name)
  }
}

///|
/// Graphviz parity: ReMincross GD_nlist order keeps cluster-local blocks in
/// first-seen cluster sequence and replays each cluster block by rank-desc
/// reverse-order before root-cluster nodes.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_nlist_order(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
  root_tail_order_override : Array[String]?,
) -> Array[String] {
  let rem_order_creation =
    build_remincross_order_creation(
      creation_order,
      rem_vnode_creation,
    )
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
      build_cluster_tail_order(
        rem_order_creation,
        rem_ranks,
        rem_cluster_keys,
        rem_edge_creation,
        cluster_order_index,
        root_tail_order_override,
      )
    }
  append_missing_creation_order_names(rem_nlist_order, rem_order_creation)
  rem_nlist_order
}

///|
/// Graphviz parity: clustered ReMincross rematerialized-order-edge payload
/// keeps bonus-adjusted tail buckets, vnode creation, and edge creation replay.
pub(all) struct ReMincrossMaterializedOrderEdges {
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  vnode_creation : Map[String, Array[String]]
  edge_creation : Array[(String, String)]
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge payload keeps node
/// order plus rematerialized edge arrays for cleanup reorder input.
pub(all) struct ReMincrossMaterializedEdgeArrays {
  node_order : Map[String, Int]
  edges_out : Array[@cgraph.Edge]
  edge_tail_out : Array[String]
  edge_head_out : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
}

///|
/// Graphviz parity: clustered ReMincross order-edge materialization inputs keep
/// dispatch snapshots unchanged before edge expansion/coalescing.
pub(all) struct ReMincrossEdgeMaterializationInputs {
  creation_order : Array[String]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  order_with_vnodes : Bool
  intercluster_keys : Map[String, String]
  order_with_clusters : Bool
  edges_by_tail : Map[String, Array[Int]]
  cluster_order_index : Map[String, Int]
}

///|
/// Graphviz parity: ReMincross order-edge materialization applies ND_out
/// expansion, coalescing, intercluster bonus, then tail-order replay.
pub fn build_remincross_materialized_edges(
  inputs : ReMincrossEdgeMaterializationInputs,
) -> ReMincrossMaterializedOrderEdges {
  let rem_order_edges_output =
    build_order_edges_by_tail(
      inputs.creation_order,
      inputs.edges,
      inputs.edge_tail,
      inputs.edge_head,
      inputs.edge_tail_port_x,
      inputs.edge_head_port_x,
      inputs.edge_tail_port_order,
      inputs.edge_head_port_order,
      inputs.ranks,
      inputs.edge_vnodes,
      inputs.order_with_vnodes,
      inputs.intercluster_keys,
      inputs.order_with_clusters,
      false,
      false,
      inputs.edges_by_tail,
      cluster_order_index=inputs.cluster_order_index,
    )
  let rem_order_edges_by_tail_raw = rem_order_edges_output.order_edges_by_tail
  let rem_vnode_creation = rem_order_edges_output.vnode_creation_by_tail
  let rem_order_edges_by_tail_coalesced =
    coalesce_order_edges_by_tail(rem_order_edges_by_tail_raw)
  let intercluster_bonus =
    collect_intercluster_bonus(
      inputs.creation_order,
      inputs.edges,
      inputs.edge_tail,
      inputs.edge_head,
      inputs.edge_tail_port_order,
      inputs.edge_head_port_order,
      inputs.ranks,
      inputs.edge_vnodes,
      inputs.order_with_vnodes,
      inputs.order_with_clusters,
      inputs.edges_by_tail,
      inputs.intercluster_keys,
    )
  let rem_order_edges_by_tail =
    apply_intercluster_bonus(
      rem_order_edges_by_tail_coalesced,
      intercluster_bonus,
    )
  // Graphviz parity: rematerialized ReMincross edge-creation replay walks
  // each tail bucket in creation-order sequence and preserves ND_out order.
  let rem_edge_creation : Array[(String, String)] = []
  for tail_name in inputs.creation_order {
    let entries = rem_order_edges_by_tail.get(tail_name).unwrap_or_default()
    for entry in entries {
      let (tail, head, _, _, _, _, _, _) = entry
      rem_edge_creation.push((tail, head))
    }
  }
  {
    order_edges_by_tail: rem_order_edges_by_tail,
    vnode_creation: rem_vnode_creation,
    edge_creation: rem_edge_creation,
  }
}

///|
/// Graphviz parity: clustered ReMincross array materialization inputs keep
/// order-graph and rank-group snapshots unchanged before edge array rebuild.
pub(all) struct ReMincrossArrayMaterializationInputs {
  creation_order : Array[String]
  rem_groups : Map[Int, Array[String]]
  rem_graph : @cgraph.Graph
  rem_node_map : Map[String, @cgraph.Node]
  rem_cluster_keys : Map[String, String]
  cluster_order_index : Map[String, Int]
  root_tail_order_override : Array[String]?
  materialized_edges : ReMincrossMaterializedOrderEdges
}

///|
/// Graphviz parity: ReMincross order-graph materialization rebuilds GD_nlist,
/// seeds node order, then materializes edge arrays in nlist tail order.
pub fn build_remincross_materialized_arrays(
  inputs : ReMincrossArrayMaterializationInputs,
) -> ReMincrossMaterializedEdgeArrays {
  let rem_ranks = build_node_ranks(inputs.rem_groups)
  let rem_nlist_order =
    build_remincross_nlist_order(
      inputs.creation_order,
      inputs.materialized_edges.vnode_creation,
      inputs.materialized_edges.edge_creation,
      rem_ranks,
      inputs.rem_cluster_keys,
      inputs.cluster_order_index,
      inputs.root_tail_order_override,
    )
  let rem_node_order = build_order_index(inputs.rem_groups)
  let rem_materialized =
    collect_order_edges_for_tails(
      rem_nlist_order,
      inputs.materialized_edges.order_edges_by_tail,
      inputs.rem_graph,
      inputs.rem_node_map,
    )
  {
    node_order: rem_node_order,
    edges_out: rem_materialized.order_edges_out,
    edge_tail_out: rem_materialized.order_edge_tail_out,
    edge_head_out: rem_materialized.order_edge_head_out,
    edge_tail_port_x: rem_materialized.order_edge_tail_port_x,
    edge_head_port_x: rem_materialized.order_edge_head_port_x,
    edge_tail_port_order: rem_materialized.order_edge_tail_port_order,
    edge_head_port_order: rem_materialized.order_edge_head_port_order,
  }
}
