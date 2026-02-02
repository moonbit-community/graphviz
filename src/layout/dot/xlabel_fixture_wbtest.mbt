///|
struct XlabelFixture {
  graph : String
  kind : String
  node : String
  tail : String
  head : String
  label : String
  label_html : Bool
  flip : Bool
  pos_x : Double
  pos_y : Double
}

///|
fn load_xlabel_fixtures() -> Array[XlabelFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/xlabels.jsonl")
  let fixtures : Array[XlabelFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let obj = require_object_local(@json.parse(line))
    let event : String = @json.from_json(obj["event"])
    if event != "xlabel" {
      continue
    }
    fixtures.push({
      graph: @json.from_json(obj["graph"]),
      kind: @json.from_json(obj["kind"]),
      node: @json.from_json(obj["node"]),
      tail: @json.from_json(obj["tail"]),
      head: @json.from_json(obj["head"]),
      label: @json.from_json(obj["label"]),
      label_html: @json.from_json(obj["label_html"]),
      flip: @json.from_json(obj["flip"]),
      pos_x: @json.from_json(obj["pos_x"]),
      pos_y: @json.from_json(obj["pos_y"]),
    })
  }
  fixtures
}

///|
fn load_xlabel_graph(
  graphs : Map[String, @cgraph.Graph],
  name : String,
) -> @cgraph.Graph raise {
  match graphs.get(name) {
    Some(value) => value
    None => {
      let path = match name {
        "xlabels_tb" => "tests/layout/dot/xlabels_tb.dot"
        "xlabels_lr" => "tests/layout/dot/xlabels_lr.dot"
        _ => fail("unknown xlabel fixture graph \{name}")
      }
      let graph = @dot_parser.parse_dot_file(path)
      graphs[name] = graph
      graph
    }
  }
}

///|
fn load_xlabel_layout(
  layouts : Map[String, DotLayoutGraph],
  graphs : Map[String, @cgraph.Graph],
  name : String,
) -> DotLayoutGraph raise {
  match layouts.get(name) {
    Some(value) => value
    None => {
      let graph = load_xlabel_graph(graphs, name)
      let layout = layout_dot(graph)
      layouts[name] = layout
      layout
    }
  }
}

///|
fn find_node_layout(
  layout : DotLayoutGraph,
  node_name : String,
) -> DotLayoutNode? {
  for node_layout in layout.nodes {
    if node_layout.node.name() == node_name {
      return Some(node_layout)
    }
  }
  None
}

///|
fn edge_attr_text(edge : @cgraph.Edge, attr_name : String) -> String {
  match edge.get_attr(attr_name) {
    Some(value) => value
    None => ""
  }
}

///|
/// Graphviz parity: wasm-vs-native math can differ by 1 ULP; compare within a tight ULP window.
fn float_eq_ulp(a : Double, b : Double, max_ulp : UInt64) -> Bool {
  if a == b {
    return true
  }
  if a.is_nan() || b.is_nan() {
    return false
  }
  let to_ordered = (value : Double) => {
    let bits = Double::reinterpret_as_uint64(value)
    if bits >> 63 == 1 {
      UInt64::lnot(bits)
    } else {
      bits | 0x8000000000000000
    }
  }
  let oa = to_ordered(a)
  let ob = to_ordered(b)
  let diff = if oa > ob { oa - ob } else { ob - oa }
  diff <= max_ulp
}

fn assert_float_eq_ulp(
  actual : Double,
  expected : Double,
  max_ulp : UInt64,
  message : String,
) -> Unit raise {
  if !float_eq_ulp(actual, expected, max_ulp) {
    fail(message)
  }
}

///|
fn find_edge_layout_by_label(
  layout : DotLayoutGraph,
  tail : String,
  head : String,
  attr_name : String,
  label : String,
) -> DotLayoutEdge? {
  for edge_layout in layout.edges {
    let edge = edge_layout.edge
    if edge.tail().name() != tail || edge.head().name() != head {
      continue
    }
    if edge_attr_text(edge, attr_name) == label {
      return Some(edge_layout)
    }
  }
  None
}

