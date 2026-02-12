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
/// Graphviz parity: dot rank/order stage consumes typed rank-stage inputs and
/// keeps rank-data/rank-height/cluster/order compute sequence unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_dot_rank_stage_from_inputs(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
) -> DotRankStage {
  // Graphviz parity: rank-data creation emits the same rank trace
  // points before downstream stage assembly.
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
  // Graphviz parity: rank-height stage consumes computed ranks/groups
  // and spacing inputs with unchanged Graphviz argument wiring.
  let rank_heights =
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
  // Graphviz parity: cluster metadata in rank/order stage uses
  // the same rank-group and edge endpoint wiring as Graphviz ordering setup.
  let cluster_meta =
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
  // Graphviz parity: ordering/vnode stage consumes rank data, rank heights,
  // and cluster metadata with unchanged Graphviz call wiring.
  // Graphviz parity: dot rank-stage ordering input payload assembly
  // reads prep/rank outputs without argument reordering.
  let ordering_inputs : DotRankStageOrderingInputs = {
    graph: graph,
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
  // Graphviz parity: ordering/vnode stage consumes rank-stage ordering
  // payload with unchanged Graphviz call wiring.
  // Graphviz parity: ordering+vnode typed payload extraction reads
  // rank-stage ordering inputs without argument reordering.
  let ordering_and_vnodes_inputs =
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
  let ordering =
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
  // Graphviz parity: rank-stage result object keeps computed
  // rank/cluster/order artifacts unchanged and emits rank-order trace.
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
  // Graphviz parity: dot rank-stage forwards graph/prep directly to
  // rank/order execution without argument reordering.
  run_dot_rank_stage_from_inputs(graph, prep)
}

///|
/// Graphviz parity: dot position stage mirrors refs/graphviz/lib/dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_position_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
) -> PositionResult {
  // Graphviz parity: position-stage result wiring forwards rank-stage
  // artifacts directly into compute_positions without remapping.
  compute_positions(
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
/// Graphviz parity: routing spatial precompute consumes typed routing-stage
/// inputs and keeps node/port + cluster-bbox computation order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_data_for_stage(
  routing_stage_inputs : DotRoutingStageInputs,
) -> DotRoutingSpatialData {
  // Graphviz parity: routing node/port input payload assembly reads
  // stage fields without argument reordering.
  let routing_node_and_port_inputs : DotRoutingNodeAndPortInputs = {
    prep: routing_stage_inputs.prep,
    positions_state: routing_stage_inputs.positions_state,
  }
  // Graphviz parity: node geometry projection and port-map derivation
  // consume typed stage payload in the same precompute order.
  let nodes_out =
    build_layout_nodes(
      routing_node_and_port_inputs.prep.nodes,
      routing_node_and_port_inputs.positions_state.positions,
      routing_node_and_port_inputs.prep.output_sizes,
      routing_node_and_port_inputs.prep.record_orientation,
    )
  // Graphviz parity: routing port maps are built from final node
  // geometry and rankdir/port-edge flags before padding and edge routing.
  let port_maps =
    build_port_layout_maps(
      nodes_out,
      routing_node_and_port_inputs.prep.output_sizes,
      routing_node_and_port_inputs.prep.record_orientation,
      routing_node_and_port_inputs.prep.rankdir,
      routing_node_and_port_inputs.prep.has_port_edges,
    )
  let routing_node_and_port_data : DotRoutingNodeAndPortData = {
    nodes_out,
    label_ports_map: port_maps.label_ports_map,
    label_ports_raw: port_maps.label_ports_raw,
  }
  // Graphviz parity: routing spatial output object consumes typed
  // routing-stage inputs and node/port precompute output without remapping.
  // Graphviz parity: routing cluster bboxes are derived from typed
  // routing-stage inputs, positioned nodes, and rank/cluster maps.
  let cluster_bboxes =
    compute_cluster_bboxes_for_routing(
      routing_stage_inputs.graph,
      routing_node_and_port_data.nodes_out,
      routing_stage_inputs.positions_state.cluster_ln_x,
      routing_stage_inputs.positions_state.cluster_rn_x,
      routing_stage_inputs.positions_state.cluster_bbox_heights,
      routing_stage_inputs.prep.rankdir,
      routing_stage_inputs.rank_stage.rank_data.ranks,
      routing_stage_inputs.positions_state.rank_y,
      routing_stage_inputs.positions_state.rank_ht1,
      routing_stage_inputs.positions_state.rank_ht2,
    )
  {
    nodes_out: routing_node_and_port_data.nodes_out,
    label_ports_map: routing_node_and_port_data.label_ports_map,
    label_ports_raw: routing_node_and_port_data.label_ports_raw,
    cluster_bboxes,
  }
}

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_edge_solve_precompute_data_for_stage(
  routing_inputs : DotRoutingEdgesAndPaddingInputs,
) -> DotRoutingEdgeSolvePrecomputeData {
  // Graphviz parity: routing padding/head-port metric input payload
  // assembly reads typed edge/padding stage inputs without argument reordering.
  let routing_metric_inputs : DotRoutingPaddingAndHeadPortMetricsInputs = {
    prep: routing_inputs.prep,
    rank_stage: routing_inputs.rank_stage,
    positions_state: routing_inputs.positions_state,
    label_ports_map: routing_inputs.routing_spatial_data.label_ports_map,
    enable_complex_tuning: routing_inputs.routing_label_and_tuning_data.enable_complex_tuning,
  }
  // Graphviz parity: port padding and head-port metrics consume
  // typed metric inputs while preserving compute order before spline routing.
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
  let routing_padding_and_head_port_metrics : DotRoutingPaddingAndHeadPortMetrics = {
    port_pad_below,
    port_pad_above,
    head_port_metrics,
  }
  // Graphviz parity: routing path-context input payload assembly reads typed
  // edge/padding stage inputs without argument reordering.
  let routing_path_context_inputs : DotRoutingPathContextInputs = {
    prep: routing_inputs.prep,
    rank_stage: routing_inputs.rank_stage,
    positions_state: routing_inputs.positions_state,
    cluster_bboxes: routing_inputs.routing_spatial_data.cluster_bboxes,
  }
  // Graphviz parity: routing path-context execution consumes typed
  // stage payload while preserving path-group selection then context-assembly order.
  // Graphviz parity: path-groups selection prefers positioned x-groups,
  // then vnode-expanded order groups, then base order groups.
  // Graphviz parity: pathplan uses final x-order (after positioning) with vnodes.
  let path_groups =
    if routing_path_context_inputs.positions_state.x_groups.length() > 0 {
      routing_path_context_inputs.positions_state.x_groups
    } else if routing_path_context_inputs.rank_stage.ordering.ordered_groups_with_vnodes.length() > 0 {
      routing_path_context_inputs.rank_stage.ordering.ordered_groups_with_vnodes
    } else {
      routing_path_context_inputs.rank_stage.ordering.ordered_groups
    }
  // Graphviz parity: routing context is assembled from typed
  // path-context inputs, final ordering, vnode/rank, and cluster bboxes.
  let routing_context =
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
  let routing_path_context_data : DotRoutingPathContextData = {
    path_groups,
    routing_context,
  }
  {
    routing_padding_and_head_port_metrics,
    routing_path_context_data,
  }
}

///|
/// Graphviz parity: dot routing stage consumes typed routing input payload and
/// preserves Graphviz routing-stage precompute and solve order.
/// Do not change behavior without updating fixtures/tests.
fn run_dot_routing_stage_from_inputs(
  routing_stage_inputs : DotRoutingStageInputs,
) -> DotRoutingStage {
  let routing_spatial_data =
    build_routing_spatial_data_for_stage(routing_stage_inputs)
  // Graphviz parity: label-edge counts and complex-tuning gate
  // are read from typed routing-stage inputs before metric derivation.
  let routing_label_and_tuning_data : DotRoutingLabelAndTuningData = {
    label_edge_counts: build_label_edge_counts(routing_stage_inputs.prep.edges),
    enable_complex_tuning: complex_tuning_enabled(),
  }
  let routing_spatial_and_tuning_data : DotRoutingSpatialAndTuningData = {
    routing_spatial_data,
    routing_label_and_tuning_data,
  }
  // Graphviz parity: routing edge/padding input payload assembly reads
  // typed stage and spatial+tuning bundles without argument reordering.
  let routing_inputs : DotRoutingEdgesAndPaddingInputs = {
    graph: routing_stage_inputs.graph,
    prep: routing_stage_inputs.prep,
    rank_stage: routing_stage_inputs.rank_stage,
    positions_state: routing_stage_inputs.positions_state,
    routing_spatial_data: routing_spatial_and_tuning_data.routing_spatial_data,
    routing_label_and_tuning_data: routing_spatial_and_tuning_data.routing_label_and_tuning_data,
  }
  // Graphviz parity: routing edge/padding execution consumes typed
  // stage payload while preserving precompute->edge-solve->output order.
  let routing_edge_solve_precompute_data =
    build_routing_edge_solve_precompute_data_for_stage(routing_inputs)
  // Graphviz parity: routed-edge solve dispatch reads typed edge/padding
  // inputs plus grouped edge-solve precompute payload without argument reordering.
  // Graphviz parity: routing edge-solve input payload assembly
  // reads typed edge/padding inputs and grouped precompute bundles.
  let routing_edge_solve_inputs : DotRoutingEdgeSolveInputs = {
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
  // Graphviz parity: edge routing call consumes typed edge-solve
  // payload while preserving Graphviz-aligned argument mapping.
  let layout_rankdir = RankDir::TB
  let edges_out =
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
  let routing_edges_and_padding_data : DotRoutingEdgesAndPaddingData = {
    edges_out,
    port_pad_below: routing_edge_solve_precompute_data.routing_padding_and_head_port_metrics.port_pad_below,
    port_pad_above: routing_edge_solve_precompute_data.routing_padding_and_head_port_metrics.port_pad_above,
  }
  // Graphviz parity: routing stage result object is built directly
  // from routed edges and computed padding, with trace emission preserved.
  dot_trace("layout_dot: edges routed")
  {
    nodes_out: routing_spatial_and_tuning_data.routing_spatial_data.nodes_out,
    edges_out: routing_edges_and_padding_data.edges_out,
    port_pad_below: routing_edges_and_padding_data.port_pad_below,
    port_pad_above: routing_edges_and_padding_data.port_pad_above,
  }
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
  let routing_stage_inputs : DotRoutingStageInputs = {
    // Graphviz parity: dot routing-stage input payload assembly reads graph/prep/
    // rank-stage/position-stage fields without argument reordering.
    graph,
    prep,
    rank_stage,
    positions_state,
  }
  run_dot_routing_stage_from_inputs(routing_stage_inputs)
}
