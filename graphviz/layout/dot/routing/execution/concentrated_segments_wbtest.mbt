// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "junction installation observes original port clipping state and box ownership" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  a.set_attr("shape", "record")
  let edge = graph.edge(a, b)
  let base = {
    ..build_route_base(edge, tail_clip_enabled=true, head_clip_enabled=true),
    tail_port: Some({ name: Some("out"), compass: None, }),
    tail_clip_center: { x: 3.0, y: 2.0, },
    tail_port_side: 1,
    head_port_side: 1,
  }
  let junction = "_mbt_edge_vn_0_1"
  let incoming = { ..base, head_name: junction, }
  let outgoing = { ..base, tail_name: junction, }
  let state = { tail_clip: true, head_clip: true, }
  let first = concentrated_install_base(base, outgoing, state)
  @test.assert_eq(first.tail_clip_enabled, false)
  @test.assert_eq(first.head_clip_enabled, true)
  @test.assert_eq(first.head_clip_center, { x: 33.0, y: 2.0, })
  @test.assert_eq(first.head_clip_size.width_pt, base.tail_clip_size.width_pt)
  @test.assert_eq(first.head_clip_size.height_pt, base.tail_clip_size.height_pt)
  @test.assert_eq(state.tail_clip, true)
  @test.assert_eq(state.head_clip, false)
  let entered = concentrated_install_base(base, incoming, state)
  @test.assert_eq(entered.tail_clip_enabled, false)
  @test.assert_eq(entered.head_clip_enabled, false)
  let later = concentrated_install_base(base, outgoing, state)
  @test.assert_eq(later.head_clip_enabled, false)
}

///|
test "backward junction installation keeps the already oriented port box" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let base = { ..build_route_base(edge), swap_ends: true, }
  let segment = { ..base, tail_name: "_mbt_edge_vn_0_1", }
  let state = { tail_clip: false, head_clip: true, }
  let installed = concentrated_install_base(base, segment, state)
  @test.assert_eq(installed.head_clip_enabled, true)
  @test.assert_eq(installed.head_clip_center, base.head_clip_center)
}
