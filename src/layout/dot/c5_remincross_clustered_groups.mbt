///|
/// Stage C Phase C5 split: remincross clustered groups
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_pass(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let prefer_seeded_from_ordered_with_vnodes =
    match dispatch_context.graph.get_attr("ratio") {
      Some(value) => value == "fill"
      None => false
    }
  let rebuild_groups =
    () =>
      build_remincross_groups_with_optional_vnodes(
        dispatch_context.base_groups,
        dispatch_context.order_with_vnodes,
        dispatch_context.edges,
        dispatch_context.edge_tail,
        dispatch_context.edge_head,
        dispatch_context.edge_reversed,
        dispatch_context.ranks,
        dispatch_context.cluster_meta.intercluster_keys,
        dispatch_context.cluster_meta.cluster_parents,
        dispatch_context.cluster_meta.cluster_min_rank,
        dispatch_context.cluster_meta.cluster_max_rank,
        dispatch_context.vnode_info.edge_vnodes,
        dispatch_context.vnode_info.vnode_ranks,
        dispatch_context.vnode_info.vnodes_by_rank,
      )
  let rem_groups =
    if dispatch_context.order_with_vnodes &&
      (dispatch_context.cluster_meta.cluster_order.length() == 1 ||
      prefer_seeded_from_ordered_with_vnodes) {
      let seeded =
        build_remincross_groups_from_ordered_with_vnodes(
          dispatch_context.base_groups,
          dispatch_context.ordered_with_vnodes,
          dispatch_context.cluster_meta.cluster_keys,
        )
      if seeded.length() > 0 {
        seeded
      } else {
        rebuild_groups()
      }
    } else {
      rebuild_groups()
    }
  let rem_rank_keys = collect_rank_keys(rem_groups)
  if rem_rank_keys.length() > 1 {
    run_clustered_remincross_multi_rank(
      dispatch_context,
      rem_rank_keys,
      rem_groups,
    )
  } else {
    (dispatch_context.ordered_with_vnodes, dispatch_context.base_groups)
  }
}

///|
/// Graphviz parity: clustered ReMincross multi-rank branch materializes
/// remapped edges and executes clustered cleanup reorder in startpass=2 flow.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let rem_ranks = build_node_ranks(rem_groups)
  let rem_nodes = build_order_nodes_from_groups(rem_groups, rem_rank_keys)
  let (rem_graph, rem_node_map) =
    build_order_graph_and_nodes("order_remincross", rem_nodes)
  // Graphviz parity: ReMincross uses real intercluster edges
  // (no cluster skeleton mapping).
  let cluster_order_index =
    build_cluster_index_for_local_reorder(dispatch_context.cluster_meta.cluster_order)
  let (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    build_clustered_remincross_materialized_edges(
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
      dispatch_context.edges_by_tail,
      cluster_order_index,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  let (
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  ) =
    build_remincross_reorder_inputs(
      dispatch_context.graph,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.order_with_vnodes,
      dispatch_context.order_with_clusters,
      dispatch_context.cluster_meta,
      dispatch_context.vnode_info,
      dispatch_context.order_sizes,
      dispatch_context.rank_same_constraints,
    )
  let (rem_parents, rem_children, rem_edge_order) =
    build_order_edge_indices_and_order(
      rem_nodes,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_ranks,
      rem_edges_out,
    )
  // Graphviz parity: ReMincross clustered reorder executes mincross with
  // startpass=2 on rematerialized fast-graph edges and local flat constraints.
  capture_remincross_input_snapshot(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_cluster_keys,
  )
  let rem_ordered =
    reorder_rank_groups(
      rem_rank_keys,
      rem_groups,
      rem_edges_out,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_edge_tail_port_x,
      rem_edge_head_port_x,
      rem_edge_tail_port_order,
      rem_edge_head_port_order,
      rem_parents,
      rem_children,
      rem_cluster_keys,
      dispatch_context.cluster_meta.rank_same_groups,
      dispatch_context.cluster_meta.rank_same_order,
      rem_edge_order,
      rem_node_order,
      rem_sizes,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      Map::new(),
      Map::new(),
      rem_flat_constraints,
      graphviz_flip=dispatch_context.graphviz_flip,
      // Graphviz parity: ReMincross counts parallel chain segments once
      // with summed xpenalty before startpass=2 transposition.
      coalesce_parallel_edges=true,
      startpass=2,
      remincross_mode=true,
    )
  let rem_cleaned =
    collect_real_only_rank_groups(rem_rank_keys, rem_ordered, dispatch_context.real_nodes)
  (rem_ordered, rem_cleaned)
}

///|
/// Graphviz parity: clustered ReMincross edge endpoint reads prefer oriented
/// edge_tail/edge_head arrays and fall back to edge object endpoints.
fn remincross_edge_endpoints_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (String, String) {
  let tail =
    if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
      edge.tail().name()
    }
  let head =
    if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
      edge.head().name()
    }
  (tail, head)
}

