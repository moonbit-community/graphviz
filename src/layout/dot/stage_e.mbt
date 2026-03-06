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
        label_ports_map: ratio_adjusted_data.label_ports_map,
        cluster_bboxes: routing_cluster_bboxes,
        sizes: prep.sizes,
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
  // Graphviz parity: route spline clipping keeps node extents in pre-ratio units.
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
    match @dot_shared.ratio_fill_scale_factors(graph, routing_bbox, prep.rankdir) {
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
    rank_y: @routing.scale_double_map_rounded(positions_state.rank_y, ratio_sy),
    positions:
      @routing.scale_point_map_rounded(
        positions_state.positions,
        ratio_sx,
        ratio_sy,
      ),
    vnode_positions:
      @routing.scale_point_map_rounded(
        positions_state.vnode_positions,
        ratio_sx,
        ratio_sy,
      ),
    cluster_ln_x:
      @routing.scale_named_double_map(positions_state.cluster_ln_x, ratio_sx),
    cluster_rn_x:
      @routing.scale_named_double_map(positions_state.cluster_rn_x, ratio_sx),
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
    cluster_bboxes:
      @routing.scale_rect_map(
        input.cluster_bboxes,
        ratio_sx,
        ratio_sy,
      ),
    label_ports_map:
      @routing.scale_record_port_maps(
        input.label_ports_map,
        ratio_sx,
        ratio_sy,
      ),
    label_ports_raw:
      @routing.scale_record_port_maps(
        input.label_ports_raw,
        ratio_sx,
        ratio_sy,
      ),
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
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_precompute_data(
  input : RoutingPrecomputeInput,
) -> RoutingPrecomputeData {
  let prep = input.prep
  // Graphviz parity: routing port padding resolves cluster/port-edge gating
  // and record-port y padding in the same order as dotsplines precompute.
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
    @routing.build_head_port_metrics_from_geometry(
      {
        edges: prep.edges,
        enable_complex_tuning: input.enable_complex_tuning,
        positions: input.positions_state.positions,
        sizes: input.sizes,
      },
      {
        is_record_shape: @dot_shared.is_record_shape,
        node_size_for_missing: node => node_size(node, prep.record_orientation),
        port_geometry_for:
          (node_name, port, node_pos, node_size) => {
            let geometry =
              port_geometry(
                node_name,
                port,
                input.label_ports_map,
                node_pos,
                node_size,
              )
            {
              center: geometry.center,
              size: geometry.size,
            }
          },
      },
    )
  // Graphviz parity: pathplan neighbor widths use ND_mval (self-edge right
  // space) before routing context assembly.
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
///|
/// Stage E spatial precompute helpers for routing.

///|
/// Graphviz parity: layout-node payload keeps node-size and position snapshots
/// grouped so node geometry projection wiring remains explicit and stable.
priv struct LayoutNodesInput {
  nodes : Array[@cgraph.Node]
  positions : Map[String, @geom.Point]
  output_sizes : Map[String, NodeSize]
  record_orientation : RecordOrientation
}

///|
priv struct PortLayoutMaps {
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
/// Graphviz parity: node layout assembly aligned to refs/graphviz/lib/dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_layout_nodes(
  input : LayoutNodesInput,
) -> Array[DotLayoutNode] {
  let nodes_out : Array[DotLayoutNode] = []
  for node in input.nodes {
    let name = node.name()
    let pos = match input.positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size =
      resolve_node_output_size(
        input.output_sizes,
        node,
        input.record_orientation,
      )
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    })
  }
  nodes_out
}

///|
/// Graphviz parity: port-layout payload keeps node geometry and routing flags
/// grouped so record/html port map wiring remains explicit and stable.
priv struct PortLayoutMapsInput {
  nodes_out : Array[DotLayoutNode]
  output_sizes : Map[String, NodeSize]
  record_orientation : RecordOrientation
  rankdir : RankDir
  has_port_edges : Bool
}

///|
/// Graphviz parity: port layout maps aligned to refs/graphviz/lib/common/shapes.c (record/html ports).
/// Do not change behavior without updating fixtures/tests.
fn build_port_layout_maps(
  input : PortLayoutMapsInput,
) -> PortLayoutMaps {
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  let label_ports_raw : Map[String, Map[String, RecordPort]] = Map::new()
  if input.has_port_edges {
    for node_layout in input.nodes_out {
      let final_size =
        resolve_node_output_size(
          input.output_sizes,
          node_layout.node,
          input.record_orientation,
        )
      let name = node_layout.node.name()
      let raw_ports =
        raw_label_ports_for_node(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
          input.record_orientation,
        )
      if raw_ports.length() > 0 {
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, input.rankdir)
        label_ports_map[name] = ports
      }
    }
  }
  { label_ports_map, label_ports_raw }
}

