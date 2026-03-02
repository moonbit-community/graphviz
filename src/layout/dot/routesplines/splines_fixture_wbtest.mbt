///|
struct FixturePoint {
  x : Double
  y : Double
} derive(FromJson)

///|
struct FixtureEndpoint {
  x : Double
  y : Double
  theta : Double
  constrained : Bool
} derive(FromJson)

///|
struct FixtureBox {
  ll : FixturePoint
  ur : FixturePoint
} derive(FromJson)

///|
struct SplineInput {
  case_id : Int
  graph : String
  polyline : Bool
  flip : Bool
  tail : String
  head : String
  start : FixtureEndpoint
  end : FixtureEndpoint
  boxes : Array[FixtureBox]
  polygon : Array[FixturePoint]
}

///|
struct SplinePoints {
  case_id : Int
  points : Array[FixturePoint]
}

///|
fn require_object(json : Json) -> Map[String, Json] raise {
  match json {
    Json::Object(obj) => obj
    _ => fail("expected JSON object")
  }
}

///|
fn parse_spline_input(obj : Map[String, Json]) -> SplineInput raise {
  let graph = match obj.get("graph") {
    Some(value) => @json.from_json(value)
    None => ""
  }
  {
    case_id: @json.from_json(obj["case"]),
    graph,
    polyline: @json.from_json(obj["polyline"]),
    flip: @json.from_json(obj["flip"]),
    tail: @json.from_json(obj["tail"]),
    head: @json.from_json(obj["head"]),
    start: @json.from_json(obj["start"]),
    end: @json.from_json(obj["end"]),
    boxes: @json.from_json(obj["boxes"]),
    polygon: @json.from_json(obj["polygon"]),
  }
}

///|
fn parse_spline_points(obj : Map[String, Json]) -> SplinePoints raise {
  {
    case_id: @json.from_json(obj["case"]),
    points: @json.from_json(obj["points"]),
  }
}

///|
fn load_spline_fixtures(
) -> Array[(SplineInput, Array[FixturePoint], Array[FixturePoint])] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/splines.jsonl")
  let cases : Array[(SplineInput, Array[FixturePoint], Array[FixturePoint])] = []
  let mut pending_input : SplineInput? = None
  let mut pending_shortest : Array[FixturePoint]? = None
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line)
    let obj = require_object(json)
    let event : String = @json.from_json(obj["event"])
    match event {
      "spline_input" => {
        if pending_input is Some(_) {
          fail("unexpected spline_input while pending")
        }
        pending_input = Some(parse_spline_input(obj))
        pending_shortest = None
      }
      "spline_shortest" => {
        let parsed = parse_spline_points(obj)
        match pending_input {
          Some(input) => {
            if input.case_id != parsed.case_id {
              fail(
                "spline shortest case mismatch input=\{input.case_id} shortest=\{parsed.case_id}",
              )
            }
            pending_shortest = Some(parsed.points)
          }
          None => fail("spline_shortest without spline_input")
        }
      }
      "spline_output" => {
        let parsed = parse_spline_points(obj)
        match pending_input {
          Some(input) =>
            match pending_shortest {
              Some(shortest) => {
                if input.case_id != parsed.case_id {
                  fail(
                    "spline output case mismatch input=\{input.case_id} output=\{parsed.case_id}",
                  )
                }
                cases.push((input, shortest, parsed.points))
                pending_input = None
                pending_shortest = None
              }
              None => fail("spline_output without spline_shortest")
            }
          None => fail("spline_output without spline_input")
        }
      }
      _ => fail("unknown spline fixture event: \{event}")
    }
  }
  match pending_input {
    Some(_) => fail("missing spline_output for last case")
    None => ()
  }
  cases
}

///|
fn to_point(point : FixturePoint) -> @geom.Point {
  { x: point.x, y: point.y }
}

///|
fn to_points(points : Array[FixturePoint]) -> Array[@geom.Point] {
  let out : Array[@geom.Point] = []
  for point in points {
    out.push(to_point(point))
  }
  out
}

///|
fn to_rect(box : FixtureBox) -> @geom.Rect {
  { llx: box.ll.x, lly: box.ll.y, urx: box.ur.x, ury: box.ur.y }
}

///|
fn to_boxes(boxes : Array[FixtureBox]) -> Array[@geom.Rect] {
  let out : Array[@geom.Rect] = []
  for box in boxes {
    out.push(to_rect(box))
  }
  out
}

///|
fn assert_points_exact(
  case_id : Int,
  graph : String,
  tail : String,
  head : String,
  label : String,
  actual : Array[@geom.Point],
  expected : Array[@geom.Point],
) -> Unit raise {
  if actual.length() != expected.length() {
    fail(
      "case \{case_id} graph=\{graph} tail=\{tail} head=\{head} \{label} length mismatch actual=\{actual.length()} expected=\{expected.length()}",
    )
  }
  for i in 0..<expected.length() {
    let actual_point = actual[i]
    let expected_point = expected[i]
    if actual_point.x != expected_point.x || actual_point.y != expected_point.y {
      fail(
        "case \{case_id} graph=\{graph} tail=\{tail} head=\{head} \{label}[\{i}] expected=\{expected_point.x},\{expected_point.y} actual=\{actual_point.x},\{actual_point.y}",
      )
    }
  }
}

///|
fn compute_flip(boxes : Array[@geom.Rect]) -> Bool {
  boxes.length() > 1 && boxes[0].lly > boxes[1].lly
}

///|
fn run_spline_case(
  input : SplineInput,
  shortest_expected : Array[FixturePoint],
  _output_expected : Array[FixturePoint],
) -> Unit raise {
  let boxes = to_boxes(input.boxes)
  let polygon_expected = to_points(input.polygon)
  let _ = input.start.theta
  let _ = input.start.constrained
  let _ = input.end.theta
  let _ = input.end.constrained
  let flip_actual = compute_flip(boxes)
  if flip_actual != input.flip {
    fail(
      "case \{input.case_id} graph=\{input.graph} flip mismatch actual=\{flip_actual} expected=\{input.flip}",
    )
  }
  if input.polyline {
    fail(
      "case \{input.case_id} graph=\{input.graph} tail=\{input.tail} head=\{input.head} unexpected polyline input",
    )
  }
  let polygon_actual = boxes_to_polygon_points(boxes)
  assert_points_exact(
    input.case_id,
    input.graph,
    input.tail,
    input.head,
    "polygon",
    polygon_actual,
    polygon_expected,
  )
  let start : @geom.Point = { x: input.start.x, y: input.start.y }
  let end : @geom.Point = { x: input.end.x, y: input.end.y }
  let shortest_actual =
    @pathplan.shortest_path_in_poly(polygon_expected, start, end)
  assert_points_exact(
    input.case_id,
    input.graph,
    input.tail,
    input.head,
    "shortest",
    shortest_actual,
    to_points(shortest_expected),
  )
}

///|
test "spline fixtures load" {
  let cases = load_spline_fixtures()
  assert_true(cases.length() > 0)
}

///|
test "spline fixtures match pathplan outputs" {
  let cases = load_spline_fixtures()
  for entry in cases {
    let (input, shortest, output) = entry
    run_spline_case(input, shortest, output)
  }
}
