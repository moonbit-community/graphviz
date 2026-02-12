///|
priv struct DotRankStage {
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: dot rank-stage input payload keeps graph+prep fields in
/// rank-data/rank-height/cluster/order stage call sequence.
/// Do not change behavior without updating fixtures/tests.
priv struct DotRankStageInputs {
  graph : @cgraph.Graph
  prep : LayoutPrep
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
/// Graphviz parity: dot position-stage input payload keeps rank-stage outputs
/// and prep fields in the same compute_positions call sequence.
/// Do not change behavior without updating fixtures/tests.
priv struct DotPositionStageInputs {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: dot routing-stage input payload keeps graph/prep/rank/
/// position artifacts in the same routing-stage call sequence.
/// Do not change behavior without updating fixtures/tests.
priv struct DotRoutingStageInputs {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_stage : DotRankStage
  positions_state : PositionResult
}

///|
/// Graphviz parity: dot rank-stage input payload assembly reads graph/prep
/// fields without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_rank_stage_inputs(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
) -> DotRankStageInputs {
  { graph, prep }
}

///|
/// Graphviz parity: cluster metadata in rank/order stage uses the same
/// rank-group and edge endpoint wiring as Graphviz ordering setup.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_meta_for_dot_rank_stage(
  rank_stage_inputs : DotRankStageInputs,
  rank_data : RankData,
) -> ClusterMetadata {
  compute_cluster_metadata(
    rank_stage_inputs.graph,
    rank_stage_inputs.prep.nodes,
    rank_stage_inputs.prep.edges,
    rank_data.groups,
    rank_data.ranks,
    rank_stage_inputs.prep.node_order,
    rank_data.edge_tail,
    rank_data.edge_head,
    rank_stage_inputs.prep.rankdir == RankDir::LR || rank_stage_inputs.prep.rankdir == RankDir::RL,
  )
}

///|
/// Graphviz parity: dot rank-stage ordering input payload assembly reads prep/
/// rank outputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_inputs_for_dot_rank_stage(
  rank_stage_inputs : DotRankStageInputs,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
) -> DotRankStageOrderingInputs {
  {
    graph: rank_stage_inputs.graph,
    nodes: rank_stage_inputs.prep.nodes,
    edges: rank_stage_inputs.prep.edges,
    edge_tail: rank_data.edge_tail,
    edge_head: rank_data.edge_head,
    edge_reversed: rank_data.edge_reversed,
    edge_out_order: rank_data.edge_out_order,
    ranks: rank_data.ranks,
    groups: rank_data.groups,
    rank_keys: rank_data.rank_keys,
    node_order: rank_stage_inputs.prep.node_order,
    order_sizes: rank_stage_inputs.prep.order_sizes,
    nodesep_pt: rank_heights.nodesep_pt,
    has_edge_labels: rank_stage_inputs.prep.has_edge_labels,
    rankdir: rank_stage_inputs.prep.rankdir,
    cluster_meta,
    port_order_positions: rank_stage_inputs.prep.port_order_positions,
    port_order_contrib: rank_stage_inputs.prep.port_order_contrib,
  }
}

