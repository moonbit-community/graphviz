// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Stage F finalization package: final layout payload assembly, pre/post-
/// rotation transforms, and root coordinate writeback.
type LayoutTree = @layout_tree.LayoutTree

///|
type LayoutPrep = @layout_prep.LayoutPrep

///|
type RankDir = @rankdir.RankDir

///|
type SplinesMode = @layout_prep.SplinesMode

///|
type NodeSize = @node_primitives.NodeSize

///|
type DotLayoutNode = @layout_tree.DotLayoutNode

///|
type DotLayoutEdge = @layout_tree.DotLayoutEdge

///|
type ClusterBboxHeightPair = @cluster_geometry.ClusterBboxHeightPair

///|
type RankData = @rank_data.RankData

///|
type RankHeights = @rank_heights.RankHeights

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
    nodes_out: sources.routing_stage_output.nodes_out,
    edges_out: sources.routing_stage_output.edges_out,
    rankdir: sources.prep.rankdir,
    splines: sources.prep.splines,
    all_ranks: sources.rank_data.all_ranks,
    ranks: sources.rank_data.ranks,
    // dot_compute_bb observes the right-side reservation accumulated for
    // self-edges during positioning; rendering still uses each node's
    // unexpanded output dimensions.
    sizes: sources.routing_stage_output.bbox_sizes,
    cluster_ln_x: sources.positions_state.cluster_ln_x,
    cluster_rn_x: sources.positions_state.cluster_rn_x,
    cluster_bbox_heights: sources.positions_state.cluster_bbox_heights,
    rank_y: sources.positions_state.rank_y,
    rank_ht1: sources.positions_state.rank_ht1,
    rank_ht2: sources.positions_state.rank_ht2,
    nodesep_pt: sources.rank_heights.nodesep_pt,
    flat_label_edge_vnodes: sources.positions_state.flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: postprocess rankdir transform keeps TB passthrough,
/// and non-TB rotation without a cluster-dependent reflection.
/// Do not change behavior without updating fixtures/tests.
fn rotate_final_layout(
  rankdir : RankDir,
  pre_rotation : PreRotationLayoutData,
) -> LayoutTree {
  if rankdir == RankDir::TB {
    pre_rotation.layout
  } else {
    rotate_layout_graph(pre_rotation.layout, pre_rotation.layout.bbox, rankdir)
  }
}

///|
/// Graphviz parity: postprocess pipeline aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess) + dotgen/position.c (cluster/label spacing).
/// Do not change behavior without updating fixtures/tests.
pub fn finalize_layout_from_sources(
  sources : FinalizeLayoutBuildSources,
) -> LayoutTree {
  let input = build_finalize_layout_input_from_sources(sources)
  let rotated = rotate_final_layout(
    input.rankdir,
    build_pre_rotation_layout_data(input),
  )
  finalize_root_coordinates(rotated)
}
