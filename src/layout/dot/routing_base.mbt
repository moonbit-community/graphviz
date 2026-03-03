///|
fn point_for_name_or_origin(
  positions : Map[String, @geom.Point],
  name : String,
) -> @geom.Point {
  match positions.get(name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
}

///|
fn size_for_name_or_node(
  sizes : Map[String, NodeSize],
  name : String,
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  match sizes.get(name) {
    Some(value) => value
    None => node_size(node, record_orientation)
  }
}

///|
fn cluster_bbox_if_named(
  cluster_bboxes : Map[String, @geom.Rect],
  cluster_name : String,
) -> @geom.Rect? {
  if cluster_name == "" {
    None
  } else {
    cluster_bboxes.get(cluster_name)
  }
}

///|
fn edge_include_arrowheads(
  dir : EdgeDir,
) -> (Bool, Bool) {
  let include_tail = match dir {
    EdgeDir::Back | EdgeDir::Both => true
    _ => false
  }
  let include_head = match dir {
    EdgeDir::Forward | EdgeDir::Both => true
    _ => false
  }
  (include_tail, include_head)
}

///|
fn route_include_arrowheads(
  include_tail : Bool,
  include_head : Bool,
  swap_ends : Bool,
) -> (Bool, Bool) {
  if swap_ends { (include_head, include_tail) } else { (include_tail, include_head) }
}

///|
/// Graphviz parity: edge endpoint/port setup aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_route_base(
  graph_kind : @cgraph.GraphKind,
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  routing_context : RoutingContext,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  enable_complex_tuning : Bool,
  edge_vnodes : Map[String, Array[String]],
  sameport_overrides : SameportOverrides,
) -> @routing.EdgeRouteBase {
  let order_index = routing_context.order_index
  let parallel_offsets = routing_context.parallel_offsets
  let cluster_bboxes = routing_context.cluster_bboxes
  let orig_tail_name = edge.tail().name()
  let orig_head_name = edge.head().name()
  let swap_ends =
    edge_swap_ends_for_route_base(
      edge,
      orig_tail_name,
      orig_head_name,
      ranks,
      order_index,
    )
  let sameport_info =
    edge_sameport_orientation_info(
      edge.id(),
      sameport_overrides,
      swap_ends,
    )
  let parallel_offset = parallel_offsets.get(edge.id()).unwrap_or_default()
  let oriented_endpoints = oriented_edge_endpoints_for_route(edge, swap_ends)
  let tail_name = oriented_endpoints.tail_name
  let head_name = oriented_endpoints.head_name
  let tail_port = oriented_endpoints.tail_port
  let head_port = oriented_endpoints.head_port
  let tail_node = oriented_endpoints.tail_node
  let head_node = oriented_endpoints.head_node
  let tail_sameport_anchor = sameport_info.tail_anchor
  let head_sameport_anchor = sameport_info.head_anchor
  let tail_sameport_group_size = sameport_info.tail_group_size
  let head_sameport_group_size = sameport_info.head_group_size
  let tail_pos = point_for_name_or_origin(positions, tail_name)
  let head_pos = point_for_name_or_origin(positions, head_name)
  let tail_size =
    size_for_name_or_node(
      sizes,
      tail_name,
      tail_node,
      record_orientation,
    )
  let head_size =
    size_for_name_or_node(
      sizes,
      head_name,
      head_node,
      record_orientation,
    )
  let tail_geometry = port_geometry(
    tail_name,
    tail_port,
    label_ports_map,
    tail_pos,
    tail_size,
  )
  let head_geometry = port_geometry(
    head_name,
    head_port,
    label_ports_map,
    head_pos,
    head_size,
  )
  let tail_port_rect = port_rect_from_geometry(
    tail_port,
    tail_geometry.center,
    tail_geometry.size,
    tail_size,
  )
  let head_port_rect = port_rect_from_geometry(
    head_port,
    head_geometry.center,
    head_geometry.size,
    head_size,
  )
  let tail_port_sides = match tail_port_rect {
    Some(rect) => @edge_spline.port_side_count(rect, tail_pos, tail_size)
    None => 0
  }
  let head_port_sides = match head_port_rect {
    Some(rect) => @edge_spline.port_side_count(rect, head_pos, head_size)
    None => 0
  }
  let tail_label_port = port_is_label_port(tail_name, tail_port, label_ports_raw)
  let head_label_port = port_is_label_port(head_name, head_port, label_ports_raw)
  // Graphviz parity: label ports should not force segmented edge splines.
  let force_segmented_base =
    (!tail_label_port && tail_port_sides >= 3) ||
    (!head_label_port && head_port_sides >= 3)
  let tail_cluster_name = match edge.get_attr("ltail") {
    Some(value) => value
    None => ""
  }
  let head_cluster_name = match edge.get_attr("lhead") {
    Some(value) => value
    None => ""
  }
  let tail_record_border_adjust =
    if is_record_shape(tail_node) &&
      !@html_label.is_html_label_text(label_text(tail_node)) {
      @dot_shared.RECORD_BORDER_PT
    } else {
      0.0
    }
  let head_record_border_adjust =
    if is_record_shape(head_node) &&
      !@html_label.is_html_label_text(label_text(head_node)) {
      @dot_shared.RECORD_BORDER_PT
    } else {
      0.0
    }
  let tail_rank = ranks.get(tail_name).unwrap_or_default()
  let head_rank = ranks.get(head_name).unwrap_or_default()
  let is_flat_edge = tail_rank == head_rank
  let is_flat_adjacent =
    if is_flat_edge {
      let tail_order = order_index.get(orig_tail_name).unwrap_or_default()
      let head_order = order_index.get(orig_head_name).unwrap_or_default()
      let delta = tail_order - head_order
      delta == 1 || delta == -1
    } else {
      false
    }
  let has_cluster = tail_cluster_name != "" || head_cluster_name != ""
  let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  let has_vnodes = vnodes.length() > 0
  let force_segmented =
    force_segmented_base ||
    (is_flat_edge && has_vnodes && edge_mid_label_width_pt(edge) > 0.0)
  let use_pathplan = match @sys.get_env_var("DOT_USE_PATHPLAN") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => true
  }
  let allow_offset =
    !is_flat_edge &&
    !has_cluster &&
    !@dot_shared.port_is_explicit(tail_port) &&
    !@dot_shared.port_is_explicit(head_port) &&
    !use_pathplan
  let (tail_offset, head_offset) = if allow_offset {
    (
      layout_port_offset(@edge_spline.point(0.0, -1.0), layout_rankdir),
      layout_port_offset(@edge_spline.point(0.0, 1.0), layout_rankdir),
    )
  } else {
    (@edge_spline.point(0.0, 0.0), @edge_spline.point(0.0, 0.0))
  }
  let tail_cluster_bbox = cluster_bbox_if_named(cluster_bboxes, tail_cluster_name)
  let head_cluster_bbox = cluster_bbox_if_named(cluster_bboxes, head_cluster_name)
  let tail_dynamic_anchor =
    dynamic_port_anchor_for_edge(
      tail_port,
      tail_name,
      label_ports_raw,
      tail_pos,
      head_pos,
      rankdir,
      tail_record_border_adjust,
    )
  let head_dynamic_anchor =
    dynamic_port_anchor_for_edge(
      head_port,
      head_name,
      label_ports_raw,
      head_pos,
      tail_pos,
      rankdir,
      head_record_border_adjust,
    )
  let has_side_anchor =
    tail_dynamic_anchor.anchor is Some(_) ||
      head_dynamic_anchor.anchor is Some(_) ||
      tail_sameport_anchor is Some(_) ||
      head_sameport_anchor is Some(_)
  let tail_anchor_base = match tail_sameport_anchor {
    Some(pos) => pos
    None =>
      match tail_dynamic_anchor.anchor {
        Some(pos) => pos
        None => tail_geometry.center
      }
  }
  let head_anchor_base = match head_sameport_anchor {
    Some(pos) => pos
    None =>
      match head_dynamic_anchor.anchor {
        Some(pos) => pos
        None => head_geometry.center
      }
  }
  let tail_port_side =
    if tail_sameport_anchor is Some(_) {
    port_side_mask_from_anchor(tail_anchor_base, tail_pos, tail_size)
  } else if tail_dynamic_anchor.is_dynamic {
    tail_dynamic_anchor.side
  } else {
    port_side_for_edge(
      tail_port,
      tail_port_rect,
      tail_pos,
      tail_size,
      None,
    )
  }
  let head_port_side =
    if head_sameport_anchor is Some(_) {
    port_side_mask_from_anchor(head_anchor_base, head_pos, head_size)
  } else if head_dynamic_anchor.is_dynamic {
    head_dynamic_anchor.side
  } else {
    port_side_for_edge(
      head_port,
      head_port_rect,
      head_pos,
      head_size,
      None,
    )
  }
  let tail_anchor0 = @edge_spline.point_add(tail_anchor_base, tail_offset)
  let head_anchor0 = @edge_spline.point_add(head_anchor_base, head_offset)
  let self_edge = orig_tail_name == orig_head_name
  let adjust_self_edge_compass_clip_size =
    (node : @cgraph.Node, port : @cgraph.Port?, size : NodeSize) => {
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
                  let width_pt =
                    match compass {
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
                  @dot_shared.node_size_from_points(
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
  let tail_clip_center = tail_geometry.center
  let tail_clip_size =
    adjust_self_edge_compass_clip_size(
      tail_node,
      tail_port,
      tail_geometry.size,
    )
  let head_clip_center = head_geometry.center
  let head_clip_size =
    adjust_self_edge_compass_clip_size(
      head_node,
      head_port,
      head_geometry.size,
    )
  let resolve_compass_clip_point :
    (@cgraph.Node, @cgraph.Port?, @geom.Point, NodeSize) -> @geom.Point? =
    (node, port, center, size) => {
      if self_edge || is_record_shape(node) {
        return None
      }
      match port {
        Some(value) =>
          match value.compass {
            Some(@cgraph.Compass::C) => None
            Some(compass) =>
              Some(
                @edge_spline.compass_port_point_on_shape(
                  node,
                  center,
                  size,
                  compass,
                  rankdir,
                ),
              )
            None => None
          }
        None => None
      }
    }
  let tail_compass_clip =
    resolve_compass_clip_point(
      tail_node,
      tail_port,
      tail_clip_center,
      tail_clip_size,
    )
  let head_compass_clip =
    resolve_compass_clip_point(
      head_node,
      head_port,
      head_clip_center,
      head_clip_size,
    )
  let tail_clip_enabled = tail_sameport_anchor is None
  let head_clip_enabled = head_sameport_anchor is None
  let tail_target = match tail_port_rect {
    Some(_) => head_pos
    None => tail_anchor0
  }
  let head_target = match head_port_rect {
    Some(_) => tail_pos
    None => head_anchor0
  }
  let slope_rankdir_for_endpoint =
    (node : @cgraph.Node, port : @cgraph.Port?) => {
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
  let tail_slope_rankdir = slope_rankdir_for_endpoint(tail_node, tail_port)
  let head_slope_rankdir = slope_rankdir_for_endpoint(head_node, head_port)
  let tail_slope = @edge_spline.endpoint_slope_for_anchor(
    tail_port,
    tail_port_side,
    tail_anchor0,
    tail_pos,
    tail_size,
    tail_target,
    tail_slope_rankdir,
    true,
    tail_port_rect,
  )
  let head_slope = @edge_spline.endpoint_slope_for_anchor(
    head_port,
    head_port_side,
    head_anchor0,
    head_pos,
    head_size,
    head_target,
    head_slope_rankdir,
    false,
    head_port_rect,
  )
  let tail_clip_target =
    if tail_sameport_anchor is Some(_) {
      tail_anchor0
    } else if @dot_shared.port_is_explicit(tail_port) &&
      (tail_slope.x != 0.0 || tail_slope.y != 0.0) {
      @edge_spline.point_add(tail_clip_center, tail_slope)
    } else {
      head_anchor0
    }
  let head_clip_target =
    if head_sameport_anchor is Some(_) {
      head_anchor0
    } else if @dot_shared.port_is_explicit(head_port) &&
      (head_slope.x != 0.0 || head_slope.y != 0.0) {
      @edge_spline.point_sub(head_clip_center, head_slope)
    } else {
      tail_anchor0
    }
  let mut tail_clip = match tail_cluster_bbox {
    Some(rect) => clip_to_bbox(tail_anchor0, rect, head_anchor0)
    None =>
      match tail_dynamic_anchor.anchor {
        Some(pos) => pos
        None =>
          match tail_compass_clip {
            Some(pos) => pos
            None =>
              clip_to_node_shape(
                tail_node,
                tail_clip_center,
                tail_clip_size,
                tail_clip_target,
              )
          }
      }
  }
  let mut head_clip = match head_cluster_bbox {
    Some(rect) => clip_to_bbox(head_anchor0, rect, tail_anchor0)
    None =>
      match head_dynamic_anchor.anchor {
        Some(pos) => pos
        None =>
          match head_compass_clip {
            Some(pos) => pos
            None =>
              clip_to_node_shape(
                head_node,
                head_clip_center,
                head_clip_size,
                head_clip_target,
              )
          }
      }
  }
  let compass_tail_on_non_record = match tail_port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => false
        Some(_) => !is_record_shape(tail_node)
        None => false
      }
    None => false
  }
  let compass_head_on_non_record = match head_port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => false
        Some(_) => !is_record_shape(head_node)
        None => false
      }
    None => false
  }
  let flat_bottom_dirboth_x_nudge =
    match edge_dir_for(edge, graph_kind) {
      EdgeDir::Both =>
        is_flat_edge &&
        !has_vnodes &&
        edge_mid_label_width_pt(edge) <= 0.0 &&
        tail_sameport_anchor is None &&
        head_sameport_anchor is None &&
        tail_dynamic_anchor.anchor is None &&
        head_dynamic_anchor.anchor is None &&
        compass_tail_on_non_record &&
        compass_head_on_non_record &&
        @dot_shared.port_is_explicit(tail_port) &&
        @dot_shared.port_is_explicit(head_port) &&
        (tail_port_side & PORT_SIDE_BOTTOM) != 0 &&
        (head_port_side & PORT_SIDE_BOTTOM) != 0 &&
        (tail_port_side & PORT_SIDE_TOP) == 0 &&
        (head_port_side & PORT_SIDE_TOP) == 0 &&
        (layout_rankdir == RankDir::TB || layout_rankdir == RankDir::BT)
      _ => false
    }
  if flat_bottom_dirboth_x_nudge {
    let delta =
      max_double(
        sameport_node_penwidth_pt(tail_node),
        sameport_node_penwidth_pt(head_node),
      )
    if delta != 0.0 {
      let x_dir = if head_anchor0.x >= tail_anchor0.x { 1.0 } else { -1.0 }
      tail_clip = @edge_spline.point(tail_clip.x + x_dir * delta, tail_clip.y)
      head_clip = @edge_spline.point(head_clip.x + x_dir * delta, head_clip.y)
    }
  }
  let tail_anchor =
    if tail_sameport_anchor is None && tail_dynamic_anchor.anchor is None &&
      compass_tail_on_non_record {
      tail_clip
    } else {
      tail_anchor0
    }
  let head_anchor =
    if head_sameport_anchor is None && head_dynamic_anchor.anchor is None &&
      compass_head_on_non_record {
      head_clip
    } else {
      head_anchor0
    }
  let out_tail_anchor = if swap_ends { head_anchor } else { tail_anchor }
  let out_head_anchor = if swap_ends { tail_anchor } else { head_anchor }
  let out_tail_clip = if swap_ends { head_clip } else { tail_clip }
  let out_head_clip = if swap_ends { tail_clip } else { head_clip }
  let out_tail_pos = point_for_name_or_origin(positions, orig_tail_name)
  let out_head_pos = point_for_name_or_origin(positions, orig_head_name)
  let out_tail_size =
    size_for_name_or_node(
      sizes,
      orig_tail_name,
      edge.tail(),
      record_orientation,
    )
  let out_head_size =
    size_for_name_or_node(
      sizes,
      orig_head_name,
      edge.head(),
      record_orientation,
    )
  let dir = edge_dir_for(edge, graph_kind)
  let (include_tail, include_head) = edge_include_arrowheads(dir)
  let (route_include_tail, route_include_head) =
    route_include_arrowheads(
      include_tail,
      include_head,
      swap_ends,
    )
  let arrow_len_override : Double? =
    if include_tail || include_head {
    if tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_) {
      let arrow_lengths =
        @edge_spline.arrow_length_for_edge(edge, include_tail, include_head, None)
      let base =
        if arrow_lengths.tail > arrow_lengths.head {
          arrow_lengths.tail
        } else {
          arrow_lengths.head
        }
      let span = @edge_spline.point_dist(tail_clip, head_clip)
      let max_len = if span < 12.0 { span * 0.25 } else { span }
      if max_len > 0.0 && max_len < base {
        Some(max_len)
      } else {
        None
      }
    } else {
      None
    }
  } else {
    None
  }
  let style_value = if enable_complex_tuning {
    match edge.get_attr("style") {
      Some(value) => value.to_lower()
      None => ""
    }
  } else {
    ""
  }
  let is_dotted = enable_complex_tuning && style_value.contains("dotted")
  let same_outer_cluster =
    node_cluster_key(tail_node) == node_cluster_key(head_node)
  let diff_local_cluster =
    node_local_cluster_key(tail_node) != node_local_cluster_key(head_node)
  let same_local_cluster = !diff_local_cluster
  {
    edge,
    parallel_offset,
    swap_ends,
    orig_tail_name,
    orig_head_name,
    tail_name,
    head_name,
    tail_port,
    head_port,
    tail_node,
    head_node,
    tail_pos,
    head_pos,
    tail_size,
    head_size,
    tail_anchor,
    head_anchor,
    head_port_rect,
    tail_port_side,
    head_port_side,
    tail_sameport_group_size,
    head_sameport_group_size,
    tail_clip_center,
    tail_clip_size,
    head_clip_center,
    head_clip_size,
    tail_clip_enabled,
    head_clip_enabled,
    tail_clip,
    head_clip,
    tail_slope,
    head_slope,
    force_segmented,
    tail_cluster_bbox,
    head_cluster_bbox,
    tail_rank,
    head_rank,
    is_flat_edge,
    is_flat_adjacent,
    vnodes,
    has_vnodes,
    use_pathplan,
    route_include_tail,
    route_include_head,
    arrow_len_override,
    is_dotted,
    same_outer_cluster,
    diff_local_cluster,
    same_local_cluster,
    out_tail_anchor,
    out_head_anchor,
    out_tail_clip,
    out_head_clip,
    out_tail_pos,
    out_head_pos,
    out_tail_size,
    out_head_size,
    rankdir,
    layout_rankdir,
    has_side_anchor,
  }
}
