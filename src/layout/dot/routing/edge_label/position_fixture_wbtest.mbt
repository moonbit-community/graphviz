///|
struct EdgeLabelVnodeFixture {
  graph : String
  tail : String
  head : String
  label : String
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
  tp_x : Double
  tp_y : Double
  hp_x : Double
  hp_y : Double
  tail_rw : Double
  head_lw : Double
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
  labelangle : Double
  labeldistance : Double
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
      tp_x: @json.from_json(obj["tp_x"]),
      tp_y: @json.from_json(obj["tp_y"]),
      hp_x: @json.from_json(obj["hp_x"]),
      hp_y: @json.from_json(obj["hp_y"]),
      tail_rw: @json.from_json(obj["tail_rw"]),
      head_lw: @json.from_json(obj["head_lw"]),
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
      labelangle: @json.from_json(obj["labelangle"]),
      labeldistance: @json.from_json(obj["labeldistance"]),
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
test "edge label vnode positions match Graphviz" {
  let fixtures = load_edge_label_vnode_fixtures()
  guard fixtures.length() > 0 else { fail("missing edge label vnode fixtures") }
  for fixture in fixtures {
    let rankdir =
      if fixture.flip { @rankdir.RankDir::LR } else { @rankdir.RankDir::TB }
    let actual = edge_label_pos_from_vnode(
      @edge_spline.point(fixture.vnode_x, fixture.vnode_y),
      fixture.dimen_x,
      fixture.dimen_y,
      rankdir,
    )
    if actual.x != fixture.pos_x || actual.y != fixture.pos_y {
      fail(
        "edge label vnode pos mismatch (\{fixture.graph} \{fixture.tail}->\{fixture.head} '\{fixture.label}') got (\{actual.x}, \{actual.y}) expected (\{fixture.pos_x}, \{fixture.pos_y})",
      )
    }
  }
}

///|
test "flat edge label positions match Graphviz" {
  let fixtures = load_edge_label_flat_fixtures()
  guard fixtures.length() > 0 else { fail("missing flat edge label fixtures") }
  for fixture in fixtures {
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
        "flat edge label pos mismatch (\{fixture.graph} \{fixture.tail}->\{fixture.head} '\{fixture.label}') got (\{actual.x}, \{actual.y}) expected (\{fixture.pos_x}, \{fixture.pos_y})",
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
        "port label pos mismatch (\{fixture.graph} \{fixture.tail}->\{fixture.head} head=\{fixture.head_label} '\{fixture.label}') got (\{actual.x}, \{actual.y}) expected (\{fixture.pos_x}, \{fixture.pos_y})",
      )
    }
  }
}
