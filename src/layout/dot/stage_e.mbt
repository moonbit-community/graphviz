///|
/// Stage E routing stage file: orchestrator plus spatial/metric/ratio
/// precompute helpers and route-edge bridge wiring.

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
    let size = match input.output_sizes.get(name) {
      Some(value) => value
      None => node_size(node, input.record_orientation)
    }
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
      let name = node_layout.node.name()
      let final_size = match input.output_sizes.get(name) {
        Some(value) => value
        None => node_size(node_layout.node, input.record_orientation)
      }
      let label = label_text(node_layout.node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html {
        let raw_ports = html_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, input.rankdir)
        label_ports_map[name] = ports
      } else if is_record_shape(node_layout.node) {
        let raw_ports = record_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
          input.record_orientation,
        )
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
  let graph = input.graph
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
  // Graphviz parity: routing port maps are built from final node
  // geometry and rankdir/port-edge flags before padding and edge routing.
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
  // Graphviz parity: routing cluster bboxes are derived from typed
  // routing-stage inputs, positioned nodes, and rank/cluster maps.
  let cluster_bboxes =
    compute_cluster_route_bboxes(
      {
        graph,
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
  @routing.build_routing_precompute_pipeline(
    {
      has_clusters: input.cluster_meta.has_clusters,
      has_port_edges: prep.has_port_edges,
      edges: prep.edges,
      enable_complex_tuning: input.enable_complex_tuning,
      x_groups: input.positions_state.x_groups,
      ordered_groups_with_vnodes: input.ordering.ordered_groups_with_vnodes,
      ordered_groups: input.ordering.ordered_groups,
      nodes: prep.nodes,
      edge_tail: input.rank_data.edge_tail,
      edge_head: input.rank_data.edge_head,
      sizes: input.sizes,
      ranks: input.rank_data.ranks,
      nodesep_pt: input.rank_heights.nodesep_pt,
      edge_vnodes: input.ordering.vnode_info.edge_vnodes,
      vnode_sizes: input.ordering.vnode_info.vnode_sizes,
      vnode_positions: input.positions_state.vnode_positions,
      cluster_bboxes: input.cluster_bboxes,
      build_order_index_fn: @ordering.build_order_index,
      apply_self_edge_right_space_fn: (nodes, edges, sizes) =>
        apply_self_edge_right_space(
          nodes,
          edges,
          sizes,
          prep.rankdir,
          prep.record_orientation,
        ),
      node_local_cluster_key_fn: @clustering.node_local_cluster_key,
      compute_padding_fn: (edges) => {
        let padding =
          record_port_padding_y(
            edges,
            input.positions_state.positions,
            input.label_ports_map,
          )
        (padding.below, padding.above)
      },
      head_metric_key_fn: (edge) => {
        let head_name = edge.head().name()
        let head_port = @dot_shared.port_key(edge.head_port())
        if head_port == "" {
          if is_record_shape(edge.head()) { head_name } else { "" }
        } else {
          "\{head_name}:\{head_port}"
        }
      },
      head_metric_distance_fn: (edge) => {
        let tail_name = edge.tail().name()
        let head_name = edge.head().name()
        let tail_pos =
          input.positions_state.positions.get(tail_name).unwrap_or({
            x: 0.0,
            y: 0.0,
          })
        let head_pos =
          input.positions_state.positions.get(head_name).unwrap_or({
            x: 0.0,
            y: 0.0,
          })
        let tail_size = input.sizes.get(tail_name).unwrap_or(node_size(edge.tail(), prep.record_orientation))
        let head_size = input.sizes.get(head_name).unwrap_or(node_size(edge.head(), prep.record_orientation))
        let tail_geometry =
          port_geometry(
            tail_name,
            edge.tail_port(),
            input.label_ports_map,
            tail_pos,
            tail_size,
          )
        let head_geometry =
          port_geometry(
            head_name,
            edge.head_port(),
            input.label_ports_map,
            head_pos,
            head_size,
          )
        let dx = head_geometry.center.x - tail_geometry.center.x
        let dy = head_geometry.center.y - tail_geometry.center.y
        Double::sqrt(dx * dx + dy * dy)
      },
    },
  )
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

///|
fn routing_spline_mode(splines : SplinesMode) -> Int {
  match splines {
    SplinesMode::None | SplinesMode::Polyline => 0
    SplinesMode::Ortho => 1
    _ => 2
  }
}

fn build_route_base_deps_for_dot(
  record_orientation : RecordOrientation,
  routing_label_ports_map : Map[String, Map[String, RecordPort]],
  routing_label_ports_raw : Map[String, Map[String, RecordPort]],
) -> @routing.RouteBaseDeps {
  {
    node_size_for_missing: (node) => node_size(node, record_orientation),
    edge_mid_label_metrics:
      (edge) =>
        match edge_mid_label_metrics(edge) {
          Some(metrics) => Some({ width: metrics.width, height: metrics.height })
          None => None
        },
    record_port_path_box,
    port_geometry:
      (node_name, port, node_pos, node_size) => {
        let geometry =
          port_geometry(
            node_name,
            port,
            routing_label_ports_map,
            node_pos,
            node_size,
          )
        { center: geometry.center, size: geometry.size }
      },
    port_rect_from_geometry,
    port_is_label_port:
      (node_name, port) =>
        port_is_label_port(node_name, port, routing_label_ports_raw),
    is_record_shape,
    record_border_adjust:
      (node) =>
        if is_record_shape(node) &&
          !@html_label.is_html_label_text(label_text(node)) {
          @dot_shared.RECORD_BORDER_PT
        } else {
          0.0
        },
    dynamic_port_anchor_for_edge:
      (port, node_name, node_pos, other_pos, rankdir, record_border_adjust) => {
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
        { anchor: anchor.anchor, side: anchor.side, is_dynamic: anchor.is_dynamic }
      },
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
  let edge_layout_deps : @routing.EdgeLayoutDeps =
    {
      edge_label_rank_for_routing_fn: (edge, ranks, mid_label_width_pt) =>
        match edge_label_rank_info(edge, ranks) {
          Some(info) =>
            if mid_label_width_pt > 0.0 {
              Some((info.label_rank, info.span))
            } else {
              None
            }
          None => None
        },
      edge_label_rank_y_fn: edge_label_rank_y,
      edge_label_rank_x_fn: (edge, label_rank, vnode_info, vnode_positions) =>
        edge_label_rank_x(
          edge,
          label_rank,
          vnode_info.vnode_ranks,
          vnode_info.edge_vnodes,
          vnode_positions,
        ),
      edge_label_pos_from_vnode_fn: edge_label_pos_from_vnode,
      flat_edge_label_pos_simple_fn: flat_edge_label_pos_simple,
      edge_label_pos_fn: edge_label_pos,
      edge_port_label_pos_fn: edge_port_label_pos,
    }
  {
    recover_slack_vnodes_fn: recover_slack_vnodes,
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
    edge_port_label_pos_fn: edge_port_label_pos,
  }
}

///|
fn route_edges_for_dot(input : RouteEdgesForDotInput) -> Array[DotLayoutEdge] {
  let edge_layout_input : @routing.EdgeLayoutInput =
    {
      ranks: input.rank_data.ranks,
      rank_y: input.routing_positions_state.rank_y,
      vnode_info: input.ordering.vnode_info,
      vnode_positions: input.routing_positions_state.vnode_positions,
      has_clusters: input.cluster_meta.has_clusters,
      nodesep_pt: input.rank_heights.nodesep_pt,
      flat_label_edge_vnodes: input.routing_positions_state.flat_label_edge_vnodes,
    }
  let deps : @routing.RouteEdgesPipelineDeps =
    {
      route_base_deps:
        build_route_base_deps_for_dot(
          input.prep.record_orientation,
          input.routing_label_ports_map,
          input.routing_label_ports_raw,
        ),
      callbacks: build_routing_callbacks_for_dot(edge_layout_input),
    }
  let pipeline_input : @routing.RouteEdgesPipelineInput =
    {
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
      spline_mode: routing_spline_mode(input.prep.splines),
    }
  @routing.route_edges_pipeline(
    pipeline_input,
    deps,
  )
}
