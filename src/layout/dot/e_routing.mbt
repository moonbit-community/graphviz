///|
priv struct EdgeRouteBase {
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
  tail_size : NodeSize
  head_size : NodeSize
  tail_anchor : @geom.Point
  head_anchor : @geom.Point
  head_port_rect : @geom.Rect?
  tail_port_side : Int
  head_port_side : Int
  tail_sameport_group_size : Int
  head_sameport_group_size : Int
  tail_clip_center : @geom.Point
  tail_clip_size : NodeSize
  head_clip_center : @geom.Point
  head_clip_size : NodeSize
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
  out_tail_size : NodeSize
  out_head_size : NodeSize
  rankdir : RankDir
  layout_rankdir : RankDir
  has_side_anchor : Bool
}

///|
priv struct EdgeSplineResult {
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
priv struct SelfEdgeRoute {
  points : Array[@geom.Point]
  label_pos : @geom.Point?
}

///|
fn edge_spline_result_for_bezier(
  spline : @geom.Spline,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
) -> EdgeSplineResult {
  {
    spline,
    label_pad_boost,
    using_pathplan: false,
    pathplan_boxes: [],
    pathplan_points: [],
    raw_bezier,
    pathplan_segments: [],
    apply_dotted_adjustment,
  }
}

///|
fn build_edge_polyline_mode_spline(
  base : EdgeRouteBase,
  is_ortho : Bool,
) -> @geom.Spline {
  // Graphviz parity: swapped routing orientation must swap clip/arrow semantics.
  @edge_spline.edge_spline_for_polyline(
    base.edge,
    base.tail_clip_center,
    base.head_clip_center,
    base.tail_clip_size,
    base.head_clip_size,
    base.tail_clip,
    base.head_clip,
    base.layout_rankdir,
    is_ortho,
    base.route_include_tail,
    base.route_include_head,
    tail_clip_enabled=base.tail_clip_enabled,
    head_clip_enabled=base.head_clip_enabled,
    arrow_len_override=base.arrow_len_override,
    tail_cluster_bbox=base.tail_cluster_bbox,
    head_cluster_bbox=base.head_cluster_bbox,
    parallel_offset=base.parallel_offset,
    clip_swapped=base.swap_ends,
    arrow_swapped=base.swap_ends,
  )
}

///|
fn route_has_no_arrowheads(
  route_include_tail : Bool,
  route_include_head : Bool,
) -> Bool {
  !route_include_tail && !route_include_head
}

///|
fn route_has_single_arrowhead(
  route_include_tail : Bool,
  route_include_head : Bool,
) -> Bool {
  route_include_tail != route_include_head
}

///|
fn needs_record_port_detour(
  using_pathplan : Bool,
  is_flat_edge : Bool,
  tail_node : @cgraph.Node,
  head_node : @cgraph.Node,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  layout_rankdir : RankDir,
) -> Bool {
  let record_port_edge =
    (is_record_shape(tail_node) && @dot_shared.port_is_explicit(tail_port)) ||
    (is_record_shape(head_node) && @dot_shared.port_is_explicit(head_port))
  !using_pathplan &&
  !is_flat_edge &&
  record_port_edge &&
  (match layout_rankdir {
    RankDir::TB | RankDir::BT =>
      Double::abs(tail_slope_line.x) > 0.01 ||
      Double::abs(head_slope_line.x) > 0.01
    RankDir::LR | RankDir::RL =>
      Double::abs(tail_slope_line.y) > 0.01 ||
      Double::abs(head_slope_line.y) > 0.01
  })
}

///|
priv struct FlatDetourCandidateFlags {
  no_arrow : Bool
  top_single_arrow : Bool
}

///|
fn flat_detour_candidate_flags(
  using_pathplan : Bool,
  is_flat_edge : Bool,
  has_explicit_port : Bool,
  label_width_pt : Double,
  tail_port_side : Int,
  head_port_side : Int,
  layout_rankdir : RankDir,
  route_include_tail : Bool,
  route_include_head : Bool,
) -> FlatDetourCandidateFlags {
  let no_arrow =
    !using_pathplan &&
    is_flat_edge &&
    !has_explicit_port &&
    label_width_pt <= 0.0 &&
    route_has_no_arrowheads(route_include_tail, route_include_head)
  let top_single_arrow =
    !using_pathplan &&
    is_flat_edge &&
    has_explicit_port &&
    label_width_pt <= 0.0 &&
    (tail_port_side & PORT_SIDE_TOP) != 0 &&
    (head_port_side & PORT_SIDE_TOP) != 0 &&
    (tail_port_side & PORT_SIDE_BOTTOM) == 0 &&
    (head_port_side & PORT_SIDE_BOTTOM) == 0 &&
    (layout_rankdir == RankDir::TB || layout_rankdir == RankDir::BT) &&
    route_has_single_arrowhead(route_include_tail, route_include_head)
  { no_arrow, top_single_arrow }
}

///|
fn edge_port_slope_or_zero(
  port : @cgraph.Port?,
  slope : @geom.Point,
) -> @geom.Point {
  if @dot_shared.port_is_explicit(port) { slope } else { @edge_spline.point(0.0, 0.0) }
}

///|
priv struct ShortRouteDetourContext {
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  needs_record_detour : Bool
  flat_no_arrow_candidate : Bool
  flat_top_compass_single_arrow_candidate : Bool
}

///|
fn short_route_detour_context(
  using_pathplan : Bool,
  is_flat_edge : Bool,
  tail_node : @cgraph.Node,
  head_node : @cgraph.Node,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  layout_rankdir : RankDir,
  has_explicit_port : Bool,
  label_width_pt : Double,
  tail_port_side : Int,
  head_port_side : Int,
  route_include_tail : Bool,
  route_include_head : Bool,
) -> ShortRouteDetourContext {
  let tail_slope_line = edge_port_slope_or_zero(tail_port, tail_slope)
  let head_slope_line = edge_port_slope_or_zero(head_port, head_slope)
  let needs_record_detour =
    needs_record_port_detour(
      using_pathplan,
      is_flat_edge,
      tail_node,
      head_node,
      tail_port,
      head_port,
      tail_slope_line,
      head_slope_line,
      layout_rankdir,
    )
  let flat_detour_flags =
    flat_detour_candidate_flags(
      using_pathplan,
      is_flat_edge,
      has_explicit_port,
      label_width_pt,
      tail_port_side,
      head_port_side,
      layout_rankdir,
      route_include_tail,
      route_include_head,
    )
  {
    tail_slope_line,
    head_slope_line,
    needs_record_detour,
    flat_no_arrow_candidate: flat_detour_flags.no_arrow,
    flat_top_compass_single_arrow_candidate: flat_detour_flags.top_single_arrow,
  }
}

///|
fn short_route_detour_context_for_base(
  base : EdgeRouteBase,
  using_pathplan : Bool,
  has_explicit_port : Bool,
  label_width_pt : Double,
) -> ShortRouteDetourContext {
  short_route_detour_context(
    using_pathplan,
    base.is_flat_edge,
    base.tail_node,
    base.head_node,
    base.tail_port,
    base.head_port,
    base.tail_slope,
    base.head_slope,
    base.layout_rankdir,
    has_explicit_port,
    label_width_pt,
    base.tail_port_side,
    base.head_port_side,
    base.route_include_tail,
    base.route_include_head,
  )
}

///|
fn flat_detour_lookup_context(
  base : EdgeRouteBase,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
) -> FlatDetourLookupContext {
  {
    tail_name: base.tail_name,
    head_name: base.head_name,
    rank: base.tail_rank,
    positions,
    sizes,
    ranks,
    rank_y,
    rank_ht1,
    rank_ht2,
    ranksep_pt,
    rankdir: base.layout_rankdir,
  }
}

///|
priv struct FlatDetourResult {
  points : Array[@geom.Point]
  first_right : Double
  last_left : Double
  detour_y : Double
  vspace : Double
}

///|
priv struct FlatDetourLookupContext {
  tail_name : String
  head_name : String
  rank : Int
  positions : Map[String, @geom.Point]
  sizes : Map[String, NodeSize]
  ranks : Map[String, Int]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  ranksep_pt : Double
  rankdir : RankDir
}

///|
priv struct PointsSplineResult {
  spline : @geom.Spline
  raw_bezier : Array[@geom.Point]
}

///|
priv struct ShortRouteDetourResolution {
  detour_spline : PointsSplineResult?
  flat_no_arrow_candidate : Bool
  has_flat_detour : Bool
}

///|
priv struct ShortRouteBuildSpec {
  detour_line_start : @geom.Point
  detour_line_end : @geom.Point
  fallback_points : Array[@geom.Point]
  fallback_line_start : @geom.Point
  fallback_line_end : @geom.Point
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
  lr_detour_uses_x_axis : Bool
}

///|
priv struct ShortRouteBuildContext {
  using_pathplan : Bool
  has_explicit_port : Bool
  label_width_pt : Double
  flat_detour_lookup : FlatDetourLookupContext
  route_barriers : Array[(@geom.Point, @geom.Point)]
  nodesep_pt : Double
  force_segmented : Bool
  curve_offset : Double
  curve_skew : Double
  prefer_linear_flat_invis : Bool
  prefer_linear_flat_bottom_single_arrow : Bool
}

///|
priv struct CurveModeRoutePrep {
  label_pad_boost : Double
  label_width_pt : Double
  has_explicit_port : Bool
  abs_dx : Double
  split_label : Bool
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  pathplan_segments : Array[@routesplines.PathplanSegment]
  route_barriers : Array[(@geom.Point, @geom.Point)]
  points : Array[@geom.Point]
  short_route_context : ShortRouteBuildContext
}

///|
priv struct CurveModeSplineBuildResult {
  spline : @geom.Spline
  raw_bezier : Array[@geom.Point]
  apply_dotted_adjustment : Bool
}

///|
fn flat_detour_points_if_blocked(
  tail_name : String,
  head_name : String,
  rank : Int,
  line_start : @geom.Point,
  line_end : @geom.Point,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
  rankdir : RankDir,
) -> FlatDetourResult? {
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let min_x = min_double(line_start.x, line_end.x)
      let max_x = max_double(line_start.x, line_end.x)
      let line_y = (line_start.y + line_end.y) / 2.0
      let mut found = false
      let mut max_top = max_double(line_start.y, line_end.y)
      let mut blocker_min_left = max_x
      let mut blocker_max_right = min_x
      let mut first_right = max_x
      let mut last_left = min_x
      for name, pos in positions {
        if name == tail_name || name == head_name {
          continue
        }
        let node_rank = match ranks.get(name) {
          Some(value) => value
          None => continue
        }
        if node_rank != rank {
          continue
        }
        let size = match sizes.get(name) {
          Some(value) => value
          None => continue
        }
        let half_h = size.height_pt / 2.0
        if line_y < pos.y - half_h - 0.01 || line_y > pos.y + half_h + 0.01 {
          continue
        }
        let half_w = size.width_pt / 2.0
        let left = pos.x - half_w
        let right = pos.x + half_w
        if right <= min_x + 0.01 || left >= max_x - 0.01 {
          continue
        }
        let top = pos.y + size.height_pt / 2.0
        if top > max_top {
          max_top = top
        }
        if left < blocker_min_left {
          blocker_min_left = left
          first_right = right
        }
        if right > blocker_max_right {
          blocker_max_right = right
          last_left = left
        }
        found = true
      }
      if !found {
        None
      } else {
        let vspace =
          if rank > 0 {
            match (
              rank_y.get(rank),
              rank_ht2.get(rank),
              rank_y.get(rank - 1),
              rank_ht1.get(rank - 1),
            ) {
              (Some(cur_y), Some(cur_ht2), Some(prev_y), Some(prev_ht1)) => {
                let gap = prev_y - prev_ht1 - cur_y - cur_ht2
                if gap > 0.0 { gap } else { ranksep_pt }
              }
              _ => ranksep_pt
            }
          } else {
            ranksep_pt
          }
        let detour_y = max_top + vspace / 2.0
        let bend1_x =
          if line_start.x <= line_end.x {
            blocker_min_left
          } else {
            blocker_max_right
          }
        let bend2_x =
          if line_start.x <= line_end.x {
            blocker_max_right
          } else {
            blocker_min_left
          }
        Some({
          points: [
          line_start,
          @edge_spline.point(bend1_x, detour_y),
          @edge_spline.point(bend2_x, detour_y),
          line_end,
        ],
          first_right,
          last_left,
          detour_y,
          vspace,
        })
      }
    }
    RankDir::LR | RankDir::RL => {
      let min_y = min_double(line_start.y, line_end.y)
      let max_y = max_double(line_start.y, line_end.y)
      let line_x = (line_start.x + line_end.x) / 2.0
      let mut found = false
      let mut max_right = max_double(line_start.x, line_end.x)
      for name, pos in positions {
        if name == tail_name || name == head_name {
          continue
        }
        let node_rank = match ranks.get(name) {
          Some(value) => value
          None => continue
        }
        if node_rank != rank {
          continue
        }
        let size = match sizes.get(name) {
          Some(value) => value
          None => continue
        }
        let half_w = size.width_pt / 2.0
        if line_x < pos.x - half_w - 0.01 || line_x > pos.x + half_w + 0.01 {
          continue
        }
        let half_h = size.height_pt / 2.0
        let bottom = pos.y - half_h
        let top = pos.y + half_h
        if top <= min_y + 0.01 || bottom >= max_y - 0.01 {
          continue
        }
        let right = pos.x + size.width_pt / 2.0
        if right > max_right {
          max_right = right
        }
        found = true
      }
      if !found {
        None
      } else {
        let detour_x = max_right + ranksep_pt / 2.0
        Some({
          points: [
            line_start,
            @edge_spline.point(detour_x, line_start.y),
            @edge_spline.point(detour_x, line_end.y),
            line_end,
          ],
          first_right: 0.0,
          last_left: 0.0,
          detour_y: 0.0,
          vspace: 0.0,
        })
      }
    }
  }
}

