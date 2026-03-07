///|
struct EdgeLabelVnodeFixture {
  graph : String
  tail : String
  head : String
  label : String
  label_html : Bool
  flip : Bool
  vnode_x : Double
  vnode_y : Double
  dimen_x : Double
  dimen_y : Double
  pos_x : Double
  pos_y : Double
}

///|
struct EdgeLabelFlatFixture {
  graph : String
  tail : String
  head : String
  label : String
  label_html : Bool
  flip : Bool
  tp_x : Double
  tp_y : Double
  hp_x : Double
  hp_y : Double
  tail_rw : Double
  head_lw : Double
  place : Int
  dimen_x : Double
  dimen_y : Double
  pos_x : Double
  pos_y : Double
}

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
fn load_edge_label_vnode_fixtures() -> Array[EdgeLabelVnodeFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/edge_label_pos.jsonl")
  let fixtures : Array[EdgeLabelVnodeFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let obj = match @json.parse(line) {
      Json::Object(value) => value
      _ => fail("expected JSON object")
    }
    let event : String = @json.from_json(obj["event"])
    if event != "edge_label_vnode" {
      continue
    }
    fixtures.push({
      graph: @json.from_json(obj["graph"]),
      tail: @json.from_json(obj["tail"]),
      head: @json.from_json(obj["head"]),
      label: @json.from_json(obj["label"]),
      label_html: @json.from_json(obj["label_html"]),
      flip: @json.from_json(obj["flip"]),
      vnode_x: @json.from_json(obj["vnode_x"]),
      vnode_y: @json.from_json(obj["vnode_y"]),
      dimen_x: @json.from_json(obj["dimen_x"]),
      dimen_y: @json.from_json(obj["dimen_y"]),
      pos_x: @json.from_json(obj["pos_x"]),
      pos_y: @json.from_json(obj["pos_y"]),
    })
  }
  fixtures
}

///|
fn load_edge_label_flat_fixtures() -> Array[EdgeLabelFlatFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/edge_label_pos.jsonl")
  let fixtures : Array[EdgeLabelFlatFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let obj = match @json.parse(line) {
      Json::Object(value) => value
      _ => fail("expected JSON object")
    }
    let event : String = @json.from_json(obj["event"])
    if event != "edge_label_flat" {
      continue
    }
    fixtures.push({
      graph: @json.from_json(obj["graph"]),
      tail: @json.from_json(obj["tail"]),
      head: @json.from_json(obj["head"]),
      label: @json.from_json(obj["label"]),
      label_html: @json.from_json(obj["label_html"]),
      flip: @json.from_json(obj["flip"]),
      tp_x: @json.from_json(obj["tp_x"]),
      tp_y: @json.from_json(obj["tp_y"]),
      hp_x: @json.from_json(obj["hp_x"]),
      hp_y: @json.from_json(obj["hp_y"]),
      tail_rw: @json.from_json(obj["tail_rw"]),
      head_lw: @json.from_json(obj["head_lw"]),
      place: @json.from_json(obj["place"]),
      dimen_x: @json.from_json(obj["dimen_x"]),
      dimen_y: @json.from_json(obj["dimen_y"]),
      pos_x: @json.from_json(obj["pos_x"]),
      pos_y: @json.from_json(obj["pos_y"]),
    })
  }
  fixtures
}

