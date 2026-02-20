///|
fn string_has_non_ascii(text : String) -> Bool {
  for ch in text {
    if !ch.is_ascii() {
      return true
    }
  }
  false
}

///|
fn graph_has_non_ascii(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("label") {
    Some(value) => if string_has_non_ascii(value) { return true }
    None => ()
  }
  for node in graph.nodes() {
    if string_has_non_ascii(node.name()) {
      return true
    }
    match node.get_attr("label") {
      Some(value) => if string_has_non_ascii(value) { return true }
      None => ()
    }
  }
  false
}

///|
fn assert_non_ascii_layout(path : String) -> Unit raise {
  let graph = @dot_parser.parse_dot_file(path)
  let layout = layout_dot(graph)
  layout.apply()
  guard graph.nodes().length() > 0 else {
    fail("expected nodes in \{path}")
  }
  guard graph.get_attr("bb") is Some(_) else {
    fail("missing bb for \{path}")
  }
  for node in graph.nodes() {
    guard node.get_attr("pos") is Some(_) else {
      fail("missing pos for node \{node.name()} in \{path}")
    }
    guard node.get_attr("width") is Some(_) else {
      fail("missing width for node \{node.name()} in \{path}")
    }
    guard node.get_attr("height") is Some(_) else {
      fail("missing height for node \{node.name()} in \{path}")
    }
  }
  for edge in graph.edges() {
    guard edge.get_attr("pos") is Some(_) else {
      fail(
        "missing pos for edge \{edge.tail().name()} -> \{edge.head().name()} in \{path}",
      )
    }
  }
  guard graph_has_non_ascii(graph) else {
    fail("expected non-ascii labels in \{path}")
  }
}

///|
test "dot layout handles non-ascii graphs" {
  assert_non_ascii_layout("refs/graphviz/graphs/directed/japanese.gv")
  assert_non_ascii_layout("refs/graphviz/graphs/directed/russian.gv")
}
