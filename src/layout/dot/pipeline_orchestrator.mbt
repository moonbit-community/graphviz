///|
priv struct DotRankStageOutput {
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c), with typed stage inputs.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
) -> DotRankStageOutput {
  // Graphviz parity: rank-data creation remains first before downstream stage assembly.
  let rank_data =
    compute_rank_data(
      graph,
      prep.nodes,
      prep.edges,
      prep.has_edge_labels,
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
  let ordering =
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
  // Graphviz parity: rank-stage result object keeps computed
  // rank/cluster/order artifacts unchanged.
  { rank_data, rank_heights, cluster_meta, ordering }
}

fn scale_point_value(point : @geom.Point, sx : Double, sy : Double) -> @geom.Point {
  { x: point.x * sx, y: point.y * sy }
}

///|
fn scale_optional_point_value(
  point : @geom.Point?,
  sx : Double,
  sy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(scale_point_value(value, sx, sy))
    None => None
  }
}

///|
fn scale_spline_value(
  spline : @geom.Spline,
  sx : Double,
  sy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(scale_point_value(point, sx, sy))
  }
  {
    start: scale_optional_point_value(spline.start, sx, sy),
    end: scale_optional_point_value(spline.end, sx, sy),
    points,
  }
}

///|
fn scale_edge_layout_output(
  edges : Array[DotLayoutEdge],
  sx : Double,
  sy : Double,
) -> Array[DotLayoutEdge] {
  let scaled : Array[DotLayoutEdge] = []
  for edge_layout in edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(scale_spline_value(spline, sx, sy))
    }
    scaled.push({
      edge: edge_layout.edge,
      splines,
      label_pos: scale_optional_point_value(edge_layout.label_pos, sx, sy),
      head_label_pos: scale_optional_point_value(
        edge_layout.head_label_pos,
        sx,
        sy,
      ),
      tail_label_pos: scale_optional_point_value(
        edge_layout.tail_label_pos,
        sx,
        sy,
      ),
      xlabel_pos: scale_optional_point_value(edge_layout.xlabel_pos, sx, sy),
    })
  }
  scaled
}

///|
fn scale_point_map_rounded(
  points : Map[String, @geom.Point],
  sx : Double,
  sy : Double,
) -> Map[String, @geom.Point] {
  let scaled : Map[String, @geom.Point] = Map::new()
  for name, point in points {
    let p = scale_point_value(point, sx, sy)
    scaled[name] = { x: p.x.round(), y: p.y.round() }
  }
  scaled
}

///|
fn scale_node_size_value(
  size : NodeSize,
  sx : Double,
  sy : Double,
) -> NodeSize {
  let width_pt = size.width_pt * sx
  let height_pt = size.height_pt * sy
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: size.left_pt * sx,
    right_pt: size.right_pt * sx,
  }
}

fn scale_double_map_rounded(
  values : Map[Int, Double],
  scale : Double,
) -> Map[Int, Double] {
  let scaled : Map[Int, Double] = Map::new()
  for key, value in values {
    scaled[key] = (value * scale).round()
  }
  scaled
}

///|
fn scale_named_double_map(
  values : Map[String, Double],
  scale : Double,
) -> Map[String, Double] {
  let scaled : Map[String, Double] = Map::new()
  for key, value in values {
    scaled[key] = value * scale
  }
  scaled
}

///|
fn scale_rect_map(
  rects : Map[String, @geom.Rect],
  sx : Double,
  sy : Double,
) -> Map[String, @geom.Rect] {
  let scaled : Map[String, @geom.Rect] = Map::new()
  for key, rect in rects {
    scaled[key] = {
      llx: rect.llx * sx,
      lly: rect.lly * sy,
      urx: rect.urx * sx,
      ury: rect.ury * sy,
    }
  }
  scaled
}