///|
/// Graphviz parity: cluster routing bboxes aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterRouteBboxesInput {
  graph : @cgraph.Graph
  nodes_out : Array[DotLayoutNode]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
  rankdir : RankDir
  ranks : Map[String, Int]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
/// Graphviz parity: cluster routing bboxes aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
fn compute_cluster_route_bboxes(
  input : ClusterRouteBboxesInput,
) -> Map[String, @geom.Rect] {
  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  if @dot_shared.graph_has_cluster(input.graph) {
    let cluster_layouts =
      layout_subgraphs(
        {
          graph: input.graph,
          nodes_out: input.nodes_out,
          edges_out: [],
          cluster_ln_x: input.cluster_ln_x,
          cluster_rn_x: input.cluster_rn_x,
          cluster_bbox_heights: input.cluster_bbox_heights,
          rankdir: input.rankdir,
          ranks: input.ranks,
          rank_y: input.rank_y,
          rank_ht1: input.rank_ht1,
          rank_ht2: input.rank_ht2,
        },
      )
    collect_cluster_bboxes(cluster_layouts, cluster_bboxes)
  }
  cluster_bboxes
}

///|
fn collect_cluster_bboxes(
  subgraphs : Array[DotLayoutGraph],
  out : Map[String, @geom.Rect],
) -> Unit {
  for layout in subgraphs {
    if @dot_shared.is_cluster_graph(layout.graph) {
      match layout.graph.name() {
        Some(name) => out[name] = layout.bbox
        None => ()
      }
    }
    if layout.subgraphs.length() > 0 {
      collect_cluster_bboxes(layout.subgraphs, out)
    }
  }
}

///|
priv struct RoutingSpatialData {
  nodes_out : Array[DotLayoutNode]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
/// Graphviz parity: routing spatial payload keeps stage context grouped so
/// node/port and cluster-bbox precompute wiring stays explicit and stable.
priv struct RoutingSpatialInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  ranks : Map[String, Int]
  positions_state : PositionResult
}

///|
/// Graphviz parity: routing spatial precompute consumes typed routing-stage
/// inputs and keeps node/port + cluster-bbox computation order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_data(
  input : RoutingSpatialInput,
) -> RoutingSpatialData {
  let prep = input.prep
  let positions_state = input.positions_state
  // Graphviz parity: node geometry projection and port-map derivation
  // consume stage inputs in the same precompute order.
  let nodes_out =
    build_layout_nodes(
      {
        nodes: prep.nodes,
        positions: positions_state.positions,
        output_sizes: prep.output_sizes,
        record_orientation: prep.record_orientation,
      },
    )
  // Graphviz parity: routing port maps use final node geometry before
  // routing padding and edge solve.
  let port_maps =
    build_port_layout_maps(
      {
        nodes_out,
        output_sizes: prep.output_sizes,
        record_orientation: prep.record_orientation,
        rankdir: prep.rankdir,
        has_port_edges: prep.has_port_edges,
      },
    )
  let label_ports_map = port_maps.label_ports_map
  let label_ports_raw = port_maps.label_ports_raw
  // Graphviz parity: routing spatial output object consumes typed
  // routing-stage inputs and node/port precompute output without remapping.
  let cluster_bboxes =
    compute_cluster_route_bboxes(
      {
        graph: input.graph,
        nodes_out,
        cluster_ln_x: positions_state.cluster_ln_x,
        cluster_rn_x: positions_state.cluster_rn_x,
        cluster_bbox_heights: positions_state.cluster_bbox_heights,
        rankdir: prep.rankdir,
        ranks: input.ranks,
        rank_y: positions_state.rank_y,
        rank_ht1: positions_state.rank_ht1,
        rank_ht2: positions_state.rank_ht2,
      },
    )
  { nodes_out, label_ports_map, label_ports_raw, cluster_bboxes }
}
///|
/// Stage E route-edge bridge helpers that adapt dot package callbacks and
/// shape/label utilities into routing subpackage pipeline dependencies.
priv struct RouteEdgesForDotInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  routing_positions_state : PositionResult
  routing_label_ports_map : Map[String, Map[String, RecordPort]]
  routing_label_ports_raw : Map[String, Map[String, RecordPort]]
  routing_sizes : Map[String, NodeSize]
  path_groups : Map[Int, Array[String]]
  routing_context : @routing.RoutingContext
  label_edge_counts : Map[String, Int]
  head_port_metrics : @routing.HeadPortMetrics
  enable_complex_tuning : Bool
}

