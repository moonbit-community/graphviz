///|
/// Extracted from layout_pipeline_helpers.mbt to keep clustered ReMincross
/// and rematerialization helpers isolated from non-cluster order flow.

///|
/// Graphviz parity: ReMincross GD_nlist order is rebuilt from creation order
/// + vnode expansion + fast-graph edge insertion order (decompose parity).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_tail_order(
  rem_order_creation : Array[String],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  rem_edge_creation : Array[(String, String)],
  cluster_order_index : Map[String, Int],
) -> Array[String] {
  let cluster_key_for_name = (name : String) => {
    let direct = match rem_cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
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
  let cluster_order_seen : Array[String] = []
  let cluster_seen : Map[String, Bool] = Map::new()
  let names_by_cluster : Map[String, Array[String]] = Map::new()
  for name in rem_order_creation {
    let cluster = cluster_key_for_name(name)
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
    let a_idx = match cluster_order_index.get(a) {
      Some(value) => value
      None => -1
    }
    let b_idx = match cluster_order_index.get(b) {
      Some(value) => value
      None => -1
    }
    if a_idx > b_idx {
      return -1
    }
    if a_idx < b_idx {
      return 1
    }
    let a_seen = match cluster_first_seen.get(a) {
      Some(value) => value
      None => 0
    }
    let b_seen = match cluster_first_seen.get(b) {
      Some(value) => value
      None => 0
    }
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
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  for edge in rem_edge_creation {
    let (tail, head) = edge
    match heads_by_tail.get(tail) {
      Some(list) => list.push(head)
      None => heads_by_tail[tail] = [head]
    }
  }
  let rem_nlist_order : Array[String] = []
  for cluster in cluster_order {
    let names = match names_by_cluster.get(cluster) {
      Some(list) => list
      None => []
    }
    if cluster == "" {
      let root_names = match remincross_root_tail_order_override_snapshot.val {
        Some(override_names) =>
          reorder_rank_names_by_override(
            names,
            override_names,
          )
        None => names
      }
      for name in root_names {
        rem_nlist_order.push(name)
      }
      continue
    }
    let rank_keys : Array[Int] = []
    let rank_seen : Map[Int, Bool] = Map::new()
    for name in names {
      let rank = match rem_ranks.get(name) {
        Some(value) => value
        None => -1
      }
      if rank_seen.get(rank) is None {
        rank_seen[rank] = true
        rank_keys.push(rank)
      }
    }
    rank_keys.sort()
    let min_rank = {
      let mut candidate = -1
      for value in rank_keys {
        if value >= 0 {
          candidate = value
          break
        }
      }
      candidate
    }
    let mut rank_idx = rank_keys.length()
    while rank_idx > 0 {
      rank_idx = rank_idx - 1
      let rank = rank_keys[rank_idx]
      let rank_names : Array[String] = []
      for name in names {
        let name_rank = match rem_ranks.get(name) {
          Some(value) => value
          None => -1
        }
        if name_rank == rank {
          rank_names.push(name)
        }
      }
      let rank_ordered : Array[String] = []
      let mut all_without_outgoing = true
      for name in rank_names {
        if heads_by_tail.get(name) is Some(_) {
          all_without_outgoing = false
          break
        }
      }
      if cluster != "" && all_without_outgoing {
        for name in rank_names {
          rank_ordered.push(name)
        }
      } else {
        let mut name_idx = rank_names.length()
        while name_idx > 0 {
          name_idx = name_idx - 1
          rank_ordered.push(rank_names[name_idx])
        }
      }
      let mut all_input_like = true
      for name in rank_ordered {
        if !name.has_prefix("i-") {
          all_input_like = false
          break
        }
      }
      if rank == min_rank && rank_ordered.length() > 1 && all_input_like {
        let current_cluster_pos = match cluster_order_pos.get(cluster) {
          Some(value) => value
          None => 0
        }
        let category0 : Array[String] = []
        let category1 : Array[String] = []
        let category2 : Array[String] = []
        let category3 : Array[String] = []
        for name in rank_ordered {
          let heads = match heads_by_tail.get(name) {
            Some(list) => list
            None => []
          }
          let mut has_later = false
          let mut has_earlier = false
          for head in heads {
            let head_cluster = cluster_key_for_name(head)
            if head_cluster == cluster {
              continue
            }
            let head_pos = match cluster_order_pos.get(head_cluster) {
              Some(value) => value
              None => cluster_order.length()
            }
            if head_pos > current_cluster_pos {
              has_later = true
            } else if head_pos < current_cluster_pos {
              has_earlier = true
            }
          }
          let out_degree = heads.length()
          if !has_later && !has_earlier && out_degree > 1 {
            category0.push(name)
          } else if has_later {
            category1.push(name)
          } else if has_earlier {
            category2.push(name)
          } else {
            category3.push(name)
          }
        }
        let reordered_rank : Array[String] = []
        for name in category0 {
          reordered_rank.push(name)
        }
        for name in category1 {
          reordered_rank.push(name)
        }
        for name in category2 {
          reordered_rank.push(name)
        }
        for name in category3 {
          reordered_rank.push(name)
        }
        let mut idx = 0
        while idx < reordered_rank.length() {
          rank_ordered[idx] = reordered_rank[idx]
          idx = idx + 1
        }
      }
      for name in rank_ordered {
        rem_nlist_order.push(name)
      }
    }
  }
  rem_nlist_order
}

///|
/// Graphviz parity: ReMincross GD_nlist order keeps cluster-local blocks in
/// first-seen cluster sequence and replays each cluster block by rank-desc
/// reverse-order before root-cluster nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_nlist_order(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
) -> Array[String] {
  let rem_order_creation =
    build_rem_order_creation_sequence(creation_order, rem_vnode_creation)
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let debug_names : Array[String] = [
      "i-gd-gd",
      "o-gd-vrml",
      "i-core-ps",
      "i-core-svg",
      "i-svg",
    ]
    for name in debug_names {
      let cluster = match rem_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      let rank = match rem_ranks.get(name) {
        Some(value) => value
        None => -1
      }
      println("remincross cluster_key \{name}=\{cluster} rank=\{rank}")
    }
  }
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
      build_remincross_cluster_tail_order(
        rem_order_creation,
        rem_ranks,
        rem_cluster_keys,
        rem_edge_creation,
        cluster_order_index,
      )
    }
  if rem_nlist_order.length() < rem_order_creation.length() {
    let seen : Map[String, Bool] = Map::new()
    for name in rem_nlist_order {
      seen[name] = true
    }
    for name in rem_order_creation {
      if seen.get(name) is None {
        rem_nlist_order.push(name)
        seen[name] = true
      }
    }
  }
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let rem_creation_joined = rem_order_creation.join(" ")
    let rem_nlist_joined = rem_nlist_order.join(" ")
    println("remincross rem_order_creation \{rem_creation_joined}")
    println("remincross rem_nlist_order \{rem_nlist_joined}")
  }
  rem_nlist_order
}

