///|
test "flat endpoint neighbor search skips virtual paths crossing the current flat edge" {
  let vnode = "_mbt_edge_vn_0_1"
  let groups = { 0: ["a", vnode, "b"] }
  let sizes = Map([(vnode, @node_primitives.node_size_from_points(2.0, 1.0))])
  let outgoing = Map([(vnode, ["c"])])
  let order = Map([("a", 0), (vnode, 1), ("b", 2), ("c", 0)])
  let without_edge = neighbor_names_for_rank(
    "a",
    0,
    groups,
    sizes,
    outgoing,
    {},
    order,
    None,
    None,
  )
  let with_edge = neighbor_names_for_rank(
    "a",
    0,
    groups,
    sizes,
    outgoing,
    {},
    order,
    None,
    Some("b"),
  )
  @test.assert_eq(without_edge.right, Some(vnode))
  @test.assert_eq(with_edge.right, Some("b"))
}

///|
test "flat bottom endpoints use the field corner and extend to the rank boundary" {
  let result = flat_endpoint_boxes(
    rect(50.0, -40.0, 100.0, 40.0),
    { x: 75.0, y: 0.0, },
    @node_primitives.node_size_from_points(30.0, 60.0),
    { x: 80.0, y: -30.0, },
    SIDE_BOTTOM,
    SIDE_BOTTOM,
    false,
    36.0,
    50.0,
    None,
  )
  @test.assert_eq(result.endpoint, { x: 80.0, y: -31.0, })
  @test.assert_eq(result.boxes, [
    rect(50.0, -40.0, 100.0, 40.0),
    rect(50.0, -50.0, 100.0, -40.0),
  ])
}

///|
test "flat top corridor clamps port nudges into connected endpoint boxes" {
  let tail = flat_endpoint_boxes(
    rect(0.0, -18.0, 54.0, 18.0),
    { x: 27.0, y: 0.0, },
    @node_primitives.node_size_from_points(54.0, 36.0),
    { x: 27.0, y: 18.0, },
    SIDE_TOP,
    SIDE_TOP,
    true,
    36.0,
    18.0,
    None,
  )
  let head = flat_endpoint_boxes(
    rect(100.0, -18.0, 154.0, 18.0),
    { x: 127.0, y: 0.0, },
    @node_primitives.node_size_from_points(54.0, 36.0),
    { x: 127.0, y: 18.0, },
    SIDE_TOP,
    SIDE_TOP,
    false,
    36.0,
    18.0,
    None,
  )
  guard flat_corridor_route(tail, head, SIDE_TOP, 9.0, 18.0) is Some(route) else {
    fail("missing flat corridor")
  }
  @test.assert_eq(tail.endpoint, { x: 27.0, y: 19.0, })
  @test.assert_eq(route.points[0], { x: 27.0, y: 18.0, })
  @test.assert_eq(route.points[route.points.length() - 1], {
    x: 127.0,
    y: 18.0,
  })
  assert_true(route.barriers.length() > 0)
}
