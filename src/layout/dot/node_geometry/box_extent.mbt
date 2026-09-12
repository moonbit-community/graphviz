///|
/// poly_init's symmetric box still passes through vertex normalization.
/// Retain that arithmetic: replacing it with width/2 loses an observable ULP
/// when Graphviz updates the bounding box from the normalized vertices.
fn box_vertex_extent(width_pt : Double, height_pt : Double) -> SizePt {
  let sector = @math.PI / 2.0
  let angle = (sector - @math.PI) / 2.0
  let side = @edge_spline.libm_sin(sector / 2.0)
  let x = 0.5 * @edge_spline.libm_cos(angle) +
    side * @edge_spline.libm_cos(sector)
  let y = 0.5 * @edge_spline.libm_sin(angle) +
    side * @edge_spline.libm_sin(sector)
  let alpha = @edge_spline.libm_atan2(y, x)
  let radius = @edge_spline.libm_hypot(x, y)
  let px = radius * @edge_spline.libm_cos(alpha) * width_pt
  let py = radius * @edge_spline.libm_sin(alpha) * height_pt
  let xmax = 2.0 * px.abs()
  let ymax = 2.0 * py.abs()
  guard xmax > 0.0 && ymax > 0.0 else { { width_pt, height_pt, } }
  let bb_width = Double::max(width_pt, xmax)
  let bb_height = Double::max(height_pt, ymax)
  {
    width_pt: Double::max(bb_width, 2.0 * (px * (bb_width / xmax)).abs()),
    height_pt: Double::max(bb_height, 2.0 * (py * (bb_height / ymax)).abs()),
  }
}
