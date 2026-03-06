///|
/// Stage E routing stage file: orchestrator for routing spatial/precompute/
/// ratio/bridge components.

///|
/// Graphviz parity: routing stage payload keeps stage outputs and context maps
/// grouped so Stage E wiring remains explicit and stable.
priv struct DotRoutingStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  positions_state : PositionResult
}

///|
priv struct DotRoutingStageOutput {
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  port_pad_below : Double
  port_pad_above : Double
}

///|
/// Graphviz parity: dot routing stage mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures), with typed stage payload.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_routing_stage(
  input : DotRoutingStageInput,
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
  let label_edge_counts =
    @routing.build_label_edge_counts(
      prep.edges,
      (edge) => edge_mid_label_text(edge) is Some(_),
    )
  let enable_complex_tuning = @routing.complex_tuning_enabled()
  // Graphviz parity: routing edge/padding execution consumes typed
  // stage payload while preserving precompute->edge-solve->output order.
  let precompute_data =
    build_routing_precompute_data(
      {
        prep,
        rank_data,
        rank_heights,
        cluster_meta,
        ordering,
        positions_state: routing_positions_state,
        label_ports_map: routing_label_ports_map,
        cluster_bboxes: routing_cluster_bboxes,
        sizes: routing_sizes,
        enable_complex_tuning,
      },
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
///|
/// Stage E ratio=fill routing adjustment helpers.

///|
/// Graphviz parity: ratio-adjust payload keeps ratio inputs grouped so the
/// pre-routing scaling boundary remains explicit and stable.
priv struct RoutingRatioAdjustInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  nodes_out : Array[DotLayoutNode]
  positions_state : PositionResult
  cluster_bboxes : Map[String, @geom.Rect]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
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
  input : RoutingRatioAdjustInput,
) -> RoutingRatioAdjustedData {
  let graph = input.graph
  let prep = input.prep
  let rank_data = input.rank_data
  let nodes_out = input.nodes_out
  let positions_state = input.positions_state
  let routing_bbox =
    compute_dot_bbox(
      {
        nodes_out,
        all_ranks: rank_data.all_ranks,
        sizes: prep.sizes,
        rank_y: positions_state.rank_y,
        rank_ht1: positions_state.rank_ht1,
        rank_ht2: positions_state.rank_ht2,
      },
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
      cluster_bboxes: input.cluster_bboxes,
      label_ports_map: input.label_ports_map,
      label_ports_raw: input.label_ports_raw,
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
    cluster_bboxes: scale_rect_map(input.cluster_bboxes, ratio_sx, ratio_sy),
    label_ports_map:
      scale_record_port_maps(input.label_ports_map, ratio_sx, ratio_sy),
    label_ports_raw:
      scale_record_port_maps(input.label_ports_raw, ratio_sx, ratio_sy),
  }
}
///|
/// Stage E routing-context precompute and edge metric helpers.

///|
/// Graphviz parity: routing precompute payload keeps context snapshots grouped
/// so port metrics and path-context wiring stay explicit and stable.
priv struct RoutingPrecomputeInput {
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  positions_state : PositionResult
  label_ports_map : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
  sizes : Map[String, NodeSize]
  enable_complex_tuning : Bool
}

///|
type RoutingPrecomputeData = @routing.RoutingPrecomputePipelineOutput

///|
/// Graphviz parity: complex head-port tuning keys match dotsplines behavior:
/// explicit port key when present, otherwise record-shape node key.
fn routing_head_metric_key(edge : @cgraph.Edge) -> String {
  let head_name = edge.head().name()
  let head_port = @dot_shared.port_key(edge.head_port())
  if head_port == "" {
    if is_record_shape(edge.head()) { head_name } else { "" }
  } else {
    "\{head_name}:\{head_port}"
  }
}

