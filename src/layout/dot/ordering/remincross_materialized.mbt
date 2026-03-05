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

///|
/// Graphviz parity: clustered ReMincross rematerialization inputs keep
/// dispatch snapshots unchanged before startpass=2 cleanup reorder setup.
pub(all) struct ReMincrossMaterializationInputs {
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
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
  cluster_order : Array[String]
  order_with_clusters : Bool
  edges_by_tail : Map[String, Array[Int]]
  root_tail_order_override : Array[String]?
  root_cluster : String
  cluster_parents : Map[String, String?]
  order_sizes : Map[String, NodeSize]
  vnode_sizes : Map[String, NodeSize]
  cluster_flat_constraints : Map[String, Bool]
  rank_same_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: clustered ReMincross starts from a shallow clone of
/// intercluster keys before root remapping and vnode LCA assignments.
fn clone_remincross_cluster_keys(
  intercluster_keys : Map[String, String],
) -> Map[String, String] {
  let cloned : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    cloned[name] = key
  }
  cloned
}

///|
/// Graphviz parity: mark_lowclusters assigns ReMincross edge-vnodes to the
/// lowest common ancestor cluster (or root cluster when LCA is empty).
fn assign_remincross_clusters(
  rem_cluster_keys : Map[String, String],
  root_cluster : String,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_vnodes : Map[String, Array[String]],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
) -> Unit {
  for edge_idx, edge in edges {
    let vnodes =
      edge_vnodes.get(@shared.edge_vnode_key(edge)).unwrap_or_default()
    if vnodes.length() == 0 {
      continue
    }
    let (tail, head) =
      edge_endpoints_at(
        edge,
        edge_idx,
        edge_tail,
        edge_head,
      )
    let tail_cluster = intercluster_keys.get(tail).unwrap_or_default()
    let head_cluster = intercluster_keys.get(head).unwrap_or_default()
    let vnode_cluster =
      @clustering.cluster_lca(
        tail_cluster,
        head_cluster,
        cluster_parents,
      )
    let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
    for vnode in vnodes {
      rem_cluster_keys[vnode] = rem_cluster
    }
  }
}

///|
/// Graphviz parity: clustered ReMincross cluster-key materialization inputs
/// capture intercluster keys and vnode-edge context before cleanup reorder.
pub(all) struct ReMincrossClusterKeyInputs {
  root_cluster : String
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_vnodes : Map[String, Array[String]]
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  order_with_vnodes : Bool
}

///|
/// Graphviz parity: ReMincross cluster-key map starts from intercluster keys,
/// rewrites empty keys to root graph key, then applies vnode LCA assignments.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_cluster_keys(
  inputs : ReMincrossClusterKeyInputs,
) -> Map[String, String] {
  let rem_cluster_keys =
    clone_remincross_cluster_keys(inputs.intercluster_keys)
  // Graphviz parity: ND_clust is the root graph for nodes outside
  // any cluster (mark_lowclusters). Use a non-empty root key so
  // ReMincross can block swaps across cluster boundaries.
  for name, key in rem_cluster_keys {
    if key == "" {
      rem_cluster_keys[name] = inputs.root_cluster
    }
  }
  if inputs.order_with_vnodes {
    assign_remincross_clusters(
      rem_cluster_keys,
      inputs.root_cluster,
      inputs.edges,
      inputs.edge_tail,
      inputs.edge_head,
      inputs.edge_vnodes,
      inputs.intercluster_keys,
      inputs.cluster_parents,
    )
  }
  rem_cluster_keys
}

