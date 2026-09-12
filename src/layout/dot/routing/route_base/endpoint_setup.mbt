// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn route_endpoint_neighbors(
  vnodes : Array[String],
  vnode_positions : Map[String, @geom.Point],
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
) -> (@geom.Point, @geom.Point) {
  guard vnodes.length() > 0 else { (head_pos, tail_pos) }
  (
    vnode_positions.get(vnodes[0]).unwrap_or(head_pos),
    vnode_positions.get(vnodes[vnodes.length() - 1]).unwrap_or(tail_pos),
  )
}

///|
/// Route endpoint setup owner: self-edge compass clip sizing, compass/dynamic
/// endpoint clip resolution, flat dir=both nudges, and related clip policy.

///|
fn adjusted_self_edge_compass_clip_size(
  self_edge : Bool,
  node : @cgraph.Node,
  port : @cgraph.Port?,
  size : NodeSize,
  is_record_shape : (@cgraph.Node) -> Bool,
) -> NodeSize {
  // Graphviz selfTop/selfBottom/selfRight/selfLeft route against ND_lw,
  // ND_rw, and ND_ht directly. Compass ports select the side but do not
  // shrink the node's clipping box.
  ignore(self_edge)
  ignore(node)
  ignore(port)
  ignore(is_record_shape)
  size
}

///|
priv struct CompassClipPointInput {
  node : @cgraph.Node
  port : @cgraph.Port?
  center : @geom.Point
  size : NodeSize
  rankdir : RankDir
}

///|
fn compass_clip_point_if_needed(input : CompassClipPointInput) -> @geom.Point? {
  guard input.port is Some(port) else { return None }
  guard port.compass is Some(compass) else { return None }
  guard compass != @cgraph.Compass::C else { return None }
  // record_port also calls compassPort: an explicit compass belongs to
  // the selected field box, including its corners, not a clipping ray.
  Some(
    @edge_spline.compass_port_point_on_shape(
      input.node,
      input.center,
      input.size,
      compass,
      input.rankdir,
    ),
  )
}

///|
fn slope_rankdir_for_endpoint(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  is_record_shape : (@cgraph.Node) -> Bool,
  layout_rankdir : RankDir,
  rankdir : RankDir,
) -> RankDir {
  match port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => layout_rankdir
        Some(_) => if is_record_shape(node) { layout_rankdir } else { rankdir }
        None => layout_rankdir
      }
    None => layout_rankdir
  }
}

///|
fn anchor_base_for_route_endpoint(
  sameport_anchor : @geom.Point?,
  dynamic_anchor : RouteDynamicPortAnchor,
  fallback_center : @geom.Point,
) -> @geom.Point {
  match sameport_anchor {
    Some(pos) => pos
    None =>
      match dynamic_anchor.anchor {
        Some(pos) => pos
        None => fallback_center
      }
  }
}

///|
priv struct RouteEndpointPortSideInput {
  node_name : String
  sameport_anchor : @geom.Point?
  dynamic_anchor : RouteDynamicPortAnchor
  anchor_base : @geom.Point
  port : @cgraph.Port?
  port_rect : @geom.Rect?
  pos : @geom.Point
  size : NodeSize
  port_side_mask_from_anchor : (@geom.Point, @geom.Point, NodeSize) -> Int
  port_side_for_edge : (
    String,
    @cgraph.Port?,
    @geom.Rect?,
    @geom.Point,
    NodeSize,
  ) -> Int
}

///|
fn port_side_for_route_endpoint(input : RouteEndpointPortSideInput) -> Int {
  if input.sameport_anchor is Some(_) {
    (input.port_side_mask_from_anchor)(input.anchor_base, input.pos, input.size)
  } else if input.dynamic_anchor.is_dynamic {
    input.dynamic_anchor.side
  } else {
    (input.port_side_for_edge)(
      input.node_name,
      input.port,
      input.port_rect,
      input.pos,
      input.size,
    )
  }
}

///|
fn compass_port_on_non_record_shape(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  is_record_shape : (@cgraph.Node) -> Bool,
) -> Bool {
  match port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => false
        Some(_) => !is_record_shape(node)
        None => false
      }
    None => false
  }
}

///|
priv struct RouteEndpointClipPointInput {
  anchor : @geom.Point
  opposite_anchor : @geom.Point
  cluster_bbox : @geom.Rect?
  dynamic_anchor : RouteDynamicPortAnchor
  compass_clip : @geom.Point?
  node : @cgraph.Node
  clip_center : @geom.Point
  clip_size : NodeSize
  clip_target : @geom.Point
}

///|
fn clip_point_for_route_endpoint(
  input : RouteEndpointClipPointInput,
) -> @geom.Point {
  match input.cluster_bbox {
    Some(rect) => clip_to_bbox(input.anchor, rect, input.opposite_anchor)
    None =>
      match input.dynamic_anchor.anchor {
        Some(pos) => pos
        None =>
          match input.compass_clip {
            Some(pos) => pos
            None =>
              clip_to_node_shape(
                input.node,
                input.clip_center,
                input.clip_size,
                input.clip_target,
              )
          }
      }
  }
}

///|
priv struct FlatBottomDirBothNudgeCheckInput {
  dir : @edge_semantics.EdgeDir
  is_flat_edge : Bool
  has_vnodes : Bool
  mid_label_width_pt : Double
  tail_sameport_anchor : @geom.Point?
  head_sameport_anchor : @geom.Point?
  tail_dynamic_anchor : RouteDynamicPortAnchor
  head_dynamic_anchor : RouteDynamicPortAnchor
  compass_tail_on_non_record : Bool
  compass_head_on_non_record : Bool
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_port_side : Int
  head_port_side : Int
  layout_rankdir : RankDir
}

///|
fn should_apply_flat_bottom_dirboth_x_nudge(
  input : FlatBottomDirBothNudgeCheckInput,
) -> Bool {
  match input.dir {
    @edge_semantics.EdgeDir::Both =>
      input.is_flat_edge &&
      !input.has_vnodes &&
      input.mid_label_width_pt <= 0.0 &&
      input.tail_sameport_anchor is None &&
      input.head_sameport_anchor is None &&
      input.tail_dynamic_anchor.anchor is None &&
      input.head_dynamic_anchor.anchor is None &&
      input.compass_tail_on_non_record &&
      input.compass_head_on_non_record &&
      @edge_identity.port_is_explicit(input.tail_port) &&
      @edge_identity.port_is_explicit(input.head_port) &&
      (input.tail_port_side & PORT_SIDE_BOTTOM) != 0 &&
      (input.head_port_side & PORT_SIDE_BOTTOM) != 0 &&
      (input.tail_port_side & PORT_SIDE_TOP) == 0 &&
      (input.head_port_side & PORT_SIDE_TOP) == 0 &&
      (
        input.layout_rankdir == RankDir::TB ||
        input.layout_rankdir == RankDir::BT
      )
    _ => false
  }
}
