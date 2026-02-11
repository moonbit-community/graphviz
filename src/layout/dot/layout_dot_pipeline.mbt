///|
priv struct DotRankStage {
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: dot rank-stage ordering input payload keeps ordering call
/// fields in the same sequence as Graphviz rank/mincross setup.
/// Do not change behavior without updating fixtures/tests.
priv struct DotRankStageOrderingInputs {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  rankdir : RankDir
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: cluster metadata in rank/order stage uses the same
/// rank-group and edge endpoint wiring as Graphviz ordering setup.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_meta_for_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
) -> ClusterMetadata {
  compute_cluster_metadata(
    graph,
    prep.nodes,
    prep.edges,
    rank_data.groups,
    rank_data.ranks,
    prep.node_order,
    rank_data.edge_tail,
    rank_data.edge_head,
    prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL,
  )
}

///|
/// Graphviz parity: dot rank-stage ordering input payload assembly reads prep/
/// rank outputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_inputs_for_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
) -> DotRankStageOrderingInputs {
  {
    graph,
    nodes: prep.nodes,
    edges: prep.edges,
    edge_tail: rank_data.edge_tail,
    edge_head: rank_data.edge_head,
    edge_reversed: rank_data.edge_reversed,
    edge_out_order: rank_data.edge_out_order,
    ranks: rank_data.ranks,
    groups: rank_data.groups,
    rank_keys: rank_data.rank_keys,
    node_order: prep.node_order,
    order_sizes: prep.order_sizes,
    nodesep_pt: rank_heights.nodesep_pt,
    has_edge_labels: prep.has_edge_labels,
    rankdir: prep.rankdir,
    cluster_meta,
    port_order_positions: prep.port_order_positions,
    port_order_contrib: prep.port_order_contrib,
  }
}

///|
/// Graphviz parity: ordering/vnode stage consumes rank-stage ordering payload
/// with unchanged Graphviz call wiring.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_for_dot_rank_stage_from_inputs(
  ordering_inputs : DotRankStageOrderingInputs,
) -> OrderingResult {
  compute_ordering_and_vnodes(
    ordering_inputs.graph,
    ordering_inputs.nodes,
    ordering_inputs.edges,
    ordering_inputs.edge_tail,
    ordering_inputs.edge_head,
    ordering_inputs.edge_reversed,
    ordering_inputs.edge_out_order,
    ordering_inputs.ranks,
    ordering_inputs.groups,
    ordering_inputs.rank_keys,
    ordering_inputs.node_order,
    ordering_inputs.order_sizes,
    ordering_inputs.nodesep_pt,
    ordering_inputs.has_edge_labels,
    ordering_inputs.rankdir,
    ordering_inputs.cluster_meta,
    ordering_inputs.port_order_positions,
    ordering_inputs.port_order_contrib,
  )
}

///|
/// Graphviz parity: ordering/vnode stage consumes rank data, rank heights,
/// and cluster metadata with unchanged Graphviz call wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_for_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
) -> OrderingResult {
  let ordering_inputs =
    build_ordering_inputs_for_dot_rank_stage(
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
    )
  run_ordering_for_dot_rank_stage_from_inputs(ordering_inputs)
}

///|
/// Graphviz parity: rank-height stage consumes computed ranks/groups and
/// spacing inputs with unchanged Graphviz argument wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_heights_for_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
) -> RankHeights {
  compute_rank_heights(
    graph,
    prep.edges,
    rank_data.ranks,
    rank_data.groups,
    rank_data.rank_keys,
    rank_data.all_ranks,
    prep.sizes,
    rank_data.self_edge_labels,
    prep.rankdir,
    prep.nodesep_in,
    prep.ranksep_in,
    prep.has_edge_labels,
  )
}

///|
/// Graphviz parity: rank-data creation emits the same rank trace points before
/// downstream stage assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_data_for_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
) -> RankData {
  let rank_data =
    compute_rank_data(
      graph,
      prep.nodes,
      prep.edges,
      prep.has_edge_labels,
    )
  dot_trace("layout_dot: ranks computed")
  dot_trace_edges(
    prep.edges,
    rank_data.edge_tail,
    rank_data.edge_head,
    rank_data.ranks,
  )
  rank_data
}

///|
/// Graphviz parity: rank-stage result object keeps computed rank/cluster/order
/// artifacts unchanged and emits rank-order trace at the same stage boundary.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_rank_stage_result_for_stage(
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> DotRankStage {
  dot_trace("layout_dot: rank order computed")
  { rank_data, rank_heights, cluster_meta, ordering }
}

