///|
/// Stage F finalization stage file: postprocess payload + pre/post-rotation
/// finalize pipeline helpers.

///|
/// Graphviz parity: final postprocess payload keeps stage outputs and layout
/// options grouped so finalize pipeline wiring remains explicit and stable.
priv struct FinalizeLayoutInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  rankdir : RankDir
  splines : SplinesMode
  all_ranks : Array[Int]
  ranks : Map[String, Int]
  sizes : Map[String, NodeSize]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  nodesep_pt : Double
  port_pad_below : Double
  port_pad_above : Double
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Graphviz parity: Stage F source payload keeps upstream stage outputs grouped
/// so final postprocess input assembly stays explicit and stable.
priv struct FinalizeLayoutBuildSources {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  positions_state : PositionResult
  routing_stage_output : DotRoutingStageOutput
}

///|
/// Graphviz parity: Stage F input assembly keeps Stage A-E outputs mapped in
/// one deterministic projection before finalize layout postprocess.
/// Do not change behavior without updating fixtures/tests.
fn build_finalize_layout_input_from_sources(
  sources : FinalizeLayoutBuildSources,
) -> FinalizeLayoutInput {
  {
    graph: sources.graph,
    nodes: sources.prep.nodes,
    nodes_out: sources.routing_stage_output.nodes_out,
    edges_out: sources.routing_stage_output.edges_out,
    rankdir: sources.prep.rankdir,
    splines: sources.prep.splines,
    all_ranks: sources.rank_data.all_ranks,
    ranks: sources.rank_data.ranks,
    sizes: sources.prep.sizes,
    cluster_ln_x: sources.positions_state.cluster_ln_x,
    cluster_rn_x: sources.positions_state.cluster_rn_x,
    cluster_bbox_heights: sources.positions_state.cluster_bbox_heights,
    rank_y: sources.positions_state.rank_y,
    rank_ht1: sources.positions_state.rank_ht1,
    rank_ht2: sources.positions_state.rank_ht2,
    nodesep_pt: sources.rank_heights.nodesep_pt,
    port_pad_below: sources.routing_stage_output.port_pad_below,
    port_pad_above: sources.routing_stage_output.port_pad_above,
    flat_label_edge_vnodes: sources.positions_state.flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: pre-rotation assembly keeps dot_compute_bb + label/ratio
/// interactions in one place before rankdir transforms are applied.
/// Do not change behavior without updating fixtures/tests.
priv struct PreRotationLayoutData {
  layout : DotLayoutGraph
  rank_bbox : @geom.Rect
  subgraph_base_bbox : @geom.Rect
}

///|
priv struct RootPaddedLayoutData {
  layout_with_root_pad : DotLayoutGraph
  ratio_bbox : @geom.Rect
}

///|
/// Graphviz parity: root port padding + root cluster padding are assembled in
/// pre-rotation dot coordinates before ratio/label postprocessing.
/// Do not change behavior without updating fixtures/tests.
fn build_root_padded_layout_data(
  input : FinalizeLayoutInput,
  final_geometry : FinalLayoutGeometry,
  subgraphs_and_bbox : SubgraphsAndBBox,
) -> RootPaddedLayoutData {
  let graph = input.graph
  let rankdir = input.rankdir
  let (root_cluster_pad_top, root_cluster_pad_bottom) =
    root_cluster_padding_for_rankdir(
      rankdir,
      compute_root_cluster_padding(
        {
          graph,
          nodes: input.nodes,
          all_ranks: input.all_ranks,
          ranks: input.ranks,
        },
      ),
    )
  let bbox =
    apply_root_port_padding(
      {
        graph,
        bbox: subgraphs_and_bbox.base_bbox,
        rankdir,
        port_pad_below: input.port_pad_below,
        port_pad_above: input.port_pad_above,
      },
    )
  let layout_with_root_pad =
    apply_root_cluster_padding(
      {
        graph,
        layout: {
          graph,
          bbox,
          label_pos: None,
          nodes: final_geometry.final_nodes,
          edges: final_geometry.final_edges,
          subgraphs: subgraphs_and_bbox.subgraphs,
        },
        root_cluster_pad_top,
        root_cluster_pad_bottom,
      },
    )
  // Graphviz parity: ratio=fill uses pre-spline bbox; include rank/cluster
  // padding that is part of set_ycoords before final edge bbox expansion.
  let ratio_bbox = layout_with_root_pad.bbox
  { layout_with_root_pad, ratio_bbox }
}

///|
fn root_cluster_padding_for_rankdir(
  rankdir : RankDir,
  root_cluster_padding : RootClusterPadding,
) -> (Double, Double) {
  // Graphviz parity: rankdir=BT flips top/bottom cluster padding
  // because ranks are inverted before postprocess transform.
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
}

///|
/// Graphviz parity: assemble final pre-rotation layout in dot coordinate space
/// before rankdir transforms and cluster mirror policy.
/// Do not change behavior without updating fixtures/tests.
fn build_pre_rotation_layout_data(
  input : FinalizeLayoutInput,
) -> PreRotationLayoutData {
  let graph = input.graph
  let rankdir = input.rankdir
  let final_geometry =
    build_final_layout_geometry(
      {
        nodes_out: input.nodes_out,
        edges_out: input.edges_out,
        all_ranks: input.all_ranks,
        sizes: input.sizes,
        rank_y: input.rank_y,
        rank_ht1: input.rank_ht1,
        rank_ht2: input.rank_ht2,
      },
    )
  let subgraphs_and_bbox =
    build_subgraphs_and_bbox(
      {
        graph,
        nodes: final_geometry.final_nodes,
        edges: final_geometry.final_edges,
        bbox: final_geometry.rank_bbox,
        cluster_ln_x: input.cluster_ln_x,
        cluster_rn_x: input.cluster_rn_x,
        cluster_bbox_heights: input.cluster_bbox_heights,
        rankdir,
        ranks: input.ranks,
        rank_y: input.rank_y,
        rank_ht1: input.rank_ht1,
        rank_ht2: input.rank_ht2,
      },
    )
  let root_padded =
    build_root_padded_layout_data(input, final_geometry, subgraphs_and_bbox)
  let layout =
    apply_pre_rotation_layout_postprocess(input, root_padded)
  {
    layout: {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    },
    rank_bbox: final_geometry.rank_bbox,
    subgraph_base_bbox: subgraphs_and_bbox.base_bbox,
  }
}

///|
/// Graphviz parity: pre-rotation postprocess applies edge bbox expansion,
/// ratio scaling, edge-label adjustment, exterior xlabels, and root label bbox
/// in fixed Graphviz-equivalent order.
/// Do not change behavior without updating fixtures/tests.
fn apply_pre_rotation_layout_postprocess(
  input : FinalizeLayoutInput,
  root_padded : RootPaddedLayoutData,
) -> DotLayoutGraph {
  let graph = input.graph
  let rankdir = input.rankdir
  let layout_with_root_pad = root_padded.layout_with_root_pad
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
    apply_ratio_fill_scale(graph, layout, rankdir, root_padded.ratio_bbox)
  let adjusted = adjust_edge_labels_if_enabled(layout, input.nodesep_pt, rankdir)
  let labeled =
    expand_bbox_for_edge_labels(
      graph,
      adjusted,
      input.ranks,
      input.flat_label_edge_vnodes,
    )
  let with_xlabels = apply_xlabels(graph, labeled, input.splines)
  let root_label_bbox =
    apply_root_label_bbox(graph, with_xlabels.bbox, rankdir)
  {
    graph: with_xlabels.graph,
    bbox: root_label_bbox.bbox,
    label_pos: root_label_bbox.label_pos,
    nodes: with_xlabels.nodes,
    edges: with_xlabels.edges,
    subgraphs: with_xlabels.subgraphs,
  }
}

///|
/// Graphviz parity: postprocess rankdir transform keeps TB passthrough,
/// non-TB rotation, and LR cluster mirror policy in fixed order.
/// Do not change behavior without updating fixtures/tests.
fn rotate_and_mirror_final_layout(
  graph : @cgraph.Graph,
  rankdir : RankDir,
  pre_rotation : PreRotationLayoutData,
) -> DotLayoutGraph {
  let rotated = if rankdir == RankDir::TB {
    pre_rotation.layout
  } else {
    rotate_layout_graph(pre_rotation.layout, pre_rotation.layout.bbox, rankdir)
  }
  apply_cluster_lr_mirror_after_rotation(
    {
      graph,
      rankdir,
      rotated,
      pre_rotation_bbox: pre_rotation.layout.bbox,
      rank_bbox: pre_rotation.rank_bbox,
      subgraph_base_bbox: pre_rotation.subgraph_base_bbox,
    },
  )
}

///|
/// Graphviz parity: postprocess pipeline aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess) + dotgen/position.c (cluster/label spacing).
/// Do not change behavior without updating fixtures/tests.
fn finalize_layout_graph(
  input : FinalizeLayoutInput,
) -> DotLayoutGraph {
  let graph = input.graph
  let rankdir = input.rankdir
  let pre_rotation = build_pre_rotation_layout_data(input)
  let rotated =
    rotate_and_mirror_final_layout(graph, rankdir, pre_rotation)
  finalize_root_coordinates(
    graph,
    rotated,
  )
}
///|
/// Final-layout ratio=fill scaling helpers used by postprocess.

fn scale_layout_graph(
  layout : DotLayoutGraph,
  sx : Double,
  sy : Double,
  round_node_pos : Bool,
) -> DotLayoutGraph {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let scaled_pos =
      if round_node_pos {
        @dot_shared.scale_point_rounded(node_layout.pos, sx, sy)
      } else {
        @dot_shared.scale_point(node_layout.pos, sx, sy)
      }
    nodes.push({
      node: node_layout.node,
      pos: scaled_pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: @dot_shared.scale_optional_point(node_layout.label_pos, sx, sy),
      xlabel_pos: @dot_shared.scale_optional_point(node_layout.xlabel_pos, sx, sy),
    })
  }
  let edges = @routing.scale_edge_layout_output(layout.edges, sx, sy)
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(scale_layout_graph(subgraph, sx, sy, round_node_pos))
  }
  {
    graph: layout.graph,
    bbox: {
      llx: layout.bbox.llx * sx,
      lly: layout.bbox.lly * sy,
      urx: layout.bbox.urx * sx,
      ury: layout.bbox.ury * sy,
    },
    label_pos: @dot_shared.scale_optional_point(layout.label_pos, sx, sy),
    nodes,
    edges,
    subgraphs,
  }
}

