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
  routing_context : @routing.RoutingContext,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  enable_complex_tuning : Bool,
  edge_vnodes : Map[String, Array[String]],
  sameport_overrides : SameportOverrides,
) -> EdgeRouteBase {
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
  let mid_label_width_pt = edge_mid_label_width_pt(edge)
  let mid_label_height_pt = match edge_mid_label_metrics(edge) {
    Some(metrics) => metrics.height
    None => 0.0
  }
  let tail_record_path_box =
    record_port_path_box(
      tail_node,
      tail_port,
      tail_pos,
      tail_size,
      rankdir,
    )
  let head_record_path_box =
    record_port_path_box(
      head_node,
      head_port,
      head_pos,
      head_size,
      rankdir,
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
    (is_flat_edge && has_vnodes && mid_label_width_pt > 0.0)
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
        mid_label_width_pt <= 0.0 &&
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
    mid_label_width_pt,
    mid_label_height_pt,
    tail_record_path_box,
    head_record_path_box,
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
///|
/// Graphviz parity: samehead/sametail group collection aligned to
/// refs/graphviz/lib/dotgen/sameport.c (dot_sameports/sameedge).
/// Do not change behavior without updating fixtures/tests.
fn add_sameport_group_edge(
  groups : Map[String, Array[@cgraph.Edge]],
  group_order : Array[String],
  key : String,
  edge : @cgraph.Edge,
) -> Unit {
  match groups.get(key) {
    Some(list) => list.push(edge)
    None => {
      groups[key] = [edge]
      group_order.push(key)
    }
  }
}

///|
fn sameport_merge_key(edge : @cgraph.Edge) -> String {
  let label = match edge.get_attr("label") {
    Some(value) => value
    None => ""
  }
  "\{edge.tail().name()}|\{edge.head().name()}|\{label}|\{@dot_shared.port_key(edge.tail_port())}|\{@dot_shared.port_key(edge.head_port())}"
}

///|
fn collect_sameport_classes(
  edges : Array[@cgraph.Edge],
) -> Map[String, Array[@cgraph.Edge]] {
  let classes : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    if edge_is_self(edge) {
      continue
    }
    let key = sameport_merge_key(edge)
    match classes.get(key) {
      Some(list) => list.push(edge)
      None => classes[key] = [edge]
    }
  }
  classes
}

///|
fn for_each_sameport_class_member_edge_id(
  merge_classes : Map[String, Array[@cgraph.Edge]],
  edge : @cgraph.Edge,
  apply_id : (Int) -> Unit,
) -> Unit {
  if edge_has_label(edge) {
    apply_id(edge.id())
    return ()
  }
  match merge_classes.get(sameport_merge_key(edge)) {
    Some(class_edges) =>
      for member_edge in class_edges {
        apply_id(member_edge.id())
      }
    None => apply_id(edge.id())
  }
}

///|
fn assign_sameport_override(
  overrides : Map[Int, @geom.Point],
  merge_classes : Map[String, Array[@cgraph.Edge]],
  edge : @cgraph.Edge,
  anchor : @geom.Point,
) -> Unit {
  for_each_sameport_class_member_edge_id(
    merge_classes,
    edge,
    (member_edge_id) => overrides[member_edge_id] = anchor,
  )
}

///|
fn assign_sameport_group_size(
  group_sizes : Map[Int, Int],
  merge_classes : Map[String, Array[@cgraph.Edge]],
  edge : @cgraph.Edge,
  group_size : Int,
) -> Unit {
  for_each_sameport_class_member_edge_id(
    merge_classes,
    edge,
    (member_edge_id) => group_sizes[member_edge_id] = group_size,
  )
}

///|
fn sameport_node_penwidth_pt(node : @cgraph.Node) -> Double {
  match node.get_attr("penwidth") {
    Some(value) => {
      let penwidth = parse_double(value, 1.0)
      if penwidth < 0.0 {
        0.0
      } else {
        penwidth
      }
    }
    None => 1.0
  }
}

///|
fn sameport_shape_has_outline(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "plain" | "plaintext" | "none" => false
    _ => true
  }
}