///|
/// Graphviz parity: clustered ReMincross flat-constraint inputs combine
/// cluster-local and rank=same constraint snapshots before cleanup reorder.
pub(all) struct ReMincrossFlatConstraintInputs {
  order_with_clusters : Bool
  cluster_flat_constraints : Map[String, Bool]
  rank_same_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: ReMincross flat constraints combine cluster flat locks and
/// rank=same constraints only for non-cluster reorder path.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_flat_constraints(
  inputs : ReMincrossFlatConstraintInputs,
) -> Map[String, Bool] {
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  // Graphviz parity: ReMincross flat constraints combine existing same-rank
  // constraints with local intra-cluster adjacency locks for non-intercluster
  // real-node pairs (flat.c cluster-local reorder guard).
  if !inputs.order_with_clusters {
    for key, value in inputs.cluster_flat_constraints {
      rem_flat_constraints[key] = value
    }
    for key, _ in inputs.rank_same_constraints {
      rem_flat_constraints[key] = true
    }
  }
  rem_flat_constraints
}

///|
/// Graphviz parity: clustered ReMincross materialized-input payload keeps
/// graph node/rank context, rematerialized edge arrays, and final reorder
/// maps for cleanup reorder dispatch.
pub(all) struct ReMincrossCleanupMaterializedInputs {
  rem_nodes : Array[String]
  rem_ranks : Map[String, Int]
  rem_node_order : Map[String, Int]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  rem_cluster_keys : Map[String, String]
  rem_sizes : Map[String, NodeSize]
  rem_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: clustered ReMincross multi-rank materialization builds
/// order graph context, rematerialized edge arrays, and reorder input maps
/// before cleanup reorder dispatch.
pub fn build_remincross_materialized_inputs(
  inputs : ReMincrossMaterializationInputs,
) -> ReMincrossCleanupMaterializedInputs {
  let rem_ranks = build_node_ranks(inputs.rem_groups)
  let rem_nodes = build_order_nodes_from_groups(inputs.rem_groups, inputs.rem_rank_keys)
  let rem_graph_output =
    build_order_graph_and_nodes("order_remincross", rem_nodes)
  // Graphviz parity: ReMincross uses real intercluster edges
  // (no cluster skeleton mapping).
  let cluster_order_index =
    build_cluster_order_index(inputs.cluster_order)
  // Graphviz parity: ReMincross rematerialization keeps order-edge expansion
  // and order-graph array materialization on one shared context snapshot.
  let materialized_edges =
    build_remincross_materialized_edges(
      {
        creation_order: inputs.creation_order,
        edges: inputs.edges,
        edge_tail: inputs.edge_tail,
        edge_head: inputs.edge_head,
        edge_tail_port_x: inputs.edge_tail_port_x,
        edge_head_port_x: inputs.edge_head_port_x,
        edge_tail_port_order: inputs.edge_tail_port_order,
        edge_head_port_order: inputs.edge_head_port_order,
        ranks: inputs.ranks,
        edge_vnodes: inputs.edge_vnodes,
        order_with_vnodes: inputs.order_with_vnodes,
        intercluster_keys: inputs.intercluster_keys,
        order_with_clusters: inputs.order_with_clusters,
        edges_by_tail: inputs.edges_by_tail,
        cluster_order_index,
      },
    )
  let materialized_arrays =
    build_remincross_materialized_arrays(
      {
        creation_order: inputs.creation_order,
        rem_groups: inputs.rem_groups,
        rem_graph: rem_graph_output.order_graph,
        rem_node_map: rem_graph_output.order_node_map,
        rem_cluster_keys: inputs.intercluster_keys,
        cluster_order_index,
        root_tail_order_override: inputs.root_tail_order_override,
        materialized_edges,
      },
    )
  let rem_cluster_keys =
    build_remincross_cluster_keys(
      {
        root_cluster: inputs.root_cluster,
        edges: inputs.edges,
        edge_tail: inputs.edge_tail,
        edge_head: inputs.edge_head,
        edge_vnodes: inputs.edge_vnodes,
        intercluster_keys: inputs.intercluster_keys,
        cluster_parents: inputs.cluster_parents,
        order_with_vnodes: inputs.order_with_vnodes,
      },
    )
  let rem_sizes =
    build_sizes_for_order_graph(
      inputs.order_sizes,
      inputs.order_with_vnodes,
      inputs.vnode_sizes,
    )
  let rem_flat_constraints =
    build_remincross_flat_constraints(
      {
        order_with_clusters: inputs.order_with_clusters,
        cluster_flat_constraints: inputs.cluster_flat_constraints,
        rank_same_constraints: inputs.rank_same_constraints,
      },
    )
  {
    rem_nodes,
    rem_ranks,
    rem_node_order: materialized_arrays.node_order,
    rem_edges_out: materialized_arrays.edges_out,
    rem_edge_tail_out: materialized_arrays.edge_tail_out,
    rem_edge_head_out: materialized_arrays.edge_head_out,
    rem_edge_tail_port_x: materialized_arrays.edge_tail_port_x,
    rem_edge_head_port_x: materialized_arrays.edge_head_port_x,
    rem_edge_tail_port_order: materialized_arrays.edge_tail_port_order,
    rem_edge_head_port_order: materialized_arrays.edge_head_port_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  }
}

///|
/// Ordering domain: clustered ReMincross tail-order replay helpers used to
/// rebuild GD_nlist from rematerialized creation/edge sequences.

///|
/// Graphviz parity: grouped ReMincross name buckets are replayed in stable
/// input order when merged into nlist/rank output vectors.
fn append_names_in_order(target : Array[String], names : Array[String]) -> Unit {
  for name in names {
    target.push(name)
  }
}

///|
/// Graphviz parity: ReMincross GD_nlist order is rebuilt from creation order
/// + vnode expansion + fast-graph edge insertion order (decompose parity).
/// Do not change behavior without updating fixtures/tests.
pub fn build_cluster_tail_order(
  rem_order_creation : Array[String],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  rem_edge_creation : Array[(String, String)],
  cluster_order_index : Map[String, Int],
  root_tail_order_override : Array[String]?,
) -> Array[String] {
  let cluster_tail_buckets =
    build_cluster_tail_buckets(rem_order_creation, rem_cluster_keys)
  let cluster_order_output =
    build_remincross_order(
      cluster_tail_buckets.cluster_order_seen,
      cluster_tail_buckets.cluster_first_seen,
      cluster_order_index,
    )
  let cluster_order = cluster_order_output.cluster_order
  let cluster_order_pos = cluster_order_output.cluster_order_pos
  let heads_by_tail =
    build_heads_by_tail_from_edge_creation(rem_edge_creation)
  let context =
    {
      rem_ranks,
      heads_by_tail,
      cluster_order_pos,
      cluster_order,
      rem_cluster_keys,
      root_tail_order_override,
    }
  let rem_nlist_order : Array[String] = []
  for cluster in cluster_order {
    // Graphviz parity: cluster buckets default to empty when absent from
    // grouped creation-order names.
    let names =
      cluster_tail_buckets.names_by_cluster.get(cluster).unwrap_or_default()
    let ordered_names =
      build_cluster_tail_names_for_cluster(cluster, names, context)
    append_names_in_order(rem_nlist_order, ordered_names)
  }
  rem_nlist_order
}

///|
/// Graphviz parity: clustered ReMincross groups names by cluster in
/// creation-order sequence and records first-seen cluster order.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterTailBuckets {
  cluster_order_seen : Array[String]
  names_by_cluster : Map[String, Array[String]]
  cluster_first_seen : Map[String, Int]
}

