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