///|
/// Graphviz parity: sameport anchor construction aligned to
/// refs/graphviz/lib/dotgen/sameport.c (sameport).
/// Do not change behavior without updating fixtures/tests.
fn sameport_anchor_for_group(
  node : @cgraph.Node,
  group_edges : Array[@cgraph.Edge],
  head_group : Bool,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  layout_rankdir : RankDir,
  ranksep_pt : Double,
) -> @geom.Point? {
  let node_name = node.name()
  let node_pos = match positions.get(node_name) {
    Some(value) => value
    None => return None
  }
  let node_size =
    size_for_name_or_node(
      sizes,
      node_name,
      node,
      record_orientation,
    )
  let base_clip_size =
    match layout_rankdir {
      RankDir::LR | RankDir::RL =>
        @dot_shared.node_size_from_points(node_size.height_pt, node_size.width_pt)
      RankDir::TB | RankDir::BT => node_size
    }
  let clip_size =
    if group_edges.length() > 3 {
      base_clip_size
    } else {
      let clip_size =
        if sameport_shape_has_outline(node) {
          let penwidth = sameport_node_penwidth_pt(node)
          if penwidth > 0.0 {
            @dot_shared.node_size_from_points(
              base_clip_size.width_pt + penwidth / 2.0,
              base_clip_size.height_pt + penwidth / 2.0,
            )
          } else {
            base_clip_size
          }
        } else {
          base_clip_size
        }
      if group_edges.length() > 2 {
        @dot_shared.node_size_from_points(
          clip_size.width_pt + 2.0,
          clip_size.height_pt + 2.0,
        )
      } else {
        clip_size
      }
    }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for edge in group_edges {
    let peer_name = if head_group { edge.tail().name() } else { edge.head().name() }
    let peer_pos = match positions.get(peer_name) {
      Some(value) => value
      None => continue
    }
    let dx = peer_pos.x - node_pos.x
    let dy = peer_pos.y - node_pos.y
    let len = Double::sqrt(dx * dx + dy * dy)
    if len <= 0.0 {
      continue
    }
    sum_x = sum_x + dx / len
    sum_y = sum_y + dy / len
  }
  let sum_len = Double::sqrt(sum_x * sum_x + sum_y * sum_y)
  if sum_len <= 0.0 {
    return None
  }
  let dir_x = sum_x / sum_len
  let dir_y = sum_y / sum_len
  let far = max_double(
    clip_size.left_pt + clip_size.right_pt,
    clip_size.height_pt + ranksep_pt,
  )
  let target = @edge_spline.point(node_pos.x + dir_x * far, node_pos.y + dir_y * far)
  let clipped0 = clip_to_node_shape(node, node_pos, clip_size, target)
  let clipped =
    if group_edges.length() > 3 {
      if Double::abs(dir_x) <= Double::abs(dir_y) * 0.25 {
        @edge_spline.point(clipped0.x + dir_x, clipped0.y + dir_y)
      } else {
        clipped0
      }
    } else {
      let sameport_nudge =
        if group_edges.length() > 2 {
          0.5
        } else {
          1.0
        }
      @edge_spline.point(
        clipped0.x + dir_x * sameport_nudge,
        clipped0.y + dir_y * sameport_nudge,
      )
    }
  // Graphviz sameport stores integer offset from node center.
  let rel_x = (clipped.x - node_pos.x).round()
  let rel_y = (clipped.y - node_pos.y).round()
  Some(@edge_spline.point(node_pos.x + rel_x, node_pos.y + rel_y))
}

///|
priv struct SameportOverrides {
  samehead_anchors : Map[Int, @geom.Point]
  sametail_anchors : Map[Int, @geom.Point]
  samehead_group_sizes : Map[Int, Int]
  sametail_group_sizes : Map[Int, Int]
}

///|
priv struct EdgeSameportOrientationInfo {
  tail_anchor : @geom.Point?
  head_anchor : @geom.Point?
  tail_group_size : Int
  head_group_size : Int
}

///|
priv struct OrientedEdgeEndpointsForRoute {
  tail_name : String
  head_name : String
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_node : @cgraph.Node
  head_node : @cgraph.Node
}

