///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_close(actual.x, expected.x, eps~)
  assert_close(actual.y, expected.y, eps~)
}

///|
fn[K : Hash + Eq, V] require_map_value(
  map : Map[K, V],
  key : K,
  label : String,
) -> V raise {
  match map.get(key) {
    Some(value) => value
    None => fail("missing \{label}")
  }
}

///|
fn sample_node_size(width_pt : Double, height_pt : Double) -> NodeSize {
  @node_primitives.node_size_from_points(width_pt, height_pt)
}

///|
fn sample_layout_prep(
  rankdir : RankDir,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_port_edges : Bool,
  output_sizes : Map[String, NodeSize],
  sizes : Map[String, NodeSize],
) -> LayoutPrep {
  {
    rankdir,
    nodesep_in: 0.25,
    ranksep_in: 0.5,
    splines: @shared.SplinesMode::Spline,
    nodes,
    edges,
    has_dotted_edges: false,
    has_port_edges,
    has_edge_labels: false,
    node_order: Map::new(),
    record_orientation: @shared.record_layout_orientation(rankdir),
    output_sizes,
    order_sizes: output_sizes,
    sizes,
    port_order_positions: Map::new(),
    port_order_contrib: Map::new(),
  }
}

///|
fn sample_position_result(
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  let empty_x_groups : Map[Int, Array[String]] = Map::new()
  let empty_flat_label_edge_vnodes : Map[String, String] = Map::new()
  let empty_cluster_bbox_heights = Map::new()
  {
    x_groups: empty_x_groups,
    rank_y,
    positions,
    vnode_positions,
    cluster_ln_x,
    cluster_rn_x,
    flat_label_edge_vnodes: empty_flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
    cluster_bbox_heights: empty_cluster_bbox_heights,
  }
}

///|

///|
fn sample_rank_data(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
) -> RankData {
  let input = @rank_data.make_rank_data_input(graph, nodes, [], false, 1, _ => {
    0.0
  })
  @rank_data.compute_rank_data(input)
}

///|
fn sample_record_port(
  center : @geom.Point,
  width_pt : Double,
  height_pt : Double,
) -> RecordPort {
  { center, size: sample_node_size(width_pt, height_pt), sides: 0 }
}

///|
test "build_routing_layout_nodes uses provided positions and defaults missing nodes to origin" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let positions : Map[String, @geom.Point] = { "a": { x: 10.0, y: 20.0 } }
  let output_sizes : Map[String, NodeSize] = {
    "a": sample_node_size(12.0, 8.0),
    "b": sample_node_size(20.0, 10.0),
  }

  let nodes_out = build_routing_layout_nodes(
    [a, b],
    positions,
    output_sizes,
    RecordOrientation::Horizontal,
  )

  assert_eq(nodes_out.length(), 2)
  assert_point_close(nodes_out[0].pos, { x: 10.0, y: 20.0 })
  assert_close(nodes_out[0].width_in, 12.0 / 72.0)
  assert_close(nodes_out[0].height_in, 8.0 / 72.0)
  assert_point_close(nodes_out[1].pos, { x: 0.0, y: 0.0 })
  assert_close(nodes_out[1].width_in, 20.0 / 72.0)
  assert_close(nodes_out[1].height_in, 10.0 / 72.0)
}

///|
test "build_routing_port_layout_maps gates on port edges and rotates record ports into layout coordinates" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("record")
  node.set_attr("shape", "record")
  node.set_attr("label", "<left>l|<right>r")
  let rankdir = RankDir::LR
  let orientation = @shared.record_layout_orientation(rankdir)
  let size = @node_geometry.node_size(node, orientation)
  let nodes_out : Array[DotLayoutNode] = [
    {
      node,
      pos: { x: 100.0, y: 50.0 },
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    },
  ]
  let output_sizes : Map[String, NodeSize] = { "record": size }

  let disabled = build_routing_port_layout_maps(
    nodes_out, output_sizes, orientation, rankdir, false,
  )
  assert_eq(disabled.label_ports_map.length(), 0)
  assert_eq(disabled.label_ports_raw.length(), 0)

  let enabled = build_routing_port_layout_maps(
    nodes_out, output_sizes, orientation, rankdir, true,
  )
  let raw_ports = require_map_value(
    enabled.label_ports_raw,
    "record",
    "raw ports",
  )
  let layout_ports = require_map_value(
    enabled.label_ports_map,
    "record",
    "layout ports",
  )
  let raw_left = require_map_value(raw_ports, "left", "raw left")
  let layout_left = require_map_value(layout_ports, "left", "layout left")
  let expected_offset = @port_geometry.layout_port_offset(
    raw_left.center,
    rankdir,
  )

  assert_eq(raw_ports.length(), 2)
  assert_eq(layout_ports.length(), 2)
  assert_point_close(layout_left.center, {
    x: 100.0 + expected_offset.x,
    y: 50.0 + expected_offset.y,
  })
  assert_close(layout_left.size.width_pt, raw_left.size.height_pt)
  assert_close(layout_left.size.height_pt, raw_left.size.width_pt)
}