///|
/// Graphviz parity: ordering+vnode typed payload extraction reads rank-stage
/// ordering inputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_and_vnodes_inputs_from_dot_rank_stage_inputs(
  ordering_inputs : DotRankStageOrderingInputs,
) -> OrderingAndVnodesInputs {
  build_ordering_and_vnodes_inputs(
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
/// Graphviz parity: ordering/vnode stage consumes rank-stage ordering payload
/// with unchanged Graphviz call wiring.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_for_dot_rank_stage_from_inputs(
  ordering_inputs : DotRankStageOrderingInputs,
) -> OrderingResult {
  let ordering_and_vnodes_inputs =
    build_ordering_and_vnodes_inputs_from_dot_rank_stage_inputs(
      ordering_inputs,
    )
  compute_ordering_and_vnodes(
    ordering_and_vnodes_inputs.graph,
    ordering_and_vnodes_inputs.nodes,
    ordering_and_vnodes_inputs.edges,
    ordering_and_vnodes_inputs.edge_tail,
    ordering_and_vnodes_inputs.edge_head,
    ordering_and_vnodes_inputs.edge_reversed,
    ordering_and_vnodes_inputs.edge_out_order,
    ordering_and_vnodes_inputs.ranks,
    ordering_and_vnodes_inputs.groups,
    ordering_and_vnodes_inputs.rank_keys,
    ordering_and_vnodes_inputs.node_order,
    ordering_and_vnodes_inputs.order_sizes,
    ordering_and_vnodes_inputs.nodesep_pt,
    ordering_and_vnodes_inputs.has_edge_labels,
    ordering_and_vnodes_inputs.rankdir,
    ordering_and_vnodes_inputs.cluster_meta,
    ordering_and_vnodes_inputs.port_order_positions,
    ordering_and_vnodes_inputs.port_order_contrib,
  )
}

///|
/// Graphviz parity: ordering/vnode stage consumes rank data, rank heights,
/// and cluster metadata with unchanged Graphviz call wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_for_dot_rank_stage(
  rank_stage_inputs : DotRankStageInputs,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
) -> OrderingResult {
  let ordering_inputs =
    build_ordering_inputs_for_dot_rank_stage(
      rank_stage_inputs,
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
  rank_stage_inputs : DotRankStageInputs,
  rank_data : RankData,
) -> RankHeights {
  compute_rank_heights(
    rank_stage_inputs.graph,
    rank_stage_inputs.prep.edges,
    rank_data.ranks,
    rank_data.groups,
    rank_data.rank_keys,
    rank_data.all_ranks,
    rank_stage_inputs.prep.sizes,
    rank_data.self_edge_labels,
    rank_stage_inputs.prep.rankdir,
    rank_stage_inputs.prep.nodesep_in,
    rank_stage_inputs.prep.ranksep_in,
    rank_stage_inputs.prep.has_edge_labels,
  )
}

///|
/// Graphviz parity: rank-data creation emits the same rank trace points before
/// downstream stage assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_data_for_dot_rank_stage(
  rank_stage_inputs : DotRankStageInputs,
) -> RankData {
  let rank_data =
    compute_rank_data(
      rank_stage_inputs.graph,
      rank_stage_inputs.prep.nodes,
      rank_stage_inputs.prep.edges,
      rank_stage_inputs.prep.has_edge_labels,
    )
  dot_trace("layout_dot: ranks computed")
  dot_trace_edges(
    rank_stage_inputs.prep.edges,
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
/// Graphviz parity: dot rank/order stage consumes typed rank-stage inputs and
/// keeps rank-data/rank-height/cluster/order compute sequence unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_dot_rank_stage_from_inputs(
  rank_stage_inputs : DotRankStageInputs,
) -> DotRankStage {
  let rank_data =
    build_rank_data_for_dot_rank_stage(rank_stage_inputs)
  let rank_heights =
    build_rank_heights_for_dot_rank_stage(rank_stage_inputs, rank_data)
  let cluster_meta =
    build_cluster_meta_for_dot_rank_stage(rank_stage_inputs, rank_data)
  let ordering =
    build_ordering_for_dot_rank_stage(
      rank_stage_inputs,
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
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
) -> DotRankStage {
  let rank_stage_inputs =
    build_dot_rank_stage_inputs(graph, prep)
  run_dot_rank_stage_from_inputs(rank_stage_inputs)
}

///|
/// Graphviz parity: dot position-stage input payload assembly reads rank-stage
/// artifacts and prep fields without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_position_stage_inputs(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
) -> DotPositionStageInputs {
  {
    graph,
    prep,
    rank_data: rank_stage.rank_data,
    rank_heights: rank_stage.rank_heights,
    cluster_meta: rank_stage.cluster_meta,
    ordering: rank_stage.ordering,
  }
}

///|
/// Graphviz parity: position-stage result wiring forwards rank-stage artifacts
/// directly into compute_positions without remapping.
/// Do not change behavior without updating fixtures/tests.
fn run_dot_position_stage_from_inputs(
  position_stage_inputs : DotPositionStageInputs,
) -> PositionResult {
  compute_positions(
    position_stage_inputs.graph,
    position_stage_inputs.prep,
    position_stage_inputs.rank_data,
    position_stage_inputs.rank_heights,
    position_stage_inputs.cluster_meta,
    position_stage_inputs.ordering,
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
  let position_stage_inputs =
    build_dot_position_stage_inputs(graph, prep, rank_stage)
  run_dot_position_stage_from_inputs(position_stage_inputs)
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
/// Graphviz parity: routing node/port input payload keeps prep and positioned
/// node geometry fields in projection and port-map build order.
/// Do not change behavior without updating fixtures/tests.
priv struct DotRoutingNodeAndPortInputs {
  prep : LayoutPrep
  positions_state : PositionResult
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
/// Graphviz parity: routing edge-solve input payload keeps graph/prep/rank/
/// position and precomputed path/port/tuning fields in call order.
/// Do not change behavior without updating fixtures/tests.
priv struct DotRoutingEdgeSolveInputs {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_stage : DotRankStage
  positions_state : PositionResult
  path_groups : Map[Int, Array[String]]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
  label_edge_counts : Map[String, Int]
  head_port_metrics : HeadPortMetrics
  routing_context : RoutingContext
  enable_complex_tuning : Bool
}

///|
/// Graphviz parity: routing padding/head-port metric input payload keeps
/// prep/rank/position + label-port + tuning fields in compute order.
/// Do not change behavior without updating fixtures/tests.
priv struct DotRoutingPaddingAndHeadPortMetricsInputs {
  prep : LayoutPrep
  rank_stage : DotRankStage
  positions_state : PositionResult
  label_ports_map : Map[String, Map[String, RecordPort]]
  enable_complex_tuning : Bool
}

///|
/// Graphviz parity: routing edge/padding input payload keeps graph/prep/rank/
/// position and spatial+tuning fields in stage call order.
/// Do not change behavior without updating fixtures/tests.
priv struct DotRoutingEdgesAndPaddingInputs {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_stage : DotRankStage
  positions_state : PositionResult
  routing_spatial_data : DotRoutingSpatialData
  routing_label_and_tuning_data : DotRoutingLabelAndTuningData
}

///|
priv struct DotRoutingSpatialAndTuningData {
  routing_spatial_data : DotRoutingSpatialData
  routing_label_and_tuning_data : DotRoutingLabelAndTuningData
}

///|
/// Graphviz parity: routing path-context input payload keeps prep/rank/position
/// and cluster-bbox fields in path-context build order.
/// Do not change behavior without updating fixtures/tests.
priv struct DotRoutingPathContextInputs {
  prep : LayoutPrep
  rank_stage : DotRankStage
  positions_state : PositionResult
  cluster_bboxes : Map[String, @geom.Rect]
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
/// Graphviz parity: routing context is assembled from typed path-context inputs,
/// final ordering, vnode, rank, and cluster bbox data without remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_context_for_stage(
  routing_path_context_inputs : DotRoutingPathContextInputs,
  path_groups : Map[Int, Array[String]],
) -> RoutingContext {
  prepare_routing_context(
    routing_path_context_inputs.prep.nodes,
    routing_path_context_inputs.prep.edges,
    routing_path_context_inputs.rank_stage.rank_data.edge_tail,
    routing_path_context_inputs.rank_stage.rank_data.edge_head,
    routing_path_context_inputs.prep.sizes,
    routing_path_context_inputs.prep.rankdir,
    routing_path_context_inputs.prep.record_orientation,
    routing_path_context_inputs.rank_stage.rank_data.ranks,
    routing_path_context_inputs.rank_stage.ordering.ordered_groups,
    path_groups,
    routing_path_context_inputs.rank_stage.rank_heights.nodesep_pt,
    routing_path_context_inputs.rank_stage.ordering.vnode_info,
    routing_path_context_inputs.positions_state.vnode_positions,
    routing_path_context_inputs.cluster_bboxes,
  )
}

///|
/// Graphviz parity: routing path-context input payload assembly reads typed
/// edge/padding stage inputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_path_context_inputs_for_stage(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
) -> DotRoutingPathContextInputs {
  {
    prep: routing_inputs.prep,
    rank_stage: routing_inputs.rank_stage,
    positions_state: routing_inputs.positions_state,
    cluster_bboxes: routing_inputs.routing_spatial_data.cluster_bboxes,
  }
}

///|
/// Graphviz parity: routing path-context execution consumes typed stage payload
/// while preserving path-group selection then context-assembly order.
/// Do not change behavior without updating fixtures/tests.
fn run_routing_path_context_from_inputs(
  routing_path_context_inputs : DotRoutingPathContextInputs,
) -> DotRoutingPathContextData {
  // Graphviz parity: pathplan uses final x-order (after positioning) with vnodes.
  let path_groups =
    build_path_groups_for_routing_stage(
      routing_path_context_inputs.positions_state,
      routing_path_context_inputs.rank_stage.ordering,
    )
  let routing_context =
    build_routing_context_for_stage(
      routing_path_context_inputs,
      path_groups,
    )
  { path_groups, routing_context }
}

///|
/// Graphviz parity: routing path groups are selected first, then the routing
/// context is derived from those groups and cluster bboxes.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_path_context_data_for_stage(
  routing_path_context_inputs : DotRoutingPathContextInputs,
) -> DotRoutingPathContextData {
  run_routing_path_context_from_inputs(routing_path_context_inputs)
}

///|
/// Graphviz parity: routing cluster bboxes are derived from typed routing-stage
/// inputs, positioned nodes, and rank/cluster maps before spline routing.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_bboxes_for_routing_stage(
  routing_stage_inputs : DotRoutingStageInputs,
  nodes_out : Array[DotLayoutNode],
) -> Map[String, @geom.Rect] {
  compute_cluster_bboxes_for_routing(
    routing_stage_inputs.graph,
    nodes_out,
    routing_stage_inputs.positions_state.cluster_ln_x,
    routing_stage_inputs.positions_state.cluster_rn_x,
    routing_stage_inputs.positions_state.cluster_bbox_heights,
    routing_stage_inputs.prep.rankdir,
    routing_stage_inputs.rank_stage.rank_data.ranks,
    routing_stage_inputs.positions_state.rank_y,
    routing_stage_inputs.positions_state.rank_ht1,
    routing_stage_inputs.positions_state.rank_ht2,
  )
}

///|
/// Graphviz parity: routing spatial output object consumes typed routing-stage
/// inputs and node/port precompute output without remapping fields.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_output_from_node_port_data_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
  routing_node_and_port_data : DotRoutingNodeAndPortData,
) -> DotRoutingSpatialData {
  let cluster_bboxes =
    build_cluster_bboxes_for_routing_stage(
      routing_stage_inputs,
      routing_node_and_port_data.nodes_out,
    )
  {
    nodes_out: routing_node_and_port_data.nodes_out,
    label_ports_map: routing_node_and_port_data.label_ports_map,
    label_ports_raw: routing_node_and_port_data.label_ports_raw,
    cluster_bboxes,
  }
}

