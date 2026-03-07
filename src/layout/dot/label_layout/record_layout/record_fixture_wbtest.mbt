///|
struct RecordFixturePoint {
  x : Double
  y : Double
} derive(FromJson)

///|
struct RecordFixtureBox {
  llx : Double
  lly : Double
  urx : Double
  ury : Double
} derive(FromJson)

///|
struct RecordFixtureField {
  id : Json
  lr : Bool
  sides : Int
  size : RecordFixturePoint
  box : RecordFixtureBox
  fields : Array[RecordFixtureField]?
  text : Json?
} derive(FromJson)

///|
struct RecordFixture {
  node : String
  field : RecordFixtureField
} derive(FromJson)

///|
struct RecordComputedField {
  id : String?
  lr : Bool
  sides : Int
  size : RecordFixturePoint
  box : RecordFixtureBox
  fields : Array[RecordComputedField]
  text : String?
}

///|
const SIDE_TOP : Int = 1

///|
const SIDE_RIGHT : Int = 2

///|
const SIDE_BOTTOM : Int = 4

///|
const SIDE_LEFT : Int = 8

///|
const ALL_RECORD_SIDES : Int = SIDE_TOP | SIDE_RIGHT | SIDE_BOTTOM | SIDE_LEFT

///|
fn load_record_fixtures() -> Array[RecordFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/record.jsonl")
  let fixtures : Array[RecordFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line)
    let fixture : RecordFixture = @json.from_json(json)
    fixtures.push(fixture)
  }
  fixtures
}

///|
fn rect_to_box(rect : @geom.Rect) -> RecordFixtureBox {
  { llx: rect.llx, lly: rect.lly, urx: rect.urx, ury: rect.ury }
}

///|
fn rect_size(rect : @geom.Rect) -> RecordFixturePoint {
  { x: rect.urx - rect.llx, y: rect.ury - rect.lly }
}

///|
fn orientation_is_horizontal(orientation : RecordOrientation) -> Bool {
  match orientation {
    RecordOrientation::Horizontal => true
    RecordOrientation::Vertical => false
  }
}

///|
fn record_layout_field(
  node : RecordLayoutNode,
  orientation : RecordOrientation,
) -> RecordComputedField {
  match node.field {
    Some(field) =>
      {
        id: field.name,
        lr: true,
        sides: node.sides,
        size: rect_size(node.rect),
        box: rect_to_box(node.rect),
        fields: [],
        text: Some(field.text),
      }
    None => {
      let child_orientation = toggle_record_orientation(orientation)
      let children : Array[RecordComputedField] = []
      for child in node.children {
        children.push(record_layout_field(child, child_orientation))
      }
      {
        id: None,
        lr: orientation_is_horizontal(child_orientation),
        sides: node.sides,
        size: rect_size(node.rect),
        box: rect_to_box(node.rect),
        fields: children,
        text: None,
      }
    }
  }
}

