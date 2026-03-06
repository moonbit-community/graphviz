///|
/// Stage D positioning boundary file: root-only geometry and label bridges plus
/// position stage dependency assembly. Stage-internal orchestration lives in the
/// position_stage subpackage.

type PositionStageInput = @position_stage.PositionStageInput

type PositionStageDeps = @position_stage.PositionStageDeps

type PositionResult = @positioning.PositionResult

///|
fn build_x_seed_port_samples_for_stage(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  x_order_sizes : Map[String, NodeSize],
) -> @ordering.EdgePortSampleBundle {
  @positioning.build_edge_port_sample_bundle(
    nodes,
    edges,
    edge_tail,
    edge_head,
    x_order_sizes,
    port_offsets_for_nodes,
    edge_port_offset,
    edge_port_order,
  )
}

///|
fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> Map[String, Map[String, RecordPort]] {
  @positioning.build_port_offsets_for_nodes(
    nodes,
    output_sizes,
    (node, rankdir) => {
      let record_orientation = @dot_shared.record_layout_orientation(rankdir)
      node_size(node, record_orientation)
    },
    (node, origin, base_size, rankdir) => {
      let record_orientation = @dot_shared.record_layout_orientation(rankdir)
      raw_label_ports_for_node(node, origin, base_size, record_orientation)
    },
    layout_port_offset,
    swap_node_size,
  )
}

///|
fn compass_uses_shape_clipping(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      true
    "diamond"
    | "mdiamond"
    | "triangle"
    | "invtriangle"
    | "trapezium"
    | "invtrapezium"
    | "parallelogram"
    | "egg"
    | "house"
    | "invhouse"
    | "pentagon"
    | "hexagon"
    | "septagon"
    | "octagon"
    | "doubleoctagon"
    | "tripleoctagon" =>
      true
    "polygon" => {
      let attrs = polygon_shape_attrs(node)
      if attrs.sides < 3 {
        true
      } else {
        !polygon_is_box_like(
          attrs.sides,
          attrs.orientation,
          attrs.distortion,
          attrs.skew,
        )
      }
    }
    _ => false
  }
}

///|
fn compass_port_point_for_layout(
  node_name : String,
  node : @cgraph.Node?,
  compass : @cgraph.Compass,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
) -> @geom.Point {
  @positioning.compass_port_point(
    node_name,
    node,
    compass,
    sizes,
    rankdir,
    compass_uses_shape_clipping,
    (shape_node, size, shape_compass, shape_rankdir) =>
      @edge_spline.compass_port_point_on_shape(
        shape_node,
        @edge_spline.point(0.0, 0.0),
        size,
        shape_compass,
        shape_rankdir,
      ),
    layout_port_offset,
  )
}

///|
fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  @positioning.edge_port_offset(
    node_name,
    port,
    offsets,
    compass =>
      @positioning.compass_port_offset(
        compass,
        node_name,
        sizes,
        rankdir,
        nodes_by_name.get(node_name),
        compass_port_point_for_layout,
        node =>
          @dot_shared.is_record_shape(node) ||
          @html_label.is_html_label_text(label_text(node)),
        layout_port_offset,
      ),
  )
}

///|
fn edge_port_order(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  @positioning.edge_port_order(
    node_name,
    port,
    offsets,
    compass =>
      compass_port_point_for_layout(
        node_name,
        nodes_by_name.get(node_name),
        compass,
        sizes,
        rankdir,
      ),
  )
}

///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128

///|
const ROOT_COMPRESS_WEIGHT : Int = 1000

