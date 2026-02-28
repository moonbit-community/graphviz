///|
/// Stage C Phase C2 split: seeded-group,
/// and early reorder-input materialization helpers.

///|
/// Graphviz parity: order-graph edge arrays are materialized from GD_nlist
/// tail order for both mapped (cluster-remapped) and unmapped variants.
/// Do not change behavior without updating fixtures/tests.
fn materialize_mapped_and_unmapped_order_edges(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  ) =
    // Graphviz parity: mapped order-edge arrays are materialized from GD_nlist
    // tail order against the cluster-remapped order graph.
    collect_order_edges_for_tail_sequence(
      nlist_order,
      order_edges_by_tail,
      order_graph,
      order_node_map,
    )
  let (
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  ) =
    // Graphviz parity: unmapped order-edge arrays are materialized from GD_nlist
    // tail order against the non-remapped order graph.
    collect_order_edges_for_tail_sequence(
      nlist_order,
      order_edges_by_tail_unmapped,
      order_graph_unmapped,
      order_node_map_unmapped,
    )
  (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
}

///|
/// Graphviz parity: cluster skeleton nodes are installed by cluster_order
/// first, then by cluster_min_rank fallback, using virtual_node() defaults.
/// Do not change behavior without updating fixtures/tests.
fn install_order_cluster_skeleton_nodes(
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  order_groups : Map[Int, Array[String]],
) -> Unit {
  if !order_with_clusters {
    return
  }
  // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
  let skeleton_size = vnode_size_from_widths(1.0, 1.0)
  let cluster_seen : Map[String, Bool] = Map::new()
  for cluster in cluster_meta.cluster_order {
    match cluster_meta.cluster_min_rank.get(cluster) {
      Some(min_rank) => {
        let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
          Some(value) => value
          None => min_rank
        }
        append_order_cluster_skeleton_range(
          cluster,
          min_rank,
          max_rank,
          order_cluster_keys,
          order_cluster_skeleton,
          order_sizes_out,
          order_groups,
          skeleton_size,
        )
        cluster_seen[cluster] = true
      }
      None => ()
    }
  }
  for cluster, min_rank in cluster_meta.cluster_min_rank {
    if cluster_seen.get(cluster) is Some(_) {
      continue
    }
    let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
      Some(value) => value
      None => min_rank
    }
    append_order_cluster_skeleton_range(
      cluster,
      min_rank,
      max_rank,
      order_cluster_keys,
      order_cluster_skeleton,
      order_sizes_out,
      order_groups,
      skeleton_size,
    )
  }
}


