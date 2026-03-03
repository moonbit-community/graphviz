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
