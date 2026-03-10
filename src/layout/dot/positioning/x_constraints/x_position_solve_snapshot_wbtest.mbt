///|
test "compute_x_positions_with_prepared_constraints solves minimal input and captures reordered snapshot" {
  let solve_input = build_x_position_solve_input(
    build_simplex_test_input(false),
  )

  xpos_constraint_snapshot.val = None
  let without_snapshot = compute_x_positions_with_prepared_constraints(
    solve_input,
    0.0,
    1000,
    (segment, _) => segment_slack_minlen(segment, (_, _) => 0.0),
    _ => false,
    _ => 1,
    false,
  )
  let uncaptured_snapshot = xpos_constraint_snapshot.val

  xpos_constraint_snapshot.val = None
  let with_snapshot = compute_x_positions_with_prepared_constraints(
    solve_input,
    0.0,
    1000,
    (segment, _) => segment_slack_minlen(segment, (_, _) => 0.0),
    _ => false,
    _ => 1,
    true,
  )
  let captured_snapshot = match xpos_constraint_snapshot.val {
    Some(value) => value
    None => fail("expected xpos constraint snapshot")
  }
  xpos_constraint_snapshot.val = None

  assert_eq(without_snapshot.get("a"), Some(0.0))
  assert_eq(without_snapshot.get("b"), Some(23.0))
  assert_eq(with_snapshot.get("a"), Some(0.0))
  assert_eq(with_snapshot.get("b"), Some(23.0))
  assert_true(uncaptured_snapshot is None)

  assert_eq(captured_snapshot.nodes.length(), 2)
  assert_eq(captured_snapshot.nodes[0].name, Some("b"))
  assert_eq(captured_snapshot.nodes[0].rank, 23)
  assert_eq(captured_snapshot.nodes[0].order, 1)
  assert_eq(captured_snapshot.nodes[0].left_pt, 6.0)
  assert_eq(captured_snapshot.nodes[0].right_pt, 6.0)
  assert_eq(captured_snapshot.nodes[0].height_pt, 8.0)
  assert_eq(captured_snapshot.nodes[1].name, Some("a"))
  assert_eq(captured_snapshot.nodes[1].rank, 0)
  assert_eq(captured_snapshot.nodes[1].order, 0)
  assert_eq(captured_snapshot.nodes[1].left_pt, 5.0)
  assert_eq(captured_snapshot.nodes[1].right_pt, 5.0)
  assert_eq(captured_snapshot.nodes[1].height_pt, 10.0)

  assert_eq(captured_snapshot.edges.length(), 1)
  assert_eq(captured_snapshot.edges[0].tail, 1)
  assert_eq(captured_snapshot.edges[0].head, 0)
  assert_eq(captured_snapshot.edges[0].minlen, 23)
  assert_eq(captured_snapshot.edges[0].weight, 0)
}