///|
/// Graphviz parity: complex tuning distance uses endpoint port centers in
/// current routing coordinates.
fn routing_head_metric_distance(
  edge : @cgraph.Edge,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  label_ports_map : Map[String, Map[String, RecordPort]],
  record_orientation : RecordOrientation,
) -> Double {
  let tail_name = edge.tail().name()
  let head_name = edge.head().name()
  let tail_pos =
    positions.get(tail_name).unwrap_or({
      x: 0.0,
      y: 0.0,
    })
  let head_pos =
    positions.get(head_name).unwrap_or({
      x: 0.0,
      y: 0.0,
    })
  let tail_size = sizes.get(tail_name).unwrap_or(node_size(edge.tail(), record_orientation))
  let head_size = sizes.get(head_name).unwrap_or(node_size(edge.head(), record_orientation))
  let tail_geometry =
    port_geometry(
      tail_name,
      edge.tail_port(),
      label_ports_map,
      tail_pos,
      tail_size,
    )
  let head_geometry =
    port_geometry(
      head_name,
      edge.head_port(),
      label_ports_map,
      head_pos,
      head_size,
    )
  let dx = head_geometry.center.x - tail_geometry.center.x
  let dy = head_geometry.center.y - tail_geometry.center.y
  Double::sqrt(dx * dx + dy * dy)
}

///|
/// Graphviz parity: head-port metric aggregation mirrors dotsplines
/// count/min/max accumulation for complex tuning.
fn build_routing_head_port_metrics(
  prep : LayoutPrep,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  label_ports_map : Map[String, Map[String, RecordPort]],
  enable_complex_tuning : Bool,
) -> @routing.HeadPortMetrics {
  @routing.build_head_port_metrics(
    prep.edges,
    enable_complex_tuning,
    (edge) => {
      let key = routing_head_metric_key(edge)
      if key == "" {
        None
      } else {
        let dist =
          routing_head_metric_distance(
            edge,
            positions,
            sizes,
            label_ports_map,
            prep.record_orientation,
          )
        Some((key, dist))
      }
    },
  )
}

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_precompute_data(
  input : RoutingPrecomputeInput,
) -> RoutingPrecomputeData {
  let prep = input.prep
  let (port_pad_below, port_pad_above) =
    @routing.resolve_routing_port_padding(
      input.cluster_meta.has_clusters,
      prep.has_port_edges,
      () => {
        let padding =
          record_port_padding_y(
            prep.edges,
            input.positions_state.positions,
            input.label_ports_map,
          )
        (padding.below, padding.above)
      },
    )
  let head_port_metrics =
    build_routing_head_port_metrics(
      prep,
      input.positions_state.positions,
      input.sizes,
      input.label_ports_map,
      input.enable_complex_tuning,
    )
  // Graphviz parity: pathplan neighbor widths use ND_mval (self-edge right space).
  let pathplan_sizes =
    apply_self_edge_right_space(
      prep.nodes,
      prep.edges,
      input.sizes,
      prep.rankdir,
      prep.record_orientation,
    )
  @routing.build_routing_precompute_pipeline(
    {
      edges: prep.edges,
      x_groups: input.positions_state.x_groups,
      ordered_groups_with_vnodes: input.ordering.ordered_groups_with_vnodes,
      ordered_groups: input.ordering.ordered_groups,
      port_pad_below,
      port_pad_above,
      head_port_metrics,
      edge_tail: input.rank_data.edge_tail,
      edge_head: input.rank_data.edge_head,
      ranks: input.rank_data.ranks,
      nodesep_pt: input.rank_heights.nodesep_pt,
      edge_vnodes: input.ordering.vnode_info.edge_vnodes,
      pathplan_sizes,
      path_cluster_keys: input.cluster_meta.intercluster_keys,
      vnode_sizes: input.ordering.vnode_info.vnode_sizes,
      vnode_positions: input.positions_state.vnode_positions,
      cluster_bboxes: input.cluster_bboxes,
    },
  )
}
