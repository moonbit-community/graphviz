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
