///|
/// Stage C Phase C3 split: cluster-local reorder/build-ranks
/// helpers isolated from other Stage C phases.

///|
/// Graphviz parity: local-cluster stable sorts compare seed order first and
/// break ties by node name to keep deterministic fixture ordering.
fn compare_by_order_then_name(
  order_map : Map[String, Int],
  a : String,
  b : String,
) -> Int {
  let a_idx = order_map.get(a).unwrap_or_default()
  let b_idx = order_map.get(b).unwrap_or_default()
  if a_idx < b_idx {
    -1
  } else if a_idx > b_idx {
    1
  } else if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

fn cluster_depth_for_order_inner(
  cluster : String,
  parents : Map[String, String?],
  fallback_parents : Map[String, String?],
  memo : Map[String, Int],
  visiting : Map[String, Bool],
) -> Int {
  match memo.get(cluster) {
    Some(value) => value
    None => {
      if visiting.get(cluster) is Some(_) {
        return 0
      }
      visiting[cluster] = true
      // Graphviz parity: cluster parent lookup prefers explicit traversal hints
      // and falls back to collected parent graph edges.
      let candidate : String? = match parents.get(cluster) {
        Some(value) => value
        None =>
          match fallback_parents.get(cluster) {
            Some(value) => value
            None => None
          }
      }
      let parent_opt : String? =
        match candidate {
          Some(value) =>
            if value == "" || value == cluster {
              None
            } else {
              Some(value)
            }
          None => None
        }
      let depth = match parent_opt {
        Some(parent) =>
          cluster_depth_for_order_inner(
            parent,
            parents,
            fallback_parents,
            memo,
            visiting,
          ) + 1
        None => 0
      }
      memo[cluster] = depth
      depth
    }
  }
}

///|
fn cluster_depth_for_order(
  cluster : String,
  parents : Map[String, String?],
  fallback_parents : Map[String, String?],
  memo : Map[String, Int],
) -> Int {
  cluster_depth_for_order_inner(
    cluster,
    parents,
    fallback_parents,
    memo,
    Map::new(),
  )
}

///|
fn cluster_order_index_or_end(
  cluster_index : Map[String, Int],
  name : String,
) -> Int {
  match cluster_index.get(name) {
    Some(value) => value
    None => cluster_index.length() + 1
  }
}



///|
/// Graphviz parity: cluster-local pass iterates cluster subgraphs in
/// depth-first parent order with cluster_order tie-breaking (cluster.c path).
/// Do not change behavior without updating fixtures/tests.
priv struct LocalClusterGraphOrderOutput {
  cluster_graphs : Map[String, @cgraph.Graph]
  cluster_names : Array[String]
}

///|
/// Graphviz parity: cluster-local pass iterates cluster subgraphs in
/// depth-first parent order with cluster_order tie-breaking (cluster.c path).
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_graph_order(
  graph : @cgraph.Graph,
  cluster_order : Array[String],
  cluster_parents_hint : Map[String, String?],
) -> LocalClusterGraphOrderOutput {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  @dot_shared.collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  let cluster_names : Array[String] = []
  for name, _ in cluster_graphs {
    cluster_names.push(name)
  }
  if cluster_graphs.length() == 0 {
    return { cluster_graphs, cluster_names }
  }
  let cluster_index = @ordering.build_cluster_order_index(cluster_order)
  let cluster_depth : Map[String, Int] = Map::new()
  for name in cluster_names {
    let _ = cluster_depth_for_order(
      name,
      cluster_parents_hint,
      cluster_parents,
      cluster_depth,
    )
  }
  if cluster_names.length() > 1 {
    cluster_names.sort_by((a, b) => {
      let a_depth = cluster_depth.get(a).unwrap_or_default()
      let b_depth = cluster_depth.get(b).unwrap_or_default()
      if a_depth < b_depth {
        -1
      } else if a_depth > b_depth {
        1
      } else {
        let a_idx = cluster_order_index_or_end(cluster_index, a)
        let b_idx = cluster_order_index_or_end(cluster_index, b)
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
  { cluster_graphs, cluster_names }
}

///|
/// Graphviz parity: rank-local real-node rewrites preserve vnode slots and only
/// replace non-vnode positions in left-to-right sequence.
fn rewrite_rank_real_slots(
  list : Array[String],
  reordered_real_nodes : Array[String],
) -> Unit {
  let mut real_idx = 0
  for i in 0..<list.length() {
    if is_edge_vnode_name(list[i]) {
      continue
    }
    list[i] = reordered_real_nodes[real_idx]
    real_idx = real_idx + 1
  }
}

///|
fn collect_rank_real_nodes(list : Array[String]) -> Array[String] {
  let real_nodes : Array[String] = []
  for name in list {
    if !is_edge_vnode_name(name) {
      real_nodes.push(name)
    }
  }
  real_nodes
}

///|
fn build_name_set(names : Array[String]) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map::new()
  for name in names {
    out[name] = true
  }
  out
}

///|
/// Graphviz parity: each rank list normalizes real-node order by seeded
/// cluster node order before previous-rank reachability seeding.
fn normalize_rank_real_nodes(
  list : Array[String],
  cluster_node_order : Map[String, Int],
) -> Unit {
  if list.length() <= 1 {
    return ()
  }
  let real_nodes = collect_rank_real_nodes(list)
  if real_nodes.length() <= 1 {
    return ()
  }
  real_nodes.sort_by((a, b) => {
    compare_by_order_then_name(cluster_node_order, a, b)
  })
  rewrite_rank_real_slots(list, real_nodes)
}

///|
/// Graphviz parity: local ND_out reachability is restricted to cluster members
/// before previous-rank seeded ordering.
fn build_cluster_out_heads_by_tail(
  cluster_node_set : Map[String, Bool],
  source_graphviz_out_neighbors : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out_heads_by_tail : Map[String, Array[String]] = Map::new()
  for tail, _ in cluster_node_set {
    let heads = source_graphviz_out_neighbors.get(tail).unwrap_or_default()
    let filtered : Array[String] = []
    for head in heads {
      if cluster_node_set.get(head) is Some(_) {
        filtered.push(head)
      }
    }
    if filtered.length() > 0 {
      out_heads_by_tail[tail] = filtered
    }
  }
  out_heads_by_tail
}

///|
/// Graphviz parity: rank real-node seeding prefers reachable heads from the
/// previous rank, then appends remaining nodes by seeded node order.
fn seed_rank_real_nodes_from_previous_rank(
  list : Array[String],
  prev_names : Array[String],
  out_heads_by_tail : Map[String, Array[String]],
  cluster_node_order : Map[String, Int],
) -> Unit {
  if list.length() <= 1 {
    return ()
  }
  let real_nodes = collect_rank_real_nodes(list)
  let real_set = build_name_set(real_nodes)
  if real_nodes.length() <= 1 {
    return ()
  }
  let seeded_real_nodes : Array[String] = []
  let seeded_seen : Map[String, Bool] = Map::new()
  for tail in prev_names {
    let heads = out_heads_by_tail.get(tail).unwrap_or_default()
    for head in heads {
      if real_set.get(head) is Some(_) && seeded_seen.get(head) is None {
        seeded_real_nodes.push(head)
        seeded_seen[head] = true
      }
    }
  }
  let fallback_real_nodes = real_nodes.copy()
  fallback_real_nodes.sort_by((a, b) => {
    compare_by_order_then_name(cluster_node_order, a, b)
  })
  for name in fallback_real_nodes {
    if seeded_seen.get(name) is None {
      seeded_real_nodes.push(name)
      seeded_seen[name] = true
    }
  }
  rewrite_rank_real_slots(list, seeded_real_nodes)
}

///|
/// Graphviz parity: local cluster rank groups include only cluster members and
/// seed each rank from previous-rank ND_out reachability before seed-order
/// fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_local_rank_groups(
  groups : Map[Int, Array[String]],
  cluster_node_set : Map[String, Bool],
  cluster_node_order : Map[String, Int],
  source_graphviz_out_neighbors : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let cluster_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    let list : Array[String] = []
    for name in names {
      if cluster_node_set.get(name) is Some(_) {
        list.push(name)
      }
    }
    normalize_rank_real_nodes(list, cluster_node_order)
    if list.length() > 0 {
      cluster_groups[rank] = list
    }
  }
  let out_heads_by_tail =
    build_cluster_out_heads_by_tail(
      cluster_node_set,
      source_graphviz_out_neighbors,
    )
  let cluster_rank_keys = @ordering.collect_rank_keys(cluster_groups)
  for rank in cluster_rank_keys {
    let list = match cluster_groups.get(rank) {
      Some(value) => value
      None => continue
    }
    let prev_names = cluster_groups.get(rank - 1).unwrap_or_default()
    seed_rank_real_nodes_from_previous_rank(
      list,
      prev_names,
      out_heads_by_tail,
      cluster_node_order,
    )
  }
  cluster_groups
}



///|
/// Graphviz parity: cluster-local ND_out/ND_in maps append raw graph AGSEQ
/// neighbors after order-graph replay, skipping duplicates to mirror fixture
/// out_all/in_all merge behavior.
/// Do not change behavior without updating fixtures/tests.
priv struct LocalNeighborMapsOutput {
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
}

///|
/// Graphviz parity: cluster-local neighbor sources keep order-graph ND_out/ND_in
/// together with raw graph AGSEQ ND_out/ND_in for deterministic merge.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalNeighborSources {
  source_out_neighbors : Map[String, Array[String]]
  source_in_neighbors : Map[String, Array[String]]
  raw_out_neighbors : Map[String, Array[String]]
  raw_in_neighbors : Map[String, Array[String]]
}

///|
/// Stage C Phase C3 split: raw Graphviz ND_out/ND_in neighbor map bundle used
/// by local-cluster neighbor replay before per-cluster merge.
priv struct GraphvizNeighborMaps {
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
}

///|
fn append_neighbor_edge(
  out_neighbors : Map[String, Array[String]],
  in_neighbors : Map[String, Array[String]],
  tail : String,
  head : String,
) -> Unit {
  match out_neighbors.get(tail) {
    Some(list) => list.push(head)
    None => out_neighbors[tail] = [head]
  }
  match in_neighbors.get(head) {
    Some(list) => list.push(tail)
    None => in_neighbors[head] = [tail]
  }
}

///|
/// Graphviz parity: raw-graph ND_out/ND_in maps preserve AGSEQ edge replay
/// order for local cluster median-anchor fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_raw_graphviz_neighbor_maps(graph : @cgraph.Graph) -> GraphvizNeighborMaps {
  let raw_graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let raw_graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for node in graph.nodes() {
    let name = node.name()
    raw_graphviz_out_neighbors[name] = []
    raw_graphviz_in_neighbors[name] = []
  }
  for edge in graph.edges() {
    append_neighbor_edge(
      raw_graphviz_out_neighbors,
      raw_graphviz_in_neighbors,
      edge.tail().name(),
      edge.head().name(),
    )
  }
  {
    out_neighbors: raw_graphviz_out_neighbors,
    in_neighbors: raw_graphviz_in_neighbors,
  }
}

