///|
fn sample_endpoint_value(
  name : String,
  port : @cgraph.Port?,
  base : Double,
) -> Double {
  let name_value = match name {
    "a" => 10.0
    "b" => 20.0
    "c" => 30.0
    _ => 0.0
  }
  let port_value = match port {
    Some(value) => {
      let name_part = match value.name {
        Some(port_name) =>
          match port_name {
            "p" => 1.0
            "q" => 2.0
            "r" => 3.0
            _ => 0.0
          }
        None => 0.0
      }
      let compass_part = match value.compass {
        Some(@cgraph.Compass::E) => 0.1
        Some(@cgraph.Compass::W) => 0.2
        Some(@cgraph.Compass::S) => 0.3
        _ => 0.0
      }
      name_part + compass_part
    }
    None => 0.0
  }
  base + name_value + port_value
}

///|
test "build_edge_port_sample_bundle follows oriented endpoints and port remapping" {
  let graph = @dot_parser.parse_dot("digraph { a:p:e -> b:q:w; b:r:s -> c; }")
  let edges = graph.edges()
  let bundle = build_edge_port_sample_bundle(
    edges,
    ["a", "c"],
    ["b", "b"],
    (name, port) => sample_endpoint_value(name, port, 0.0),
    (name, port) => sample_endpoint_value(name, port, 100.0),
  )

  assert_eq(bundle.tail_port_x, [11.1, 30.0])
  assert_eq(bundle.head_port_x, [22.2, 23.3])
  assert_eq(bundle.tail_port_order, [111.1, 130.0])
  assert_eq(bundle.head_port_order, [122.2, 123.3])
}

///|
test "build_edge_port_sample_bundle returns empty arrays when there are no edges" {
  let bundle = build_edge_port_sample_bundle(
    [],
    [],
    [],
    (name, _port) => name.length().to_double(),
    (_name, _port) => 0.0,
  )

  assert_eq(bundle.tail_port_x, [])
  assert_eq(bundle.head_port_x, [])
  assert_eq(bundle.tail_port_order, [])
  assert_eq(bundle.head_port_order, [])
}