///|
/// Graphviz parity: routing spatial precompute consumes typed routing-stage
/// inputs and keeps node/port + cluster-bbox computation order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_data_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
) -> DotRoutingSpatialData {
  let routing_node_and_port_data =
    build_routing_node_and_port_data_for_stage(routing_stage_inputs)
  build_routing_spatial_output_from_node_port_data_for_stage(
    routing_stage_inputs,
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
/// Graphviz parity: routing node/port input payload assembly reads stage fields
/// without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_node_and_port_inputs_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
) -> DotRoutingNodeAndPortInputs {
  {
    prep: routing_stage_inputs.prep,
    positions_state: routing_stage_inputs.positions_state,
  }
}

///|
/// Graphviz parity: node geometry projection and port-map derivation consume
/// typed stage payload in the same precompute order.
/// Do not change behavior without updating fixtures/tests.
fn run_routing_node_and_port_from_inputs(
  routing_node_and_port_inputs : DotRoutingNodeAndPortInputs,
) -> DotRoutingNodeAndPortData {
  let nodes_out =
    build_layout_nodes(
      routing_node_and_port_inputs.prep.nodes,
      routing_node_and_port_inputs.positions_state.positions,
      routing_node_and_port_inputs.prep.output_sizes,
      routing_node_and_port_inputs.prep.record_orientation,
    )
  let port_maps =
    build_port_layout_maps_for_routing_stage(
      routing_node_and_port_inputs.prep,
      nodes_out,
    )
  build_routing_node_and_port_output_for_stage(nodes_out, port_maps)
}

///|
/// Graphviz parity: node geometry projection and port-map derivation are
/// sequenced together before routing precompute consumption.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_node_and_port_data_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
) -> DotRoutingNodeAndPortData {
  let routing_node_and_port_inputs =
    build_routing_node_and_port_inputs_for_stage(routing_stage_inputs)
  run_routing_node_and_port_from_inputs(routing_node_and_port_inputs)
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
/// Graphviz parity: label-edge counts and complex-tuning gate are read from
/// typed routing-stage inputs before metric derivation and spline routing.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_label_and_tuning_data_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
) -> DotRoutingLabelAndTuningData {
  let label_edge_counts =
    build_label_edge_counts(routing_stage_inputs.prep.edges)
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
/// Graphviz parity: routing padding/head-port metric input payload assembly
/// reads typed edge/padding stage inputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_padding_and_head_port_metrics_inputs_for_stage(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
) -> DotRoutingPaddingAndHeadPortMetricsInputs {
  {
    prep: routing_inputs.prep,
    rank_stage: routing_inputs.rank_stage,
    positions_state: routing_inputs.positions_state,
    label_ports_map: routing_inputs.routing_spatial_data.label_ports_map,
    enable_complex_tuning: routing_inputs.routing_label_and_tuning_data.enable_complex_tuning,
  }
}

