///|
priv struct RoutingContext {
  order_index : Map[String, Int]
  path_order_index : Map[String, Int]
  path_adjacency : @routesplines.PathAdjacency
  pathplan_sizes : Map[String, NodeSize]
  path_cluster_keys : Map[String, String]
  path_vnode_clusters : Map[String, String]
  parallel_offsets : Map[Int, Double]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
/// Graphviz parity: routing context aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn prepare_routing_context(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
  ranks : Map[String, Int],
  ordered_groups : Map[Int, Array[String]],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  cluster_bboxes : Map[String, @geom.Rect],
) -> RoutingContext {
  let order_index = build_order_index(ordered_groups)
  let path_order_index = build_order_index(x_groups)
  let path_adjacency =
    @routesplines.build_path_adjacency(edges, vnode_info.edge_vnodes)
  let pathplan_sizes =
    apply_self_edge_right_space(
      nodes,
      edges,
      sizes,
      rankdir,
      record_orientation,
    )
  let path_cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    path_cluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let path_vnode_clusters : Map[String, String] = Map::new()
  for edge in edges {
    let key = edge_vnode_key(edge)
    let vnodes = match vnode_info.edge_vnodes.get(key) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail_cluster = node_local_cluster_key(edge.tail())
    let head_cluster = node_local_cluster_key(edge.head())
    for vnode in vnodes {
      let pos = match vnode_positions.get(vnode) {
        Some(value) => value
        None => continue
      }
      let mut vnode_cluster = ""
      if tail_cluster != "" {
        match cluster_bboxes.get(tail_cluster) {
          Some(rect) =>
            if pos.x >= rect.llx && pos.x <= rect.urx &&
              pos.y >= rect.lly && pos.y <= rect.ury {
              vnode_cluster = tail_cluster
            }
          None => ()
        }
      }
      if vnode_cluster == "" && head_cluster != "" {
        match cluster_bboxes.get(head_cluster) {
          Some(rect) =>
            if pos.x >= rect.llx && pos.x <= rect.urx &&
              pos.y >= rect.lly && pos.y <= rect.ury {
              vnode_cluster = head_cluster
            }
          None => ()
        }
      }
      path_vnode_clusters[vnode] = vnode_cluster
    }
  }
  let parallel_offsets =
    edge_parallel_offsets(edges, ranks, order_index, nodesep_pt)
  {
    order_index,
    path_order_index,
    path_adjacency,
    pathplan_sizes,
    path_cluster_keys,
    path_vnode_clusters,
    parallel_offsets,
    cluster_bboxes,
  }
}
///|
priv struct EdgeRouteBase {
  edge : @cgraph.Edge
  parallel_offset : Double
  swap_ends : Bool
  orig_tail_name : String
  orig_head_name : String
  tail_name : String
  head_name : String
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_node : @cgraph.Node
  head_node : @cgraph.Node
  tail_pos : @geom.Point
  head_pos : @geom.Point
  tail_size : NodeSize
  head_size : NodeSize
  tail_anchor : @geom.Point
  head_anchor : @geom.Point
  head_port_rect : @geom.Rect?
  tail_port_side : Int
  head_port_side : Int
  tail_clip_center : @geom.Point
  tail_clip_size : NodeSize
  head_clip_center : @geom.Point
  head_clip_size : NodeSize
  tail_clip : @geom.Point
  head_clip : @geom.Point
  tail_slope : @geom.Point
  head_slope : @geom.Point
  force_segmented : Bool
  tail_cluster_bbox : @geom.Rect?
  head_cluster_bbox : @geom.Rect?
  tail_rank : Int
  head_rank : Int
  is_flat_edge : Bool
  vnodes : Array[String]
  has_vnodes : Bool
  use_pathplan : Bool
  route_include_tail : Bool
  route_include_head : Bool
  arrow_len_override : Double?
  is_dotted : Bool
  same_outer_cluster : Bool
  diff_local_cluster : Bool
  same_local_cluster : Bool
  out_tail_anchor : @geom.Point
  out_head_anchor : @geom.Point
  out_tail_clip : @geom.Point
  out_head_clip : @geom.Point
  out_tail_pos : @geom.Point
  out_head_pos : @geom.Point
  out_tail_size : NodeSize
  out_head_size : NodeSize
  rankdir : RankDir
  layout_rankdir : RankDir
  has_side_anchor : Bool
}

