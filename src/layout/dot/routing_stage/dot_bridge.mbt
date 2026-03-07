///|
/// Dot-owned bridge logic for routing_stage default dependencies: layout node
/// assembly, routing bbox/port geometry, and edge-layout callback wiring.

///|
/// Graphviz parity: node layout assembly aligned to refs/graphviz/lib/dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_layout_nodes_for_routing_stage(
  nodes : Array[@cgraph.Node],
  positions : Map[String, @geom.Point],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Array[DotLayoutNode] {
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size =
      @shared.resolve_node_output_size(
        output_sizes,
        node,
        record_orientation,
        @node_geometry.node_size,
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
/// Graphviz parity: port layout maps aligned to refs/graphviz/lib/common/shapes.c (record/html ports).
/// Do not change behavior without updating fixtures/tests.
fn build_port_layout_maps_for_routing_stage(
  nodes_out : Array[DotLayoutNode],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  rankdir : RankDir,
  has_port_edges : Bool,
) -> RoutingPortLayoutMaps {
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  let label_ports_raw : Map[String, Map[String, RecordPort]] = Map::new()
  if has_port_edges {
    for node_layout in nodes_out {
      let final_size =
        @shared.resolve_node_output_size(
          output_sizes,
          node_layout.node,
          record_orientation,
          @node_geometry.node_size,
        )
      let name = node_layout.node.name()
      let raw_ports =
        @label_layout.raw_label_ports_for_node(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
          record_orientation,
        )
      if raw_ports.length() > 0 {
        label_ports_raw[name] = raw_ports
        let ports =
          @label_layout.layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      }
    }
  }
  { label_ports_map, label_ports_raw }
}

///|
fn compute_routing_bbox_for_stage(
  nodes_out : Array[DotLayoutNode],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> @geom.Rect {
  @bbox.compute_dot_bbox(
    {
      nodes_out,
      all_ranks,
      sizes,
      rank_y,
      rank_ht1,
      rank_ht2,
    },
  )
}

///|
fn routing_port_padding_for_stage(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> RoutingPortPadding {
  let padding =
    @label_layout.record_port_padding_y(
      edges,
      positions,
      label_ports_map,
    )
  { below: padding.below, above: padding.above }
}

///|
fn build_head_port_metrics_for_stage(
  edges : Array[@cgraph.Edge],
  enable_complex_tuning : Bool,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> @routing.HeadPortMetrics {
  @routing.build_head_port_metrics_from_geometry(
    {
      edges,
      enable_complex_tuning,
      positions,
      sizes,
    },
    {
      is_record_shape: @shared.is_record_shape,
      node_size_for_missing: node => @node_geometry.node_size(node, record_orientation),
      port_geometry_for:
        (node_name, port, node_pos, node_size) => {
          let geometry =
            @label_layout.port_geometry(
              node_name,
              port,
              label_ports_map,
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
}

///|
fn edge_has_mid_label_for_routing_stage(edge : @cgraph.Edge) -> Bool {
  @label_metrics.edge_mid_label_text(edge) is Some(_)
}

///|
fn build_route_base_deps_for_dot(
  record_orientation : RecordOrientation,
  routing_label_ports_map : Map[String, Map[String, RecordPort]],
  routing_label_ports_raw : Map[String, Map[String, RecordPort]],
) -> @routing.RouteBaseDeps {
  let route_mid_label_metrics : (@cgraph.Edge) -> @routing.RouteLabelMetrics? =
    (edge : @cgraph.Edge) =>
      match @label_metrics.edge_mid_label_metrics(edge) {
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
        @label_layout.port_geometry(
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
        @label_layout.dynamic_port_anchor_for_edge(
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
    node_size_for_missing: (node) => @node_geometry.node_size(node, record_orientation),
    edge_mid_label_metrics: route_mid_label_metrics,
    record_port_path_box: @label_layout.record_port_path_box,
    port_geometry: route_port_geometry,
    port_rect_from_geometry: @label_layout.port_rect_from_geometry,
    port_is_label_port:
      (node_name, port) =>
        @label_layout.port_is_label_port(node_name, port, routing_label_ports_raw),
    is_record_shape: @shared.is_record_shape,
    record_border_adjust:
      (node) =>
        if @shared.is_record_shape(node) &&
          !@html_label.is_html_label_text(@label_layout.label_text(node)) {
          @shared.RECORD_BORDER_PT
        } else {
          0.0
        },
    dynamic_port_anchor_for_edge: route_dynamic_port_anchor,
    port_side_mask_from_anchor: @label_layout.port_side_mask_from_anchor,
    port_side_for_edge:
      (port, port_rect, node_pos, node_size) =>
        @label_layout.port_side_for_edge(port, port_rect, node_pos, node_size, None),
    layout_port_offset: @label_layout.layout_port_offset,
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
      @edge_label.edge_port_label_pos(
        input,
        @node_geometry.PORT_LABEL_ANGLE_DEG,
        @node_geometry.PORT_LABEL_ANGLE_MIN_DEG,
        @node_geometry.PORT_LABEL_DISTANCE_PT,
        @node_geometry.GRAPHVIZ_PI,
      )
  let route_mid_label_metrics : (@cgraph.Edge) -> @routing.RouteLabelMetrics? =
    (edge : @cgraph.Edge) =>
      match @label_metrics.edge_mid_label_metrics(edge) {
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
          @label_metrics.edge_mid_label_width_pt(edge),
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
        @routing.recover_slack_vnodes(
          input,
          (edge, ranks) =>
            match @edge_label.edge_label_rank_info(
              edge,
              ranks,
              @label_metrics.edge_mid_label_width_pt(edge),
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
    self_edge_label_height_fn: @label_metrics.self_edge_label_height_pt,
    self_edge_label_width_fn: @label_metrics.self_edge_label_width_pt,
    edge_port_label_pos_fn: edge_port_label_pos_for_dot,
  }
}

///|
/// Graphviz parity: default dot routing deps keep routing-stage geometry,
/// callback bridges, and cluster-bbox tree recursion inside subpackages so the
/// root package no longer needs a Stage E-specific bridge file.
pub fn build_dot_routing_stage_deps() -> RoutingStageDeps {
  {
    build_layout_nodes: build_layout_nodes_for_routing_stage,
    build_port_layout_maps: build_port_layout_maps_for_routing_stage,
    compute_cluster_route_bboxes: @clustering.compute_cluster_route_bboxes,
    compute_routing_bbox: compute_routing_bbox_for_stage,
    edge_has_mid_label: edge_has_mid_label_for_routing_stage,
    record_port_padding: routing_port_padding_for_stage,
    build_head_port_metrics: build_head_port_metrics_for_stage,
    apply_self_edge_right_space: @port_bridge.apply_self_edge_right_space,
    build_route_base_deps: build_route_base_deps_for_dot,
    build_routing_callbacks: build_routing_callbacks_for_dot,
  }
}
