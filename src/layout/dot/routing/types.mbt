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