///|
/// Graphviz parity: ReMincross order-graph materialization filters local flat
/// constraints by fast-graph membership, rebuilds GD_nlist, seeds node order,
/// then materializes edge arrays in nlist tail order.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_materialized_order_graph(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let rem_ranks = build_node_ranks(rem_groups)
  let rem_nlist_order =
    build_remincross_nlist_order(
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_ranks,
      rem_cluster_keys,
      cluster_order_index,
    )
  let rem_node_order = build_order_index(rem_groups)
  let (
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    collect_order_edges_for_tail_sequence(
      rem_nlist_order,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
    )
  build_clustered_remincross_materialized_edges_output(
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: ReMincross base cluster keys copy intercluster keys and
/// map empty keys to a non-empty root ND_clust key (mark_lowclusters).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys_base(
  graph : @cgraph.Graph,
  intercluster_keys : Map[String, String],
) -> (Map[String, String], String) {
  let rem_cluster_keys : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
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
  (rem_cluster_keys, root_cluster)
}


///|
/// Graphviz parity: ReMincross virtual nodes take the LCA endpoint cluster
/// (or root fallback) from intercluster edge endpoints.
/// Do not change behavior without updating fixtures/tests.
fn assign_remincross_vnode_clusters_from_edges(
  rem_cluster_keys : Map[String, String],
  root_cluster : String,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Unit {
  let mut edge_idx = 0
  for edge in edges {
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      edge_idx = edge_idx + 1
      continue
    }
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = cluster_key_or_empty(intercluster_keys, tail)
    let head_cluster = cluster_key_or_empty(intercluster_keys, head)
    // Graphviz parity: mark_lowclusters assigns virtual nodes to the
    // lowest common ancestor cluster for intercluster edges.
    let vnode_cluster =
      cluster_lowest_common_ancestor(
        tail_cluster,
        head_cluster,
        cluster_parents,
      )
    let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
    for vnode in vnodes {
      rem_cluster_keys[vnode] = rem_cluster
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: ReMincross cluster keys start from intercluster keys,
/// map empty keys to the root graph key, and assign edge vnodes to the LCA
/// cluster (mark_lowclusters) for cluster-boundary swap guards.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, String] {
  let (rem_cluster_keys, root_cluster) =
    build_remincross_cluster_keys_base(graph, intercluster_keys)
  if !order_with_vnodes {
    return rem_cluster_keys
  }
  assign_remincross_vnode_clusters_from_edges(
    rem_cluster_keys,
    root_cluster,
    edges,
    edge_tail,
    edge_head,
    intercluster_keys,
    cluster_parents,
    edge_vnodes,
  )
  rem_cluster_keys
}

///|
/// Graphviz parity: intercluster short-span guard selects only edges crossing
/// cluster keys with absolute rank difference <= 1.
/// Do not change behavior without updating fixtures/tests.
fn edge_has_intercluster_short_span(
  tail : String,
  head : String,
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Bool {
  let tail_cluster = cluster_key_or_empty(intercluster_keys, tail)
  let head_cluster = cluster_key_or_empty(intercluster_keys, head)
  if tail_cluster == head_cluster {
    return false
  }
  let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
  let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
  let span = if tail_rank <= head_rank {
    head_rank - tail_rank
  } else {
    tail_rank - head_rank
  }
  span <= 1
}

///|
/// Graphviz parity: intercluster node guard marks real endpoints of
/// intercluster edges with rank span <= 1 for local-order relaxation.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_nodes_with_short_span(
  order_with_clusters : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let intercluster_nodes : Map[String, Bool] = Map::new()
  if !order_with_clusters {
    return intercluster_nodes
  }
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if edge_has_intercluster_short_span(
      tail,
      head,
      intercluster_keys,
      ranks,
    ) {
      intercluster_nodes[tail] = true
      intercluster_nodes[head] = true
    }
    edge_idx = edge_idx + 1
  }
  intercluster_nodes
}

///|
/// Graphviz parity: root/ReMincross node-order seeding follows GD_nlist order
/// and fills missing nodes from current rank-group index.
/// Do not change behavior without updating fixtures/tests.
fn build_order_node_order_from_nlist_and_groups(
  nlist_order : Array[String],
  node_map : Map[String, @cgraph.Node],
  groups : Map[Int, Array[String]],
) -> Map[String, Int] {
  let node_order_out : Map[String, Int] = Map::new()
  let mut node_idx = 0
  for name in nlist_order {
    if node_map.get(name) is Some(_) {
      node_order_out[name] = node_idx
      node_idx = node_idx + 1
    }
  }
  let order_index = build_order_index(groups)
  for name, idx in order_index {
    if node_order_out.get(name) is None {
      node_order_out[name] = idx
    }
  }
  node_order_out
}

///|
/// Graphviz parity: ReMincross flat constraints combine existing same-rank
/// constraints with local intra-cluster adjacency locks for non-intercluster
/// real-node pairs (flat.c cluster-local reorder guard).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_flat_constraints(
  flat_constraints : Map[String, Bool],
  rank_same_constraints : Map[String, Bool],
  order_with_clusters : Bool,
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_cluster_keys : Map[String, String],
  intercluster_nodes : Map[String, Bool],
) -> Map[String, Bool] {
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  if !order_with_clusters {
    for key, value in flat_constraints {
      rem_flat_constraints[key] = value
    }
    for key, _ in rank_same_constraints {
      rem_flat_constraints[key] = true
    }
    return rem_flat_constraints
  }
  ignore(rem_groups)
  ignore(real_nodes)
  ignore(rem_cluster_keys)
  ignore(intercluster_nodes)
  rem_flat_constraints
}

///|
/// Graphviz parity: ReMincross clustered reorder executes mincross with
/// startpass=2 on rematerialized fast-graph edges and local flat constraints.
/// Do not change behavior without updating fixtures/tests.
fn run_remincross_rank_reorder_startpass2(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
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
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    for rank in rem_rank_keys {
      let names = match rem_groups.get(rank) {
        Some(list) => list
        None => []
      }
      let rank_joined = names.join(" ")
      println("remincross_input_rank \{rank}: \{rank_joined}")
    }
    let mut idx = 0
    while idx < rem_edges_out.length() {
      let tail = rem_edge_tail_out[idx]
      let head = rem_edge_head_out[idx]
      let pen = edge_xpenalty(rem_edges_out[idx])
      println("remincross_input_edge \{idx}: \{tail} -> \{head} pen=\{pen}")
      idx = idx + 1
    }
  }
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
    rank_same_groups,
    rank_same_order,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    Map::new(),
    rem_flat_constraints,
    graphviz_flip=graphviz_flip,
    // Graphviz parity: ReMincross counts parallel chain segments once
    // with summed xpenalty before startpass=2 transposition.
    coalesce_parallel_edges=true,
    startpass=2,
    remincross_mode=true,
  )
}

