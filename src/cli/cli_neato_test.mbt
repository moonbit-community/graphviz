///|
fn parse_double(text : String, fallback : Double) -> Double {
  try @strconv.parse_double(text) catch {
    _ => fallback
  } noraise {
    value => value
  }
}

///|
fn parse_pos(text : String) -> (Double, Double) {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let x = if parts.length() > 0 { parse_double(parts[0], 0.0) } else { 0.0 }
  let y = if parts.length() > 1 { parse_double(parts[1], 0.0) } else { 0.0 }
  (x, y)
}

///|
fn node_pos(graph : @cgraph.Graph, name : String) -> (Double, Double)? {
  match graph.find_node(name) {
    Some(node) => match node.get_attr("pos") {
      Some(value) => Some(parse_pos(value))
      None => None
    }
    None => None
  }
}

test "cli neato -n preserves node positions" {
  ensure_dir("target")
  ensure_dir("target/cli")
  let input_path = "target/cli/neato_input.dot"
  write_input(
    input_path,
    "graph { a [pos=\"10,20!\", pin=true]; b [pos=\"30,40\"]; a -- b; }",
  )
  let output = run_cli(["-n", input_path], program="neato")
  let graph = @dot.parse_dot(output)
  let (ax, ay) = match node_pos(graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let (bx, by) = match node_pos(graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  assert_true(Double::is_close(ax, 10.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(ay, 20.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(bx, 30.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(by, 40.0, absolute_tolerance=0.01))
}

test "cli neato -x prunes isolated nodes" {
  ensure_dir("target")
  ensure_dir("target/cli")
  let input_path = "target/cli/neato_prune.dot"
  write_input(
    input_path,
    "graph { a [pos=\"0,0\"]; b [pos=\"10,0\"]; c [pos=\"5,8\"]; d [pos=\"100,100\"]; a -- b; b -- c; c -- a; }",
  )
  let output = run_cli(["-n", "-x", input_path], program="neato")
  let graph = @dot.parse_dot(output)
  match graph.find_node("d") {
    Some(_) => fail("expected node d to be pruned")
    None => ()
  }
  match graph.find_node("a") {
    Some(_) => ()
    None => fail("expected node a to remain")
  }
  match graph.find_node("b") {
    Some(_) => ()
    None => fail("expected node b to remain")
  }
  match graph.find_node("c") {
    Some(_) => ()
    None => fail("expected node c to remain")
  }
}