///|
fn oriented_edge_endpoints_for_route(
  edge : @cgraph.Edge,
  swap_ends : Bool,
) -> OrientedEdgeEndpointsForRoute {
  if swap_ends {
    {
      tail_name: edge.head().name(),
      head_name: edge.tail().name(),
      tail_port: edge.head_port(),
      head_port: edge.tail_port(),
      tail_node: edge.head(),
      head_node: edge.tail(),
    }
  } else {
    {
      tail_name: edge.tail().name(),
      head_name: edge.head().name(),
      tail_port: edge.tail_port(),
      head_port: edge.head_port(),
      tail_node: edge.tail(),
      head_node: edge.head(),
    }
  }
}

///|
/// Graphviz parity: same-rank intercluster edges keep original direction in
/// route base setup even when edgecmp would otherwise swap endpoints.
fn edge_swap_ends_for_route_base(
  edge : @cgraph.Edge,
  orig_tail_name : String,
  orig_head_name : String,
  ranks : Map[String, Int],
  order_index : Map[String, Int],
) -> Bool {
  let swap_ends_raw =
    @edge_ops.edge_swap_ends(orig_tail_name, orig_head_name, ranks, order_index)
  let tail_rank_for_swap = ranks.get(orig_tail_name).unwrap_or_default()
  let head_rank_for_swap = ranks.get(orig_head_name).unwrap_or_default()
  if tail_rank_for_swap == head_rank_for_swap &&
    node_local_cluster_key(edge.tail()) != node_local_cluster_key(edge.head()) {
    false
  } else {
    swap_ends_raw
  }
}

///|
fn edge_sameport_orientation_info(
  edge_id : Int,
  sameport_overrides : SameportOverrides,
  swap_ends : Bool,
) -> EdgeSameportOrientationInfo {
  let samehead_anchor = sameport_overrides.samehead_anchors.get(edge_id)
  let sametail_anchor = sameport_overrides.sametail_anchors.get(edge_id)
  let samehead_group_size =
    sameport_overrides.samehead_group_sizes.get(edge_id).unwrap_or_default()
  let sametail_group_size =
    sameport_overrides.sametail_group_sizes.get(edge_id).unwrap_or_default()
  let tail_anchor = if swap_ends { samehead_anchor } else { sametail_anchor }
  let head_anchor = if swap_ends { sametail_anchor } else { samehead_anchor }
  let tail_group_size =
    if swap_ends { samehead_group_size } else { sametail_group_size }
  let head_group_size =
    if swap_ends { sametail_group_size } else { samehead_group_size }
  { tail_anchor, head_anchor, tail_group_size, head_group_size }
}

///|
fn apply_sameport_group_overrides(
  groups : Map[String, Array[@cgraph.Edge]],
  group_order : Array[String],
  head_group : Bool,
  overrides : Map[Int, @geom.Point],
  group_sizes : Map[Int, Int],
  merge_classes : Map[String, Array[@cgraph.Edge]],
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  layout_rankdir : RankDir,
  ranksep_pt : Double,
) -> Unit {
  for key in group_order {
    let group_edges = match groups.get(key) {
      Some(value) => value
      None => continue
    }
    if group_edges.length() <= 1 {
      continue
    }
    let anchor_node =
      if head_group { group_edges[0].head() } else { group_edges[0].tail() }
    match sameport_anchor_for_group(
      anchor_node,
      group_edges,
      head_group,
      positions,
      sizes,
      record_orientation,
      layout_rankdir,
      ranksep_pt,
    ) {
      Some(anchor) =>
        for edge in group_edges {
          assign_sameport_override(overrides, merge_classes, edge, anchor)
          assign_sameport_group_size(
            group_sizes,
            merge_classes,
            edge,
            group_edges.length(),
          )
        }
      None => ()
    }
  }
}

