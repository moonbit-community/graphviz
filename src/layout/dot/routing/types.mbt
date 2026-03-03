///|
pub(all) struct EdgeRouteBase {
  edge : @cgraph.Edge
  parallel_offset : Double
  swap_ends : Bool
  orig_tail_name : String
  orig_head_name : String
  tail_name : String
  head_name : String
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_node : @cgraph.Node
  head_node : @cgraph.Node
  tail_pos : @geom.Point
  head_pos : @geom.Point
  tail_size : @dot_shared.NodeSize
  head_size : @dot_shared.NodeSize
  mid_label_width_pt : Double
  mid_label_height_pt : Double
  tail_record_path_box : @geom.Rect?
  head_record_path_box : @geom.Rect?
  tail_anchor : @geom.Point
  head_anchor : @geom.Point
  head_port_rect : @geom.Rect?
  tail_port_side : Int
  head_port_side : Int
  tail_sameport_group_size : Int
  head_sameport_group_size : Int
  tail_clip_center : @geom.Point
  tail_clip_size : @dot_shared.NodeSize
  head_clip_center : @geom.Point
  head_clip_size : @dot_shared.NodeSize
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
  tail_clip : @geom.Point
  head_clip : @geom.Point
  tail_slope : @geom.Point
  head_slope : @geom.Point
  force_segmented : Bool
  tail_cluster_bbox : @geom.Rect?
  head_cluster_bbox : @geom.Rect?
  tail_rank : Int
  head_rank : Int
  is_flat_edge : Bool
  is_flat_adjacent : Bool
  vnodes : Array[String]
  has_vnodes : Bool
  use_pathplan : Bool
  route_include_tail : Bool
  route_include_head : Bool
  arrow_len_override : Double?
  is_dotted : Bool
  same_outer_cluster : Bool
  diff_local_cluster : Bool
  same_local_cluster : Bool
  out_tail_anchor : @geom.Point
  out_head_anchor : @geom.Point
  out_tail_clip : @geom.Point
  out_head_clip : @geom.Point
  out_tail_pos : @geom.Point
  out_head_pos : @geom.Point
  out_tail_size : @dot_shared.NodeSize
  out_head_size : @dot_shared.NodeSize
  rankdir : @dot_shared.RankDir
  layout_rankdir : @dot_shared.RankDir
  has_side_anchor : Bool
}

///|
pub(all) struct EdgeSplineResult {
  spline : @geom.Spline
  label_pad_boost : Double
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  raw_bezier : Array[@geom.Point]
  pathplan_segments : Array[@routesplines.PathplanSegment]
  apply_dotted_adjustment : Bool
}

///|
pub(all) struct SelfEdgeRoute {
  points : Array[@geom.Point]
  label_pos : @geom.Point?
}

///|
pub(all) struct DotLayoutEdge {
  edge : @cgraph.Edge
  splines : Array[@geom.Spline]
  label_pos : @geom.Point?
  head_label_pos : @geom.Point?
  tail_label_pos : @geom.Point?
  xlabel_pos : @geom.Point?
}

///|
pub(all) struct EdgeVnodeInfo {
  vnode_ranks : Map[String, Int]
  vnode_sizes : Map[String, @dot_shared.NodeSize]
  vnodes_by_rank : Map[Int, Array[String]]
  edge_vnodes : Map[String, Array[String]]
  vnode_clusters : Map[String, String]
}

///|
pub(all) struct HeadPortMetrics {
  head_port_counts : Map[String, Int]
  head_port_min_dist : Map[String, Double]
  head_port_max_dist : Map[String, Double]
}

///|
pub(all) struct EdgeLayoutInput {
  ranks : Map[String, Int]
  rank_y : Map[Int, Double]
  vnode_info : EdgeVnodeInfo
  vnode_positions : Map[String, @geom.Point]
  has_clusters : Bool
  nodesep_pt : Double
  flat_label_edge_vnodes : Map[String, String]
}

///|
pub(all) struct RegularPassInput {
  spline_mode : Int
  ranks : Map[String, Int]
  sizes : Map[String, @dot_shared.NodeSize]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_info : EdgeVnodeInfo
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  x_groups : Map[Int, Array[String]]
  nodesep_pt : Double
  ranksep_pt : Double
  label_edge_counts : Map[String, Int]
  head_port_metrics : HeadPortMetrics
  routing_context : RoutingContext
  enable_complex_tuning : Bool
}

///|
pub(all) struct OrderedRoutingInput {
  ordered_edges : Array[@cgraph.Edge]
  flat_adjacent_simple_beziers : Map[Int, Array[@geom.Point]]
  base_cache : Map[Int, EdgeRouteBase]
  self_edge_groups : Map[String, Array[@cgraph.Edge]]
  regular_pass_input : RegularPassInput
  path_left_bound : Double
  path_right_bound : Double
  recover_edge_id_for_routing : Map[String, Int]
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  rank_y : Map[Int, Double]
  nodesep_pt : Double
}

///|
pub(all) struct RouteEdgesInput {
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  sizes : Map[String, @dot_shared.NodeSize]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_info : EdgeVnodeInfo
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  x_groups : Map[Int, Array[String]]
  nodesep_pt : Double
  ranksep_pt : Double
  label_edge_counts : Map[String, Int]
  head_port_metrics : HeadPortMetrics
  flat_label_edge_vnodes : Map[String, String]
  routing_context : RoutingContext
  enable_complex_tuning : Bool
  use_spline_prepass : Bool
  spline_mode : Int
  base_cache : Map[Int, EdgeRouteBase]
}
