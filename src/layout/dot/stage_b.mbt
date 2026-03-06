///|
/// Stage B stage-local type definitions shared by rank assignment and
/// rank-height assembly.

///|
/// Graphviz parity: rank-data payload keeps stage-B rank inputs grouped so
/// edge direction/orientation wiring remains explicit and stable.
priv struct RankDataInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  has_edge_labels : Bool
}

///|
priv struct RankData {
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  all_ranks : Array[Int]
  self_edge_labels : Map[String, Double]
}

///|
priv struct RankHeights {
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  nodesep_pt : Double
  ranksep_pt : Double
}

///|
/// Graphviz parity: cluster metadata payload keeps rank and cluster snapshots
/// grouped so Stage B clustered-ordering wiring remains explicit and stable.
priv struct ClusterMetadata {
  has_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
/// Stage B rank-data scaffolding helpers for layered ordering preparation.

///|
/// Graphviz parity: rank direction + acyclic edge directions aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_data(
  input : RankDataInput,
) -> RankData {
  let graph = input.graph
  let nodes = input.nodes
  let edges = input.edges
  // Graphviz parity: edge direction/order comes from acyclic.c for both
  // directed and undirected inputs (dot rank preprocessing orients edges first).
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  let acyclic_directions =
    @rank_assignment.acyclic_edge_directions_with_order(graph, nodes, edges)
  let edge_tail = acyclic_directions.tail
  let edge_head = acyclic_directions.head
  let edge_reversed = acyclic_directions.reversed
  let out_edges = acyclic_directions.out_edges
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    edge_out_order[name] = out_edges[i].copy()
  }
  let ranks = @rank_assignment.compute_ranks_directed(
    graph,
    nodes,
    edges,
    input.has_edge_labels,
    edge_tail,
    edge_head,
    CL_BACK,
  )
  let groups = @ordering.build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  // Graphviz parity: rank sweep iterates the closed min..max rank interval
  // from sorted rank keys, including missing intermediate ranks.
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  let self_edge_labels =
    @positioning.self_edge_label_half_heights(
      edges,
      edge => edge_label_height_pt(edge),
    )
  {
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    rank_keys,
    all_ranks,
    self_edge_labels,
  }
}
///|
/// Stage B rank-height assembly helpers for layered spacing preparation.

///|
/// Graphviz parity: rank-height payload keeps rank and spacing snapshots
/// grouped so Stage B height wiring remains explicit and stable.
priv struct RankHeightsInput {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  all_ranks : Array[Int]
  sizes : Map[String, NodeSize]
  self_edge_labels : Map[String, Double]
  rankdir : RankDir
  nodesep_in : Double
  ranksep_in : Double
  has_edge_labels : Bool
}

///|
/// Graphviz parity: long-edge label midpoint contributes half height to the
/// midpoint rank slot before rank height normalization.
/// Do not change behavior without updating fixtures/tests.
fn update_rank_pht_for_label(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rankdir : RankDir,
) -> Unit {
  if !@dot_shared.edge_has_label(edge) {
    return
  }
  let tail = edge.tail().name()
  let head = edge.head().name()
  let tail_rank = match ranks.get(tail) {
    Some(value) => value
    None => return
  }
  let head_rank = match ranks.get(head) {
    Some(value) => value
    None => return
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  if max_rank - min_rank <= 1 {
    return
  }
  let label_rank = (min_rank + max_rank) / 2
  let half_height = match edge_mid_label_metrics(edge) {
    Some(metrics) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        metrics.width / 2.0
      } else {
        metrics.height / 2.0
      }
    None => 0.0
  }
  let current = match rank_pht.get(label_rank) {
    Some(value) => value
    None => 0.0
  }
  if half_height > current {
    rank_pht[label_rank] = half_height
  }
}

