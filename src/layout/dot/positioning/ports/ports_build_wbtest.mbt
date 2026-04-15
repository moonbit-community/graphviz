// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_port_offsets_with_callbacks uses fallback node size then rotates centers and swaps sizes in LR" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("rankdir", "LR")
  let node = graph.node("n")
  let missing_size_rankdir = Ref::new(@rankdir.RankDir::TB)
  let ports_rankdir = Ref::new(@rankdir.RankDir::TB)
  let observed_base_size = Ref::new(
    @node_primitives.node_size_from_points(0.0, 0.0),
  )
  let missing_size_calls = Ref::new(0)
  let ports_calls = Ref::new(0)

  let offsets = build_port_offsets_with_callbacks(
    [node],
    Map::new(),
    (_node, rankdir) => {
      missing_size_calls.val = missing_size_calls.val + 1
      missing_size_rankdir.val = rankdir
      @node_primitives.node_size_from_points(20.0, 10.0)
    },
    (_node, _origin, base_size, rankdir) => {
      ports_calls.val = ports_calls.val + 1
      ports_rankdir.val = rankdir
      observed_base_size.val = base_size
      {
        "p": {
          center: { x: base_size.width_pt, y: base_size.height_pt },
          size: @node_primitives.node_size_from_points(6.0, 8.0),
          sides: 3,
        },
      }
    },
    @port_geometry.layout_port_offset,
    @node_primitives.swap_node_size,
  )

  assert_eq(missing_size_calls.val, 1)
  assert_eq(ports_calls.val, 1)
  assert_eq(missing_size_rankdir.val, @rankdir.RankDir::LR)
  assert_eq(ports_rankdir.val, @rankdir.RankDir::LR)
  assert_eq(observed_base_size.val.width_pt, 20.0)
  assert_eq(observed_base_size.val.height_pt, 10.0)

  let node_offsets = match offsets.get("n") {
    Some(value) => value
    None => fail("expected node offsets")
  }
  let port = match node_offsets.get("p") {
    Some(value) => value
    None => fail("expected port offset")
  }

  assert_eq(port.center, { x: 10.0, y: -20.0 })
  assert_eq(port.size.width_pt, 8.0)
  assert_eq(port.size.height_pt, 6.0)
  assert_eq(port.sides, 3)
}

///|
test "port_side_mask_for_self_edge prefers compass and otherwise uses named port sides" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")

  let port_maps : Map[String, Map[String, @record_geometry.RecordPort]] = {
    "n": {
      "west": {
        center: { x: -5.0, y: 0.0 },
        size: @node_primitives.node_size_from_points(4.0, 4.0),
        sides: @port_geometry.PORT_SIDE_LEFT,
      },
    },
  }

  let named_only : @cgraph.Port = { name: Some("west"), compass: None }
  let named_with_compass : @cgraph.Port = {
    name: Some("west"),
    compass: Some(@cgraph.Compass::E),
  }
  let missing_named : @cgraph.Port = { name: Some("missing"), compass: None }

  assert_eq(
    port_side_mask_for_self_edge(node, Some(named_only), port_maps),
    @port_geometry.PORT_SIDE_LEFT,
  )
  assert_eq(
    port_side_mask_for_self_edge(node, Some(named_with_compass), port_maps),
    @port_geometry.PORT_SIDE_RIGHT,
  )
  assert_eq(
    port_side_mask_for_self_edge(node, Some(missing_named), port_maps),
    0,
  )
}
