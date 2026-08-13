// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
  let graph = try
    @dot.parse_dot("graph G { { a; } label=\"root\"; fontsize=20; }")
  catch {
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
  let graph = try
    @dot.parse_dot("graph G { label=\"root\"; fontsize=20; { a; } }")
  catch {
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
  let graph = try
    @dot.parse_dot(
      "digraph { a [height=0.5, pos=\"1,2\", width=0.75, image=\"usershape.svg\"]; }",
    )
  catch {
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
  let graph = try
    @dot.parse_dot(
      "digraph { subgraph cluster_1 { 1; } subgraph cluster_2 { 1 } }",
    )
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let start = match output.find("subgraph cluster_2 {") {
    Some(value) => value
    None => fail("missing cluster_2: \{output}")
  }
  let tail = output.unsafe_substring(start~, end=output.length())
  let close = match tail.find("}") {
    Some(value) => value
    None => fail("unterminated cluster_2 block: \{output}")
  }
  let cluster_block = tail.unsafe_substring(start=0, end=close + 1)
  assert_true(!cluster_block.contains("1;"))
}