///|
/// Graphviz parity: root ratio=fill scaling aligned to refs/graphviz/lib/dotgen/position.c
/// (set_aspect R_FILL branch + ND_coord rounding).
fn apply_ratio_fill_scale(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  rankdir : RankDir,
  ratio_bbox : @geom.Rect,
) -> DotLayoutGraph {
  if !graph.is_root() {
    return layout
  }
  match @dot_shared.ratio_fill_scale_factors(graph, ratio_bbox, rankdir) {
    Some(scale_factors) => {
      if scale_factors.sx == 1.0 && scale_factors.sy == 1.0 {
        layout
      } else {
        // Graphviz parity: set_aspect rounds ND_coord after scaling.
        scale_layout_graph(layout, scale_factors.sx, scale_factors.sy, true)
      }
    }
    None => layout
  }
}
///|
/// Edge-label bbox expansion helpers used in final postprocess.

///|
/// Graphviz parity: edge label bbox expansion aligned to refs/graphviz/lib/common/utils.c
/// (addLabelBB/compute_bb) + dotgen/dotsplines.c (updateBB for edge labels).
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_for_edge_labels(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  ranks : Map[String, Int],
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutGraph {
  if !graph.is_root() {
    return layout
  }
  let bbox =
    @routing.expand_bbox_for_edge_labels(
      {
        bbox: layout.bbox,
        edges: layout.edges,
        ranks,
        flat_label_edge_vnodes,
        rankdir: @dot_shared.graph_rankdir(graph),
      },
      {
        edge_mid_label_metrics_for:
          edge =>
            match edge_mid_label_metrics(edge) {
              Some(metrics) => Some({ width: metrics.width, height: metrics.height })
              None => None
            },
        edge_label_metrics_for_attr:
          (edge, label_attr) =>
            match edge_label_metrics_for_attr(edge, label_attr, true) {
              Some(metrics) => Some({ width: metrics.width, height: metrics.height })
              None => None
            },
        node_half_height_pt_for:
          (node, rankdir) => {
            let orientation = record_layout_orientation(rankdir)
            node_size(node, orientation).height_pt / 2.0
          },
      },
    )
  if bbox == layout.bbox {
    layout
  } else {
    {
      graph: layout.graph,
      bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    }
  }
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