///|
/// Graphviz parity: port padding and head-port metrics consume typed metric
/// inputs while preserving compute order before spline routing.
/// Do not change behavior without updating fixtures/tests.
fn run_routing_padding_and_head_port_metrics_from_inputs(
  routing_metric_inputs : DotRoutingPaddingAndHeadPortMetricsInputs,
) -> DotRoutingPaddingAndHeadPortMetrics {
  let (port_pad_below, port_pad_above) =
    compute_port_padding(
      routing_metric_inputs.rank_stage.cluster_meta.has_clusters,
      routing_metric_inputs.prep.has_port_edges,
      routing_metric_inputs.prep.edges,
      routing_metric_inputs.positions_state.positions,
      routing_metric_inputs.label_ports_map,
    )
  let head_port_metrics =
    collect_head_port_metrics(
      routing_metric_inputs.prep.edges,
      routing_metric_inputs.positions_state.positions,
      routing_metric_inputs.prep.sizes,
      routing_metric_inputs.label_ports_map,
      routing_metric_inputs.prep.record_orientation,
      routing_metric_inputs.enable_complex_tuning,
    )
  build_routing_padding_and_head_port_metrics_output_for_stage(
    port_pad_below,
    port_pad_above,
    head_port_metrics,
  )
}

///|
/// Graphviz parity: port padding and head-port metrics are computed from the
/// same inputs and in the same order before spline routing.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_padding_and_head_port_metrics_for_stage(
  routing_metric_inputs : DotRoutingPaddingAndHeadPortMetricsInputs,
) -> DotRoutingPaddingAndHeadPortMetrics {
  run_routing_padding_and_head_port_metrics_from_inputs(routing_metric_inputs)
}