///|
fn compute_record_tree(
  nodes : Array[RecordNode],
  rect : @geom.Rect,
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> RecordComputedField {
  let children = layout_record_tree(
    nodes,
    rect,
    orientation,
    font_name,
    font_size_pt,
    pad_x_pt,
    pad_y_pt,
    ALL_RECORD_SIDES,
  )
  let fields : Array[RecordComputedField] = []
  for child in children {
    fields.push(record_layout_field(child, orientation))
  }
  {
    id: None,
    lr: orientation_is_horizontal(orientation),
    sides: ALL_RECORD_SIDES,
    size: rect_size(rect),
    box: rect_to_box(rect),
    fields,
    text: None,
  }
}

///|
fn assert_point_eq(
  path : String,
  label : String,
  expected : RecordFixturePoint,
  actual : RecordFixturePoint,
) -> Unit raise {
  if expected.x != actual.x {
    fail("\{path} \{label} x expected \{expected.x} got \{actual.x}")
  }
  if expected.y != actual.y {
    fail("\{path} \{label} y expected \{expected.y} got \{actual.y}")
  }
}

///|
fn assert_box_eq(
  path : String,
  expected : RecordFixtureBox,
  actual : RecordFixtureBox,
) -> Unit raise {
  if expected.llx != actual.llx {
    fail("\{path} llx expected \{expected.llx} got \{actual.llx}")
  }
  if expected.lly != actual.lly {
    fail("\{path} lly expected \{expected.lly} got \{actual.lly}")
  }
  if expected.urx != actual.urx {
    fail("\{path} urx expected \{expected.urx} got \{actual.urx}")
  }
  if expected.ury != actual.ury {
    fail("\{path} ury expected \{expected.ury} got \{actual.ury}")
  }
}

///|
fn record_point_json(point : RecordFixturePoint) -> Json {
  let data : Map[String, Json] = {}
  data["x"] = Json::number(point.x)
  data["y"] = Json::number(point.y)
  Json::object(data)
}

///|
fn record_box_json(box : RecordFixtureBox) -> Json {
  let data : Map[String, Json] = {}
  data["llx"] = Json::number(box.llx)
  data["lly"] = Json::number(box.lly)
  data["urx"] = Json::number(box.urx)
  data["ury"] = Json::number(box.ury)
  Json::object(data)
}

///|
fn record_field_json(field : RecordComputedField) -> Json {
  let data : Map[String, Json] = {}
  data["id"] = match field.id {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  data["lr"] = Json::boolean(field.lr)
  data["sides"] = Json::number(field.sides.to_double())
  data["size"] = record_point_json(field.size)
  data["box"] = record_box_json(field.box)
  if field.fields.length() > 0 {
    let children : Array[Json] = []
    for child in field.fields {
      children.push(record_field_json(child))
    }
    data["fields"] = Json::array(children)
  } else {
    data["text"] = match field.text {
      Some(value) => Json::string(value)
      None => Json::null()
    }
  }
  Json::object(data)
}

///|
fn record_fixture_json(
  node : String,
  label : String,
  html : Bool,
  lr : Bool,
  flip : Bool,
  width_in : Double,
  height_in : Double,
  size_pt : RecordFixturePoint,
  field : RecordComputedField,
) -> Json {
  let data : Map[String, Json] = {}
  data["node"] = Json::string(node)
  data["label"] = Json::string(label)
  data["html"] = Json::boolean(html)
  data["lr"] = Json::boolean(lr)
  data["flip"] = Json::boolean(flip)
  data["width_in"] = Json::number(width_in)
  data["height_in"] = Json::number(height_in)
  data["size_pt"] = record_point_json(size_pt)
  data["field"] = record_field_json(field)
  Json::object(data)
}

///|
fn json_string_option(value : Json) -> String? raise {
  if value == Json::null() {
    None
  } else {
    Some(@json.from_json(value))
  }
}

///|
fn unescape_quotes(label : String) -> String {
  let sb = StringBuilder::new()
  let mut escaping = false
  for ch in label {
    if escaping {
      escaping = false
      if ch == '"' {
        sb.write_char('"')
      } else {
        sb.write_char('\\')
        sb.write_char(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    sb.write_char(ch)
  }
  if escaping {
    sb.write_char('\\')
  }
  sb.to_string()
}

///|
fn assert_field_eq(
  path : String,
  expected : RecordFixtureField,
  actual : RecordComputedField,
) -> Unit raise {
  let expected_id = json_string_option(expected.id)
  if expected_id != actual.id {
    fail("\{path} id expected \{expected_id} got \{actual.id}")
  }
  if expected.lr != actual.lr {
    fail("\{path} lr expected \{expected.lr} got \{actual.lr}")
  }
  if expected.sides != actual.sides {
    fail("\{path} sides expected \{expected.sides} got \{actual.sides}")
  }
  assert_point_eq(path, "size", expected.size, actual.size)
  assert_box_eq(path, expected.box, actual.box)
  match expected.fields {
    Some(children) => {
      if actual.text != None {
        fail("\{path} expected group text to be None")
      }
      if children.length() != actual.fields.length() {
        fail(
          "\{path} fields length expected \{children.length()} got \{actual.fields.length()}",
        )
      }
      for i in 0..<children.length() {
        let child_path = "\{path}.\{i}"
        assert_field_eq(child_path, children[i], actual.fields[i])
      }
    }
    None => {
      if actual.fields.length() != 0 {
        fail("\{path} expected no child fields")
      }
      let expected_text = match expected.text {
        Some(value) => json_string_option(value)
        None => None
      }
      if expected_text != actual.text {
        fail("\{path} text expected \{expected_text} got \{actual.text}")
      }
    }
  }
}

///|
test "record fixtures match Graphviz field geometry" {
  let dump_path = @sys.get_env_var("MBT_RECORD_FIXTURE_OUT")
  let fixtures = load_record_fixtures()
  let source = @fs.read_file_to_string("tests/layout/dot/complex.dot")
  let graph = @dot_parser.parse_dot(source)
  let record_orientation = @shared.record_layout_orientation(
    @rankdir.graph_rankdir(graph),
  )
  if dump_path is Some(out_path) {
    let output = StringBuilder::new()
    for fixture in fixtures {
      let node = graph.node(fixture.node)
      let label = unescape_quotes(@label_attrs.label_text(node))
      let expected_flip = orientation_is_horizontal(record_orientation)
      let size = @node_geometry.node_size(node, record_orientation)
      let record_size : RecordFixturePoint = {
        x: size.width_pt,
        y: size.height_pt - @record_geometry.RECORD_BORDER_PT * 2.0,
      }
      let rect : @geom.Rect = {
        llx: -record_size.x / 2.0,
        lly: -record_size.y / 2.0,
        urx: record_size.x / 2.0,
        ury: record_size.y / 2.0,
      }
      let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
      let font = @attrs.font_name(node.get_attr("fontname"))
      let padding = @label_attrs.node_padding(node)
      let computed = compute_record_tree(
        record_nodes(label),
        rect,
        record_orientation,
        font,
        font_size_pt,
        padding.pad_x_pt,
        padding.pad_y_pt,
      )
      let json = record_fixture_json(
        fixture.node,
        label,
        false,
        expected_flip,
        expected_flip,
        size.width_in,
        size.height_in,
        record_size,
        computed,
      )
      output.write_string(Json::stringify(json))
      output.write_char('\n')
    }
    @fs.write_string_to_file(out_path, output.to_string())
    return
  }
  for fixture in fixtures {
    let node = graph.node(fixture.node)
    let label = unescape_quotes(@label_attrs.label_text(node))
    let size = @node_geometry.node_size(node, record_orientation)
    let record_size : RecordFixturePoint = {
      x: size.width_pt,
      y: size.height_pt - @record_geometry.RECORD_BORDER_PT * 2.0,
    }
    let rect : @geom.Rect = {
      llx: -record_size.x / 2.0,
      lly: -record_size.y / 2.0,
      urx: record_size.x / 2.0,
      ury: record_size.y / 2.0,
    }
    let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
    let font = @attrs.font_name(node.get_attr("fontname"))
    let padding = @label_attrs.node_padding(node)
    let computed = compute_record_tree(
      record_nodes(label),
      rect,
      record_orientation,
      font,
      font_size_pt,
      padding.pad_x_pt,
      padding.pad_y_pt,
    )
    assert_field_eq(fixture.node, fixture.field, computed)
  }
}
