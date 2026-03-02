///|
/// Stage C Phase C2 split: non-cluster rank-reorder
/// helpers isolated from clustered ordering branches.

///|
priv struct GraphvizNeighborMaps {
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
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
      let head =
        if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
          edges[edge_idx].head().name()
        }
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
/// builds Graphviz-style ND_out/ND_in neighbor order, and runs rank reorder
/// without cluster remapping.
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_reorder_pass(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  nlist_order : Array[String],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  // Graphviz parity: non-cluster reorder seeds build_ranks node order from
  // GD_nlist, then falls back to existing node order for missing nodes.
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
  let edge_index_data =
    build_edge_index_for_order(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
    )
  let parents = edge_index_data.parents
  let children = edge_index_data.children
  let graphviz_neighbors =
    build_noncluster_graphviz_neighbors(
      nodes,
      edges,
      edge_head,
      edge_out_order,
    )
  let graphviz_out_neighbors = graphviz_neighbors.out_neighbors
  let graphviz_in_neighbors = graphviz_neighbors.in_neighbors
  reorder_rank_groups(
    rank_keys,
    groups,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    parents,
    children,
    cluster_meta.cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    edge_order,
    order_node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    cluster_meta.cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
    graphviz_flip=graphviz_flip,
  )
}
