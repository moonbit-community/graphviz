///|
/// Exterior edge-label nudge heuristic (DOT_ADJUST_EDGE_LABELS only).
fn adjust_edge_labels_if_enabled(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  if edge_label_adjust_enabled() {
    let adjusted_for_clusters =
      adjust_labels_for_clusters(layout, nodesep_pt)
    adjust_labels_for_overlaps(
      adjusted_for_clusters,
      nodesep_pt,
      rankdir,
    )
  } else {
    layout
  }
}

///|
/// Graphviz parity: postprocess pipeline aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess) + dotgen/position.c (cluster/label spacing).
/// Do not change behavior without updating fixtures/tests.
fn finalize_layout_graph(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
  rankdir : RankDir,
  splines : SplinesMode,
  all_ranks : Array[Int],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  nodesep_pt : Double,
  port_pad_below : Double,
  port_pad_above : Double,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutGraph {
  let final_geometry =
    build_final_layout_geometry(
      nodes_out,
      edges_out,
      all_ranks,
      sizes,
      rank_y,
      rank_ht1,
      rank_ht2,
    )
  let subgraphs_and_bbox =
    build_subgraphs_and_bbox(
      graph,
      final_geometry.final_nodes,
      final_geometry.final_edges,
      final_geometry.rank_bbox,
      cluster_ln_x,
      cluster_rn_x,
      cluster_bbox_heights,
      rankdir,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
    )
  let root_cluster_padding =
    compute_root_cluster_padding(graph, nodes, all_ranks, ranks)
  // Graphviz parity: rankdir=BT flips top/bottom cluster padding (ranks are inverted).
  let (root_cluster_pad_top, root_cluster_pad_bottom) =
    if rankdir == RankDir::BT {
      (
        root_cluster_padding.root_cluster_pad_bottom,
        root_cluster_padding.root_cluster_pad_top,
      )
    } else {
      (
        root_cluster_padding.root_cluster_pad_top,
        root_cluster_padding.root_cluster_pad_bottom,
      )
    }
  let bbox =
    apply_root_port_padding(
      graph,
      subgraphs_and_bbox.base_bbox,
      rankdir,
      port_pad_below,
      port_pad_above,
    )
  let layout_with_root_pad =
    apply_root_cluster_padding(
      graph,
      {
        graph,
        bbox,
        label_pos: None,
        nodes: final_geometry.final_nodes,
        edges: final_geometry.final_edges,
        subgraphs: subgraphs_and_bbox.subgraphs,
      },
      root_cluster_pad_top,
      root_cluster_pad_bottom,
    )
  // Graphviz parity: ratio=fill uses pre-spline bbox; include rank/cluster
  // padding that is part of set_ycoords before final edge bbox expansion.
  let ratio_bbox = layout_with_root_pad.bbox
  // Graphviz parity: edge splines update bbox after dot_compute_bb (dotsplines.c).
  let bbox =
    expand_bbox_with_edges(layout_with_root_pad.bbox, layout_with_root_pad.edges)
  let layout = {
    graph: layout_with_root_pad.graph,
    bbox,
    label_pos: layout_with_root_pad.label_pos,
    nodes: layout_with_root_pad.nodes,
    edges: layout_with_root_pad.edges,
    subgraphs: layout_with_root_pad.subgraphs,
  }
  let layout =
    apply_ratio_fill_scale(graph, layout, rankdir, ratio_bbox)
  let adjusted = adjust_edge_labels_if_enabled(layout, nodesep_pt, rankdir)
  let labeled =
    expand_bbox_for_edge_labels(
      graph,
      adjusted,
      ranks,
      flat_label_edge_vnodes,
    )
  let with_xlabels = apply_xlabels(graph, labeled, splines)
  let root_label_bbox =
    apply_root_label_bbox(graph, with_xlabels.bbox, rankdir)
  let labeled_with_root = {
    graph: with_xlabels.graph,
    bbox: root_label_bbox.bbox,
    label_pos: root_label_bbox.label_pos,
    nodes: with_xlabels.nodes,
    edges: with_xlabels.edges,
    subgraphs: with_xlabels.subgraphs,
  }
  let rotated = if rankdir == RankDir::TB {
    labeled_with_root
  } else {
    rotate_layout_graph(labeled_with_root, labeled_with_root.bbox, rankdir)
  }
  let cluster_mirror_bbox =
    transform_bbox_with_root(final_geometry.rank_bbox, labeled_with_root.bbox, rankdir)
  let use_cluster_point_mirror =
    subgraphs_and_bbox.base_bbox.urx > final_geometry.rank_bbox.urx &&
    (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(graph)
  let use_lr_multi_cluster_creation_order_mode =
    (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    count_cluster_subgraphs(graph) > 1
  // Graphviz parity: clustered LR/RL layouts are mirrored back after rankdir
  // rotation (dotgen cluster decompose + postproc map_point ordering).
  let rotated = if (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(graph) &&
    !use_lr_multi_cluster_creation_order_mode {
    if use_cluster_point_mirror {
      refresh_cluster_labels(
        mirror_layout_points(
          rotated,
          cluster_mirror_bbox,
          rotated.bbox,
        ),
      )
    } else {
      rotate_layout_graph(rotated, rotated.bbox, RankDir::BT)
    }
  } else {
    rotated
  }
  let rotated_with_margin = {
    graph: rotated.graph,
    bbox: apply_root_margin_x(graph, rotated.bbox),
    label_pos: rotated.label_pos,
    nodes: rotated.nodes,
    edges: rotated.edges,
    subgraphs: rotated.subgraphs,
  }
  refresh_root_label_position(
    shift_layout_to_origin(graph, rotated_with_margin),
  )
}
