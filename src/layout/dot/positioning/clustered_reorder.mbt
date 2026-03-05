///|
/// Graphviz parity: clustered xpos reorder pipeline input keeps seed material,
/// order-graph edge materialization data, and reorder constraints grouped for a
/// single clustered xpos pass.
pub struct ClusteredXposReorderInput {
  x_groups : Map[Int, Array[String]]
  x_order_sizes : Map[String, @shared.NodeSize]
  x_cluster_keys : Map[String, String]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  node_order : Map[String, Int]
  cluster_skeleton_size : @shared.NodeSize
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  cluster_skeleton_penalty : Int
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

/// Graphviz parity: clustered xpos reorder runs seed build, order-edge
/// materialization, and reorder_rank_groups in Graphviz-equivalent sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn build_clustered_xpos_groups(
  input : ClusteredXposReorderInput,
) -> Map[Int, Array[String]] {
  let reorder_seed_data =
    build_clustered_xpos_seed(
      {
        x_groups: input.x_groups,
        x_order_sizes: input.x_order_sizes,
        x_cluster_keys: input.x_cluster_keys,
        cluster_min_rank: input.cluster_min_rank,
        cluster_max_rank: input.cluster_max_rank,
        node_order: input.node_order,
        cluster_skeleton_size: input.cluster_skeleton_size,
      },
    )
  let reorder_edges_data =
    build_clustered_xpos_edges(
      {
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        ranks: input.ranks,
        edge_vnodes: input.edge_vnodes,
        order_nodes: reorder_seed_data.order_nodes,
        edge_tail_port_x: input.edge_tail_port_x,
        edge_head_port_x: input.edge_head_port_x,
        edge_tail_port_order: input.edge_tail_port_order,
        edge_head_port_order: input.edge_head_port_order,
        cluster_min_rank: input.cluster_min_rank,
        cluster_max_rank: input.cluster_max_rank,
        cluster_skeleton_penalty: input.cluster_skeleton_penalty,
      },
    )
  apply_clustered_xpos_reorder(
    {
      order_rank_keys: reorder_seed_data.order_rank_keys,
      order_groups: reorder_seed_data.order_groups,
      order_edges_out: reorder_edges_data.order_edges_out,
      order_edge_tail_out: reorder_edges_data.order_edge_tail_out,
      order_edge_head_out: reorder_edges_data.order_edge_head_out,
      order_edge_tail_port_x: reorder_edges_data.order_edge_tail_port_x,
      order_edge_head_port_x: reorder_edges_data.order_edge_head_port_x,
      order_edge_tail_port_order: reorder_edges_data.order_edge_tail_port_order,
      order_edge_head_port_order: reorder_edges_data.order_edge_head_port_order,
      order_nodes: reorder_seed_data.order_nodes,
      order_ranks: reorder_seed_data.order_ranks,
      order_cluster_keys: reorder_seed_data.order_cluster_keys,
      rank_same_groups: input.rank_same_groups,
      rank_same_order: input.rank_same_order,
      order_node_order: reorder_seed_data.order_node_order,
      order_sizes: reorder_seed_data.order_sizes,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      order_cluster_skeleton: reorder_seed_data.order_cluster_skeleton,
      flat_constraints: input.flat_constraints,
      graphviz_flip: input.graphviz_flip,
    },
  )
}

///|
/// Graphviz parity: clustered xpos reorder apply inputs keep order-graph edge
/// snapshots, rank metadata, and cluster constraints grouped for one
/// reorder_rank_groups invocation.
priv struct ClusteredXposReorderApplyInput {
  order_rank_keys : Array[Int]
  order_groups : Map[Int, Array[String]]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_nodes : Array[String]
  order_ranks : Map[String, Int]
  order_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  order_node_order : Map[String, Int]
  order_sizes : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  order_cluster_skeleton : Map[String, Bool]
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: clustered xpos reorder consumes order-graph
/// parents/children plus edge-order hints exactly once before
/// reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn apply_clustered_xpos_reorder(
  input : ClusteredXposReorderApplyInput,
) -> Map[Int, Array[String]] {
  let edge_index_data = @ordering.build_edge_index_for_names(
    input.order_nodes,
    input.order_edge_tail_out,
    input.order_edge_head_out,
    input.order_ranks,
  )
  let parents = edge_index_data.parents
  let children = edge_index_data.children
  let edge_order = @ordering.collect_edge_order(input.order_edges_out)
  @ordering.reorder_rank_groups(
    input.order_rank_keys,
    input.order_groups,
    input.order_edges_out,
    input.order_edge_tail_out,
    input.order_edge_head_out,
    input.order_edge_tail_port_x,
    input.order_edge_head_port_x,
    input.order_edge_tail_port_order,
    input.order_edge_head_port_order,
    parents,
    children,
    input.order_cluster_keys,
    input.rank_same_groups,
    input.rank_same_order,
    edge_order,
    input.order_node_order,
    input.order_sizes,
    input.nodesep_pt,
    input.has_edge_labels,
    Map::new(),
    Map::new(),
    Map::new(),
    input.order_cluster_skeleton,
    input.flat_constraints,
    graphviz_flip=input.graphviz_flip,
  )
}

///|
/// Clustered xpos seed/materialization internals are co-located with
/// clustered reorder orchestration for a single maintainability surface.