///|
priv struct EdgeSplineResult {
  spline : @geom.Spline
  label_pad_boost : Double
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  raw_bezier : Array[@geom.Point]
  apply_dotted_adjustment : Bool
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
) -> EdgeRouteBase {
  let order_index = routing_context.order_index
  let parallel_offsets = routing_context.parallel_offsets
  let cluster_bboxes = routing_context.cluster_bboxes
  let parallel_offset = match parallel_offsets.get(edge.id()) {
    Some(value) => value
    None => 0.0
  }
  let orig_tail_name = edge.tail().name()
  let orig_head_name = edge.head().name()
  let swap_ends = edge_swap_ends(orig_tail_name, orig_head_name, ranks, order_index)
  let (tail_name, head_name, tail_port, head_port, tail_node, head_node) =
    if swap_ends {
      (orig_head_name, orig_tail_name, edge.head_port(), edge.tail_port(), edge.head(), edge.tail())
    } else {
      (orig_tail_name, orig_head_name, edge.tail_port(), edge.head_port(), edge.tail(), edge.head())
    }
  let tail_pos = match positions.get(tail_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let head_pos = match positions.get(head_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let tail_size = match sizes.get(tail_name) {
    Some(value) => value
    None => node_size(tail_node, record_orientation)
  }
  let head_size = match sizes.get(head_name) {
    Some(value) => value
    None => node_size(head_node, record_orientation)
  }
  let (raw_tail_anchor, raw_tail_anchor_size) = port_geometry(
    tail_name,
    tail_port,
    label_ports_map,
    tail_pos,
    tail_size,
  )
  let (raw_head_anchor, raw_head_anchor_size) = port_geometry(
    head_name,
    head_port,
    label_ports_map,
    head_pos,
    head_size,
  )
  let tail_port_rect = port_rect_from_geometry(
    tail_port,
    raw_tail_anchor,
    raw_tail_anchor_size,
    tail_size,
  )
  let head_port_rect = port_rect_from_geometry(
    head_port,
    raw_head_anchor,
    raw_head_anchor_size,
    head_size,
  )
  let tail_port_sides = match tail_port_rect {
    Some(rect) => port_side_count(rect, tail_pos, tail_size)
    None => 0
  }
  let head_port_sides = match head_port_rect {
    Some(rect) => port_side_count(rect, head_pos, head_size)
    None => 0
  }
  let force_segmented = tail_port_sides >= 3 || head_port_sides >= 3
  let tail_cluster_name = match edge.get_attr("ltail") {
    Some(value) => value
    None => ""
  }
  let head_cluster_name = match edge.get_attr("lhead") {
    Some(value) => value
    None => ""
  }
  let tail_rank = match ranks.get(tail_name) {
    Some(value) => value
    None => 0
  }
  let head_rank = match ranks.get(head_name) {
    Some(value) => value
    None => 0
  }
  let is_flat_edge = tail_rank == head_rank
  let has_cluster = tail_cluster_name != "" || head_cluster_name != ""
  let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  let has_vnodes = vnodes.length() > 0
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
    !port_is_explicit(tail_port) &&
    !port_is_explicit(head_port) &&
    !use_pathplan
  let (tail_offset, head_offset) = if allow_offset {
    (
      layout_port_offset(point(0.0, -1.0), layout_rankdir),
      layout_port_offset(point(0.0, 1.0), layout_rankdir),
    )
  } else {
    (point(0.0, 0.0), point(0.0, 0.0))
  }
  let tail_cluster_bbox : @geom.Rect? =
    if tail_cluster_name == "" {
    None
  } else {
    cluster_bboxes.get(tail_cluster_name)
  }
  let head_cluster_bbox : @geom.Rect? =
    if head_cluster_name == "" {
    None
  } else {
    cluster_bboxes.get(head_cluster_name)
  }
  let (tail_side_anchor, tail_dynamic_side, tail_dynamic) =
    dynamic_port_anchor_for_edge(
      tail_port,
      tail_name,
      label_ports_raw,
      tail_pos,
      head_pos,
      layout_rankdir,
      "tail",
    )
  let (head_side_anchor, head_dynamic_side, head_dynamic) =
    dynamic_port_anchor_for_edge(
      head_port,
      head_name,
      label_ports_raw,
      head_pos,
      tail_pos,
      layout_rankdir,
      "head",
    )
  let has_side_anchor =
    tail_side_anchor is Some(_) || head_side_anchor is Some(_)
  let tail_anchor_base = match tail_side_anchor {
    Some(pos) => pos
    None => raw_tail_anchor
  }
  let head_anchor_base = match head_side_anchor {
    Some(pos) => pos
    None => raw_head_anchor
  }
  let tail_port_side =
    if tail_dynamic {
    tail_dynamic_side
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
    if head_dynamic {
    head_dynamic_side
  } else {
    port_side_for_edge(
      head_port,
      head_port_rect,
      head_pos,
      head_size,
      None,
    )
  }
  let tail_anchor = point_add(tail_anchor_base, tail_offset)
  let head_anchor = point_add(head_anchor_base, head_offset)
  let tail_clip_center = raw_tail_anchor
  let tail_clip_size = raw_tail_anchor_size
  let head_clip_center = raw_head_anchor
  let head_clip_size = raw_head_anchor_size
  let tail_target = match tail_port_rect {
    Some(_) => head_pos
    None => tail_anchor
  }
  let head_target = match head_port_rect {
    Some(_) => tail_pos
    None => head_anchor
  }
  let tail_slope = endpoint_slope_for_anchor(
    tail_port,
    tail_anchor,
    tail_pos,
    tail_size,
    tail_target,
    layout_rankdir,
    true,
    tail_port_rect,
  )
  let head_slope = endpoint_slope_for_anchor(
    head_port,
    head_anchor,
    head_pos,
    head_size,
    head_target,
    layout_rankdir,
    false,
    head_port_rect,
  )
  let tail_clip_target =
    if port_is_explicit(tail_port) &&
      (tail_slope.x != 0.0 || tail_slope.y != 0.0) {
      point_add(tail_clip_center, tail_slope)
    } else {
      head_anchor
    }
  let head_clip_target =
    if port_is_explicit(head_port) &&
      (head_slope.x != 0.0 || head_slope.y != 0.0) {
      point_add(head_clip_center, head_slope)
    } else {
      tail_anchor
    }
  let tail_clip = match tail_cluster_bbox {
    Some(rect) => clip_to_bbox(tail_anchor, rect, head_anchor)
    None =>
      match tail_side_anchor {
        Some(pos) => pos
        None => clip_to_rect(tail_clip_center, tail_clip_size, tail_clip_target)
      }
  }
  let head_clip = match head_cluster_bbox {
    Some(rect) => clip_to_bbox(head_anchor, rect, tail_anchor)
    None =>
      match head_side_anchor {
        Some(pos) => pos
        None => clip_to_rect(head_clip_center, head_clip_size, head_clip_target)
      }
  }
  let out_tail_anchor = if swap_ends { head_anchor } else { tail_anchor }
  let out_head_anchor = if swap_ends { tail_anchor } else { head_anchor }
  let out_tail_clip = if swap_ends { head_clip } else { tail_clip }
  let out_head_clip = if swap_ends { tail_clip } else { head_clip }
  let out_tail_pos = match positions.get(orig_tail_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let out_head_pos = match positions.get(orig_head_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let out_tail_size = match sizes.get(orig_tail_name) {
    Some(value) => value
    None => node_size(edge.tail(), record_orientation)
  }
  let out_head_size = match sizes.get(orig_head_name) {
    Some(value) => value
    None => node_size(edge.head(), record_orientation)
  }
  let dir = edge_dir_for(edge, graph_kind)
  let include_tail = match dir {
    EdgeDir::Back | EdgeDir::Both => true
    _ => false
  }
  let include_head = match dir {
    EdgeDir::Forward | EdgeDir::Both => true
    _ => false
  }
  let (route_include_tail, route_include_head) =
    if swap_ends { (include_head, include_tail) } else { (include_tail, include_head) }
  let arrow_len_override : Double? =
    if include_tail || include_head {
    if tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_) {
      let base = arrow_length_for_edge(edge)
      let span = point_dist(tail_clip, head_clip)
      let max_len = span * 0.25
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
    tail_clip_center,
    tail_clip_size,
    head_clip_center,
    head_clip_size,
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
priv struct RoutePointState {
  points : Array[@geom.Point]
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  route_barriers : Array[(@geom.Point, @geom.Point)]
}

///|
/// Graphviz parity: pathplan polyline aligned to refs/graphviz/lib/pathplan/* + lib/common/routespl.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_route_points_with_pathplan(
  base : EdgeRouteBase,
  ranks : Map[String, Int],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  nodesep_pt : Double,
  ranksep_pt : Double,
  routing_context : RoutingContext,
  guide_points : Array[@geom.Point],
) -> RoutePointState {
  let mut route_barriers : Array[(@geom.Point, @geom.Point)] = []
  let mut pathplan_boxes : Array[@geom.Rect] = []
  let mut pathplan_points : Array[@geom.Point] = []
  let (points, pathplan_used) =
    if base.use_pathplan && !base.is_flat_edge {
    match @routesplines.edge_pathplan_polyline(
      base.edge,
      base.tail_name,
      base.head_name,
      base.tail_anchor,
      base.head_anchor,
      base.layout_rankdir,
      base.tail_port_side,
      base.head_port_side,
      ranksep_pt,
      ranks,
      vnode_info.vnode_ranks,
      vnode_info.edge_vnodes,
      positions,
      vnode_positions,
      routing_context.pathplan_sizes,
      sizes,
      vnode_info.vnode_sizes,
      routing_context.path_cluster_keys,
      routing_context.path_vnode_clusters,
      routing_context.cluster_bboxes,
      x_groups,
      routing_context.path_order_index,
      routing_context.path_adjacency.out_edges,
      routing_context.path_adjacency.in_edges,
      rank_y,
      rank_ht1,
      rank_ht2,
      nodesep_pt,
    ) {
      Some((path_points, barriers, path_boxes)) => {
        route_barriers = barriers
        pathplan_boxes = path_boxes
        pathplan_points = path_points.copy()
        (path_points, true)
      }
      None => (guide_points, false)
    }
  } else {
    (
      guide_points,
      false,
    )
  }
  {
    points,
    using_pathplan: pathplan_used,
    pathplan_boxes,
    pathplan_points,
    route_barriers,
  }
}

///|
/// Graphviz parity: route point tweaks aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn adjust_route_points(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
  base : EdgeRouteBase,
  head_port_rect : @geom.Rect?,
  has_explicit_port : Bool,
  using_pathplan : Bool,
  nodesep_pt : Double,
) -> Array[@geom.Point] {
  let mut points = points
  let touch_eps = max_double(RECORD_BORDER_PT + 0.01, 1.5)
  let head_lr_touch =
    match head_port_rect {
      Some(rect) => {
        let node_rect = port_side_rect(base.head_pos, base.head_size)
        Double::abs(rect.llx - node_rect.llx) <= touch_eps ||
          Double::abs(rect.urx - node_rect.urx) <= touch_eps
      }
      None => false
    }
  let head_tb_touch =
    match head_port_rect {
      Some(rect) => {
        let node_rect = port_side_rect(base.head_pos, base.head_size)
        Double::abs(rect.lly - node_rect.lly) <= touch_eps ||
          Double::abs(rect.ury - node_rect.ury) <= touch_eps
      }
      None => false
    }
  let detour_ok =
    match base.layout_rankdir {
      RankDir::TB | RankDir::BT => head_tb_touch && !head_lr_touch
      RankDir::LR | RankDir::RL => head_lr_touch && !head_tb_touch
    }
  if points.length() <= 2 && has_explicit_port && detour_ok {
    let tail_rect = port_side_rect(base.tail_pos, base.tail_size)
    let head_rect = port_side_rect(base.head_pos, base.head_size)
    let anchor_eps = 0.02
    let needs_detour =
      segment_intersects_rect(
        base.tail_anchor,
        base.head_anchor,
        head_rect,
        anchor_eps,
      )
    if needs_detour {
      points =
        detour_polyline_for_rects(
          base.tail_anchor,
          base.head_anchor,
          tail_rect,
          head_rect,
          nodesep_pt,
          base.layout_rankdir,
        )
    }
  }
  if base.is_dotted && !base.same_outer_cluster && !using_pathplan {
    points = adjust_intercluster_dotted_points(
      points,
      base.tail_anchor,
      base.head_anchor,
      base.head_clip_size,
      nodesep_pt,
    )
  }
  dot_trace_route_points(edge, points)
  if has_explicit_port && base.has_side_anchor && points.length() <= 2 {
    let offset = max_double(4.0, nodesep_pt * 0.5)
    let kinked : Array[@geom.Point] = [base.tail_anchor]
    if base.tail_slope.x != 0.0 || base.tail_slope.y != 0.0 {
      kinked.push(point_add(base.tail_anchor, point_scale(base.tail_slope, offset)))
    }
    if base.head_slope.x != 0.0 || base.head_slope.y != 0.0 {
      kinked.push(point_add(base.head_anchor, point_scale(base.head_slope, -offset)))
    }
    kinked.push(base.head_anchor)
    points = kinked
  }
  points
}

///|
/// Graphviz parity: curve offset tuning aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_curve_offset(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  head_port_metrics : HeadPortMetrics,
  label_width_pt : Double,
  nodesep_pt : Double,
  enable_complex_tuning : Bool,
) -> (Double, Double) {
  let mut curve_offset = 0.0
  let mut curve_skew = 1.0
  if enable_complex_tuning {
    let head_port_key = port_key(edge.head_port())
    let key =
      if head_port_key == "" {
      if is_record_shape(edge.head()) { base.orig_head_name } else { "" }
    } else {
      "\{base.orig_head_name}:\{head_port_key}"
    }
    if key != "" {
      let count = match head_port_metrics.head_port_counts.get(key) {
        Some(value) => value
        None => 0
      }
      if count > 1 {
        let dx = base.head_anchor.x - base.tail_anchor.x
        let dy = base.head_anchor.y - base.tail_anchor.y
        let dist = Double::sqrt(dx * dx + dy * dy)
        let min_dist = match head_port_metrics.head_port_min_dist.get(key) {
          Some(value) => value
          None => dist
        }
        let max_dist = match head_port_metrics.head_port_max_dist.get(key) {
          Some(value) => value
          None => dist
        }
        let span = max_dist - min_dist
        if span > 0.0 {
          let t = (dist - min_dist) / span
          let label_factor = if label_width_pt > 0.0 { 1.0 } else { 0.5 }
          let port_scale = if head_port_key == "" { 0.6 } else { 0.6 }
          curve_offset = nodesep_pt * t * t * label_factor * port_scale
          if head_port_key != "" {
            match base.rankdir {
              RankDir::TB | RankDir::BT =>
                if dx < 0.0 {
                  curve_skew = 0.5
                }
              RankDir::LR | RankDir::RL =>
                if dy < 0.0 {
                  curve_skew = 0.5
                }
            }
          }
        }
      }
    }
  }
  (curve_offset, curve_skew)
}

///|
/// Graphviz parity: spline routing aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_spline(
  base : EdgeRouteBase,
  splines : SplinesMode,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  ranksep_pt : Double,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> EdgeSplineResult {
  let edge = base.edge
  let tail_name = base.tail_name
  let head_name = base.head_name
  let tail_port = base.tail_port
  let head_port = base.head_port
  let tail_node = base.tail_node
  let head_node = base.head_node
  let tail_anchor = base.tail_anchor
  let head_anchor = base.head_anchor
  let head_port_rect = base.head_port_rect
  let tail_clip_center = base.tail_clip_center
  let head_clip_center = base.head_clip_center
  let tail_clip_size = base.tail_clip_size
  let head_clip_size = base.head_clip_size
  let tail_clip = base.tail_clip
  let head_clip = base.head_clip
  let tail_slope = base.tail_slope
  let head_slope = base.head_slope
  let force_segmented = base.force_segmented
  let tail_cluster_bbox = base.tail_cluster_bbox
  let head_cluster_bbox = base.head_cluster_bbox
  let is_flat_edge = base.is_flat_edge
  let has_vnodes = base.has_vnodes
  let route_include_tail = base.route_include_tail
  let route_include_head = base.route_include_head
  let arrow_len_override = base.arrow_len_override
  let is_dotted = base.is_dotted
  let same_outer_cluster = base.same_outer_cluster
  let diff_local_cluster = base.diff_local_cluster
  let same_local_cluster = base.same_local_cluster
  let layout_rankdir = base.layout_rankdir
  let parallel_offset = base.parallel_offset
  let orig_tail_name = base.orig_tail_name
  let mut label_pad_boost = 0.0
  let mut using_pathplan = false
  let mut pathplan_boxes : Array[@geom.Rect] = []
  let mut pathplan_points : Array[@geom.Point] = []
  let mut raw_bezier : Array[@geom.Point] = []
  let mut apply_dotted_adjustment = false
  let spline = match splines {
    SplinesMode::None | SplinesMode::Polyline =>
      edge_spline_for_polyline(
        edge,
        tail_clip_center,
        head_clip_center,
        tail_clip_size,
        head_clip_size,
        tail_clip,
        head_clip,
        layout_rankdir,
        false,
        route_include_tail,
        route_include_head,
        arrow_len_override=arrow_len_override,
        tail_cluster_bbox=tail_cluster_bbox,
        head_cluster_bbox=head_cluster_bbox,
        parallel_offset=parallel_offset,
      )
    SplinesMode::Ortho =>
      edge_spline_for_polyline(
        edge,
        tail_clip_center,
        head_clip_center,
        tail_clip_size,
        head_clip_size,
        tail_clip,
        head_clip,
        layout_rankdir,
        true,
        route_include_tail,
        route_include_head,
        arrow_len_override=arrow_len_override,
        tail_cluster_bbox=tail_cluster_bbox,
        head_cluster_bbox=head_cluster_bbox,
        parallel_offset=parallel_offset,
      )
    _ => {
      let label_width_pt = edge_mid_label_width_pt(edge)
      let has_explicit_port =
        port_is_explicit(tail_port) || port_is_explicit(head_port)
      let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
      let split_label = enable_complex_tuning &&
        label_width_pt > 0.0 &&
        same_outer_cluster &&
        diff_local_cluster &&
        abs_dx > label_width_pt
      if split_label {
        label_pad_boost = nodesep_pt * 1.2
      }
      let dotted_weight = if enable_complex_tuning { 1.0 } else { 0.8 }
      let guide_points = edge_polyline_points(
        edge,
        tail_name,
        head_name,
        tail_port,
        head_port,
        tail_anchor,
        head_anchor,
        ranks,
        vnode_info.edge_vnodes,
        vnode_info.vnode_ranks,
        vnode_positions,
        rank_y,
        rank_ht1,
        nodesep_pt,
        label_width_pt,
        dotted_weight,
        enable_complex_tuning,
        split_label,
        same_local_cluster,
      )
      let route_state =
        compute_route_points_with_pathplan(
          base,
          ranks,
          positions,
          vnode_positions,
          vnode_info,
          sizes,
          x_groups,
          rank_y,
          rank_ht1,
          rank_ht2,
          nodesep_pt,
          ranksep_pt,
          routing_context,
          guide_points,
        )
      using_pathplan = route_state.using_pathplan
      pathplan_boxes = route_state.pathplan_boxes
      pathplan_points = route_state.pathplan_points
      let route_barriers = route_state.route_barriers
      let points =
        adjust_route_points(
          edge,
          route_state.points,
          base,
          head_port_rect,
          has_explicit_port,
          using_pathplan,
          nodesep_pt,
        )
      let (curve_offset, curve_skew) =
        compute_curve_offset(
          edge,
          base,
          head_port_metrics,
          label_width_pt,
          nodesep_pt,
          enable_complex_tuning,
        )
      let routed_spline = if points.length() > 2 {
        let clipped = points
        let simplify_tol = nodesep_pt * 0.8
        let tail_label_edges = match label_edge_counts.get(orig_tail_name) {
          Some(value) => value > 1
          None => false
        }
      let keep_label_kink =
        label_width_pt > 0.0 &&
        (has_explicit_port ||
          (same_outer_cluster &&
              (abs_dx < nodesep_pt || (tail_label_edges && abs_dx < label_width_pt))))
        let simplified =
          if using_pathplan {
            clipped
          } else if enable_complex_tuning &&
            has_vnodes &&
            !split_label &&
            !keep_label_kink {
            simplify_polyline(clipped, simplify_tol)
          } else {
            clipped
          }
        let adjusted =
          if !using_pathplan && is_dotted && same_outer_cluster {
            adjust_intracluster_dotted_points(simplified)
          } else {
            simplified
          }
        if adjusted.length() <= 2 {
          let tail_slope_line =
            if port_is_explicit(tail_port) {
              tail_slope
            } else {
              point(0.0, 0.0)
            }
          let head_slope_line =
            if port_is_explicit(head_port) {
              head_slope
            } else {
              point(0.0, 0.0)
            }
          let record_port_edge =
            (is_record_shape(tail_node) && port_is_explicit(tail_port)) ||
              (is_record_shape(head_node) && port_is_explicit(head_port))
          let needs_record_detour =
            !is_flat_edge &&
            record_port_edge &&
            (match layout_rankdir {
              RankDir::TB | RankDir::BT =>
                Double::abs(tail_slope_line.x) > 0.01 ||
                  Double::abs(head_slope_line.x) > 0.01
              RankDir::LR | RankDir::RL =>
                Double::abs(tail_slope_line.y) > 0.01 ||
                  Double::abs(head_slope_line.y) > 0.01
            })
          if needs_record_detour {
            let tail_rect = port_side_rect(tail_clip_center, tail_clip_size)
            let head_rect = port_side_rect(head_clip_center, head_clip_size)
            let detour_offset = nodesep_pt * 0.5
            let detour_points =
              match layout_rankdir {
                RankDir::TB | RankDir::BT => {
                  let mut side = tail_clip.x - tail_clip_center.x
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.x - head_clip_center.x
                  }
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.x - tail_clip.x
                  }
                  let detour_x =
                    if side < 0.0 {
                      min_double(tail_rect.llx, head_rect.llx) - detour_offset
                    } else {
                      max_double(tail_rect.urx, head_rect.urx) + detour_offset
                    }
                  [
                    tail_clip,
                    point(detour_x, tail_clip.y),
                    point(detour_x, head_clip.y),
                    head_clip,
                  ]
                }
                RankDir::LR | RankDir::RL => {
                  let mut side = tail_clip.y - tail_clip_center.y
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.y - head_clip_center.y
                  }
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.y - tail_clip.y
                  }
                  let detour_y =
                    if side < 0.0 {
                      min_double(tail_rect.lly, head_rect.lly) - detour_offset
                    } else {
                      max_double(tail_rect.ury, head_rect.ury) + detour_offset
                    }
                  [
                    tail_clip,
                    point(detour_y, tail_clip.y),
                    point(detour_y, head_clip.y),
                    head_clip,
                  ]
              }
            }
            if using_pathplan {
              raw_bezier =
                edge_spline_raw_for_points(
                  detour_points,
                  tail_slope_line,
                  head_slope_line,
                  true,
                  route_barriers=route_barriers,
                )
            }
            edge_spline_for_points(
              edge,
              detour_points,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              true,
              route_include_tail,
              route_include_head,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
            )
          } else {
            if using_pathplan {
              let line_points = adjusted
              raw_bezier =
                edge_spline_raw_for_points(
                  line_points,
                  tail_slope_line,
                  head_slope_line,
                  force_segmented,
                  route_barriers=route_barriers,
                )
              edge_spline_for_points(
                edge,
                line_points,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                force_segmented,
                route_include_tail,
                route_include_head,
                route_barriers=route_barriers,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
              )
            } else {
              edge_spline_for_line(
                edge,
                adjusted[0],
                adjusted[adjusted.length() - 1],
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                route_include_tail,
                route_include_head,
                layout_rankdir,
                curve_offset,
                curve_skew,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
              )
            }
          }
        } else {
          let tail_slope_for =
            if port_is_explicit(tail_port) {
              tail_slope
            } else {
              point(0.0, 0.0)
            }
        let head_slope_for =
          if port_is_explicit(head_port) {
            head_slope
          } else {
            point(0.0, 0.0)
          }
        let edge_force_segmented = force_segmented
        if using_pathplan {
          raw_bezier =
            edge_spline_raw_for_points(
              adjusted,
              tail_slope_for,
              head_slope_for,
              edge_force_segmented,
              route_barriers=route_barriers,
            )
        }
        let spline =
          edge_spline_for_points(
            edge,
            adjusted,
            tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_for,
              head_slope_for,
              edge_force_segmented,
              route_include_tail,
              route_include_head,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
            )
        apply_dotted_adjustment = true
        spline
        }
      } else {
        let tail_slope_line =
          if port_is_explicit(tail_port) {
            tail_slope
          } else {
            point(0.0, 0.0)
          }
        let head_slope_line =
          if port_is_explicit(head_port) {
            head_slope
          } else {
            point(0.0, 0.0)
          }
        let record_port_edge =
          (is_record_shape(tail_node) && port_is_explicit(tail_port)) ||
            (is_record_shape(head_node) && port_is_explicit(head_port))
        let needs_record_detour =
          !is_flat_edge &&
          record_port_edge &&
          (match layout_rankdir {
            RankDir::TB | RankDir::BT =>
              Double::abs(tail_slope_line.x) > 0.01 ||
                Double::abs(head_slope_line.x) > 0.01
            RankDir::LR | RankDir::RL =>
              Double::abs(tail_slope_line.y) > 0.01 ||
                Double::abs(head_slope_line.y) > 0.01
          })
        if needs_record_detour {
          let tail_rect = port_side_rect(tail_clip_center, tail_clip_size)
          let head_rect = port_side_rect(head_clip_center, head_clip_size)
          let detour_offset = nodesep_pt * 0.5
          let detour_points =
            match layout_rankdir {
              RankDir::TB | RankDir::BT => {
                let mut side = tail_clip.x - tail_clip_center.x
                if Double::abs(side) <= 0.01 {
                  side = head_clip.x - head_clip_center.x
                }
                if Double::abs(side) <= 0.01 {
                  side = head_clip.x - tail_clip.x
                }
                let detour_x =
                  if side < 0.0 {
                    min_double(tail_rect.llx, head_rect.llx) - detour_offset
                  } else {
                    max_double(tail_rect.urx, head_rect.urx) + detour_offset
                  }
                [
                  tail_clip,
                  point(detour_x, tail_clip.y),
                  point(detour_x, head_clip.y),
                  head_clip,
                ]
              }
              RankDir::LR | RankDir::RL => {
                let mut side = tail_clip.y - tail_clip_center.y
                if Double::abs(side) <= 0.01 {
                  side = head_clip.y - head_clip_center.y
                }
                if Double::abs(side) <= 0.01 {
                  side = head_clip.y - tail_clip.y
                }
                let detour_y =
                  if side < 0.0 {
                    min_double(tail_rect.lly, head_rect.lly) - detour_offset
                  } else {
                    max_double(tail_rect.ury, head_rect.ury) + detour_offset
                  }
                [
                  tail_clip,
                  point(tail_clip.x, detour_y),
                point(head_clip.x, detour_y),
                head_clip,
              ]
            }
          }
          if using_pathplan {
            raw_bezier =
              edge_spline_raw_for_points(
                detour_points,
                tail_slope_line,
                head_slope_line,
                true,
                route_barriers=route_barriers,
              )
          }
          edge_spline_for_points(
            edge,
            detour_points,
            tail_clip_center,
            head_clip_center,
            tail_clip_size,
            head_clip_size,
            tail_slope_line,
            head_slope_line,
            true,
            route_include_tail,
            route_include_head,
            route_barriers=route_barriers,
            arrow_len_override=arrow_len_override,
            tail_cluster_bbox=tail_cluster_bbox,
            head_cluster_bbox=head_cluster_bbox,
            parallel_offset=parallel_offset,
          )
        } else {
          let line_start =
            if using_pathplan && points.length() >= 2 {
              points[0]
            } else {
              tail_anchor
            }
          let line_end =
            if using_pathplan && points.length() >= 2 {
              points[points.length() - 1]
            } else {
              head_anchor
            }
          if using_pathplan {
            let line_points : Array[@geom.Point] =
              if points.length() >= 2 { points } else { [line_start, line_end] }
            raw_bezier =
              edge_spline_raw_for_points(
                line_points,
                tail_slope_line,
                head_slope_line,
                force_segmented,
                route_barriers=route_barriers,
              )
            edge_spline_for_points(
              edge,
              line_points,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              force_segmented,
              route_include_tail,
              route_include_head,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
            )
          } else {
            edge_spline_for_line(
              edge,
              line_start,
              line_end,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              route_include_tail,
              route_include_head,
              layout_rankdir,
              curve_offset,
              curve_skew,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
            )
          }
        }
      }
      routed_spline
    }
  }
  {
    spline,
    label_pad_boost,
    using_pathplan,
    pathplan_boxes,
    pathplan_points,
    raw_bezier,
    apply_dotted_adjustment,
  }
}