///|
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
) -> DotRankStage {
  let rank_data =
    build_rank_data_for_dot_rank_stage(graph, prep)
  let rank_heights =
    build_rank_heights_for_dot_rank_stage(graph, prep, rank_data)
  let cluster_meta =
    build_cluster_meta_for_dot_rank_stage(graph, prep, rank_data)
  let ordering =
    build_ordering_for_dot_rank_stage(
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
    )
  build_dot_rank_stage_result_for_stage(
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
  )
}

///|
/// Graphviz parity: position-stage result wiring forwards rank-stage artifacts
/// directly into compute_positions without remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_position_stage_result_for_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> PositionResult {
  compute_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
  )
}

///|
/// Graphviz parity: dot position stage mirrors refs/graphviz/lib/dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_position_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
) -> PositionResult {
  build_dot_position_stage_result_for_stage(
    graph,
    prep,
    rank_stage.rank_data,
    rank_stage.rank_heights,
    rank_stage.cluster_meta,
    rank_stage.ordering,
  )
}

///|
priv struct DotRoutingStage {
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  port_pad_below : Double
  port_pad_above : Double
}

///|
priv struct DotRoutingPaddingAndHeadPortMetrics {
  port_pad_below : Double
  port_pad_above : Double
  head_port_metrics : HeadPortMetrics
}

///|
priv struct DotRoutingNodeAndPortData {
  nodes_out : Array[DotLayoutNode]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
priv struct DotRoutingPathContextData {
  path_groups : Map[Int, Array[String]]
  routing_context : RoutingContext
}

///|
priv struct DotRoutingLabelAndTuningData {
  label_edge_counts : Map[String, Int]
  enable_complex_tuning : Bool
}

///|
priv struct DotRoutingSpatialData {
  nodes_out : Array[DotLayoutNode]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
priv struct DotRoutingEdgesAndPaddingData {
  edges_out : Array[DotLayoutEdge]
  port_pad_below : Double
  port_pad_above : Double
}

///|
priv struct DotRoutingEdgeSolvePrecomputeData {
  routing_padding_and_head_port_metrics : DotRoutingPaddingAndHeadPortMetrics
  routing_path_context_data : DotRoutingPathContextData
}

///|
priv struct DotRoutingSpatialAndTuningData {
  routing_spatial_data : DotRoutingSpatialData
  routing_label_and_tuning_data : DotRoutingLabelAndTuningData
}

///|
/// Graphviz parity: routing path-groups selection prefers positioned x-groups,
/// then vnode-expanded order groups, then base order groups.
/// Do not change behavior without updating fixtures/tests.
fn build_path_groups_for_routing_stage(
  positions_state : PositionResult,
  ordering : OrderingResult,
) -> Map[Int, Array[String]] {
  if positions_state.x_groups.length() > 0 {
    positions_state.x_groups
  } else if ordering.ordered_groups_with_vnodes.length() > 0 {
    ordering.ordered_groups_with_vnodes
  } else {
    ordering.ordered_groups
  }
}

///|
/// Graphviz parity: routing context is assembled from final ordering, vnode,
/// rank, and cluster bbox data without altering parameter mapping.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_context_for_stage(
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  path_groups : Map[Int, Array[String]],
  cluster_bboxes : Map[String, @geom.Rect],
) -> RoutingContext {
  prepare_routing_context(
    prep.nodes,
    prep.edges,
    rank_stage.rank_data.edge_tail,
    rank_stage.rank_data.edge_head,
    prep.sizes,
    prep.rankdir,
    prep.record_orientation,
    rank_stage.rank_data.ranks,
    rank_stage.ordering.ordered_groups,
    path_groups,
    rank_stage.rank_heights.nodesep_pt,
    rank_stage.ordering.vnode_info,
    positions_state.vnode_positions,
    cluster_bboxes,
  )
}

///|
/// Graphviz parity: routing path groups are selected first, then the routing
/// context is derived from those groups and cluster bboxes.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_path_context_data_for_stage(
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  cluster_bboxes : Map[String, @geom.Rect],
) -> DotRoutingPathContextData {
  // Graphviz parity: pathplan uses final x-order (after positioning) with vnodes.
  let path_groups =
    build_path_groups_for_routing_stage(positions_state, rank_stage.ordering)
  let routing_context =
    build_routing_context_for_stage(
      prep,
      rank_stage,
      positions_state,
      path_groups,
      cluster_bboxes,
    )
  { path_groups, routing_context }
}

