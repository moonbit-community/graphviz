// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn concentrated_junction_slope(
  name : String,
  context : @precompute.RoutingContext,
) -> @geom.Point {
  let positions = context.merged_positions
  let center = positions[name]
  let incoming = context.path_adjacency.in_edges[name]
  let outgoing = context.path_adjacency.out_edges[name]
  let incoming_x = for sum = 0.0, index = 0 {
    guard index < incoming.length() else {
      break sum / incoming.length().to_double()
    }
    continue sum + positions[incoming[index]].x, index + 1
  }
  let outgoing_x = for sum = 0.0, index = 0 {
    guard index < outgoing.length() else {
      break sum / outgoing.length().to_double()
    }
    continue sum + positions[outgoing[index]].x, index + 1
  }
  let angle = (
      @math.atan2(center.y - positions[incoming[0]].y, center.x - incoming_x) +
      @math.atan2(positions[outgoing[0]].y - center.y, outgoing_x - center.x)
    ) /
    2.0
  { x: @math.cos(angle), y: @math.sin(angle), }
}

///|
fn concentrated_segment_base(
  base : EdgeRouteBase,
  segment : @precompute.ConcentratedSegment,
  input : RegularPassInput,
  virtual_graph : @cgraph.Graph,
) -> EdgeRouteBase {
  let context = input.routing_context
  let tail_virtual = @edge_identity.is_edge_vnode_name(segment.tail)
  let head_virtual = @edge_identity.is_edge_vnode_name(segment.head)
  let tail_pos = context.merged_positions[segment.tail]
  let head_pos = context.merged_positions[segment.head]
  let tail_size = context.pathplan_route_sizes[segment.tail]
  let head_size = context.pathplan_route_sizes[segment.head]
  let tail_anchor = if tail_virtual { tail_pos } else { base.tail_anchor }
  let head_anchor = if head_virtual { head_pos } else { base.head_anchor }
  {
    ..base,
    tail_name: segment.tail,
    head_name: segment.head,
    tail_node: if tail_virtual {
      virtual_graph.node(segment.tail)
    } else {
      base.tail_node
    },
    head_node: if head_virtual {
      virtual_graph.node(segment.head)
    } else {
      base.head_node
    },
    tail_pos,
    head_pos,
    tail_size,
    head_size,
    tail_anchor,
    head_anchor,
    tail_port: if tail_virtual {
      None
    } else {
      base.tail_port
    },
    head_port: if head_virtual {
      None
    } else {
      base.head_port
    },
    tail_port_side: if tail_virtual {
      0
    } else {
      base.tail_port_side
    },
    head_port_side: if head_virtual {
      0
    } else {
      base.head_port_side
    },
    tail_record_path_box: if tail_virtual {
      None
    } else {
      base.tail_record_path_box
    },
    head_record_path_box: if head_virtual {
      None
    } else {
      base.head_record_path_box
    },
    head_port_rect: if head_virtual {
      None
    } else {
      base.head_port_rect
    },
    tail_sameport_group_size: if tail_virtual {
      0
    } else {
      base.tail_sameport_group_size
    },
    head_sameport_group_size: if head_virtual {
      0
    } else {
      base.head_sameport_group_size
    },
    tail_clip_center: if tail_virtual {
      tail_pos
    } else {
      base.tail_clip_center
    },
    head_clip_center: if head_virtual {
      head_pos
    } else {
      base.head_clip_center
    },
    tail_clip_size: if tail_virtual {
      tail_size
    } else {
      base.tail_clip_size
    },
    head_clip_size: if head_virtual {
      head_size
    } else {
      base.head_clip_size
    },
    tail_clip_enabled: !tail_virtual && base.tail_clip_enabled,
    head_clip_enabled: !head_virtual && base.head_clip_enabled,
    tail_clip: if tail_virtual {
      tail_pos
    } else {
      base.tail_clip
    },
    head_clip: if head_virtual {
      head_pos
    } else {
      base.head_clip
    },
    tail_slope: if tail_virtual {
      concentrated_junction_slope(segment.tail, context)
    } else {
      base.tail_slope
    },
    head_slope: if head_virtual {
      concentrated_junction_slope(segment.head, context)
    } else {
      base.head_slope
    },
    tail_cluster_bbox: if tail_virtual {
      None
    } else {
      base.tail_cluster_bbox
    },
    head_cluster_bbox: if head_virtual {
      None
    } else {
      base.head_cluster_bbox
    },
    tail_rank: input.vnode_info.vnode_ranks
    .get(segment.tail)
    .unwrap_or(base.tail_rank),
    head_rank: input.vnode_info.vnode_ranks
    .get(segment.head)
    .unwrap_or(base.head_rank),
    vnodes: segment.vnodes,
    has_vnodes: segment.vnodes.length() > 0,
    use_pathplan: true,
    // arrow_clip suppresses junction flags before swapEnds, not after it.
    route_include_tail: base.route_include_tail &&
    !(if base.swap_ends { head_virtual } else { tail_virtual }),
    route_include_head: base.route_include_head &&
    !(if base.swap_ends { tail_virtual } else { head_virtual }),
  }
}

