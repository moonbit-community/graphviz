// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
    splines: @layout_prep.SplinesMode::Spline,
    nodes,
    edges,
    has_dotted_edges: false,
    has_port_edges,
    has_edge_labels: false,
    node_order: Map::new(),
    record_orientation: @layout_prep.record_layout_orientation(rankdir),
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
