///|
fn roundtrip_file(path : String) -> Unit raise {
  let graph = try @dot.parse_dot_file(path) catch {
    err => fail("parse_dot_file failed: \{path} \{err}")
  } noraise {
    graph => graph
  }
  let out1 = @dot.write_dot(graph)
  let graph2 = try @dot.parse_dot(out1) catch {
    err => fail("parse_dot failed after write: \{path} \{err}")
  } noraise {
    graph => graph
  }
  let out2 = @dot.write_dot(graph2)
  assert_eq(out1, out2)
}

///|
test "dot roundtrip tier0" {
  let paths : Array[String] = [
    "refs/graphviz/doc/dotguide/graph1.dot", "refs/graphviz/doc/dotguide/graph2.dot",
    "refs/graphviz/graphs/directed/try.gv", "refs/graphviz/graphs/directed/tree.gv",
    "refs/graphviz/graphs/undirected/ER.gv",
  ]
  for path in paths {
    roundtrip_file(path)
  }
}

///|
test "dot roundtrip tier1" {
  let paths : Array[String] = [
    "refs/graphviz/graphs/directed/clust.gv", "refs/graphviz/graphs/directed/clust4.gv",
    "refs/graphviz/graphs/directed/records.gv", "refs/graphviz/graphs/directed/structs.gv",
    "refs/graphviz/graphs/directed/table.gv", "refs/graphviz/graphs/directed/arrows.gv",
    "refs/graphviz/graphs/directed/oldarrows.gv", "refs/graphviz/graphs/directed/polypoly.gv",
    "refs/graphviz/graphs/directed/trapeziumlr.gv", "refs/graphviz/graphs/directed/psfonttest.gv",
    "refs/graphviz/graphs/directed/Latin1.gv",
  ]
  for path in paths {
    roundtrip_file(path)
  }
}
