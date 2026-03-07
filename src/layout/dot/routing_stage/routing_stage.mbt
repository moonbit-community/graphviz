///|
type LayoutPrep = @shared.LayoutPrep
type RankDir = @shared.RankDir
type SplinesMode = @shared.SplinesMode
type RecordOrientation = @shared.RecordOrientation
type NodeSize = @shared.NodeSize
type RecordPort = @shared.RecordPort
type DotLayoutNode = @shared.DotLayoutNode
type DotLayoutEdge = @routing.DotLayoutEdge
type RankData = @rank_assignment.RankData
type RankHeights = @rank_assignment.RankHeights
type ClusterMetadata = @ordering.DotClusterMetadata
type OrderingResult = @ordering.OrderingResult
type PositionResult = @positioning.PositionResult
type ClusterBboxHeightPair = @clustering.ClusterBboxHeightPair

///|
/// Graphviz parity: routing stage payload keeps stage outputs and context maps
/// grouped so Stage E wiring remains explicit and stable.
pub(all) struct DotRoutingStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  positions_state : PositionResult
}

///|
pub(all) struct DotRoutingStageOutput {
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  port_pad_below : Double
  port_pad_above : Double
}

///|
pub(all) struct RoutingPortLayoutMaps {
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
pub(all) struct RoutingPortPadding {
  below : Double
  above : Double
}

///|
/// Graphviz parity: routing stage dependency payload groups root-boundary
/// geometry and bbox bridges so the subpackage owns stage-internal orchestration
/// without importing the root dot package.
pub(all) struct RoutingStageDeps {
  build_layout_nodes : (
    Array[@cgraph.Node],
    Map[String, @geom.Point],
    Map[String, NodeSize],
    RecordOrientation,
  ) -> Array[DotLayoutNode]
  build_port_layout_maps : (
    Array[DotLayoutNode],
    Map[String, NodeSize],
    RecordOrientation,
    RankDir,
    Bool,
  ) -> RoutingPortLayoutMaps
  compute_cluster_route_bboxes : (
    @cgraph.Graph,
    Array[DotLayoutNode],
    Map[String, Double],
    Map[String, Double],
    Map[String, ClusterBboxHeightPair],
    RankDir,
    Map[String, Int],
    Map[Int, Double],
    Map[Int, Double],
    Map[Int, Double],
  ) -> Map[String, @geom.Rect]
  compute_routing_bbox : (
    Array[DotLayoutNode],
    Array[Int],
    Map[String, NodeSize],
    Map[Int, Double],
    Map[Int, Double],
    Map[Int, Double],
  ) -> @geom.Rect
  edge_has_mid_label : (@cgraph.Edge) -> Bool
  record_port_padding : (
    Array[@cgraph.Edge],
    Map[String, @geom.Point],
    Map[String, Map[String, RecordPort]],
  ) -> RoutingPortPadding
  build_head_port_metrics : (
    Array[@cgraph.Edge],
    Bool,
    Map[String, @geom.Point],
    Map[String, NodeSize],
    RecordOrientation,
    Map[String, Map[String, RecordPort]],
  ) -> @precompute.HeadPortMetrics
  apply_self_edge_right_space : (
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Map[String, NodeSize],
    RankDir,
    RecordOrientation,
  ) -> Map[String, NodeSize]
  build_route_base_deps : (
    RecordOrientation,
    Map[String, Map[String, RecordPort]],
    Map[String, Map[String, RecordPort]],
  ) -> @routing.RouteBaseDeps
  build_routing_callbacks : (@routing.EdgeLayoutInput) -> @routing.RoutingCallbacks
}

///|
/// Graphviz parity: dot routing stage mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures), with typed stage payload.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_dot_routing_stage(
  input : DotRoutingStageInput,
  deps : RoutingStageDeps,
) -> DotRoutingStageOutput {
  let graph = input.graph
  let prep = input.prep
  let rank_data = input.rank_data
  let rank_heights = input.rank_heights
  let cluster_meta = input.cluster_meta
  let ordering = input.ordering
  let positions_state = input.positions_state
  let spatial_data =
    build_routing_spatial_data(
      {
        graph,
        prep,
        ranks: rank_data.ranks,
        positions_state,
      },
      deps,
    )
  let nodes_out = spatial_data.nodes_out
  let ratio_adjusted_data =
    build_routing_ratio_adjusted_data(
      {
        graph,
        prep,
        rank_data,
        nodes_out,
        positions_state,
        cluster_bboxes: spatial_data.cluster_bboxes,
        label_ports_map: spatial_data.label_ports_map,
        label_ports_raw: spatial_data.label_ports_raw,
      },
      deps,
    )
  let ratio_scaled = ratio_adjusted_data.ratio_scaled
  let ratio_sx = ratio_adjusted_data.ratio_sx
  let ratio_sy = ratio_adjusted_data.ratio_sy
  let routing_cluster_bboxes = ratio_adjusted_data.cluster_bboxes
  let routing_positions_state = ratio_adjusted_data.positions_state
  let label_edge_counts =
    @precompute.build_label_edge_counts(
      prep.edges,
      deps.edge_has_mid_label,
    )
  let enable_complex_tuning = @precompute.complex_tuning_enabled()
  let precompute_data =
    build_routing_precompute_data(
      {
        prep,
        rank_data,
        rank_heights,
        cluster_meta,
        ordering,
        positions_state: routing_positions_state,
        label_ports_map: ratio_adjusted_data.label_ports_map,
        cluster_bboxes: routing_cluster_bboxes,
        sizes: prep.sizes,
        enable_complex_tuning,
      },
      deps,
    )
  let port_pad_below = precompute_data.port_pad_below
  let port_pad_above = precompute_data.port_pad_above
  let head_port_metrics = precompute_data.head_port_metrics
  let path_groups = precompute_data.path_groups
  let routing_context = precompute_data.routing_context
  let edges_routed =
    route_edges_for_dot(
      {
        graph,
        prep,
        rank_data,
        rank_heights,
        cluster_meta,
        ordering,
        routing_positions_state: ratio_adjusted_data.positions_state,
        routing_label_ports_map: ratio_adjusted_data.label_ports_map,
        routing_label_ports_raw: ratio_adjusted_data.label_ports_raw,
        routing_sizes: prep.sizes,
        path_groups,
        routing_context,
        label_edge_counts,
        head_port_metrics,
        enable_complex_tuning,
      },
      deps,
    )
  let edges_out =
    if ratio_scaled {
      @routing.scale_edge_layout_output(
        edges_routed,
        1.0 / ratio_sx,
        1.0 / ratio_sy,
      )
    } else {
      edges_routed
    }
  { nodes_out, edges_out, port_pad_below, port_pad_above }
}