///|
/// Graphviz parity: samehead/sametail handling aligned to
/// refs/graphviz/lib/dotgen/sameport.c (dot_sameports).
/// Do not change behavior without updating fixtures/tests.
fn collect_sameport_overrides(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  layout_rankdir : RankDir,
  ranksep_pt : Double,
) -> SameportOverrides {
  let samehead_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  let sametail_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  let samehead_group_order : Array[String] = []
  let sametail_group_order : Array[String] = []
  let merge_classes = collect_sameport_classes(edges)
  for edge in edges {
    if edge_is_self(edge) {
      continue
    }
    let samehead_id = edge_attr_or_empty(edge, "samehead")
    if samehead_id != "" {
      add_sameport_group_edge(
        samehead_groups,
        samehead_group_order,
        "\{edge.head().name()}|\{samehead_id}",
        edge,
      )
    }
    let sametail_id = edge_attr_or_empty(edge, "sametail")
    if sametail_id != "" {
      add_sameport_group_edge(
        sametail_groups,
        sametail_group_order,
        "\{edge.tail().name()}|\{sametail_id}",
        edge,
      )
    }
  }
  let samehead_overrides : Map[Int, @geom.Point] = Map::new()
  let samehead_group_sizes : Map[Int, Int] = Map::new()
  apply_sameport_group_overrides(
    samehead_groups,
    samehead_group_order,
    true,
    samehead_overrides,
    samehead_group_sizes,
    merge_classes,
    positions,
    sizes,
    record_orientation,
    layout_rankdir,
    ranksep_pt,
  )
  let sametail_overrides : Map[Int, @geom.Point] = Map::new()
  let sametail_group_sizes : Map[Int, Int] = Map::new()
  apply_sameport_group_overrides(
    sametail_groups,
    sametail_group_order,
    false,
    sametail_overrides,
    sametail_group_sizes,
    merge_classes,
    positions,
    sizes,
    record_orientation,
    layout_rankdir,
    ranksep_pt,
  )
  {
    samehead_anchors: samehead_overrides,
    sametail_anchors: sametail_overrides,
    samehead_group_sizes,
    sametail_group_sizes,
  }
}

///|
fn edge_attr_non_empty(edge : @cgraph.Edge, name : String) -> Bool {
  edge_attr_or_empty(edge, name) != ""
}

///|
fn edge_attr_or_empty(edge : @cgraph.Edge, name : String) -> String {
  match edge.get_attr(name) {
    Some(value) => value
    None => ""
  }
}
///|
fn clip_polygon_attr_int(
  node : @cgraph.Node,
  key : String,
  fallback : Int,
) -> Int {
  match node.get_attr(key) {
    Some(value) => parse_double(value, fallback.to_double()).round().to_int()
    None => fallback
  }
}

///|
fn clip_polygon_attr_double(
  node : @cgraph.Node,
  key : String,
  fallback : Double,
) -> Double {
  match node.get_attr(key) {
    Some(value) => parse_double(value, fallback)
    None => fallback
  }
}

///|
priv struct ClipPolygonShapeParams {
  sides : Int
  orientation : Double
  distortion : Double
  skew : Double
}

