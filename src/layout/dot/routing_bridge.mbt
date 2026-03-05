///|
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

///|
fn self_edge_label_height_pt_for_routing(
  edge : @cgraph.Edge,
  rankdir : RankDir,
) -> Double {
  match edge_mid_label_metrics(edge) {
    Some(metrics) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        metrics.width
      } else {
        metrics.height
      }
    None => 0.0
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
    record_port_path_box:
      (node, port, pos, size, rankdir) =>
        record_port_path_box(
          node,
          port,
          pos,
          size,
          rankdir,
        ),
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
    port_rect_from_geometry:
      (port, center, port_size, node_size) =>
        port_rect_from_geometry(port, center, port_size, node_size),
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
    edge_dir_for:
      (edge, kind) =>
        match edge_dir_for(edge, kind) {
          EdgeDir::Forward => @routing.RouteEdgeDir::Forward
          EdgeDir::Back => @routing.RouteEdgeDir::Back
          EdgeDir::Both => @routing.RouteEdgeDir::Both
          EdgeDir::None => @routing.RouteEdgeDir::None
        },
    node_cluster_key,
    node_local_cluster_key,
  }
}

///|
priv struct RoutingEdgeLayoutBuildInput {
  base : @routing.EdgeRouteBase
  spline : @geom.Spline
  spline_result : @routing.EdgeSplineResult
  edge_layout_input : @routing.EdgeLayoutInput
}

///|
fn build_routing_edge_layout_deps() -> @routing.EdgeLayoutDeps {
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
}

///|
fn build_routing_edge_layout_for_dot(
  input : RoutingEdgeLayoutBuildInput,
) -> DotLayoutEdge {
  @routing.build_edge_layout(
    {
      base: input.base,
      spline: input.spline,
      spline_result: input.spline_result,
      edge_layout_input: input.edge_layout_input,
      deps: build_routing_edge_layout_deps(),
    },
  )
}

///|
fn build_routing_callbacks_for_dot(
  edge_layout_input : @routing.EdgeLayoutInput,
) -> @routing.RoutingCallbacks {
  {
    recover_slack_vnodes_fn: recover_slack_vnodes,
    build_edge_layout_fn: (input) =>
      build_routing_edge_layout_for_dot(
        {
          base: input.base,
          spline: input.spline,
          spline_result: input.spline_result,
          edge_layout_input,
        },
      ),
    self_edge_label_height_fn: self_edge_label_height_pt_for_routing,
    self_edge_label_width_fn: self_edge_label_width_pt,
    edge_port_label_pos_fn: edge_port_label_pos,
  }
}

///|
fn build_route_edges_pipeline_input_for_dot(
  input : RouteEdgesForDotInput,
) -> @routing.RouteEdgesPipelineInput {
  let layout_rankdir = RankDir::TB
  {
    graph_kind: input.graph.kind(),
    rankdir: input.prep.rankdir,
    layout_rankdir,
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
}

///|
fn build_route_edges_pipeline_deps_for_dot(
  input : RouteEdgesForDotInput,
  edge_layout_input : @routing.EdgeLayoutInput,
) -> @routing.RouteEdgesPipelineDeps {
  {
    route_base_deps:
      build_route_base_deps_for_dot(
        input.prep.record_orientation,
        input.routing_label_ports_map,
        input.routing_label_ports_raw,
      ),
    callbacks: build_routing_callbacks_for_dot(edge_layout_input),
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
  @routing.route_edges_pipeline(
    build_route_edges_pipeline_input_for_dot(input),
    build_route_edges_pipeline_deps_for_dot(input, edge_layout_input),
  )
}