///|
/// Graphviz parity: routing cluster bboxes are derived from positioned nodes,
/// rank heights, and cluster x-bound maps before spline routing.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_bboxes_for_routing_stage(
  graph : @cgraph.Graph,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  nodes_out : Array[DotLayoutNode],
  rankdir : RankDir,
) -> Map[String, @geom.Rect] {
  compute_cluster_bboxes_for_routing(
    graph,
    nodes_out,
    positions_state.cluster_ln_x,
    positions_state.cluster_rn_x,
    positions_state.cluster_bbox_heights,
    rankdir,
    rank_stage.rank_data.ranks,
    positions_state.rank_y,
    positions_state.rank_ht1,
    positions_state.rank_ht2,
  )
}

///|
/// Graphviz parity: routing spatial output object reuses node/port precompute
/// fields and cluster-bbox derivation without remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_output_from_node_port_data_for_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  routing_node_and_port_data : DotRoutingNodeAndPortData,
) -> DotRoutingSpatialData {
  let cluster_bboxes =
    build_cluster_bboxes_for_routing_stage(
      graph,
      rank_stage,
      positions_state,
      routing_node_and_port_data.nodes_out,
      prep.rankdir,
    )
  {
    nodes_out: routing_node_and_port_data.nodes_out,
    label_ports_map: routing_node_and_port_data.label_ports_map,
    label_ports_raw: routing_node_and_port_data.label_ports_raw,
    cluster_bboxes,
  }
}

///|
/// Graphviz parity: routing spatial precompute keeps node projection, port-map
/// derivation, and cluster-bbox computation order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_data_for_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
) -> DotRoutingSpatialData {
  let routing_node_and_port_data =
    build_routing_node_and_port_data_for_stage(prep, positions_state)
  build_routing_spatial_output_from_node_port_data_for_stage(
    graph,
    prep,
    rank_stage,
    positions_state,
    routing_node_and_port_data,
  )
}

///|
/// Graphviz parity: routing port maps are built from final node geometry and
/// rankdir/port-edge flags before padding and edge routing.
/// Do not change behavior without updating fixtures/tests.
fn build_port_layout_maps_for_routing_stage(
  prep : LayoutPrep,
  nodes_out : Array[DotLayoutNode],
) -> PortLayoutMaps {
  build_port_layout_maps(
    nodes_out,
    prep.output_sizes,
    prep.record_orientation,
    prep.rankdir,
    prep.has_port_edges,
  )
}

///|
/// Graphviz parity: routing node/port output object maps projected nodes and
/// derived port-layout maps without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_node_and_port_output_for_stage(
  nodes_out : Array[DotLayoutNode],
  port_maps : PortLayoutMaps,
) -> DotRoutingNodeAndPortData {
  {
    nodes_out,
    label_ports_map: port_maps.label_ports_map,
    label_ports_raw: port_maps.label_ports_raw,
  }
}

///|
/// Graphviz parity: node geometry projection and port-map derivation are
/// sequenced together before routing precompute consumption.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_node_and_port_data_for_stage(
  prep : LayoutPrep,
  positions_state : PositionResult,
) -> DotRoutingNodeAndPortData {
  let nodes_out =
    build_layout_nodes(
      prep.nodes,
      positions_state.positions,
      prep.output_sizes,
      prep.record_orientation,
    )
  let port_maps =
    build_port_layout_maps_for_routing_stage(prep, nodes_out)
  build_routing_node_and_port_output_for_stage(nodes_out, port_maps)
}

///|
/// Graphviz parity: routing label/tuning output object maps label-edge counts
/// and complex-tuning gate values without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_label_and_tuning_output_for_stage(
  label_edge_counts : Map[String, Int],
  enable_complex_tuning : Bool,
) -> DotRoutingLabelAndTuningData {
  { label_edge_counts, enable_complex_tuning }
}

///|
/// Graphviz parity: label-edge counts and complex-tuning gate are read before
/// routing metric derivation and spline routing, without remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_label_and_tuning_data_for_stage(
  prep : LayoutPrep,
) -> DotRoutingLabelAndTuningData {
  let label_edge_counts = build_label_edge_counts(prep.edges)
  let enable_complex_tuning = complex_tuning_enabled()
  build_routing_label_and_tuning_output_for_stage(
    label_edge_counts,
    enable_complex_tuning,
  )
}

///|
/// Graphviz parity: routing padding/head-port metrics output maps computed
/// padding tuple and collected head metrics without extra transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_padding_and_head_port_metrics_output_for_stage(
  port_pad_below : Double,
  port_pad_above : Double,
  head_port_metrics : HeadPortMetrics,
) -> DotRoutingPaddingAndHeadPortMetrics {
  { port_pad_below, port_pad_above, head_port_metrics }
}