///|
/// Graphviz parity: cluster tail-order context keeps rematerialized rank and
/// tail->head adjacency snapshots for per-cluster ordered-name replay.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterTailOrderContext {
  rem_ranks : Map[String, Int]
  heads_by_tail : Map[String, Array[String]]
  cluster_order_pos : Map[String, Int]
  cluster_order : Array[String]
  rem_cluster_keys : Map[String, String]
  root_tail_order_override : Array[String]?
}

///|
/// Graphviz parity: clustered ReMincross groups names by cluster in
/// creation-order sequence and records first-seen cluster order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_tail_buckets(
  rem_order_creation : Array[String],
  rem_cluster_keys : Map[String, String],
) -> ClusterTailBuckets {
  // Graphviz parity: clustered ReMincross groups names by cluster in
  // rem_order_creation order and records first-seen cluster sequence.
  let cluster_order_seen : Array[String] = []
  let cluster_seen : Map[String, Bool] = Map::new()
  let names_by_cluster : Map[String, Array[String]] = Map::new()
  for name in rem_order_creation {
    let cluster =
      cluster_key_for_tail_name(
        rem_cluster_keys,
        name,
      )
    if cluster_seen.get(cluster) is None {
      cluster_seen[cluster] = true
      cluster_order_seen.push(cluster)
    }
    match names_by_cluster.get(cluster) {
      Some(list) => list.push(name)
      None => names_by_cluster[cluster] = [name]
    }
  }
  let cluster_first_seen : Map[String, Int] = Map::new()
  for idx, cluster in cluster_order_seen {
    cluster_first_seen[cluster] = idx
  }
  { cluster_order_seen, names_by_cluster, cluster_first_seen }
}

