// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "segment_slack_minlen splits positive and negative port deltas" {
  let tail_port = Some(
    make_constraint_builder_test_port("tail", @cgraph.Compass::E),
  )
  let head_port = Some(
    make_constraint_builder_test_port("head", @cgraph.Compass::W),
  )
  let offset_by_key : Map[String, Double] = Map::new()
  offset_by_key["a|tail:e"] = 3.0
  offset_by_key["b|head:w"] = 9.0
  offset_by_key["c|tail:e"] = 11.0
  offset_by_key["d|head:w"] = 7.0
  let edge_port_offset = (name : String, port : @cgraph.Port?) => {
    let key = "\{name}|\{@edge_identity.port_key(port)}"
    offset_by_key.get(key).unwrap_or_default()
  }

  let positive = segment_slack_minlen(
    { tail: "a", head: "b", weight: 1, tail_port, head_port },
    edge_port_offset,
  )
  let negative = segment_slack_minlen(
    { tail: "c", head: "d", weight: 1, tail_port, head_port },
    edge_port_offset,
  )

  assert_eq(positive, (6, 0))
  assert_eq(negative, (0, 4))
}