///|
/// Graphviz parity: clustered xpos reorder seed inputs keep x-order rank
/// groups, cluster bounds, and node-order seeds together before skeleton
/// injection and rank/order materialization.
priv struct ClusteredXposSeedInput {
  x_groups : Map[Int, Array[String]]
  x_order_sizes : Map[String, @shared.NodeSize]
  x_cluster_keys : Map[String, String]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  node_order : Map[String, Int]
  cluster_skeleton_size : @shared.NodeSize
}

///|
/// Graphviz parity: clustered xpos reorder seed output preserves the same
/// order-group/rank/node-order snapshots consumed by edge materialization and
/// reorder_rank_groups.
priv struct ClusteredXposSeedOutput {
  order_groups : Map[Int, Array[String]]
  order_sizes : Map[String, @shared.NodeSize]
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
  order_sizes : Map[String, @shared.NodeSize],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Unit {
  for cluster, min_rank in input.cluster_min_rank {
    let max_rank = input.cluster_max_rank.get(cluster).unwrap_or(min_rank)
    for rank in min_rank..=max_rank {
      let name = @clustering.cluster_skeleton_name(cluster, rank)
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
fn build_clustered_xpos_seed(
  input : ClusteredXposSeedInput,
) -> ClusteredXposSeedOutput {
  let order_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in input.x_groups {
    order_groups[rank] = names.copy()
  }
  let order_sizes : Map[String, @shared.NodeSize] = Map::new()
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

///|
/// Graphviz parity: clustered xpos edge materialization inputs keep order-graph
/// node set, expanded edge/vnode chains, and cluster skeleton range metadata
/// together before reorder_rank_groups.
priv struct ClusteredXposEdgeMaterializationInput {
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  order_nodes : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_skeleton_penalty : Int
}

///|
/// Graphviz parity: clustered xpos edge materialization output preserves edge
/// sequence and endpoint metadata arrays consumed by reorder_rank_groups.
priv struct ClusteredXposEdgeMaterializationOutput {
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
fn edge_name_at(names : Array[String], idx : Int, fallback : String) -> String {
  if idx < names.length() { names[idx] } else { fallback }
}

///|
fn edge_port_value_or_default(
  values : Array[Double],
  idx : Int,
  fallback : Double,
) -> Double {
  if idx < values.length() { values[idx] } else { fallback }
}

///|
fn build_xpos_chain_with_vnodes(
  ranks : Map[String, Int],
  tail : String,
  head : String,
  vnodes : Array[String],
) -> Array[String] {
  let tail_rank = ranks.get(tail).unwrap_or_default()
  let head_rank = ranks.get(head).unwrap_or_default()
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
fn append_xpos_chain_segments(
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
    let seg_tail_port = if chain[idx] == tail { tail_port_x } else { 0.0 }
    let seg_head_port = if chain[idx + 1] == head { head_port_x } else { 0.0 }
    let seg_tail_order =
      if chain[idx] == tail { tail_port_order } else { 0.5 }
    let seg_head_order =
      if chain[idx + 1] == head { head_port_order } else { 0.5 }
    @ordering.add_order_edge(
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
fn append_xpos_edge_with_vnodes(
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
    @ordering.add_order_edge(
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
    let chain = build_xpos_chain_with_vnodes(ranks, tail, head, vnodes)
    append_xpos_chain_segments(
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
fn append_clustered_input_edges(
  input : ClusteredXposEdgeMaterializationInput,
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> Unit {
  let mut edge_idx = 0
  for edge in input.edges {
    let tail = edge_name_at(input.edge_tail, edge_idx, edge.tail().name())
    let head = edge_name_at(input.edge_head, edge_idx, edge.head().name())
    let penalty = @shared.edge_xpenalty(edge)
    let constraint = @shared.edge_is_constraint(edge)
    let tail_port_x = edge_port_value_or_default(input.edge_tail_port_x, edge_idx, 0.0)
    let head_port_x = edge_port_value_or_default(input.edge_head_port_x, edge_idx, 0.0)
    let tail_port_order =
      edge_port_value_or_default(input.edge_tail_port_order, edge_idx, 0.5)
    let head_port_order =
      edge_port_value_or_default(input.edge_head_port_order, edge_idx, 0.5)
    let vnodes =
      input.edge_vnodes.get(@shared.edge_vnode_key(edge)).unwrap_or_default()
    append_xpos_edge_with_vnodes(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      input.ranks,
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
fn append_skeleton_edges(
  input : ClusteredXposEdgeMaterializationInput,
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> Unit {
  for cluster, min_rank in input.cluster_min_rank {
    let max_rank = input.cluster_max_rank.get(cluster).unwrap_or(min_rank)
    let mut rank = min_rank
    while rank < max_rank {
      let tail_name = @clustering.cluster_skeleton_name(cluster, rank)
      let head_name = @clustering.cluster_skeleton_name(cluster, rank + 1)
      @ordering.add_order_edge(
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
        input.cluster_skeleton_penalty,
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
/// Graphviz parity: clustered xpos reorder edge materialization preserves vnode
/// chain splitting and cluster skeleton linking before reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_edges(
  input : ClusteredXposEdgeMaterializationInput,
) -> ClusteredXposEdgeMaterializationOutput {
  let order_graph =
    @cgraph.Graph::new(@cgraph.GraphKind::Directed, name="xpos_order", strict=false)
  let order_node_map : Map[String, @cgraph.Node] = Map::new()
  for name in input.order_nodes {
    order_node_map[name] = order_graph.node(name)
  }
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  append_clustered_input_edges(
    input,
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
  append_skeleton_edges(
    input,
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
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
