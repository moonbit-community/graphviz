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
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=record]; a [label=\"{a|{b|<here>c|d}|e}\"]; }",
  )
  let record_orientation =
    record_layout_orientation(graph_rankdir(graph))
  let node = graph.node("a")
  let size = node_size(node, record_orientation)
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
test "html_ports include td port names" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE><TR><TD PORT=\\\"p1\\\">one</TD></TR></TABLE>>]; }",
  )
  let record_orientation =
    record_layout_orientation(graph_rankdir(graph))
  let node = graph.node("a")
  let size = node_size(node, record_orientation)
  let ports = html_ports(node, @geom.Point::{ x: 0.0, y: 0.0 }, size)
  match ports.get("p1") {
    Some(port) => {
      let half_w = size.width_pt / 2.0
      let half_h = size.height_pt / 2.0
      assert_true(port.center.x >= -half_w && port.center.x <= half_w)
      assert_true(port.center.y >= -half_h && port.center.y <= half_h)
    }
    None => fail("missing html port")
  }
}

///|
test "record_ports honor rankdir LR field order" {
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=LR; node [shape=record]; b [label=\"<left>   |<mid> b |   \"]; }",
  )
  let record_orientation =
    record_layout_orientation(graph_rankdir(graph))
  let node = graph.node("b")
  let size = node_size(node, record_orientation)
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
test "record_ports rotate into layout coords for rankdir LR" {
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=LR; node [shape=record]; b [label=\"<left>   |<mid> b |   \"]; }",
  )
  let record_orientation =
    record_layout_orientation(graph_rankdir(graph))
  let node = graph.node("b")
  let size = node_size(node, record_orientation)
  let ports = record_ports(
    node,
    @geom.Point::{ x: 0.0, y: 0.0 },
    size,
    record_orientation,
  )
  let rotated = layout_ports_from_final(ports, @geom.Point::{ x: 0.0, y: 0.0 }, RankDir::LR)
  match rotated.get("left") {
    Some(port) => {
      assert_true(port.center.x > 0.0)
    }
    None => fail("missing left port")
  }
}
