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
