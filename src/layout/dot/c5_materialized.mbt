///|
/// Stage C Phase C5 split: clustered materialized-edge
/// reorder/input orchestration helpers.

///|
/// Graphviz parity: nested intercluster merge-chain bonuses are applied to the
/// first representative coalesced edge entry for each merge key.
fn apply_intercluster_bonus(
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
        @ordering.order_edge_merge_key(
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
/// Graphviz parity: clustered ReMincross rematerialized-order-edge payload
/// keeps bonus-adjusted tail buckets, vnode creation, and edge creation replay.
priv struct ReMincrossMaterializedOrderEdges {
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  vnode_creation : Map[String, Array[String]]
  edge_creation : Array[(String, String)]
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge payload keeps node
/// order plus rematerialized edge arrays for cleanup reorder input.
priv struct ReMincrossMaterializedEdgeArrays {
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
/// Graphviz parity: clustered ReMincross order-edge rematerialization applies
/// ND_out expansion, coalescing, intercluster bonus, then tail-order replay.
fn build_materialized_edges(
  dispatch_context : ReMincrossDispatchContext,
  cluster_order_index : Map[String, Int],
) -> ReMincrossMaterializedOrderEdges {
  let rem_order_edges_output =
    @ordering.build_order_edges_by_tail(
      dispatch_context.creation_order,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_tail_port_x,
      dispatch_context.edge_head_port_x,
      dispatch_context.edge_tail_port_order,
      dispatch_context.edge_head_port_order,
      dispatch_context.ranks,
      dispatch_context.vnode_info.edge_vnodes,
      dispatch_context.order_with_vnodes,
      dispatch_context.cluster_meta.intercluster_keys,
      dispatch_context.order_with_clusters,
      false,
      false,
      dispatch_context.edges_by_tail,
      cluster_order_index=cluster_order_index,
    )
  let rem_order_edges_by_tail_raw = rem_order_edges_output.order_edges_by_tail
  let rem_vnode_creation = rem_order_edges_output.vnode_creation_by_tail
  let rem_order_edges_by_tail_coalesced =
    @ordering.coalesce_order_edges_by_tail(rem_order_edges_by_tail_raw)
  let intercluster_bonus =
    @ordering.collect_intercluster_bonus(
      dispatch_context.creation_order,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_tail_port_order,
      dispatch_context.edge_head_port_order,
      dispatch_context.ranks,
      dispatch_context.vnode_info.edge_vnodes,
      dispatch_context.order_with_vnodes,
      dispatch_context.order_with_clusters,
      dispatch_context.edges_by_tail,
      dispatch_context.cluster_meta.intercluster_keys,
    )
  let rem_order_edges_by_tail =
    apply_intercluster_bonus(
      rem_order_edges_by_tail_coalesced,
      intercluster_bonus,
    )
  // Graphviz parity: rematerialized ReMincross edge-creation replay walks
  // each tail bucket in creation-order sequence and preserves ND_out order.
  let rem_edge_creation : Array[(String, String)] = []
  for tail_name in dispatch_context.creation_order {
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
/// Graphviz parity: ReMincross order-graph materialization rebuilds GD_nlist,
/// seeds node order, then materializes edge arrays in nlist tail order.
fn build_materialized_arrays(
  dispatch_context : ReMincrossDispatchContext,
  rem_groups : Map[Int, Array[String]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  cluster_order_index : Map[String, Int],
  materialized_edges : ReMincrossMaterializedOrderEdges,
) -> ReMincrossMaterializedEdgeArrays {
  let rem_ranks = @ordering.build_node_ranks(rem_groups)
  let rem_nlist_order =
    build_remincross_nlist_order(
      dispatch_context.creation_order,
      materialized_edges.vnode_creation,
      materialized_edges.edge_creation,
      rem_ranks,
      dispatch_context.cluster_meta.intercluster_keys,
      cluster_order_index,
    )
  let rem_node_order = @ordering.build_order_index(rem_groups)
  let rem_materialized =
    @ordering.collect_order_edges_for_tails(
      rem_nlist_order,
      materialized_edges.order_edges_by_tail,
      rem_graph,
      rem_node_map,
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
    @ordering.append_creation_name(
      rem_order_creation,
      rem_seen,
      tail_name,
    )
    let vnodes = rem_vnode_creation.get(tail_name).unwrap_or_default()
    for vnode in vnodes {
      @ordering.append_creation_name(
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
    @ordering.append_creation_name(rem_nlist_order, seen, name)
  }
}

///|
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
      @ordering.build_cluster_tail_order(
        rem_order_creation,
        rem_ranks,
        rem_cluster_keys,
        rem_edge_creation,
        cluster_order_index,
        remincross_root_tail_order_override_snapshot.val,
      )
    }
  append_missing_creation_order_names(rem_nlist_order, rem_order_creation)
  rem_nlist_order
}
