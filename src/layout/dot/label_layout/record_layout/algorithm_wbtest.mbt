///|
fn assert_close(actual : Double, expected : Double, tol : Double) -> Unit raise {
  let ok = Double::is_close(actual, expected, absolute_tolerance=tol)
  if !ok {
    fail("expected \{expected}, got \{actual}")
  }
}

///|
const ALL_PORT_SIDES : Int =
  @port_geometry.PORT_SIDE_TOP |
  @port_geometry.PORT_SIDE_BOTTOM |
  @port_geometry.PORT_SIDE_LEFT |
  @port_geometry.PORT_SIDE_RIGHT

///|
fn assert_rect_close(
  actual : @geom.Rect,
  llx : Double,
  lly : Double,
  urx : Double,
  ury : Double,
) -> Unit raise {
  assert_close(actual.llx, llx, 0.0001)
  assert_close(actual.lly, lly, 0.0001)
  assert_close(actual.urx, urx, 0.0001)
  assert_close(actual.ury, ury, 0.0001)
}

///|
fn record_layout_for_node(
  source : String,
  node_name : String,
) -> (@geom.Rect, Array[RecordLayoutNode]) raise {
  reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(source)
  let orientation = @shared.record_layout_orientation(
    @rankdir.graph_rankdir(graph),
  )
  let node = graph.node(node_name)
  let size = @node_geometry.node_size(node, orientation)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = @label_attrs.node_padding(node)
  let inner_rect : @geom.Rect = {
    llx: -size.width_pt / 2.0,
    lly: -size.height_pt / 2.0 + @record_geometry.RECORD_BORDER_PT,
    urx: size.width_pt / 2.0,
    ury: size.height_pt / 2.0 - @record_geometry.RECORD_BORDER_PT,
  }
  let layout = layout_record_tree(
    record_nodes(@label_attrs.label_text(node)),
    inner_rect,
    orientation,
    font,
    font_size_pt,
    padding.pad_x_pt,
    padding.pad_y_pt,
    ALL_PORT_SIDES,
  )
  (inner_rect, layout)
}

///|
test "record_nodes parses nested braces" {
  let nodes = record_nodes("{a|{b|<here>c|d}|e}")
  guard nodes.length() == 1 else { fail("expected single top-level group") }
  match nodes[0] {
    RecordNode::Group(top) => {
      guard top.length() == 3 else { fail("expected 3 top-level fields") }
      match top[0] {
        RecordNode::Field(field_a) => {
          assert_eq(field_a.name, None)
          assert_eq(field_a.text, "a")
        }
        _ => fail("expected first field")
      }
      match top[1] {
        RecordNode::Group(children) => {
          guard children.length() == 3 else { fail("expected 3 nested fields") }
          match children[0] {
            RecordNode::Field(field_b) => {
              assert_eq(field_b.name, None)
              assert_eq(field_b.text, "b")
            }
            _ => fail("expected nested field b")
          }
          match children[1] {
            RecordNode::Field(field_c) => {
              assert_eq(field_c.name, Some("here"))
              assert_eq(field_c.text, "c")
            }
            _ => fail("expected nested field c")
          }
          match children[2] {
            RecordNode::Field(field_d) => {
              assert_eq(field_d.name, None)
              assert_eq(field_d.text, "d")
            }
            _ => fail("expected nested field d")
          }
        }
        _ => fail("expected nested group")
      }
      match top[2] {
        RecordNode::Field(field_e) => {
          assert_eq(field_e.name, None)
          assert_eq(field_e.text, "e")
        }
        _ => fail("expected last field")
      }
    }
    _ => fail("expected top-level group")
  }
}

///|
test "layout_record_tree assigns group orientation and side masks" {
  let nodes = record_nodes("<left>a|{<top>b|<bottom>c}|<right>d")
  let rect : @geom.Rect = { llx: -120.0, lly: -40.0, urx: 120.0, ury: 40.0 }
  let layout = layout_record_tree(
    nodes,
    rect,
    RecordOrientation::Horizontal,
    "Times-Roman",
    14.0,
    8.0,
    4.0,
    @port_geometry.PORT_SIDE_TOP |
    @port_geometry.PORT_SIDE_BOTTOM |
    @port_geometry.PORT_SIDE_LEFT |
    @port_geometry.PORT_SIDE_RIGHT,
  )

  assert_eq(layout.length(), 3)
  assert_eq(
    layout[0].sides,
    @port_geometry.PORT_SIDE_TOP |
    @port_geometry.PORT_SIDE_BOTTOM |
    @port_geometry.PORT_SIDE_LEFT,
  )
  assert_eq(
    layout[1].sides,
    @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_BOTTOM,
  )
  assert_eq(
    layout[2].sides,
    @port_geometry.PORT_SIDE_TOP |
    @port_geometry.PORT_SIDE_BOTTOM |
    @port_geometry.PORT_SIDE_RIGHT,
  )

  let group = layout[1]
  match group.field {
    Some(_) => fail("expected nested group")
    None => ()
  }
  assert_eq(group.children.length(), 2)
  assert_true(group.children[0].rect.ury > group.children[1].rect.ury)
  assert_eq(group.children[0].sides, @port_geometry.PORT_SIDE_TOP)
  assert_eq(group.children[1].sides, @port_geometry.PORT_SIDE_BOTTOM)

  match group.children[0].field {
    Some(field) => assert_eq(field.name, Some("top"))
    None => fail("expected top child field")
  }
  match group.children[1].field {
    Some(field) => assert_eq(field.name, Some("bottom"))
    None => fail("expected bottom child field")
  }
}