///|
/// Graphviz parity: neighbor list append preserves first occurrence order.
fn append_unique_neighbor_name(
  list : Array[String],
  value : String,
) -> Unit {
  for item in list {
    if item == value {
      return ()
    }
  }
  list.push(value)
}

///|
/// Graphviz parity: unresolved neighbors from not-yet-expanded clusters are
/// collapsed onto the shared external anchor name.
fn normalize_external_neighbor_name(
  other : String,
  cluster : String,
  expanded_clusters : Map[String, Bool],
  intercluster_keys : Map[String, String],
  external_anchor_name : String,
) -> String {
  let other_cluster = @ordering.cluster_key_or_empty(intercluster_keys, other)
  if other_cluster != "" && other_cluster != cluster &&
    expanded_clusters.get(other_cluster) is None {
    external_anchor_name
  } else {
    other
  }
}

///|
/// Graphviz parity: raw AGSEQ neighbors are merged only when source ND_out/in
/// does not already expose an external anchor.
fn has_external_neighbor(
  neighbors : Array[String],
  cluster_node_set : Map[String, Bool],
) -> Bool {
  for other in neighbors {
    if cluster_node_set.get(other) is None {
      return true
    }
  }
  false
}

///|
/// Graphviz parity: raw AGSEQ neighbors are merged only when source ND_out/in
/// does not already expose an external anchor.
fn has_source_external_anchor(
  name : String,
  cluster_node_set : Map[String, Bool],
  source_out_neighbors : Map[String, Array[String]],
  source_in_neighbors : Map[String, Array[String]],
) -> Bool {
  let out = source_out_neighbors.get(name).unwrap_or_default()
  if has_external_neighbor(out, cluster_node_set) {
    return true
  }
  let inn = source_in_neighbors.get(name).unwrap_or_default()
  has_external_neighbor(inn, cluster_node_set)
}