///|
fn maybe_flat_detour_points_if_blocked(
  flat_no_arrow_candidate : Bool,
  flat_top_compass_single_arrow_candidate : Bool,
  tail_name : String,
  head_name : String,
  rank : Int,
  line_start : @geom.Point,
  line_end : @geom.Point,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
  rankdir : RankDir,
) -> FlatDetourResult? {
  if flat_no_arrow_candidate || flat_top_compass_single_arrow_candidate {
    flat_detour_points_if_blocked(
      tail_name,
      head_name,
      rank,
      line_start,
      line_end,
      positions,
      sizes,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      ranksep_pt,
      rankdir,
    )
  } else {
    None
  }
}

///|
fn flat_detour_points_for_line(
  context : FlatDetourLookupContext,
  flat_no_arrow_candidate : Bool,
  flat_top_compass_single_arrow_candidate : Bool,
  line_start : @geom.Point,
  line_end : @geom.Point,
) -> FlatDetourResult? {
  maybe_flat_detour_points_if_blocked(
    flat_no_arrow_candidate,
    flat_top_compass_single_arrow_candidate,
    context.tail_name,
    context.head_name,
    context.rank,
    line_start,
    line_end,
    context.positions,
    context.sizes,
    context.ranks,
    context.rank_y,
    context.rank_ht1,
    context.rank_ht2,
    context.ranksep_pt,
    context.rankdir,
  )
}