///|
/// Graphviz parity: edge routing call consumes typed edge-solve payload while
/// preserving Graphviz-aligned argument mapping and rankdir override.
/// Do not change behavior without updating fixtures/tests.
fn build_edges_out_for_routing_stage(
  routing_edge_solve_inputs : DotRoutingEdgeSolveInputs,
) -> Array[DotLayoutEdge] {
  let layout_rankdir = RankDir::TB
  route_edges(
    routing_edge_solve_inputs.graph,
    routing_edge_solve_inputs.prep.edges,
    routing_edge_solve_inputs.rank_stage.rank_data.ranks,
    routing_edge_solve_inputs.prep.sizes,
    routing_edge_solve_inputs.prep.record_orientation,
    routing_edge_solve_inputs.prep.rankdir,
    layout_rankdir,
    routing_edge_solve_inputs.prep.splines,
    routing_edge_solve_inputs.positions_state.positions,
    routing_edge_solve_inputs.positions_state.vnode_positions,
    routing_edge_solve_inputs.rank_stage.ordering.vnode_info,
    routing_edge_solve_inputs.positions_state.rank_y,
    routing_edge_solve_inputs.positions_state.rank_ht1,
    routing_edge_solve_inputs.positions_state.rank_ht2,
    routing_edge_solve_inputs.path_groups,
    routing_edge_solve_inputs.rank_stage.rank_heights.nodesep_pt,
    routing_edge_solve_inputs.rank_stage.rank_heights.ranksep_pt,
    routing_edge_solve_inputs.rank_stage.cluster_meta.has_clusters,
    routing_edge_solve_inputs.label_ports_map,
    routing_edge_solve_inputs.label_ports_raw,
    routing_edge_solve_inputs.label_edge_counts,
    routing_edge_solve_inputs.head_port_metrics,
    routing_edge_solve_inputs.positions_state.flat_label_edge_vnodes,
    routing_edge_solve_inputs.routing_context,
    routing_edge_solve_inputs.enable_complex_tuning,
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
/// Graphviz parity: routing edge-solve input payload assembly reads typed
/// edge/padding stage inputs and grouped precompute bundles without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edge_solve_inputs_for_stage(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
  routing_edge_solve_precompute_data : DotRoutingEdgeSolvePrecomputeData,
) -> DotRoutingEdgeSolveInputs {
  {
    graph: routing_inputs.graph,
    prep: routing_inputs.prep,
    rank_stage: routing_inputs.rank_stage,
    positions_state: routing_inputs.positions_state,
    path_groups: routing_edge_solve_precompute_data.routing_path_context_data.path_groups,
    label_ports_map: routing_inputs.routing_spatial_data.label_ports_map,
    label_ports_raw: routing_inputs.routing_spatial_data.label_ports_raw,
    label_edge_counts: routing_inputs.routing_label_and_tuning_data.label_edge_counts,
    head_port_metrics: routing_edge_solve_precompute_data.routing_padding_and_head_port_metrics.head_port_metrics,
    routing_context: routing_edge_solve_precompute_data.routing_path_context_data.routing_context,
    enable_complex_tuning: routing_inputs.routing_label_and_tuning_data.enable_complex_tuning,
  }
}

///|
/// Graphviz parity: routed-edge solve call consumes typed edge-solve payload
/// without remapping stage inputs.
/// Do not change behavior without updating fixtures/tests.
fn run_routing_edge_solve_from_inputs(
  routing_edge_solve_inputs : DotRoutingEdgeSolveInputs,
) -> Array[DotLayoutEdge] {
  build_edges_out_for_routing_stage(routing_edge_solve_inputs)
}

///|
/// Graphviz parity: routed-edge solve dispatch reads typed edge/padding inputs
/// plus grouped edge-solve precompute payload without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edges_from_edge_solve_precompute_data_for_stage(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
  routing_edge_solve_precompute_data : DotRoutingEdgeSolvePrecomputeData,
) -> Array[DotLayoutEdge] {
  let routing_edge_solve_inputs =
    build_routing_edge_solve_inputs_for_stage(
      routing_inputs,
      routing_edge_solve_precompute_data,
    )
  run_routing_edge_solve_from_inputs(routing_edge_solve_inputs)
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
/// Graphviz parity: routing metric precompute extraction reads typed edge/
/// padding inputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_padding_and_head_port_metrics_from_routing_inputs(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
) -> DotRoutingPaddingAndHeadPortMetrics {
  let routing_metric_inputs =
    build_routing_padding_and_head_port_metrics_inputs_for_stage(
      routing_inputs,
    )
  build_routing_padding_and_head_port_metrics_for_stage(routing_metric_inputs)
}