///|
/// Graphviz parity: raw AGSEQ neighbors merge with duplicate suppression and
/// one external anchor per external cluster in each direction list.
fn append_raw_neighbors_with_external_anchor(
  neighbors : Array[String],
  raw_neighbors : Array[String],
  cluster : String,
  expanded_clusters : Map[String, Bool],
  intercluster_keys : Map[String, String],
  external_anchor_name : String,
) -> Unit {
  let external_cluster_seen : Map[String, Bool] = Map::new()
  for other in raw_neighbors {
    if is_edge_vnode_name(other) || other.has_prefix(CLUSTER_SKELETON_PREFIX) {
      continue
    }
    let normalized =
      normalize_external_neighbor_name(
        other,
        cluster,
        expanded_clusters,
        intercluster_keys,
        external_anchor_name,
      )
    if normalized == external_anchor_name {
      let external_cluster = @ordering.cluster_key_or_empty(intercluster_keys, other)
      if external_cluster == "" ||
        external_cluster_seen.get(external_cluster) is Some(_) {
        continue
      }
      external_cluster_seen[external_cluster] = true
      neighbors.push(normalized)
    } else {
      append_unique_neighbor_name(neighbors, normalized)
    }
  }
}

///|
priv struct LocalNeighborLists {
  out_neighbors : Array[String]
  in_neighbors : Array[String]
}

