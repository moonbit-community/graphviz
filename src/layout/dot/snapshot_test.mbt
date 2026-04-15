// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
test "snapshot input path resolves representative local and Graphviz cases" {
  assert_eq(snapshot_input_path("complex"), "tests/layout/dot/complex.dot")
  assert_eq(
    snapshot_input_path("japanese"),
    "refs/graphviz/graphs/directed/japanese.gv",
  )
}

//|

///|
fn extract_numbers(value : String) -> Array[Double] raise {
  let sb = StringBuilder::new()
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
    } else {
      sb.write_char(' ')
    }
  }
  let normalized = sb.to_string()
  let numbers : Array[Double] = []
  for token in normalized.split(" ") {
    if token.length() == 0 {
      continue
    }
    let parsed = @string.parse_double(token)
    numbers.push(parsed)
  }
  numbers
}

///|
test "compass ports on plain nodes clip away from node centers" {
  let graph = try
    @dot_parser.parse_dot(
      "digraph { foo:s -> bar:n [dir=both arrowhead=crow arrowtail=crow] }",
    )
  catch {
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