///|
/// Graphviz parity: clustered ReMincross tail->head adjacency keeps
/// rematerialized edge-creation order for downstream rank/block replay.
/// Do not change behavior without updating fixtures/tests.
fn build_heads_by_tail_from_edge_creation(
  rem_edge_creation : Array[(String, String)],
) -> Map[String, Array[String]] {
  // Graphviz parity: clustered ReMincross tail->head adjacency keeps
  // rematerialized edge-creation order for downstream rank/block replay.
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  for edge in rem_edge_creation {
    let (tail, head) = edge
    match heads_by_tail.get(tail) {
      Some(list) => list.push(head)
      None => heads_by_tail[tail] = [head]
    }
  }
  heads_by_tail
}

///|
/// Graphviz parity: cluster-tail ordered-name replay keeps root override
/// behavior and non-root rank replay rules for one cluster bucket.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_tail_names_for_cluster(
  cluster : String,
  names : Array[String],
  context : ClusterTailOrderContext,
) -> Array[String] {
  if cluster == "" {
    // Graphviz parity: root cluster tail order can apply a temporary
    // override snapshot before replaying root names into GD_nlist.
    return match context.root_tail_order_override {
      Some(override_names) =>
        reorder_names_by_override(
          names,
          override_names,
        )
      None => names
    }
  }
  build_nonroot_tail_names(
    cluster,
    names,
    context.rem_ranks,
    context.heads_by_tail,
    context.cluster_order_pos,
    context.cluster_order,
    context.rem_cluster_keys,
  )
}

///|
/// Graphviz parity: clustered tail-order cluster lookup uses explicit
/// rem_cluster_keys with skeleton-name fallback parsing.
/// Do not change behavior without updating fixtures/tests.
fn cluster_key_for_tail_name(
  rem_cluster_keys : Map[String, String],
  name : String,
) -> String {
  let direct = rem_cluster_keys.get(name).unwrap_or_default()
  if direct != "" {
    return direct
  }
  if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
    return ""
  }
  let prefix_len = CLUSTER_SKELETON_PREFIX.length()
  let len = name.length()
  if prefix_len >= len {
    return ""
  }
  let suffix = name.unsafe_substring(start=prefix_len, end=len)
  match suffix.find("@") {
    Some(pos) =>
      if pos > 0 { suffix.unsafe_substring(start=0, end=pos) } else { "" }
    None => ""
  }
}

///|
/// Graphviz parity: clustered tail-order cluster ordering sorts non-root
/// clusters by descending cluster_order_index, then by first-seen sequence.
/// Root cluster always remains last when present.
/// Do not change behavior without updating fixtures/tests.
priv struct ReMincrossClusterOrder {
  cluster_order : Array[String]
  cluster_order_pos : Map[String, Int]
}