///|
fn load_port_label_fixtures() -> Array[PortLabelFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/port_label_pos.jsonl")
  let fixtures : Array[PortLabelFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let obj = match @json.parse(line) {
      Json::Object(value) => value
      _ => fail("expected JSON object")
    }
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
fn find_edge_by_nodes_with_label(
  graph : @cgraph.Graph,
  tail : String,
  head : String,
  label : String,
) -> @cgraph.Edge? {
  for edge in graph.edges() {
    if edge.tail().name() != tail || edge.head().name() != head {
      continue
    }
    let edge_label = match edge.get_attr("label") {
      Some(value) => value
      None => ""
    }
    if edge_label == label {
      return Some(edge)
    }
  }
  None
}

///|
fn load_edge_label_graph(
  graphs : Map[String, @cgraph.Graph],
  name : String,
) -> @cgraph.Graph raise {
  match graphs.get(name) {
    Some(value) => value
    None => {
      let path = match name {
        "yours_truly" => "tests/layout/dot/complex.dot"
        "edge_labels" => "tests/layout/dot/edge_label_spacing.dot"
        "edge_vnode_spacing" => "tests/layout/dot/edge_vnode_spacing.dot"
        "edge_label_rl" => "tests/layout/dot/edge_label_rl.dot"
        "edge_label_bt" => "tests/layout/dot/edge_label_bt.dot"
        "edge_label_lr" => "tests/layout/dot/edge_label_lr.dot"
        "states" => "refs/graphviz/graphs/directed/states.gv"
        _ => fail("unknown edge label fixture graph \{name}")
      }
      let graph = @dot_parser.parse_dot_file(path)
      graphs[name] = graph
      graph
    }
  }
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
test "edge label vnode positions match Graphviz" {
  let fixtures = load_edge_label_vnode_fixtures()
  guard fixtures.length() > 0 else { fail("missing edge label vnode fixtures") }
  let graphs : Map[String, @cgraph.Graph] = Map::new()
  for fixture in fixtures {
    assert_eq(fixture.label_html, false)
    if fixture.graph == "" || fixture.tail == "" || fixture.head == "" ||
      fixture.label == "" {
      fail("missing edge label vnode fixture fields")
    }
    let graph = load_edge_label_graph(graphs, fixture.graph)
    let rankdir = @rankdir.graph_rankdir(graph)
    let expected_flip = rankdir == @rankdir.RankDir::LR || rankdir == @rankdir.RankDir::RL
    assert_eq(fixture.flip, expected_flip)
    match find_edge_by_nodes_with_label(
      graph,
      fixture.tail,
      fixture.head,
      fixture.label,
    ) {
      Some(_) => ()
      None =>
        fail(
          "missing labeled edge \{fixture.tail} -> \{fixture.head} '\{fixture.label}' for edge label vnode fixtures",
        )
    }
    let actual = edge_label_pos_from_vnode(
      @edge_spline.point(fixture.vnode_x, fixture.vnode_y),
      fixture.dimen_x,
      fixture.dimen_y,
      rankdir,
    )
    if actual.x != fixture.pos_x || actual.y != fixture.pos_y {
      fail(
        "edge label vnode pos mismatch (\{fixture.graph} \{fixture.tail}->\{fixture.head} '\{fixture.label}') got (\{actual.x},\{actual.y}) expected (\{fixture.pos_x},\{fixture.pos_y})",
      )
    }
  }
}

///|
test "flat edge label positions match Graphviz" {
  let fixtures = load_edge_label_flat_fixtures()
  guard fixtures.length() > 0 else { fail("missing flat edge label fixtures") }
  let graph = @dot_parser.parse_dot_file(
    "tests/layout/dot/flat_edge_label_adjacent.dot",
  )
  for fixture in fixtures {
    assert_eq(fixture.label_html, false)
    assert_eq(fixture.flip, false)
    assert_eq(fixture.graph, "flat_label_adjacent")
    assert_eq(fixture.place, 0)
    if fixture.label == "" {
      fail("empty flat edge label for \{fixture.tail} -> \{fixture.head}")
    }
    let edge = match find_edge_by_nodes(graph, fixture.tail, fixture.head) {
      Some(value) => value
      None =>
        fail(
          "missing edge \{fixture.tail} -> \{fixture.head} for flat label fixtures",
        )
    }
    let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
      Some(value) => value
      None => fail("missing label metrics for \{fixture.tail} -> \{fixture.head}")
    }
    assert_eq(metrics.width, fixture.dimen_x)
    assert_eq(metrics.height, fixture.dimen_y)
    let actual = flat_edge_label_pos_simple(
      @edge_spline.point(fixture.tp_x, fixture.tp_y),
      @edge_spline.point(fixture.hp_x, fixture.hp_y),
      fixture.tail_rw,
      fixture.head_lw,
      fixture.dimen_y,
      @node_geometry.EDGE_LABEL_FLAT_SPACE_PT,
    )
    if actual.x != fixture.pos_x || actual.y != fixture.pos_y {
      fail(
        "flat edge label pos mismatch (\{fixture.graph} \{fixture.tail}->\{fixture.head} '\{fixture.label}' place=\{fixture.place}) got (\{actual.x},\{actual.y}) expected (\{fixture.pos_x},\{fixture.pos_y})",
      )
    }
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
    assert_eq(
      fixture.dist,
      @node_geometry.PORT_LABEL_DISTANCE_PT * fixture.labeldistance,
    )
    let actual = port_label_pos_from_points(
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
    let (angle_deg, distance_scale) = match port_label_params(
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
