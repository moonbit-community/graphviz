///|
/// Graphviz parity: label placement aligned to refs/graphviz/lib/common/labels.c (fixtures).
/// Xlabel placement lives in xlabel_layout.mbt (refs/graphviz/lib/label/xlabels.c).
/// Do not change behavior without updating fixtures/tests.
priv enum LabelLoc {
  Top
  Bottom
}

///|
priv enum LabelJust {
  Left
  Center
  Right
}

///|
fn parse_label_loc(value : String?, default_loc : LabelLoc) -> LabelLoc {
  match value {
    Some(text) => {
      let lower = text.to_lower()
      match lower {
        "t" | "top" => LabelLoc::Top
        "b" | "bottom" => LabelLoc::Bottom
        _ => default_loc
      }
    }
    None => default_loc
  }
}

///|
fn parse_label_just(value : String?) -> LabelJust {
  match value {
    Some(text) => {
      let lower = text.to_lower()
      match lower {
        "l" | "left" => LabelJust::Left
        "r" | "right" => LabelJust::Right
        "c" | "center" => LabelJust::Center
        _ => LabelJust::Center
      }
    }
    None => LabelJust::Center
  }
}

///|
fn graph_label_loc(graph : @cgraph.Graph) -> LabelLoc {
  let default_loc = if graph.is_root() {
    LabelLoc::Bottom
  } else {
    LabelLoc::Top
  }
  parse_label_loc(graph.get_attr("labelloc"), default_loc)
}

///|
fn graph_attr_inherited(
  graph : @cgraph.Graph,
  key : String,
) -> String? {
  let mut current = Some(graph)
  while current is Some(_) {
    match current {
      Some(value) =>
        match value.get_attr(key) {
          Some(found) => return Some(found)
          None => current = value.parent()
        }
      None => ()
    }
  }
  None
}

///|
fn graph_label_just(graph : @cgraph.Graph) -> LabelJust {
  parse_label_just(graph_attr_inherited(graph, "labeljust"))
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (Double, Double)? {
  match graph.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(
          graph_attr_inherited(graph, "fontsize"),
        )
        let font = @attrs.font_name(graph_attr_inherited(graph, "fontname"))
        let (width_pt, height_pt) = label_text_dimensions(
          value, font, font_size_pt,
        )
        Some((width_pt, height_pt))
      }
    None => None
  }
}

///|
fn graph_label_pos(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
  just : LabelJust,
) -> @geom.Point {
  let x = match just {
    LabelJust::Left => bbox.llx + label_width_pt / 2.0
    LabelJust::Right => bbox.urx - label_width_pt / 2.0
    LabelJust::Center => (bbox.llx + bbox.urx) / 2.0
  }
  let y = match loc {
    LabelLoc::Top => bbox.ury - label_height_pt / 2.0
    LabelLoc::Bottom => bbox.lly + label_height_pt / 2.0
  }
  { x, y }
}

