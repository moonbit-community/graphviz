///|
/// Positioning domain: x-seed group assembly helpers shared by Stage D
/// vnode-aware xpos preparation.

///|
/// Graphviz parity: vnode-order probe input keeps order-index plus x-seed
/// contexts grouped before Graphviz-compatible vnode-order derivation.
pub(all) struct XposVNodeOrderInput {
  use_vnodes_for_xpos : Bool
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  ranks : Map[String, Int]
  order_index : Map[String, Int]
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
}

///|
/// Graphviz parity: vnode order-key output keeps derived keys and presence gate
/// grouped for downstream x-group assembly.
pub struct XposVNodeOrderState {
  vnode_order_keys : Map[String, Double]
  has_vnode_order : Bool
}

///|
/// Graphviz parity: vnode order-key derivation follows Graphviz: explicit
/// ordered_groups_with_vnodes means vnode order is present; otherwise build
/// keys from edge-vnode chains and mark presence by non-empty key map.
/// Do not change behavior without updating fixtures/tests.
pub fn build_vnode_order_state(
  input : XposVNodeOrderInput,
) -> XposVNodeOrderState {
  let mut vnode_order_keys : Map[String, Double] = Map::new()
  let mut has_vnode_order = false
  if input.use_vnodes_for_xpos && input.ordered_groups_with_vnodes.length() == 0 {
    vnode_order_keys = @ordering.build_vnode_order_keys(
      input.edges,
      input.edge_tail,
      input.edge_head,
      input.edge_reversed,
      input.ranks,
      input.order_index,
      input.intercluster_keys,
      input.cluster_parents,
      input.edge_vnodes,
      input.vnode_ranks,
    )
    for _name, _ in vnode_order_keys {
      has_vnode_order = true
      break
    }
  }
  if input.use_vnodes_for_xpos && input.ordered_groups_with_vnodes.length() > 0 {
    has_vnode_order = true
  }
  { vnode_order_keys, has_vnode_order }
}

///|
/// Graphviz parity: initial x-group assembly inputs keep vnode-aware ordering
/// seeds and cluster-skeleton filtering gates grouped for one build pass.
pub(all) struct XInitialGroupsInput {
  use_vnodes_for_xpos : Bool
  ordered_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  order_index : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_order_keys : Map[String, Double]
  has_clusters : Bool
  is_cluster_skeleton_name : (String) -> Bool
}

///|
/// Graphviz parity: initial x-groups preserve vnode-aware ordering and strip
/// cluster skeleton placeholders before xpos constraints run.
/// Do not change behavior without updating fixtures/tests.
pub fn build_initial_x_groups(
  input : XInitialGroupsInput,
) -> Map[Int, Array[String]] {
  let mut x_groups =
    if input.use_vnodes_for_xpos {
      if input.ordered_groups_with_vnodes.length() > 0 {
        @ordering.clone_rank_groups(input.ordered_groups_with_vnodes)
      } else {
        @ordering.build_x_groups_with_vnodes(
          input.ordered_groups,
          input.order_index,
          input.vnodes_by_rank,
          input.vnode_order_keys,
        )
      }
    } else {
      input.ordered_groups
    }
  if input.has_clusters {
    let cleaned : Map[Int, Array[String]] = Map::new()
    for rank, names in x_groups {
      let filtered : Array[String] = []
      for name in names {
        if !(input.is_cluster_skeleton_name)(name) {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        cleaned[rank] = filtered
      }
    }
    x_groups = cleaned
  }
  x_groups
}

///|
/// Graphviz parity: x-stage cluster-key seed starts from graph cluster keys and
/// overlays vnode cluster keys only when vnode xpos mode is enabled.
/// Do not change behavior without updating fixtures/tests.
pub fn build_x_cluster_keys(
  cluster_keys : Map[String, String],
  use_vnodes_for_xpos : Bool,
  vnode_clusters : Map[String, String],
) -> Map[String, String] {
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_keys {
    x_cluster_keys[name] = key
  }
  if use_vnodes_for_xpos {
    for name, key in vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  x_cluster_keys
}

/// Graphviz parity: x-stage seed output keeps vnode-order probes, edge-port
/// samples, and initial x-group/cluster snapshots grouped for downstream
/// reorder/flat-label stages.
pub struct XPositionSeedData {
  has_vnode_order : Bool
  x_base_sizes : Map[String, @shared.NodeSize]
  x_order_sizes : Map[String, @shared.NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
}

///|
/// Graphviz parity: x-stage seed source bundle keeps ordering/rank snapshots
/// and precomputed edge-port samples grouped before one seed build pass.
pub(all) struct XSeedBuildSources {
  use_vnodes_for_xpos : Bool
  ordered_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  ranks : Map[String, Int]
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  x_base_sizes : Map[String, @shared.NodeSize]
  x_order_sizes : Map[String, @shared.NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
  vnodes_by_rank : Map[Int, Array[String]]
  has_clusters : Bool
  is_cluster_skeleton_name : (String) -> Bool
  cluster_keys : Map[String, String]
  vnode_clusters : Map[String, String]
}

///|
/// Graphviz parity: pre-reorder x-stage setup keeps order-index build,
/// vnode-order probing, edge-port metadata, and initial group/cluster maps
/// unchanged.
/// Do not change behavior without updating fixtures/tests.
pub fn build_x_seed_data_from_sources(
  sources : XSeedBuildSources,
) -> XPositionSeedData {
  let order_index = @ordering.build_order_index(sources.ordered_groups)
  let vnode_order_state =
    build_vnode_order_state(
      {
        use_vnodes_for_xpos: sources.use_vnodes_for_xpos,
        ordered_groups_with_vnodes: sources.ordered_groups_with_vnodes,
        edges: sources.edges,
        edge_tail: sources.edge_tail,
        edge_head: sources.edge_head,
        edge_reversed: sources.edge_reversed,
        ranks: sources.ranks,
        order_index,
        intercluster_keys: sources.intercluster_keys,
        cluster_parents: sources.cluster_parents,
        edge_vnodes: sources.edge_vnodes,
        vnode_ranks: sources.vnode_ranks,
      },
    )
  let x_groups =
    build_initial_x_groups(
      {
        use_vnodes_for_xpos: sources.use_vnodes_for_xpos,
        ordered_groups: sources.ordered_groups,
        ordered_groups_with_vnodes: sources.ordered_groups_with_vnodes,
        order_index,
        vnodes_by_rank: sources.vnodes_by_rank,
        vnode_order_keys: vnode_order_state.vnode_order_keys,
        has_clusters: sources.has_clusters,
        is_cluster_skeleton_name: sources.is_cluster_skeleton_name,
      },
    )
  let x_cluster_keys =
    build_x_cluster_keys(
      sources.cluster_keys,
      sources.use_vnodes_for_xpos,
      sources.vnode_clusters,
    )
  {
    has_vnode_order: vnode_order_state.has_vnode_order,
    x_base_sizes: sources.x_base_sizes,
    x_order_sizes: sources.x_order_sizes,
    x_edge_tail_port_x: sources.x_edge_tail_port_x,
    x_edge_head_port_x: sources.x_edge_head_port_x,
    x_edge_tail_port_order: sources.x_edge_tail_port_order,
    x_edge_head_port_order: sources.x_edge_head_port_order,
    x_groups,
    x_cluster_keys,
  }
}