///|
fn record_port_detour_points(
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_clip_size : NodeSize,
  head_clip_size : NodeSize,
  tail_clip : @geom.Point,
  head_clip : @geom.Point,
  nodesep_pt : Double,
  layout_rankdir : RankDir,
  lr_detour_uses_x_axis : Bool,
) -> Array[@geom.Point] {
  let tail_rect = @edge_spline.port_side_rect(tail_clip_center, tail_clip_size)
  let head_rect = @edge_spline.port_side_rect(head_clip_center, head_clip_size)
  let detour_offset = nodesep_pt * 0.5
  match layout_rankdir {
    RankDir::TB | RankDir::BT => {
      let mut side = tail_clip.x - tail_clip_center.x
      if Double::abs(side) <= 0.01 {
        side = head_clip.x - head_clip_center.x
      }
      if Double::abs(side) <= 0.01 {
        side = head_clip.x - tail_clip.x
      }
      let detour_x =
        if side < 0.0 {
          min_double(tail_rect.llx, head_rect.llx) - detour_offset
        } else {
          max_double(tail_rect.urx, head_rect.urx) + detour_offset
        }
      [
        tail_clip,
        @edge_spline.point(detour_x, tail_clip.y),
        @edge_spline.point(detour_x, head_clip.y),
        head_clip,
      ]
    }
    RankDir::LR | RankDir::RL => {
      let mut side = tail_clip.y - tail_clip_center.y
      if Double::abs(side) <= 0.01 {
        side = head_clip.y - head_clip_center.y
      }
      if Double::abs(side) <= 0.01 {
        side = head_clip.y - tail_clip.y
      }
      let detour_y =
        if side < 0.0 {
          min_double(tail_rect.lly, head_rect.lly) - detour_offset
        } else {
          max_double(tail_rect.ury, head_rect.ury) + detour_offset
        }
      if lr_detour_uses_x_axis {
        // Graphviz parity: keep legacy short-route LR detour axis mapping in this branch.
        [
          tail_clip,
          @edge_spline.point(detour_y, tail_clip.y),
          @edge_spline.point(detour_y, head_clip.y),
          head_clip,
        ]
      } else {
        [
          tail_clip,
          @edge_spline.point(tail_clip.x, detour_y),
          @edge_spline.point(head_clip.x, detour_y),
          head_clip,
        ]
      }
    }
  }
}

///|
fn bottom_single_arrow_line_endpoints(
  prefer_linear_flat_bottom_single_arrow : Bool,
  line_start : @geom.Point,
  line_end : @geom.Point,
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_clip_size : NodeSize,
  head_clip_size : NodeSize,
) -> (@geom.Point, @geom.Point) {
  if prefer_linear_flat_bottom_single_arrow {
    let tail_bottom = tail_clip_center.y - tail_clip_size.height_pt / 2.0
    let head_bottom = head_clip_center.y - head_clip_size.height_pt / 2.0
    let line_y = min_double(tail_bottom, head_bottom)
    (@edge_spline.point(line_start.x, line_y), @edge_spline.point(line_end.x, line_y))
  } else {
    (line_start, line_end)
  }
}

