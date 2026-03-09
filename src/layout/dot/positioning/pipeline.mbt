///|
/// Graphviz parity: position stage result keeps x/y coordinates, vnode
/// positions, and cluster bbox metadata grouped for downstream stages.
pub(all) struct PositionResult {
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  flat_label_edge_vnodes : Map[String, String]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  cluster_bbox_heights : Map[String, @cluster_geometry.ClusterBboxHeightPair]
}

///|
/// Positioning owner package keeps Stage D result types plus x/y orchestration
/// in one focused root file so stage-level flow stays cohesive.
type LayoutPrep = @shared.LayoutPrep

///|
type RankData = @rank_data.RankData

///|
type RankHeights = @rank_heights.RankHeights

///|
type ClusterMetadata = @setup.DotClusterMetadata

///|
type OrderingResult = @setup.OrderingResult

///|
/// Graphviz parity: owner-side position pipeline input keeps graph/rank/cluster
/// snapshots grouped so Stage D orchestration avoids positional drift.
pub(all) struct PositionPipelineInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: shared position pipeline context keeps graph/rank/cluster
/// snapshots grouped so x/y/output stages consume the same base inputs.
priv struct PositionPipelineContext {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Stage D root now delegates the full X-stage kernel to `positioning/x_stage`
/// and keeps only cross-X/Y/output orchestration.

///|
/// Graphviz parity: final projection stage in compute_positions keeps y/x solve
/// projection and result assembly sequencing identical to Graphviz-aligned flow.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result(
  pipeline : PositionPipelineContext,
  x_stage_output : @x_stage.XStageOutput,
) -> PositionResult {
  let y_position_data = @y_positions.build_y_position_pipeline({
    has_clusters: pipeline.cluster_meta.has_clusters,
    graph: pipeline.graph,
    rankdir: pipeline.prep.rankdir,
    rank_keys: pipeline.rank_data.rank_keys,
    groups: pipeline.rank_data.groups,
    ranks: pipeline.rank_data.ranks,
    sizes: pipeline.prep.sizes,
    self_edge_labels: pipeline.rank_data.self_edge_labels,
    rank_pht: pipeline.rank_heights.rank_pht,
    rank_ht1: pipeline.rank_heights.rank_ht1,
    rank_ht2: pipeline.rank_heights.rank_ht2,
    ranksep_pt: pipeline.rank_heights.ranksep_pt,
    flat_label_ranks: x_stage_output.flat_label_ranks,
    vnode_sizes: pipeline.ordering.vnode_info.vnode_sizes,
    cluster_margin_pt_for: @clustering.cluster_margin_pt,
    cluster_label_padding_for: @cluster_geometry.cluster_label_padding_for_layout,
    node_half_height_pt_for: @y_positions.node_half_height_pt,
    cluster_label_width_pt_for: @cluster_geometry.cluster_label_width_with_pad_for_layout,
  })
  let position_output_maps = @output_maps.build_position_output_pipeline({
    has_clusters: pipeline.cluster_meta.has_clusters,
    has_dotted_edges: pipeline.prep.has_dotted_edges,
    graph: pipeline.graph,
    nodes: pipeline.prep.nodes,
    edges: pipeline.prep.edges,
    ranks: pipeline.rank_data.ranks,
    x_positions: x_stage_output.x_positions,
    y_positions: y_position_data.y_positions,
    rank_y: y_position_data.rank_y,
    cluster_keys: pipeline.cluster_meta.cluster_keys,
    intercluster_keys: pipeline.cluster_meta.intercluster_keys,
    nodesep_pt: pipeline.rank_heights.nodesep_pt,
    has_edge_labels: pipeline.prep.has_edge_labels,
    use_vnodes_for_xpos: x_stage_output.use_vnodes_for_xpos,
    vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
    edge_vnodes: pipeline.ordering.vnode_info.edge_vnodes,
    cluster_rounding_enabled: @output_maps.cluster_rounding_enabled(),
    vnode_clusters: pipeline.ordering.vnode_info.vnode_clusters,
    sizes: pipeline.prep.sizes,
    cluster_margin_pt_for: @clustering.cluster_margin_pt,
    expand_cluster_label_bbox: @cluster_geometry.expand_cluster_label_bbox_for_position_stage,
  })
  {
    x_groups: x_stage_output.x_groups,
    rank_y: y_position_data.rank_y,
    positions: position_output_maps.positions,
    vnode_positions: position_output_maps.vnode_positions,
    cluster_ln_x: position_output_maps.cluster_ln_x,
    cluster_rn_x: position_output_maps.cluster_rn_x,
    flat_label_edge_vnodes: x_stage_output.flat_label_edge_vnodes,
    rank_ht1: pipeline.rank_heights.rank_ht1,
    rank_ht2: pipeline.rank_heights.rank_ht2,
    cluster_bbox_heights: y_position_data.cluster_bbox_heights,
  }
}

///|
/// Graphviz parity: x-positioning aligned to refs/graphviz/lib/dotgen/position.c
/// + dotgen/cluster.c (fixtures), with the Stage D owner package exposing the
/// direct entry used by the root layout pipeline.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_positions(input : PositionPipelineInput) -> PositionResult {
  let pipeline : PositionPipelineContext = {
    graph: input.graph,
    prep: input.prep,
    rank_data: input.rank_data,
    rank_heights: input.rank_heights,
    cluster_meta: input.cluster_meta,
    ordering: input.ordering,
  }
  let x_stage_output = @x_stage.build_x_stage_output({
    graph: pipeline.graph,
    prep: pipeline.prep,
    rank_data: pipeline.rank_data,
    rank_heights: pipeline.rank_heights,
    cluster_meta: pipeline.cluster_meta,
    ordering: pipeline.ordering,
  })
  build_projection_result(pipeline, x_stage_output)
}
