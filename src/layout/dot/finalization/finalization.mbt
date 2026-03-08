///|
/// Stage F finalization package: final layout payload assembly, pre/post-
/// rotation transforms, and root coordinate writeback.
type LayoutTree = @shared.LayoutTree

///|
type LayoutPrep = @shared.LayoutPrep

///|
type RankDir = @rankdir.RankDir

///|
type SplinesMode = @shared.SplinesMode

///|
type NodeSize = @node_primitives.NodeSize

///|
type DotLayoutNode = @shared.DotLayoutNode

///|
type DotLayoutEdge = @shared.DotLayoutEdge

///|
type ClusterBboxHeightPair = @clustering.ClusterBboxHeightPair

///|
type RankData = @rank_assignment.RankData

///|
type RankHeights = @rank_assignment.RankHeights

///|
type PositionResult = @positioning.PositionResult

///|
type DotRoutingStageOutput = @integration.DotRoutingStageOutput

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
    rotate_layout_graph(pre_rotation.layout, pre_rotation.layout.bbox, rankdir)
  }
  apply_cluster_lr_mirror_after_rotation({
    graph,
    rankdir,
    rotated,
    pre_rotation_bbox: pre_rotation.layout.bbox,
    rank_bbox: pre_rotation.rank_bbox,
    subgraph_base_bbox: pre_rotation.subgraph_base_bbox,
  })
}

///|
/// Graphviz parity: postprocess pipeline aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess) + dotgen/position.c (cluster/label spacing).
/// Do not change behavior without updating fixtures/tests.
pub fn finalize_layout_from_sources(
  sources : FinalizeLayoutBuildSources,
) -> LayoutTree {
  let input = build_finalize_layout_input_from_sources(sources)
  let rotated = rotate_and_mirror_final_layout(
    input.graph,
    input.rankdir,
    build_pre_rotation_layout_data(input),
  )
  finalize_root_coordinates(rotated)
}
