///|
pub struct BezierLayoutSplineResult {
  final_spline : @geom.Spline
  layout_spline_result : EdgeSplineResult
}

///|
/// Graphviz parity: bezier route rendering follows
/// build_bezier_points_spline -> edge_spline_result_for_bezier ->
/// rebuild_spline_for_render -> finalize_edge_spline.
/// Do not change behavior without updating fixtures/tests.
pub fn build_bezier_layout_spline_result(
  base : EdgeRouteBase,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
  tail_swap : Bool,
  head_swap : Bool,
) -> BezierLayoutSplineResult {
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
  let layout_spline_result = rebuild_spline_for_render(base, spline_result)
  let final_spline = finalize_edge_spline(base, layout_spline_result)
  { final_spline, layout_spline_result }
}
