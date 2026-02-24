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
test "write_dot omits implicit node label defaults" {
  let graph = try @dot.parse_dot("digraph { a }") catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  assert_true(!output.contains("label=\"\\N\""))
}

///|
test "write_dot preserves graph attr scope for earlier subgraphs" {
  let graph = try @dot.parse_dot(
    "graph G { { a; } label=\"root\"; fontsize=20; }",
  ) catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  assert_true(output.contains("graph [fontsize=\"\""))
  assert_true(output.contains("label=\"\""))
}

///|
test "write_dot skips graph attr resets for later subgraphs" {
  let graph = try @dot.parse_dot(
    "graph G { label=\"root\"; fontsize=20; { a; } }",
  ) catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  assert_true(!output.contains("graph [fontsize=\"\""))
  assert_true(!output.contains("graph [label=\"\""))
}

///|
test "write_dot keeps image before generated node geometry attrs" {
  let graph = try @dot.parse_dot(
    "digraph { a [height=0.5, pos=\"1,2\", width=0.75, image=\"usershape.svg\"]; }",
  ) catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let image_index = match output.find("image=\"usershape.svg\"") {
    Some(value) => value
    None => fail("missing image attr: \{output}")
  }
  let pos_index = match output.find("pos=\"1,2\"") {
    Some(value) => value
    None => fail("missing pos attr: \{output}")
  }
  let width_index = match output.find("width=0.75") {
    Some(value) => value
    None => fail("missing width attr: \{output}")
  }
  assert_true(image_index < pos_index)
  assert_true(image_index < width_index)
}

///|
test "parser keeps duplicate cluster node membership on first cluster only" {
  let graph = try @dot.parse_dot(
    "digraph { subgraph cluster_1 { 1; } subgraph cluster_2 { 1 } }",
  ) catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let start = match output.find("subgraph cluster_2 {") {
    Some(value) => value
    None => fail("missing cluster_2: \{output}")
  }
  let tail = output.unsafe_substring(start=start, end=output.length())
  let close = match tail.find("}") {
    Some(value) => value
    None => fail("unterminated cluster_2 block: \{output}")
  }
  let cluster_block = tail.unsafe_substring(start=0, end=close + 1)
  assert_true(!cluster_block.contains("1;"))
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

///|
test "write_dot_bytes keeps latin1 output bytes" {
  let graph = try @dot.parse_dot_file("refs/graphviz/graphs/directed/Latin1.gv") catch {
    err => fail("parse_dot_file failed: \{err}")
  } noraise {
    value => value
  }
  let bytes = @dot.write_dot_bytes(graph)
  let mut has_high_byte = false
  for b in bytes {
    if b.to_int() >= 0x80 {
      has_high_byte = true
      break
    }
  }
  assert_true(has_high_byte)
  let decoded : Result[String, Error] = try? @utf8.decode(bytes)
  guard decoded is Err(_) else {
    fail("expected latin1 byte stream")
  }
}

///|
test "write_dot_bytes keeps latin1 output bytes for non-utf8 input" {
  let graph = try @dot.parse_dot_file("refs/graphviz/tests/windows/Latin1.gv") catch {
    err => fail("parse_dot_file failed: \{err}")
  } noraise {
    value => value
  }
  let output = @dot.write_dot(graph)
  assert_true(!output.contains("_mbt_input_latin1_fallback"))
  let bytes = @dot.write_dot_bytes(graph)
  let mut has_high_byte = false
  for b in bytes {
    if b.to_int() >= 0x80 {
      has_high_byte = true
      break
    }
  }
  assert_true(has_high_byte)
  let decoded : Result[String, Error] = try? @utf8.decode(bytes)
  guard decoded is Err(_) else {
    fail("expected latin1 byte stream")
  }
}