///|
/// Graphviz parity: port padding and head-port metrics are computed from the
/// same inputs and in the same order before spline routing.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_padding_and_head_port_metrics_for_stage(
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  label_ports_map : Map[String, Map[String, RecordPort]],
  enable_complex_tuning : Bool,
) -> DotRoutingPaddingAndHeadPortMetrics {
  let (port_pad_below, port_pad_above) =
    compute_port_padding(
      rank_stage.cluster_meta.has_clusters,
      prep.has_port_edges,
      prep.edges,
      positions_state.positions,
      label_ports_map,
    )
  let head_port_metrics =
    collect_head_port_metrics(
      prep.edges,
      positions_state.positions,
      prep.sizes,
      label_ports_map,
      prep.record_orientation,
      enable_complex_tuning,
    )
  build_routing_padding_and_head_port_metrics_output_for_stage(
    port_pad_below,
    port_pad_above,
    head_port_metrics,
  )
}

///|
/// Graphviz parity: edge routing call preserves Graphviz-aligned argument
/// mapping, including layout rankdir override and path-group/vnode wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_edges_out_for_routing_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  path_groups : Map[Int, Array[String]],
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> Array[DotLayoutEdge] {
  let layout_rankdir = RankDir::TB
  route_edges(
    graph,
    prep.edges,
    rank_stage.rank_data.ranks,
    prep.sizes,
    prep.record_orientation,
    prep.rankdir,
    layout_rankdir,
    prep.splines,
    positions_state.positions,
    positions_state.vnode_positions,
    rank_stage.ordering.vnode_info,
    positions_state.rank_y,
    positions_state.rank_ht1,
    positions_state.rank_ht2,
    path_groups,
    rank_stage.rank_heights.nodesep_pt,
    rank_stage.rank_heights.ranksep_pt,
    rank_stage.cluster_meta.has_clusters,
    label_ports_map,
    label_ports_raw,
    label_edge_counts,
    head_port_metrics,
    positions_state.flat_label_edge_vnodes,
    routing_context,
    enable_complex_tuning,
  )
}

///|
/// Graphviz parity: routing stage result object is built directly from routed
/// edges and computed padding, with trace emission preserved.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_routing_stage_result_from_edges_for_stage(
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
  port_pad_below : Double,
  port_pad_above : Double,
) -> DotRoutingStage {
  dot_trace("layout_dot: edges routed")
  { nodes_out, edges_out, port_pad_below, port_pad_above }
}

///|
/// Graphviz parity: routed-edge solve call consumes path-context, label/tuning,
/// and head-port metrics precompute without remapping stage inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edges_from_precomputed_data_for_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  routing_spatial_data : DotRoutingSpatialData,
  routing_label_and_tuning_data : DotRoutingLabelAndTuningData,
  routing_padding_and_head_port_metrics : DotRoutingPaddingAndHeadPortMetrics,
  routing_path_context_data : DotRoutingPathContextData,
) -> Array[DotLayoutEdge] {
  build_edges_out_for_routing_stage(
    graph,
    prep,
    rank_stage,
    positions_state,
    routing_path_context_data.path_groups,
    routing_spatial_data.label_ports_map,
    routing_spatial_data.label_ports_raw,
    routing_label_and_tuning_data.label_edge_counts,
    routing_padding_and_head_port_metrics.head_port_metrics,
    routing_path_context_data.routing_context,
    routing_label_and_tuning_data.enable_complex_tuning,
  )
}

///|
/// Graphviz parity: routing edge-solve precompute output object maps metric
/// and path-context bundles without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edge_solve_precompute_output_for_stage(
  routing_padding_and_head_port_metrics : DotRoutingPaddingAndHeadPortMetrics,
  routing_path_context_data : DotRoutingPathContextData,
) -> DotRoutingEdgeSolvePrecomputeData {
  { routing_padding_and_head_port_metrics, routing_path_context_data }
}

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order before routed-edge solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edge_solve_precompute_data_for_stage(
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  routing_spatial_data : DotRoutingSpatialData,
  routing_label_and_tuning_data : DotRoutingLabelAndTuningData,
) -> DotRoutingEdgeSolvePrecomputeData {
  let routing_padding_and_head_port_metrics =
    build_routing_padding_and_head_port_metrics_for_stage(
      prep,
      rank_stage,
      positions_state,
      routing_spatial_data.label_ports_map,
      routing_label_and_tuning_data.enable_complex_tuning,
    )
  let routing_path_context_data =
    build_routing_path_context_data_for_stage(
      prep,
      rank_stage,
      positions_state,
      routing_spatial_data.cluster_bboxes,
    )
  build_routing_edge_solve_precompute_output_for_stage(
    routing_padding_and_head_port_metrics,
    routing_path_context_data,
  )
}