///|
/// Graphviz parity: per-node local neighbor lists start from order-graph
/// ND_out/ND_in and only then merge raw AGSEQ neighbors when allowed.
fn build_local_neighbor_lists_for_name(
  name : String,
  cluster : String,
  cluster_node_set : Map[String, Bool],
  expanded_clusters : Map[String, Bool],
  neighbor_sources : ClusterLocalNeighborSources,
  intercluster_keys : Map[String, String],
  allow_raw_neighbors : Bool,
  external_anchor_name : String,
) -> LocalNeighborLists {
  let out_neighbors =
    neighbor_sources.source_out_neighbors.get(name).unwrap_or_default().copy()
  let in_neighbors =
    neighbor_sources.source_in_neighbors.get(name).unwrap_or_default().copy()
  if !allow_raw_neighbors ||
    has_source_external_anchor(
      name,
      cluster_node_set,
      neighbor_sources.source_out_neighbors,
      neighbor_sources.source_in_neighbors,
    ) {
    return { out_neighbors, in_neighbors }
  }
  let raw_out = neighbor_sources.raw_out_neighbors.get(name).unwrap_or_default()
  append_raw_neighbors_with_external_anchor(
    out_neighbors,
    raw_out,
    cluster,
    expanded_clusters,
    intercluster_keys,
    external_anchor_name,
  )
  let raw_in = neighbor_sources.raw_in_neighbors.get(name).unwrap_or_default()
  append_raw_neighbors_with_external_anchor(
    in_neighbors,
    raw_in,
    cluster,
    expanded_clusters,
    intercluster_keys,
    external_anchor_name,
  )
  { out_neighbors, in_neighbors }
}

///|
/// Graphviz parity: cluster-local ND_out/ND_in maps append raw graph AGSEQ
/// neighbors after order-graph replay, skipping duplicates to mirror fixture
/// out_all/in_all merge behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_local_neighbor_maps(
  cluster : String,
  expanded_clusters : Map[String, Bool],
  cluster_nodes : Array[String],
  neighbor_sources : ClusterLocalNeighborSources,
  intercluster_keys : Map[String, String],
  allow_raw_neighbors : Bool,
) -> LocalNeighborMapsOutput {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  let cluster_node_set = build_name_set(cluster_nodes)
  let external_anchor_name = "%0"
  for name in cluster_nodes {
    let local_neighbor_lists =
      build_local_neighbor_lists_for_name(
        name,
        cluster,
        cluster_node_set,
        expanded_clusters,
        neighbor_sources,
        intercluster_keys,
        allow_raw_neighbors,
        external_anchor_name,
      )
    graphviz_out_neighbors[name] = local_neighbor_lists.out_neighbors
    graphviz_in_neighbors[name] = local_neighbor_lists.in_neighbors
  }
  { graphviz_out_neighbors, graphviz_in_neighbors }
}

/// Graphviz parity: cluster-local mincross runs only when a cluster has
/// internal ordering constraints; otherwise the input order is preserved.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterRankReorderOutput {
  has_internal_constraints : Bool
  ordered_cluster : Map[Int, Array[String]]
}

///|
/// Graphviz parity: cluster-local mincross seeds ND_order by vnode
/// interpolation, then applies same-rank flat constraints before startpass=2.
fn build_cluster_rank_seeded_groups(
  local_context : ClusterLocalReorderContext,
  input_phase_output : ClusterLocalReorderRunInputsOutput,
  fixed_ranks : Map[String, Int],
) -> Map[Int, Array[String]] {
  let seeded_by_vnode_interp =
    seed_local_groups_by_vnode(
      local_context.cluster_rank_keys,
      local_context.cluster_groups,
      fixed_ranks,
      input_phase_output.parents,
      input_phase_output.children,
    )
  // Graphviz parity: mincross_clust() runs flat_reorder before mincross(g,2).
  @ordering.flat_reorder_rank_groups(
    local_context.cluster_rank_keys,
    seeded_by_vnode_interp,
    fixed_ranks,
    input_phase_output.cluster_flat_constraints,
    false,
  )
}