///|
/// Graphviz parity: clustered tail-order cluster ordering sorts non-root
/// clusters by descending cluster_order_index, then by first-seen sequence.
/// Root cluster always remains last when present.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_order(
  cluster_order_seen : Array[String],
  cluster_first_seen : Map[String, Int],
  cluster_order_index : Map[String, Int],
) -> ReMincrossClusterOrder {
  let cluster_order_non_root : Array[String] = []
  let mut has_root_cluster = false
  for cluster in cluster_order_seen {
    if cluster == "" {
      has_root_cluster = true
    } else {
      cluster_order_non_root.push(cluster)
    }
  }
  cluster_order_non_root.sort_by((a, b) => {
    // Graphviz parity: non-root clusters sort by descending Graphviz
    // cluster-order index (-1 fallback), then first-seen tie-break.
    let a_idx = cluster_order_index.get(a).unwrap_or(-1)
    let b_idx = cluster_order_index.get(b).unwrap_or(-1)
    if a_idx > b_idx {
      return -1
    }
    if a_idx < b_idx {
      return 1
    }
    let a_seen = cluster_first_seen.get(a).unwrap_or_default()
    let b_seen = cluster_first_seen.get(b).unwrap_or_default()
    if a_seen < b_seen {
      -1
    } else if a_seen > b_seen {
      1
    } else {
      0
    }
  })
  let cluster_order = cluster_order_non_root
  if has_root_cluster {
    cluster_order.push("")
  }
  let cluster_order_pos : Map[String, Int] = Map::new()
  for idx, cluster in cluster_order {
    cluster_order_pos[cluster] = idx
  }
  { cluster_order, cluster_order_pos }
}

///|
/// Graphviz parity: clustered non-root rank replay is forward for no-outgoing
/// blocks and reverse insertion order otherwise.
fn build_nonroot_ordered_names(
  rank_names : Array[String],
  heads_by_tail : Map[String, Array[String]],
) -> Array[String] {
  let rank_ordered : Array[String] = []
  // Graphviz parity: preserve forward rank order only when every tail has no
  // outgoing edge in the rematerialized graph.
  let mut all_without_outgoing = true
  for name in rank_names {
    if heads_by_tail.get(name) is Some(_) {
      all_without_outgoing = false
      break
    }
  }
  if all_without_outgoing {
    append_names_in_order(rank_ordered, rank_names)
    return rank_ordered
  }
  let mut name_idx = rank_names.length()
  while name_idx > 0 {
    name_idx = name_idx - 1
    rank_ordered.push(rank_names[name_idx])
  }
  rank_ordered
}

///|
/// Graphviz parity: clustered tail-order rank buckets keep first-seen unique
/// rank keys in cluster-name order, then sort ascending for reverse replay.
/// Do not change behavior without updating fixtures/tests.
fn collect_nonroot_tail_rank_keys(
  names : Array[String],
  rem_ranks : Map[String, Int],
) -> Array[Int] {
  let rank_keys : Array[Int] = []
  let rank_seen : Map[Int, Bool] = Map::new()
  for name in names {
    let rank = rem_ranks.get(name).unwrap_or(-1)
    if rank_seen.get(rank) is None {
      rank_seen[rank] = true
      rank_keys.push(rank)
    }
  }
  rank_keys.sort()
  rank_keys
}

///|
/// Graphviz parity: clustered tail-order rank replay groups names by exact
/// rematerialized rank value (including -1 fallback rank bucket).
/// Do not change behavior without updating fixtures/tests.
fn collect_nonroot_tail_rank_names(
  names : Array[String],
  rem_ranks : Map[String, Int],
  rank : Int,
) -> Array[String] {
  let rank_names : Array[String] = []
  for name in names {
    if rem_ranks.get(name).unwrap_or(-1) == rank {
      rank_names.push(name)
    }
  }
  rank_names
}

