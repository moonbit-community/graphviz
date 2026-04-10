// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Dot-specific Stage E assembly lives with the routing integration owner so
/// callback/dependency wiring stays alongside the pipeline that consumes it.

///|
/// Graphviz parity: dot route-base deps keep port-geometry, record/html border,
/// and label-metric callbacks aligned with the same dot routing rules used by
/// Stage E.
/// Do not change behavior without updating fixtures/tests.
pub fn build_dot_route_base_deps(
  record_orientation : @layout_prep.RecordOrientation,
  routing_label_ports_map : Map[
    String,
    Map[String, @record_geometry.RecordPort],
  ],
  routing_label_ports_raw : Map[
    String,
    Map[String, @record_geometry.RecordPort],
  ],
) -> @routing.RouteBaseDeps {
  let route_mid_label_metrics : (@cgraph.Edge) -> @routing.RouteLabelMetrics? = (
    edge : @cgraph.Edge,
  ) => {
    match @edge_label_metrics.edge_mid_label_metrics(edge) {
      Some(metrics) => Some({ width: metrics.width, height: metrics.height })
      None => None
    }
  }
  let route_port_geometry : (
    String,
    @cgraph.Port?,
    @geom.Point,
    @node_primitives.NodeSize,
  ) -> @precompute.RoutePortGeometry = (
    node_name : String,
    port : @cgraph.Port?,
    node_pos : @geom.Point,
    node_size : @node_primitives.NodeSize,
  ) => {
    let geometry = @port_geometry.port_geometry(
      node_name, port, routing_label_ports_map, node_pos, node_size,
    )
    { center: geometry.center, size: geometry.size }
  }
  let route_dynamic_port_anchor : (
    @cgraph.Port?,
    String,
    @geom.Point,
    @geom.Point,
    @rankdir.RankDir,
    Double,
  ) -> @routing.RouteDynamicPortAnchor = (
    port : @cgraph.Port?,
    node_name : String,
    node_pos : @geom.Point,
    other_pos : @geom.Point,
    rankdir : @rankdir.RankDir,
    record_border_adjust : Double,
  ) => {
    let anchor = @port_geometry.dynamic_port_anchor_for_edge(
      port, node_name, routing_label_ports_raw, node_pos, other_pos, rankdir, record_border_adjust,
    )
    { anchor: anchor.anchor, side: anchor.side, is_dynamic: anchor.is_dynamic }
  }
  {
    node_size_for_missing: node => {
      @node_geometry.node_size(node, record_orientation)
    },
    edge_mid_label_metrics: route_mid_label_metrics,
    record_port_path_box: @record_layout.record_port_path_box,
    port_geometry: route_port_geometry,
    port_rect_from_geometry: @port_geometry.port_rect_from_geometry,
    port_is_label_port: (node_name, port) => {
      @port_geometry.port_is_label_port(
        node_name, port, routing_label_ports_raw,
      )
    },
    is_record_shape: @record_geometry.is_record_shape,
    record_border_adjust: node => {
      if @record_geometry.is_record_shape(node) &&
        !@html_label.is_html_label_text(@label_attrs.label_text(node)) {
        @record_geometry.RECORD_BORDER_PT
      } else {
        0.0
      }
    },
    dynamic_port_anchor_for_edge: route_dynamic_port_anchor,
    port_side_mask_from_anchor: @port_geometry.port_side_mask_from_anchor,
    port_side_for_edge: (port, port_rect, node_pos, node_size) => {
      @port_geometry.port_side_for_edge(
        port,
        port_rect,
        node_pos,
        node_size,
        None,
      )
    },
    layout_port_offset: @port_geometry.layout_port_offset,
    node_cluster_key: @membership.node_cluster_key,
    node_local_cluster_key: @membership.node_local_cluster_key,
  }
}

///|
/// Graphviz parity: dot routing callbacks keep slack-vnode recovery, edge-label
/// layout, and port-label placement aligned with Stage E edge-routing rules.
/// Do not change behavior without updating fixtures/tests.
pub fn build_dot_routing_callbacks(
  edge_layout_input : @routing.EdgeLayoutInput,
) -> @routing.RoutingCallbacks {
  {
    recover_slack_vnodes_fn: input => {
      @execution.recover_slack_vnodes(input, (edge, ranks) => {
        match
          @edge_label.edge_label_rank_info(
            edge,
            ranks,
            @edge_label_metrics.edge_mid_label_width_pt(edge),
          ) {
          Some(info) => Some(info.label_rank)
          None => None
        }
      })
    },
    build_edge_layout_fn: input => {
      @edge_label.build_edge_layout({
        base: input.base,
        spline: input.spline,
        spline_result: input.spline_result,
        edge_layout_input,
      })
    },
    self_edge_label_height_fn: @edge_label_metrics.self_edge_label_height_pt,
    self_edge_label_width_fn: @edge_label_metrics.self_edge_label_width_pt,
    edge_port_label_pos_fn: @edge_label.edge_port_label_pos_for_dot,
  }
}
