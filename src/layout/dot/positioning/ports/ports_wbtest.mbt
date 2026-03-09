///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
test "port order fraction keeps Graphviz cardinal compass quantization" {
  assert_eq(port_order_fraction({ x: 0.0, y: 0.0 }), 0.5)
  assert_close(port_order_fraction({ x: 0.0, y: 1.0 }), 0.0)
  assert_close(port_order_fraction({ x: -1.0, y: 0.0 }), 0.25)
  assert_close(port_order_fraction({ x: 0.0, y: -1.0 }), 0.5)
  assert_close(port_order_fraction({ x: 1.0, y: 0.0 }), 0.75)
}

///|
test "record port sampling uses mapped geometry before compass fallback" {
  let size = @node_primitives.node_size_from_points(8.0, 4.0)
  let info : @record_geometry.RecordPort = {
    center: { x: 10.0, y: 20.0 },
    size,
    sides: 0,
  }
  let offsets : Map[String, Map[String, @record_geometry.RecordPort]] = {
    "n": { "p": info },
  }
  let named_ne : @cgraph.Port = {
    name: Some("p"),
    compass: Some(@cgraph.Compass::NE),
  }
  let named_w : @cgraph.Port = {
    name: Some("p"),
    compass: Some(@cgraph.Compass::W),
  }
  let missing_e : @cgraph.Port = {
    name: Some("missing"),
    compass: Some(@cgraph.Compass::E),
  }

  assert_eq(record_port_point(info, Some(@cgraph.Compass::NE)), {
    x: 14.0,
    y: 22.0,
  })
  assert_eq(
    sample_edge_port_offset("n", Some(named_ne), offsets, _ => 99.0),
    14.0,
  )
  assert_eq(
    sample_edge_port_offset("n", Some(named_w), offsets, _ => 99.0),
    6.0,
  )
  assert_eq(
    sample_edge_port_offset("n", Some(missing_e), offsets, _ => 42.0),
    42.0,
  )
  assert_eq(sample_edge_port_offset("n", None, offsets, _ => 42.0), 0.0)

  let expected_order = port_order_fraction({ x: 14.0, y: 22.0 })
  assert_close(
    sample_edge_port_order("n", Some(named_ne), offsets, _ => {
      x: 100.0,
      y: 0.0,
    }),
    expected_order,
  )
  assert_close(
    sample_edge_port_order("n", Some(missing_e), offsets, _ => {
      x: 1.0,
      y: 0.0,
    }),
    0.75,
  )
  assert_eq(
    sample_edge_port_order("n", None, offsets, _ => { x: 1.0, y: 0.0 }),
    0.0,
  )
}

///|
test "resolve_compass_port_point uses box fallback or shape-clipped point before rankdir offset" {
  let sizes : Map[String, @node_primitives.NodeSize] = {
    "n": @node_primitives.vnode_size_from_widths_with_h(12.0, 18.0, 20.0),
  }
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")

  let box_point = resolve_compass_port_point(
    "n",
    None,
    @cgraph.Compass::NE,
    sizes,
    @rankdir.RankDir::TB,
    _ => false,
    (_node, _size, _compass, _rankdir) => { x: 99.0, y: 99.0 },
    (point, _rankdir) => point,
  )
  assert_eq(box_point, { x: 18.0, y: 10.0 })

  let clipped_point = resolve_compass_port_point(
    "n",
    Some(node),
    @cgraph.Compass::E,
    sizes,
    @rankdir.RankDir::LR,
    _ => true,
    (_node, _size, _compass, _rankdir) => { x: 7.0, y: 3.0 },
    (point, rankdir) => {
      if rankdir == @rankdir.RankDir::LR {
        { x: point.y, y: -point.x }
      } else {
        point
      }
    },
  )
  assert_eq(clipped_point, { x: 3.0, y: -7.0 })
}