///|
test "layout_record_tree preserves exact geometry for quoted leaf record" {
  let source =
    "digraph { node [shape=Mrecord]; other_xprot [label=\"XPROT \\\"crystalizer\\\"\"]; }"
  let (inner_rect, layout) = record_layout_for_node(source, "other_xprot")

  assert_rect_close(inner_rect, -65.75, -18.0, 65.75, 18.0)
  guard layout.length() == 1 else { fail("expected single field") }
  let leaf = layout[0]
  assert_eq(leaf.sides, ALL_PORT_SIDES)
  assert_eq(leaf.children.length(), 0)
  assert_rect_close(leaf.rect, -65.75, -18.0, 65.75, 18.0)
  match leaf.field {
    Some(field) => {
      assert_eq(field.name, None)
      assert_eq(field.text, "XPROT \"crystalizer\"")
    }
    None => fail("expected leaf field")
  }
}

///|
test "layout_record_tree preserves exact geometry for split record fields" {
  let source =
    "digraph { node [shape=Mrecord]; machsrv_xprot_gen [label=\"<f0>Machsrv Core|<f1>PROT_A-to-XPROT Converter\"]; }"
  let (inner_rect, layout) = record_layout_for_node(source, "machsrv_xprot_gen")

  assert_rect_close(inner_rect, -140.875, -18.0, 140.875, 18.0)
  guard layout.length() == 2 else { fail("expected split fields") }
  let left = layout[0]
  let right = layout[1]
  assert_eq(left.children.length(), 0)
  assert_eq(right.children.length(), 0)
  assert_eq(left.sides, @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_BOTTOM | @port_geometry.PORT_SIDE_LEFT)
  assert_eq(right.sides, @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_BOTTOM | @port_geometry.PORT_SIDE_RIGHT)
  assert_rect_close(left.rect, -140.875, -18.0, -46.875, 18.0)
  assert_rect_close(right.rect, -46.875, -18.0, 140.875, 18.0)
  match left.field {
    Some(field) => {
      assert_eq(field.name, Some("f0"))
      assert_eq(field.text, "Machsrv Core")
    }
    None => fail("expected left field")
  }
  match right.field {
    Some(field) => {
      assert_eq(field.name, Some("f1"))
      assert_eq(field.text, "PROT_A-to-XPROT Converter")
    }
    None => fail("expected right field")
  }
}

///|
test "layout_record_tree preserves exact geometry for compact leaf record" {
  let source =
    "digraph { node [shape=Mrecord]; zzz [label=\"ZZZ\"]; }"
  let (inner_rect, layout) = record_layout_for_node(source, "zzz")

  assert_rect_close(inner_rect, -27.0, -18.0, 27.0, 18.0)
  guard layout.length() == 1 else { fail("expected single field") }
  let leaf = layout[0]
  assert_eq(leaf.sides, ALL_PORT_SIDES)
  assert_eq(leaf.children.length(), 0)
  assert_rect_close(leaf.rect, -27.0, -18.0, 26.75, 18.0)
  match leaf.field {
    Some(field) => {
      assert_eq(field.name, None)
      assert_eq(field.text, "ZZZ")
    }
    None => fail("expected leaf field")
  }
}

///|
test "layout_record_tree preserves exact geometry for wrapped worker record" {
  let source =
    "digraph { node [shape=Mrecord]; zzz_worker [label=\"{ZZZ Worker}\"]; }"
  let (inner_rect, layout) = record_layout_for_node(source, "zzz_worker")

  assert_rect_close(inner_rect, -42.5, -18.0, 42.5, 18.0)
  guard layout.length() == 1 else { fail("expected wrapped top-level group") }
  let group = layout[0]
  assert_eq(group.sides, ALL_PORT_SIDES)
  assert_rect_close(group.rect, -42.5, -18.0, 42.5, 18.0)
  match group.field {
    Some(_) => fail("expected group node")
    None => ()
  }
  guard group.children.length() == 1 else { fail("expected nested leaf") }
  let leaf = group.children[0]
  assert_eq(leaf.sides, ALL_PORT_SIDES)
  assert_eq(leaf.children.length(), 0)
  assert_rect_close(leaf.rect, -42.5, -17.5, 42.5, 18.0)
  match leaf.field {
    Some(field) => {
      assert_eq(field.name, None)
      assert_eq(field.text, "ZZZ Worker")
    }
    None => fail("expected wrapped leaf field")
  }
}

