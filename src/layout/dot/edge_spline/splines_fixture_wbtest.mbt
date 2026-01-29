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
struct SplineInput {
  case_id : Int
  graph : String
  polyline : Bool
  tail : String
  head : String
  start : FixtureEndpoint
  end : FixtureEndpoint
  polygon : Array[FixturePoint]
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
    tail: @json.from_json(obj["tail"]),
    head: @json.from_json(obj["head"]),
    start: @json.from_json(obj["start"]),
    end: @json.from_json(obj["end"]),
    polygon: @json.from_json(obj["polygon"]),
  }
}

///|
fn parse_spline_points(obj : Map[String, Json]) -> (Int, Array[FixturePoint]) raise {
  let case_id : Int = @json.from_json(obj["case"])
  let points : Array[FixturePoint] = @json.from_json(obj["points"])
  (case_id, points)
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
        let (case_id, points) = parse_spline_points(obj)
        match pending_input {
          Some(input) => {
            if input.case_id != case_id {
              fail(
                "spline shortest case mismatch input=\{input.case_id} shortest=\{case_id}",
              )
            }
            pending_shortest = Some(points)
          }
          None => fail("spline_shortest without spline_input")
        }
      }
      "spline_output" => {
        let (case_id, points) = parse_spline_points(obj)
        match pending_input {
          Some(input) =>
            match pending_shortest {
              Some(shortest) => {
                if input.case_id != case_id {
                  fail(
                    "spline output case mismatch input=\{input.case_id} output=\{case_id}",
                  )
                }
                cases.push((input, shortest, points))
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
fn to_point(fixture : FixturePoint) -> @geom.Point {
  point(fixture.x, fixture.y)
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
fn polygon_edges(
  polygon : Array[@geom.Point],
) -> Array[(@geom.Point, @geom.Point)] {
  let edges : Array[(@geom.Point, @geom.Point)] = []
  if polygon.length() < 2 {
    return edges
  }
  for i in 0..<polygon.length() {
    let next = if i + 1 < polygon.length() { i + 1 } else { 0 }
    edges.push((polygon[i], polygon[next]))
  }
  edges
}

///|
fn endpoint_slope(endpoint : FixtureEndpoint, invert : Bool) -> @geom.Point {
  if !endpoint.constrained {
    return point(0.0, 0.0)
  }
  let x = libm_cos(endpoint.theta)
  let y = libm_sin(endpoint.theta)
  if invert {
    point(-x, -y)
  } else {
    point(x, y)
  }
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
fn run_spline_case(
  input : SplineInput,
  shortest_expected : Array[FixturePoint],
  output_expected : Array[FixturePoint],
) -> Unit raise {
  let _ = input.start.x
  let _ = input.start.y
  let _ = input.end.x
  let _ = input.end.y
  if input.polyline {
    fail(
      "case \{input.case_id} graph=\{input.graph} tail=\{input.tail} head=\{input.head} unexpected polyline input",
    )
  }
  let polygon = to_points(input.polygon)
  let route_barriers = polygon_edges(polygon)
  let shortest = to_points(shortest_expected)
  let start_dir = endpoint_slope(input.start, false)
  let end_dir = endpoint_slope(input.end, true)
  let output_actual =
    route_polyline_to_bezier(
      shortest,
      start_dir,
      end_dir,
      true,
      1.0,
      0.0,
      route_barriers=route_barriers,
    )
  assert_points_exact(
    input.case_id,
    input.graph,
    input.tail,
    input.head,
    "spline",
    output_actual,
    to_points(output_expected),
  )
}

///|
test "spline fixtures load" {
  let cases = load_spline_fixtures()
  assert_true(cases.length() > 0)
}

///|
test "spline fixtures match route spline output" {
  // Graphviz fixtures come from native libm; non-native math drifts slightly.
  if !LIBM_IS_NATIVE {
    return
  }
  let cases = load_spline_fixtures()
  for entry in cases {
    let (input, shortest, output) = entry
    run_spline_case(input, shortest, output)
  }
}
