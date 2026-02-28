///|
/// Stage C Phase C2 split: seeded-group,
/// and early reorder-input materialization helpers.

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
  // Graphviz parity: order graph cluster-key map starts from real-node keys and
  // appends vnode cluster keys only when vnode ordering is enabled.
  let order_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_meta.cluster_keys {
    order_cluster_keys[name] = key
  }
  if order_with_vnodes {
    for name, key in vnode_info.vnode_clusters {
      order_cluster_keys[name] = key
    }
  }
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
  let gdnlist_order_index : Map[String, Int] = Map::new()
  let mut gdnlist_idx = 0
  for name in gdnlist_order {
    if real_nodes.get(name) is Some(_) {
      gdnlist_order_index[name] = gdnlist_idx
    }
    gdnlist_idx = gdnlist_idx + 1
  }
  let unconstrained_nodes : Map[String, Bool] = Map::new()
  for name in order_nodes {
    let out = match graphviz_out_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let inn = match graphviz_in_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    if out.length() == 0 && inn.length() == 0 {
      unconstrained_nodes[name] = true
    }
  }
  for name, idx in gdnlist_order_index {
    if real_nodes.get(name) is Some(_) &&
      unconstrained_nodes.get(name) is Some(_) &&
      rank_same_groups.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: incoming-only unconstrained nodes inside local clusters
  // follow first incoming-edge order from unmapped class2 edge lists.
  let node_has_out : Map[String, Bool] = Map::new()
  let node_has_in : Map[String, Bool] = Map::new()
  let first_in_order : Map[String, Int] = Map::new()
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      node_has_out[tail] = true
      node_has_in[head] = true
      if first_in_order.get(head) is None {
        first_in_order[head] = edge_idx
      }
    }
    edge_idx = edge_idx + 1
  }
  let local_creation : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    let local_cluster = match intercluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if local_cluster == "" {
      continue
    }
    match local_creation.get(local_cluster) {
      Some(list) => list.push(name)
      None => local_creation[local_cluster] = [name]
    }
  }
  for _cluster, names in local_creation {
    let unconstrained_local : Array[String] = []
    for name in names {
      if unconstrained_nodes.get(name) is Some(_) &&
        rank_same_groups.get(name) is None &&
        node_has_out.get(name) is None &&
        node_has_in.get(name) is Some(_) {
        unconstrained_local.push(name)
      }
    }
    if unconstrained_local.length() <= 1 {
      continue
    }
    let desired = unconstrained_local.copy()
    if desired.length() > 1 {
      let local_index : Map[String, Int] = Map::new()
      for idx, name in unconstrained_local {
        local_index[name] = idx
      }
      desired.sort_by((a, b) => {
        let a_in = match first_in_order.get(a) {
          Some(value) => value
          None => 0x7fffffff
        }
        let b_in = match first_in_order.get(b) {
          Some(value) => value
          None => 0x7fffffff
        }
        if a_in < b_in {
          -1
        } else if a_in > b_in {
          1
        } else {
          let a_idx = match local_index.get(a) {
            Some(value) => value
            None => 0
          }
          let b_idx = match local_index.get(b) {
            Some(value) => value
            None => 0
          }
          if a_idx < b_idx {
            -1
          } else if a_idx > b_idx {
            1
          } else {
            0
          }
        }
      })
    }
    let orders : Array[Int] = []
    let mut all_present = true
    for name in unconstrained_local {
      match order_node_order.get(name) {
        Some(value) => orders.push(value)
        None => {
          all_present = false
          break
        }
      }
    }
    if !all_present || orders.length() != desired.length() {
      continue
    }
    orders.sort()
    let mut idx = 0
    while idx < desired.length() && idx < orders.length() {
      order_node_order[desired[idx]] = orders[idx]
      idx = idx + 1
    }
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
  seeded_groups
}