/// Graphviz parity: cluster-local mincross runs only when a cluster has
/// internal ordering constraints; otherwise the input order is preserved.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_reorder(
  local_context : ClusterLocalReorderContext,
  input_phase_output : ClusterLocalReorderRunInputsOutput,
  dispatch_context : ClusterLocalReorderDispatchContext,
) -> ClusterRankReorderOutput {
  if input_phase_output.cluster_edges.length() == 0 &&
    input_phase_output.cluster_flat_constraints.length() == 0 {
    return { has_internal_constraints: false, ordered_cluster: Map::new() }
  }
  let seeded_cluster_groups =
    build_cluster_rank_seeded_groups(
      local_context,
      input_phase_output,
      dispatch_context.fixed_ranks,
    )
  let ordered_cluster =
    @ordering.reorder_rank_groups(
      local_context.cluster_rank_keys,
      seeded_cluster_groups,
      input_phase_output.cluster_edges,
      input_phase_output.cluster_edge_tail,
      input_phase_output.cluster_edge_head,
      input_phase_output.cluster_edge_tail_port_x,
      input_phase_output.cluster_edge_head_port_x,
      input_phase_output.cluster_edge_tail_port_order,
      input_phase_output.cluster_edge_head_port_order,
      input_phase_output.parents,
      input_phase_output.children,
      input_phase_output.cluster_keys,
      dispatch_context.cluster_meta.rank_same_groups,
      dispatch_context.cluster_meta.rank_same_order,
      input_phase_output.edge_order,
      local_context.cluster_node_order,
      input_phase_output.cluster_sizes,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      Map::new(),
      dispatch_context.empty_cluster_skeleton,
      input_phase_output.cluster_flat_constraints,
      graphviz_out_neighbors=input_phase_output.graphviz_out_neighbors,
      graphviz_in_neighbors=input_phase_output.graphviz_in_neighbors,
      // Graphviz parity: subgraphs use effective rankdir=TB, so flip is false.
      fixed_positions=local_context.cluster_fixed_positions,
      fixed_ranks=dispatch_context.fixed_ranks,
      graphviz_flip=false,
      // Graphviz parity: cluster-local startpass=2 mincross coalesces
      // parallel edge segments by endpoint+port order and sums xpenalty.
      coalesce_parallel_edges=true,
      startpass=2,
      startpass_init_infinite=false,
  )
  { has_internal_constraints: true, ordered_cluster }
}

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
fn seed_local_groups_by_vnode(
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

///|
fn build_cluster_sizes_for_reorder(
  cluster_node_set : Map[String, Bool],
  order_sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  // Graphviz parity: cluster-local reorder metadata keeps node sizes scoped to
  // the filtered cluster node subset.
  let cluster_sizes : Map[String, NodeSize] = Map::new()
  for name, _ in cluster_node_set {
    match order_sizes.get(name) {
      Some(size) => cluster_sizes[name] = size
      None =>
        match vnode_sizes.get(name) {
          Some(size) => cluster_sizes[name] = size
          None => ()
        }
    }
  }
  cluster_sizes
}

///|
fn filter_cluster_flat_constraints(
  cluster_node_set : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> Map[String, Bool] {
  // Graphviz parity: local reorder forwards same-rank flat constraints only
  // when both endpoints belong to the active cluster node subset.
  let cluster_flat_constraints : Map[String, Bool] = Map::new()
  for key, value in flat_constraints {
    if !value {
      continue
    }
    match @dot_shared.parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        if cluster_node_set.get(tail) is Some(_) &&
          cluster_node_set.get(head) is Some(_) {
          cluster_flat_constraints[key] = value
        }
      }
      None => ()
    }
  }
  cluster_flat_constraints
}

///|
/// Graphviz parity: cluster-local reorder run-input payload keeps edge arrays
/// and metadata maps grouped for dispatch into reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderRunInputsOutput {
  cluster_edges : Array[@cgraph.Edge]
  cluster_edge_tail : Array[String]
  cluster_edge_head : Array[String]
  cluster_edge_tail_port_x : Array[Double]
  cluster_edge_head_port_x : Array[Double]
  cluster_edge_tail_port_order : Array[Double]
  cluster_edge_head_port_order : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  edge_order : Map[String, Int]
  cluster_sizes : Map[String, NodeSize]
  cluster_keys : Map[String, String]
  cluster_flat_constraints : Map[String, Bool]
}

///|
priv struct LocalReorderEdgeBundle {
  cluster_edges : Array[@cgraph.Edge]
  cluster_edge_tail : Array[String]
  cluster_edge_head : Array[String]
  cluster_edge_tail_port_x : Array[Double]
  cluster_edge_head_port_x : Array[Double]
  cluster_edge_tail_port_order : Array[Double]
  cluster_edge_head_port_order : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  edge_order : Map[String, Int]
}

///|
/// Graphviz parity: local edge-bundle build reads one immutable snapshot of
/// order-edge arrays together with the cluster node subset/filter mode.
priv struct LocalReorderEdgeBuildInputs {
  include_external_crossing : Bool
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  cluster_node_set : Map[String, Bool]
  cluster_nodes : Array[String]
  fixed_ranks : Map[String, Int]
}

///|
/// Graphviz parity: shallow cluster-local reorder (<=2 ranks) keeps incoming
/// and outgoing crossing edges so median anchors see external slots.
/// Do not change behavior without updating fixtures/tests.
fn build_local_reorder_edge_bundle(
  inputs : LocalReorderEdgeBuildInputs,
) -> LocalReorderEdgeBundle {
  let cluster_edges : Array[@cgraph.Edge] = []
  let cluster_edge_tail : Array[String] = []
  let cluster_edge_head : Array[String] = []
  let cluster_edge_tail_port_x : Array[Double] = []
  let cluster_edge_head_port_x : Array[Double] = []
  let cluster_edge_tail_port_order : Array[Double] = []
  let cluster_edge_head_port_order : Array[Double] = []
  for i in 0..<inputs.order_edges.length() {
    let tail = inputs.order_edge_tail[i]
    let head = inputs.order_edge_head[i]
    let tail_in = inputs.cluster_node_set.get(tail) is Some(_)
    let head_in = inputs.cluster_node_set.get(head) is Some(_)
    let keep = (tail_in && head_in) ||
      (inputs.include_external_crossing && (tail_in || head_in))
    if !keep {
      continue
    }
    cluster_edges.push(inputs.order_edges[i])
    cluster_edge_tail.push(tail)
    cluster_edge_head.push(head)
    cluster_edge_tail_port_x.push(inputs.order_edge_tail_port_x[i])
    cluster_edge_head_port_x.push(inputs.order_edge_head_port_x[i])
    cluster_edge_tail_port_order.push(inputs.order_edge_tail_port_order[i])
    cluster_edge_head_port_order.push(inputs.order_edge_head_port_order[i])
  }
  let edge_index_data = @ordering.build_edge_index_for_names(
    inputs.cluster_nodes,
    cluster_edge_tail,
    cluster_edge_head,
    inputs.fixed_ranks,
  )
  {
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents: edge_index_data.parents,
    children: edge_index_data.children,
    edge_order: @ordering.collect_edge_order(cluster_edges),
  }
}