///|
fn cluster_label_borders_for_xpos_constraints(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> (Double, Double) {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if !flip {
    return (0.0, 0.0)
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let border = metrics.height_pt + CLUSTER_LABEL_PAD_PT
      match @dot_shared.graph_label_loc(graph) {
        LabelLoc::Top => (0.0, border)
        LabelLoc::Bottom => (border, 0.0)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
fn has_port_edges_for_position_stage(edges : Array[@cgraph.Edge]) -> Bool {
  @dot_shared.scan_edge_flags(edges).has_port_edges
}

///|
fn edge_mid_label_metrics_for_position_stage(
  edge : @cgraph.Edge,
) -> (Double, Double)? {
  match @label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => Some((value.width, value.height))
    None => None
  }
}

///|
fn resolve_x_simplex_root_context(
  nodes : Array[@cgraph.Node],
) -> (RankDir, Double) {
  if nodes.length() > 0 {
    let root_graph = nodes[0].graph()
    (
      @dot_shared.graph_rankdir(root_graph),
      @positioning.cluster_margin_pt(root_graph),
    )
  } else {
    (RankDir::TB, CLUSTER_MARGIN_PT)
  }
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/position.c + cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_x_positions_for_stage(
  input : @positioning.XPositionSolveInput,
) -> Map[String, Double] {
  let port_offsets =
    if has_port_edges_for_position_stage(input.edges) {
      port_offsets_for_nodes(input.nodes, input.output_sizes)
    } else {
      Map::new()
    }
  let (rankdir, root_margin) =
    resolve_x_simplex_root_context(input.nodes)
  @positioning.compute_x_positions_with_prepared_constraints(
    input,
    {
      cluster_label_borders_for: cluster_label_borders_for_xpos_constraints,
      cluster_label_width_with_pad_for: cluster_label_width_with_pad_for_layout,
      cluster_compact_weight: CLUSTER_COMPACT_WEIGHT,
    },
    root_margin,
    ROOT_COMPRESS_WEIGHT,
    (segment, real_by_name) =>
      @positioning.segment_slack_minlen(
        segment,
        (node_name, port) =>
          edge_port_offset(
            node_name,
            port,
            port_offsets,
            input.sizes,
            rankdir,
            real_by_name,
          ),
      ),
    edge => @label_metrics.edge_mid_label_metrics(edge) is Some(_),
    edge =>
      if @dot_shared.edge_dir_for(edge, edge.tail().graph().kind()) is @dot_shared.EdgeDir::Both {
        2
      } else {
        1
      },
    @positioning.should_capture_xpos_snapshot(input.graph),
  )
}

///|
fn build_port_maps_for_nodes(
  nodes : Array[@cgraph.Node],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Map[String, Map[String, RecordPort]] {
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  let port_maps : Map[String, Map[String, RecordPort]] = Map::new()
  for node in nodes {
    let name = node.name()
    let size = @dot_shared.resolve_node_output_size(sizes, node, record_orientation, node_size)
    let ports =
      raw_label_ports_for_node(
        node,
        origin,
        size,
        record_orientation,
      )
    if ports.length() > 0 {
      port_maps[name] = ports
    }
  }
  port_maps
}

///|
fn port_side_mask_for_self_edge(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  port_maps : Map[String, Map[String, RecordPort]],
) -> Int {
  match port {
    None => 0
    Some(value) =>
      match value.compass {
        Some(compass) => compass_side_mask(compass)
        None =>
          match value.name {
            Some(port_name) =>
              match port_maps.get(node.name()) {
                Some(ports) =>
                  match ports.get(port_name) {
                    Some(info) => info.sides
                    None => 0
                  }
                None => 0
              }
            None => 0
          }
      }
  }
}

///|
/// Graphviz parity: self-edge right-side spacing aligned to
/// refs/graphviz/lib/dotgen/position.c (self-edge width padding).
/// Do not change behavior without updating fixtures/tests.
fn apply_self_edge_right_space(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, NodeSize] {
  let port_maps = build_port_maps_for_nodes(nodes, sizes, record_orientation)
  @routing.apply_self_edge_right_space(
    {
      edges,
      sizes,
      rankdir,
      self_edge_size_pt: SELF_EDGE_SIZE_PT,
      self_edge_label_width_for: @label_metrics.self_edge_label_width_pt,
      port_side_mask_for:
        (node, port) => port_side_mask_for_self_edge(node, port, port_maps),
    },
  )
}

///|
fn expand_cluster_label_bbox_for_position_stage(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Rect {
  match graph_label_metrics(graph) {
    Some(metrics) =>
      @dot_shared.expand_bbox_for_label(
        bbox,
        metrics.width_pt,
        metrics.height_pt,
        @dot_shared.graph_label_loc(graph),
      )
    None => bbox
  }
}

///|
fn build_position_stage_deps() -> PositionStageDeps {
  {
    max_xpos_vnodes: MAX_XPOS_VNODES,
    max_xpos_reorder_vnodes: MAX_XPOS_REORDER_VNODES,
    cluster_skeleton_penalty: CL_CROSS,
    build_x_seed_port_samples: build_x_seed_port_samples_for_stage,
    apply_self_edge_right_space,
    edge_mid_label_metrics_for: edge_mid_label_metrics_for_position_stage,
    compute_x_positions: compute_x_positions_for_stage,
    cluster_label_padding_for: cluster_label_padding_for_layout,
    cluster_label_width_with_pad_for: cluster_label_width_with_pad_for_layout,
    expand_cluster_label_bbox: expand_cluster_label_bbox_for_position_stage,
  }
}

///|
/// Graphviz parity: position stage root entry retains only the cross-stage and
/// root-geometry boundary wiring; stage-internal orchestration lives in the
/// position_stage subpackage.
/// Do not change behavior without updating fixtures/tests.
fn compute_positions(
  input : PositionStageInput,
) -> PositionResult {
  @position_stage.compute_positions(input, build_position_stage_deps())
}
