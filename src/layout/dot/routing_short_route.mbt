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
