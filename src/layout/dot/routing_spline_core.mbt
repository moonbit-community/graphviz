///|
fn edge_spline_result_for_bezier(
  spline : @geom.Spline,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
) -> @routing.EdgeSplineResult {
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
fn edge_polyline_mode_spline(
  base : @routing.EdgeRouteBase,
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
fn build_bezier_points_spline(
  base : @routing.EdgeRouteBase,
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
/// Graphviz parity: spline finalization aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn finalize_edge_spline(
  base : @routing.EdgeRouteBase,
  result : @routing.EdgeSplineResult,
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
fn edge_render_clip_flags(
  base : @routing.EdgeRouteBase,
) -> EdgeRenderClipFlags {
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
  base : @routing.EdgeRouteBase,
  spline_result : @routing.EdgeSplineResult,
) -> @routing.EdgeSplineResult {
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