///|
priv struct RankHeightCopies {
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
priv struct BaseRankHalfHeights {
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
fn init_rank_half_heights(
  all_ranks : Array[Int],
) -> Map[Int, Double] {
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  rank_pht
}

///|
fn apply_node_rank_half_heights(
  rank_pht : Map[Int, Double],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
) -> Unit {
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_half = 0.0
    for name in names {
      let half_height =
        @positioning.node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
}

///|
fn apply_edge_label_rank_half_heights(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rankdir : RankDir,
) -> Unit {
  for edge in edges {
    update_rank_pht_for_label(edge, ranks, rank_pht, rankdir)
  }
}

///|
fn apply_vnode_rank_half_heights(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
) -> Unit {
  // Graphviz parity: long edges reserve vnode half-height across
  // intermediate ranks before cluster rank height adjustments.
  let vnode_half_height = VNODE_HEIGHT_PT / 2.0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      continue
    }
    for rank in (min_rank + 1)..<max_rank {
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if vnode_half_height > current {
        rank_pht[rank] = vnode_half_height
      }
    }
  }
}

///|
fn clone_rank_half_heights(
  all_ranks : Array[Int],
  rank_pht : Map[Int, Double],
) -> RankHeightCopies {
  // Graphviz parity: rank_ht1/rank_ht2 start as symmetric copies of rank_pht
  // before cluster-specific adjustments.
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = match rank_pht.get(rank) {
      Some(value) => value
      None => 0.0
    }
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  { rank_ht1, rank_ht2 }
}

///|
/// Graphviz parity: base rank half-heights are computed before cluster-specific
/// rank height adjustment in the same node->edge-label->vnode order as rank.c.
/// Do not change behavior without updating fixtures/tests.
fn build_base_rank_half_heights(
  input : RankHeightsInput,
) -> BaseRankHalfHeights {
  let rank_pht = init_rank_half_heights(input.all_ranks)
  apply_node_rank_half_heights(
    rank_pht,
    input.rank_keys,
    input.groups,
    input.sizes,
    input.self_edge_labels,
  )
  if input.has_edge_labels {
    apply_edge_label_rank_half_heights(
      input.edges,
      input.ranks,
      rank_pht,
      input.rankdir,
    )
  }
  apply_vnode_rank_half_heights(input.edges, input.ranks, rank_pht)
  let rank_height_copies = clone_rank_half_heights(input.all_ranks, rank_pht)
  {
    rank_pht,
    rank_ht1: rank_height_copies.rank_ht1,
    rank_ht2: rank_height_copies.rank_ht2,
  }
}

///|
/// Graphviz parity: rank height/spacing aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_heights(
  input : RankHeightsInput,
) -> RankHeights {
  let graph = input.graph
  let ranks = input.ranks
  let sizes = input.sizes
  let self_edge_labels = input.self_edge_labels
  let base_half_heights = build_base_rank_half_heights(input)
  let rank_pht = base_half_heights.rank_pht
  let rank_ht1 = base_half_heights.rank_ht1
  let rank_ht2 = base_half_heights.rank_ht2
  let _ = @clustering.apply_cluster_rank_heights(
    {
      graph,
      ranks,
      sizes,
      self_edge_labels,
      rank_ht1,
      rank_ht2,
      rankdir: input.rankdir,
      cluster_margin_pt_for: @positioning.cluster_margin_pt,
      cluster_label_padding_for: cluster_label_padding_for_layout,
      node_half_height_pt_for: @positioning.node_half_height_pt,
    },
  )
  let nodesep_pt = @dot_shared.round_int(input.nodesep_in * 72.0).to_double()
  let mut ranksep_pt_int = @dot_shared.round_int(input.ranksep_in * 72.0)
  if input.has_edge_labels {
    ranksep_pt_int = (ranksep_pt_int + 1) / 2
  }
  let ranksep_pt = ranksep_pt_int.to_double()
  { rank_pht, rank_ht1, rank_ht2, nodesep_pt, ranksep_pt }
}
///|
/// Stage B cluster metadata preprocessing and rank-same helper flow for
/// clustered ordering inputs.

