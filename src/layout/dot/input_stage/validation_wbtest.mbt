// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn assert_validate_layout_graph_error(
  source : String,
  needle : String,
) -> Unit raise {
  let graph = @dot_parser.parse_dot(source)
  match validate_layout_graph(graph) {
    Ok(_) => fail("expected layout validation error containing \{needle}")
    Err(message) =>
      if !message.contains(needle) {
        fail("expected error containing \{needle}, got: \{message}")
      }
  }
}

///|
fn assert_prepare_layout_prep_error(
  source : String,
  options : LayoutInputOptions,
  needle : String,
) -> Unit raise {
  let graph = @dot_parser.parse_dot(source)
  match prepare_layout_prep(graph, options) {
    Ok(_) => fail("expected layout prep error containing \{needle}")
    Err(message) =>
      if !message.contains(needle) {
        fail("expected error containing \{needle}, got: \{message}")
      }
  }
}

///|
test "validate_layout_graph rejects negative graph, node, and edge attrs" {
  let cases : Array[(String, String)] = [
    ("digraph { nodesep=-1; a; }", "nodesep"),
    ("digraph { ranksep=-1; a; }", "ranksep"),
    ("digraph { a [width=-1]; }", "width"),
    ("digraph { a [height=-1]; }", "height"),
    ("digraph { a -> b [minlen=-1]; }", "minlen"),
    ("digraph { a -> b [weight=-1]; }", "weight"),
  ]
  for entry in cases {
    let (source, needle) = entry
    assert_validate_layout_graph_error(source, needle)
  }
}

///|
test "prepare_layout_prep rejects negative spacing overrides" {
  let base_source = "digraph { a; }"
  let cases : Array[(LayoutInputOptions, String)] = [
    (
      { rankdir: None, nodesep: Some(-1.0), ranksep: None, splines: None },
      "nodesep must be non-negative",
    ),
    (
      { rankdir: None, nodesep: None, ranksep: Some(-1.0), splines: None },
      "ranksep must be non-negative",
    ),
  ]
  for entry in cases {
    let (options, needle) = entry
    assert_prepare_layout_prep_error(base_source, options, needle)
  }
}