///|
/// Graphviz parity: routing path-context precompute extraction reads typed edge/
/// padding inputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_path_context_data_from_routing_inputs(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
) -> DotRoutingPathContextData {
  let routing_path_context_inputs =
    build_routing_path_context_inputs_for_stage(routing_inputs)
  build_routing_path_context_data_for_stage(routing_path_context_inputs)
}

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edge_solve_precompute_data_for_stage(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
) -> DotRoutingEdgeSolvePrecomputeData {
  let routing_padding_and_head_port_metrics =
    build_routing_padding_and_head_port_metrics_from_routing_inputs(
      routing_inputs,
    )
  let routing_path_context_data =
    build_routing_path_context_data_from_routing_inputs(routing_inputs)
  build_routing_edge_solve_precompute_output_for_stage(
    routing_padding_and_head_port_metrics,
    routing_path_context_data,
  )
}

///|
/// Graphviz parity: routing edge/padding input payload assembly reads typed
/// stage and spatial+tuning bundles without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edges_and_padding_inputs_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
  routing_spatial_and_tuning_data : DotRoutingSpatialAndTuningData,
) -> DotRoutingEdgesAndPaddingInputs {
  {
    graph: routing_stage_inputs.graph,
    prep: routing_stage_inputs.prep,
    rank_stage: routing_stage_inputs.rank_stage,
    positions_state: routing_stage_inputs.positions_state,
    routing_spatial_data: routing_spatial_and_tuning_data.routing_spatial_data,
    routing_label_and_tuning_data: routing_spatial_and_tuning_data.routing_label_and_tuning_data,
  }
}

