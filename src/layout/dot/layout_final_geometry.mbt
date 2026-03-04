///|
/// Final geometry, subgraph bbox, and root cluster/port padding helpers.

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
priv struct FinalLayoutGeometry {
  final_nodes : Array[DotLayoutNode]
  final_edges : Array[DotLayoutEdge]
  rank_bbox : @geom.Rect
}

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn build_final_layout_geometry(
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> FinalLayoutGeometry {
  let base_bbox = compute_dot_bbox(
    nodes_out,
    all_ranks,
    sizes,
    rank_y,
    rank_ht1,
    rank_ht2,
  )
  { final_nodes: nodes_out, final_edges: edges_out, rank_bbox: base_bbox }
}

///|
/// Graphviz parity: cluster bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
priv struct SubgraphsAndBBox {
  subgraphs : Array[DotLayoutGraph]
  base_bbox : @geom.Rect
}

///|
/// Graphviz parity: cluster bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
fn build_subgraphs_and_bbox(
  graph : @cgraph.Graph,
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
  bbox : @geom.Rect,
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair],
  rankdir : RankDir,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> SubgraphsAndBBox {
  let subgraphs =
    layout_subgraphs(
      graph,
      nodes,
      edges,
      cluster_ln_x,
      cluster_rn_x,
      cluster_bbox_heights,
      rankdir,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
    )
  let expanded = if subgraphs.length() > 0 {
    expand_bbox_with_clusters(bbox, subgraphs)
  } else {
    bbox
  }
  { subgraphs, base_bbox: expanded }
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterPadding {
  root_cluster_pad_top : Double
  root_cluster_pad_bottom : Double
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn compute_root_cluster_padding(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  all_ranks : Array[Int],
  ranks : Map[String, Int],
) -> RootClusterPadding {
  if graph.is_root() && @dot_shared.graph_has_cluster(graph) && all_ranks.length() > 0 {
    let min_rank = all_ranks[0]
    let max_rank = all_ranks[all_ranks.length() - 1]
    let mut cluster_at_min = false
    let mut cluster_at_max = false
    for node in nodes {
      let cluster_key = node_local_cluster_key(node)
      if cluster_key == "" {
        continue
      }
      match ranks.get(node.name()) {
        Some(rank) => {
          if rank == min_rank {
            cluster_at_min = true
          }
          if rank == max_rank {
            cluster_at_max = true
          }
        }
        None => ()
      }
      if cluster_at_min && cluster_at_max {
        break
      }
    }
    let pad = cluster_margin_pt(graph)
    {
      root_cluster_pad_top: if cluster_at_min { pad } else { 0.0 },
      root_cluster_pad_bottom: if cluster_at_max { pad } else { 0.0 },
    }
  } else {
    { root_cluster_pad_top: 0.0, root_cluster_pad_bottom: 0.0 }
  }
}

///|
/// Graphviz parity: record port padding impact aligned to refs/graphviz/lib/dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn apply_root_port_padding(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
  port_pad_below : Double,
  port_pad_above : Double,
) -> @geom.Rect {
  if graph.is_root() && (rankdir == RankDir::TB || rankdir == RankDir::BT) {
    if port_pad_below > 0.0 || port_pad_above > 0.0 {
      {
        llx: bbox.llx,
        lly: bbox.lly - port_pad_below,
        urx: bbox.urx,
        ury: bbox.ury + port_pad_above,
      }
    } else {
      bbox
    }
  } else {
    bbox
  }
}