///|
test "layout_record_tree preserves exact geometry for wrapped single-field record" {
  let source =
    "digraph { node [shape=Mrecord]; foo_agent [label=\"{Foo Agent}\"]; }"
  let (inner_rect, layout) = record_layout_for_node(source, "foo_agent")

  assert_rect_close(inner_rect, -36.5, -18.0, 36.5, 18.0)
  guard layout.length() == 1 else { fail("expected wrapped top-level group") }
  let group = layout[0]
  assert_eq(group.sides, ALL_PORT_SIDES)
  assert_rect_close(group.rect, -36.5, -18.0, 36.5, 18.0)
  match group.field {
    Some(_) => fail("expected group node")
    None => ()
  }
  guard group.children.length() == 1 else { fail("expected nested leaf") }
  let leaf = group.children[0]
  assert_eq(leaf.sides, ALL_PORT_SIDES)
  assert_eq(leaf.children.length(), 0)
  assert_rect_close(leaf.rect, -36.5, -17.5, 36.5, 18.0)
  match leaf.field {
    Some(field) => {
      assert_eq(field.name, None)
      assert_eq(field.text, "Foo Agent")
    }
    None => fail("expected wrapped leaf field")
  }
}

///|
test "record_ports include nested port names" {
  reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=record]; nested_record [label=\"{a|{b|<here>c|d}|e}\"]; }",
  )
  let record_orientation = @shared.record_layout_orientation(
    @rankdir.graph_rankdir(graph),
  )
  let node = graph.node("nested_record")
  let size = @node_geometry.node_size(node, record_orientation)
  let ports = record_ports(
    node,
    @geom.Point::{ x: 0.0, y: 0.0 },
    size,
    record_orientation,
  )
  match ports.get("here") {
    Some(port) => {
      let half_w = size.width_pt / 2.0
      let half_h = size.height_pt / 2.0
      assert_true(port.center.x >= -half_w && port.center.x <= half_w)
      assert_true(port.center.y >= -half_h && port.center.y <= half_h)
    }
    None => fail("missing nested port")
  }
}

///|
test "record_ports honor rankdir LR field order" {
  reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=LR; node [shape=record]; ordered_record [label=\"<left>   |<mid> b |   \"]; }",
  )
  let record_orientation = @shared.record_layout_orientation(
    @rankdir.graph_rankdir(graph),
  )
  let node = graph.node("ordered_record")
  let size = @node_geometry.node_size(node, record_orientation)
  let ports = record_ports(
    node,
    @geom.Point::{ x: 0.0, y: 0.0 },
    size,
    record_orientation,
  )
  match ports.get("left") {
    Some(port) => assert_true(port.center.y > 0.0)
    None => fail("missing left port")
  }
}

///|
test "record_port_path_box expands an explicit field port to the full field lane" {
  reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=record]; path_box_record [label=\"<left>l|<mid>m|<right>r\"]; sink; path_box_record:left -> sink; path_box_record:right -> sink; }",
  )
  let rankdir = @rankdir.graph_rankdir(graph)
  let orientation = @shared.record_layout_orientation(rankdir)
  let node = graph.node("path_box_record")
  let size = @node_geometry.node_size(node, orientation)
  let ports = record_ports(node, { x: 0.0, y: 0.0 }, size, orientation)
  let left_port = match ports.get("left") {
    Some(value) => value
    None => fail("missing left port")
  }
  let right_port = match ports.get("right") {
    Some(value) => value
    None => fail("missing right port")
  }
  let edges = graph.edges()
  let left_box = match
    record_port_path_box(
      node,
      edges[0].tail_port(),
      { x: 0.0, y: 0.0 },
      size,
      rankdir,
    ) {
    Some(value) => value
    None => fail("expected left port path box")
  }
  let right_box = match
    record_port_path_box(
      node,
      edges[1].tail_port(),
      { x: 0.0, y: 0.0 },
      size,
      rankdir,
    ) {
    Some(value) => value
    None => fail("expected right port path box")
  }

  assert_close(left_box.lly, -size.height_pt / 2.0, 0.0001)
  assert_close(left_box.ury, size.height_pt / 2.0, 0.0001)
  assert_true(
    left_port.center.x >= left_box.llx && left_port.center.x <= left_box.urx,
  )
  assert_true(
    right_port.center.x >= right_box.llx && right_port.center.x <= right_box.urx,
  )
  assert_true(left_box.urx < 0.0)
  assert_true(right_box.llx > 0.0)
}

///|
test "record_port_padding_y tracks explicit top and bottom label ports" {
  reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=LR; node [shape=record]; padding_record [label=\"<top>t|<mid>m|<bot>b\"]; up; down; up -> padding_record:top; padding_record:bot -> down; }",
  )
  let orientation = @shared.record_layout_orientation(
    @rankdir.graph_rankdir(graph),
  )
  let node = graph.node("padding_record")
  let size = @node_geometry.node_size(node, orientation)
  let ports = record_ports(node, { x: 0.0, y: 0.0 }, size, orientation)
  let positions : Map[String, @geom.Point] = Map::new()
  positions["padding_record"] = { x: 0.0, y: 0.0 }
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  label_ports_map["padding_record"] = ports

  let padding = record_port_padding_y(graph.edges(), positions, label_ports_map)

  assert_true(padding.above > 0.0)
  assert_true(padding.below > 0.0)
}
