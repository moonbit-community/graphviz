///|
/// Ordering domain: non-cluster rank-reorder helpers shared by Stage C
/// dispatch without cluster-specific root/mincross materialization.

///|
priv struct GraphvizNeighborMaps {
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
}

///|
/// Graphviz parity: non-cluster reorder input bundle keeps order-edge
/// materialization, rank groups, node-order seed sources, and graph metadata
/// unchanged before reorder_rank_groups dispatch.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct NonclusterReorderInputs {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  nlist_order : Array[String]
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_order : Map[String, Int]
  order_sizes : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: non-cluster reorder input-source bundle keeps dispatch
/// snapshots paired with class2/edge-port setup outputs before call assembly.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct NonclusterReorderInputsBuildSources {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  order_sizes : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  flat_constraints : Map[String, Bool]
  reorder_setup : OrderingReorderSetup
  edge_port_data : OrderingEdgePortData
}

///|
/// Graphviz parity: non-cluster reorder call payload is assembled from one
/// dispatch snapshot plus reorder-setup and edge-port materialization outputs.
/// Do not change behavior without updating fixtures/tests.
pub fn build_noncluster_reorder_inputs_from_sources(
  sources : NonclusterReorderInputsBuildSources,
) -> NonclusterReorderInputs {
  {
    nodes: sources.nodes,
    edges: sources.edges,
    edge_head: sources.edge_head,
    edge_out_order: sources.edge_out_order,
    ranks: sources.ranks,
    rank_keys: sources.rank_keys,
    groups: sources.groups,
    nlist_order: sources.reorder_setup.class2_data.nlist_order,
    node_order: sources.node_order,
    order_edges: sources.edge_port_data.order_edges,
    order_edge_tail: sources.edge_port_data.order_edge_tail,
    order_edge_head: sources.edge_port_data.order_edge_head,
    order_edge_tail_port_x: sources.edge_port_data.order_edge_tail_port_x,
    order_edge_head_port_x: sources.edge_port_data.order_edge_head_port_x,
    order_edge_tail_port_order: sources.edge_port_data.order_edge_tail_port_order,
    order_edge_head_port_order: sources.edge_port_data.order_edge_head_port_order,
    cluster_keys: sources.cluster_keys,
    cluster_skeleton: sources.cluster_skeleton,
    rank_same_groups: sources.rank_same_groups,
    rank_same_order: sources.rank_same_order,
    edge_order: sources.edge_port_data.edge_order,
    order_sizes: sources.order_sizes,
    nodesep_pt: sources.nodesep_pt,
    has_edge_labels: sources.has_edge_labels,
    port_order_positions: sources.port_order_positions,
    port_order_contrib: sources.port_order_contrib,
    flat_constraints: sources.flat_constraints,
    graphviz_flip: sources.reorder_setup.graphviz_flip,
  }
}

///|
/// Graphviz parity: non-cluster reorder call payload preserves exact
/// reorder_rank_groups argument order and precomputed graphviz neighbors.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct NonclusterRankReorderInputs {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_order : Map[String, Int]
  order_node_order : Map[String, Int]
  order_sizes : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_skeleton : Map[String, Bool]
  flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: non-cluster ND_order seed starts from GD_nlist order and
/// then fills any missing names using existing node-order values.
fn build_noncluster_order_node_order(
  nlist_order : Array[String],
  node_order : Map[String, Int],
) -> Map[String, Int] {
  let order_node_order : Map[String, Int] = Map::new()
  let mut order_idx = 0
  for name in nlist_order {
    order_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  for name, idx in node_order {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  order_node_order
}

///|
/// Graphviz parity: non-cluster neighbor maps preserve ND_out tail order from
/// edge_out_order and ND_in head order from node-ordered ND_out scans.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_graphviz_neighbors(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
) -> GraphvizNeighborMaps {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  let node_names : Array[String] = []
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    node_names.push(name)
    graphviz_out_neighbors[name] = []
    graphviz_in_neighbors[name] = []
  }
  for name, list in edge_out_order {
    let heads : Array[String] = []
    for edge_idx in list {
      let head = edge_head_at(edges[edge_idx], edge_idx, edge_head)
      heads.push(head)
    }
    graphviz_out_neighbors[name] = heads
  }
  // Graphviz parity: non-cluster ND_in neighbor order follows ND_out traversal
  // in graph node iteration order (agfstnode/agnxtnode), matching add_fast_edges.
  let in_entries : Map[String, Array[String]] = Map::new()
  for tail in node_names {
    let heads = graphviz_out_neighbors.get(tail).unwrap_or_default()
    for head in heads {
      match in_entries.get(head) {
        Some(list) => list.push(tail)
        None => in_entries[head] = [tail]
      }
    }
  }
  for head, entries in in_entries {
    graphviz_in_neighbors[head] = entries
  }
  {
    out_neighbors: graphviz_out_neighbors,
    in_neighbors: graphviz_in_neighbors,
  }
}

///|
/// Graphviz parity: non-cluster reorder path seeds node order from GD_nlist,
/// builds Graphviz-style ND_out/ND_in neighbor order, and delegates one
/// reorder_rank_groups call with unchanged argument wiring.
/// Do not change behavior without updating fixtures/tests.
pub fn run_noncluster_reorder_pass(
  inputs : NonclusterReorderInputs,
) -> Map[Int, Array[String]] {
  let order_node_order =
    build_noncluster_order_node_order(inputs.nlist_order, inputs.node_order)
  let edge_index_data =
    build_edge_index_for_order(
      inputs.nodes,
      inputs.order_edges,
      inputs.order_edge_tail,
      inputs.order_edge_head,
      inputs.ranks,
    )
  let graphviz_neighbors =
    build_noncluster_graphviz_neighbors(
      inputs.nodes,
      inputs.edges,
      inputs.edge_head,
      inputs.edge_out_order,
    )
  let call_inputs : NonclusterRankReorderInputs =
    {
      rank_keys: inputs.rank_keys,
      groups: inputs.groups,
      order_edges: inputs.order_edges,
      order_edge_tail: inputs.order_edge_tail,
      order_edge_head: inputs.order_edge_head,
      order_edge_tail_port_x: inputs.order_edge_tail_port_x,
      order_edge_head_port_x: inputs.order_edge_head_port_x,
      order_edge_tail_port_order: inputs.order_edge_tail_port_order,
      order_edge_head_port_order: inputs.order_edge_head_port_order,
      parents: edge_index_data.parents,
      children: edge_index_data.children,
      cluster_keys: inputs.cluster_keys,
      rank_same_groups: inputs.rank_same_groups,
      rank_same_order: inputs.rank_same_order,
      edge_order: inputs.edge_order,
      order_node_order,
      order_sizes: inputs.order_sizes,
      nodesep_pt: inputs.nodesep_pt,
      has_edge_labels: inputs.has_edge_labels,
      port_order_positions: inputs.port_order_positions,
      port_order_contrib: inputs.port_order_contrib,
      cluster_skeleton: inputs.cluster_skeleton,
      flat_constraints: inputs.flat_constraints,
      graphviz_out_neighbors: graphviz_neighbors.out_neighbors,
      graphviz_in_neighbors: graphviz_neighbors.in_neighbors,
      graphviz_flip: inputs.graphviz_flip,
    }
  run_noncluster_rank_reorder(call_inputs)
}
