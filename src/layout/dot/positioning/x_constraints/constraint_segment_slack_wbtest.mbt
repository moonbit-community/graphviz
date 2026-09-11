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
  let offset_by_key : Map[String, Double] = Map([])
  offset_by_key["a|tail:e"] = 3.0
  offset_by_key["b|head:w"] = 9.0
  offset_by_key["c|tail:e"] = 11.0
  offset_by_key["d|head:w"] = 7.0
  let edge_port_offset = (name : String, port : @cgraph.Port?) => {
    let key = "\{name}|\{@edge_identity.port_key(port)}"
    offset_by_key.get(key).unwrap_or_default()
  }

  let positive = segment_slack_minlen(
    {
      tail: "a",
      head: "b",
      weight: 1,
      tail_port,
      head_port,
      concentrated_absorbed: false,
    },
    edge_port_offset,
  )
  let negative = segment_slack_minlen(
    {
      tail: "c",
      head: "d",
      weight: 1,
      tail_port,
      head_port,
      concentrated_absorbed: false,
    },
    edge_port_offset,
  )

  assert_eq(positive, (6, 0))
  assert_eq(negative, (0, 4))
}

///|
test "coalesce_concentrated_segments keeps one pair per retained live edge" {
  let virtual_a = "\{@edge_identity.EDGE_VNODE_PREFIX}a"
  let virtual_b = "\{@edge_identity.EDGE_VNODE_PREFIX}b"
  let segments_by_tail : Map[String, Array[SlackSegment]] = Map([])
  segments_by_tail["normal"] = [
    {
      tail: "normal",
      head: virtual_a,
      weight: 2,
      tail_port: None,
      head_port: None,
      concentrated_absorbed: true,
    },
    {
      tail: "normal",
      head: virtual_a,
      weight: 3,
      tail_port: None,
      head_port: None,
      concentrated_absorbed: false,
    },
  ]
  segments_by_tail[virtual_a] = [
    {
      tail: virtual_a,
      head: "normal_head",
      weight: 5,
      tail_port: None,
      head_port: None,
      concentrated_absorbed: false,
    },
    {
      tail: virtual_a,
      head: "normal_head",
      weight: 7,
      tail_port: None,
      head_port: None,
      concentrated_absorbed: true,
    },
    {
      tail: virtual_a,
      head: virtual_b,
      weight: 11,
      tail_port: None,
      head_port: None,
      concentrated_absorbed: true,
    },
    {
      tail: virtual_a,
      head: virtual_b,
      weight: 13,
      tail_port: None,
      head_port: None,
      concentrated_absorbed: true,
    },
  ]

  let coalesced = coalesce_concentrated_segments(segments_by_tail)
  let normal_segments = coalesced.get("normal").unwrap_or_default()
  let virtual_segments = coalesced.get(virtual_a).unwrap_or_default()

  assert_eq(normal_segments.length(), 1)
  assert_eq(normal_segments[0].weight, 5)
  assert_eq(virtual_segments.length(), 3)
  assert_eq(virtual_segments[0].weight, 12)
  assert_eq(virtual_segments[1].weight, 11)
  assert_eq(virtual_segments[2].weight, 13)
}
