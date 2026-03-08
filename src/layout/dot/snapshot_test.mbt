///|
/// Keep the snapshot input candidate list in this file because
/// `check_snapshot_input_candidates.py` parses `snapshot_test.mbt` directly.

///|
fn snapshot_input_path(case_name : String) -> String raise {
  let candidates : Array[String] = [
    "refs/graphviz/graphs/directed/\{case_name}.gv",
    "refs/graphviz/graphs/undirected/\{case_name}.gv",
    "tests/layout/dot/\{case_name}.dot",
    "refs/graphviz/doc/dotguide/\{case_name}.dot",
    "refs/graphviz/doc/infosrc/\{case_name}.dot",
    "refs/graphviz/doc/infosrc/\{case_name}.gv",
    "refs/graphviz/doc/neato/\{case_name}.dot",
    "refs/graphviz/contrib/prune/\{case_name}.gv",
    "refs/graphviz/contrib/dirgraph/\{case_name}.dot",
    "refs/graphviz/contrib/java-dot/\{case_name}.dot",
    "refs/graphviz/tests/\{case_name}.dot",
    "refs/graphviz/tests/graphs/\{case_name}.gv",
    "refs/graphviz/tests/share/\{case_name}.gv",
    "refs/graphviz/tests/windows/\{case_name}.gv",
    "refs/graphviz/tests/regression_tests/\{case_name}.gv",
    "refs/graphviz/tests/regression_tests/shapes/reference/\{case_name}.gv",
    "refs/graphviz/tests/linux.x86/\{case_name}.gv",
    "refs/graphviz/tests/nshare/\{case_name}.gv",
    "refs/graphviz/tests/linux.i386/\{case_name}.gv",
    "refs/graphviz/tests/macosx/\{case_name}.gv",
  ]
  for path in candidates {
    if @fs.path_exists(path) {
      return path
    }
  }
  fail("missing snapshot input for case \{case_name}")
}

///|
test "compass ports on plain nodes clip away from node centers" {
  let graph = try @dot_parser.parse_dot(
    "digraph { foo:s -> bar:n [dir=both arrowhead=crow arrowtail=crow] }",
  ) catch {
    err => fail("parse failed: \{err}")
  } noraise {
    value => value
  }
  let layout = layout_dot(graph)
  layout.apply()
  let edges = graph.edges()
  assert_eq(edges.length(), 1)
  let pos = match edges[0].get_attr("pos") {
    Some(value) => value
    None => fail("missing edge pos")
  }
  let numbers = try extract_numbers(pos) catch {
    err => fail("extract_numbers failed: \{err}")
  } noraise {
    value => value
  }
  if numbers.length() < 4 {
    fail("unexpected pos attr: \{pos}")
  }
  let tail_y = numbers[1]
  let head_y = numbers[3]
  // Centers for default nodes are near y=90 and y=18; port clipping should
  // move anchors toward boundaries around y=72 and y=36.
  assert_true(tail_y < 80.0)
  assert_true(head_y > 30.0)
}

///|
test "dot layout tier2 snapshots" {
  if !full_parity_tests_enabled() {
    return
  }
  let cases = dot_snapshot_cases("tests/layout/dot/cases.txt", "tests/layout/dot")
  if cases.length() == 0 {
    fail("no dot fixtures under tests/layout/dot")
  }
  for pair in cases {
    let (input_path, expected_path) = pair
    assert_snapshot(input_path, expected_path, 0.01)
  }
}