///|
/// Graphviz parity: flipped cluster label placement aligned to
/// refs/graphviz/lib/common/postproc.c (place_flip_graph_label).
/// Do not change behavior without updating fixtures/tests.
fn graph_label_pos_flip(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
  just : LabelJust,
) -> @geom.Point {
  let x = match loc {
    LabelLoc::Top => bbox.urx - label_width_pt / 2.0
    LabelLoc::Bottom => bbox.llx + label_width_pt / 2.0
  }
  let y = match just {
    LabelJust::Left => bbox.ury - label_height_pt / 2.0
    LabelJust::Right => bbox.lly + label_height_pt / 2.0
    LabelJust::Center => (bbox.lly + bbox.ury) / 2.0
  }
  { x, y }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b { a } else { b }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

///|
fn rect_from_center(
  center : @geom.Point,
  width : Double,
  height : Double,
  pad : Double,
) -> @geom.Rect {
  let half_w = width / 2.0 + pad
  let half_h = height / 2.0 + pad
  {
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  }
}

///|
priv struct EdgeLabelEntry {
  key : String
  pos : @geom.Point
  base_axis : Double
  half_axis : Double
}

///|
fn rect_overlap_amount(
  a : @geom.Rect,
  b : @geom.Rect,
) -> (Double, Double)? {
  let overlap_x = min_double(a.urx, b.urx) - max_double(a.llx, b.llx)
  let overlap_y = min_double(a.ury, b.ury) - max_double(a.lly, b.lly)
  if overlap_x > 0.0 && overlap_y > 0.0 {
    Some((overlap_x, overlap_y))
  } else {
    None
  }
}

///|
fn nudge_label_rect(
  label_pos : @geom.Point,
  label_rect : @geom.Rect,
  other_rect : @geom.Rect,
  label_width : Double,
  label_height : Double,
  pad : Double,
) -> (@geom.Point, @geom.Rect) {
  match rect_overlap_amount(label_rect, other_rect) {
    Some((overlap_x, overlap_y)) => {
      let other_center : @geom.Point = {
        x: (other_rect.llx + other_rect.urx) / 2.0,
        y: (other_rect.lly + other_rect.ury) / 2.0,
      }
      if overlap_x < overlap_y {
        let dir = if label_pos.x < other_center.x { -1.0 } else { 1.0 }
        let shift = overlap_x + pad
        let new_pos : @geom.Point = {
          x: label_pos.x + dir * shift,
          y: label_pos.y,
        }
        (new_pos, rect_from_center(new_pos, label_width, label_height, pad))
      } else {
        let dir = if label_pos.y < other_center.y { -1.0 } else { 1.0 }
        let shift = overlap_y + pad
        let new_pos : @geom.Point = {
          x: label_pos.x,
          y: label_pos.y + dir * shift,
        }
        (new_pos, rect_from_center(new_pos, label_width, label_height, pad))
      }
    }
    None => (label_pos, label_rect)
  }
}

///|
fn edge_tail_point(edge_layout : DotLayoutEdge) -> @geom.Point? {
  match edge_layout.splines.get(0) {
    Some(spline) =>
      match spline.start {
        Some(point) => Some(point)
        None =>
          if spline.points.length() > 0 { Some(spline.points[0]) } else { None }
      }
    None => None
  }
}

///|
fn bezier_point(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let p01 = @edge_spline.point_lerp(p0, p1, t)
  let p12 = @edge_spline.point_lerp(p1, p2, t)
  let p23 = @edge_spline.point_lerp(p2, p3, t)
  let p012 = @edge_spline.point_lerp(p01, p12, t)
  let p123 = @edge_spline.point_lerp(p12, p23, t)
  @edge_spline.point_lerp(p012, p123, t)
}

///|
/// Graphviz parity: linear interpolation aligned to refs/graphviz/lib/common/utils.c
/// (Bezier helper, uses fused multiply-add to match Graphviz compiler output).
/// Do not change behavior without updating fixtures/tests.
fn point_lerp_fma(
  a : @geom.Point,
  b : @geom.Point,
  t : Double,
) -> @geom.Point {
  let mt = 1.0 - t
  let x = @edge_spline.libm_fma(mt, a.x, t * b.x)
  let y = @edge_spline.libm_fma(mt, a.y, t * b.y)
  @edge_spline.point(x, y)
}

///|
/// Graphviz parity: Bézier evaluation aligned to refs/graphviz/lib/common/utils.c
/// (Bezier).
/// Do not change behavior without updating fixtures/tests.
fn bezier_point_fma(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let vtemp : Array[Array[@geom.Point]] = []
  let mut row = 0
  while row < 4 {
    let line : Array[@geom.Point] = []
    let mut col = 0
    while col < 4 {
      line.push(@edge_spline.point(0.0, 0.0))
      col = col + 1
    }
    vtemp.push(line)
    row = row + 1
  }
  vtemp[0][0] = p0
  vtemp[0][1] = p1
  vtemp[0][2] = p2
  vtemp[0][3] = p3
  let mut i = 1
  while i <= 3 {
    let mut j = 0
    while j <= 3 - i {
      let a = vtemp[i - 1][j]
      let b = vtemp[i - 1][j + 1]
      vtemp[i][j] = point_lerp_fma(a, b, t)
      j = j + 1
    }
    i = i + 1
  }
  vtemp[3][0]
}

///|
fn sample_spline_points(
  points : Array[@geom.Point],
  steps : Int,
) -> Array[@geom.Point] {
  let samples : Array[@geom.Point] = []
  if points.length() == 0 || steps <= 0 {
    return samples
  }
  samples.push(points[0])
  let mut index = 0
  let step_count = steps.to_double()
  while index + 3 < points.length() {
    let p0 = points[index]
    let p1 = points[index + 1]
    let p2 = points[index + 2]
    let p3 = points[index + 3]
    for step in 1..=steps {
      let t = step.to_double() / step_count
      samples.push(bezier_point(p0, p1, p2, p3, t))
    }
    index = index + 3
  }
  samples
}

///|
fn polyline_point_with_dir(
  points : Array[@geom.Point],
  target_len : Double,
) -> (@geom.Point, @geom.Point)? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some((points[0], @edge_spline.point(1.0, 0.0)))
  }
  let mut remaining = target_len
  let mut last_dir = @edge_spline.point(1.0, 0.0)
  let mut last_pos = points[points.length() - 1]
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = @edge_spline.segment_length(a, b)
    if seg_len > 0.0 {
      let delta = @edge_spline.point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      if len > 0.0 {
        last_dir = @edge_spline.point_scale(delta, 1.0 / len)
        last_pos = b
      }
    }
    if seg_len <= 0.0 {
      continue
    }
    if remaining <= seg_len {
      let t = remaining / seg_len
      let pos = @edge_spline.point_lerp(a, b, t)
      let delta = @edge_spline.point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let dir =
        if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
      return Some((pos, dir))
    }
    remaining = remaining - seg_len
  }
  Some((last_pos, last_dir))
}

