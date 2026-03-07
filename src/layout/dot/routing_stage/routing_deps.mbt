///|
/// Dot-owned routing dependency assembly for Stage E: node/port layout maps,
/// bbox/padding bridges, and routing callback wiring.

///|
pub(all) struct RoutingPortLayoutMaps {
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
pub(all) struct RoutingPortPadding {
  below : Double
  above : Double
}

///|
/// Graphviz parity: routing stage dependency payload groups root-boundary
/// geometry and bbox bridges so the subpackage owns stage-internal orchestration
/// without importing the root dot package.
pub(all) struct RoutingStageDeps {
  build_layout_nodes : (
    Array[@cgraph.Node],
    Map[String, @geom.Point],
    Map[String, NodeSize],
    RecordOrientation,
  ) -> Array[DotLayoutNode]
  build_port_layout_maps : (
    Array[DotLayoutNode],
    Map[String, NodeSize],
    RecordOrientation,
    RankDir,
    Bool,
  ) -> RoutingPortLayoutMaps
  compute_cluster_route_bboxes : (
    @cgraph.Graph,
    Array[DotLayoutNode],
    Map[String, Double],
    Map[String, Double],
    Map[String, ClusterBboxHeightPair],
    RankDir,
    Map[String, Int],
    Map[Int, Double],
    Map[Int, Double],
    Map[Int, Double],
  ) -> Map[String, @geom.Rect]
  compute_routing_bbox : (
    Array[DotLayoutNode],
    Array[Int],
    Map[String, NodeSize],
    Map[Int, Double],
    Map[Int, Double],
    Map[Int, Double],
  ) -> @geom.Rect
  edge_has_mid_label : (@cgraph.Edge) -> Bool
  record_port_padding : (
    Array[@cgraph.Edge],
    Map[String, @geom.Point],
    Map[String, Map[String, RecordPort]],
  ) -> RoutingPortPadding
  build_head_port_metrics : (
    Array[@cgraph.Edge],
    Bool,
    Map[String, @geom.Point],
    Map[String, NodeSize],
    RecordOrientation,
    Map[String, Map[String, RecordPort]],
  ) -> @precompute.HeadPortMetrics
  apply_self_edge_right_space : (
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Map[String, NodeSize],
    RankDir,
    RecordOrientation,
  ) -> Map[String, NodeSize]
  build_route_base_deps : (
    RecordOrientation,
    Map[String, Map[String, RecordPort]],
    Map[String, Map[String, RecordPort]],
  ) -> @routing.RouteBaseDeps
  build_routing_callbacks : (@routing.EdgeLayoutInput) -> @routing.RoutingCallbacks
}

///|

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
      @node_geometry.resolve_node_output_size(
        output_sizes,
        node,
        record_orientation
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
        @node_geometry.resolve_node_output_size(
          output_sizes,
          node_layout.node,
          record_orientation
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
          @port_geometry.layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
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
    @record_layout.record_port_padding_y(
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
) -> @precompute.HeadPortMetrics {
  @precompute.build_head_port_metrics_from_geometry(
    {
      edges,
      enable_complex_tuning,
      positions,
      sizes,
    },
    {
      is_record_shape: @record_geometry.is_record_shape,
      node_size_for_missing: node => @node_geometry.node_size(node, record_orientation),
      port_geometry_for:
        (node_name, port, node_pos, node_size) => {
          let geometry =
            @port_geometry.port_geometry(
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
/// Graphviz parity: default dot routing deps keep routing-stage geometry,
/// callback bridges, and cluster-bbox tree recursion inside subpackages so the
/// root package no longer needs a Stage E-specific bridge file.
pub fn build_dot_routing_stage_deps() -> RoutingStageDeps {
  {
    build_layout_nodes: build_layout_nodes_for_routing_stage,
    build_port_layout_maps: build_port_layout_maps_for_routing_stage,
    compute_cluster_route_bboxes: @clustering.compute_cluster_route_bboxes,
    compute_routing_bbox: compute_routing_bbox_for_stage,
    edge_has_mid_label: edge => @edge_label_metrics.edge_mid_label_text(edge) is Some(_),
    record_port_padding: routing_port_padding_for_stage,
    build_head_port_metrics: build_head_port_metrics_for_stage,
    apply_self_edge_right_space: @port_bridge.apply_self_edge_right_space,
    build_route_base_deps: @routing.build_dot_route_base_deps,
    build_routing_callbacks: @dot_callbacks.build_dot_routing_callbacks,
  }
}
