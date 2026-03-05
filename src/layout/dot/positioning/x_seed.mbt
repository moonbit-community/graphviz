///|
/// Positioning domain: x-seed group assembly helpers shared by Stage D
/// vnode-aware xpos preparation.

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
