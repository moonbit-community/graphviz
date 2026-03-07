///|
/// Stage F finalization package: final layout payload assembly, pre/post-
/// rotation transforms, and root coordinate writeback.

type LayoutTree = @shared.LayoutTree
type LayoutPrep = @shared.LayoutPrep
type RankDir = @rankdir.RankDir
type SplinesMode = @shared.SplinesMode
type NodeSize = @node_primitives.NodeSize
type DotLayoutNode = @shared.DotLayoutNode
type DotLayoutEdge = @shared.DotLayoutEdge
type ClusterBboxHeightPair = @clustering.ClusterBboxHeightPair
type RankData = @rank_assignment.RankData
type RankHeights = @rank_assignment.RankHeights
type PositionResult = @positioning.PositionResult
type DotRoutingStageOutput = @routing_stage.DotRoutingStageOutput

///|
/// Graphviz parity: Stage F source payload keeps upstream stage outputs grouped
/// so final postprocess input assembly stays explicit and stable.
pub(all) struct FinalizeLayoutBuildSources {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  positions_state : PositionResult
  routing_stage_output : DotRoutingStageOutput
}

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
/// Graphviz parity: cluster bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
priv struct SubgraphsAndBBox {
  subgraphs : Array[LayoutTree]
  base_bbox : @geom.Rect
}

///|
/// Graphviz parity: Stage F subgraph-bbox payload keeps cluster/rank snapshots
/// grouped so final cluster-bbox assembly wiring remains explicit and stable.
priv struct SubgraphsAndBBoxInput {
  graph : @cgraph.Graph
  nodes : Array[DotLayoutNode]
  edges : Array[DotLayoutEdge]
  bbox : @geom.Rect
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
  rankdir : RankDir
  ranks : Map[String, Int]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

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
/// Graphviz parity: final-geometry input keeps rank-bbox dependencies grouped
/// before postprocess assembles subgraphs and root padding.
priv struct FinalLayoutGeometryInput {
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  all_ranks : Array[Int]
  sizes : Map[String, NodeSize]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
/// Graphviz parity: pre-rotation assembly keeps dot_compute_bb + label/ratio
/// interactions in one place before rankdir transforms are applied.
/// Do not change behavior without updating fixtures/tests.
priv struct PreRotationLayoutData {
  layout : LayoutTree
  rank_bbox : @geom.Rect
  subgraph_base_bbox : @geom.Rect
}

///|
priv struct RootPaddedLayoutData {
  layout_with_root_pad : LayoutTree
  ratio_bbox : @geom.Rect
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
/// Graphviz parity: Stage F subgraph+bbox assembly delegates recursive cluster
/// layout to layout_subgraphs, then applies root cluster-bbox expansion.
/// Do not change behavior without updating fixtures/tests.
fn build_subgraphs_and_bbox(
  input : SubgraphsAndBBoxInput,
) -> SubgraphsAndBBox {
  let subgraphs =
    @clustering.layout_subgraphs(
      {
        graph: input.graph,
        nodes_out: input.nodes,
        edges_out: input.edges,
        cluster_ln_x: input.cluster_ln_x,
        cluster_rn_x: input.cluster_rn_x,
        cluster_bbox_heights: input.cluster_bbox_heights,
        rankdir: input.rankdir,
        ranks: input.ranks,
        rank_y: input.rank_y,
        rank_ht1: input.rank_ht1,
        rank_ht2: input.rank_ht2,
      },
    )
  let expanded = if subgraphs.length() > 0 {
    @clustering.expand_bbox_with_clusters(input.bbox, subgraphs)
  } else {
    input.bbox
  }
  { subgraphs, base_bbox: expanded }
}

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn build_final_layout_geometry(
  input : FinalLayoutGeometryInput,
) -> FinalLayoutGeometry {
  let base_bbox = @bbox.compute_dot_bbox(
    {
      nodes_out: input.nodes_out,
      all_ranks: input.all_ranks,
      sizes: input.sizes,
      rank_y: input.rank_y,
      rank_ht1: input.rank_ht1,
      rank_ht2: input.rank_ht2,
    },
  )
  {
    final_nodes: input.nodes_out,
    final_edges: input.edges_out,
    rank_bbox: base_bbox,
  }
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
    @root_geometry.root_cluster_padding_for_rankdir(
      rankdir,
      @root_geometry.compute_root_cluster_padding(
        graph,
        input.nodes,
        input.all_ranks,
        input.ranks,
      ),
    )
  let bbox =
    @root_geometry.apply_root_port_padding(
      graph,
      subgraphs_and_bbox.base_bbox,
      rankdir,
      input.port_pad_below,
      input.port_pad_above,
    )
  let layout_with_root_pad =
    apply_root_cluster_padding(
      {
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
/// Graphviz parity: pre-rotation postprocess applies edge bbox expansion,
/// ratio scaling, edge-label adjustment, exterior xlabels, and root label bbox
/// in fixed Graphviz-equivalent order.
/// Do not change behavior without updating fixtures/tests.
fn apply_pre_rotation_layout_postprocess(
  input : FinalizeLayoutInput,
  root_padded : RootPaddedLayoutData,
) -> LayoutTree {
  let graph = input.graph
  let rankdir = input.rankdir
  let layout_with_root_pad = root_padded.layout_with_root_pad
  // Graphviz parity: edge splines update bbox after dot_compute_bb (dotsplines.c).
  let bbox =
    @bbox.expand_bbox_with_edges(layout_with_root_pad.bbox, layout_with_root_pad.edges)
  let layout : LayoutTree = {
    graph: layout_with_root_pad.graph,
    bbox,
    label_pos: layout_with_root_pad.label_pos,
    nodes: layout_with_root_pad.nodes,
    edges: layout_with_root_pad.edges,
    subgraphs: layout_with_root_pad.subgraphs,
  }
  let layout =
    apply_ratio_fill_scale(
      layout,
      rankdir,
      root_padded.ratio_bbox,
    )
  let adjusted =
    adjust_edge_labels_if_enabled(
      layout,
      input.nodesep_pt,
      rankdir,
    )
  let labeled =
    expand_layout_tree_bbox_for_edge_labels(
      adjusted,
      input.ranks,
      input.flat_label_edge_vnodes,
    )
  let with_xlabels =
    @xlabel_collection.apply_xlabels(
      labeled,
      input.splines,
    )
  let root_label_bbox =
    @root_geometry.apply_root_label_bbox(graph, with_xlabels.bbox, rankdir)
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
  {
    layout: apply_pre_rotation_layout_postprocess(input, root_padded),
    rank_bbox: final_geometry.rank_bbox,
    subgraph_base_bbox: subgraphs_and_bbox.base_bbox,
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
) -> LayoutTree {
  let rotated = if rankdir == RankDir::TB {
    pre_rotation.layout
  } else {
    rotate_layout_graph(
      pre_rotation.layout,
      pre_rotation.layout.bbox,
      rankdir,
    )
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
pub fn finalize_layout_from_sources(
  sources : FinalizeLayoutBuildSources,
) -> LayoutTree {
  let input = build_finalize_layout_input_from_sources(sources)
  let rotated =
    rotate_and_mirror_final_layout(
      input.graph,
      input.rankdir,
      build_pre_rotation_layout_data(input),
    )
  finalize_root_coordinates(rotated)
}