///|
/// Graphviz parity: ReMincross final reorder runs with startpass=2 using
/// materialized fast-graph edges, then drops non-real nodes for final groups
/// while preserving rank iteration and per-rank order.
/// Do not change behavior without updating fixtures/tests.
fn run_remincross_reorder_and_collect_real_groups(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let rem_ordered =
    run_remincross_rank_reorder_startpass2(
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
      rank_same_groups,
      rank_same_order,
      rem_edge_order,
      rem_node_order,
      rem_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      rem_flat_constraints,
      graphviz_flip,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    dot_trace_groups("remincross_ordered", rem_ordered)
  }
  let rem_cleaned =
    collect_real_only_rank_groups(rem_rank_keys, rem_ordered, real_nodes)
  (rem_ordered, rem_cleaned)
}

///|
/// Graphviz parity: ReMincross reorder cluster inputs derive cluster keys
/// (including vnode LCA assignments) and intercluster short-span node guards.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_inputs_for_reorder(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> (Map[String, String], Map[String, Bool]) {
  let rem_cluster_keys =
    build_remincross_cluster_keys(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      vnode_info.edge_vnodes,
    )
  let intercluster_nodes =
    collect_intercluster_nodes_with_short_span(
      order_with_clusters,
      edge_tail,
      edge_head,
      cluster_meta.intercluster_keys,
      ranks,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_vnodes : Array[String] = [
      "_mbt_edge_vn_0_3",
      "_mbt_edge_vn_1_3",
    ]
    for name in debug_vnodes {
      let cluster = cluster_key_or_empty(rem_cluster_keys, name)
      println("remincross vnode \{name} cluster=\{cluster}")
    }
  }
  (rem_cluster_keys, intercluster_nodes)
}