///|
/// Graphviz parity: cluster-metadata payload keeps rank and cluster snapshots
/// grouped so Stage B clustered-ordering wiring remains explicit and stable.
priv struct ClusterMetadataInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  groups : Map[Int, Array[String]]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  edge_tail : Array[String]
  edge_head : Array[String]
  graphviz_flip : Bool
}

///|
priv struct ClusterRankBounds {
  min_rank : Map[String, Int]
  max_rank : Map[String, Int]
  first_order : Map[String, Int]
}

///|
priv struct RankSameMetadata {
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
}

///|
/// Graphviz parity: optional cluster order base expansion follows the
/// DOT_CLUSTER_ORDER_BASE debug path used for deterministic cluster spacing.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_order_metadata(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  cluster_min_rank : Map[String, Int],
  cluster_first_order : Map[String, Int],
  node_order : Map[String, Int],
) -> Unit {
  let cluster_order_list : Array[(String, Int, Int)] = []
  for cluster, rank in cluster_min_rank {
    let order = match cluster_first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    cluster_order_list.push((cluster, rank, order))
  }
  let cluster_order_base : Map[String, Int] = Map::new()
  if cluster_order_list.length() > 1 &&
    @sys.get_env_var("DOT_CLUSTER_ORDER_BASE") is Some(_) {
    cluster_order_list.sort_by((a, b) => {
      let (_name_a, rank_a, order_a) = a
      let (_name_b, rank_b, order_b) = b
      if rank_a < rank_b {
        -1
      } else if rank_a > rank_b {
        1
      } else if order_a < order_b {
        -1
      } else if order_a > order_b {
        1
      } else {
        0
      }
    })
    let step = nodes.length() + 1
    let mut base = 0
    for entry in cluster_order_list {
      let (cluster, _rank, _order) = entry
      cluster_order_base[cluster] = base
      base = base + step
    }
    for node in nodes {
      let name = node.name()
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let base_order = match cluster_order_base.get(cluster) {
        Some(value) => value
        None => 0
      }
      let inner = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = base_order + inner
    }
  }
}

///|
/// Graphviz parity: each cluster contributes one skeleton node per rank
/// (first node encountered in rank order).
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_skeleton(
  groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[String, Bool] {
  let cluster_skeleton : Map[String, Bool] = Map::new()
  let cluster_rank_seen : Map[String, Bool] = Map::new()
  for rank, names in groups {
    for name in names {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let key = "\{cluster}@\{rank}"
      if cluster_rank_seen.get(key) is None {
        cluster_rank_seen[key] = true
        cluster_skeleton[name] = true
      }
    }
  }
  cluster_skeleton
}

///|
/// Graphviz parity: cluster min/max rank and first order are collected
/// from cluster member nodes before clustered reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_rank_bounds(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> ClusterRankBounds {
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let cluster_first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = @ordering.cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match cluster_min_rank.get(cluster) {
      Some(current) => if rank < current { cluster_min_rank[cluster] = rank }
      None => cluster_min_rank[cluster] = rank
    }
    match cluster_max_rank.get(cluster) {
      Some(current) => if rank > current { cluster_max_rank[cluster] = rank }
      None => cluster_max_rank[cluster] = rank
    }
    if cluster_first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      cluster_first_order[cluster] = order_value
    }
  }
  {
    min_rank: cluster_min_rank,
    max_rank: cluster_max_rank,
    first_order: cluster_first_order,
  }
}

///|
/// Graphviz parity: same-rank edges are promoted to flat ordering
/// constraints for clustered metadata reorder paths.
/// Do not change behavior without updating fixtures/tests.
fn promote_same_rank_edges_to_flat_constraints(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  flat_constraints : Map[String, Bool],
) -> Unit {
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    if edge_idx < edges.length() && !@dot_shared.edge_is_constraint(edges[edge_idx]) {
      edge_idx = edge_idx + 1
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      let tail_rank = @ordering.flat_constraint_rank_or_zero(ranks, tail)
      let head_rank = @ordering.flat_constraint_rank_or_zero(ranks, head)
      if tail_rank == head_rank {
        flat_constraints["\{tail}|\{head}"] = true
      }
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: cluster keys mirror per-node cluster ownership used across
/// clustered ordering and compound-edge preprocessing.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_key_map(
  nodes : Array[@cgraph.Node],
) -> Map[String, String] {
  let cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    cluster_keys[node.name()] = @clustering.node_cluster_key(node)
  }
  cluster_keys
}

