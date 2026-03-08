///|
type LayoutPrep = @shared.LayoutPrep
type RankData = @rank_assignment.RankData
type RankHeights = @rank_assignment.RankHeights
type ClusterMetadata = @ordering.DotClusterMetadata
type OrderingResult = @ordering.OrderingResult
type PositionResult = @positioning.PositionResult

///|
/// Graphviz parity: position stage payload keeps stage B/C outputs grouped so
/// Stage D wiring remains explicit and stable.
pub(all) struct PositionStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Root Stage D boundary stays in `position_stage`; owner-internal x/y/output
/// orchestration now lives under `positioning/integration`.

///|
/// Graphviz parity: x-positioning aligned to refs/graphviz/lib/dotgen/position.c + dotgen/cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_positions(
  input : PositionStageInput,
) -> PositionResult {
  @integration.compute_position_pipeline(
    {
      graph: input.graph,
      prep: input.prep,
      rank_data: input.rank_data,
      rank_heights: input.rank_heights,
      cluster_meta: input.cluster_meta,
      ordering: input.ordering,
    },
  )
}
