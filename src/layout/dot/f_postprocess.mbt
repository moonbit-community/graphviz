///|
priv struct ClusterLabelPlacementInfo {
  width_pt : Double
  height_pt : Double
  loc : LabelLoc
  just : LabelJust
  flipped : Bool
}

///|
/// Graphviz parity: cluster bbox + label placement aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + lib/common/input.c (cluster label borders) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
fn layout_subgraphs(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair],
  rankdir : RankDir,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Array[DotLayoutGraph] {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let result : Array[DotLayoutGraph] = []
  for subgraph in graph.subgraphs() {
    let node_set : Map[String, Bool] = Map::new()
    for node in subgraph.nodes() {
      if graph_contains_node(subgraph, node) {
        node_set[node.name()] = true
      }
    }
    let edge_set : Map[String, Bool] = Map::new()
    for edge in subgraph.edges() {
      edge_set[@dot_shared.edge_key(edge)] = true
    }
    let sub_nodes : Array[DotLayoutNode] = []
    for node_layout in nodes_out {
      if node_set.get(node_layout.node.name()) is Some(_) {
        sub_nodes.push(node_layout)
      }
    }
    let sub_edges : Array[DotLayoutEdge] = []
    for edge_layout in edges_out {
      if edge_set.get(@dot_shared.edge_key(edge_layout.edge)) is Some(_) {
        let tail_name = edge_layout.edge.tail().name()
        let head_name = edge_layout.edge.head().name()
        if node_set.get(tail_name) is Some(_) &&
          node_set.get(head_name) is Some(_) {
          sub_edges.push(edge_layout)
        }
      }
    }
    let mut bbox = compute_bbox(sub_nodes, sub_edges)
    let mut label_pos : @geom.Point? = None
    let mut label_info : ClusterLabelPlacementInfo? = None
    let sub_subgraphs =
      layout_subgraphs(
        subgraph,
        nodes_out,
        edges_out,
        cluster_ln_x,
        cluster_rn_x,
        cluster_bbox_heights,
        rankdir,
        ranks,
        rank_y,
        rank_ht1,
        rank_ht2,
      )
    if @dot_shared.is_cluster_graph(subgraph) {
      // Graphviz parity: empty clusters (no descendant nodes) are omitted.
      let cluster_nodes : Map[String, Bool] = Map::new()
      @dot_shared.collect_graph_nodes(subgraph, cluster_nodes)
      if cluster_nodes.length() == 0 {
        continue
      }
    }
    if sub_subgraphs.length() > 0 {
      bbox = expand_bbox_with_subgraphs(bbox, sub_subgraphs)
    }
    if @dot_shared.is_cluster_graph(subgraph) {
      let pad = cluster_margin_pt(subgraph)
      let mut pad_left = pad
      let mut pad_right = pad
      let mut pad_y = pad
      let mut use_rank_bbox = false
      // Graphviz parity: cluster y bounds come from rank positions (dot_compute_bb).
      let mut min_rank : Int? = None
      let mut max_rank : Int? = None
      let cluster_nodes : Map[String, Bool] = Map::new()
      @dot_shared.collect_graph_nodes(subgraph, cluster_nodes)
      for name, _ in cluster_nodes {
        match ranks.get(name) {
          Some(rank) => {
            match min_rank {
              Some(value) => if rank < value { min_rank = Some(rank) }
              None => min_rank = Some(rank)
            }
            match max_rank {
              Some(value) => if rank > value { max_rank = Some(rank) }
              None => max_rank = Some(rank)
            }
          }
          None => ()
        }
      }
      match (min_rank, max_rank) {
        (Some(min_rank_value), Some(max_rank_value)) => {
          let max_rank_y = match rank_y.get(max_rank_value) {
            Some(value) => value
            None => bbox.lly
          }
          let min_rank_y = match rank_y.get(min_rank_value) {
            Some(value) => value
            None => bbox.ury
          }
          let mut ht1 = match rank_ht1.get(max_rank_value) {
            Some(value) => value
            None => 0.0
          }
          let mut ht2 = match rank_ht2.get(min_rank_value) {
            Some(value) => value
            None => 0.0
          }
          match subgraph.name() {
            Some(cluster_name) =>
              match cluster_bbox_heights.get(cluster_name) {
                Some(value) => {
                  ht1 = value.ht1
                  ht2 = value.ht2
                }
                None => ()
              }
            None => ()
          }
          bbox =
            { llx: bbox.llx, lly: max_rank_y - ht1, urx: bbox.urx, ury: min_rank_y + ht2 }
          pad_y = 0.0
          use_rank_bbox = true
        }
        _ => ()
      }
      // Graphviz parity: cluster x bounds come from ln/rn positions (dot_compute_bb).
      match subgraph.name() {
        Some(cluster_name) => {
          match cluster_ln_x.get(cluster_name) {
            Some(value) => {
              bbox = { llx: value, lly: bbox.lly, urx: bbox.urx, ury: bbox.ury }
              pad_left = 0.0
            }
            None => ()
          }
          match cluster_rn_x.get(cluster_name) {
            Some(value) => {
              bbox = { llx: bbox.llx, lly: bbox.lly, urx: value, ury: bbox.ury }
              pad_right = 0.0
            }
            None => ()
          }
        }
        None => ()
      }
      let llx = bbox.llx - pad_left
      let lly = bbox.lly - pad_y
      let urx = bbox.urx + pad_right
      let ury = bbox.ury + pad_y
      bbox = { llx, lly, urx, ury }
      match graph_label_metrics(subgraph) {
        Some(metrics) => {
          let loc = graph_label_loc(subgraph)
          let just = graph_label_just(subgraph)
          let pad = CLUSTER_LABEL_PAD_PT
          let padded_width = metrics.width_pt + pad * 2.0
          let padded_height = metrics.height_pt + pad
          if flip {
            let border_x = padded_height
            let border_y = padded_width
            let mut llx = bbox.llx
            let mut urx = bbox.urx
            let mut lly = bbox.lly
            let mut ury = bbox.ury
            if !use_rank_bbox {
              match loc {
                LabelLoc::Top => urx = urx + border_x
                LabelLoc::Bottom => llx = llx - border_x
              }
            }
            let span = ury - lly
            if border_y > span {
              let diff = (border_y - span) / 2.0
              lly = lly - diff
              ury = ury + diff
            }
            bbox = { llx, lly, urx, ury }
            label_info = Some({
              width_pt: border_x,
              height_pt: border_y,
              loc,
              just,
              flipped: true,
            })
          } else {
            if !use_rank_bbox {
              bbox =
                expand_bbox_for_label(
                  bbox,
                  metrics.width_pt,
                  metrics.height_pt,
                  loc,
                )
            }
            label_info = Some({
              width_pt: padded_width,
              height_pt: padded_height,
              loc,
              just,
              flipped: false,
            })
          }
        }
        None => ()
      }
      bbox = round_bbox(bbox)
    }
    match label_info {
      Some(value) =>
        label_pos =
          Some(
            if value.flipped {
              graph_label_pos_flip(
                bbox,
                value.width_pt,
                value.height_pt,
                value.loc,
                value.just,
              )
            } else {
              graph_label_pos(
                bbox,
                value.width_pt,
                value.height_pt,
                value.loc,
                value.just,
              )
            },
          )
      None => ()
    }
    result.push({
      graph: subgraph,
      bbox,
      label_pos,
      nodes: sub_nodes,
      edges: sub_edges,
      subgraphs: sub_subgraphs,
    })
  }
  result
}

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
