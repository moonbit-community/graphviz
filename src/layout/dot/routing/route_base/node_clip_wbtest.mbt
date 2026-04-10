// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "clip_to_bbox returns the first rectangle intersection and preserves inside targets" {
  let rect : @geom.Rect = { llx: 4.0, lly: -2.0, urx: 8.0, ury: 2.0 }

  let clipped = clip_to_bbox(
    @edge_spline.point(0.0, 0.0),
    rect,
    @edge_spline.point(10.0, 0.0),
  )
  assert_eq(clipped, @edge_spline.point(4.0, 0.0))

  let preserved = clip_to_bbox(
    @edge_spline.point(0.0, 0.0),
    rect,
    @edge_spline.point(6.0, 1.0),
  )
  assert_eq(preserved, @edge_spline.point(6.0, 1.0))
}

///|
test "clip_polygon_shape_params promotes distorted two-sided polygons and rejects flat ones" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  node.set_attr("sides", "2")
  node.set_attr("distortion", "0.5")

  let promoted = clip_polygon_shape_params(node, "polygon")
  match promoted {
    Some(params) => {
      assert_eq(params.sides, 120)
      assert_eq(params.distortion, 0.5)
    }
    None => fail("expected distorted polygon params")
  }

  node.set_attr("distortion", "0")
  node.set_attr("skew", "0")
  let rejected = clip_polygon_shape_params(node, "polygon")
  match rejected {
    None => ()
    Some(_) => fail("expected flat two-sided polygon to be rejected")
  }
}

///|
test "clip_to_node_shape dispatches diamond clipping instead of rectangle fallback" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  node.set_attr("shape", "diamond")
  let size = @node_primitives.node_size_from_points(20.0, 20.0)

  let clipped = clip_to_node_shape(
    node,
    @edge_spline.point(0.0, 0.0),
    size,
    @edge_spline.point(20.0, 20.0),
  )

  assert_eq(clipped, @edge_spline.point(5.0, 5.0))
}
