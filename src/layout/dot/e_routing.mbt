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