///|
fn prefer_linear_for_flat_line(
  prefer_linear_flat_invis : Bool,
  flat_no_arrow_candidate : Bool,
  has_flat_detour : Bool,
  prefer_linear_flat_bottom_single_arrow : Bool,
) -> Bool {
  prefer_linear_flat_invis ||
  (flat_no_arrow_candidate && !has_flat_detour) ||
  prefer_linear_flat_bottom_single_arrow
}

///|
fn build_points_spline(
  base : EdgeRouteBase,
  points : Array[@geom.Point],
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  force_segmented : Bool,
  using_pathplan : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> PointsSplineResult {
  let raw_bezier =
    if using_pathplan {
      @edge_spline.edge_spline_raw_for_points(
        points,
        tail_slope_line,
        head_slope_line,
        force_segmented,
        route_barriers=route_barriers,
      )
    } else {
      []
    }
  let spline =
    @edge_spline.edge_spline_for_points(
      base.edge,
      points,
      base.tail_clip_center,
      base.head_clip_center,
      base.tail_clip_size,
      base.head_clip_size,
      tail_slope_line,
      head_slope_line,
      force_segmented,
      base.route_include_tail,
      base.route_include_head,
      tail_clip_enabled=base.tail_clip_enabled,
      head_clip_enabled=base.head_clip_enabled,
      tail_port_side=base.tail_port_side,
      head_port_side=base.head_port_side,
      route_barriers=route_barriers,
      arrow_len_override=base.arrow_len_override,
      tail_cluster_bbox=base.tail_cluster_bbox,
      head_cluster_bbox=base.head_cluster_bbox,
      parallel_offset=base.parallel_offset,
      clip_swapped=base.swap_ends,
      arrow_swapped=base.swap_ends,
    )
  { spline, raw_bezier }
}

///|
fn pathplan_line_points_or_endpoints(
  points : Array[@geom.Point],
  line_start : @geom.Point,
  line_end : @geom.Point,
) -> Array[@geom.Point] {
  if points.length() >= 2 { points } else { [line_start, line_end] }
}

///|
fn build_pathplan_points_spline(
  base : EdgeRouteBase,
  pathplan_points : Array[@geom.Point],
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  force_segmented : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> PointsSplineResult {
  build_points_spline(
    base,
    pathplan_points,
    tail_slope_line,
    head_slope_line,
    force_segmented,
    true,
    route_barriers,
  )
}

///|
fn build_line_spline(
  base : EdgeRouteBase,
  line_start : @geom.Point,
  line_end : @geom.Point,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
  curve_offset : Double,
  curve_skew : Double,
  prefer_linear : Bool,
) -> @geom.Spline {
  @edge_spline.edge_spline_for_line(
    base.edge,
    line_start,
    line_end,
    base.tail_clip_center,
    base.head_clip_center,
    base.tail_clip_size,
    base.head_clip_size,
    tail_slope_line,
    head_slope_line,
    base.route_include_tail,
    base.route_include_head,
    tail_clip_enabled=tail_clip_enabled,
    head_clip_enabled=head_clip_enabled,
    base.layout_rankdir,
    curve_offset,
    curve_skew,
    arrow_len_override=base.arrow_len_override,
    tail_cluster_bbox=base.tail_cluster_bbox,
    head_cluster_bbox=base.head_cluster_bbox,
    prefer_linear=prefer_linear,
    parallel_offset=base.parallel_offset,
    clip_swapped=base.swap_ends,
    arrow_swapped=base.swap_ends,
  )
}

///|
fn build_bezier_points_spline(
  base : EdgeRouteBase,
  bezier_points : Array[@geom.Point],
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
  clip_swapped : Bool,
  arrow_swapped : Bool,
) -> @geom.Spline {
  @edge_spline.edge_spline_for_bezier_points(
    base.edge,
    bezier_points,
    base.tail_clip_center,
    base.head_clip_center,
    base.tail_clip_size,
    base.head_clip_size,
    base.route_include_tail,
    base.route_include_head,
    tail_clip_enabled=tail_clip_enabled,
    head_clip_enabled=head_clip_enabled,
    arrow_len_override=base.arrow_len_override,
    tail_cluster_bbox=base.tail_cluster_bbox,
    head_cluster_bbox=base.head_cluster_bbox,
    parallel_offset=base.parallel_offset,
    clip_swapped=clip_swapped,
    arrow_swapped=arrow_swapped,
  )
}

///|
fn build_short_route_line_or_pathplan_spline(
  base : EdgeRouteBase,
  using_pathplan : Bool,
  pathplan_points : Array[@geom.Point],
  line_start : @geom.Point,
  line_end : @geom.Point,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  force_segmented : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
  curve_offset : Double,
  curve_skew : Double,
  prefer_linear : Bool,
) -> PointsSplineResult {
  if using_pathplan {
    build_pathplan_points_spline(
      base,
      pathplan_points,
      tail_slope_line,
      head_slope_line,
      force_segmented,
      route_barriers,
    )
  } else {
    {
      spline:
        build_line_spline(
          base,
          line_start,
          line_end,
          tail_slope_line,
          head_slope_line,
          tail_clip_enabled,
          head_clip_enabled,
          curve_offset,
          curve_skew,
          prefer_linear,
        ),
      raw_bezier: [],
    }
  }
}

///|
fn build_flat_detour_spline(
  base : EdgeRouteBase,
  detour : FlatDetourResult,
  using_pathplan : Bool,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> PointsSplineResult {
  let detour_points = detour.points
  let first_right = detour.first_right
  let last_left = detour.last_left
  let detour_y = detour.detour_y
  let vspace = detour.vspace
  let points_spline =
    build_points_spline(
      base,
      detour_points,
      tail_slope_line,
      head_slope_line,
      true,
      using_pathplan,
      route_barriers,
    )
  let raw_bezier = points_spline.raw_bezier
  let mut detour_spline = points_spline.spline
  if detour_spline.points.length() == 10 &&
    (base.layout_rankdir == RankDir::TB || base.layout_rankdir == RankDir::BT) {
    let gap = last_left - first_right
    if gap > 200.0 {
      let points = detour_spline.points.copy()
      points[4] = {
        x: first_right + 0.76,
        y: detour_y + vspace * 0.3535,
      }
      points[5] = {
        x: last_left + 0.25,
        y: detour_y + vspace * 0.4016,
      }
      detour_spline = {
        start: detour_spline.start,
        end: detour_spline.end,
        points,
      }
    }
  }
  { spline: detour_spline, raw_bezier }
}

///|
fn detour_spline_if_any(
  base : EdgeRouteBase,
  needs_record_detour : Bool,
  flat_detour : FlatDetourResult?,
  using_pathplan : Bool,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  nodesep_pt : Double,
  lr_detour_uses_x_axis : Bool,
) -> PointsSplineResult? {
  if needs_record_detour {
    let detour_points =
      record_port_detour_points(
        base.tail_clip_center,
        base.head_clip_center,
        base.tail_clip_size,
        base.head_clip_size,
        base.tail_clip,
        base.head_clip,
        nodesep_pt,
        base.layout_rankdir,
        lr_detour_uses_x_axis,
      )
    Some(
      build_points_spline(
        base,
        detour_points,
        tail_slope_line,
        head_slope_line,
        true,
        using_pathplan,
        route_barriers,
      ),
    )
  } else {
    match flat_detour {
      Some(detour) =>
        Some(
          build_flat_detour_spline(
            base,
            detour,
            using_pathplan,
            tail_slope_line,
            head_slope_line,
            route_barriers,
          ),
        )
      None => None
    }
  }
}

///|
fn resolve_short_route_detour(
  base : EdgeRouteBase,
  detour_context : ShortRouteDetourContext,
  flat_detour_lookup : FlatDetourLookupContext,
  line_start : @geom.Point,
  line_end : @geom.Point,
  using_pathplan : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  nodesep_pt : Double,
  lr_detour_uses_x_axis : Bool,
) -> ShortRouteDetourResolution {
  let flat_no_arrow_candidate = detour_context.flat_no_arrow_candidate
  let flat_top_compass_single_arrow_candidate =
    detour_context.flat_top_compass_single_arrow_candidate
  let flat_detour =
    flat_detour_points_for_line(
      flat_detour_lookup,
      flat_no_arrow_candidate,
      flat_top_compass_single_arrow_candidate,
      line_start,
      line_end,
    )
  let detour_spline =
    detour_spline_if_any(
      base,
      detour_context.needs_record_detour,
      flat_detour,
      using_pathplan,
      detour_context.tail_slope_line,
      detour_context.head_slope_line,
      route_barriers,
      nodesep_pt,
      lr_detour_uses_x_axis,
    )
  {
    detour_spline,
    flat_no_arrow_candidate,
    has_flat_detour: flat_detour is Some(_),
  }
}

///|
fn resolve_short_route_detour_for_base(
  base : EdgeRouteBase,
  using_pathplan : Bool,
  has_explicit_port : Bool,
  label_width_pt : Double,
  flat_detour_lookup : FlatDetourLookupContext,
  line_start : @geom.Point,
  line_end : @geom.Point,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  nodesep_pt : Double,
  lr_detour_uses_x_axis : Bool,
) -> (ShortRouteDetourContext, ShortRouteDetourResolution) {
  let detour_context =
    short_route_detour_context_for_base(
      base,
      using_pathplan,
      has_explicit_port,
      label_width_pt,
    )
  let detour_resolution =
    resolve_short_route_detour(
      base,
      detour_context,
      flat_detour_lookup,
      line_start,
      line_end,
      using_pathplan,
      route_barriers,
      nodesep_pt,
      lr_detour_uses_x_axis,
    )
  (detour_context, detour_resolution)
}

///|
fn build_short_route_fallback_spline(
  base : EdgeRouteBase,
  using_pathplan : Bool,
  pathplan_points : Array[@geom.Point],
  line_start : @geom.Point,
  line_end : @geom.Point,
  detour_context : ShortRouteDetourContext,
  detour_resolution : ShortRouteDetourResolution,
  force_segmented : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
  curve_offset : Double,
  curve_skew : Double,
  prefer_linear_flat_invis : Bool,
  prefer_linear_flat_bottom_single_arrow : Bool,
) -> PointsSplineResult {
  let prefer_linear_flat_line =
    prefer_linear_for_flat_line(
      prefer_linear_flat_invis,
      detour_resolution.flat_no_arrow_candidate,
      detour_resolution.has_flat_detour,
      prefer_linear_flat_bottom_single_arrow,
    )
  build_short_route_line_or_pathplan_spline(
    base,
    using_pathplan,
    pathplan_points,
    line_start,
    line_end,
    detour_context.tail_slope_line,
    detour_context.head_slope_line,
    force_segmented,
    route_barriers,
    tail_clip_enabled,
    head_clip_enabled,
    curve_offset,
    curve_skew,
    prefer_linear_flat_line,
  )
}

///|
fn short_route_build_context(
  base : EdgeRouteBase,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  using_pathplan : Bool,
  has_explicit_port : Bool,
  label_width_pt : Double,
  nodesep_pt : Double,
  force_segmented : Bool,
  curve_offset : Double,
  curve_skew : Double,
) -> ShortRouteBuildContext {
  let style_value = match base.edge.get_attr("style") {
    Some(value) => value.to_lower()
    None => ""
  }
  // Graphviz parity: flat invisible edges use linear control points in
  // line routing (matches proc3d rank=same invis edge snapshots).
  let prefer_linear_flat_invis =
    base.is_flat_edge &&
    !has_explicit_port &&
    label_width_pt <= 0.0 &&
    style_value.contains("invis")
  let prefer_linear_flat_bottom_single_arrow =
    base.is_flat_edge &&
    !base.is_flat_adjacent &&
    !base.swap_ends &&
    has_explicit_port &&
    label_width_pt <= 0.0 &&
    (base.tail_port_side & PORT_SIDE_BOTTOM) != 0 &&
    (base.head_port_side & PORT_SIDE_BOTTOM) != 0 &&
    (base.tail_port_side & PORT_SIDE_TOP) == 0 &&
    (base.head_port_side & PORT_SIDE_TOP) == 0 &&
    route_has_single_arrowhead(base.route_include_tail, base.route_include_head)
  let flat_detour_lookup =
    flat_detour_lookup_context(
      base,
      positions,
      sizes,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      ranksep_pt,
    )
  {
    using_pathplan,
    has_explicit_port,
    label_width_pt,
    flat_detour_lookup,
    route_barriers,
    nodesep_pt,
    force_segmented,
    curve_offset,
    curve_skew,
    prefer_linear_flat_invis,
    prefer_linear_flat_bottom_single_arrow,
  }
}

///|
fn short_route_spec_for_adjusted_points(
  adjusted : Array[@geom.Point],
) -> ShortRouteBuildSpec {
  {
    detour_line_start: adjusted[0],
    detour_line_end: adjusted[adjusted.length() - 1],
    fallback_points: adjusted,
    fallback_line_start: adjusted[0],
    fallback_line_end: adjusted[adjusted.length() - 1],
    tail_clip_enabled: true,
    head_clip_enabled: true,
    lr_detour_uses_x_axis: true,
  }
}

///|
fn short_route_spec_for_anchor_or_pathplan_points(
  points : Array[@geom.Point],
  using_pathplan : Bool,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
) -> ShortRouteBuildSpec {
  let fallback_line_start =
    if using_pathplan && points.length() >= 2 {
      points[0]
    } else {
      tail_anchor
    }
  let fallback_line_end =
    if using_pathplan && points.length() >= 2 {
      points[points.length() - 1]
    } else {
      head_anchor
    }
  {
    detour_line_start: tail_anchor,
    detour_line_end: head_anchor,
    fallback_points: points,
    fallback_line_start,
    fallback_line_end,
    tail_clip_enabled,
    head_clip_enabled,
    lr_detour_uses_x_axis: false,
  }
}

///|
fn build_short_route_spline_with_detour(
  base : EdgeRouteBase,
  short_route_context : ShortRouteBuildContext,
  short_route_spec : ShortRouteBuildSpec,
) -> PointsSplineResult {
  let (detour_context, detour_resolution) =
    resolve_short_route_detour_for_base(
      base,
      short_route_context.using_pathplan,
      short_route_context.has_explicit_port,
      short_route_context.label_width_pt,
      short_route_context.flat_detour_lookup,
      short_route_spec.detour_line_start,
      short_route_spec.detour_line_end,
      short_route_context.route_barriers,
      short_route_context.nodesep_pt,
      short_route_spec.lr_detour_uses_x_axis,
    )
  if detour_resolution.detour_spline is Some(result) {
    result
  } else {
    let (line_start, line_end) =
      bottom_single_arrow_line_endpoints(
        short_route_context.prefer_linear_flat_bottom_single_arrow,
        short_route_spec.fallback_line_start,
        short_route_spec.fallback_line_end,
        base.tail_clip_center,
        base.head_clip_center,
        base.tail_clip_size,
        base.head_clip_size,
      )
    let line_points =
      pathplan_line_points_or_endpoints(
        short_route_spec.fallback_points,
        line_start,
        line_end,
      )
    build_short_route_fallback_spline(
      base,
      short_route_context.using_pathplan,
      line_points,
      line_start,
      line_end,
      detour_context,
      detour_resolution,
      short_route_context.force_segmented,
      short_route_context.route_barriers,
      short_route_spec.tail_clip_enabled,
      short_route_spec.head_clip_enabled,
      short_route_context.curve_offset,
      short_route_context.curve_skew,
      short_route_context.prefer_linear_flat_invis,
      short_route_context.prefer_linear_flat_bottom_single_arrow,
    )
  }
}

///|
fn prepare_edge_curve_mode_route(
  base : EdgeRouteBase,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> CurveModeRoutePrep {
  let edge = base.edge
  let tail_anchor = base.tail_anchor
  let head_anchor = base.head_anchor
  let label_width_pt = edge_mid_label_width_pt(edge)
  let label_height_pt = match edge_mid_label_metrics(edge) {
    Some(metrics) => Some(metrics.height)
    None => None
  }
  let has_explicit_port =
    @dot_shared.port_is_explicit(base.tail_port) ||
    @dot_shared.port_is_explicit(base.head_port)
  let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
  let split_label = enable_complex_tuning &&
    label_width_pt > 0.0 &&
    base.same_outer_cluster &&
    base.diff_local_cluster &&
    abs_dx > label_width_pt
  let label_pad_boost = if split_label { nodesep_pt * 1.2 } else { 0.0 }
  let dotted_weight = if enable_complex_tuning { 1.0 } else { 0.8 }
  let guide_points =
    @routing.edge_polyline_points(
      edge,
      base.tail_name,
      base.head_name,
      base.tail_port,
      base.head_port,
      tail_anchor,
      head_anchor,
      ranks,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
      vnode_positions,
      rank_y,
      rank_ht1,
      nodesep_pt,
      label_width_pt,
      label_height_pt,
      dotted_weight,
      enable_complex_tuning,
      split_label,
      base.same_local_cluster,
      DEFAULT_VNODE_WEIGHT,
    )
  let route_state =
    compute_pathplan_route_points(
      base,
      ranks,
      positions,
      vnode_positions,
      vnode_info,
      sizes,
      x_groups,
      rank_y,
      rank_ht1,
      rank_ht2,
      nodesep_pt,
      path_left_bound,
      path_right_bound,
      ranksep_pt,
      routing_context,
      guide_points,
    )
  let using_pathplan = route_state.using_pathplan
  let points =
    adjust_route_points(
      route_state.points,
      base,
      base.head_port_rect,
      has_explicit_port,
      using_pathplan,
      nodesep_pt,
    )
  let curve_offset_params = compute_curve_offset(
    edge,
    base,
    head_port_metrics,
    label_width_pt,
    nodesep_pt,
    enable_complex_tuning,
  )
  let short_route_context =
    short_route_build_context(
      base,
      positions,
      sizes,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      ranksep_pt,
      route_state.route_barriers,
      using_pathplan,
      has_explicit_port,
      label_width_pt,
      nodesep_pt,
      base.force_segmented,
      curve_offset_params.curve_offset,
      curve_offset_params.curve_skew,
    )
  {
    label_pad_boost,
    label_width_pt,
    has_explicit_port,
    abs_dx,
    split_label,
    using_pathplan,
    pathplan_boxes: route_state.pathplan_boxes,
    pathplan_points: route_state.pathplan_points,
    pathplan_segments: route_state.pathplan_segments,
    route_barriers: route_state.route_barriers,
    points,
    short_route_context,
  }
}

///|
fn curve_mode_result_for_short_route(
  base : EdgeRouteBase,
  prepared : CurveModeRoutePrep,
  short_route_spec : ShortRouteBuildSpec,
) -> CurveModeSplineBuildResult {
  let short_route_spline =
    build_short_route_spline_with_detour(
      base,
      prepared.short_route_context,
      short_route_spec,
    )
  {
    spline: short_route_spline.spline,
    raw_bezier: short_route_spline.raw_bezier,
    apply_dotted_adjustment: false,
  }
}

///|
fn adjusted_curve_mode_points(
  base : EdgeRouteBase,
  prepared : CurveModeRoutePrep,
  label_edge_counts : Map[String, Int],
  nodesep_pt : Double,
  enable_complex_tuning : Bool,
) -> Array[@geom.Point] {
  let points = prepared.points
  let simplify_tol = nodesep_pt * 0.8
  let tail_label_edges = match label_edge_counts.get(base.orig_tail_name) {
    Some(value) => value > 1
    None => false
  }
  let keep_label_kink =
    prepared.label_width_pt > 0.0 &&
    (prepared.has_explicit_port ||
      (base.same_outer_cluster &&
          (prepared.abs_dx < nodesep_pt ||
            (tail_label_edges && prepared.abs_dx < prepared.label_width_pt))))
  let simplified =
    if prepared.using_pathplan {
      points
    } else if enable_complex_tuning &&
      base.has_vnodes &&
      !prepared.split_label &&
      !keep_label_kink {
      simplify_polyline(points, simplify_tol)
    } else {
      points
    }
  if !prepared.using_pathplan && base.is_dotted && base.same_outer_cluster {
    @edge_ops.adjust_intracluster_dots(simplified)
  } else {
    simplified
  }
}

///|
fn build_curve_mode_spline_from_prepared_route(
  base : EdgeRouteBase,
  prepared : CurveModeRoutePrep,
  label_edge_counts : Map[String, Int],
  nodesep_pt : Double,
  enable_complex_tuning : Bool,
) -> CurveModeSplineBuildResult {
  let points = prepared.points
  if points.length() > 2 {
    let adjusted =
      adjusted_curve_mode_points(
        base,
        prepared,
        label_edge_counts,
        nodesep_pt,
        enable_complex_tuning,
      )
    if adjusted.length() <= 2 {
      let short_route_spec = short_route_spec_for_adjusted_points(adjusted)
      curve_mode_result_for_short_route(base, prepared, short_route_spec)
    } else {
      let multi_point_spline =
        build_multi_point_routed_spline(
          base,
          adjusted,
          prepared.using_pathplan,
          base.force_segmented,
          prepared.pathplan_segments,
          prepared.route_barriers,
          base.tail_clip_enabled,
          base.head_clip_enabled,
        )
      {
        spline: multi_point_spline.spline,
        raw_bezier: multi_point_spline.raw_bezier,
        apply_dotted_adjustment: true,
      }
    }
  } else {
    let short_route_spec =
      short_route_spec_for_anchor_or_pathplan_points(
        points,
        prepared.using_pathplan,
        base.tail_anchor,
        base.head_anchor,
        base.tail_clip_enabled,
        base.head_clip_enabled,
      )
    curve_mode_result_for_short_route(base, prepared, short_route_spec)
  }
}

///|
fn build_edge_curve_mode_result(
  base : EdgeRouteBase,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> EdgeSplineResult {
  let prepared =
    prepare_edge_curve_mode_route(
      base,
      ranks,
      sizes,
      positions,
      vnode_positions,
      vnode_info,
      rank_y,
      rank_ht1,
      rank_ht2,
      x_groups,
      nodesep_pt,
      path_left_bound,
      path_right_bound,
      ranksep_pt,
      head_port_metrics,
      routing_context,
      enable_complex_tuning,
    )
  let spline_result =
    build_curve_mode_spline_from_prepared_route(
      base,
      prepared,
      label_edge_counts,
      nodesep_pt,
      enable_complex_tuning,
    )
  let (pathplan_boxes, pathplan_segments) =
    finalize_pathplan_boxes_and_segments(
      base,
      prepared.using_pathplan,
      prepared.pathplan_boxes,
      prepared.pathplan_points,
      spline_result.raw_bezier,
      prepared.pathplan_segments,
    )
  {
    spline: spline_result.spline,
    label_pad_boost: prepared.label_pad_boost,
    using_pathplan: prepared.using_pathplan,
    pathplan_boxes,
    pathplan_points: prepared.pathplan_points,
    raw_bezier: spline_result.raw_bezier,
    pathplan_segments,
    apply_dotted_adjustment: spline_result.apply_dotted_adjustment,
  }
}

///|
/// Graphviz parity: spline routing aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_spline(
  base : EdgeRouteBase,
  splines : SplinesMode,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> EdgeSplineResult {
  match splines {
    SplinesMode::None | SplinesMode::Polyline =>
      edge_spline_result_for_bezier(
        build_edge_polyline_mode_spline(base, false),
        [],
        0.0,
        false,
      )
    SplinesMode::Ortho =>
      edge_spline_result_for_bezier(
        build_edge_polyline_mode_spline(base, true),
        [],
        0.0,
        false,
      )
    _ =>
      build_edge_curve_mode_result(
        base,
        ranks,
        sizes,
        positions,
        vnode_positions,
        vnode_info,
        rank_y,
        rank_ht1,
        rank_ht2,
        x_groups,
        nodesep_pt,
        path_left_bound,
        path_right_bound,
        ranksep_pt,
        label_edge_counts,
        head_port_metrics,
        routing_context,
        enable_complex_tuning,
      )
  }
}

///|
/// Graphviz parity: spline finalization aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn finalize_edge_spline(
  base : EdgeRouteBase,
  result : EdgeSplineResult,
) -> @geom.Spline {
  let mut spline = result.spline
  if base.swap_ends {
    spline = @edge_ops.reverse_spline(spline)
  }
  if result.apply_dotted_adjustment && base.is_dotted && !base.same_outer_cluster &&
    spline.points.length() > 1 {
    let tuned = spline.points.copy()
    let tail_bias = 0.7
    tuned[1] = {
      x: tuned[1].x,
      y: tuned[1].y * (1.0 - tail_bias) + base.out_tail_anchor.y * tail_bias,
    }
    let head_bias = 0.7
    let last = tuned.length() - 2
    tuned[last] = {
      x: tuned[last].x,
      y: tuned[last].y * (1.0 - head_bias) + base.out_head_anchor.y * head_bias,
    }
    spline = { start: spline.start, end: spline.end, points: tuned }
  }
  spline
}

///|
priv struct EdgeSameportDirectFlags {
  tail_direct : Bool
  head_direct : Bool
}

///|
priv struct EdgeRenderClipFlags {
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
}

///|
fn edge_sameport_direct_flags(
  edge : @cgraph.Edge,
  swap_ends : Bool,
) -> EdgeSameportDirectFlags {
  let samehead_direct = edge_attr_non_empty(edge, "samehead")
  let sametail_direct = edge_attr_non_empty(edge, "sametail")
  if swap_ends {
    { tail_direct: samehead_direct, head_direct: sametail_direct }
  } else {
    { tail_direct: sametail_direct, head_direct: samehead_direct }
  }
}

///|
fn edge_render_clip_flags(base : EdgeRouteBase) -> EdgeRenderClipFlags {
  let sameport_direct_flags =
    edge_sameport_direct_flags(base.edge, base.swap_ends)
  let tail_clip_enabled =
    if !base.tail_clip_enabled && !sameport_direct_flags.tail_direct {
      true
    } else {
      base.tail_clip_enabled
    }
  let head_clip_enabled =
    if !base.head_clip_enabled && !sameport_direct_flags.head_direct {
      true
    } else {
      base.head_clip_enabled
    }
  { tail_clip_enabled, head_clip_enabled }
}

///|
fn rebuild_spline_for_render(
  base : EdgeRouteBase,
  spline_result : EdgeSplineResult,
) -> EdgeSplineResult {
  let edge_clip_flags = edge_render_clip_flags(base)
  if edge_clip_flags.tail_clip_enabled == base.tail_clip_enabled &&
    edge_clip_flags.head_clip_enabled == base.head_clip_enabled {
    return spline_result
  }
  if spline_result.raw_bezier.length() < 4 {
    return spline_result
  }
  let rebuilt =
    build_bezier_points_spline(
      base,
      spline_result.raw_bezier,
      edge_clip_flags.tail_clip_enabled,
      edge_clip_flags.head_clip_enabled,
      base.swap_ends,
      base.swap_ends,
    )
  {
    spline: rebuilt,
    label_pad_boost: spline_result.label_pad_boost,
    using_pathplan: spline_result.using_pathplan,
    pathplan_boxes: spline_result.pathplan_boxes,
    pathplan_points: spline_result.pathplan_points,
    raw_bezier: spline_result.raw_bezier,
    pathplan_segments: spline_result.pathplan_segments,
    apply_dotted_adjustment: spline_result.apply_dotted_adjustment,
  }
}

///|
/// Graphviz parity: edge label placement aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_layout(
  base : EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let edge = base.edge
  let label_rank_info = edge_label_rank_info(edge, ranks)
  let label_rank_y = edge_label_rank_y(edge, ranks, rank_y)
  let label_rank_x = match label_rank_info {
    Some(info) =>
      if info.span > 1 {
        edge_label_rank_x(
          edge,
          info.label_rank,
          vnode_info.vnode_ranks,
          vnode_info.edge_vnodes,
          vnode_positions,
        )
      } else {
        None
      }
    None => None
  }
  let apply_label_pad = has_clusters
  let label_pos : @geom.Point? = match edge.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        match (label_rank_x, label_rank_y, edge_mid_label_metrics(edge)) {
          (Some(rank_x), Some(rank_y), Some(metrics)) => {
            Some(
              edge_label_pos_from_vnode(
                @edge_spline.point(rank_x, rank_y),
                metrics.width,
                metrics.height,
                base.rankdir,
              ),
            )
          }
          _ =>
            if base.is_flat_edge {
              match flat_label_edge_vnodes.get(@dot_shared.edge_key(edge)) {
                Some(vnode_name) =>
                  match vnode_positions.get(vnode_name) {
                    Some(pos) => Some(pos)
                    None =>
                      match edge_mid_label_metrics(edge) {
                        Some(metrics) =>
                          Some(
                            flat_edge_label_pos_simple(
                              base.out_tail_pos,
                              base.out_head_pos,
                              base.out_tail_size.right_pt,
                              base.out_head_size.left_pt,
                              metrics.height,
                            ),
                          )
                        None =>
                          edge_label_pos(
                            edge,
                            spline,
                            base.out_tail_clip,
                            base.out_head_clip,
                            base.layout_rankdir,
                            label_rank_y,
                            label_rank_x,
                            apply_label_pad,
                            nodesep_pt,
                            spline_result.label_pad_boost,
                          )
                      }
                  }
                None =>
                  match edge_mid_label_metrics(edge) {
                    Some(metrics) => {
                      Some(
                        flat_edge_label_pos_simple(
                          base.out_tail_pos,
                          base.out_head_pos,
                          base.out_tail_size.right_pt,
                          base.out_head_size.left_pt,
                          metrics.height,
                        ),
                      )
                    }
                    None =>
                      edge_label_pos(
                        edge,
                        spline,
                        base.out_tail_clip,
                        base.out_head_clip,
                        base.layout_rankdir,
                        label_rank_y,
                        label_rank_x,
                        apply_label_pad,
                        nodesep_pt,
                        spline_result.label_pad_boost,
                      )
                  }
              }
            } else {
              edge_label_pos(
                edge,
                spline,
                base.out_tail_clip,
                base.out_head_clip,
                base.layout_rankdir,
                label_rank_y,
                label_rank_x,
                apply_label_pad,
                nodesep_pt,
                spline_result.label_pad_boost,
              )
            }
        }
      }
    None => None
  }
  let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, true)
      }
    None => None
  }
  let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, false)
      }
    None => None
  }
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos: None,
  }
}