///|
test "sample_compass_port_offset keeps unrotated x for record-like nodes" {
  let sizes : Map[String, @node_primitives.NodeSize] = {
    "n": @node_primitives.node_size_from_points(20.0, 10.0),
  }
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")

  let rotated = sample_compass_port_offset(
    @cgraph.Compass::E,
    "n",
    sizes,
    @rankdir.RankDir::LR,
    Some(node),
    (_name, _node, _compass, _sizes, _rankdir) => { x: 10.0, y: 4.0 },
    _ => false,
    (point, rankdir) => {
      if rankdir == @rankdir.RankDir::LR {
        { x: point.y, y: -point.x }
      } else {
        point
      }
    },
  )
  assert_eq(rotated, 4.0)

  let unrotated = sample_compass_port_offset(
    @cgraph.Compass::E,
    "n",
    sizes,
    @rankdir.RankDir::LR,
    Some(node),
    (_name, _node, _compass, _sizes, _rankdir) => { x: 10.0, y: 4.0 },
    _ => true,
    (point, rankdir) => {
      if rankdir == @rankdir.RankDir::LR {
        { x: point.y, y: -point.x }
      } else {
        point
      }
    },
  )
  assert_eq(unrotated, 10.0)
}

///|
test "build_port_offsets_with_callbacks uses fallback node size then rotates centers and swaps sizes in LR" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("rankdir", "LR")
  let node = graph.node("n")
  let missing_size_rankdir = Ref::new(@rankdir.RankDir::TB)
  let ports_rankdir = Ref::new(@rankdir.RankDir::TB)
  let observed_base_size = Ref::new(
    @node_primitives.node_size_from_points(0.0, 0.0),
  )
  let missing_size_calls = Ref::new(0)
  let ports_calls = Ref::new(0)

  let offsets = build_port_offsets_with_callbacks(
    [node],
    Map::new(),
    (_node, rankdir) => {
      missing_size_calls.val = missing_size_calls.val + 1
      missing_size_rankdir.val = rankdir
      @node_primitives.node_size_from_points(20.0, 10.0)
    },
    (_node, _origin, base_size, rankdir) => {
      ports_calls.val = ports_calls.val + 1
      ports_rankdir.val = rankdir
      observed_base_size.val = base_size
      {
        "p": {
          center: { x: base_size.width_pt, y: base_size.height_pt },
          size: @node_primitives.node_size_from_points(6.0, 8.0),
          sides: 3,
        },
      }
    },
    @port_geometry.layout_port_offset,
    @node_primitives.swap_node_size,
  )

  assert_eq(missing_size_calls.val, 1)
  assert_eq(ports_calls.val, 1)
  assert_eq(missing_size_rankdir.val, @rankdir.RankDir::LR)
  assert_eq(ports_rankdir.val, @rankdir.RankDir::LR)
  assert_eq(observed_base_size.val.width_pt, 20.0)
  assert_eq(observed_base_size.val.height_pt, 10.0)

  let node_offsets = match offsets.get("n") {
    Some(value) => value
    None => fail("expected node offsets")
  }
  let port = match node_offsets.get("p") {
    Some(value) => value
    None => fail("expected port offset")
  }

  assert_eq(port.center, { x: 10.0, y: -20.0 })
  assert_eq(port.size.width_pt, 8.0)
  assert_eq(port.size.height_pt, 6.0)
  assert_eq(port.sides, 3)
}

///|
test "port_side_mask_for_self_edge prefers compass and otherwise uses named port sides" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")

  let port_maps : Map[String, Map[String, @record_geometry.RecordPort]] = {
    "n": {
      "west": {
        center: { x: -5.0, y: 0.0 },
        size: @node_primitives.node_size_from_points(4.0, 4.0),
        sides: @port_geometry.PORT_SIDE_LEFT,
      },
    },
  }

  let named_only : @cgraph.Port = { name: Some("west"), compass: None }
  let named_with_compass : @cgraph.Port = {
    name: Some("west"),
    compass: Some(@cgraph.Compass::E),
  }
  let missing_named : @cgraph.Port = { name: Some("missing"), compass: None }

  assert_eq(
    port_side_mask_for_self_edge(node, Some(named_only), port_maps),
    @port_geometry.PORT_SIDE_LEFT,
  )
  assert_eq(
    port_side_mask_for_self_edge(node, Some(named_with_compass), port_maps),
    @port_geometry.PORT_SIDE_RIGHT,
  )
  assert_eq(
    port_side_mask_for_self_edge(node, Some(missing_named), port_maps),
    0,
  )
  assert_eq(port_side_mask_for_self_edge(node, None, port_maps), 0)
}
