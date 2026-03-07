priv struct RoutingSpatialData {
  nodes_out : Array[DotLayoutNode]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
priv struct RoutingPortLayoutMaps {
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
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
/// Graphviz parity: node layout assembly aligned to refs/graphviz/lib/dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_routing_layout_nodes(
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
        record_orientation,
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
fn build_routing_port_layout_maps(
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
          record_orientation,
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
          @port_geometry.layout_ports_from_final(
            raw_ports,
            node_layout.pos,
            rankdir,
          )
        label_ports_map[name] = ports
      }
    }
  }
  { label_ports_map, label_ports_raw }
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
  let nodes_out =
    build_routing_layout_nodes(
      prep.nodes,
      positions_state.positions,
      prep.output_sizes,
      prep.record_orientation,
    )
  let port_layout_maps =
    build_routing_port_layout_maps(
      nodes_out,
      prep.output_sizes,
      prep.record_orientation,
      prep.rankdir,
      prep.has_port_edges,
    )
  let cluster_bboxes =
    @clustering.compute_cluster_route_bboxes(
      input.graph,
      nodes_out,
      positions_state.cluster_ln_x,
      positions_state.cluster_rn_x,
      positions_state.cluster_bbox_heights,
      prep.rankdir,
      input.ranks,
      positions_state.rank_y,
      positions_state.rank_ht1,
      positions_state.rank_ht2,
    )
  {
    nodes_out,
    label_ports_map: port_layout_maps.label_ports_map,
    label_ports_raw: port_layout_maps.label_ports_raw,
    cluster_bboxes,
  }
}