///|
fn clip_polygon_shape_params(
  node : @cgraph.Node,
  shape : String,
) -> ClipPolygonShapeParams? {
  match shape {
    "triangle" => Some({ sides: 3, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "invtriangle" =>
      Some({ sides: 3, orientation: 180.0, distortion: 0.0, skew: 0.0 })
    "trapezium" =>
      Some({ sides: 4, orientation: 0.0, distortion: -0.4, skew: 0.0 })
    "invtrapezium" =>
      Some({ sides: 4, orientation: 180.0, distortion: -0.4, skew: 0.0 })
    "parallelogram" =>
      Some({ sides: 4, orientation: 0.0, distortion: 0.0, skew: 0.6 })
    "egg" => Some({ sides: 120, orientation: 0.0, distortion: -0.3, skew: 0.0 })
    "house" => Some({ sides: 5, orientation: 0.0, distortion: -0.64, skew: 0.0 })
    "invhouse" =>
      Some({ sides: 5, orientation: 180.0, distortion: -0.64, skew: 0.0 })
    "pentagon" => Some({ sides: 5, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "hexagon" => Some({ sides: 6, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "septagon" => Some({ sides: 7, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "octagon" | "doubleoctagon" | "tripleoctagon" =>
      Some({ sides: 8, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "polygon" => {
      let mut sides = clip_polygon_attr_int(node, "sides", 4)
      if sides < 0 {
        sides = 0
      }
      let orientation = clip_polygon_attr_double(node, "orientation", 0.0)
      let distortion = clip_polygon_attr_double(node, "distortion", 0.0)
      let skew = clip_polygon_attr_double(node, "skew", 0.0)
      if sides <= 2 && (Double::abs(distortion) > 0.0000001 || Double::abs(skew) > 0.0000001) {
        sides = 120
      }
      if sides >= 3 {
        Some({ sides, orientation, distortion, skew })
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn clip_polygon_for_shape(
  size : NodeSize,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> Array[@geom.Point] {
  if sides < 3 {
    return []
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  if half_w <= 0.0 || half_h <= 0.0 {
    return []
  }
  let sector = 2.0 * @math.PI / sides.to_double()
  let side_len = @math.sin(sector / 2.0)
  let abs_mix = Double::abs(distortion) + Double::abs(skew)
  let skew_dist = Double::sqrt(abs_mix * abs_mix + 1.0)
  let cos_half = @math.cos(sector / 2.0)
  if Double::abs(cos_half) <= 0.0000001 {
    return []
  }
  let g_distortion = distortion * Double::sqrt(2.0) / cos_half
  let g_skew = skew / 2.0
  let mut angle = (sector - @math.PI) / 2.0
  let mut sinx = @math.sin(angle)
  let mut cosx = @math.cos(angle)
  let mut r = @edge_spline.point(0.5 * cosx, 0.5 * sinx)
  let mut xmax = 0.0
  let mut ymax = 0.0
  angle = angle + (@math.PI - sector) / 2.0
  let base : Array[@geom.Point] = []
  for _ in 0..<sides {
    angle = angle + sector
    sinx = @math.sin(angle)
    cosx = @math.cos(angle)
    r = @edge_spline.point(r.x + side_len * cosx, r.y + side_len * sinx)
    let mut px = r.x * (skew_dist + r.y * g_distortion) + r.y * g_skew
    let mut py = r.y
    let alpha = orientation_deg * @math.PI / 180.0 + @math.atan2(py, px)
    let radius = Double::sqrt(px * px + py * py)
    px = radius * @math.cos(alpha)
    py = radius * @math.sin(alpha)
    if Double::abs(px) > xmax {
      xmax = Double::abs(px)
    }
    if Double::abs(py) > ymax {
      ymax = Double::abs(py)
    }
    base.push(@edge_spline.point(px, py))
  }
  if xmax <= 0.0 || ymax <= 0.0 {
    return []
  }
  let scale_x = half_w / xmax
  let scale_y = half_h / ymax
  let out : Array[@geom.Point] = []
  for vertex in base {
    out.push(@edge_spline.point(vertex.x * scale_x, vertex.y * scale_y))
  }
  out
}

///|
fn clip_to_polygon_shape(
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> @geom.Point {
  let vertices =
    clip_polygon_for_shape(
      size,
      sides,
      orientation_deg,
      distortion,
      skew,
    )
  if vertices.length() < 3 {
    return clip_to_rect(center, size, target)
  }
  let dx = target.x - center.x
  let dy = target.y - center.y
  if Double::abs(dx) <= 0.0000001 && Double::abs(dy) <= 0.0000001 {
    return center
  }
  let mut best_t = 0.0
  let mut found = false
  for i in 0..<vertices.length() {
    let a = vertices[i]
    let b = vertices[(i + 1) % vertices.length()]
    let sx = b.x - a.x
    let sy = b.y - a.y
    let denom = dx * sy - dy * sx
    if Double::abs(denom) <= 0.0000001 {
      continue
    }
    let t = (a.x * sy - a.y * sx) / denom
    let u = (a.x * dy - a.y * dx) / denom
    if t < 0.0 {
      continue
    }
    if u < -0.000001 || u > 1.000001 {
      continue
    }
    if !found || t < best_t {
      best_t = t
      found = true
    }
  }
  if found {
    @edge_spline.point(center.x + dx * best_t, center.y + dy * best_t)
  } else {
    clip_to_rect(center, size, target)
  }
}

///|
/// Graphviz parity: route anchor clipping uses node shape bounds.
fn clip_to_node_shape(
  node : @cgraph.Node,
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
) -> @geom.Point {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      clip_to_ellipse(center, size, target)
    "diamond" | "mdiamond" => clip_to_diamond(center, size, target)
    _ =>
      match clip_polygon_shape_params(node, shape) {
        Some(params) =>
          clip_to_polygon_shape(
            center,
            size,
            target,
            params.sides,
            params.orientation,
            params.distortion,
            params.skew,
          )
        None => clip_to_rect(center, size, target)
      }
  }
}