///|
/// Graphviz parity: routing edge/padding substage derives metrics, path
/// context, and routed edges from spatial+tuning data in fixed order.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edges_and_padding_data_for_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  routing_spatial_data : DotRoutingSpatialData,
  routing_label_and_tuning_data : DotRoutingLabelAndTuningData,
) -> DotRoutingEdgesAndPaddingData {
  let routing_edge_solve_precompute_data =
    build_routing_edge_solve_precompute_data_for_stage(
      prep,
      rank_stage,
      positions_state,
      routing_spatial_data,
      routing_label_and_tuning_data,
    )
  let edges_out =
    build_routing_edges_from_precomputed_data_for_stage(
      graph,
      prep,
      rank_stage,
      positions_state,
      routing_spatial_data,
      routing_label_and_tuning_data,
      routing_edge_solve_precompute_data.routing_padding_and_head_port_metrics,
      routing_edge_solve_precompute_data.routing_path_context_data,
    )
  build_routing_edges_and_padding_output_for_stage(
    edges_out,
    routing_edge_solve_precompute_data.routing_padding_and_head_port_metrics,
  )
}

///|
/// Graphviz parity: routing edge/padding output object maps routed edges with
/// computed port padding metrics without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edges_and_padding_output_for_stage(
  edges_out : Array[DotLayoutEdge],
  routing_padding_and_head_port_metrics : DotRoutingPaddingAndHeadPortMetrics,
) -> DotRoutingEdgesAndPaddingData {
  {
    edges_out,
    port_pad_below: routing_padding_and_head_port_metrics.port_pad_below,
    port_pad_above: routing_padding_and_head_port_metrics.port_pad_above,
  }
}

///|
/// Graphviz parity: routing-stage output assembly maps spatial node geometry
/// and routed-edge padding data directly into final stage result.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_routing_stage_from_spatial_and_edges_data_for_stage(
  routing_spatial_data : DotRoutingSpatialData,
  routing_edges_and_padding_data : DotRoutingEdgesAndPaddingData,
) -> DotRoutingStage {
  build_dot_routing_stage_result_from_edges_for_stage(
    routing_spatial_data.nodes_out,
    routing_edges_and_padding_data.edges_out,
    routing_edges_and_padding_data.port_pad_below,
    routing_edges_and_padding_data.port_pad_above,
  )
}

///|
/// Graphviz parity: routing precompute bundle keeps spatial precompute and
/// label/tuning gate derivation in fixed order before edge routing.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_and_tuning_data_for_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
) -> DotRoutingSpatialAndTuningData {
  let routing_spatial_data =
    build_routing_spatial_data_for_stage(
      graph,
      prep,
      rank_stage,
      positions_state,
    )
  let routing_label_and_tuning_data =
    build_routing_label_and_tuning_data_for_stage(prep)
  build_routing_spatial_and_tuning_output_for_stage(
    routing_spatial_data,
    routing_label_and_tuning_data,
  )
}

///|
/// Graphviz parity: routing spatial+tuning output object maps precomputed
/// spatial data and tuning gates without extra transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_and_tuning_output_for_stage(
  routing_spatial_data : DotRoutingSpatialData,
  routing_label_and_tuning_data : DotRoutingLabelAndTuningData,
) -> DotRoutingSpatialAndTuningData {
  { routing_spatial_data, routing_label_and_tuning_data }
}

///|
/// Graphviz parity: routing-stage edge/padding + result assembly consumes
/// spatial+tuning precompute bundle without altering argument wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_routing_stage_from_spatial_tuning_data_for_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
  routing_spatial_and_tuning_data : DotRoutingSpatialAndTuningData,
) -> DotRoutingStage {
  let routing_edges_and_padding_data =
    build_routing_edges_and_padding_data_for_stage(
      graph,
      prep,
      rank_stage,
      positions_state,
      routing_spatial_and_tuning_data.routing_spatial_data,
      routing_spatial_and_tuning_data.routing_label_and_tuning_data,
    )
  build_dot_routing_stage_from_spatial_and_edges_data_for_stage(
    routing_spatial_and_tuning_data.routing_spatial_data,
    routing_edges_and_padding_data,
  )
}

///|
/// Graphviz parity: dot splines stage mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_routing_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
) -> DotRoutingStage {
  let routing_spatial_and_tuning_data =
    build_routing_spatial_and_tuning_data_for_stage(
      graph,
      prep,
      rank_stage,
      positions_state,
    )
  build_dot_routing_stage_from_spatial_tuning_data_for_stage(
    graph,
    prep,
    rank_stage,
    positions_state,
    routing_spatial_and_tuning_data,
  )
}