///|
fn polyline_point_at_axis(
  points : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> (@geom.Point, @geom.Point)? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some((points[0], @edge_spline.point(1.0, 0.0)))
  }
  let total_len = @edge_spline.polyline_length(points)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  let epsilon = 0.000001
  let mut traveled = 0.0
  let mut best_pos : @geom.Point? = None
  let mut best_dir : @geom.Point? = None
  let mut best_dist = 0.0
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = @edge_spline.segment_length(a, b)
    let a_axis = if axis_is_x { a.x } else { a.y }
    let b_axis = if axis_is_x { b.x } else { b.y }
    let min_axis = if a_axis < b_axis { a_axis } else { b_axis }
    let max_axis = if a_axis < b_axis { b_axis } else { a_axis }
    if axis_value < min_axis || axis_value > max_axis {
      traveled = traveled + seg_len
      continue
    }
    let delta_axis = b_axis - a_axis
    let t =
      if Double::abs(delta_axis) <= epsilon {
        0.5
      } else {
        (axis_value - a_axis) / delta_axis
      }
    let pos = @edge_spline.point_lerp(a, b, t)
    let delta = @edge_spline.point_sub(b, a)
    let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
    let dir =
      if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
    let cross_len = traveled + seg_len * t
    let dist = Double::abs(cross_len - target)
    if best_pos is None || dist < best_dist {
      best_pos = Some(pos)
      best_dir = Some(dir)
      best_dist = dist
    }
    traveled = traveled + seg_len
  }
  match best_pos {
    Some(pos) =>
      match best_dir {
        Some(dir) => Some((pos, dir))
        None => None
      }
    None => None
  }
}

///|
fn spline_label_pos_with_samples(
  samples : Array[@geom.Point],
) -> (@geom.Point, @geom.Point)? {
  if samples.length() == 0 {
    return None
  }
  let total_len = @edge_spline.polyline_length(samples)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  polyline_point_with_dir(samples, target)
}