///|
fn count_edge_vnodes(names : Array[String]) -> Int {
  let mut vnode_count = 0
  for name in names {
    if is_edge_vnode_name(name) {
      vnode_count = vnode_count + 1
    }
  }
  vnode_count
}

///|
/// Graphviz parity: shallow cluster-local reorder (<=2 ranks) keeps incoming
/// and outgoing crossing edges so median anchors see external slots.
/// Do not change behavior without updating fixtures/tests.
fn should_include_external_crossing_edges(
  cluster_rank_keys : Array[Int],
  cluster_graph_edge_count : Int,
  vnode_count : Int,
) -> Bool {
  if @sys.get_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE") is Some(_) {
    return cluster_rank_keys.length() <= 2
  }
  if cluster_rank_keys.length() > 2 &&
    cluster_graph_edge_count == 0 &&
    vnode_count == 0 {
    return false
  }
  true
}

///|
/// Graphviz parity: local edge-bundle policy derives external-crossing
/// inclusion from rank depth, cluster edge presence, vnode density, and
/// fixture-capture mode before filtering order edges.
fn build_local_reorder_edge_bundle_for_context(
  input_context : ClusterLocalReorderInputBuildContext,
) -> LocalReorderEdgeBundle {
  let vnode_count = count_edge_vnodes(input_context.cluster_nodes)
  let include_external_crossing =
    should_include_external_crossing_edges(
      input_context.cluster_rank_keys,
      input_context.cluster_graph_edge_count,
      vnode_count,
    )
  build_local_reorder_edge_bundle(
    {
      include_external_crossing,
      order_edges: input_context.order_edges,
      order_edge_tail: input_context.order_edge_tail,
      order_edge_head: input_context.order_edge_head,
      order_edge_tail_port_x: input_context.order_edge_tail_port_x,
      order_edge_head_port_x: input_context.order_edge_head_port_x,
      order_edge_tail_port_order: input_context.order_edge_tail_port_order,
      order_edge_head_port_order: input_context.order_edge_head_port_order,
      cluster_node_set: input_context.cluster_node_set,
      cluster_nodes: input_context.cluster_nodes,
      fixed_ranks: input_context.fixed_ranks,
    },
  )
}

///|
/// Graphviz parity: local cluster keys are cleared for all active cluster
/// nodes so cluster-local reorder ignores cross-cluster barriers.
fn build_local_reorder_cluster_keys(
  cluster_node_set : Map[String, Bool],
) -> Map[String, String] {
  let cluster_keys : Map[String, String] = Map::new()
  for name, _ in cluster_node_set {
    // Graphviz parity: mincross_clust() runs on the expanded subgraph where
    // ND_clust is cleared, so local reorder/transpose should not see
    // cross-cluster barriers for these nodes.
    cluster_keys[name] = ""
  }
  cluster_keys
}

///|
/// Graphviz parity: cluster-local reorder metadata keeps node sizes, local
/// cluster-key resets, flat constraints, and neighbor maps scoped together.
priv struct ClusterLocalReorderMetadata {
  cluster_sizes : Map[String, NodeSize]
  cluster_keys : Map[String, String]
  cluster_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
}

///|
/// Graphviz parity: cluster-local reorder metadata is assembled from one
/// cluster-node subset and one filtered edge bundle snapshot.
fn build_cluster_local_reorder_metadata(
  input_context : ClusterLocalReorderInputBuildContext,
  edge_bundle : LocalReorderEdgeBundle,
) -> ClusterLocalReorderMetadata {
  let cluster_sizes =
    build_cluster_sizes_for_reorder(
      input_context.cluster_node_set,
      input_context.order_sizes,
      input_context.vnode_sizes,
    )
  let cluster_keys =
    build_local_reorder_cluster_keys(input_context.cluster_node_set)
  let cluster_flat_constraints =
    filter_cluster_flat_constraints(
      input_context.cluster_node_set,
      input_context.flat_constraints,
    )
  let local_neighbor_maps =
    build_local_neighbor_maps(
      input_context.cluster_name,
      input_context.expanded_clusters,
      input_context.cluster_nodes,
      input_context.neighbor_sources,
      input_context.intercluster_keys,
      edge_bundle.cluster_edges.length() >= 5,
    )
  {
    cluster_sizes,
    cluster_keys,
    cluster_flat_constraints,
    graphviz_out_neighbors: local_neighbor_maps.graphviz_out_neighbors,
    graphviz_in_neighbors: local_neighbor_maps.graphviz_in_neighbors,
  }
}

