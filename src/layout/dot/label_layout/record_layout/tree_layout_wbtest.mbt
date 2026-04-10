// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
  let source = "digraph { node [shape=Mrecord]; other_xprot [label=\"XPROT \\\"crystalizer\\\"\"]; }"
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
  let source = "digraph { node [shape=Mrecord]; machsrv_xprot_gen [label=\"<f0>Machsrv Core|<f1>PROT_A-to-XPROT Converter\"]; }"
  let (inner_rect, layout) = record_layout_for_node(source, "machsrv_xprot_gen")

  assert_rect_close(inner_rect, -140.875, -18.0, 140.875, 18.0)
  guard layout.length() == 2 else { fail("expected split fields") }
  let left = layout[0]
  let right = layout[1]
  assert_eq(left.children.length(), 0)
  assert_eq(right.children.length(), 0)
  assert_eq(
    left.sides,
    @port_geometry.PORT_SIDE_TOP |
    @port_geometry.PORT_SIDE_BOTTOM |
    @port_geometry.PORT_SIDE_LEFT,
  )
  assert_eq(
    right.sides,
    @port_geometry.PORT_SIDE_TOP |
    @port_geometry.PORT_SIDE_BOTTOM |
    @port_geometry.PORT_SIDE_RIGHT,
  )
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
  let source = "digraph { node [shape=Mrecord]; zzz [label=\"ZZZ\"]; }"
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
  let source = "digraph { node [shape=Mrecord]; zzz_worker [label=\"{ZZZ Worker}\"]; }"
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
  let source = "digraph { node [shape=Mrecord]; foo_agent [label=\"{Foo Agent}\"]; }"
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