///|
test "xlabel positions match Graphviz" {
  let max_ulp : UInt64 = 1
  let fixtures = load_xlabel_fixtures()
  guard fixtures.length() > 0 else { fail("missing xlabel fixtures") }
  let graphs : Map[String, @cgraph.Graph] = Map::new()
  let layouts : Map[String, DotLayoutGraph] = Map::new()
  for fixture in fixtures {
    assert_eq(fixture.label_html, false)
    let expected_flip = fixture.graph == "xlabels_lr"
    assert_eq(fixture.flip, expected_flip)
    let layout = load_xlabel_layout(layouts, graphs, fixture.graph)
    match fixture.kind {
      "node_xlabel" => {
        guard fixture.node != "" else {
          fail("missing node name for node xlabel fixture")
        }
        let node_layout = match find_node_layout(layout, fixture.node) {
          Some(value) => value
          None => fail("missing node \{fixture.node} in xlabel fixture graph")
        }
        let expected_label = match node_layout.node.get_attr("xlabel") {
          Some(value) => value
          None => ""
        }
        if expected_label != fixture.label {
          fail("node xlabel mismatch for \{fixture.node} expected '\{fixture.label}' got '\{expected_label}'")
        }
        let pos = match node_layout.xlabel_pos {
          Some(value) => value
          None => fail("missing node xlabel position for \{fixture.node}")
        }
        assert_float_eq_ulp(
          pos.x,
          fixture.pos_x,
          max_ulp,
          "node xlabel pos x mismatch \{fixture.graph} \{fixture.node} got (\{pos.x}) expected (\{fixture.pos_x})",
        )
        assert_float_eq_ulp(
          pos.y,
          fixture.pos_y,
          max_ulp,
          "node xlabel pos y mismatch \{fixture.graph} \{fixture.node} got (\{pos.y}) expected (\{fixture.pos_y})",
        )
      }
      "edge_xlabel" | "headlabel" | "taillabel" => {
        guard fixture.tail != "" && fixture.head != "" else {
          fail("missing edge endpoints for xlabel fixture")
        }
        let attr_name = match fixture.kind {
          "edge_xlabel" => "xlabel"
          "headlabel" => "headlabel"
          "taillabel" => "taillabel"
          _ => ""
        }
        let edge_layout = match find_edge_layout_by_label(
          layout,
          fixture.tail,
          fixture.head,
          attr_name,
          fixture.label,
        ) {
          Some(value) => value
          None =>
            fail(
              "missing labeled edge \{fixture.tail}->\{fixture.head} '\{fixture.label}' for kind \{fixture.kind}",
            )
        }
        let pos = match fixture.kind {
          "edge_xlabel" => edge_layout.xlabel_pos
          "headlabel" => edge_layout.head_label_pos
          "taillabel" => edge_layout.tail_label_pos
          _ => None
        }
        match pos {
          Some(value) => {
            assert_float_eq_ulp(
              value.x,
              fixture.pos_x,
              max_ulp,
              "edge xlabel pos x mismatch \{fixture.graph} \{fixture.kind} \{fixture.tail}->\{fixture.head} got (\{value.x}) expected (\{fixture.pos_x})",
            )
            assert_float_eq_ulp(
              value.y,
              fixture.pos_y,
              max_ulp,
              "edge xlabel pos y mismatch \{fixture.graph} \{fixture.kind} \{fixture.tail}->\{fixture.head} got (\{value.y}) expected (\{fixture.pos_y})",
            )
          }
          None =>
            fail(
              "missing edge label position \{fixture.graph} \{fixture.kind} \{fixture.tail}->\{fixture.head}",
            )
        }
      }
      _ => fail("unknown xlabel fixture kind \{fixture.kind}")
    }
  }
}