///|
/// Graphviz parity: order-stage groups clone rank groups, optionally merge edge
/// vnodes, and install cluster skeleton nodes with virtual-node defaults.
/// Do not change behavior without updating fixtures/tests.
fn build_order_groups_sizes_and_cluster_skeleton(
  ordering_groups_base : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_sizes : Map[String, NodeSize],
) -> (
  Map[Int, Array[String]],
  Map[String, NodeSize],
  Map[String, String],
  Map[String, Bool],
) {
  let order_groups =
    if order_with_vnodes {
      build_x_groups_with_vnodes(
        ordering_groups_base,
        base_order_index,
        vnode_info.vnodes_by_rank,
        vnode_order_keys_for_ordering,
      )
    } else {
      let out : Map[Int, Array[String]] = Map::new()
      for rank, names in ordering_groups_base {
        out[rank] = names.copy()
      }
      out
    }
  let order_sizes_out =
    build_order_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
    )
  let order_cluster_keys =
    build_order_cluster_keys_for_order_graph(
      cluster_meta.cluster_keys,
      order_with_vnodes,
      vnode_info.vnode_clusters,
    )
  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  install_order_cluster_skeleton_nodes(
    order_with_clusters,
    cluster_meta,
    order_cluster_keys,
    order_cluster_skeleton,
    order_sizes_out,
    order_groups,
  )
  (
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: unconstrained real nodes keep GD_nlist seed order, with
/// incoming-only local-cluster nodes reversed to match fast_node head-insert
/// behavior before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn apply_unconstrained_order_node_overrides(
  gdnlist_order : Array[String],
  real_nodes : Map[String, Bool],
  order_nodes : Array[String],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  rank_same_groups : Map[String, Int],
  edge_tail : Array[String],
  edge_head : Array[String],
  nodes : Array[@cgraph.Node],
  intercluster_keys : Map[String, String],
  order_node_order : Map[String, Int],
) -> Unit {
  // Graphviz parity: unconstrained nodes retain GD_nlist order for seeding.
  let gdnlist_order_index =
    build_gdnlist_order_index_for_real_nodes(gdnlist_order, real_nodes)
  let unconstrained_nodes =
    collect_unconstrained_order_nodes(
      order_nodes,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
    )
  for name, idx in gdnlist_order_index {
    if real_nodes.get(name) is Some(_) &&
      unconstrained_nodes.get(name) is Some(_) &&
      rank_same_groups.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: incoming-only unconstrained nodes inside local clusters
  // follow first incoming-edge order from unmapped class2 edge lists.
  let (node_has_out, node_has_in, first_in_order) =
    build_node_in_out_presence_and_first_in_order(edge_tail, edge_head)
  let local_creation =
    build_local_cluster_creation_order(nodes, intercluster_keys)
  reorder_incoming_only_unconstrained_local_nodes(
    local_creation,
    unconstrained_nodes,
    rank_same_groups,
    node_has_out,
    node_has_in,
    first_in_order,
    order_node_order,
  )
}

///|
/// Graphviz parity: seeded build_ranks transpose phase runs only when crossing
/// count remains positive after component-scoped initial ordering.
/// Do not change behavior without updating fixtures/tests.
fn apply_seeded_groups_transpose_phase(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  order_ranks : Map[String, Int],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  flat_rank_constraints : Map[String, Bool],
) -> Unit {
  // Graphviz parity: build_ranks applies transpose if crossings remain;
  // crossing count uses endpoint port x offsets for tie-correct ordering.
  let seed_cross = count_crossings_port_aware(
    seeded_groups,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    edge_tail_port_x=order_edge_tail_port_x,
    edge_head_port_x=order_edge_head_port_x,
  )
  if seed_cross > 0 {
    let (edge_penalty, edge_in, edge_out) =
      build_transpose_seed_edge_maps(
        order_rank_keys,
        seeded_groups,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_ranks,
      )
    let _ = transpose_rank_groups_port_tiebreak(
      order_rank_keys,
      seeded_groups,
      order_ranks,
      edge_in,
      edge_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      edge_penalty,
      order_cluster_keys,
      order_cluster_skeleton,
      flat_rank_constraints,
      false,
      0,
    )
  }
}

///|
/// Graphviz parity: build_ranks seeding runs component-scoped ordering first,
/// then applies transpose when crossings remain (port-offset aware tie-breaks).
/// Do not change behavior without updating fixtures/tests.
fn build_seeded_groups_for_order_reorder(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  order_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  // Graphviz parity: seed build_ranks from component-scoped walk,
  // matching decompose/install traversal used by remincross with
  // cluster-expanded flat constraints.
  let seed_pass =
    if @sys.get_env_var("DOT_SEED_PASS1") is Some(_) { 1 } else { 0 }
  let seeded_groups = build_rank_groups_by_components(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    seed_pass,
    order_flat_constraints,
    flip=graphviz_flip,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
  )
  apply_seeded_groups_transpose_phase(
    order_rank_keys,
    seeded_groups,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_cluster_keys,
    order_cluster_skeleton,
    flat_rank_constraints,
  )
  seeded_groups
}

///|
/// Graphviz parity: clustered order pass runs cluster-local build_ranks on the
/// unmapped order graph, then stores vnode-inclusive rank groups for later xpos.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_build_ranks_and_track_vnodes(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if order_with_clusters {
    reorder_groups_by_cluster_build_ranks(
      graph,
      ordered,
      cluster_meta,
      order_node_order,
      order_edges_out_unmapped,
      order_edge_tail_out_unmapped,
      order_edge_head_out_unmapped,
      order_edge_tail_port_x_unmapped,
      order_edge_head_port_x_unmapped,
      order_edge_tail_port_order_unmapped,
      order_edge_head_port_order_unmapped,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      ranks,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      vnode_info,
      order_with_vnodes,
    )
  }
  let mut next_ordered_with_vnodes = ordered_with_vnodes
  if order_with_vnodes {
    next_ordered_with_vnodes = ordered
  }
  next_ordered_with_vnodes
}
