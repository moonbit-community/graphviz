///|
priv struct DotRankStage {
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
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
  compute_ordering_and_vnodes(
    graph,
    prep.nodes,
    prep.edges,
    rank_data.edge_tail,
    rank_data.edge_head,
    rank_data.edge_reversed,
    rank_data.edge_out_order,
    rank_data.ranks,
    rank_data.groups,
    rank_data.rank_keys,
    prep.node_order,
    prep.order_sizes,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    prep.rankdir,
    cluster_meta,
    prep.port_order_positions,
    prep.port_order_contrib,
  )
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
  dot_trace("layout_dot: rank order computed")
  { rank_data, rank_heights, cluster_meta, ordering }
}

///|
/// Graphviz parity: dot position stage mirrors refs/graphviz/lib/dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_position_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
) -> PositionResult {
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
  let nodes_out = routing_node_and_port_data.nodes_out
  let label_ports_map = routing_node_and_port_data.label_ports_map
  let label_ports_raw = routing_node_and_port_data.label_ports_raw
  let cluster_bboxes =
    build_cluster_bboxes_for_routing_stage(
      graph,
      rank_stage,
      positions_state,
      nodes_out,
      prep.rankdir,
    )
  { nodes_out, label_ports_map, label_ports_raw, cluster_bboxes }
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
  {
    nodes_out,
    label_ports_map: port_maps.label_ports_map,
    label_ports_raw: port_maps.label_ports_raw,
  }
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
  { label_edge_counts, enable_complex_tuning }
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
  { port_pad_below, port_pad_above, head_port_metrics }
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
/// Graphviz parity: dot splines stage mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_routing_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
) -> DotRoutingStage {
  let routing_spatial_data =
    build_routing_spatial_data_for_stage(
      graph,
      prep,
      rank_stage,
      positions_state,
    )
  let nodes_out = routing_spatial_data.nodes_out
  let label_ports_map = routing_spatial_data.label_ports_map
  let label_ports_raw = routing_spatial_data.label_ports_raw
  let cluster_bboxes = routing_spatial_data.cluster_bboxes
  let routing_label_and_tuning_data =
    build_routing_label_and_tuning_data_for_stage(prep)
  let label_edge_counts = routing_label_and_tuning_data.label_edge_counts
  let enable_complex_tuning =
    routing_label_and_tuning_data.enable_complex_tuning
  let routing_padding_and_head_port_metrics =
    build_routing_padding_and_head_port_metrics_for_stage(
      prep,
      rank_stage,
      positions_state,
      label_ports_map,
      enable_complex_tuning,
    )
  let port_pad_below =
    routing_padding_and_head_port_metrics.port_pad_below
  let port_pad_above =
    routing_padding_and_head_port_metrics.port_pad_above
  let head_port_metrics =
    routing_padding_and_head_port_metrics.head_port_metrics
  let routing_path_context_data =
    build_routing_path_context_data_for_stage(
      prep,
      rank_stage,
      positions_state,
      cluster_bboxes,
    )
  let path_groups = routing_path_context_data.path_groups
  let routing_context = routing_path_context_data.routing_context
  let edges_out =
    build_edges_out_for_routing_stage(
      graph,
      prep,
      rank_stage,
      positions_state,
      path_groups,
      label_ports_map,
      label_ports_raw,
      label_edge_counts,
      head_port_metrics,
      routing_context,
      enable_complex_tuning,
    )
  build_dot_routing_stage_result_from_edges_for_stage(
    nodes_out,
    edges_out,
    port_pad_below,
    port_pad_above,
  )
}
