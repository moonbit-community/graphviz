///|
/// Ordering domain: vnode interpolation seeding for clustered local reorder
/// passes before flat-constraint application.

///|
/// Graphviz parity: vnode interpolation picks the first neighbor that crosses
/// the current rank boundary and falls back to the first incident endpoint.
fn select_vnode_anchor_neighbor(
  neighbors : Array[String],
  ranks : Map[String, Int],
  vnode_rank : Int,
  select_lower : Bool,
) -> String {
  for candidate in neighbors {
    let candidate_rank =
      match ranks.get(candidate) {
        Some(value) => value
        None => if select_lower { vnode_rank - 1 } else { vnode_rank + 1 }
      }
    if select_lower {
      if candidate_rank < vnode_rank {
        return candidate
      }
    } else if candidate_rank > vnode_rank {
      return candidate
    }
  }
  if neighbors.length() > 0 { neighbors[0] } else { "" }
}

///|
/// Graphviz parity: vnode interpolation key falls back to base order when
/// anchors are missing, and otherwise interpolates between anchor orders.
fn compute_vnode_interpolation_key(
  name : String,
  rank : Int,
  base_order : Int,
  order_index : Map[String, Int],
  ranks : Map[String, Int],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
) -> Double {
  if !is_edge_vnode_name(name) {
    return Double::from_int(base_order)
  }
  let vnode_rank = ranks.get(name).unwrap_or(rank)
  let parent_name =
    match parents.get(name) {
      Some(list) =>
        select_vnode_anchor_neighbor(
          list,
          ranks,
          vnode_rank,
          true,
        )
      None => ""
    }
  let child_name =
    match children.get(name) {
      Some(list) =>
        select_vnode_anchor_neighbor(
          list,
          ranks,
          vnode_rank,
          false,
        )
      None => ""
    }
  if parent_name == "" || child_name == "" {
    return Double::from_int(base_order)
  }
  let parent_rank = ranks.get(parent_name).unwrap_or(vnode_rank - 1)
  let child_rank = ranks.get(child_name).unwrap_or(vnode_rank + 1)
  let parent_order = order_index.get(parent_name).unwrap_or(base_order)
  let child_order = order_index.get(child_name).unwrap_or(base_order)
  let (low_rank, high_rank, low_order, high_order) =
    if parent_rank <= child_rank {
      (parent_rank, child_rank, parent_order, child_order)
    } else {
      (child_rank, parent_rank, child_order, parent_order)
    }
  let span = high_rank - low_rank
  if span <= 0 {
    return Double::from_int(base_order)
  }
  let t = Double::from_int(vnode_rank - low_rank) / Double::from_int(span)
  if low_order == high_order {
    Double::from_int(low_order) - (1.0 - t)
  } else {
    Double::from_int(low_order) + Double::from_int(high_order - low_order) * t
  }
}

///|
const SEEDED_RANK_KEY_EPS : Double = 0.000000001

///|
fn sort_seeded_rank_items(
  items : Array[(Double, Int, String)],
) -> Unit {
  items.sort_by((a, b) => {
    let (a_key, a_idx, _a_name) = a
    let (b_key, b_idx, _b_name) = b
    let diff = a_key - b_key
    if diff < -SEEDED_RANK_KEY_EPS {
      -1
    } else if diff > SEEDED_RANK_KEY_EPS {
      1
    } else if a_idx < b_idx {
      -1
    } else if a_idx > b_idx {
      1
    } else {
      0
    }
  })
}

///|
fn build_cluster_group_order_index(
  cluster_rank_keys : Array[Int],
  cluster_groups : Map[Int, Array[String]],
) -> Map[String, Int] {
  let order_index : Map[String, Int] = Map::new()
  for rank in cluster_rank_keys {
    let names = cluster_groups.get(rank).unwrap_or_default()
    for idx, name in names {
      order_index[name] = idx
    }
  }
  order_index
}

///|
/// Graphviz parity: cluster-local ND_order seeds vnode positions by
/// interpolating between current tail/head orders inside the cluster.
/// Do not change behavior without updating fixtures/tests.
pub fn seed_local_groups_by_vnode(
  cluster_rank_keys : Array[Int],
  cluster_groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let order_index =
    build_cluster_group_order_index(cluster_rank_keys, cluster_groups)
  let seeded : Map[Int, Array[String]] = Map::new()
  for rank in cluster_rank_keys {
    let names = cluster_groups.get(rank).unwrap_or_default()
    if names.length() <= 1 {
      if names.length() > 0 {
        seeded[rank] = names.copy()
      }
      continue
    }
    let items : Array[(Double, Int, String)] = []
    for idx, name in names {
      let key =
        compute_vnode_interpolation_key(
          name,
          rank,
          idx,
          order_index,
          ranks,
          parents,
          children,
        )
      items.push((key, idx, name))
    }
    sort_seeded_rank_items(items)
    let reordered : Array[String] = []
    for item in items {
      let (_key, _idx, name) = item
      reordered.push(name)
    }
    seeded[rank] = reordered
  }
  seeded
}