///|
/// Graphviz parity: ReMincross reorder size/constraint inputs extend sizes with
/// vnode dimensions and augment flat constraints with same-rank + cluster-local
/// guards before final reorder.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_sizes_and_flat_constraints(
  order_sizes : Map[String, NodeSize],
  order_with_vnodes : Bool,
  vnode_sizes : Map[String, NodeSize],
  flat_constraints : Map[String, Bool],
  rank_same_constraints : Map[String, Bool],
  order_with_clusters : Bool,
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_cluster_keys : Map[String, String],
  intercluster_nodes : Map[String, Bool],
) -> (Map[String, NodeSize], Map[String, Bool]) {
  let rem_sizes =
    build_order_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_sizes,
    )
  let rem_flat_constraints =
    build_remincross_flat_constraints(
      flat_constraints,
      rank_same_constraints,
      order_with_clusters,
      rem_groups,
      real_nodes,
      rem_cluster_keys,
      intercluster_nodes,
    )
  (rem_sizes, rem_flat_constraints)
}

///|
/// Graphviz parity: ReMincross reorder inputs derive cluster keys (including
/// vnode LCA assignments), local intercluster-node guards, size map extension,
/// and flat-constraint augmentation before final reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_reorder_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> (Map[String, String], Map[String, NodeSize], Map[String, Bool]) {
  let (rem_cluster_keys, intercluster_nodes) =
    build_remincross_cluster_inputs_for_reorder(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      order_with_clusters,
      ranks,
      cluster_meta,
      vnode_info,
    )
  let (rem_sizes, rem_flat_constraints) =
    build_remincross_sizes_and_flat_constraints(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
      cluster_meta.flat_constraints,
      rank_same_constraints,
      order_with_clusters,
      rem_groups,
      real_nodes,
      rem_cluster_keys,
      intercluster_nodes,
    )
  (rem_cluster_keys, rem_sizes, rem_flat_constraints)
}

