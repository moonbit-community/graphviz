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
test "xdot snapshot input path resolves representative local and Graphviz cases" {
  assert_eq(snapshot_input_path("complex"), "tests/layout/dot/complex.dot")
  assert_eq(snapshot_input_path("japanese"), "refs/graphviz/graphs/directed/japanese.gv")
}