///|
fn scale_record_port_maps(
  maps : Map[String, Map[String, RecordPort]],
  sx : Double,
  sy : Double,
) -> Map[String, Map[String, RecordPort]] {
  let scaled : Map[String, Map[String, RecordPort]] = Map::new()
  for node_name, ports in maps {
    let scaled_ports : Map[String, RecordPort] = Map::new()
    for port_name, port in ports {
      scaled_ports[port_name] = {
        center: scale_point_value(port.center, sx, sy),
        size: scale_node_size_value(port.size, sx, sy),
        sides: port.sides,
      }
    }
    scaled[node_name] = scaled_ports
  }
  scaled
}

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
priv struct RoutingPrecomputeData {
  port_pad_below : Double
  port_pad_above : Double
  head_port_metrics : @routing.HeadPortMetrics
  path_groups : Map[Int, Array[String]]
  routing_context : @routing.RoutingContext
}

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_precompute_data(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  positions_state : PositionResult,
  label_ports_map : Map[String, Map[String, RecordPort]],
  cluster_bboxes : Map[String, @geom.Rect],
  sizes : Map[String, NodeSize],
  enable_complex_tuning : Bool,
) -> RoutingPrecomputeData {
  // Graphviz parity: port padding and head-port metrics consume
  // routing-stage inputs while preserving compute order before spline routing.
  let port_padding =
    compute_port_padding(
      cluster_meta.has_clusters,
      prep.has_port_edges,
      prep.edges,
      positions_state.positions,
      label_ports_map,
    )
  let port_pad_below = port_padding.port_pad_below
  let port_pad_above = port_padding.port_pad_above
  let head_port_metrics =
    collect_head_port_metrics(
      prep.edges,
      positions_state.positions,
      sizes,
      label_ports_map,
      prep.record_orientation,
      enable_complex_tuning,
    )
  // Graphviz parity: routing path-context execution consumes routing-stage
  // fields while preserving path-group selection then context-assembly order.
  // Graphviz parity: path-groups selection prefers positioned x-groups,
  // then vnode-expanded order groups, then base order groups.
  // Graphviz parity: pathplan uses final x-order (after positioning) with vnodes.
  let path_groups =
    if positions_state.x_groups.length() > 0 {
      positions_state.x_groups
    } else if ordering.ordered_groups_with_vnodes.length() > 0 {
      ordering.ordered_groups_with_vnodes
    } else {
      ordering.ordered_groups
    }
  // Graphviz parity: routing context is assembled from routing-stage
  // inputs, final ordering, vnode/rank, and cluster bboxes.
  let routing_context =
    @routing.prepare_routing_context(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      sizes,
      rank_data.ranks,
      ordering.ordered_groups,
      path_groups,
      rank_heights.nodesep_pt,
      ordering.vnode_info.edge_vnodes,
      ordering.vnode_info.vnode_sizes,
      positions_state.vnode_positions,
      cluster_bboxes,
      build_order_index,
      (nodes, edges, sizes) =>
        apply_self_edge_right_space(
          nodes,
          edges,
          sizes,
          prep.rankdir,
          prep.record_orientation,
        ),
      node_local_cluster_key,
    )
  {
    port_pad_below,
    port_pad_above,
    head_port_metrics,
    path_groups,
    routing_context,
  }
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
  let label_ports_map = spatial_data.label_ports_map
  let label_ports_raw = spatial_data.label_ports_raw
  let cluster_bboxes = spatial_data.cluster_bboxes
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
  let routing_positions =
    if ratio_scaled {
      scale_point_map_rounded(positions_state.positions, ratio_sx, ratio_sy)
    } else {
      positions_state.positions
    }
  let routing_vnode_positions =
    if ratio_scaled {
      scale_point_map_rounded(positions_state.vnode_positions, ratio_sx, ratio_sy)
    } else {
      positions_state.vnode_positions
    }
  let routing_rank_y =
    if ratio_scaled {
      scale_double_map_rounded(positions_state.rank_y, ratio_sy)
    } else {
      positions_state.rank_y
    }
  let routing_cluster_bboxes =
    if ratio_scaled {
      scale_rect_map(cluster_bboxes, ratio_sx, ratio_sy)
    } else {
      cluster_bboxes
    }
  let routing_label_ports_map =
    if ratio_scaled {
      scale_record_port_maps(label_ports_map, ratio_sx, ratio_sy)
    } else {
      label_ports_map
    }
  let routing_label_ports_raw =
    if ratio_scaled {
      scale_record_port_maps(label_ports_raw, ratio_sx, ratio_sy)
    } else {
      label_ports_raw
    }
  let routing_sizes =
    // Graphviz parity: route spline clipping keeps node extents in pre-ratio units.
    prep.sizes
  let routing_positions_state : PositionResult =
    if ratio_scaled {
      {
        x_groups: positions_state.x_groups,
        rank_y: routing_rank_y,
        positions: routing_positions,
        vnode_positions: routing_vnode_positions,
        cluster_ln_x: scale_named_double_map(positions_state.cluster_ln_x, ratio_sx),
        cluster_rn_x: scale_named_double_map(positions_state.cluster_rn_x, ratio_sx),
        flat_label_edge_vnodes: positions_state.flat_label_edge_vnodes,
        rank_ht1: positions_state.rank_ht1,
        rank_ht2: positions_state.rank_ht2,
        cluster_bbox_heights: positions_state.cluster_bbox_heights,
      }
    } else {
      positions_state
    }
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
