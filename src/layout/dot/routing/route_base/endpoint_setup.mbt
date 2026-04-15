// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
  if !self_edge || is_record_shape(node) {
    return size
  }
  match port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => size
        Some(compass) =>
          if sameport_shape_has_outline(node) {
            let penwidth = sameport_node_penwidth_pt(node)
            if penwidth > 0.0 {
              let pad = penwidth * 0.33055
              let width_pt = match compass {
                @cgraph.Compass::NE
                | @cgraph.Compass::NW
                | @cgraph.Compass::SE
                | @cgraph.Compass::SW =>
                  max_double(
                    size.width_pt - (size.height_pt / 3.0 + penwidth * 0.05),
                    size.height_pt,
                  )
                _ => size.width_pt
              }
              @node_primitives.node_size_from_points(
                width_pt,
                size.height_pt + pad * 2.0,
              )
            } else {
              size
            }
          } else {
            size
          }
        None => size
      }
    None => size
  }
}

///|
priv struct CompassClipPointInput {
  self_edge : Bool
  is_record_shape : (@cgraph.Node) -> Bool
  node : @cgraph.Node
  port : @cgraph.Port?
  center : @geom.Point
  size : NodeSize
  rankdir : RankDir
}

///|
fn compass_clip_point_if_needed(input : CompassClipPointInput) -> @geom.Point? {
  if input.self_edge || (input.is_record_shape)(input.node) {
    return None
  }
  match input.port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => None
        Some(compass) =>
          Some(
            @edge_spline.compass_port_point_on_shape(
              input.node,
              input.center,
              input.size,
              compass,
              input.rankdir,
            ),
          )
        None => None
      }
    None => None
  }
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
  sameport_anchor : @geom.Point?
  dynamic_anchor : RouteDynamicPortAnchor
  anchor_base : @geom.Point
  port : @cgraph.Port?
  port_rect : @geom.Rect?
  pos : @geom.Point
  size : NodeSize
  port_side_mask_from_anchor : (@geom.Point, @geom.Point, NodeSize) -> Int
  port_side_for_edge : (@cgraph.Port?, @geom.Rect?, @geom.Point, NodeSize) -> Int
}

///|
fn port_side_for_route_endpoint(input : RouteEndpointPortSideInput) -> Int {
  if input.sameport_anchor is Some(_) {
    (input.port_side_mask_from_anchor)(input.anchor_base, input.pos, input.size)
  } else if input.dynamic_anchor.is_dynamic {
    input.dynamic_anchor.side
  } else {
    (input.port_side_for_edge)(
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
priv struct ClusteredArrowLenOverrideInput {
  edge : @cgraph.Edge
  include_tail : Bool
  include_head : Bool
  tail_cluster_bbox : @geom.Rect?
  head_cluster_bbox : @geom.Rect?
  tail_clip : @geom.Point
  head_clip : @geom.Point
}

///|
fn clustered_edge_arrow_len_override(
  input : ClusteredArrowLenOverrideInput,
) -> Double? {
  if !(input.include_tail || input.include_head) {
    return None
  }
  if input.tail_cluster_bbox is None && input.head_cluster_bbox is None {
    return None
  }
  let arrow_lengths = @edge_spline.arrow_length_for_edge(
    input.edge,
    input.include_tail,
    input.include_head,
    None,
  )
  let base = if arrow_lengths.tail > arrow_lengths.head {
    arrow_lengths.tail
  } else {
    arrow_lengths.head
  }
  let span = @edge_spline.point_dist(input.tail_clip, input.head_clip)
  let max_len = if span < 12.0 { span * 0.25 } else { span }
  if max_len > 0.0 && max_len < base {
    Some(max_len)
  } else {
    None
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