///|
/// Graphviz parity: cluster-local reorder input build context keeps the
/// per-cluster node subset together with shared edge/neighbor snapshots.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderInputBuildContext {
  cluster_name : String
  cluster_graph_edge_count : Int
  expanded_clusters : Map[String, Bool]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  neighbor_sources : ClusterLocalNeighborSources
  cluster_node_set : Map[String, Bool]
  cluster_rank_keys : Array[Int]
  cluster_nodes : Array[String]
  fixed_ranks : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  vnode_sizes : Map[String, NodeSize]
  intercluster_keys : Map[String, String]
  flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: cluster-local reorder input context pulls all shared edge/
/// neighbor snapshots from dispatch context and all cluster subset data from
/// local context before edge/metadata materialization.
fn build_cluster_local_reorder_input_build_context(
  cluster : String,
  cluster_graph_edge_count : Int,
  expanded_clusters : Map[String, Bool],
  local_context : ClusterLocalReorderContext,
  dispatch_context : ClusterLocalReorderDispatchContext,
) -> ClusterLocalReorderInputBuildContext {
  {
    cluster_name: cluster,
    cluster_graph_edge_count,
    expanded_clusters,
    order_edges: dispatch_context.order_edges,
    order_edge_tail: dispatch_context.order_edge_tail,
    order_edge_head: dispatch_context.order_edge_head,
    order_edge_tail_port_x: dispatch_context.order_edge_tail_port_x,
    order_edge_head_port_x: dispatch_context.order_edge_head_port_x,
    order_edge_tail_port_order: dispatch_context.order_edge_tail_port_order,
    order_edge_head_port_order: dispatch_context.order_edge_head_port_order,
    neighbor_sources: dispatch_context.neighbor_sources,
    cluster_node_set: local_context.cluster_node_set,
    cluster_rank_keys: local_context.cluster_rank_keys,
    cluster_nodes: local_context.cluster_nodes,
    fixed_ranks: dispatch_context.fixed_ranks,
    order_sizes: dispatch_context.order_sizes,
    vnode_sizes: dispatch_context.vnode_info.vnode_sizes,
    intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
    flat_constraints: dispatch_context.cluster_meta.flat_constraints,
  }
}

///|
/// Graphviz parity: cluster-local reorder builds internal edge bundle and
/// metadata maps from the same filtered cluster node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_local_reorder_inputs(
  input_context : ClusterLocalReorderInputBuildContext,
) -> ClusterLocalReorderRunInputsOutput {
  let edge_bundle =
    build_local_reorder_edge_bundle_for_context(input_context)
  let metadata =
    build_cluster_local_reorder_metadata(input_context, edge_bundle)
  {
    cluster_edges: edge_bundle.cluster_edges,
    cluster_edge_tail: edge_bundle.cluster_edge_tail,
    cluster_edge_head: edge_bundle.cluster_edge_head,
    cluster_edge_tail_port_x: edge_bundle.cluster_edge_tail_port_x,
    cluster_edge_head_port_x: edge_bundle.cluster_edge_head_port_x,
    cluster_edge_tail_port_order: edge_bundle.cluster_edge_tail_port_order,
    cluster_edge_head_port_order: edge_bundle.cluster_edge_head_port_order,
    parents: edge_bundle.parents,
    children: edge_bundle.children,
    graphviz_out_neighbors: metadata.graphviz_out_neighbors,
    graphviz_in_neighbors: metadata.graphviz_in_neighbors,
    edge_order: edge_bundle.edge_order,
    cluster_sizes: metadata.cluster_sizes,
    cluster_keys: metadata.cluster_keys,
    cluster_flat_constraints: metadata.cluster_flat_constraints,
  }
}

///|
/// Graphviz parity: cluster-local reorder context keeps filtered cluster nodes,
/// seeded local rank groups, and fixed-slot exclusions in one bundle.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderContext {
  cluster_node_set : Map[String, Bool]
  cluster_nodes : Array[String]
  cluster_node_order : Map[String, Int]
  cluster_groups : Map[Int, Array[String]]
  cluster_rank_keys : Array[Int]
  cluster_fixed_positions : Map[String, Double]
}

///|
/// Graphviz parity: cluster-local reorder node-order context keeps filtered
/// cluster members and deterministic local node indices built from node_order.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterNodeOrderContext {
  cluster_nodes : Array[String]
  cluster_node_order : Map[String, Int]
}

///|
/// Graphviz parity: cluster-local reorder node set keeps cluster members that
/// are present in rank groups, plus local vnodes when enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_node_set_for_reorder(
  cluster : String,
  cluster_graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  vnode_clusters : Map[String, String],
  order_with_vnodes : Bool,
) -> Map[String, Bool] {
  let cluster_nodes_set : Map[String, Bool] = Map::new()
  for node in cluster_graph.nodes() {
    cluster_nodes_set[node.name()] = true
  }
  if order_with_vnodes {
    for vnode, vnode_cluster in vnode_clusters {
      if vnode_cluster == cluster {
        cluster_nodes_set[vnode] = true
      }
    }
  }
  let cluster_node_set : Map[String, Bool] = Map::new()
  for _rank, names in groups {
    for name in names {
      if cluster_nodes_set.get(name) is Some(_) {
        cluster_node_set[name] = true
      }
    }
  }
  cluster_node_set
}