///|
test "build_routing_ratio_adjusted_data keeps geometry unchanged when ratio fill is inactive" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("a")
  let size = sample_node_size(10.0, 10.0)
  let output_sizes : Map[String, NodeSize] = { "a": size }
  let positions : Map[String, @geom.Point] = { "a": { x: 5.0, y: 5.0 } }
  let position_state = sample_position_result(
    positions,
    Map::new(),
    { "cluster": 1.5 },
    { "cluster": 2.5 },
    { 0: 5.0 },
    { 0: 5.0 },
    { 0: 5.0 },
  )
  let nodes_out = build_routing_layout_nodes(
    [node],
    positions,
    output_sizes,
    RecordOrientation::Horizontal,
  )
  let cluster_bboxes : Map[String, @geom.Rect] = {
    "cluster": { llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 },
  }
  let label_ports_map : Map[String, Map[String, RecordPort]] = {
    "a": { "p": sample_record_port({ x: 1.0, y: 2.0 }, 2.0, 4.0) },
  }
  let prep = sample_layout_prep(
    RankDir::TB,
    [node],
    [],
    false,
    output_sizes,
    output_sizes,
  )

  let adjusted = build_routing_ratio_adjusted_data({
    graph,
    prep,
    rank_data: sample_rank_data(graph, [node]),
    nodes_out,
    positions_state: position_state,
    cluster_bboxes,
    label_ports_map,
    label_ports_raw: label_ports_map,
  })

  assert_false(adjusted.ratio_scaled)
  assert_close(adjusted.ratio_sx, 1.0)
  assert_close(adjusted.ratio_sy, 1.0)
  assert_eq(
    adjusted.positions_state.positions.get("a"),
    Some({ x: 5.0, y: 5.0 }),
  )
  assert_eq(
    adjusted.cluster_bboxes.get("cluster"),
    Some({ llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 }),
  )
  let adjusted_ports = require_map_value(
    adjusted.label_ports_map,
    "a",
    "adjusted ports",
  )
  let adjusted_port = require_map_value(adjusted_ports, "p", "adjusted port")
  assert_point_close(adjusted_port.center, { x: 1.0, y: 2.0 })
  assert_close(adjusted_port.size.width_pt, 2.0)
  assert_close(adjusted_port.size.height_pt, 4.0)
}

///|
test "build_routing_ratio_adjusted_data scales positions cluster boxes and port maps for ratio fill" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ratio", "fill")
  graph.set_attr("size", "1,2")
  let node = graph.node("a")
  let size = sample_node_size(10.0, 10.0)
  let output_sizes : Map[String, NodeSize] = { "a": size }
  let positions : Map[String, @geom.Point] = { "a": { x: 5.0, y: 5.0 } }
  let vnode_positions : Map[String, @geom.Point] = { "v1": { x: 1.5, y: 2.5 } }
  let position_state = sample_position_result(
    positions,
    vnode_positions,
    { "cluster": 1.5 },
    { "cluster": 2.5 },
    { 0: 5.0 },
    { 0: 5.0 },
    { 0: 5.0 },
  )
  let nodes_out = build_routing_layout_nodes(
    [node],
    positions,
    output_sizes,
    RecordOrientation::Horizontal,
  )
  let cluster_bboxes : Map[String, @geom.Rect] = {
    "cluster": { llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 },
  }
  let label_ports_map : Map[String, Map[String, RecordPort]] = {
    "a": { "p": sample_record_port({ x: 1.0, y: 2.0 }, 2.0, 4.0) },
  }
  let prep = sample_layout_prep(
    RankDir::TB,
    [node],
    [],
    false,
    output_sizes,
    output_sizes,
  )

  let adjusted = build_routing_ratio_adjusted_data({
    graph,
    prep,
    rank_data: sample_rank_data(graph, [node]),
    nodes_out,
    positions_state: position_state,
    cluster_bboxes,
    label_ports_map,
    label_ports_raw: label_ports_map,
  })

  assert_true(adjusted.ratio_scaled)
  assert_close(adjusted.ratio_sx, 7.2)
  assert_close(adjusted.ratio_sy, 14.4)
  assert_eq(
    adjusted.positions_state.positions.get("a"),
    Some({ x: 36.0, y: 72.0 }),
  )
  assert_eq(
    adjusted.positions_state.vnode_positions.get("v1"),
    Some({ x: 11.0, y: 36.0 }),
  )
  assert_close(
    require_map_value(
      adjusted.positions_state.cluster_ln_x,
      "cluster",
      "cluster ln x",
    ),
    10.8,
  )
  assert_close(
    require_map_value(
      adjusted.positions_state.cluster_rn_x,
      "cluster",
      "cluster rn x",
    ),
    18.0,
  )
  assert_eq(adjusted.positions_state.rank_y.get(0), Some(72.0))
  let cluster_bbox = require_map_value(
    adjusted.cluster_bboxes,
    "cluster",
    "scaled cluster bbox",
  )
  assert_close(cluster_bbox.llx, 7.2)
  assert_close(cluster_bbox.lly, 28.8)
  assert_close(cluster_bbox.urx, 21.6)
  assert_close(cluster_bbox.ury, 57.6)
  let adjusted_ports = require_map_value(
    adjusted.label_ports_map,
    "a",
    "scaled ports",
  )
  let adjusted_port = require_map_value(adjusted_ports, "p", "scaled port")
  assert_point_close(adjusted_port.center, { x: 7.2, y: 28.8 })
  assert_close(adjusted_port.size.width_pt, 14.4)
  assert_close(adjusted_port.size.height_pt, 57.6)
}
