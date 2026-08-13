// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
async fn roundtrip_file(path : String) -> Unit {
  let graph = try parse_dot_file(path) catch {
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
async test "dot roundtrip tier0" {
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
async test "dot roundtrip tier1" {
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
async test "write_dot_bytes keeps latin1 output bytes" {
  let graph = try
    parse_dot_file("refs/graphviz/graphs/directed/Latin1.gv")
  catch {
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
  try @utf8.decode(bytes) catch {
    _ => ()
  } noraise {
    _ => fail("expected latin1 byte stream")
  }
}

///|
async test "write_dot_bytes keeps latin1 output bytes for non-utf8 input" {
  let graph = try
    parse_dot_file("refs/graphviz/tests/windows/Latin1.gv")
  catch {
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
  try @utf8.decode(bytes) catch {
    _ => ()
  } noraise {
    _ => fail("expected latin1 byte stream")
  }
}