///|
/// Graphviz parity: cluster-local node-order context uses global node_order as
/// deterministic seed before assigning contiguous local order ids.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_node_order_context(
  cluster_node_set : Map[String, Bool],
  node_order : Map[String, Int],
) -> ClusterNodeOrderContext {
  let cluster_nodes : Array[String] = []
  for name, _ in cluster_node_set {
    cluster_nodes.push(name)
  }
  let cluster_node_order : Map[String, Int] = Map::new()
  let cluster_ordered_nodes = cluster_nodes.copy()
  if cluster_ordered_nodes.length() > 1 {
    cluster_ordered_nodes.sort_by((a, b) => {
      compare_by_order_then_name(node_order, a, b)
    })
  }
  let mut order_idx = 0
  for name in cluster_ordered_nodes {
    cluster_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  { cluster_nodes, cluster_node_order }
}

///|
/// Graphviz parity: cluster-local reorder preserves fixed slots outside the
/// active cluster node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_fixed_positions(
  fixed_positions : Map[String, Double],
  cluster_node_set : Map[String, Bool],
) -> Map[String, Double] {
  let cluster_fixed_positions : Map[String, Double] = Map::new()
  for name, value in fixed_positions {
    if cluster_node_set.get(name) is None {
      cluster_fixed_positions[name] = value
    }
  }
  cluster_fixed_positions
}

///|
/// Graphviz parity: cluster-local reorder only considers nodes that are
/// present in rank groups and belong to the current cluster (plus local
/// virtual nodes when enabled).
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderContextBuildInputs {
  cluster : String
  cluster_graph : @cgraph.Graph
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  source_out_neighbors : Map[String, Array[String]]
  vnode_clusters : Map[String, String]
  fixed_positions : Map[String, Double]
  order_with_vnodes : Bool
}

///|
/// Graphviz parity: cluster-local reorder context inputs pair the active
/// cluster graph/group slice with dispatch-level ordering/vnode snapshots.
fn build_cluster_local_reorder_context_build_inputs(
  cluster : String,
  cluster_graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  fixed_positions : Map[String, Double],
  dispatch_context : ClusterLocalReorderDispatchContext,
) -> ClusterLocalReorderContextBuildInputs {
  {
    cluster,
    cluster_graph,
    groups,
    node_order: dispatch_context.node_order,
    source_out_neighbors: dispatch_context.neighbor_sources.source_out_neighbors,
    vnode_clusters: dispatch_context.vnode_info.vnode_clusters,
    fixed_positions,
    order_with_vnodes: dispatch_context.order_with_vnodes,
  }
}

///|
/// Graphviz parity: cluster-local reorder only considers nodes that are
/// present in rank groups and belong to the current cluster (plus local
/// virtual nodes when enabled).
fn build_cluster_local_reorder_context(
  inputs : ClusterLocalReorderContextBuildInputs,
) -> ClusterLocalReorderContext? {
  let cluster_node_set =
    build_cluster_node_set_for_reorder(
      inputs.cluster,
      inputs.cluster_graph,
      inputs.groups,
      inputs.vnode_clusters,
      inputs.order_with_vnodes,
    )
  if cluster_node_set.length() <= 1 {
    return None
  }
  let node_order_context =
    build_cluster_node_order_context(
      cluster_node_set,
      inputs.node_order,
    )
  let cluster_nodes = node_order_context.cluster_nodes
  let cluster_node_order = node_order_context.cluster_node_order
  let cluster_groups = build_local_rank_groups(
    inputs.groups,
    cluster_node_set,
    cluster_node_order,
    inputs.source_out_neighbors,
  )
  let cluster_rank_keys = @ordering.collect_rank_keys(cluster_groups)
  let cluster_fixed_positions =
    build_cluster_fixed_positions(inputs.fixed_positions, cluster_node_set)
  Some({
    cluster_node_set,
    cluster_nodes,
    cluster_node_order,
    cluster_groups,
    cluster_rank_keys,
    cluster_fixed_positions,
  })
}

///|
/// Graphviz parity: cluster-local reorder writes only cluster members back to
/// existing rank slots, preserving non-cluster node positions.
fn apply_cluster_rank_reorder_output(
  groups : Map[Int, Array[String]],
  cluster_rank_keys : Array[Int],
  ordered_cluster : Map[Int, Array[String]],
  cluster_node_set : Map[String, Bool],
) -> Unit {
  for rank in cluster_rank_keys {
    let desired = ordered_cluster.get(rank).unwrap_or_default()
    if desired.length() <= 1 {
      continue
    }
    let names = match groups.get(rank) {
      Some(list) => list
      None => continue
    }
    let mut idx = 0
    let mut pos = 0
    while pos < names.length() && idx < desired.length() {
      if cluster_node_set.get(names[pos]) is Some(_) {
        names[pos] = desired[idx]
        idx = idx + 1
      }
      pos = pos + 1
    }
  }
}
