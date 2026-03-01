///|
/// Stage D Phase D4 split: clustered x-constraint solve
/// helpers (seed/materialization/apply) for reorder flow.

///|
/// Graphviz parity: clustered xpos reorder seed skeleton injection appends
/// per-rank cluster skeleton vnodes before rank-order/index materialization.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_nodes_for_xpos_reorder_seed(
  order_groups : Map[Int, Array[String]],
  order_sizes : Map[String, NodeSize],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  cluster_meta : ClusterMetadata,
) -> Unit {
  // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
  let skeleton_size = vnode_size_from_widths(1.0, 1.0)
  for cluster, min_rank in cluster_meta.cluster_min_rank {
    let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
      Some(value) => value
      None => min_rank
    }
    for rank in min_rank..=max_rank {
      let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      order_cluster_keys[name] = cluster
      order_cluster_skeleton[name] = true
      order_sizes[name] = skeleton_size
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
fn build_clustered_xpos_reorder_seed_data(
  x_groups : Map[Int, Array[String]],
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  node_order : Map[String, Int],
) -> XposClusteredReorderSeedData {
  let order_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in x_groups {
    order_groups[rank] = names.copy()
  }
  let order_sizes : Map[String, NodeSize] = Map::new()
  for name, size in x_order_sizes {
    order_sizes[name] = size
  }
  let order_cluster_keys : Map[String, String] = Map::new()
  for name, key in x_cluster_keys {
    order_cluster_keys[name] = key
  }
  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  append_cluster_skeleton_nodes_for_xpos_reorder_seed(
    order_groups,
    order_sizes,
    order_cluster_keys,
    order_cluster_skeleton,
    cluster_meta,
  )
  let order_node_order : Map[String, Int] = Map::new()
  for name, value in node_order {
    order_node_order[name] = value
  }
  let order_index = build_order_index(order_groups)
  for name, idx in order_index {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let order_rank_keys = collect_rank_keys(order_groups)
  let order_ranks = build_node_ranks(order_groups)
  let order_nodes : Array[String] = []
  for rank in order_rank_keys {
    let names = match order_groups.get(rank) {
      Some(list) => list
      None => []
    }
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

///|
/// Graphviz parity: clustered xpos reorder vnode chain direction follows
/// rank order (forward/reverse) before segment emission.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_reorder_edge_chain_with_vnodes(
  ranks : Map[String, Int],
  tail : String,
  head : String,
  vnodes : Array[String],
) -> Array[String] {
  let tail_rank = match ranks.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_rank = match ranks.get(head) {
    Some(value) => value
    None => 0
  }
  let chain : Array[String] = []
  chain.push(tail)
  if tail_rank <= head_rank {
    for vnode in vnodes {
      chain.push(vnode)
    }
  } else {
    let mut i = vnodes.length()
    while i > 0 {
      i = i - 1
      chain.push(vnodes[i])
    }
  }
  chain.push(head)
  chain
}

///|
/// Graphviz parity: clustered xpos reorder emits chain segments with
/// endpoint port hints and midpoint-neutral port-order values.
/// Do not change behavior without updating fixtures/tests.
fn append_clustered_xpos_reorder_edge_chain_segments(
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  chain : Array[String],
  tail : String,
  head : String,
  penalty : Int,
  constraint : Bool,
  tail_port_x : Double,
  head_port_x : Double,
  tail_port_order : Double,
  head_port_order : Double,
) -> Unit {
  let mut idx = 0
  while idx + 1 < chain.length() {
    let seg_tail_port =
      if chain[idx] == tail { tail_port_x } else { 0.0 }
    let seg_head_port =
      if chain[idx + 1] == head { head_port_x } else { 0.0 }
    // Graphviz parity: split edge segments keep neutral midpoint
    // port-order (0.5) unless endpoint matches real tail/head.
    let seg_tail_order =
      if chain[idx] == tail { tail_port_order } else { 0.5 }
    let seg_head_order =
      if chain[idx + 1] == head { head_port_order } else { 0.5 }
    add_order_edge(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      chain[idx],
      chain[idx + 1],
      penalty,
      constraint,
      seg_tail_port,
      seg_head_port,
      seg_tail_order,
      seg_head_order,
    )
    idx = idx + 1
  }
}

///|
/// Graphviz parity: clustered xpos reorder expands vnode edge chains
/// into order-graph segments while preserving endpoint port hints.
/// Do not change behavior without updating fixtures/tests.
fn append_clustered_xpos_reorder_edge_with_vnodes(
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  tail : String,
  head : String,
  penalty : Int,
  constraint : Bool,
  tail_port_x : Double,
  head_port_x : Double,
  tail_port_order : Double,
  head_port_order : Double,
  vnodes : Array[String],
) -> Unit {
  if vnodes.length() == 0 {
    add_order_edge(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      tail,
      head,
      penalty,
      constraint,
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
    )
  } else {
    let chain = build_clustered_xpos_reorder_edge_chain_with_vnodes(
      ranks,
      tail,
      head,
      vnodes,
    )
    append_clustered_xpos_reorder_edge_chain_segments(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      chain,
      tail,
      head,
      penalty,
      constraint,
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
    )
  }
}

///|
/// Graphviz parity: clustered xpos reorder appends cluster skeleton chain
/// edges between consecutive cluster ranks with CL_CROSS penalty.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_edges_for_xpos_reorder(
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Unit {
  for cluster, min_rank in cluster_min_rank {
    let max_rank = match cluster_max_rank.get(cluster) {
      Some(value) => value
      None => min_rank
    }
    let mut rank = min_rank
    while rank < max_rank {
      let tail_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      let head_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank + 1}"
      add_order_edge(
        order_graph,
        order_node_map,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_edge_tail_port_x,
        order_edge_head_port_x,
        order_edge_tail_port_order,
        order_edge_head_port_order,
        tail_name,
        head_name,
        CL_CROSS,
        true,
        0.0,
        0.0,
        0.5,
        0.5,
      )
      rank = rank + 1
    }
  }
}

///|
/// Graphviz parity: clustered xpos reorder first materializes input
/// edges in Graphviz iteration order before appending cluster skeleton edges.
/// Do not change behavior without updating fixtures/tests.
fn append_clustered_xpos_reorder_input_edges(
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
) -> Unit {
  let mut edge_idx = 0
  for edge in prep.edges {
    let tail =
      if edge_idx < rank_data.edge_tail.length() { rank_data.edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < rank_data.edge_head.length() { rank_data.edge_head[edge_idx] } else {
        edge.head().name()
      }
    let penalty = @dot_shared.edge_xpenalty(edge)
    let constraint = @dot_shared.edge_is_constraint(edge)
    let tail_port_x =
      if edge_idx < x_edge_tail_port_x.length() { x_edge_tail_port_x[edge_idx] } else {
        0.0
      }
    let head_port_x =
      if edge_idx < x_edge_head_port_x.length() { x_edge_head_port_x[edge_idx] } else {
        0.0
      }
    let tail_port_order =
      if edge_idx < x_edge_tail_port_order.length() { x_edge_tail_port_order[edge_idx] } else {
        0.5
      }
    let head_port_order =
      if edge_idx < x_edge_head_port_order.length() { x_edge_head_port_order[edge_idx] } else {
        0.5
      }
    let vnodes = match ordering.vnode_info.edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    append_clustered_xpos_reorder_edge_with_vnodes(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      rank_data.ranks,
      tail,
      head,
      penalty,
      constraint,
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
      vnodes,
    )
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: clustered xpos reorder edge materialization preserves
/// vnode chain splitting and cluster skeleton linking before reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_reorder_edges(
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  cluster_meta : ClusterMetadata,
  order_nodes : Array[String],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
) -> XposClusteredReorderEdgesData {
  let order_graph =
    @cgraph.Graph::new(@cgraph.GraphKind::Directed, name="xpos_order", strict=false)
  let order_node_map : Map[String, @cgraph.Node] = Map::new()
  for name in order_nodes {
    order_node_map[name] = order_graph.node(name)
  }
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  append_clustered_xpos_reorder_input_edges(
    prep,
    rank_data,
    ordering,
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
  )
  append_cluster_skeleton_edges_for_xpos_reorder(
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    cluster_meta.cluster_min_rank,
    cluster_meta.cluster_max_rank,
  )
  {
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}

///|
/// Graphviz parity: clustered xpos reorder consumes order-graph parents/children
/// plus edge-order hints exactly once before reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn apply_clustered_xpos_reorder_rank_groups(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_nodes : Array[String],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  order_cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let (parents, children) = build_edge_index_for_order_names(
    order_nodes,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
  )
  let edge_order = collect_edge_order(order_edges_out)
  // Graphviz parity: xpos reorder uses the same edge-segment port-order hints
  // computed for the order graph (mincross median tie-breaking path).
  reorder_rank_groups(
    order_rank_keys,
    order_groups,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    parents,
    children,
    order_cluster_keys,
    rank_same_groups,
    rank_same_order,
    edge_order,
    order_node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    Map::new(),
    Map::new(),
    Map::new(),
    order_cluster_skeleton,
    flat_constraints,
    graphviz_flip=graphviz_flip,
  )
}

///|
/// Graphviz parity: clustered xpos reorder branch keeps the same seed build,
/// edge materialization, and reorder_rank_groups invocation sequence as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_reordered_groups(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_groups : Map[Int, Array[String]],
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let reorder_seed_data =
    build_clustered_xpos_reorder_seed_data(
      x_groups,
      x_order_sizes,
      x_cluster_keys,
      cluster_meta,
      prep.node_order,
    )
  let reorder_edges_data =
    build_clustered_xpos_reorder_edges(
      prep,
      rank_data,
      ordering,
      cluster_meta,
      reorder_seed_data.order_nodes,
      x_edge_tail_port_x,
      x_edge_head_port_x,
      x_edge_tail_port_order,
      x_edge_head_port_order,
    )
  apply_clustered_xpos_reorder_rank_groups(
    reorder_seed_data.order_rank_keys,
    reorder_seed_data.order_groups,
    reorder_edges_data.order_edges_out,
    reorder_edges_data.order_edge_tail_out,
    reorder_edges_data.order_edge_head_out,
    reorder_edges_data.order_edge_tail_port_x,
    reorder_edges_data.order_edge_head_port_x,
    reorder_edges_data.order_edge_tail_port_order,
    reorder_edges_data.order_edge_head_port_order,
    reorder_seed_data.order_nodes,
    reorder_seed_data.order_ranks,
    reorder_seed_data.order_cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    reorder_seed_data.order_node_order,
    reorder_seed_data.order_sizes,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    reorder_seed_data.order_cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_flip,
  )
}
