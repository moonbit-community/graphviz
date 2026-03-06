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
  let edges_out = maybe_rescale_routed_edges(edges_routed, ratio_scaled, ratio_sx, ratio_sy)
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
/// Graphviz parity: routing port padding resolves cluster/port-edge gating and
/// record-port y padding in the same order as dotsplines precompute.
/// Do not change behavior without updating fixtures/tests.
fn resolve_routing_port_padding(
  input : RoutingPrecomputeInput,
) -> (Double, Double) {
  let prep = input.prep
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
}

///|
/// Graphviz parity: pathplan neighbor widths use ND_mval (self-edge right
/// space) before routing context assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_pathplan_sizes_for_routing(
  prep : LayoutPrep,
  sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    sizes,
    prep.rankdir,
    prep.record_orientation,
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
  let (port_pad_below, port_pad_above) = resolve_routing_port_padding(input)
  let head_port_metrics =
    build_routing_head_port_metrics(
      prep,
      input.positions_state.positions,
      input.sizes,
      input.label_ports_map,
      input.enable_complex_tuning,
    )
  let pathplan_sizes =
    build_pathplan_sizes_for_routing(prep, input.sizes)
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
/// Graphviz parity: routing port maps are built from final node geometry and
/// rankdir/port-edge flags before padding and edge routing.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_port_maps(
  prep : LayoutPrep,
  nodes_out : Array[DotLayoutNode],
) -> PortLayoutMaps {
  build_port_layout_maps(
    {
      nodes_out,
      output_sizes: prep.output_sizes,
      record_orientation: prep.record_orientation,
      rankdir: prep.rankdir,
      has_port_edges: prep.has_port_edges,
    },
  )
}