///|
/// Debug trace: dump selected ReMincross per-tail edge lists when
/// DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_order_edges_by_tail(
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  match rem_order_edges_by_tail.get("arbiter_vadam") {
    Some(list) => {
      let mut idx = 0
      while idx < list.length() {
        let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
        println("remincross arbiter edge \{idx}: \{t} -> \{h}")
        idx = idx + 1
      }
    }
    None => ()
  }
  let debug_tails : Array[String] = ["front_end_jz", "others"]
  for name in debug_tails {
    match rem_order_edges_by_tail.get(name) {
      Some(list) => {
        let mut idx = 0
        while idx < list.length() {
          let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
          println("remincross out \{name} \{idx}: \{t} -> \{h}")
          idx = idx + 1
        }
      }
      None => ()
    }
  }
}

///|
/// Debug trace: dump materialized ReMincross edges (high-pen and selected
/// endpoints) when DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_materialized_edges(
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let mut idx = 0
  while idx < rem_edges_out.length() {
    let edge = rem_edges_out[idx]
    let pen = edge_xpenalty(edge)
    if pen >= CL_CROSS {
      let tail = rem_edge_tail_out[idx]
      let head = rem_edge_head_out[idx]
      println("remincross high-pen edge \{tail} -> \{head} pen=\{pen}")
    }
    idx = idx + 1
  }
  let mut edge_idx = 0
  while edge_idx < rem_edge_tail_out.length() {
    let tail = rem_edge_tail_out[edge_idx]
    let head = rem_edge_head_out[edge_idx]
    if tail == "z_req" || tail == "z_req1" || head == "z_req" ||
      head == "z_req1" {
      println("remincross edge \{edge_idx}: \{tail} -> \{head}")
    }
    edge_idx = edge_idx + 1
  }
}

