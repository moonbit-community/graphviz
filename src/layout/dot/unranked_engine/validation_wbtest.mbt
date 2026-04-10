// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn assert_prepare_neato_layout_tree_error(
  source : String,
  needle : String,
) -> Unit raise {
  let graph = @dot_parser.parse_dot(source)
  match prepare_neato_layout_tree(graph, 72.0, false) {
    Ok(_) => fail("expected neato prep error containing \{needle}")
    Err(message) =>
      if !message.contains(needle) {
        fail("expected error containing \{needle}, got: \{message}")
      }
  }
}

///|
test "prepare_neato_layout_tree rejects negative graph, node, and edge attrs" {
  let cases : Array[(String, String)] = [
    ("graph { nodesep=-1; a; b; a -- b; }", "nodesep"),
    ("graph { a [width=-1]; b; a -- b; }", "width"),
    ("graph { a [height=-1]; b; a -- b; }", "height"),
    ("graph { a -- b [len=-1]; }", "len"),
    ("graph { a -- b [weight=-1]; }", "weight"),
  ]
  for entry in cases {
    let (source, needle) = entry
    assert_prepare_neato_layout_tree_error(source, needle)
  }
}
