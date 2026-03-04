///|
/// Graphviz parity: clustered xpos edge materialization inputs keep order-graph
/// node set, expanded edge/vnode chains, and cluster skeleton range metadata
/// together before reorder_rank_groups.
pub struct ClusteredXposEdgeMaterializationInput {
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
  cluster_skeleton_prefix : String
  cluster_skeleton_penalty : Int
}

///|
pub fn build_clustered_xpos_edge_materialization_input(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_nodes : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  cluster_skeleton_prefix : String,
  cluster_skeleton_penalty : Int,
) -> ClusteredXposEdgeMaterializationInput {
  {
    edges,
    edge_tail,
    edge_head,
    ranks,
    edge_vnodes,
    order_nodes,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    cluster_min_rank,
    cluster_max_rank,
    cluster_skeleton_prefix,
    cluster_skeleton_penalty,
  }
}

///|
/// Graphviz parity: clustered xpos edge materialization output preserves edge
/// sequence and endpoint metadata arrays consumed by reorder_rank_groups.
pub struct ClusteredXposEdgeMaterializationOutput {
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
      let tail_name = "\{input.cluster_skeleton_prefix}\{cluster}@\{rank}"
      let head_name = "\{input.cluster_skeleton_prefix}\{cluster}@\{rank + 1}"
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
pub fn build_clustered_xpos_edges(
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