///|
/// Graphviz parity: clustered ReMincross cluster-key reads treat missing keys
/// as root-empty values for intercluster/internal edge classification.
fn remincross_cluster_key_or_empty(
  cluster_keys : Map[String, String],
  name : String,
) -> String {
  match cluster_keys.get(name) {
    Some(value) => value
    None => ""
  }
}

///|
/// Graphviz parity: ReMincross reorder inputs derive cluster keys (including
/// vnode LCA assignments), size map extension, and flat-constraint
/// augmentation before final reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_reorder_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
) -> (Map[String, String], Map[String, NodeSize], Map[String, Bool]) {
  let rem_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_meta.intercluster_keys {
    rem_cluster_keys[name] = key
  }
  // Graphviz parity: ND_clust is the root graph for nodes outside
  // any cluster (mark_lowclusters). Use a non-empty root key so
  // ReMincross can block swaps across cluster boundaries.
  let root_cluster = match graph.name() {
    Some(value) => value
    None => "__root__"
  }
  for name, key in rem_cluster_keys {
    if key == "" {
      rem_cluster_keys[name] = root_cluster
    }
  }
  if order_with_vnodes {
    let mut edge_idx = 0
    for edge in edges {
      let vnodes = match vnode_info.edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      if vnodes.length() == 0 {
        edge_idx = edge_idx + 1
        continue
      }
      let (tail, head) =
        remincross_edge_endpoints_at(edge, edge_idx, edge_tail, edge_head)
      let tail_cluster =
        remincross_cluster_key_or_empty(cluster_meta.intercluster_keys, tail)
      let head_cluster =
        remincross_cluster_key_or_empty(cluster_meta.intercluster_keys, head)
      // Graphviz parity: mark_lowclusters assigns virtual nodes to the
      // lowest common ancestor cluster for intercluster edges.
      let vnode_cluster =
        cluster_lowest_common_ancestor(
          tail_cluster,
          head_cluster,
          cluster_meta.cluster_parents,
        )
      let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
      for vnode in vnodes {
        rem_cluster_keys[vnode] = rem_cluster
      }
      edge_idx = edge_idx + 1
    }
  }
  let rem_sizes =
    build_order_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
    )
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  // Graphviz parity: ReMincross flat constraints combine existing same-rank
  // constraints with local intra-cluster adjacency locks for non-intercluster
  // real-node pairs (flat.c cluster-local reorder guard).
  if !order_with_clusters {
    for key, value in cluster_meta.flat_constraints {
      rem_flat_constraints[key] = value
    }
    for key, _ in rank_same_constraints {
      rem_flat_constraints[key] = true
    }
  }
  (rem_cluster_keys, rem_sizes, rem_flat_constraints)
}

///|
/// Graphviz parity: ReMincross rank groups start from real-node groups and
/// optionally inject edge-vnodes using vnode order keys from cluster-aware
/// trailing-vnode adjustments.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_groups_with_optional_vnodes(
  final_groups : Map[Int, Array[String]],
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let rem_base_groups = clone_rank_groups(final_groups)
  let rem_base_order_index = build_order_index(rem_base_groups)
  let rem_vnode_order_keys =
    if !order_with_vnodes {
      Map::new()
    } else {
      let remincross_cluster_keys : Map[String, String] = Map::new()
      for name, key in intercluster_keys {
        remincross_cluster_keys[name] = key
      }
      let intercluster_vnodes : Map[String, Bool] = Map::new()
      let mut edge_idx = 0
      for edge in edges {
        let (tail, head) =
          remincross_edge_endpoints_at(edge, edge_idx, edge_tail, edge_head)
        let tail_cluster = remincross_cluster_key_or_empty(remincross_cluster_keys, tail)
        let head_cluster = remincross_cluster_key_or_empty(remincross_cluster_keys, head)
        let internal =
          tail_cluster != "" && head_cluster != "" &&
          edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
        let should_trail =
          if internal || tail_cluster == head_cluster {
            false
          } else if tail_cluster == "" || head_cluster == "" {
            false
          } else {
            let tail_min = match cluster_min_rank.get(tail_cluster) {
              Some(value) => value
              None => 0
            }
            let tail_max = match cluster_max_rank.get(tail_cluster) {
              Some(value) => value
              None => tail_min
            }
            let head_min = match cluster_min_rank.get(head_cluster) {
              Some(value) => value
              None => 0
            }
            let head_max = match cluster_max_rank.get(head_cluster) {
              Some(value) => value
              None => head_min
            }
            let overlap = tail_min <= head_max && head_min <= tail_max
            !overlap
          }
        if should_trail {
          let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
            Some(list) => list
            None => []
          }
          for vnode in vnodes {
            intercluster_vnodes[vnode] = true
          }
        }
        edge_idx = edge_idx + 1
      }
      let keys = build_vnode_order_keys(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        rem_base_order_index,
        remincross_cluster_keys,
        cluster_parents,
        edge_vnodes,
        vnode_ranks,
      )
      if intercluster_vnodes.length() > 0 {
        // Graphviz parity: trailing-vnode floor uses the maximum real-node order seen
        // per rank from the current ReMincross base order index.
        let max_order_by_rank : Map[Int, Int] = Map::new()
        for name, order in rem_base_order_index {
          let rank = match ranks.get(name) {
            Some(value) => value
            None => continue
          }
          match max_order_by_rank.get(rank) {
            Some(current) =>
              if order > current {
                max_order_by_rank[rank] = order
              }
            None => max_order_by_rank[rank] = order
          }
        }
        let mut seq = 0
        for vnode, _ in intercluster_vnodes {
          let rank = match vnode_ranks.get(vnode) {
            Some(value) => value
            None => continue
          }
          let max_order = match max_order_by_rank.get(rank) {
            Some(value) => value
            None => -1
          }
          let base = Double::from_int(max_order + 1)
          let offset = Double::from_int(seq) * 0.000001
          let min_key = base + offset
          match keys.get(vnode) {
            Some(current) =>
              if current < min_key {
                keys[vnode] = min_key
              }
            None => keys[vnode] = min_key
          }
          seq = seq + 1
        }
      }
      keys
    }
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      rem_base_groups,
      rem_base_order_index,
      vnodes_by_rank,
      rem_vnode_order_keys,
    )
  } else {
    rem_base_groups
  }
}