///|
priv struct ConcentratedPortClipState {
  mut tail_clip : Bool
  mut head_clip : Bool
}

///|
fn concentrated_install_base(
  base : EdgeRouteBase,
  segment_base : EdgeRouteBase,
  state : ConcentratedPortClipState,
) -> EdgeRouteBase {
  // beginpath/endpath disable clipping on the original endpoint as it is
  // visited. A later junction segment observes that mutation.
  let tail_virtual = @edge_identity.is_edge_vnode_name(segment_base.tail_name)
  let head_virtual = @edge_identity.is_edge_vnode_name(segment_base.head_name)
  if !tail_virtual && segment_base.tail_port_side != 0 {
    state.tail_clip = false
  }
  if !head_virtual && segment_base.head_port_side != 0 {
    state.head_clip = false
  }
  let swapped_ports = !base.swap_ends && tail_virtual
  let use_tail_box_at_head = swapped_ports &&
    base.tail_port is Some(_) &&
    @record_geometry.is_record_shape(base.tail_node)
  // clip_and_install tests tn == agtail(orig), not the direction of the
  // original edge. A virtual tail therefore selects the opposite port box.
  {
    ..segment_base,
    tail_clip_enabled: !tail_virtual && state.tail_clip,
    head_clip_enabled: !head_virtual &&
    (if swapped_ports { state.tail_clip } else { state.head_clip }),
    head_clip_center: if use_tail_box_at_head {
      {
        x: segment_base.head_pos.x + base.tail_clip_center.x - base.tail_pos.x,
        y: segment_base.head_pos.y + base.tail_clip_center.y - base.tail_pos.y,
      }
    } else {
      segment_base.head_clip_center
    },
    head_clip_size: if use_tail_box_at_head {
      base.tail_clip_size
    } else {
      segment_base.head_clip_size
    },
  }
}

///|
fn route_concentrated_segments(
  edge : @cgraph.Edge,
  segments : Array[@precompute.ConcentratedSegment],
  input : OrderedRoutingInput,
  state : OrderedEdgeRoutingState,
  callbacks : RoutingCallbacks,
) -> Unit {
  guard input.base_cache.get(edge.id()) is Some(base) else { return }
  let virtual_graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  let splines : Array[@geom.Spline] = []
  let clip_state = {
    tail_clip: base.tail_clip_enabled,
    head_clip: base.head_clip_enabled,
  }
  for segment in segments {
    let pass = input.regular_pass_input
    let segment_base = concentrated_segment_base(
      base, segment, pass, virtual_graph,
    )
    let edge_vnodes = pass.vnode_info.edge_vnodes.copy()
    edge_vnodes[@edge_identity.edge_vnode_key(edge)] = segment.vnodes
    let ranks = pass.ranks.copy()
    ranks[segment.tail] = segment_base.tail_rank
    ranks[segment.head] = segment_base.head_rank
    let segment_input = {
      ..pass,
      ranks,
      vnode_info: { ..pass.vnode_info, edge_vnodes, },
    }
    let install_base = concentrated_install_base(base, segment_base, clip_state)
    let layout = build_regular_spline_layout(
      {
        edge,
        base: segment_base,
        input: segment_input,
        path_left_bound: input.path_left_bound,
        path_right_bound: input.path_right_bound,
        recover_edge_id_by_key: {},
        recovered_slack_keys: {},
        callbacks,
      },
      install_base=Some(install_base),
    )
    for spline in layout.edge_layout.splines {
      splines.push(spline)
    }
  }
  state.edges_out_by_id[edge.id()] = {
    edge,
    // swap_spline reverses both the points of each Bezier (already handled
    // by emit) and the complete list of segments for a backward edge.
    splines: if base.swap_ends {
      splines.rev()
    } else {
      splines
    },
    label_pos: None,
    head_label_pos: None,
    tail_label_pos: None,
    xlabel_pos: None,
  }
}