///|
fn spline_label_pos_at_samples(
  samples : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> (@geom.Point, @geom.Point)? {
  if samples.length() == 0 {
    return None
  }
  polyline_point_at_axis(samples, axis_value, axis_is_x)
}

///|
fn edge_label_rank_info(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
) -> (Int, Int)? {
  if edge_mid_label_width_pt(edge) <= 0.0 {
    return None
  }
  let tail_rank = match ranks.get(edge.tail().name()) {
    Some(value) => value
    None => return None
  }
  let head_rank = match ranks.get(edge.head().name()) {
    Some(value) => value
    None => return None
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  let span = max_rank - min_rank
  if span <= 1 {
    return None
  }
  let label_rank = (min_rank + max_rank) / 2
  Some((label_rank, span))
}

///|
fn edge_label_rank_y(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
) -> Double? {
  match edge_label_rank_info(edge, ranks) {
    Some((label_rank, _span)) => rank_y.get(label_rank)
    None => None
  }
}

///|
fn edge_label_rank_x(
  edge : @cgraph.Edge,
  label_rank : Int,
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_positions : Map[String, @geom.Point],
) -> Double? {
  match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(vnodes) =>
      for name in vnodes {
        match vnode_ranks.get(name) {
          Some(rank) =>
            if rank == label_rank {
              match vnode_positions.get(name) {
                Some(pos) => return Some(pos.x)
                None => ()
              }
            }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
/// Graphviz parity: label vnode offset aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// (place_vnlabel, GD_flip).
/// Do not change behavior without updating fixtures/tests.
fn edge_label_pos_from_vnode(
  vnode_pos : @geom.Point,
  label_width_pt : Double,
  label_height_pt : Double,
  rankdir : RankDir,
) -> @geom.Point {
  let width =
    if rankdir == RankDir::LR || rankdir == RankDir::RL {
      label_height_pt
    } else {
      label_width_pt
    }
  @edge_spline.point(vnode_pos.x + width / 2.0, vnode_pos.y)
}

///|
fn vnode_is_merged(
  name : String,
  adjacency : @routesplines.PathAdjacency,
) -> Bool {
  let out_raw = match adjacency.out_edges.get(name) {
    Some(list) => list
    None => []
  }
  let in_raw = match adjacency.in_edges.get(name) {
    Some(list) => list
    None => []
  }
  let unique_count = (list : Array[String]) => {
    let seen : Map[String, Bool] = Map::new()
    let mut count = 0
    for item in list {
      if seen.get(item) is None {
        seen[item] = true
        count = count + 1
      }
    }
    count
  }
  // Graphviz virtual edges can carry parallel multiplicity on one edge record.
  // Our path adjacency lists parallel hops explicitly, so merge detection must
  // compare distinct predecessors/successors instead of raw multiplicity.
  let out_count = unique_count(out_raw)
  let in_count = unique_count(in_raw)
  out_count > 1 || in_count > 1
}

///|
/// Graphviz parity: recover_slack aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
fn recover_slack_vnodes(
  edge : @cgraph.Edge,
  ordered_vnodes : Array[String],
  boxes : Array[@geom.Rect],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_positions : Map[String, @geom.Point],
  vnode_sizes : Map[String, NodeSize],
  adjacency : @routesplines.PathAdjacency,
) -> Unit {
  if ordered_vnodes.length() == 0 || boxes.length() == 0 {
    return ()
  }
  let trace_recover = @sys.get_env_var("DOT_TRACE_RECOVER") is Some(_)
  let tail_name = edge.tail().name()
  let head_name = edge.head().name()
  let label_rank = match edge_label_rank_info(edge, ranks) {
    Some((rank, _span)) => rank
    None => -1
  }
  let mut box_idx = 0
  for vnode in ordered_vnodes {
    if vnode_is_merged(vnode, adjacency) {
      break
    }
    let vnode_rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let vnode_y = match rank_y.get(vnode_rank) {
      Some(value) => value
      None => continue
    }
    while box_idx < boxes.length() && boxes[box_idx].lly > vnode_y {
      box_idx = box_idx + 1
    }
    if box_idx >= boxes.length() {
      break
    }
    let box = boxes[box_idx]
    if box.ury < vnode_y {
      continue
    }
    let size = match vnode_sizes.get(vnode) {
      Some(value) => value
      None => continue
    }
    let old_pos = match vnode_positions.get(vnode) {
      Some(value) => value
      None => { x: 0.0, y: vnode_y }
    }
    let old_left = size.left_pt
    let old_right = size.right_pt
    if vnode_rank == label_rank {
      let new_x = box.urx
      let left = new_x - box.llx
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        vnode_size_from_widths_with_height(left, size.right_pt, size.height_pt)
    } else {
      let new_x = (box.llx + box.urx) / 2.0
      let half = (box.urx - box.llx) / 2.0
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        vnode_size_from_widths_with_height(half, half, size.height_pt)
    }
    if trace_recover {
      let new_pos = match vnode_positions.get(vnode) {
        Some(value) => value
        None => { x: 0.0, y: vnode_y }
      }
      let new_size = match vnode_sizes.get(vnode) {
        Some(value) => value
        None => size
      }
      let is_label = vnode_rank == label_rank
      println(
        "{\"event\":\"recover_slack\",\"tail\":\"\{tail_name}\",\"head\":\"\{head_name}\",\"rank\":\{vnode_rank},\"label\":\{is_label},\"vnode\":\"\{vnode}\",\"box\":{\"llx\":\{box.llx},\"lly\":\{box.lly},\"urx\":\{box.urx},\"ury\":\{box.ury}},\"old\":{\"x\":\{old_pos.x},\"lw\":\{old_left},\"rw\":\{old_right}},\"new\":{\"x\":\{new_pos.x},\"lw\":\{new_size.left_pt},\"rw\":\{new_size.right_pt}}}",
      )
    }
  }
}

///|
fn flat_edge_label_pos_simple(
  tail_port : @geom.Point,
  head_port : @geom.Point,
  tail_right_pt : Double,
  head_left_pt : Double,
  label_height_pt : Double,
) -> @geom.Point {
  let left_end = tail_port.x + tail_right_pt
  let right_end = head_port.x - head_left_pt
  let ctrx = (left_end + right_end) / 2.0
  let ctry = tail_port.y + (label_height_pt + EDGE_LABEL_FLAT_SPACE_PT) / 2.0
  @edge_spline.point(ctrx, ctry)
}

///|
fn port_label_params(edge : @cgraph.Edge) -> (Double, Double)? {
  let angle_attr = edge.get_attr("labelangle")
  let distance_attr = edge.get_attr("labeldistance")
  let has_angle = match angle_attr {
    Some(value) => value != ""
    None => false
  }
  let has_distance = match distance_attr {
    Some(value) => value != ""
    None => false
  }
  if !has_angle && !has_distance {
    return None
  }
  let angle_deg = match angle_attr {
    Some(value) =>
      if value == "" {
        PORT_LABEL_ANGLE_DEG
      } else {
        parse_attr_double(value, PORT_LABEL_ANGLE_DEG, PORT_LABEL_ANGLE_MIN_DEG)
      }
    None => PORT_LABEL_ANGLE_DEG
  }
  let distance_scale = match distance_attr {
    Some(value) =>
      if value == "" {
        1.0
      } else {
        parse_attr_double(value, 1.0, 0.0)
      }
    None => 1.0
  }
  Some((angle_deg, distance_scale))
}

fn port_label_points(
  spline : @geom.Spline,
  head_p : Bool,
  marker_present : Bool,
) -> (@geom.Point, @geom.Point)? {
  // Graphviz parity: place_portlabel uses eflag/sflag to choose marker tangent
  // (marker present => use marker+endpoint tangent, absent => use Bezier sample).
  let points = spline.points
  if points.length() < 4 {
    return None
  }
  if head_p {
    match spline.end {
      Some(end_point) =>
        if marker_present {
          Some((end_point, points[points.length() - 1]))
        } else {
          let start = points.length() - 4
          let p0 = points[start]
          let p1 = points[start + 1]
          let p2 = points[start + 2]
          let p3 = points[start + 3]
          Some((p3, bezier_point_fma(p0, p1, p2, p3, 0.9)))
        }
      None => {
        let start = points.length() - 4
        let p0 = points[start]
        let p1 = points[start + 1]
        let p2 = points[start + 2]
        let p3 = points[start + 3]
        Some((p3, bezier_point_fma(p0, p1, p2, p3, 0.9)))
      }
    }
  } else {
    match spline.start {
      Some(start_point) =>
        if marker_present {
          Some((start_point, points[0]))
        } else {
          let p0 = points[0]
          let p1 = points[1]
          let p2 = points[2]
          let p3 = points[3]
          Some((p0, bezier_point_fma(p0, p1, p2, p3, 0.1)))
        }
      None => {
        let p0 = points[0]
        let p1 = points[1]
        let p2 = points[2]
        let p3 = points[3]
        Some((p0, bezier_point_fma(p0, p1, p2, p3, 0.1)))
      }
    }
  }
}

///|
fn port_label_pos_from_points(
  pe : @geom.Point,
  pf : @geom.Point,
  angle_deg : Double,
  distance_scale : Double,
) -> @geom.Point {
  let angle =
    @edge_spline.libm_fma(
      angle_deg / 180.0,
      GRAPHVIZ_PI,
      @edge_spline.libm_atan2(pf.y - pe.y, pf.x - pe.x),
    )
  let dist = PORT_LABEL_DISTANCE_PT * distance_scale
  @edge_spline.point(
    @edge_spline.libm_fma(dist, @edge_spline.libm_cos(angle), pe.x),
    @edge_spline.libm_fma(dist, @edge_spline.libm_sin(angle), pe.y),
  )
}

///|
fn edge_port_label_pos(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  head_p : Bool,
) -> @geom.Point? {
  let arrow_is_none = (value : String?) => {
    match value {
      Some(v) => v.trim().to_lower() == "none"
      None => false
    }
  }
  let dir = edge_dir_for(edge, edge.tail().graph().kind())
  // Graphviz parity: map edge dir + arrow attrs to place_portlabel eflag/sflag.
  let marker_present =
    if head_p {
      match dir {
        EdgeDir::Forward | EdgeDir::Both =>
          !arrow_is_none(edge.get_attr("arrowhead"))
        _ => false
      }
    } else {
      match dir {
        EdgeDir::Back | EdgeDir::Both =>
          !arrow_is_none(edge.get_attr("arrowtail"))
        _ => false
      }
    }
  match port_label_params(edge) {
    Some((angle_deg, distance_scale)) =>
      match port_label_points(spline, head_p, marker_present) {
        Some((pe, pf)) =>
          Some(port_label_pos_from_points(pe, pf, angle_deg, distance_scale))
        None => None
      }
    None => None
  }
}

///|
/// Graphviz parity: edge label midpoint placement aligned to refs/graphviz/lib/common/labels.c.
/// Do not change behavior without updating fixtures/tests.
fn edge_label_pos(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  tail_clip : @geom.Point,
  head_clip : @geom.Point,
  rankdir : RankDir,
  label_rank_y : Double?,
  label_rank_x : Double?,
  apply_label_pad : Bool,
  nodesep_pt : Double,
  label_pad_boost : Double,
) -> @geom.Point? {
  let samples = sample_spline_points(spline.points, 96)
  let fallback = match spline_label_pos_with_samples(samples) {
    Some((pos, tangent)) => (pos, tangent)
    None => {
      let mid = @edge_spline.point(
        (tail_clip.x + head_clip.x) / 2.0,
        (tail_clip.y + head_clip.y) / 2.0,
      )
      let delta = @edge_spline.point_sub(head_clip, tail_clip)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let tangent =
        if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
      (mid, tangent)
    }
  }
  let (raw_pos, dir) = match label_rank_y {
    Some(axis) =>
      match spline_label_pos_at_samples(
        samples,
        axis,
        false,
      ) {
        Some((pos, tangent)) => (pos, tangent)
        None => fallback
      }
    None => fallback
  }
  let base_pos =
    match (label_rank_x, label_rank_y) {
      (Some(x_axis), Some(y_axis)) =>
        match rankdir {
          RankDir::LR | RankDir::RL => @edge_spline.point(y_axis, x_axis)
          _ => @edge_spline.point(x_axis, y_axis)
        }
      (Some(value), None) =>
        match rankdir {
          RankDir::LR | RankDir::RL => @edge_spline.point(raw_pos.x, value)
          _ => @edge_spline.point(value, raw_pos.y)
        }
      _ => raw_pos
    }
  if edge.tail().name() == edge.head().name() {
    return Some(base_pos)
  }
  match label_rank_y {
    Some(_) =>
      match edge_mid_label_metrics(edge) {
        Some((width, height)) => {
          let half_extent = match rankdir {
            RankDir::LR | RankDir::RL => height / 2.0
            _ => width / 2.0
          }
          let sign = match rankdir {
            RankDir::RL => -1.0
            _ => 1.0
          }
          let mut pad = label_pad_boost
          if label_rank_x is None {
            if apply_label_pad {
              pad = pad + nodesep_pt * 0.22
            } else if width >= EDGE_LABEL_PAD_WIDTH_PT {
              pad = pad + nodesep_pt * 0.22
            }
          } else {
            pad = 0.0
          }
          Some(@edge_spline.point(base_pos.x + sign * (half_extent + pad), base_pos.y))
        }
        None => Some(base_pos)
      }
    None => {
      let (width, height) = match edge_mid_label_metrics(edge) {
        Some((w, h)) => (w, h)
        None => return Some(base_pos)
      }
      let normal = @edge_spline.point(-dir.y, dir.x)
      let axis_threshold = 0.1
      let abs_dx = Double::abs(dir.x)
      let abs_dy = Double::abs(dir.y)
      if spline.points.length() > 4 &&
        abs_dx > axis_threshold &&
        abs_dy > axis_threshold {
        return Some(base_pos)
      }
      let offset =
        if abs_dx <= axis_threshold {
          width / 2.0
        } else if abs_dy <= axis_threshold {
          height / 2.0
        } else {
          0.0
        }
      if offset <= 0.0 {
        Some(base_pos)
      } else {
        let pad = label_pad_boost
        Some(@edge_spline.point_add(base_pos, @edge_spline.point_scale(normal, offset + pad)))
      }
    }
  }
}

///|
fn collect_cluster_label_rects(
  graphs : Array[DotLayoutGraph],
  pad : Double,
) -> Array[@geom.Rect] {
  let rects : Array[@geom.Rect] = []
  for subgraph in graphs {
    match subgraph.label_pos {
      Some(pos) =>
        match graph_label_metrics(subgraph.graph) {
          Some((width, height)) => rects.push(rect_from_center(pos, width, height, pad))
          None => ()
        }
      None => ()
    }
    let nested = collect_cluster_label_rects(subgraph.subgraphs, pad)
    for rect in nested {
      rects.push(rect)
    }
  }
  rects
}

///|
fn adjust_edge_label_positions(
  edges : Array[DotLayoutEdge],
  label_rects : Array[@geom.Rect],
  pad : Double,
) -> (Array[DotLayoutEdge], Map[String, @geom.Point]) {
  let adjusted : Array[DotLayoutEdge] = []
  let updates : Map[String, @geom.Point] = Map::new()
  for edge_layout in edges {
    let mut label_pos = edge_layout.label_pos
    match label_pos {
      Some(pos) =>
        match edge_mid_label_metrics(edge_layout.edge) {
          Some((width, height)) => {
            let mut current_pos = pos
            let mut current_rect = rect_from_center(current_pos, width, height, pad)
            for rect in label_rects {
              let (next_pos, next_rect) = nudge_label_rect(
                current_pos,
                current_rect,
                rect,
                width,
                height,
                pad,
              )
              current_pos = next_pos
              current_rect = next_rect
            }
            label_pos = Some(current_pos)
          }
          None => ()
        }
      None => ()
    }
    match label_pos {
      Some(pos) => updates[@dot_shared.edge_key(edge_layout.edge)] = pos
      None => ()
    }
    adjusted.push({
      edge: edge_layout.edge,
      splines: edge_layout.splines,
      label_pos,
      head_label_pos: edge_layout.head_label_pos,
      tail_label_pos: edge_layout.tail_label_pos,
      xlabel_pos: edge_layout.xlabel_pos,
    })
  }
  (adjusted, updates)
}

///|
fn apply_edge_label_updates(
  graphs : Array[DotLayoutGraph],
  updates : Map[String, @geom.Point],
) -> Array[DotLayoutGraph] {
  let updated : Array[DotLayoutGraph] = []
  for graph in graphs {
    let edges : Array[DotLayoutEdge] = []
    for edge_layout in graph.edges {
      let label_pos = match updates.get(@dot_shared.edge_key(edge_layout.edge)) {
        Some(pos) => Some(pos)
        None => edge_layout.label_pos
      }
      edges.push({
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos,
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
        xlabel_pos: edge_layout.xlabel_pos,
      })
    }
    let subgraphs = apply_edge_label_updates(graph.subgraphs, updates)
    updated.push({
      graph: graph.graph,
      bbox: graph.bbox,
      label_pos: graph.label_pos,
      nodes: graph.nodes,
      edges,
      subgraphs,
    })
  }
  updated
}

///|
fn adjust_edge_labels_for_clusters(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
) -> DotLayoutGraph {
  let pad = if nodesep_pt * 0.2 < 2.0 { 2.0 } else { nodesep_pt * 0.2 }
  let label_rects : Array[@geom.Rect] = []
  match layout.label_pos {
    Some(pos) =>
      match graph_label_metrics(layout.graph) {
        Some((width, height)) =>
          label_rects.push(rect_from_center(pos, width, height, pad))
        None => ()
      }
    None => ()
  }
  let subgraph_rects = collect_cluster_label_rects(layout.subgraphs, pad)
  for rect in subgraph_rects {
    label_rects.push(rect)
  }
  if label_rects.length() == 0 {
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in layout.subgraphs {
      subgraphs.push(
        adjust_edge_labels_for_clusters(subgraph, nodesep_pt),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs,
    }
  } else {
    let (edges, updates) = adjust_edge_label_positions(
      layout.edges,
      label_rects,
      pad,
    )
    let updated_subgraphs = apply_edge_label_updates(layout.subgraphs, updates)
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in updated_subgraphs {
      subgraphs.push(
        adjust_edge_labels_for_clusters(subgraph, nodesep_pt),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges,
      subgraphs,
    }
  }
}

///|
fn adjust_edge_labels_for_overlaps(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  let axis_is_x = match rankdir {
    RankDir::TB | RankDir::BT => true
    RankDir::LR | RankDir::RL => false
  }
  let tail_pad = max_double(2.0, nodesep_pt * 0.3)
  let gap = max_double(4.0, nodesep_pt * 0.8)
  let groups : Map[String, Array[EdgeLabelEntry]] = Map::new()
  for edge_layout in layout.edges {
    match edge_layout.label_pos {
      Some(pos) =>
        match edge_mid_label_metrics(edge_layout.edge) {
          Some((width, height)) => {
            let pos_axis = if axis_is_x { pos.x } else { pos.y }
            let tail_axis = match edge_tail_point(edge_layout) {
              Some(point) => if axis_is_x { point.x } else { point.y }
              None => pos_axis
            }
            let base_axis =
              if tail_axis + tail_pad > pos_axis { tail_axis + tail_pad } else { pos_axis }
            let half_axis = if axis_is_x { width / 2.0 } else { height / 2.0 }
            let entry = {
              key: @dot_shared.edge_key(edge_layout.edge),
              pos,
              base_axis,
              half_axis,
            }
            let tail_name = edge_layout.edge.tail().name()
            let list = match groups.get(tail_name) {
              Some(value) => value
              None => []
            }
            list.push(entry)
            groups[tail_name] = list
          }
          None => ()
        }
      None => ()
    }
  }
  let updates : Map[String, @geom.Point] = Map::new()
  for _, entries in groups {
    if entries.length() < 2 {
      continue
    }
    entries.sort_by((a, b) => Double::compare(a.base_axis, b.base_axis))
    let mut last_axis = 0.0
    let mut last_half = 0.0
    let mut first = true
    for entry in entries {
      let mut axis_value = entry.base_axis
      if !first {
        let min_axis = last_axis + last_half + entry.half_axis + gap
        if axis_value < min_axis {
          axis_value = min_axis
        }
      }
      let new_pos : @geom.Point =
        if axis_is_x {
        { x: axis_value, y: entry.pos.y }
      } else {
        { x: entry.pos.x, y: axis_value }
      }
      if new_pos.x != entry.pos.x || new_pos.y != entry.pos.y {
        updates[entry.key] = new_pos
      }
      last_axis = axis_value
      last_half = entry.half_axis
      first = false
    }
  }
  if updates.length() == 0 {
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in layout.subgraphs {
      subgraphs.push(
        adjust_edge_labels_for_overlaps(subgraph, nodesep_pt, rankdir),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs,
    }
  } else {
    let edges : Array[DotLayoutEdge] = []
    for edge_layout in layout.edges {
      let label_pos = match updates.get(@dot_shared.edge_key(edge_layout.edge)) {
        Some(pos) => Some(pos)
        None => edge_layout.label_pos
      }
      edges.push({
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos,
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
        xlabel_pos: edge_layout.xlabel_pos,
      })
    }
    let updated_subgraphs = apply_edge_label_updates(layout.subgraphs, updates)
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in updated_subgraphs {
      subgraphs.push(
        adjust_edge_labels_for_overlaps(subgraph, nodesep_pt, rankdir),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges,
      subgraphs,
    }
  }
}

///|
fn edge_label_adjust_enabled() -> Bool {
  match @sys.get_env_var("DOT_ADJUST_EDGE_LABELS") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "" && lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}

///|
fn cluster_rounding_enabled() -> Bool {
  match @sys.get_env_var("DOT_ADJUST_CLUSTER_ROUNDING") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "" && lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}

///|
fn expand_bbox_for_label(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
) -> @geom.Rect {
  let pad = 8.0
  let mut llx = bbox.llx
  let mut lly = bbox.lly
  let mut urx = bbox.urx
  let mut ury = bbox.ury
  match loc {
    LabelLoc::Top => ury = ury + label_height_pt + pad
    LabelLoc::Bottom => lly = lly - label_height_pt - pad
  }
  let label_width = label_width_pt + pad * 2.0
  let current_width = urx - llx
  if label_width > current_width {
    let extra = label_width - current_width
    llx = llx - extra / 2.0
    urx = urx + extra / 2.0
  }
  { llx, lly, urx, ury }
}