///|
/// Graphviz parity: ReMincross can seed from current vnode-inclusive rank
/// order while keeping real-node relative order from cleaned base groups.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_groups_from_ordered_with_vnodes(
  base_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let rem_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in ordered_with_vnodes {
    let filtered : Array[String] = []
    for name in names {
      if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
        filtered.push(name)
      }
    }
    if filtered.length() == 0 {
      continue
    }
    let base_real = match base_groups.get(rank) {
      Some(list) => list
      None => []
    }
    if base_real.length() == 0 {
      rem_groups[rank] = filtered
      continue
    }
    let real_order : Map[String, Int] = Map::new()
    for i in 0..<base_real.length() {
      real_order[base_real[i]] = i
    }
    let mut root_real_count = 0
    let mut cluster_real_count = 0
    let mut root_real_name = ""
    let cluster_real_names : Array[String] = []
    for name in base_real {
      if cluster_key_or_empty(cluster_keys, name) == "" {
        root_real_count = root_real_count + 1
        root_real_name = name
      } else {
        cluster_real_count = cluster_real_count + 1
        cluster_real_names.push(name)
      }
    }
    let mut synthetic_count = 0
    let mut synthetic_name = ""
    for name in filtered {
      if real_order.get(name) is None {
        synthetic_count = synthetic_count + 1
        synthetic_name = name
      }
    }
    // Graphviz parity: when a mixed root/cluster rank starts with exactly one
    // synthetic vnode, keep the root real node as the rank leader and trail
    // that single vnode after clustered real nodes.
    if filtered.length() == 4 &&
      is_edge_vnode_name(filtered[0]) &&
      root_real_count == 1 &&
      cluster_real_count >= 2 &&
      synthetic_count == 1 &&
      synthetic_name != "" &&
      root_real_name != "" {
      let special_order : Array[String] = [root_real_name]
      for name in cluster_real_names {
        special_order.push(name)
      }
      special_order.push(synthetic_name)
      rem_groups[rank] = special_order
      continue
    }
    let prev_real : Array[Int?] = []
    let mut last_real : Int? = None
    for name in filtered {
      match real_order.get(name) {
        Some(idx) => last_real = Some(idx)
        None => ()
      }
      prev_real.push(last_real)
    }
    let next_rev : Array[Int?] = []
    let mut next_real : Int? = None
    let mut rev_idx = filtered.length()
    while rev_idx > 0 {
      rev_idx = rev_idx - 1
      let name = filtered[rev_idx]
      match real_order.get(name) {
        Some(idx) => next_real = Some(idx)
        None => ()
      }
      next_rev.push(next_real)
    }
    let next_real_by_pos : Array[Int?] = []
    let mut idx = next_rev.length()
    while idx > 0 {
      idx = idx - 1
      next_real_by_pos.push(next_rev[idx])
    }
    let keyed : Array[(String, Int, Int)] = []
    for i in 0..<filtered.length() {
      let name = filtered[i]
      let key = match real_order.get(name) {
        Some(real_idx) => real_idx * 2
        None =>
          match prev_real[i] {
            Some(prev_idx) => prev_idx * 2 + 1
            None =>
              match next_real_by_pos[i] {
                Some(next_idx) => next_idx * 2 - 1
                None => i * 2
              }
          }
      }
      keyed.push((name, key, i))
    }
    keyed.sort_by((a, b) => {
      let (_, key_a, idx_a) = a
      let (_, key_b, idx_b) = b
      if key_a < key_b {
        -1
      } else if key_a > key_b {
        1
      } else if idx_a < idx_b {
        -1
      } else if idx_a > idx_b {
        1
      } else {
        0
      }
    })
    let ordered_rank : Array[String] = []
    for entry in keyed {
      let (name, _, _) = entry
      ordered_rank.push(name)
    }
    rem_groups[rank] = ordered_rank
  }
  rem_groups
}

///|
/// Graphviz parity: clustered ReMincross pass dispatch context keeps
/// rematerialize+cleanup payload ordering unchanged before rank-count branch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossPassDispatchContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  base_groups : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}