///|
/// Graphviz parity: initial cluster node order seeds follow GD_nlist traversal
/// with optional graphviz_flip reversal before clustered reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn seed_cluster_node_order(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
  node_order : Map[String, Int],
) -> Unit {
  let creation_order : Map[String, Int] = Map::new()
  for i, node in nodes {
    creation_order[node.name()] = i
  }
  let total_nodes = nodes.length()
  for node in nodes {
    let name = node.name()
    let cluster = @ordering.cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    let base_order = match creation_order.get(name) {
      Some(value) => value
      None => 0
    }
    let order_value =
      if graphviz_flip {
        total_nodes - 1 - base_order
      } else {
        base_order
      }
    node_order[name] = order_value
  }
}

///|
/// Graphviz parity: intercluster keys mirror each node's local cluster
/// membership for compound edge ordering paths.
/// Do not change behavior without updating fixtures/tests.
fn build_intercluster_key_map(
  nodes : Array[@cgraph.Node],
) -> Map[String, String] {
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    intercluster_keys[node.name()] = @clustering.node_local_cluster_key(node)
  }
  intercluster_keys
}

///|
/// Graphviz parity: rank=same group/order metadata is collected once from graph
/// attributes before clustered reorder and flat-constraint wiring.
/// Do not change behavior without updating fixtures/tests.
fn collect_rank_same_metadata(
  graph : @cgraph.Graph,
) -> RankSameMetadata {
  let rank_same_groups : Map[String, Int] = Map::new()
  let rank_same_order : Map[String, Int] = Map::new()
  let _ = @ordering.collect_rank_same_order(graph, rank_same_groups, rank_same_order, 0)
  { rank_same_groups, rank_same_order }
}

///|
/// Graphviz parity: cluster metadata/order aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/compound.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_cluster_metadata(
  input : ClusterMetadataInput,
) -> ClusterMetadata {
  let graph = input.graph
  let nodes = input.nodes
  let edges = input.edges
  let groups = input.groups
  let ranks = input.ranks
  let node_order = input.node_order
  let edge_tail = input.edge_tail
  let edge_head = input.edge_head
  let has_clusters = @dot_shared.graph_has_cluster(graph)
  let cluster_keys = build_cluster_key_map(nodes)
  seed_cluster_node_order(nodes, cluster_keys, input.graphviz_flip, node_order)
  let cluster_skeleton = build_cluster_skeleton(groups, cluster_keys)
  // Graphviz parity: cluster rank bounds are collected from member node rank
  // and first appearance order before cluster-order base expansion.
  let cluster_rank_bounds =
    collect_cluster_rank_bounds(nodes, cluster_keys, ranks, node_order)
  let cluster_min_rank = cluster_rank_bounds.min_rank
  let cluster_max_rank = cluster_rank_bounds.max_rank
  let cluster_first_order = cluster_rank_bounds.first_order
  // Graphviz parity: cluster order and parent map are collected from
  // Graphviz cluster traversal before clustered ordering stages.
  let cluster_order : Array[String] = []
  @clustering.collect_cluster_names_order(graph, cluster_order)
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  @dot_shared.collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  apply_cluster_order_metadata(
    nodes,
    cluster_keys,
    cluster_min_rank,
    cluster_first_order,
    node_order,
  )
  let intercluster_keys = build_intercluster_key_map(nodes)
  let rank_same_metadata = collect_rank_same_metadata(graph)
  let rank_same_groups = rank_same_metadata.rank_same_groups
  let rank_same_order = rank_same_metadata.rank_same_order
  // Graphviz parity: flat ordering constraints include Graphviz ordering attrs
  // plus same-rank edge constraints before clustered reorder dispatch.
  let flat_constraints_output = @ordering.build_flat_constraints(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    cluster_keys,
  )
  let flat_constraints = flat_constraints_output.flat_constraints
  let ordering_set = flat_constraints_output.ordering_set
  promote_same_rank_edges_to_flat_constraints(edges, edge_tail, edge_head, ranks, flat_constraints)
  {
    has_clusters,
    cluster_keys,
    cluster_skeleton,
    cluster_min_rank,
    cluster_max_rank,
    cluster_order,
    cluster_parents,
    intercluster_keys,
    rank_same_groups,
    rank_same_order,
    flat_constraints,
    ordering_set,
  }
}
///|
/// Stage B rank stage file: orchestrator plus rank/height/cluster preprocessing
/// helpers.