///|
/// Graphviz parity: routing cluster bboxes are derived from typed routing-stage
/// inputs, positioned nodes, and rank/cluster maps.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_cluster_bboxes(
  input : RoutingSpatialInput,
  nodes_out : Array[DotLayoutNode],
) -> Map[String, @geom.Rect] {
  let prep = input.prep
  let positions_state = input.positions_state
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
  let port_maps =
    build_routing_port_maps(prep, nodes_out)
  let label_ports_map = port_maps.label_ports_map
  let label_ports_raw = port_maps.label_ports_raw
  // Graphviz parity: routing spatial output object consumes typed
  // routing-stage inputs and node/port precompute output without remapping.
  let cluster_bboxes =
    build_routing_cluster_bboxes(input, nodes_out)
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

fn maybe_rescale_routed_edges(
  edges_routed : Array[DotLayoutEdge],
  ratio_scaled : Bool,
  ratio_sx : Double,
  ratio_sy : Double,
) -> Array[DotLayoutEdge] {
  if ratio_scaled {
    scale_edge_layout_output(edges_routed, 1.0 / ratio_sx, 1.0 / ratio_sy)
  } else {
    edges_routed
  }
}

///|
fn routing_spline_mode(splines : SplinesMode) -> Int {
  match splines {
    SplinesMode::None | SplinesMode::Polyline => 0
    SplinesMode::Ortho => 1
    _ => 2
  }
}

///|
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
    is_record_shape,
    record_border_adjust:
      (node) =>
        if is_record_shape(node) &&
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
  let edge_layout_deps =
    build_edge_layout_deps_for_dot()
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
fn build_edge_layout_deps_for_dot() -> @routing.EdgeLayoutDeps {
  {
    edge_label_rank_for_routing_fn:
      (edge, ranks, mid_label_width_pt) =>
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
    edge_label_pos_fn: edge_label_pos_from_input,
    edge_port_label_pos_fn: edge_port_label_pos,
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
    spline_mode: routing_spline_mode(input.prep.splines),
  }
  @routing.route_edges_pipeline(
    pipeline_input,
    deps,
  )
}
///|
/// Edge-label position computation from spline samples and rank-guided anchors,
/// including flat-edge fallback and routing entry wrappers.

///|
fn flat_edge_label_pos_simple(
  tail_port : @geom.Point,
  head_port : @geom.Point,
  tail_right_pt : Double,
  head_left_pt : Double,
  label_height_pt : Double,
) -> @geom.Point {
  let left_end = tail_port.x + tail_right_pt
  let right_end = head_port.x - head_left_pt
  let ctrx = (left_end + right_end) / 2.0
  let ctry = tail_port.y + (label_height_pt + EDGE_LABEL_FLAT_SPACE_PT) / 2.0
  @edge_spline.point(ctrx, ctry)
}

///|
fn edge_label_pos_from_input(
  input : @routing.EdgeLabelPosInput,
) -> @geom.Point? {
  let edge = input.edge
  let spline = input.spline
  let tail_clip = input.tail_clip
  let head_clip = input.head_clip
  let rankdir = input.rankdir
  let label_rank_y = input.label_rank_y
  let label_rank_x = input.label_rank_x
  let apply_label_pad = input.apply_label_pad
  let nodesep_pt = input.nodesep_pt
  let label_pad_boost = input.label_pad_boost
  let samples = sample_spline_points(spline.points, 96)
  let fallback = match spline_label_pos_with_samples(samples) {
    Some(value) => value
    None => {
      let mid = @edge_spline.point(
        (tail_clip.x + head_clip.x) / 2.0,
        (tail_clip.y + head_clip.y) / 2.0,
      )
      let delta = @edge_spline.point_sub(head_clip, tail_clip)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let tangent =
        if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
      { pos: mid, tangent }
    }
  }
  let label_point = match label_rank_y {
    Some(axis) =>
      match spline_label_pos_at_samples(
        samples,
        axis,
        false,
      ) {
        Some(value) => value
        None => fallback
      }
    None => fallback
  }
  let raw_pos = label_point.pos
  let dir = label_point.tangent
  let base_pos =
    match (label_rank_x, label_rank_y) {
      (Some(x_axis), Some(y_axis)) =>
        match rankdir {
          RankDir::LR | RankDir::RL => @edge_spline.point(y_axis, x_axis)
          _ => @edge_spline.point(x_axis, y_axis)
        }
      (Some(value), None) =>
        match rankdir {
          RankDir::LR | RankDir::RL => @edge_spline.point(raw_pos.x, value)
          _ => @edge_spline.point(value, raw_pos.y)
        }
      _ => raw_pos
    }
  if @dot_shared.edge_is_self(edge) {
    return Some(base_pos)
  }
  match label_rank_y {
    Some(_) =>
      match edge_mid_label_metrics(edge) {
        Some(metrics) => {
          let half_extent = match rankdir {
            RankDir::LR | RankDir::RL => metrics.height / 2.0
            _ => metrics.width / 2.0
          }
          let sign = match rankdir {
            RankDir::RL => -1.0
            _ => 1.0
          }
          let mut pad = label_pad_boost
          if label_rank_x is None {
            if apply_label_pad {
              pad = pad + nodesep_pt * 0.22
            } else if metrics.width >= EDGE_LABEL_PAD_WIDTH_PT {
              pad = pad + nodesep_pt * 0.22
            }
          } else {
            pad = 0.0
          }
          Some(@edge_spline.point(base_pos.x + sign * (half_extent + pad), base_pos.y))
        }
        None => Some(base_pos)
      }
    None => {
      let metrics = match edge_mid_label_metrics(edge) {
        Some(value) => value
        None => return Some(base_pos)
      }
      let normal = @edge_spline.point(-dir.y, dir.x)
      let axis_threshold = 0.1
      let abs_dx = Double::abs(dir.x)
      let abs_dy = Double::abs(dir.y)
      if spline.points.length() > 4 &&
        abs_dx > axis_threshold &&
        abs_dy > axis_threshold {
        return Some(base_pos)
      }
      let offset =
        if abs_dx <= axis_threshold {
          metrics.width / 2.0
        } else if abs_dy <= axis_threshold {
          metrics.height / 2.0
        } else {
          0.0
        }
      if offset <= 0.0 {
        Some(base_pos)
      } else {
        let pad = label_pad_boost
        Some(@edge_spline.point_add(base_pos, @edge_spline.point_scale(normal, offset + pad)))
      }
    }
  }
}

///|
/// Port-label parameter parsing and placement helpers for edge endpoints.

///|
priv struct PortLabelParams {
  angle_deg : Double
  distance_scale : Double
}

///|
fn port_label_params(edge : @cgraph.Edge) -> PortLabelParams? {
  let angle_attr = edge.get_attr("labelangle")
  let distance_attr = edge.get_attr("labeldistance")
  let has_angle = match angle_attr {
    Some(value) => value != ""
    None => false
  }
  let has_distance = match distance_attr {
    Some(value) => value != ""
    None => false
  }
  if !has_angle && !has_distance {
    return None
  }
  let angle_deg = match angle_attr {
    Some(value) =>
      if value == "" {
        PORT_LABEL_ANGLE_DEG
      } else {
        @dot_shared.parse_attr_double(
          value,
          PORT_LABEL_ANGLE_DEG,
          PORT_LABEL_ANGLE_MIN_DEG,
        )
      }
    None => PORT_LABEL_ANGLE_DEG
  }
  let distance_scale = match distance_attr {
    Some(value) =>
      if value == "" {
        1.0
      } else {
        @dot_shared.parse_attr_double(value, 1.0, 0.0)
      }
    None => 1.0
  }
  Some({ angle_deg, distance_scale })
}

fn port_label_points(
  spline : @geom.Spline,
  head_p : Bool,
  marker_present : Bool,
) -> PointWithTangent? {
  // Graphviz parity: place_portlabel uses eflag/sflag to choose marker tangent
  // (marker present => use marker+endpoint tangent, absent => use Bezier sample).
  let points = spline.points
  if points.length() < 4 {
    return None
  }
  let head_bezier_sample = () => {
    let start = points.length() - 4
    let p0 = points[start]
    let p1 = points[start + 1]
    let p2 = points[start + 2]
    let p3 = points[start + 3]
    { pos: p3, tangent: bezier_point_fma(p0, p1, p2, p3, 0.9) }
  }
  let tail_bezier_sample = () => {
    let p0 = points[0]
    let p1 = points[1]
    let p2 = points[2]
    let p3 = points[3]
    { pos: p0, tangent: bezier_point_fma(p0, p1, p2, p3, 0.1) }
  }
  if head_p {
    if !marker_present {
      return Some(head_bezier_sample())
    }
    match spline.end {
      Some(end_point) => Some({ pos: end_point, tangent: points[points.length() - 1] })
      None => Some(head_bezier_sample())
    }
  } else {
    if !marker_present {
      return Some(tail_bezier_sample())
    }
    match spline.start {
      Some(start_point) => Some({ pos: start_point, tangent: points[0] })
      None => Some(tail_bezier_sample())
    }
  }
}

///|
fn port_label_pos_from_points(
  pe : @geom.Point,
  pf : @geom.Point,
  angle_deg : Double,
  distance_scale : Double,
) -> @geom.Point {
  let angle =
    @edge_spline.libm_fma(
      angle_deg / 180.0,
      GRAPHVIZ_PI,
      @edge_spline.libm_atan2(pf.y - pe.y, pf.x - pe.x),
    )
  let dist = PORT_LABEL_DISTANCE_PT * distance_scale
  @edge_spline.point(
    @edge_spline.libm_fma(dist, @edge_spline.libm_cos(angle), pe.x),
    @edge_spline.libm_fma(dist, @edge_spline.libm_sin(angle), pe.y),
  )
}

///|
fn edge_port_label_pos(
  input : @routing.EdgePortLabelPosInput,
) -> @geom.Point? {
  let edge = input.edge
  let spline = input.spline
  let head_p = input.is_head
  // Graphviz parity: map edge dir + arrow attrs to place_portlabel eflag/sflag.
  let graph_kind = edge.tail().graph().kind()
  let marker_present =
    if head_p {
      @dot_shared.edge_has_head_marker(edge, graph_kind)
    } else {
      @dot_shared.edge_has_tail_marker(edge, graph_kind)
    }
  let params = match port_label_params(edge) {
    Some(value) => value
    None => return None
  }
  let port_points = match port_label_points(spline, head_p, marker_present) {
    Some(value) => value
    None => return None
  }
  Some(
    port_label_pos_from_points(
      port_points.pos,
      port_points.tangent,
      params.angle_deg,
      params.distance_scale,
    ),
  )
}
///|
/// Edge-label rank/vnode helpers aligned with Graphviz dotsplines label flows.

///|
fn edge_label_rank_info(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
) -> EdgeLabelRankInfo? {
  if edge_mid_label_width_pt(edge) <= 0.0 {
    return None
  }
  let tail_rank = match ranks.get(edge.tail().name()) {
    Some(value) => value
    None => return None
  }
  let head_rank = match ranks.get(edge.head().name()) {
    Some(value) => value
    None => return None
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  let span = max_rank - min_rank
  if span <= 1 {
    return None
  }
  let label_rank = (min_rank + max_rank) / 2
  Some({ label_rank, span })
}

///|
fn edge_label_rank_y(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
) -> Double? {
  match edge_label_rank_info(edge, ranks) {
    Some(info) => rank_y.get(info.label_rank)
    None => None
  }
}

///|
fn edge_label_rank_x(
  edge : @cgraph.Edge,
  label_rank : Int,
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_positions : Map[String, @geom.Point],
) -> Double? {
  match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(vnodes) =>
      for name in vnodes {
        match vnode_ranks.get(name) {
          Some(rank) =>
            if rank == label_rank {
              match vnode_positions.get(name) {
                Some(pos) => return Some(pos.x)
                None => ()
              }
            }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
/// Graphviz parity: label vnode offset aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// (place_vnlabel, GD_flip).
/// Do not change behavior without updating fixtures/tests.
fn edge_label_pos_from_vnode(
  vnode_pos : @geom.Point,
  label_width_pt : Double,
  label_height_pt : Double,
  rankdir : RankDir,
) -> @geom.Point {
  let width =
    if rankdir == RankDir::LR || rankdir == RankDir::RL {
      label_height_pt
    } else {
      label_width_pt
    }
  @edge_spline.point(vnode_pos.x + width / 2.0, vnode_pos.y)
}

///|
fn vnode_is_merged(
  name : String,
  adjacency : @routesplines.PathAdjacency,
) -> Bool {
  let out_raw = match adjacency.out_edges.get(name) {
    Some(list) => list
    None => []
  }
  let in_raw = match adjacency.in_edges.get(name) {
    Some(list) => list
    None => []
  }
  let unique_count = (list : Array[String]) => {
    let seen : Map[String, Bool] = Map::new()
    let mut count = 0
    for item in list {
      if seen.get(item) is None {
        seen[item] = true
        count = count + 1
      }
    }
    count
  }
  // Graphviz virtual edges can carry parallel multiplicity on one edge record.
  // Our path adjacency lists parallel hops explicitly, so merge detection must
  // compare distinct predecessors/successors instead of raw multiplicity.
  let out_count = unique_count(out_raw)
  let in_count = unique_count(in_raw)
  out_count > 1 || in_count > 1
}

///|
/// Graphviz parity: recover_slack aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
fn recover_slack_vnodes(
  input : @routing.RecoverSlackVnodesInput,
) -> Unit {
  let edge = input.edge
  let ordered_vnodes = input.ordered_vnodes
  let boxes = input.boxes
  let ranks = input.ranks
  let vnode_ranks = input.vnode_ranks
  let rank_y = input.rank_y
  let vnode_positions = input.vnode_positions
  let vnode_sizes = input.vnode_sizes
  let adjacency = input.adjacency
  if ordered_vnodes.length() == 0 || boxes.length() == 0 {
    return ()
  }
  let label_rank = match edge_label_rank_info(edge, ranks) {
    Some(info) => info.label_rank
    None => -1
  }
  let mut box_idx = 0
  for vnode in ordered_vnodes {
    if vnode_is_merged(vnode, adjacency) {
      break
    }
    let vnode_rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let vnode_y = match rank_y.get(vnode_rank) {
      Some(value) => value
      None => continue
    }
    while box_idx < boxes.length() && boxes[box_idx].lly > vnode_y {
      box_idx = box_idx + 1
    }
    if box_idx >= boxes.length() {
      break
    }
    let box = boxes[box_idx]
    if box.ury < vnode_y {
      continue
    }
    let size = match vnode_sizes.get(vnode) {
      Some(value) => value
      None => continue
    }
    if vnode_rank == label_rank {
      let new_x = box.urx
      let left = new_x - box.llx
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        @dot_shared.vnode_size_from_widths_with_h(left, size.right_pt, size.height_pt)
    } else {
      let new_x = (box.llx + box.urx) / 2.0
      let half = (box.urx - box.llx) / 2.0
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        @dot_shared.vnode_size_from_widths_with_h(half, half, size.height_pt)
    }
  }
}
///|
/// Edge-label overlap nudge geometry plus spline sampling/tangent helpers used
/// by edge-label and port-label placement paths.

///|
priv struct PointWithTangent {
  pos : @geom.Point
  tangent : @geom.Point
}

///|
priv struct EdgeLabelRankInfo {
  label_rank : Int
  span : Int
}

///|
priv struct RectOverlapAmount {
  overlap_x : Double
  overlap_y : Double
}

///|
priv struct LabelRectNudge {
  label_pos : @geom.Point
  label_rect : @geom.Rect
}

///|
fn rect_overlap_amount(
  a : @geom.Rect,
  b : @geom.Rect,
) -> RectOverlapAmount? {
  let overlap_x = min_double(a.urx, b.urx) - max_double(a.llx, b.llx)
  let overlap_y = min_double(a.ury, b.ury) - max_double(a.lly, b.lly)
  if overlap_x > 0.0 && overlap_y > 0.0 {
    Some({ overlap_x, overlap_y })
  } else {
    None
  }
}

///|
fn nudge_label_rect(
  label_pos : @geom.Point,
  label_rect : @geom.Rect,
  other_rect : @geom.Rect,
  label_width : Double,
  label_height : Double,
  pad : Double,
) -> LabelRectNudge {
  match rect_overlap_amount(label_rect, other_rect) {
    Some(overlap) => {
      let other_center : @geom.Point = {
        x: (other_rect.llx + other_rect.urx) / 2.0,
        y: (other_rect.lly + other_rect.ury) / 2.0,
      }
      if overlap.overlap_x < overlap.overlap_y {
        let dir = if label_pos.x < other_center.x { -1.0 } else { 1.0 }
        let shift = overlap.overlap_x + pad
        let new_pos : @geom.Point = {
          x: label_pos.x + dir * shift,
          y: label_pos.y,
        }
        {
          label_pos: new_pos,
          label_rect: rect_from_center(new_pos, label_width, label_height, pad),
        }
      } else {
        let dir = if label_pos.y < other_center.y { -1.0 } else { 1.0 }
        let shift = overlap.overlap_y + pad
        let new_pos : @geom.Point = {
          x: label_pos.x,
          y: label_pos.y + dir * shift,
        }
        {
          label_pos: new_pos,
          label_rect: rect_from_center(new_pos, label_width, label_height, pad),
        }
      }
    }
    None => { label_pos, label_rect }
  }
}

///|
fn edge_tail_point(edge_layout : DotLayoutEdge) -> @geom.Point? {
  match edge_layout.splines.get(0) {
    Some(spline) =>
      match spline.start {
        Some(point) => Some(point)
        None =>
          if spline.points.length() > 0 { Some(spline.points[0]) } else { None }
      }
    None => None
  }
}

///|
fn bezier_point(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let p01 = @edge_spline.point_lerp(p0, p1, t)
  let p12 = @edge_spline.point_lerp(p1, p2, t)
  let p23 = @edge_spline.point_lerp(p2, p3, t)
  let p012 = @edge_spline.point_lerp(p01, p12, t)
  let p123 = @edge_spline.point_lerp(p12, p23, t)
  @edge_spline.point_lerp(p012, p123, t)
}

///|
/// Graphviz parity: linear interpolation aligned to refs/graphviz/lib/common/utils.c
/// (Bezier helper, uses fused multiply-add to match Graphviz compiler output).
/// Do not change behavior without updating fixtures/tests.
fn point_lerp_fma(
  a : @geom.Point,
  b : @geom.Point,
  t : Double,
) -> @geom.Point {
  let mt = 1.0 - t
  let x = @edge_spline.libm_fma(mt, a.x, t * b.x)
  let y = @edge_spline.libm_fma(mt, a.y, t * b.y)
  @edge_spline.point(x, y)
}

///|
/// Graphviz parity: Bézier evaluation aligned to refs/graphviz/lib/common/utils.c
/// (Bezier).
/// Do not change behavior without updating fixtures/tests.
fn bezier_point_fma(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let vtemp : Array[Array[@geom.Point]] = []
  let mut row = 0
  while row < 4 {
    let line : Array[@geom.Point] = []
    let mut col = 0
    while col < 4 {
      line.push(@edge_spline.point(0.0, 0.0))
      col = col + 1
    }
    vtemp.push(line)
    row = row + 1
  }
  vtemp[0][0] = p0
  vtemp[0][1] = p1
  vtemp[0][2] = p2
  vtemp[0][3] = p3
  let mut i = 1
  while i <= 3 {
    let mut j = 0
    while j <= 3 - i {
      let a = vtemp[i - 1][j]
      let b = vtemp[i - 1][j + 1]
      vtemp[i][j] = point_lerp_fma(a, b, t)
      j = j + 1
    }
    i = i + 1
  }
  vtemp[3][0]
}

///|
fn sample_spline_points(
  points : Array[@geom.Point],
  steps : Int,
) -> Array[@geom.Point] {
  let samples : Array[@geom.Point] = []
  if points.length() == 0 || steps <= 0 {
    return samples
  }
  samples.push(points[0])
  let mut index = 0
  let step_count = steps.to_double()
  while index + 3 < points.length() {
    let p0 = points[index]
    let p1 = points[index + 1]
    let p2 = points[index + 2]
    let p3 = points[index + 3]
    for step in 1..=steps {
      let t = step.to_double() / step_count
      samples.push(bezier_point(p0, p1, p2, p3, t))
    }
    index = index + 3
  }
  samples
}

///|
fn polyline_point_with_dir(
  points : Array[@geom.Point],
  target_len : Double,
) -> PointWithTangent? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some({ pos: points[0], tangent: @edge_spline.point(1.0, 0.0) })
  }
  let mut remaining = target_len
  let mut last_dir = @edge_spline.point(1.0, 0.0)
  let mut last_pos = points[points.length() - 1]
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = @edge_spline.segment_length(a, b)
    if seg_len > 0.0 {
      let delta = @edge_spline.point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      if len > 0.0 {
        last_dir = @edge_spline.point_scale(delta, 1.0 / len)
        last_pos = b
      }
    }
    if seg_len <= 0.0 {
      continue
    }
    if remaining <= seg_len {
      let t = remaining / seg_len
      let pos = @edge_spline.point_lerp(a, b, t)
      let delta = @edge_spline.point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let dir =
        if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
      return Some({ pos, tangent: dir })
    }
    remaining = remaining - seg_len
  }
  Some({ pos: last_pos, tangent: last_dir })
}

///|
fn polyline_point_at_axis(
  points : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> PointWithTangent? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some({ pos: points[0], tangent: @edge_spline.point(1.0, 0.0) })
  }
  let total_len = @edge_spline.polyline_length(points)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  let epsilon = 0.000001
  let mut traveled = 0.0
  let mut best_pos : @geom.Point? = None
  let mut best_dir : @geom.Point? = None
  let mut best_dist = 0.0
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = @edge_spline.segment_length(a, b)
    let a_axis = if axis_is_x { a.x } else { a.y }
    let b_axis = if axis_is_x { b.x } else { b.y }
    let min_axis = if a_axis < b_axis { a_axis } else { b_axis }
    let max_axis = if a_axis < b_axis { b_axis } else { a_axis }
    if axis_value < min_axis || axis_value > max_axis {
      traveled = traveled + seg_len
      continue
    }
    let delta_axis = b_axis - a_axis
    let t =
      if Double::abs(delta_axis) <= epsilon {
        0.5
      } else {
        (axis_value - a_axis) / delta_axis
      }
    let pos = @edge_spline.point_lerp(a, b, t)
    let delta = @edge_spline.point_sub(b, a)
    let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
    let dir =
      if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
    let cross_len = traveled + seg_len * t
    let dist = Double::abs(cross_len - target)
    if best_pos is None || dist < best_dist {
      best_pos = Some(pos)
      best_dir = Some(dir)
      best_dist = dist
    }
    traveled = traveled + seg_len
  }
  match best_pos {
    Some(pos) =>
      match best_dir {
        Some(dir) => Some({ pos, tangent: dir })
        None => None
      }
    None => None
  }
}

///|
fn spline_label_pos_with_samples(
  samples : Array[@geom.Point],
) -> PointWithTangent? {
  if samples.length() == 0 {
    return None
  }
  let total_len = @edge_spline.polyline_length(samples)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  polyline_point_with_dir(samples, target)
}

///|
fn spline_label_pos_at_samples(
  samples : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> PointWithTangent? {
  if samples.length() == 0 {
    return None
  }
  polyline_point_at_axis(samples, axis_value, axis_is_x)
}
