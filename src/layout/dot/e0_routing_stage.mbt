///|
/// Stage E routing-stage orchestrator and spatial/ratio helpers.

///|
priv struct RoutingSpatialData {
  nodes_out : Array[DotLayoutNode]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
/// Graphviz parity: routing spatial precompute consumes typed routing-stage
/// inputs and keeps node/port + cluster-bbox computation order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_data(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  ranks : Map[String, Int],
  positions_state : PositionResult,
) -> RoutingSpatialData {
  // Graphviz parity: node geometry projection and port-map derivation
  // consume stage inputs in the same precompute order.
  let nodes_out =
    build_layout_nodes(
      prep.nodes,
      positions_state.positions,
      prep.output_sizes,
      prep.record_orientation,
    )
  // Graphviz parity: routing port maps are built from final node
  // geometry and rankdir/port-edge flags before padding and edge routing.
  let port_maps =
    build_port_layout_maps(
      nodes_out,
      prep.output_sizes,
      prep.record_orientation,
      prep.rankdir,
      prep.has_port_edges,
    )
  let label_ports_map = port_maps.label_ports_map
  let label_ports_raw = port_maps.label_ports_raw
  // Graphviz parity: routing spatial output object consumes typed
  // routing-stage inputs and node/port precompute output without remapping.
  // Graphviz parity: routing cluster bboxes are derived from typed
  // routing-stage inputs, positioned nodes, and rank/cluster maps.
  let cluster_bboxes =
    compute_cluster_route_bboxes(
      graph,
      nodes_out,
      positions_state.cluster_ln_x,
      positions_state.cluster_rn_x,
      positions_state.cluster_bbox_heights,
      prep.rankdir,
      ranks,
      positions_state.rank_y,
      positions_state.rank_ht1,
      positions_state.rank_ht2,
    )
  { nodes_out, label_ports_map, label_ports_raw, cluster_bboxes }
}

///|
priv struct DotRoutingStageOutput {
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  port_pad_below : Double
  port_pad_above : Double
}

///|
priv struct RoutingRatioAdjustedData {
  ratio_scaled : Bool
  ratio_sx : Double
  ratio_sy : Double
  positions_state : PositionResult
  cluster_bboxes : Map[String, @geom.Rect]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
/// Graphviz parity: ratio=fill scaling is resolved once before routing
/// precompute/edge solve and keeps position/cluster/port maps in sync.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_ratio_adjusted_data(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  nodes_out : Array[DotLayoutNode],
  positions_state : PositionResult,
  cluster_bboxes : Map[String, @geom.Rect],
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
) -> RoutingRatioAdjustedData {
  let routing_bbox =
    compute_dot_bbox(
      nodes_out,
      rank_data.all_ranks,
      prep.sizes,
      positions_state.rank_y,
      positions_state.rank_ht1,
      positions_state.rank_ht2,
    )
  let (ratio_sx, ratio_sy) =
    match ratio_fill_scale_factors(graph, routing_bbox, prep.rankdir) {
      Some(scale_factors) =>
        if scale_factors.sx != 1.0 || scale_factors.sy != 1.0 {
          (scale_factors.sx, scale_factors.sy)
        } else {
          (1.0, 1.0)
        }
      None => (1.0, 1.0)
    }
  let ratio_scaled = ratio_sx != 1.0 || ratio_sy != 1.0
  if !ratio_scaled {
    return {
      ratio_scaled,
      ratio_sx,
      ratio_sy,
      positions_state,
      cluster_bboxes,
      label_ports_map,
      label_ports_raw,
    }
  }
  let adjusted_positions_state : PositionResult = {
    x_groups: positions_state.x_groups,
    rank_y: scale_double_map_rounded(positions_state.rank_y, ratio_sy),
    positions: scale_point_map_rounded(positions_state.positions, ratio_sx, ratio_sy),
    vnode_positions:
      scale_point_map_rounded(
        positions_state.vnode_positions,
        ratio_sx,
        ratio_sy,
      ),
    cluster_ln_x: scale_named_double_map(positions_state.cluster_ln_x, ratio_sx),
    cluster_rn_x: scale_named_double_map(positions_state.cluster_rn_x, ratio_sx),
    flat_label_edge_vnodes: positions_state.flat_label_edge_vnodes,
    rank_ht1: positions_state.rank_ht1,
    rank_ht2: positions_state.rank_ht2,
    cluster_bbox_heights: positions_state.cluster_bbox_heights,
  }
  {
    ratio_scaled,
    ratio_sx,
    ratio_sy,
    positions_state: adjusted_positions_state,
    cluster_bboxes: scale_rect_map(cluster_bboxes, ratio_sx, ratio_sy),
    label_ports_map: scale_record_port_maps(label_ports_map, ratio_sx, ratio_sy),
    label_ports_raw: scale_record_port_maps(label_ports_raw, ratio_sx, ratio_sy),
  }
}