///|
/// Graphviz parity: rank stage payload keeps Stage A-prepared inputs grouped
/// so Stage B wiring remains explicit and stable.
priv struct DotRankStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
}

///|
priv struct DotRankStageOutput {
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c), with typed stage inputs.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_rank_stage(
  input : DotRankStageInput,
) -> DotRankStageOutput {
  let graph = input.graph
  let prep = input.prep
  // Graphviz parity: rank-data creation remains first before downstream stage assembly.
  let rank_data =
    compute_rank_data(
      {
        graph,
        nodes: prep.nodes,
        edges: prep.edges,
        has_edge_labels: prep.has_edge_labels,
      },
    )
  // Graphviz parity: rank-height stage consumes computed ranks/groups
  // and spacing inputs with unchanged Graphviz argument wiring.
  let rank_heights =
    compute_rank_heights(
      {
        graph,
        edges: prep.edges,
        ranks: rank_data.ranks,
        groups: rank_data.groups,
        rank_keys: rank_data.rank_keys,
        all_ranks: rank_data.all_ranks,
        sizes: prep.sizes,
        self_edge_labels: rank_data.self_edge_labels,
        rankdir: prep.rankdir,
        nodesep_in: prep.nodesep_in,
        ranksep_in: prep.ranksep_in,
        has_edge_labels: prep.has_edge_labels,
      },
    )
  // Graphviz parity: cluster metadata in rank/order stage uses
  // the same rank-group and edge endpoint wiring as Graphviz ordering setup.
  let cluster_meta =
    compute_cluster_metadata(
      {
        graph,
        nodes: prep.nodes,
        edges: prep.edges,
        groups: rank_data.groups,
        ranks: rank_data.ranks,
        node_order: prep.node_order,
        edge_tail: rank_data.edge_tail,
        edge_head: rank_data.edge_head,
        graphviz_flip: prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL,
      },
    )
  // Graphviz parity: ordering/vnode stage consumes rank data, rank heights,
  // and cluster metadata with unchanged Graphviz call wiring.
  let ordering =
    compute_ordering_and_vnodes(
      {
        graph,
        nodes: prep.nodes,
        edges: prep.edges,
        edge_tail: rank_data.edge_tail,
        edge_head: rank_data.edge_head,
        edge_reversed: rank_data.edge_reversed,
        edge_out_order: rank_data.edge_out_order,
        ranks: rank_data.ranks,
        groups: rank_data.groups,
        rank_keys: rank_data.rank_keys,
        node_order: prep.node_order,
        order_sizes: prep.order_sizes,
        nodesep_pt: rank_heights.nodesep_pt,
        has_edge_labels: prep.has_edge_labels,
        rankdir: prep.rankdir,
        cluster_meta,
        port_order_positions: prep.port_order_positions,
        port_order_contrib: prep.port_order_contrib,
      },
    )
  // Graphviz parity: rank-stage result object keeps computed
  // rank/cluster/order artifacts unchanged.
  { rank_data, rank_heights, cluster_meta, ordering }
}