fn build_route_base_deps_for_dot(
  record_orientation : RecordOrientation,
  routing_label_ports_map : Map[String, Map[String, RecordPort]],
  routing_label_ports_raw : Map[String, Map[String, RecordPort]],
) -> @routing.RouteBaseDeps {
  let route_mid_label_metrics : (@cgraph.Edge) -> @routing.RouteLabelMetrics? =
    (edge : @cgraph.Edge) =>
      match edge_mid_label_metrics(edge) {
        Some(metrics) => {
          let route_metrics : @routing.RouteLabelMetrics = {
            width: metrics.width,
            height: metrics.height,
          }
          Some(route_metrics)
        }
        None => None
      }
  let route_port_geometry :
    (
      String,
      @cgraph.Port?,
      @geom.Point,
      NodeSize,
    ) -> @routing.RoutePortGeometry =
    (
      node_name : String,
      port : @cgraph.Port?,
      node_pos : @geom.Point,
      node_size : NodeSize,
    ) => {
      let geometry =
        port_geometry(
          node_name,
          port,
          routing_label_ports_map,
          node_pos,
          node_size,
        )
      let route_geometry : @routing.RoutePortGeometry = {
        center: geometry.center,
        size: geometry.size,
      }
      route_geometry
    }
  let route_dynamic_port_anchor :
    (
      @cgraph.Port?,
      String,
      @geom.Point,
      @geom.Point,
      RankDir,
      Double,
    ) -> @routing.RouteDynamicPortAnchor =
    (
      port : @cgraph.Port?,
      node_name : String,
      node_pos : @geom.Point,
      other_pos : @geom.Point,
      rankdir : RankDir,
      record_border_adjust : Double,
    ) => {
      let anchor =
        dynamic_port_anchor_for_edge(
          port,
          node_name,
          routing_label_ports_raw,
          node_pos,
          other_pos,
          rankdir,
          record_border_adjust,
        )
      let route_anchor : @routing.RouteDynamicPortAnchor = {
        anchor: anchor.anchor,
        side: anchor.side,
        is_dynamic: anchor.is_dynamic,
      }
      route_anchor
    }
  {
    node_size_for_missing: (node) => node_size(node, record_orientation),
    edge_mid_label_metrics: route_mid_label_metrics,
    record_port_path_box,
    port_geometry: route_port_geometry,
    port_rect_from_geometry,
    port_is_label_port:
      (node_name, port) =>
        port_is_label_port(node_name, port, routing_label_ports_raw),
    is_record_shape: @dot_shared.is_record_shape,
    record_border_adjust:
      (node) =>
        if @dot_shared.is_record_shape(node) &&
          !@html_label.is_html_label_text(label_text(node)) {
          @dot_shared.RECORD_BORDER_PT
        } else {
          0.0
        },
    dynamic_port_anchor_for_edge: route_dynamic_port_anchor,
    port_side_mask_from_anchor,
    port_side_for_edge:
      (port, port_rect, node_pos, node_size) =>
        port_side_for_edge(port, port_rect, node_pos, node_size, None),
    layout_port_offset,
    node_cluster_key: @clustering.node_cluster_key,
    node_local_cluster_key: @clustering.node_local_cluster_key,
  }
}

