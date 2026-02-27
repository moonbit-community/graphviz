///|
/// Stage D phase split: seed-construction helpers for x-stage inputs
/// and flat-label vnode augmentation utilities.

///|
/// Graphviz parity: vnode order-key derivation follows Graphviz: explicit
/// ordered_groups_with_vnodes means vnode order is present; otherwise build
/// keys from edge-vnode chains and mark presence by non-empty key map.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_state_for_positions(
  use_vnodes_for_xpos : Bool,
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  prep : LayoutPrep,
  rank_data : RankData,
  order_index : Map[String, Int],
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XposVNodeOrderState {
  let mut vnode_order_keys : Map[String, Double] = Map::new()
  let mut has_vnode_order = false
  if use_vnodes_for_xpos && ordered_groups_with_vnodes.length() == 0 {
    vnode_order_keys = build_vnode_order_keys(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.edge_reversed,
      rank_data.ranks,
      order_index,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      ordering.vnode_info.edge_vnodes,
      ordering.vnode_info.vnode_ranks,
    )
    for _name, _ in vnode_order_keys {
      has_vnode_order = true
      break
    }
  }
  if use_vnodes_for_xpos && ordered_groups_with_vnodes.length() > 0 {
    has_vnode_order = true
  }
  { vnode_order_keys, has_vnode_order }
}

///|
/// Graphviz parity: x-order sizes and edge port position/order arrays are
/// derived from layout-coordinate sizes before any xpos reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_x_order_edge_port_data_for_positions(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
) -> XposOrderEdgePortData {
  // Graphviz parity: x-positioning uses layout-coordinate node sizes,
  // so rankdir flip is handled via prep.sizes (not ordering-space widths).
  let x_base_sizes = apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    prep.sizes,
    prep.rankdir,
    prep.record_orientation,
  )
  let x_order_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let (x_edge_tail_port_x, x_edge_head_port_x) =
    compute_edge_port_positions(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let (x_edge_tail_port_order, x_edge_head_port_order) =
    compute_edge_port_orders(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  {
    x_base_sizes,
    x_order_sizes,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
  }
}


///|
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, and vnode cluster-key overlay only on vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_label_vnode_augmentation_for_positions(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
) -> XposFlatLabelAugmentation {
  let mut next_x_groups = x_groups
  let mut flat_label_edges : Array[ConstraintEdge] = []
  let mut flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let mut flat_label_edge_vnodes : Map[String, String] = Map::new()
  let next_x_cluster_keys = x_cluster_keys
  let existing_names = build_existing_node_names_map_for_positions(prep.nodes)
  add_vnode_names_to_existing_names_for_positions(
    existing_names,
    ordering.vnode_info.vnode_ranks,
  )
  if use_vnodes_for_xpos {
    let (
      updated_groups,
      label_nodes,
      label_edge_vnodes,
      extra_edges,
    ) = add_flat_label_vnodes(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.ranks,
      ordering.ordered_groups,
      rank_heights.nodesep_pt,
      prep.rankdir,
      x_base_sizes,
      ordering.edge_cluster_keys,
      cluster_meta.cluster_parents,
      existing_names,
      ordering.vnode_info,
      next_x_groups,
    )
    next_x_groups = updated_groups
    flat_label_edges = extra_edges
    flat_label_nodes = label_nodes
    flat_label_edge_vnodes = label_edge_vnodes
    for name, key in ordering.vnode_info.vnode_clusters {
      next_x_cluster_keys[name] = key
    }
  }
  {
    x_groups: next_x_groups,
    x_cluster_keys: next_x_cluster_keys,
    flat_label_edges,
    flat_label_nodes,
    flat_label_edge_vnodes,
  }
}

