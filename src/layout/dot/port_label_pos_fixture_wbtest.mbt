///|
struct PortLabelFixture {
  graph : String
  tail : String
  head : String
  head_label : Bool
  label : String
  label_html : Bool
  labelangle : Double
  labeldistance : Double
  dist : Double
  pe_x : Double
  pe_y : Double
  pf_x : Double
  pf_y : Double
  pos_x : Double
  pos_y : Double
}

///|
fn load_port_label_fixtures() -> Array[PortLabelFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/port_label_pos.jsonl")
  let fixtures : Array[PortLabelFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let obj = require_object_local(@json.parse(line))
    let event : String = @json.from_json(obj["event"])
    if event != "port_label_pos" {
      continue
    }
    fixtures.push({
      graph: @json.from_json(obj["graph"]),
      tail: @json.from_json(obj["tail"]),
      head: @json.from_json(obj["head"]),
      head_label: @json.from_json(obj["head_label"]),
      label: @json.from_json(obj["label"]),
      label_html: @json.from_json(obj["label_html"]),
      labelangle: @json.from_json(obj["labelangle"]),
      labeldistance: @json.from_json(obj["labeldistance"]),
      dist: @json.from_json(obj["dist"]),
      pe_x: @json.from_json(obj["pe_x"]),
      pe_y: @json.from_json(obj["pe_y"]),
      pf_x: @json.from_json(obj["pf_x"]),
      pf_y: @json.from_json(obj["pf_y"]),
      pos_x: @json.from_json(obj["pos_x"]),
      pos_y: @json.from_json(obj["pos_y"]),
    })
  }
  fixtures
}

///|
fn find_edge_by_nodes(
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

///|
fn load_port_label_graph(
  graphs : Map[String, @cgraph.Graph],
  name : String,
) -> @cgraph.Graph raise {
  match graphs.get(name) {
    Some(value) => value
    None => {
      let path = match name {
        "port_label" => "tests/layout/dot/port_label.dot"
        "port_label_lr" => "tests/layout/dot/port_label_lr.dot"
        "port_label_rl" => "tests/layout/dot/port_label_rl.dot"
        "port_label_bt" => "tests/layout/dot/port_label_bt.dot"
        _ => fail("unknown port label fixture graph \{name}")
      }
      let graph = @dot_parser.parse_dot_file(path)
      graphs[name] = graph
      graph
    }
  }
}

///|
fn assert_port_label_edge(
  edge : @cgraph.Edge,
  fixture : PortLabelFixture,
) -> Unit raise {
  if fixture.label == "" {
    fail("empty port label for \{fixture.tail} -> \{fixture.head}")
  }
  let attr_name = if fixture.head_label { "headlabel" } else { "taillabel" }
  let attr_value = edge.get_attr(attr_name)
  match attr_value {
    Some(value) =>
      if value != fixture.label {
        fail(
          "port label attr mismatch (\{fixture.tail} -> \{fixture.head}) attr=\{attr_name} expected=\{fixture.label} actual=\{value}",
        )
      }
    None =>
      fail(
        "missing port label attr (\{fixture.tail} -> \{fixture.head}) attr=\{attr_name}",
      )
  }
}

///|
test "port label positions match Graphviz" {
  if !@edge_spline.LIBM_IS_NATIVE {
    return
  }
  let fixtures = load_port_label_fixtures()
  guard fixtures.length() > 0 else { fail("missing port label fixtures") }
  for fixture in fixtures {
    assert_eq(fixture.label_html, false)
    assert_eq(fixture.dist, @node_geometry.PORT_LABEL_DISTANCE_PT * fixture.labeldistance)
    let actual = @edge_label.port_label_pos_from_points(
      @edge_spline.point(fixture.pe_x, fixture.pe_y),
      @edge_spline.point(fixture.pf_x, fixture.pf_y),
      fixture.labelangle,
      fixture.labeldistance,
      @node_geometry.PORT_LABEL_DISTANCE_PT,
      @node_geometry.GRAPHVIZ_PI,
    )
    if actual.x != fixture.pos_x || actual.y != fixture.pos_y {
      fail(
        "port label pos mismatch (\{fixture.graph} \{fixture.tail}->\{fixture.head} head=\{fixture.head_label} '\{fixture.label}') got (\{actual.x},\{actual.y}) expected (\{fixture.pos_x},\{fixture.pos_y})",
      )
    }
  }
}

///|
test "port label params match Graphviz defaults" {
  let fixtures = load_port_label_fixtures()
  guard fixtures.length() > 0 else { fail("missing port label fixtures") }
  let graphs : Map[String, @cgraph.Graph] = Map::new()
  for fixture in fixtures {
    let graph = load_port_label_graph(graphs, fixture.graph)
    let edge = match find_edge_by_nodes(graph, fixture.tail, fixture.head) {
      Some(value) => value
      None =>
        fail(
          "missing edge \{fixture.tail} -> \{fixture.head} for port label fixtures",
        )
    }
    assert_port_label_edge(edge, fixture)
    let (angle_deg, distance_scale) = match @edge_label.port_label_params(
      edge,
      @node_geometry.PORT_LABEL_ANGLE_DEG,
      @node_geometry.PORT_LABEL_ANGLE_MIN_DEG,
    ) {
      Some(value) => value
      None =>
        fail(
          "missing port label params for edge \{fixture.tail} -> \{fixture.head}",
        )
    }
    if angle_deg != fixture.labelangle ||
      distance_scale != fixture.labeldistance {
      fail(
        "port label params mismatch (\{fixture.tail}->\{fixture.head}) got (\{angle_deg},\{distance_scale}) expected (\{fixture.labelangle},\{fixture.labeldistance})",
      )
    }
  }
}
