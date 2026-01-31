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
fn load_edge_label_vnode_fixtures() -> Array[EdgeLabelVnodeFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/edge_label_pos.jsonl")
  let fixtures : Array[EdgeLabelVnodeFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let obj = require_object_local(@json.parse(line))
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
    let obj = require_object_local(@json.parse(line))
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
test "edge label vnode positions match Graphviz" {
  let fixtures = load_edge_label_vnode_fixtures()
  guard fixtures.length() > 0 else { fail("missing edge label vnode fixtures") }
  for fixture in fixtures {
    let rankdir = if fixture.flip { RankDir::LR } else { RankDir::TB }
    let actual = edge_label_pos_from_vnode(
      point(fixture.vnode_x, fixture.vnode_y),
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
  for fixture in fixtures {
    let actual = flat_edge_label_pos_simple(
      point(fixture.tp_x, fixture.tp_y),
      point(fixture.hp_x, fixture.hp_y),
      fixture.tail_rw,
      fixture.head_lw,
      fixture.dimen_y,
    )
    if actual.x != fixture.pos_x || actual.y != fixture.pos_y {
      fail(
        "flat edge label pos mismatch (\{fixture.graph} \{fixture.tail}->\{fixture.head} '\{fixture.label}' place=\{fixture.place}) got (\{actual.x},\{actual.y}) expected (\{fixture.pos_x},\{fixture.pos_y})",
      )
    }
  }
}
