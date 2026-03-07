///|
/// Dot-specific routing callback assembly that bridges routing execution and
/// edge-label layout behavior without leaving the routing owner tree.

///|
/// Graphviz parity: dot routing callbacks keep slack-vnode recovery, edge-label
/// layout, and port-label placement aligned with Stage E edge-routing rules.
/// Do not change behavior without updating fixtures/tests.
pub fn build_dot_routing_callbacks(
  edge_layout_input : @routing.EdgeLayoutInput,
) -> @routing.RoutingCallbacks {
  let edge_port_label_pos_for_dot =
    (input : @routing.EdgePortLabelPosInput) =>
      @edge_label.edge_port_label_pos(
        input,
        @node_geometry.PORT_LABEL_ANGLE_DEG,
        @node_geometry.PORT_LABEL_ANGLE_MIN_DEG,
        @node_geometry.PORT_LABEL_DISTANCE_PT,
        @node_geometry.GRAPHVIZ_PI,
      )
  let route_mid_label_metrics : (@cgraph.Edge) -> @routing.RouteLabelMetrics? =
    (edge : @cgraph.Edge) =>
      match @edge_label_metrics.edge_mid_label_metrics(edge) {
        Some(metrics) => Some({ width: metrics.width, height: metrics.height })
        None => None
      }
  let edge_layout_deps : @edge_label.EdgeLayoutDeps = {
    edge_label_rank_for_routing_fn:
      (edge, ranks, mid_label_width_pt) =>
        match @edge_label.edge_label_rank_info(edge, ranks, mid_label_width_pt) {
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
        @edge_label.edge_label_rank_y(
          edge,
          ranks,
          rank_y,
          @edge_label_metrics.edge_mid_label_width_pt(edge),
        ),
    edge_label_rank_x_fn: @edge_label.edge_label_rank_x,
    edge_label_pos_from_vnode_fn: @edge_label.edge_label_pos_from_vnode,
    flat_edge_label_pos_simple_fn:
      (tail_port, head_port, tail_right_pt, head_left_pt, label_height_pt) =>
        @edge_label.flat_edge_label_pos_simple(
          tail_port,
          head_port,
          tail_right_pt,
          head_left_pt,
          label_height_pt,
          @node_geometry.EDGE_LABEL_FLAT_SPACE_PT,
        ),
    edge_label_pos_fn:
      input =>
        @edge_label.edge_label_pos_from_input(
          input,
          route_mid_label_metrics,
          @node_geometry.EDGE_LABEL_PAD_WIDTH_PT,
        ),
    edge_port_label_pos_fn: edge_port_label_pos_for_dot,
  }
  {
    recover_slack_vnodes_fn:
      input =>
        @execution.recover_slack_vnodes(
          input,
          (edge, ranks) =>
            match @edge_label.edge_label_rank_info(
              edge,
              ranks,
              @edge_label_metrics.edge_mid_label_width_pt(edge),
            ) {
              Some(info) => Some(info.label_rank)
              None => None
            },
        ),
    build_edge_layout_fn: (input) =>
      @edge_label.build_edge_layout(
        {
          base: input.base,
          spline: input.spline,
          spline_result: input.spline_result,
          edge_layout_input,
          deps: edge_layout_deps,
        }
      ),
    self_edge_label_height_fn: @edge_label_metrics.self_edge_label_height_pt,
    self_edge_label_width_fn: @edge_label_metrics.self_edge_label_width_pt,
    edge_port_label_pos_fn: edge_port_label_pos_for_dot,
  }
}
