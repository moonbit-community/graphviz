///|
test "sample_spline_points and spline label helpers follow arc length" {
  let samples = sample_spline_points(straight_spline_points(), 3)
  assert_eq(samples.length(), 4)
  assert_point_close(samples[0], @edge_spline.point(0.0, 0.0))
  assert_point_close(samples[1], @edge_spline.point(3.0, 0.0), eps=0.001)
  assert_point_close(samples[2], @edge_spline.point(6.0, 0.0), eps=0.001)
  assert_point_close(samples[3], @edge_spline.point(9.0, 0.0), eps=0.001)

  let midpoint = require_point_with_tangent(
    spline_label_pos_with_samples(samples),
    "midpoint",
  )
  assert_point_close(midpoint.pos, @edge_spline.point(4.5, 0.0), eps=0.001)
  assert_point_close(midpoint.tangent, @edge_spline.point(1.0, 0.0))

  let axis_hit = require_point_with_tangent(
    spline_label_pos_at_samples(samples, 6.0, true),
    "axis-hit",
  )
  assert_point_close(axis_hit.pos, @edge_spline.point(6.0, 0.0), eps=0.001)
  assert_point_close(axis_hit.tangent, @edge_spline.point(1.0, 0.0))
}

///|
test "spline_label_pos_at_samples picks the y-axis crossing nearest the arc midpoint" {
  let samples = [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(4.0, 4.0),
    @edge_spline.point(8.0, 0.0),
    @edge_spline.point(12.0, 4.0),
  ]

  let axis_hit = require_point_with_tangent(
    spline_label_pos_at_samples(samples, 2.0, false),
    "y-axis-hit",
  )

  assert_point_close(axis_hit.pos, @edge_spline.point(6.0, 2.0), eps=0.001)
  assert_point_close(
    axis_hit.tangent,
    @edge_spline.point(0.70710678, -0.70710678),
    eps=0.001,
  )
}
