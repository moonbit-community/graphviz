type NodeSize = @shared.NodeSize

///|
/// Graphviz parity: clustered xpos reorder seed inputs keep x-order rank
/// groups, cluster bounds, and node-order seeds together before skeleton
/// injection and rank/order materialization.
pub struct ClusteredXposSeedInput {
  x_groups : Map[Int, Array[String]]
  x_order_sizes : Map[String, NodeSize]
  x_cluster_keys : Map[String, String]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  node_order : Map[String, Int]
  cluster_skeleton_prefix : String
  cluster_skeleton_size : NodeSize
}

///|
pub fn build_clustered_xpos_seed_input(
  x_groups : Map[Int, Array[String]],
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  node_order : Map[String, Int],
  cluster_skeleton_prefix : String,
  cluster_skeleton_size : NodeSize,
) -> ClusteredXposSeedInput {
  {
    x_groups,
    x_order_sizes,
    x_cluster_keys,
    cluster_min_rank,
    cluster_max_rank,
    node_order,
    cluster_skeleton_prefix,
    cluster_skeleton_size,
  }
}

///|
/// Graphviz parity: clustered xpos reorder seed output preserves the same
/// order-group/rank/node-order snapshots consumed by edge materialization and
/// reorder_rank_groups.
pub struct ClusteredXposSeedOutput {
  order_groups : Map[Int, Array[String]]
  order_sizes : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_node_order : Map[String, Int]
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_nodes : Array[String]
}

///|
fn append_skeleton_nodes(
  input : ClusteredXposSeedInput,
  order_groups : Map[Int, Array[String]],
  order_sizes : Map[String, NodeSize],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Unit {
  for cluster, min_rank in input.cluster_min_rank {
    let max_rank = input.cluster_max_rank.get(cluster).unwrap_or(min_rank)
    for rank in min_rank..=max_rank {
      let name = "\{input.cluster_skeleton_prefix}\{cluster}@\{rank}"
      order_cluster_keys[name] = cluster
      order_cluster_skeleton[name] = true
      order_sizes[name] = input.cluster_skeleton_size
      match order_groups.get(rank) {
        Some(list) => list.push(name)
        None => order_groups[rank] = [name]
      }
    }
  }
}

///|
/// Graphviz parity: clustered xpos reorder seed setup clones x-order groups,
/// injects cluster skeleton nodes, and materializes rank/order maps.
/// Do not change behavior without updating fixtures/tests.
pub fn build_clustered_xpos_seed(
  input : ClusteredXposSeedInput,
) -> ClusteredXposSeedOutput {
  let order_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in input.x_groups {
    order_groups[rank] = names.copy()
  }
  let order_sizes : Map[String, NodeSize] = Map::new()
  for name, size in input.x_order_sizes {
    order_sizes[name] = size
  }
  let order_cluster_keys : Map[String, String] = Map::new()
  for name, key in input.x_cluster_keys {
    order_cluster_keys[name] = key
  }
  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  append_skeleton_nodes(
    input,
    order_groups,
    order_sizes,
    order_cluster_keys,
    order_cluster_skeleton,
  )
  let order_node_order : Map[String, Int] = Map::new()
  for name, value in input.node_order {
    order_node_order[name] = value
  }
  let order_index = @ordering.build_order_index(order_groups)
  for name, idx in order_index {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let order_rank_keys = @ordering.collect_rank_keys(order_groups)
  let order_ranks = @ordering.build_node_ranks(order_groups)
  let order_nodes : Array[String] = []
  for rank in order_rank_keys {
    let names = order_groups.get(rank).unwrap_or_default()
    for name in names {
      order_nodes.push(name)
    }
  }
  {
    order_groups,
    order_sizes,
    order_cluster_keys,
    order_cluster_skeleton,
    order_node_order,
    order_rank_keys,
    order_ranks,
    order_nodes,
  }
}