///|
/// Graphviz parity: spline finalization aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn finalize_edge_spline(
  base : EdgeRouteBase,
  result : EdgeSplineResult,
) -> @geom.Spline {
  let mut spline = result.spline
  if base.swap_ends {
    spline = reverse_spline(spline)
  }
  if result.apply_dotted_adjustment && base.is_dotted && !base.same_outer_cluster &&
    spline.points.length() > 1 {
    let tuned = spline.points.copy()
    let tail_bias = 0.7
    tuned[1] = {
      x: tuned[1].x,
      y: tuned[1].y * (1.0 - tail_bias) + base.out_tail_anchor.y * tail_bias,
    }
    let head_bias = 0.7
    let last = tuned.length() - 2
    tuned[last] = {
      x: tuned[last].x,
      y: tuned[last].y * (1.0 - head_bias) + base.out_head_anchor.y * head_bias,
    }
    spline = { start: spline.start, end: spline.end, points: tuned }
  }
  spline
}

///|
/// Graphviz parity: edge label placement aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_layout(
  base : EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let edge = base.edge
  let label_rank_info = edge_label_rank_info(edge, ranks)
  let label_rank_y = edge_label_rank_y(edge, ranks, rank_y)
  let label_rank_x = match label_rank_info {
    Some((label_rank, span)) =>
      if span > 1 {
        edge_label_rank_x(
          edge,
          label_rank,
          vnode_info.vnode_ranks,
          vnode_info.edge_vnodes,
          vnode_positions,
        )
      } else {
        None
      }
    None => None
  }
  if @sys.get_env_var("DOT_TRACE_SLACK") is Some(_) &&
    edge.tail().name() == "foo_agent" &&
    edge.head().name() == "zzz_worker" {
    let (rank_label, span) = match label_rank_info {
      Some(value) => value
      None => (-1, 0)
    }
    let rank_x_text = match label_rank_x {
      Some(value) => "\{value}"
      None => "None"
    }
    let rank_y_text = match label_rank_y {
      Some(value) => "\{value}"
      None => "None"
    }
    println(
      "label_rank=\{rank_label} span=\{span} label_rank_x=\{rank_x_text} label_rank_y=\{rank_y_text}",
    )
  }
  let apply_label_pad = has_clusters
  let label_pos : @geom.Point? = match edge.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        match (label_rank_x, label_rank_y, edge_mid_label_metrics(edge)) {
          (Some(rank_x), Some(rank_y), Some((width, height))) => {
            Some(
              edge_label_pos_from_vnode(
                point(rank_x, rank_y),
                width,
                height,
                base.layout_rankdir,
              ),
            )
          }
          _ =>
            if base.is_flat_edge {
              match flat_label_edge_vnodes.get(edge_key(edge)) {
                Some(vnode_name) =>
                  match vnode_positions.get(vnode_name) {
                    Some(pos) => Some(pos)
                    None =>
                      match edge_mid_label_metrics(edge) {
                        Some((_width, height)) => {
                        Some(
                          flat_edge_label_pos_simple(
                              base.out_tail_pos,
                              base.out_head_pos,
                              base.out_tail_size.right_pt,
                              base.out_head_size.left_pt,
                              height,
                            ),
                          )
                        }
                        None =>
                          edge_label_pos(
                            edge,
                            spline,
                            base.out_tail_clip,
                            base.out_head_clip,
                            base.layout_rankdir,
                            label_rank_y,
                            label_rank_x,
                            apply_label_pad,
                            nodesep_pt,
                            spline_result.label_pad_boost,
                          )
                      }
                  }
                None =>
                  match edge_mid_label_metrics(edge) {
                    Some((_width, height)) => {
                      Some(
                        flat_edge_label_pos_simple(
                          base.out_tail_pos,
                          base.out_head_pos,
                          base.out_tail_size.right_pt,
                          base.out_head_size.left_pt,
                          height,
                        ),
                      )
                    }
                    None =>
                      edge_label_pos(
                        edge,
                        spline,
                        base.out_tail_clip,
                        base.out_head_clip,
                        base.layout_rankdir,
                        label_rank_y,
                        label_rank_x,
                        apply_label_pad,
                        nodesep_pt,
                        spline_result.label_pad_boost,
                      )
                  }
              }
            } else {
              edge_label_pos(
                edge,
                spline,
                base.out_tail_clip,
                base.out_head_clip,
                base.layout_rankdir,
                label_rank_y,
                label_rank_x,
                apply_label_pad,
                nodesep_pt,
                spline_result.label_pad_boost,
              )
            }
        }
      }
    None => None
  }
  let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, true)
      }
    None => None
  }
  let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, false)
      }
    None => None
  }
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos: None,
  }
}

