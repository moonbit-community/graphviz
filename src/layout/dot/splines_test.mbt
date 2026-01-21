///|
test "layout_dot accepts non-spline modes" {
  let modes : Array[String] = ["none", "polyline", "ortho"]
  for mode in modes {
    let graph = @dot_parser.parse_dot("digraph { splines=\{mode}; a -> b; }")
    let layout = layout_dot(graph)
    layout.apply()
    let edges = graph.edges()
    assert_eq(edges.length(), 1)
    match edges[0].get_attr("pos") {
      Some(value) => assert_true(value != "")
      None => fail("missing edge pos for splines=\{mode}")
    }
  }
}

///|
fn count_numbers(text : String) -> Int {
  let mut count = 0
  let mut in_num = false
  for ch in text {
    let is_num = ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.'
    if is_num {
      if !in_num {
        count = count + 1
        in_num = true
      }
    } else {
      in_num = false
    }
  }
  count
}

///|
fn edge_pos(edge : @cgraph.Edge) -> String {
  match edge.get_attr("pos") {
    Some(value) => value
    None => ""
  }
}

///|
fn find_edge(
  graph : @cgraph.Graph,
  tail : String,
  head : String,
) -> @cgraph.Edge? {
  for edge in graph.edges() {
    if edge.tail().name() == tail && edge.head().name() == head {
      return Some(edge)
    }
  }
  None
}

test "layout_dot ortho adds more control points than polyline" {
  let source = "digraph { a -> c; b -> c; }"
  let graph_poly = @dot_parser.parse_dot("digraph { splines=polyline; \{source} }")
  let layout_poly = layout_dot(graph_poly)
  layout_poly.apply()
  let poly_edge = match find_edge(graph_poly, "a", "c") {
    Some(edge) => edge
    None => fail("missing edge a -> c")
  }
  let poly_pos = edge_pos(poly_edge)
  assert_true(poly_pos != "")
  let graph_ortho = @dot_parser.parse_dot("digraph { splines=ortho; \{source} }")
  let layout_ortho = layout_dot(graph_ortho)
  layout_ortho.apply()
  let ortho_edge = match find_edge(graph_ortho, "a", "c") {
    Some(edge) => edge
    None => fail("missing edge a -> c")
  }
  let ortho_pos = edge_pos(ortho_edge)
  assert_true(ortho_pos != "")
  let poly_count = count_numbers(poly_pos)
  let ortho_count = count_numbers(ortho_pos)
  if ortho_count <= poly_count {
    fail(
      "expected ortho points > polyline points, poly=\{poly_count} ortho=\{ortho_count} poly_pos=\{poly_pos} ortho_pos=\{ortho_pos}",
    )
  }
}
