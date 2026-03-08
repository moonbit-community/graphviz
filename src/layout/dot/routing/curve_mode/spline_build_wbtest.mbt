///|
test "bottom_single_arrow_line_endpoints snaps both ends to the lower node bottom when preferred" {
  let line_start = @edge_spline.point(1.0, 10.0)
  let line_end = @edge_spline.point(9.0, 14.0)
  let tail_size = @node_primitives.node_size_from_points(10.0, 8.0)
  let head_size = @node_primitives.node_size_from_points(10.0, 12.0)

  let preferred = bottom_single_arrow_line_endpoints({
    prefer_linear_flat_bottom_single_arrow: true,
    line_start,
    line_end,
    tail_clip_center: @edge_spline.point(1.0, 20.0),
    head_clip_center: @edge_spline.point(9.0, 18.0),
    tail_clip_size: tail_size,
    head_clip_size: head_size,
  })
  let unchanged = bottom_single_arrow_line_endpoints({
    prefer_linear_flat_bottom_single_arrow: false,
    line_start,
    line_end,
    tail_clip_center: @edge_spline.point(1.0, 20.0),
    head_clip_center: @edge_spline.point(9.0, 18.0),
    tail_clip_size: tail_size,
    head_clip_size: head_size,
  })

  assert_eq(preferred, (
    @edge_spline.point(1.0, 12.0),
    @edge_spline.point(9.0, 12.0),
  ))
  assert_eq(unchanged, (line_start, line_end))
}

///|
test "prefer_linear_for_flat_line enables on any of its three trigger paths" {
  assert_true(prefer_linear_for_flat_line(true, false, false, false))
  assert_true(prefer_linear_for_flat_line(false, true, false, false))
  assert_true(prefer_linear_for_flat_line(false, false, false, true))
  assert_false(prefer_linear_for_flat_line(false, true, true, false))
  assert_false(prefer_linear_for_flat_line(false, false, false, false))
}

///|
test "pathplan_line_points_or_endpoints falls back only when fewer than two points exist" {
  let start = @edge_spline.point(0.0, 0.0)
  let end = @edge_spline.point(5.0, 5.0)
  let actual_points = [start, @edge_spline.point(2.0, 3.0), end]

  assert_eq(pathplan_line_points_or_endpoints([], start, end), [start, end])
  assert_eq(pathplan_line_points_or_endpoints([start], start, end), [start, end])
  assert_eq(pathplan_line_points_or_endpoints(actual_points, start, end), actual_points)
}

///|
test "straight path joins and endpoint slopes follow rankdir and explicit ports" {
  assert_eq(straight_path_join_dir(RankDir::TB), @edge_spline.point(0.0, -1.0))
  assert_eq(straight_path_join_dir(RankDir::BT), @edge_spline.point(0.0, 1.0))
  assert_eq(straight_path_join_dir(RankDir::LR), @edge_spline.point(1.0, 0.0))
  assert_eq(straight_path_join_dir(RankDir::RL), @edge_spline.point(-1.0, 0.0))

  let (tail_slope, head_slope) = route_endpoint_slopes(
    Some({ name: Some("p"), compass: None }),
    None,
    @edge_spline.point(3.0, 4.0),
    @edge_spline.point(5.0, 6.0),
  )
  assert_eq(tail_slope, @edge_spline.point(3.0, 4.0))
  assert_eq(head_slope, @edge_spline.point(0.0, 0.0))
}

///|
test "pathplan segment helper logic uses endpoint slopes on edges and trims tiny near-collinear tails" {
  let join_dir = @edge_spline.point(0.0, -1.0)
  let first = pathplan_segment_slopes({
    seg_idx: 0,
    segment_count: 3,
    tail_slope_for: @edge_spline.point(2.0, 0.0),
    head_slope_for: @edge_spline.point(-2.0, 0.0),
    join_dir,
  })
  let middle = pathplan_segment_slopes({
    seg_idx: 1,
    segment_count: 3,
    tail_slope_for: @edge_spline.point(2.0, 0.0),
    head_slope_for: @edge_spline.point(-2.0, 0.0),
    join_dir,
  })
  let last = pathplan_segment_slopes({
    seg_idx: 2,
    segment_count: 3,
    tail_slope_for: @edge_spline.point(2.0, 0.0),
    head_slope_for: @edge_spline.point(-2.0, 0.0),
    join_dir,
  })

  let trimmed = trimmed_pathplan_segment_points([
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(1.0, 0.0),
    @edge_spline.point(1.01, 0.0001),
  ])
  let kept = trimmed_pathplan_segment_points([
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(1.0, 0.0),
    @edge_spline.point(1.01, 0.2),
  ])

  assert_eq(first, (@edge_spline.point(2.0, 0.0), join_dir))
  assert_eq(middle, (join_dir, join_dir))
  assert_eq(last, (join_dir, @edge_spline.point(-2.0, 0.0)))
  assert_eq(trimmed, [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(1.01, 0.0001),
  ])
  assert_eq(kept, [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(1.0, 0.0),
    @edge_spline.point(1.01, 0.2),
  ])
}