///|
/// Graphviz parity: edge routing aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn route_edges(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  splines : SplinesMode,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  ranksep_pt : Double,
  has_clusters : Bool,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  flat_label_edge_vnodes : Map[String, String],
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> Array[DotLayoutEdge] {
  let path_adjacency = routing_context.path_adjacency
  let edges_out : Array[DotLayoutEdge] = []
  dot_trace("layout_dot: routing edges")
  for edge in edges {
    let base = build_edge_route_base(
      graph.kind(),
      edge,
      ranks,
      sizes,
      positions,
      record_orientation,
      label_ports_map,
      label_ports_raw,
      routing_context,
      rankdir,
      layout_rankdir,
      enable_complex_tuning,
      vnode_info.edge_vnodes,
    )
    let spline_result = build_edge_spline(
      base,
      splines,
      ranks,
      sizes,
      positions,
      vnode_positions,
      vnode_info,
      rank_y,
      rank_ht1,
      rank_ht2,
      x_groups,
      nodesep_pt,
      ranksep_pt,
      label_edge_counts,
      head_port_metrics,
      routing_context,
      enable_complex_tuning,
    )
    let spline = finalize_edge_spline(base, spline_result)
    if spline_result.using_pathplan &&
      spline_result.pathplan_boxes.length() > 0 &&
      spline_result.raw_bezier.length() >= 4 {
      let limited_boxes =
        @routesplines.limit_boxes_for_spline(
          spline_result.pathplan_boxes,
          spline_result.raw_bezier,
          fallback_polyline=spline_result.pathplan_points,
        )
      let ordered_vnodes =
        if base.tail_rank <= base.head_rank {
        base.vnodes.copy()
      } else {
        let reversed : Array[String] = []
        let mut idx = base.vnodes.length()
        while idx > 0 {
          idx = idx - 1
          reversed.push(base.vnodes[idx])
        }
        reversed
      }
      if @sys.get_env_var("DOT_TRACE_SLACK") is Some(_) &&
        edge.tail().name() == "foo_agent" &&
        edge.head().name() == "zzz_worker" {
        println(
          "slack edge front_end_jz -> tunnel_ingress raw_bezier=\{spline_result.raw_bezier.length()} boxes=\{limited_boxes.length()}",
        )
        let mut bi = 0
        for box in limited_boxes {
          println(
            "  box[\{bi}] llx=\{box.llx} lly=\{box.lly} urx=\{box.urx} ury=\{box.ury}",
          )
          bi = bi + 1
        }
        for vnode in ordered_vnodes {
          let vnode_rank = match vnode_info.vnode_ranks.get(vnode) {
            Some(value) => value
            None => continue
          }
          let vnode_y = match rank_y.get(vnode_rank) {
            Some(value) => value
            None => continue
          }
          let size = match vnode_info.vnode_sizes.get(vnode) {
            Some(value) => value
            None => continue
          }
          let is_label = size.height_pt > 0.0
          println(
            "  vnode=\{vnode} rank=\{vnode_rank} y=\{vnode_y} label=\{is_label}",
          )
        }
      }
      recover_slack_vnodes(
        edge,
        ordered_vnodes,
        limited_boxes,
        ranks,
        vnode_info.vnode_ranks,
        rank_y,
        vnode_positions,
        vnode_info.vnode_sizes,
        path_adjacency,
      )
    }
    let edge_layout =
      build_edge_layout(
        base,
        spline,
        spline_result,
        ranks,
        rank_y,
        vnode_info,
        vnode_positions,
        nodesep_pt,
        has_clusters,
        flat_label_edge_vnodes,
      )
    edges_out.push(edge_layout)
  }
  edges_out
}
