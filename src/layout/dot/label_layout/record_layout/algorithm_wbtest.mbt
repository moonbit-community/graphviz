///|
fn assert_close(actual : Double, expected : Double, tol : Double) -> Unit raise {
  let ok = Double::is_close(actual, expected, absolute_tolerance=tol)
  if !ok {
    fail("expected \{expected}, got \{actual}")
  }
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
test "record_ports include nested port names" {
  reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=record]; nested_record [label=\"{a|{b|<here>c|d}|e}\"]; }",
  )
  let record_orientation =
    @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
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
  let record_orientation =
    @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
  let node = graph.node("ordered_record")
  let size = @node_geometry.node_size(node, record_orientation)
  let ports = record_ports(
    node,
    @geom.Point::{ x: 0.0, y: 0.0 },
    size,
    record_orientation,
  )
  match ports.get("left") {
    Some(port) => {
      assert_true(port.center.y > 0.0)
    }
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
  let left_box = match record_port_path_box(node, edges[0].tail_port(), { x: 0.0, y: 0.0 }, size, rankdir) {
    Some(value) => value
    None => fail("expected left port path box")
  }
  let right_box = match record_port_path_box(node, edges[1].tail_port(), { x: 0.0, y: 0.0 }, size, rankdir) {
    Some(value) => value
    None => fail("expected right port path box")
  }

  assert_close(left_box.lly, -size.height_pt / 2.0, 0.0001)
  assert_close(left_box.ury, size.height_pt / 2.0, 0.0001)
  assert_true(left_port.center.x >= left_box.llx && left_port.center.x <= left_box.urx)
  assert_true(right_port.center.x >= right_box.llx && right_port.center.x <= right_box.urx)
  assert_true(left_box.urx < 0.0)
  assert_true(right_box.llx > 0.0)
}

///|
test "record_port_padding_y tracks explicit top and bottom label ports" {
  reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=LR; node [shape=record]; padding_record [label=\"<top>t|<mid>m|<bot>b\"]; up; down; up -> padding_record:top; padding_record:bot -> down; }",
  )
  let orientation = @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
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
