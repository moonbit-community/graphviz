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
fn assert_layout_error_with_options(
  source : String,
  options : DotLayoutOptions,
  needle : String,
) -> Unit raise {
  let graph = @dot_parser.parse_dot(source)
  try layout_dot(graph, options=options) catch {
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
test "layout_dot rejects negative nodesep option" {
  assert_layout_error_with_options(
    "digraph { a; }",
    {
      rankdir: None,
      nodesep: Some(-1.0),
      ranksep: None,
      splines: None,
    },
    "nodesep must be non-negative",
  )
}

///|
test "layout_dot rejects negative ranksep option" {
  assert_layout_error_with_options(
    "digraph { a; }",
    {
      rankdir: None,
      nodesep: None,
      ranksep: Some(-1.0),
      splines: None,
    },
    "ranksep must be non-negative",
  )
}

///|
test "layout_neato rejects negative nodesep" {
  assert_neato_error("graph { nodesep=-1; a; b; a -- b; }", "nodesep")
}

///|
test "layout_neato rejects negative node width" {
  assert_neato_error("graph { a [width=-1]; b; a -- b; }", "width")
}

///|
test "layout_neato rejects negative node height" {
  assert_neato_error("graph { a [height=-1]; b; a -- b; }", "height")
}
