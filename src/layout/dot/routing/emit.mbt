priv struct BezierLayoutSplineResult {
  final_spline : @geom.Spline
  layout_spline_result : EdgeSplineResult
}

///|
priv struct BezierLayoutSplineBuildInput {
  base : EdgeRouteBase
  raw_bezier : Array[@geom.Point]
  label_pad_boost : Double
  apply_dotted_adjustment : Bool
  tail_swap : Bool
  head_swap : Bool
}

///|
/// Graphviz parity: bezier route rendering follows
/// build_bezier_points_spline -> edge_spline_result_for_bezier ->
/// rebuild_spline_for_render -> finalize_edge_spline.
/// Do not change behavior without updating fixtures/tests.
fn build_bezier_layout_spline_result(
  input : BezierLayoutSplineBuildInput,
) -> BezierLayoutSplineResult {
  let base = input.base
  let raw_bezier = input.raw_bezier
  let label_pad_boost = input.label_pad_boost
  let apply_dotted_adjustment = input.apply_dotted_adjustment
  let tail_swap = input.tail_swap
  let head_swap = input.head_swap
  let spline =
    build_bezier_points_spline(
      base,
      raw_bezier,
      base.tail_clip_enabled,
      base.head_clip_enabled,
      tail_swap,
      head_swap,
    )
  let spline_result =
    edge_spline_result_for_bezier(
      spline,
      raw_bezier,
      label_pad_boost,
      apply_dotted_adjustment,
    )
  let layout_spline_result =
    rebuild_spline_for_render(base, spline_result)
  let final_spline =
    finalize_edge_spline(base, layout_spline_result)
  { final_spline, layout_spline_result }
}

///|
priv struct BezierLayoutEdgeBuildInput {
  base : EdgeRouteBase
  raw_bezier : Array[@geom.Point]
  label_pad_boost : Double
  apply_dotted_adjustment : Bool
  tail_swap : Bool
  head_swap : Bool
  build_edge_layout_fn : EdgeLayoutBuilderFn
}

///|
fn build_bezier_layout_edge(
  input : BezierLayoutEdgeBuildInput,
) -> DotLayoutEdge {
  let bezier_layout_result =
    build_bezier_layout_spline_result(
      {
        base: input.base,
        raw_bezier: input.raw_bezier,
        label_pad_boost: input.label_pad_boost,
        apply_dotted_adjustment: input.apply_dotted_adjustment,
        tail_swap: input.tail_swap,
        head_swap: input.head_swap,
      },
    )
  (input.build_edge_layout_fn)(
    input.base,
    bezier_layout_result.final_spline,
    bezier_layout_result.layout_spline_result,
  )
}

///|
/// Graphviz parity: self-edge routes reuse finalize/build_edge_layout path.
/// Do not change behavior without updating fixtures/tests.
pub fn build_self_edge_layout(
  base : EdgeRouteBase,
  route : SelfEdgeRoute,
  build_edge_layout_fn : EdgeLayoutBuilderFn,
) -> DotLayoutEdge {
  let mut edge_layout =
    build_bezier_layout_edge(
      {
        base,
        raw_bezier: route.points,
        label_pad_boost: 0.0,
        apply_dotted_adjustment: false,
        tail_swap: false,
        head_swap: false,
        build_edge_layout_fn,
      },
    )
  match route.label_pos {
    Some(pos) =>
      edge_layout = {
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos: Some(pos),
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
        xlabel_pos: edge_layout.xlabel_pos,
      }
    None => ()
  }
  edge_layout
}

///|
/// Graphviz parity: adjacent same-rank no-port/no-label multiedges use the
/// makeSimpleFlat spindle path (dotsplines.c).
/// Do not change behavior without updating fixtures/tests.
pub fn build_flat_adjacent_layout(
  base : EdgeRouteBase,
  bezier : Array[@geom.Point],
  build_edge_layout_fn : EdgeLayoutBuilderFn,
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    {
      base,
      raw_bezier: bezier,
      label_pad_boost: 0.0,
      apply_dotted_adjustment: false,
      tail_swap: base.swap_ends,
      head_swap: base.swap_ends,
      build_edge_layout_fn,
    },
  )
}

///|
/// Graphviz parity: regular-edge reuse path keeps clipping/label finalization.
pub fn build_regular_bezier_layout(
  base : EdgeRouteBase,
  shared_spline_result : EdgeSplineResult,
  build_edge_layout_fn : EdgeLayoutBuilderFn,
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    {
      base,
      raw_bezier: shared_spline_result.raw_bezier,
      label_pad_boost: shared_spline_result.label_pad_boost,
      apply_dotted_adjustment: shared_spline_result.apply_dotted_adjustment,
      tail_swap: base.swap_ends,
      head_swap: base.swap_ends,
      build_edge_layout_fn,
    },
  )
}
