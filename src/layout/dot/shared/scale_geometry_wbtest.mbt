///|
fn assert_scale_factors(
  actual : RatioFillScaleFactors?,
  expected_sx : Double,
  expected_sy : Double,
) -> Unit raise {
  match actual {
    Some(value) => {
      assert_eq(value.sx, expected_sx)
      assert_eq(value.sy, expected_sy)
    }
    None => fail("expected scale factors")
  }
}

///|
test "ratio_fill_scale_factors handles direct, flipped, clamped, and invalid cases" {
  let direct = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  direct.set_attr("ratio", "fill")
  direct.set_attr("size", "2,1")
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 72.0, ury: 36.0 }
  assert_scale_factors(ratio_fill_scale_factors(direct, bbox, RankDir::TB), 2.0, 2.0)
  assert_scale_factors(ratio_fill_scale_factors(direct, bbox, RankDir::LR), 1.0, 4.0)

  let clamped = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  clamped.set_attr("ratio", "fill")
  clamped.set_attr("size", "1,2")
  let wide_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 144.0, ury: 36.0 }
  assert_scale_factors(
    ratio_fill_scale_factors(clamped, wide_bbox, RankDir::TB),
    1.0,
    8.0,
  )

  let missing_ratio = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  missing_ratio.set_attr("size", "2,1")
  let invalid_size = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  invalid_size.set_attr("ratio", "fill")
  invalid_size.set_attr("size", "0,1")
  let non_fill = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  non_fill.set_attr("ratio", "compress")
  non_fill.set_attr("size", "2,1")
  let flat_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 0.0, ury: 10.0 }

  assert_true(ratio_fill_scale_factors(missing_ratio, bbox, RankDir::TB) is None)
  assert_true(ratio_fill_scale_factors(invalid_size, bbox, RankDir::TB) is None)
  assert_true(ratio_fill_scale_factors(non_fill, bbox, RankDir::TB) is None)
  assert_true(ratio_fill_scale_factors(direct, flat_bbox, RankDir::TB) is None)
}

///|
test "point and map scaling helpers keep expected rounding and axis scaling" {
  let point : @geom.Point = { x: 1.25, y: -2.5 }
  assert_eq(scale_point(point, 2.0, 3.0), { x: 2.5, y: -7.5 })
  assert_eq(scale_point_rounded({ x: 1.4, y: -2.6 }, 2.0, 3.0), { x: 3.0, y: -8.0 })
  assert_eq(scale_optional_point(Some(point), 2.0, 3.0), Some({ x: 2.5, y: -7.5 }))
  assert_eq(scale_optional_point(None, 2.0, 3.0), None)

  let points : Map[String, @geom.Point] = Map::new()
  points["a"] = { x: 1.4, y: -2.6 }
  points["b"] = { x: -0.6, y: 0.6 }
  let scaled_points = scale_point_map_rounded(points, 2.0, 3.0)
  assert_eq(scaled_points.get("a"), Some({ x: 3.0, y: -8.0 }))
  assert_eq(scaled_points.get("b"), Some({ x: -1.0, y: 2.0 }))

  let doubles : Map[Int, Double] = Map::new()
  doubles[1] = 1.24
  doubles[2] = -1.26
  let scaled_doubles = scale_double_map_rounded(doubles, 10.0)
  assert_eq(scaled_doubles.get(1), Some(12.0))
  assert_eq(scaled_doubles.get(2), Some(-13.0))

  let named : Map[String, Double] = Map::new()
  named["x"] = 1.5
  named["y"] = -2.0
  let scaled_named = scale_named_double_map(named, 4.0)
  assert_eq(scaled_named.get("x"), Some(6.0))
  assert_eq(scaled_named.get("y"), Some(-8.0))

  let rects : Map[String, @geom.Rect] = Map::new()
  rects["r"] = { llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 }
  let scaled_rects = scale_rect_map(rects, 2.0, 5.0)
  assert_eq(scaled_rects.get("r"), Some({ llx: 2.0, lly: 10.0, urx: 6.0, ury: 20.0 }))
}

///|
test "scale_edge_layout_output and scale_record_port_maps keep nested geometry synchronized" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let edges : Array[DotLayoutEdge] = [{
    edge,
    splines: [{
      start: Some({ x: 1.0, y: 2.0 }),
      end: Some({ x: 7.0, y: 8.0 }),
      points: [
        { x: 1.0, y: 2.0 },
        { x: 3.0, y: 4.0 },
        { x: 5.0, y: 6.0 },
        { x: 7.0, y: 8.0 },
      ],
    }],
    label_pos: Some({ x: 2.0, y: 3.0 }),
    head_label_pos: Some({ x: 4.0, y: 5.0 }),
    tail_label_pos: Some({ x: 0.0, y: 1.0 }),
    xlabel_pos: Some({ x: 6.0, y: 7.0 }),
  }]
  let scaled_edges = scale_edge_layout_output(edges, 2.0, 3.0)
  let scaled_spline = scaled_edges[0].splines[0]
  assert_eq(scaled_spline.start, Some({ x: 2.0, y: 6.0 }))
  assert_eq(scaled_spline.end, Some({ x: 14.0, y: 24.0 }))
  assert_eq(scaled_spline.points, [
    { x: 2.0, y: 6.0 },
    { x: 6.0, y: 12.0 },
    { x: 10.0, y: 18.0 },
    { x: 14.0, y: 24.0 },
  ])
  assert_eq(scaled_edges[0].label_pos, Some({ x: 4.0, y: 9.0 }))
  assert_eq(scaled_edges[0].head_label_pos, Some({ x: 8.0, y: 15.0 }))
  assert_eq(scaled_edges[0].tail_label_pos, Some({ x: 0.0, y: 3.0 }))
  assert_eq(scaled_edges[0].xlabel_pos, Some({ x: 12.0, y: 21.0 }))

  let ports : Map[String, Map[String, @record_geometry.RecordPort]] = Map::new()
  ports["node"] = {
    "p": {
      center: { x: 4.0, y: 5.0 },
      size: @node_primitives.node_size_from_points(10.0, 20.0),
      sides: 3,
    },
  }
  let scaled_ports = scale_record_port_maps(ports, 2.0, 0.5)
  let node_ports = match scaled_ports.get("node") {
    Some(value) => value
    None => fail("missing node ports")
  }
  let port = match node_ports.get("p") {
    Some(value) => value
    None => fail("missing port")
  }
  assert_eq(port.center, { x: 8.0, y: 2.5 })
  assert_eq(port.size.width_pt, 20.0)
  assert_eq(port.size.height_pt, 10.0)
  assert_eq(port.sides, 3)
}
