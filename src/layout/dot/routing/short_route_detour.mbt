priv struct FlatDetourLookupInput {
  base : EdgeRouteBase
  positions : Map[String, @geom.Point]
  sizes : Map[String, NodeSize]
  ranks : Map[String, Int]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  ranksep_pt : Double
}

///|
fn flat_detour_lookup_context(
  input : FlatDetourLookupInput,
) -> FlatDetourLookupContext {
  let base = input.base
  {
    tail_name: base.tail_name,
    head_name: base.head_name,
    rank: base.tail_rank,
    positions: input.positions,
    sizes: input.sizes,
    ranks: input.ranks,
    rank_y: input.rank_y,
    rank_ht1: input.rank_ht1,
    rank_ht2: input.rank_ht2,
    ranksep_pt: input.ranksep_pt,
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
pub(all) struct FlatDetourLookupContext {
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

priv struct ShortRouteDetourResolution {
  detour_spline : PointsSplineResult?
  flat_no_arrow_candidate : Bool
  has_flat_detour : Bool
}

///|
priv struct FlatDetourScanInput {
  lookup : FlatDetourLookupContext
  line_start : @geom.Point
  line_end : @geom.Point
}

///|
fn flat_detour_points_if_blocked(
  input : FlatDetourScanInput,
) -> FlatDetourResult? {
  let lookup = input.lookup
  let line_start = input.line_start
  let line_end = input.line_end
  let tail_name = lookup.tail_name
  let head_name = lookup.head_name
  let rank = lookup.rank
  let positions = lookup.positions
  let sizes = lookup.sizes
  let ranks = lookup.ranks
  let rank_y = lookup.rank_y
  let rank_ht1 = lookup.rank_ht1
  let rank_ht2 = lookup.rank_ht2
  let ranksep_pt = lookup.ranksep_pt
  let rankdir = lookup.rankdir
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
  flat_detour_scan_input : FlatDetourScanInput,
) -> FlatDetourResult? {
  if flat_no_arrow_candidate || flat_top_compass_single_arrow_candidate {
    flat_detour_points_if_blocked(
      flat_detour_scan_input,
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
  let flat_detour_scan_input = { lookup: context, line_start, line_end }
  maybe_flat_detour_points_if_blocked(
    flat_no_arrow_candidate,
    flat_top_compass_single_arrow_candidate,
    flat_detour_scan_input,
  )
}

///|
priv struct RecordPortDetourPointsInput {
  tail_clip_center : @geom.Point
  head_clip_center : @geom.Point
  tail_clip_size : NodeSize
  head_clip_size : NodeSize
  tail_clip : @geom.Point
  head_clip : @geom.Point
  nodesep_pt : Double
  layout_rankdir : RankDir
  lr_detour_uses_x_axis : Bool
}

///|
fn record_port_detour_points(
  input : RecordPortDetourPointsInput,
) -> Array[@geom.Point] {
  let tail_clip_center = input.tail_clip_center
  let head_clip_center = input.head_clip_center
  let tail_clip_size = input.tail_clip_size
  let head_clip_size = input.head_clip_size
  let tail_clip = input.tail_clip
  let head_clip = input.head_clip
  let nodesep_pt = input.nodesep_pt
  let layout_rankdir = input.layout_rankdir
  let lr_detour_uses_x_axis = input.lr_detour_uses_x_axis
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
priv struct ShortRouteDetourResolveInput {
  base : EdgeRouteBase
  detour_context : ShortRouteDetourContext
  flat_detour_lookup : FlatDetourLookupContext
  line_start : @geom.Point
  line_end : @geom.Point
  using_pathplan : Bool
  route_barriers : Array[(@geom.Point, @geom.Point)]
  nodesep_pt : Double
  lr_detour_uses_x_axis : Bool
}

///|
fn resolve_short_route_detour(
  input : ShortRouteDetourResolveInput,
) -> ShortRouteDetourResolution {
  let flat_no_arrow_candidate = input.detour_context.flat_no_arrow_candidate
  let flat_top_compass_single_arrow_candidate =
    input.detour_context.flat_top_compass_single_arrow_candidate
  let flat_detour =
    flat_detour_points_for_line(
      input.flat_detour_lookup,
      flat_no_arrow_candidate,
      flat_top_compass_single_arrow_candidate,
      input.line_start,
      input.line_end,
    )
  let detour_spline =
    detour_spline_if_any(
      {
        base: input.base,
        needs_record_detour: input.detour_context.needs_record_detour,
        flat_detour,
        using_pathplan: input.using_pathplan,
        tail_slope_line: input.detour_context.tail_slope_line,
        head_slope_line: input.detour_context.head_slope_line,
        route_barriers: input.route_barriers,
        nodesep_pt: input.nodesep_pt,
        lr_detour_uses_x_axis: input.lr_detour_uses_x_axis,
      },
    )
  {
    detour_spline,
    flat_no_arrow_candidate,
    has_flat_detour: flat_detour is Some(_),
  }
}

///|
priv struct ShortRouteDetourResolveForBaseInput {
  base : EdgeRouteBase
  using_pathplan : Bool
  has_explicit_port : Bool
  label_width_pt : Double
  flat_detour_lookup : FlatDetourLookupContext
  line_start : @geom.Point
  line_end : @geom.Point
  route_barriers : Array[(@geom.Point, @geom.Point)]
  nodesep_pt : Double
  lr_detour_uses_x_axis : Bool
}

///|
fn resolve_short_route_detour_for_base(
  input : ShortRouteDetourResolveForBaseInput,
) -> (ShortRouteDetourContext, ShortRouteDetourResolution) {
  let detour_context =
    short_route_detour_context_for_base(
      input.base,
      input.using_pathplan,
      input.has_explicit_port,
      input.label_width_pt,
    )
  let detour_resolution =
    resolve_short_route_detour(
      {
        base: input.base,
        detour_context,
        flat_detour_lookup: input.flat_detour_lookup,
        line_start: input.line_start,
        line_end: input.line_end,
        using_pathplan: input.using_pathplan,
        route_barriers: input.route_barriers,
        nodesep_pt: input.nodesep_pt,
        lr_detour_uses_x_axis: input.lr_detour_uses_x_axis,
      },
    )
  (detour_context, detour_resolution)
}