///|
/// Graphviz parity: dot routing stage mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures), with typed stage payload.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_routing_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  positions_state : PositionResult,
) -> DotRoutingStageOutput {
  let spatial_data =
    build_routing_spatial_data(graph, prep, rank_data.ranks, positions_state)
  let nodes_out = spatial_data.nodes_out
  let ratio_adjusted_data =
    build_routing_ratio_adjusted_data(
      graph,
      prep,
      rank_data,
      nodes_out,
      positions_state,
      spatial_data.cluster_bboxes,
      spatial_data.label_ports_map,
      spatial_data.label_ports_raw,
    )
  let ratio_scaled = ratio_adjusted_data.ratio_scaled
  let ratio_sx = ratio_adjusted_data.ratio_sx
  let ratio_sy = ratio_adjusted_data.ratio_sy
  let routing_cluster_bboxes = ratio_adjusted_data.cluster_bboxes
  let routing_label_ports_map = ratio_adjusted_data.label_ports_map
  let routing_label_ports_raw = ratio_adjusted_data.label_ports_raw
  let routing_sizes =
    // Graphviz parity: route spline clipping keeps node extents in pre-ratio units.
    prep.sizes
  let routing_positions_state = ratio_adjusted_data.positions_state
  // Graphviz parity: label-edge counts and complex-tuning gate
  // are read before routing precompute and edge solve.
  let label_edge_counts = build_label_edge_counts(prep.edges)
  let enable_complex_tuning = complex_tuning_enabled()
  // Graphviz parity: routing edge/padding execution consumes typed
  // stage payload while preserving precompute->edge-solve->output order.
  let precompute_data =
    build_routing_precompute_data(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      routing_positions_state,
      routing_label_ports_map,
      routing_cluster_bboxes,
      routing_sizes,
      enable_complex_tuning,
    )
  let port_pad_below = precompute_data.port_pad_below
  let port_pad_above = precompute_data.port_pad_above
  let head_port_metrics = precompute_data.head_port_metrics
  let path_groups = precompute_data.path_groups
  let routing_context = precompute_data.routing_context
  // Graphviz parity: routed-edge solve dispatch reads typed edge/padding
  // inputs plus grouped edge-solve precompute payload without argument reordering.
  // Graphviz parity: edge routing call consumes edge/padding fields plus
  // grouped precompute payload while preserving Graphviz-aligned argument mapping.
  let edges_routed =
    route_edges_for_dot({
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      routing_positions_state,
      routing_label_ports_map,
      routing_label_ports_raw,
      routing_sizes,
      path_groups,
      routing_context,
      label_edge_counts,
      head_port_metrics,
      enable_complex_tuning,
    })
  let edges_out =
    if ratio_scaled {
      scale_edge_layout_output(edges_routed, 1.0 / ratio_sx, 1.0 / ratio_sy)
    } else {
      edges_routed
    }
  // Graphviz parity: routing stage result object is built directly
  // from routed edges and computed padding.
  { nodes_out, edges_out, port_pad_below, port_pad_above }
}
