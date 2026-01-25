///|
fn assert_layout_error(source : String, needle : String) -> Unit raise {
  let graph = @dot_parser.parse_dot(source)
  try layout_dot(graph) catch {
    err => {
      let message = "\{err}"
      if !message.contains(needle) {
        fail("expected error containing \{needle}, got: \{message}")
      }
    }
  } noraise {
    _ => fail("expected layout error containing \{needle}")
  }
}

///|
fn assert_neato_error(source : String, needle : String) -> Unit raise {
  let graph = @dot_parser.parse_dot(source)
  try layout_neato(graph) catch {
    err => {
      let message = "\{err}"
      if !message.contains(needle) {
        fail("expected error containing \{needle}, got: \{message}")
      }
    }
  } noraise {
    _ => fail("expected layout error containing \{needle}")
  }
}

///|
test "layout_dot rejects negative nodesep" {
  assert_layout_error("digraph { nodesep=-1; a; }", "nodesep")
}

///|
test "layout_dot rejects negative ranksep" {
  assert_layout_error("digraph { ranksep=-1; a; }", "ranksep")
}

///|
test "layout_dot rejects negative node width" {
  assert_layout_error("digraph { a [width=-1]; }", "width")
}

///|
test "layout_dot rejects negative node height" {
  assert_layout_error("digraph { a [height=-1]; }", "height")
}

///|
test "layout_neato rejects negative nodesep" {
  assert_neato_error("graph { nodesep=-1; a; b; a -- b; }", "nodesep")
}
