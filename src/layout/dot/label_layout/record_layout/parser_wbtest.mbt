// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
test "record_nodes ignores unescaped ASCII control characters in field text" {
  let nodes = record_nodes("<p0>1571 \tas Ref: 1338 \tD")
  guard nodes.length() == 1 else { fail("expected one field") }
  match nodes[0] {
    RecordNode::Field(field) => {
      assert_eq(field.name, Some("p0"))
      assert_eq(field.text, "1571 as Ref: 1338 D")
    }
    _ => fail("expected field")
  }
}

///|
test "record_nodes compacts ordinary spaces but retains hard spaces" {
  let compacted = record_nodes("Honey   subscription")
  guard compacted.length() == 1 else { fail("expected one compacted field") }
  match compacted[0] {
    RecordNode::Field(field) => assert_eq(field.text, "Honey subscription")
    _ => fail("expected a compacted field")
  }

  let hard_spaced = record_nodes("Honey\\  subscription")
  guard hard_spaced.length() == 1 else {
    fail("expected one hard-spaced field")
  }
  match hard_spaced[0] {
    RecordNode::Field(field) => assert_eq(field.text, "Honey  subscription")
    _ => fail("expected a hard-spaced field")
  }
}