///|
fn build_routing_callbacks_for_dot(
  edge_layout_input : @routing.EdgeLayoutInput,
) -> @routing.RoutingCallbacks {
  let edge_port_label_pos_for_dot =
    (input : @routing.EdgePortLabelPosInput) =>
      @routing.edge_port_label_pos(
        input,
        PORT_LABEL_ANGLE_DEG,
        PORT_LABEL_ANGLE_MIN_DEG,
        PORT_LABEL_DISTANCE_PT,
        GRAPHVIZ_PI,
      )
  let route_mid_label_metrics : (@cgraph.Edge) -> @routing.RouteLabelMetrics? =
    (edge : @cgraph.Edge) =>
      match edge_mid_label_metrics(edge) {
        Some(metrics) => Some({ width: metrics.width, height: metrics.height })
        None => None
      }
  let edge_layout_deps : @routing.EdgeLayoutDeps = {
    edge_label_rank_for_routing_fn:
      (edge, ranks, mid_label_width_pt) =>
        match @routing.edge_label_rank_info(edge, ranks, mid_label_width_pt) {
          Some(info) =>
            if mid_label_width_pt > 0.0 {
              Some((info.label_rank, info.span))
            } else {
              None
            }
          None => None
        },
    edge_label_rank_y_fn:
      (edge, ranks, rank_y) =>
        @routing.edge_label_rank_y(
          edge,
          ranks,
          rank_y,
          edge_mid_label_width_pt(edge),
        ),
    edge_label_rank_x_fn: @routing.edge_label_rank_x,
    edge_label_pos_from_vnode_fn: @routing.edge_label_pos_from_vnode,
    flat_edge_label_pos_simple_fn:
      (tail_port, head_port, tail_right_pt, head_left_pt, label_height_pt) =>
        @routing.flat_edge_label_pos_simple(
          tail_port,
          head_port,
          tail_right_pt,
          head_left_pt,
          label_height_pt,
          EDGE_LABEL_FLAT_SPACE_PT,
        ),
    edge_label_pos_fn:
      input =>
        @routing.edge_label_pos_from_input(
          input,
          route_mid_label_metrics,
          EDGE_LABEL_PAD_WIDTH_PT,
        ),
    edge_port_label_pos_fn: edge_port_label_pos_for_dot,
  }
  {
    recover_slack_vnodes_fn:
      input =>
        @routing.recover_slack_vnodes(
          input,
          (edge, ranks) =>
            match @routing.edge_label_rank_info(
              edge,
              ranks,
              edge_mid_label_width_pt(edge),
            ) {
              Some(info) => Some(info.label_rank)
              None => None
            },
        ),
    build_edge_layout_fn: (input) =>
      @routing.build_edge_layout(
        {
          base: input.base,
          spline: input.spline,
          spline_result: input.spline_result,
          edge_layout_input,
          deps: edge_layout_deps,
        }
      ),
    self_edge_label_height_fn: self_edge_label_height_pt,
    self_edge_label_width_fn: self_edge_label_width_pt,
    edge_port_label_pos_fn: edge_port_label_pos_for_dot,
  }
}

///|
fn route_edges_for_dot(input : RouteEdgesForDotInput) -> Array[DotLayoutEdge] {
  let edge_layout_input : @routing.EdgeLayoutInput = {
    ranks: input.rank_data.ranks,
    rank_y: input.routing_positions_state.rank_y,
    vnode_info: input.ordering.vnode_info,
    vnode_positions: input.routing_positions_state.vnode_positions,
    has_clusters: input.cluster_meta.has_clusters,
    nodesep_pt: input.rank_heights.nodesep_pt,
    flat_label_edge_vnodes: input.routing_positions_state.flat_label_edge_vnodes,
  }
  let deps : @routing.RouteEdgesPipelineDeps = {
    route_base_deps:
      build_route_base_deps_for_dot(
        input.prep.record_orientation,
        input.routing_label_ports_map,
        input.routing_label_ports_raw,
      ),
    callbacks: build_routing_callbacks_for_dot(edge_layout_input),
  }
  let pipeline_input : @routing.RouteEdgesPipelineInput = {
    graph_kind: input.graph.kind(),
    rankdir: input.prep.rankdir,
    layout_rankdir: RankDir::TB,
    edges: input.prep.edges,
    ranks: input.rank_data.ranks,
    sizes: input.routing_sizes,
    positions: input.routing_positions_state.positions,
    vnode_positions: input.routing_positions_state.vnode_positions,
    vnode_info: input.ordering.vnode_info,
    rank_y: input.routing_positions_state.rank_y,
    rank_ht1: input.routing_positions_state.rank_ht1,
    rank_ht2: input.routing_positions_state.rank_ht2,
    x_groups: input.path_groups,
    nodesep_pt: input.rank_heights.nodesep_pt,
    ranksep_pt: input.rank_heights.ranksep_pt,
    label_edge_counts: input.label_edge_counts,
    head_port_metrics: input.head_port_metrics,
    flat_label_edge_vnodes: input.routing_positions_state.flat_label_edge_vnodes,
    routing_context: input.routing_context,
    enable_complex_tuning: input.enable_complex_tuning,
    use_spline_prepass: input.prep.splines == SplinesMode::Spline,
    spline_mode:
      match input.prep.splines {
        SplinesMode::None | SplinesMode::Polyline => 0
        SplinesMode::Ortho => 1
        _ => 2
      },
  }
  @routing.route_edges_pipeline(
    pipeline_input,
    deps,
  )
}