///|
/// Graphviz parity: clustered tail-order non-root phase preserves rank-key
/// collection, descending rank replay, and input-like category rebucketing.
/// Do not change behavior without updating fixtures/tests.
fn build_nonroot_tail_names(
  cluster : String,
  names : Array[String],
  rem_ranks : Map[String, Int],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let rank_keys =
    collect_nonroot_tail_rank_keys(names, rem_ranks)
  // Graphviz parity: minimum replay rank for input-like rebucketing ignores
  // missing-name (-1) buckets and falls back to -1 when absent.
  let mut min_rank = -1
  for value in rank_keys {
    if value >= 0 {
      min_rank = value
      break
    }
  }
  let cluster_rank_ordered : Array[String] = []
  let mut rank_idx = rank_keys.length()
  while rank_idx > 0 {
    rank_idx = rank_idx - 1
    let rank = rank_keys[rank_idx]
    let rank_names =
      collect_nonroot_tail_rank_names(
        names,
        rem_ranks,
        rank,
      )
    let rank_ordered_base =
      build_nonroot_ordered_names(rank_names, heads_by_tail)
    // Graphviz parity: minimum-rank input-like rebucketing runs only on ranks
    // that satisfy Graphviz's rank+shape preconditions.
    let mut all_input_like = true
    for name in rank_ordered_base {
      if !name.has_prefix("i-") {
        all_input_like = false
        break
      }
    }
    let rank_ordered =
      if rank == min_rank && rank_ordered_base.length() > 1 && all_input_like {
        rebucket_input_like_order(
          cluster,
          rank_ordered_base,
          heads_by_tail,
          cluster_order_pos,
          cluster_order,
          rem_cluster_keys,
        )
      } else {
        rank_ordered_base
      }
    append_names_in_order(cluster_rank_ordered, rank_ordered)
  }
  cluster_rank_ordered
}

///|
/// Graphviz parity: input-like category classification context keeps cluster
/// order positions and rematerialized edge lookups for one rank rebucket pass.
/// Do not change behavior without updating fixtures/tests.
priv struct InputLikeBucketContext {
  cluster : String
  heads_by_tail : Map[String, Array[String]]
  cluster_order_pos : Map[String, Int]
  cluster_end_pos : Int
  current_cluster_pos : Int
  rem_cluster_keys : Map[String, String]
}

///|
/// Graphviz parity: input-like rebucketing classifies names by outgoing
/// cross-cluster direction and out-degree priority.
fn classify_input_like_bucket(
  name : String,
  context : InputLikeBucketContext,
) -> Int {
  let heads = context.heads_by_tail.get(name).unwrap_or_default()
  let mut has_later = false
  let mut has_earlier = false
  for head in heads {
    let head_cluster =
      cluster_key_for_tail_name(context.rem_cluster_keys, head)
    if head_cluster == context.cluster {
      continue
    }
    let head_pos =
      context.cluster_order_pos.get(head_cluster).unwrap_or(context.cluster_end_pos)
    if head_pos > context.current_cluster_pos {
      has_later = true
    } else if head_pos < context.current_cluster_pos {
      has_earlier = true
    }
  }
  let out_degree = heads.length()
  if !has_later && !has_earlier && out_degree > 1 {
    return 0
  }
  if has_later {
    return 1
  }
  if has_earlier {
    return 2
  }
  3
}

///|
/// Graphviz parity: minimum-rank all-input-like clustered rank blocks are
/// rebucketed by outgoing cross-cluster direction and out-degree priority.
/// Do not change behavior without updating fixtures/tests.
fn rebucket_input_like_order(
  cluster : String,
  rank_ordered : Array[String],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let context =
    {
      cluster,
      heads_by_tail,
      cluster_order_pos,
      cluster_end_pos: cluster_order.length(),
      current_cluster_pos:
        cluster_order_pos.get(cluster).unwrap_or_default(),
      rem_cluster_keys,
    }
  let category0 : Array[String] = []
  let category1 : Array[String] = []
  let category2 : Array[String] = []
  let category3 : Array[String] = []
  for name in rank_ordered {
    match classify_input_like_bucket(
      name,
      context,
    ) {
      0 => category0.push(name)
      1 => category1.push(name)
      2 => category2.push(name)
      _ => category3.push(name)
    }
  }
  let reordered_rank : Array[String] = []
  append_names_in_order(reordered_rank, category0)
  append_names_in_order(reordered_rank, category1)
  append_names_in_order(reordered_rank, category2)
  append_names_in_order(reordered_rank, category3)
  reordered_rank
}
