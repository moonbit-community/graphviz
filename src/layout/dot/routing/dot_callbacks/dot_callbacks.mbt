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
        },
      ),
    self_edge_label_height_fn: @edge_label_metrics.self_edge_label_height_pt,
    self_edge_label_width_fn: @edge_label_metrics.self_edge_label_width_pt,
    edge_port_label_pos_fn: @edge_label.edge_port_label_pos_for_dot,
  }
}