///|
/// Graphviz parity: routing edge/padding execution consumes typed stage payload
/// while preserving precompute->edge-solve->output order.
/// Do not change behavior without updating fixtures/tests.
fn run_routing_edges_and_padding_from_inputs(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
) -> DotRoutingEdgesAndPaddingData {
  let routing_edge_solve_precompute_data =
    build_routing_edge_solve_precompute_data_for_stage(routing_inputs)
  let edges_out =
    build_routing_edges_from_edge_solve_precompute_data_for_stage(
      routing_inputs,
      routing_edge_solve_precompute_data,
    )
  build_routing_edges_and_padding_output_for_stage(
    edges_out,
    routing_edge_solve_precompute_data.routing_padding_and_head_port_metrics,
  )
}

///|
/// Graphviz parity: routing edge/padding substage consumes typed stage payload
/// and keeps metrics/path-context/edge-solve order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edges_and_padding_data_for_stage(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
) -> DotRoutingEdgesAndPaddingData {
  run_routing_edges_and_padding_from_inputs(routing_inputs)
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
/// Graphviz parity: routing precompute bundle consumes typed routing-stage
/// inputs and keeps spatial then label/tuning derivation order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_and_tuning_data_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
) -> DotRoutingSpatialAndTuningData {
  let routing_spatial_data =
    build_routing_spatial_data_for_stage(routing_stage_inputs)
  let routing_label_and_tuning_data =
    build_routing_label_and_tuning_data_for_stage(routing_stage_inputs)
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
/// Graphviz parity: routing edge/padding derivation from spatial+tuning bundle
/// reads typed routing-stage inputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edges_and_padding_data_from_spatial_tuning_data_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
  routing_spatial_and_tuning_data : DotRoutingSpatialAndTuningData,
) -> DotRoutingEdgesAndPaddingData {
  let routing_inputs =
    build_routing_edges_and_padding_inputs_for_stage(
      routing_stage_inputs,
      routing_spatial_and_tuning_data,
    )
  build_routing_edges_and_padding_data_for_stage(routing_inputs)
}

///|
/// Graphviz parity: routing-stage edge/padding + result assembly consumes
/// spatial+tuning precompute bundle without altering argument wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_routing_stage_from_spatial_tuning_data_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
  routing_spatial_and_tuning_data : DotRoutingSpatialAndTuningData,
) -> DotRoutingStage {
  let routing_edges_and_padding_data =
    build_routing_edges_and_padding_data_from_spatial_tuning_data_for_stage(
      routing_stage_inputs,
      routing_spatial_and_tuning_data,
    )
  build_dot_routing_stage_from_spatial_and_edges_data_for_stage(
    routing_spatial_and_tuning_data.routing_spatial_data,
    routing_edges_and_padding_data,
  )
}

///|
/// Graphviz parity: dot routing-stage input payload assembly reads graph/prep/
/// rank-stage/position-stage fields without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_routing_stage_inputs(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
) -> DotRoutingStageInputs {
  { graph, prep, rank_stage, positions_state }
}

///|
/// Graphviz parity: dot routing stage consumes typed routing input payload and
/// preserves Graphviz routing-stage precompute and solve order.
/// Do not change behavior without updating fixtures/tests.
fn run_dot_routing_stage_from_inputs(
  routing_stage_inputs : DotRoutingStageInputs,
) -> DotRoutingStage {
  let routing_spatial_and_tuning_data =
    build_routing_spatial_and_tuning_data_for_stage(routing_stage_inputs)
  build_dot_routing_stage_from_spatial_tuning_data_for_stage(
    routing_stage_inputs,
    routing_spatial_and_tuning_data,
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
  let routing_stage_inputs =
    build_dot_routing_stage_inputs(
      graph,
      prep,
      rank_stage,
      positions_state,
    )
  run_dot_routing_stage_from_inputs(routing_stage_inputs)
}
