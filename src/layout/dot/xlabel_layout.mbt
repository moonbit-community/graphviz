///|
/// Graphviz parity: exterior label placement aligned to refs/graphviz/lib/label/xlabels.c
/// + lib/common/postproc.c (addXLabels/edgeMidpoint).
/// Do not change behavior without updating fixtures/tests.
const XLXDENOM : Double = 8.0

///|
const XLYDENOM : Double = 2.0

///|
const MILLIPOINT : Double = 0.001

const XLPXPY : Int = 0
const XLCXPY : Int = 1
const XLNXPY : Int = 2
const XLPXCY : Int = 3
const XLCXCY : Int = 4
const XLNXCY : Int = 5
const XLPXNY : Int = 6
const XLCXNY : Int = 7
const XLNXNY : Int = 8

///|
priv enum XLabelTarget {
  Node(String)
  EdgeMid(String)
  EdgeHead(String)
  EdgeTail(String)
  EdgeXlabel(String)
}

///|
priv struct XLabel {
  target : XLabelTarget
  width : Double
  height : Double
  pos : @geom.Point
  set : Bool
}

///|
priv struct XObject {
  pos : @geom.Point
  width : Double
  height : Double
  label_index : Int?
}

///|
priv struct XBestPos {
  n : Int
  area : Double
  pos : @geom.Point
}

fn xlabel_metrics_for_node(node : @cgraph.Node) -> (Double, Double)? {
  match node.get_attr("xlabel") {
    Some(text) =>
      if text == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
        let font = @attrs.font_name(node.get_attr("fontname"))
        let (width, height) = label_text_dimensions(text, font, font_size_pt)
        Some((width, height))
      }
    None => None
  }
}

fn xlabel_metrics_for_edge(edge : @cgraph.Edge) -> (Double, Double)? {
  edge_label_metrics_for_attr(edge, "xlabel", false)
}

fn rect_overlap_area(a : @geom.Rect, b : @geom.Rect) -> Double {
  let min_x = if a.llx > b.llx { a.llx } else { b.llx }
  let max_x = if a.urx < b.urx { a.urx } else { b.urx }
  let min_y = if a.lly > b.lly { a.lly } else { b.lly }
  let max_y = if a.ury < b.ury { a.ury } else { b.ury }
  if max_x > min_x && max_y > min_y {
    (max_x - min_x) * (max_y - min_y)
  } else {
    0.0
  }
}

fn rect_from_object(obj : XObject) -> @geom.Rect {
  let llx = obj.pos.x.round()
  let lly = obj.pos.y.round()
  let urx = (obj.pos.x + obj.width).round()
  let ury = (obj.pos.y + obj.height).round()
  { llx, lly, urx, ury }
}

fn rect_from_label(label : XLabel) -> @geom.Rect {
  let llx = label.pos.x.round()
  let lly = label.pos.y.round()
  let urx = (label.pos.x + label.width).round()
  let ury = (label.pos.y + label.height).round()
  { llx, lly, urx, ury }
}

fn label_encloses_point(label : XLabel, point_obj : XObject) -> Bool {
  let px = point_obj.pos.x
  let py = point_obj.pos.y
  px > label.pos.x &&
    px < label.pos.x + label.width &&
    py > label.pos.y &&
    py < label.pos.y + label.height
}

fn get_intrsx_index(
  op : XObject,
  cp : XObject,
  labels : Array[XLabel],
) -> Int {
  let op_set = match op.label_index {
    Some(idx) => labels[idx].set
    None => false
  }
  let cp_set = match cp.label_index {
    Some(idx) => labels[idx].set
    None => false
  }
  if !op_set || !cp_set {
    return -1
  }
  if (op.pos.x == 0.0 && op.pos.y == 0.0) ||
    (cp.pos.x == 0.0 && cp.pos.y == 0.0) {
    return -1
  }
  if cp.pos.y < op.pos.y {
    if cp.pos.x < op.pos.x {
      return XLPXPY
    }
    if cp.pos.x > op.pos.x {
      return XLNXPY
    }
    return XLCXPY
  }
  if cp.pos.y > op.pos.y {
    if cp.pos.x < op.pos.x {
      return XLPXNY
    }
    if cp.pos.x > op.pos.x {
      return XLNXNY
    }
    return XLCXNY
  }
  if cp.pos.x < op.pos.x {
    return XLPXCY
  }
  if cp.pos.x > op.pos.x {
    return XLNXCY
  }
  -1
}

fn record_obj_intersection(
  objs : Array[XObject],
  labels : Array[XLabel],
  op_idx : Int,
  cp_idx : Int,
  rect : @geom.Rect,
  area : Double,
  intrsx : Array[Int?],
) -> Double {
  let op = objs[op_idx]
  let cp = objs[cp_idx]
  let mut idx = get_intrsx_index(op, cp, labels)
  if idx < 0 {
    idx = XLCXCY
  }
  match intrsx[idx] {
    Some(existing_idx) => {
      let mut max_area = 0.0
      let srect = rect_from_object(objs[existing_idx])
      let sa = rect_overlap_area(rect, srect)
      if sa > area {
        max_area = sa
      }
      match objs[existing_idx].label_index {
        Some(label_idx) => {
          let existing_label = labels[label_idx]
          let srect = rect_from_label(existing_label)
          let sa = rect_overlap_area(rect, srect)
          if sa > area && sa > max_area {
            max_area = sa
          }
        }
        None => ()
      }
      if max_area > 0.0 {
        return max_area
      }
      intrsx[idx] = Some(cp_idx)
      area
    }
    None => {
      intrsx[idx] = Some(cp_idx)
      area
    }
  }
}

fn record_label_intersection(
  objs : Array[XObject],
  labels : Array[XLabel],
  op_idx : Int,
  cp_idx : Int,
  rect : @geom.Rect,
  area : Double,
  intrsx : Array[Int?],
) -> Double {
  let op = objs[op_idx]
  let cp = objs[cp_idx]
  let mut idx = get_intrsx_index(op, cp, labels)
  if idx < 0 {
    idx = XLCXCY
  }
  match intrsx[idx] {
    Some(existing_idx) => {
      let mut max_area = 0.0
      let srect = rect_from_object(objs[existing_idx])
      let sa = rect_overlap_area(rect, srect)
      if sa > area {
        max_area = sa
      }
      match objs[existing_idx].label_index {
        Some(label_idx) => {
          let existing_label = labels[label_idx]
          let srect = rect_from_label(existing_label)
          let sa = rect_overlap_area(rect, srect)
          if sa > area && sa > max_area {
            max_area = sa
          }
        }
        None => ()
      }
      if max_area > 0.0 {
        return max_area
      }
      intrsx[idx] = Some(cp_idx)
      area
    }
    None => {
      intrsx[idx] = Some(cp_idx)
      area
    }
  }
}

fn xlintersections(
  objs : Array[XObject],
  labels : Array[XLabel],
  obj_idx : Int,
  intrsx : Array[Int?],
) -> XBestPos {
  let obj = objs[obj_idx]
  let label_idx = match obj.label_index {
    Some(value) => value
    None => return { n: 0, area: 0.0, pos: point(0.0, 0.0) }
  }
  let label = labels[label_idx]
  let mut count = 0
  let mut area = 0.0
  for i in 0..<objs.length() {
    if i == obj_idx {
      continue
    }
    let other = objs[i]
    if other.width > 0.0 && other.height > 0.0 {
      continue
    }
    if label_encloses_point(label, other) {
      count = count + 1
    }
  }
  let rect = rect_from_label(label)
  for i in 0..<objs.length() {
    if i == obj_idx {
      continue
    }
    let other = objs[i]
    let srect = rect_from_object(other)
    let overlap = rect_overlap_area(rect, srect)
    if overlap > 0.0 {
      let ra =
        record_obj_intersection(objs, labels, obj_idx, i, rect, overlap, intrsx)
      count = count + 1
      area = area + ra
    }
    match other.label_index {
      Some(other_label_idx) => {
        let other_label = labels[other_label_idx]
        if other_label.set {
          let srect = rect_from_label(other_label)
          let overlap = rect_overlap_area(rect, srect)
          if overlap > 0.0 {
            let ra =
              record_label_intersection(
                objs,
                labels,
                obj_idx,
                i,
                rect,
                overlap,
                intrsx,
              )
            count = count + 1
            area = area + ra
          }
        }
      }
      None => ()
    }
  }
  { n: count, area, pos: label.pos }
}

fn xladjust(
  objs : Array[XObject],
  labels : Array[XLabel],
  obj_idx : Int,
) -> XBestPos {
  let obj = objs[obj_idx]
  let label_idx = match obj.label_index {
    Some(value) => value
    None => return { n: 0, area: 0.0, pos: point(0.0, 0.0) }
  }
  let label = labels[label_idx]
  let xincr = (2.0 * label.width + obj.width) / XLXDENOM
  let yincr = (2.0 * label.height + obj.height) / XLYDENOM
  let intrsx : Array[Int?] = []
  for _ in 0..<9 {
    intrsx.push(None)
  }
  let set_label = (pos : @geom.Point) => {
    let updated = {
      target: label.target,
      width: label.width,
      height: label.height,
      pos,
      set: label.set,
    }
    labels[label_idx] = updated
  }
  // x left
  set_label(point(obj.pos.x - label.width, obj.pos.y + obj.height))
  let mut best = xlintersections(objs, labels, obj_idx, intrsx)
  if best.n == 0 {
    return best
  }
  // mid
  set_label(point(obj.pos.x - label.width, obj.pos.y))
  let mut candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(point(obj.pos.x - label.width, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // x mid
  set_label(point(obj.pos.x, obj.pos.y + obj.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(point(obj.pos.x, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // x right
  set_label(point(obj.pos.x + obj.width, obj.pos.y + obj.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // mid
  set_label(point(obj.pos.x + obj.width, obj.pos.y))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(point(obj.pos.x + obj.width, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // sliding from top left
  if intrsx[XLPXNY] is Some(_) ||
    intrsx[XLCXNY] is Some(_) ||
    intrsx[XLNXNY] is Some(_) ||
    intrsx[XLPXCY] is Some(_) ||
    intrsx[XLPXPY] is Some(_) {
    if intrsx[XLCXNY] is None && intrsx[XLNXNY] is None {
      let mut x = obj.pos.x - label.width
      while x <= obj.pos.x + obj.width {
        set_label(point(x, obj.pos.y + obj.height))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        x = x + xincr
      }
    }
    if intrsx[XLPXCY] is None && intrsx[XLPXPY] is None {
      let mut y = obj.pos.y + obj.height
      while y >= obj.pos.y - label.height {
        set_label(point(obj.pos.x - label.width, y))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        y = y - yincr
      }
    }
  }

  // sliding from bottom right
  set_label(point(obj.pos.x + obj.width, obj.pos.y - label.height))
  if intrsx[XLNXPY] is Some(_) ||
    intrsx[XLCXPY] is Some(_) ||
    intrsx[XLPXPY] is Some(_) ||
    intrsx[XLNXCY] is Some(_) ||
    intrsx[XLNXNY] is Some(_) {
    if intrsx[XLCXPY] is None && intrsx[XLPXPY] is None {
      let mut x = obj.pos.x + obj.width
      while x >= obj.pos.x - label.width {
        set_label(point(x, obj.pos.y - label.height))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        x = x - xincr
      }
    }
    if intrsx[XLNXCY] is None && intrsx[XLNXNY] is None {
      let mut y = obj.pos.y - label.height
      while y <= obj.pos.y + obj.height {
        set_label(point(obj.pos.x + obj.width, y))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        y = y + yincr
      }
    }
  }
  best
}

fn place_labels(
  objs : Array[XObject],
  labels : Array[XLabel],
  force : Bool,
) -> Unit {
  for i in 0..<objs.length() {
    let obj = objs[i]
    let label_idx = match obj.label_index {
      Some(value) => value
      None => continue
    }
    let best = xladjust(objs, labels, i)
    if best.n == 0 {
      let label = labels[label_idx]
      labels[label_idx] = {
        target: label.target,
        width: label.width,
        height: label.height,
        pos: label.pos,
        set: true,
      }
    } else if best.area == 0.0 || force {
      let label = labels[label_idx]
      labels[label_idx] = {
        target: label.target,
        width: label.width,
        height: label.height,
        pos: best.pos,
        set: true,
      }
    }
  }
}

fn edge_tail_point_for_layout(edge_layout : DotLayoutEdge) -> @geom.Point? {
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

fn edge_head_point_for_layout(edge_layout : DotLayoutEdge) -> @geom.Point? {
  if edge_layout.splines.length() == 0 {
    return None
  }
  let last_idx = edge_layout.splines.length() - 1
  match edge_layout.splines.get(last_idx) {
    Some(spline) =>
      match spline.end {
        Some(point) => Some(point)
        None =>
          if spline.points.length() > 0 {
            Some(spline.points[spline.points.length() - 1])
          } else {
            None
          }
      }
    None => None
  }
}

fn edge_endpoints(
  edge_layout : DotLayoutEdge,
) -> (@geom.Point, @geom.Point)? {
  match (edge_tail_point_for_layout(edge_layout),
    edge_head_point_for_layout(edge_layout)) {
    (Some(tail), Some(head)) => Some((tail, head))
    _ => None
  }
}

fn approx_eq_point(a : @geom.Point, b : @geom.Point) -> Bool {
  let dx = a.x - b.x
  let dy = a.y - b.y
  dx * dx + dy * dy < MILLIPOINT * MILLIPOINT
}

fn dotneato_closest_point(
  edge_layout : DotLayoutEdge,
  target : @geom.Point,
) -> @geom.Point? {
  if edge_layout.splines.length() == 0 {
    return None
  }
  let mut best_i = 0
  let mut best_j = 0
  let mut best_dist = 1.0e38
  let mut found = false
  for i in 0..<edge_layout.splines.length() {
    let spline = edge_layout.splines[i]
    let points = spline.points
    for j in 0..<points.length() {
      let p = points[j]
      let dx = p.x - target.x
      let dy = p.y - target.y
      let dist = dx * dx + dy * dy
      if !found || dist < best_dist {
        best_dist = dist
        best_i = i
        best_j = j
        found = true
      }
    }
  }
  if !found {
    return None
  }
  let spline = edge_layout.splines[best_i]
  let points = spline.points
  if points.length() == 0 {
    return None
  }
  if points.length() < 4 {
    return Some(points[0])
  }
  let mut closest_idx = best_j
  if closest_idx == points.length() - 1 {
    closest_idx = closest_idx - 1
  }
  let j = 3 * (closest_idx / 3)
  if j + 3 >= points.length() {
    return Some(points[points.length() - 1])
  }
  let p0 = points[j]
  let p1 = points[j + 1]
  let p2 = points[j + 2]
  let p3 = points[j + 3]
  let mut low = 0.0
  let mut high = 1.0
  let mut dlow = {
    let dx = p0.x - target.x
    let dy = p0.y - target.y
    dx * dx + dy * dy
  }
  let mut dhigh = {
    let dx = p3.x - target.x
    let dy = p3.y - target.y
    dx * dx + dy * dy
  }
  let mut pt2 = p0
  while true {
    let t = (low + high) / 2.0
    pt2 = bezier_point_graphviz(p0, p1, p2, p3, t)
    if Double::abs(dlow - dhigh) < 1.0 {
      break
    }
    if Double::abs(high - low) < 0.00001 {
      break
    }
    if dlow < dhigh {
      high = t
      let dx = pt2.x - target.x
      let dy = pt2.y - target.y
      dhigh = dx * dx + dy * dy
    } else {
      low = t
      let dx = pt2.x - target.x
      let dy = pt2.y - target.y
      dlow = dx * dx + dy * dy
    }
  }
  Some(pt2)
}

fn polyline_midpoint(edge_layout : DotLayoutEdge) -> @geom.Point? {
  if edge_layout.splines.length() == 0 {
    return None
  }
  let mut total = 0.0
  for spline in edge_layout.splines {
    let points = spline.points
    let mut j = 0
    while j + 3 < points.length() {
      total = total + segment_length(points[j], points[j + 3])
      j = j + 3
    }
  }
  if total <= 0.0 {
    match edge_endpoints(edge_layout) {
      Some((tail, _)) => return Some(tail)
      None => return None
    }
  }
  let mut dist = total / 2.0
  for spline in edge_layout.splines {
    let points = spline.points
    let mut j = 0
    while j + 3 < points.length() {
      let pf = points[j]
      let qf = points[j + 3]
      let d = segment_length(pf, qf)
      if d >= dist {
        let t = dist / d
        let x = qf.x * t + pf.x * (1.0 - t)
        let y = qf.y * t + pf.y * (1.0 - t)
        return Some(point(x, y))
      }
      dist = dist - d
      j = j + 3
    }
  }
  None
}

fn edge_midpoint_for_layout(
  edge_layout : DotLayoutEdge,
  splines : SplinesMode,
) -> @geom.Point? {
  match edge_endpoints(edge_layout) {
    Some((tail, head)) => {
      if approx_eq_point(tail, head) {
        return Some(tail)
      }
      match splines {
        SplinesMode::Spline | SplinesMode::Curved => {
          let mid = point((tail.x + head.x) / 2.0, (tail.y + head.y) / 2.0)
          match dotneato_closest_point(edge_layout, mid) {
            Some(value) => Some(value)
            None => Some(mid)
          }
        }
        _ => polyline_midpoint(edge_layout)
      }
    }
    None => None
  }
}

fn parse_forcelabels(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("forcelabels") {
    None => true
    Some(text) => {
      let lower = text.to_lower()
      if lower == "" {
        false
      } else if lower == "false" || lower == "no" {
        false
      } else if lower == "true" || lower == "yes" {
        true
      } else {
        try @strconv.parse_int(lower) catch {
          _ => false
        } noraise {
          value => value != 0
        }
      }
    }
  }
}

fn apply_xlabel_updates(
  layout : DotLayoutGraph,
  node_updates : Map[String, @geom.Point],
  edge_mid_updates : Map[String, @geom.Point],
  edge_head_updates : Map[String, @geom.Point],
  edge_tail_updates : Map[String, @geom.Point],
  edge_xlabel_updates : Map[String, @geom.Point],
) -> DotLayoutGraph {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let xlabel_pos = match node_updates.get(node_layout.node.name()) {
      Some(pos) => Some(pos)
      None => node_layout.xlabel_pos
    }
    nodes.push({
      node: node_layout.node,
      pos: node_layout.pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: node_layout.label_pos,
      xlabel_pos,
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let key = edge_key(edge_layout.edge)
    let label_pos = match edge_mid_updates.get(key) {
      Some(pos) => Some(pos)
      None => edge_layout.label_pos
    }
    let head_label_pos = match edge_head_updates.get(key) {
      Some(pos) => Some(pos)
      None => edge_layout.head_label_pos
    }
    let tail_label_pos = match edge_tail_updates.get(key) {
      Some(pos) => Some(pos)
      None => edge_layout.tail_label_pos
    }
    let xlabel_pos = match edge_xlabel_updates.get(key) {
      Some(pos) => Some(pos)
      None => edge_layout.xlabel_pos
    }
    edges.push({
      edge: edge_layout.edge,
      splines: edge_layout.splines,
      label_pos,
      head_label_pos,
      tail_label_pos,
      xlabel_pos,
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(
      apply_xlabel_updates(
        subgraph,
        node_updates,
        edge_mid_updates,
        edge_head_updates,
        edge_tail_updates,
        edge_xlabel_updates,
      ),
    )
  }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes,
    edges,
    subgraphs,
  }
}

fn collect_cluster_label_objects(
  layout : DotLayoutGraph,
  objects : Array[XObject],
) -> Unit {
  for subgraph in layout.subgraphs {
    match subgraph.label_pos {
      Some(pos) =>
        match graph_label_metrics(subgraph.graph) {
          Some((width, height)) => {
            let llx = pos.x - width / 2.0
            let lly = pos.y - height / 2.0
            objects.push({
              pos: point(llx, lly),
              width,
              height,
              label_index: None,
            })
          }
          None => ()
        }
      None => ()
    }
    collect_cluster_label_objects(subgraph, objects)
  }
}

fn apply_xlabels(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  splines : SplinesMode,
) -> DotLayoutGraph {
  let labels : Array[XLabel] = []
  let objects : Array[XObject] = []
  let node_updates : Map[String, @geom.Point] = Map::new()
  let edge_mid_updates : Map[String, @geom.Point] = Map::new()
  let edge_head_updates : Map[String, @geom.Point] = Map::new()
  let edge_tail_updates : Map[String, @geom.Point] = Map::new()
  let edge_xlabel_updates : Map[String, @geom.Point] = Map::new()

  let edges_by_tail : Map[String, Array[DotLayoutEdge]] = Map::new()
  for edge_layout in layout.edges {
    let tail_name = edge_layout.edge.tail().name()
    let list = match edges_by_tail.get(tail_name) {
      Some(value) => value
      None => []
    }
    list.push(edge_layout)
    edges_by_tail[tail_name] = list
  }

  for node_layout in layout.nodes {
    let node = node_layout.node
    let width_pt = node_layout.width_in * 72.0
    let height_pt = node_layout.height_in * 72.0
    let llx = node_layout.pos.x - width_pt / 2.0
    let lly = node_layout.pos.y - height_pt / 2.0
    let mut label_index : Int? = None
    let mut label_object : XObject? = None
    match xlabel_metrics_for_node(node) {
      Some((label_w, label_h)) =>
        match node_layout.xlabel_pos {
          Some(pos) => {
            let pos_ll = point(pos.x - label_w / 2.0, pos.y - label_h / 2.0)
            label_object = Some({
              pos: pos_ll,
              width: label_w,
              height: label_h,
              label_index: None,
            })
          }
          None => {
            let idx = labels.length()
            labels.push({
              target: XLabelTarget::Node(node.name()),
              width: label_w,
              height: label_h,
              pos: point(0.0, 0.0),
              set: false,
            })
            label_index = Some(idx)
          }
        }
      None => ()
    }
    objects.push({
      pos: point(llx, lly),
      width: width_pt,
      height: height_pt,
      label_index,
    })
    match label_object {
      Some(obj) => objects.push(obj)
      None => ()
    }

    let edges_for_node = match edges_by_tail.get(node.name()) {
      Some(value) => value
      None => []
    }
    for edge_layout in edges_for_node {
      let edge = edge_layout.edge
      let edge_key_value = edge_key(edge)
      let has_geometry = edge_layout.splines.length() > 0
      match edge_layout.label_pos {
        Some(pos) =>
          match edge_mid_label_metrics(edge) {
            Some((label_w, label_h)) => {
              let pos_ll = point(pos.x - label_w / 2.0, pos.y - label_h / 2.0)
              objects.push({
                pos: pos_ll,
                width: label_w,
                height: label_h,
                label_index: None,
              })
            }
            None => ()
          }
        None =>
          if has_geometry {
            match edge_mid_label_metrics(edge) {
              Some((label_w, label_h)) =>
                match edge_midpoint_for_layout(edge_layout, splines) {
                  Some(anchor) => {
                    let idx = labels.length()
                    labels.push({
                      target: XLabelTarget::EdgeMid(edge_key_value),
                      width: label_w,
                      height: label_h,
                      pos: point(0.0, 0.0),
                      set: false,
                    })
                    objects.push({
                      pos: anchor,
                      width: 0.0,
                      height: 0.0,
                      label_index: Some(idx),
                    })
                  }
                  None => ()
                }
              None => ()
            }
          }
      }
      match edge_layout.tail_label_pos {
        Some(pos) =>
          match edge_label_metrics_for_attr(edge, "taillabel", true) {
            Some((label_w, label_h)) => {
              let pos_ll = point(pos.x - label_w / 2.0, pos.y - label_h / 2.0)
              objects.push({
                pos: pos_ll,
                width: label_w,
                height: label_h,
                label_index: None,
              })
            }
            None => ()
          }
        None =>
          if has_geometry {
            match edge_label_metrics_for_attr(edge, "taillabel", true) {
              Some((label_w, label_h)) =>
                match edge_tail_point_for_layout(edge_layout) {
                  Some(anchor) => {
                    let idx = labels.length()
                    labels.push({
                      target: XLabelTarget::EdgeTail(edge_key_value),
                      width: label_w,
                      height: label_h,
                      pos: point(0.0, 0.0),
                      set: false,
                    })
                    objects.push({
                      pos: anchor,
                      width: 0.0,
                      height: 0.0,
                      label_index: Some(idx),
                    })
                  }
                  None => ()
                }
              None => ()
            }
          }
      }
      match edge_layout.head_label_pos {
        Some(pos) =>
          match edge_label_metrics_for_attr(edge, "headlabel", true) {
            Some((label_w, label_h)) => {
              let pos_ll = point(pos.x - label_w / 2.0, pos.y - label_h / 2.0)
              objects.push({
                pos: pos_ll,
                width: label_w,
                height: label_h,
                label_index: None,
              })
            }
            None => ()
          }
        None =>
          if has_geometry {
            match edge_label_metrics_for_attr(edge, "headlabel", true) {
              Some((label_w, label_h)) =>
                match edge_head_point_for_layout(edge_layout) {
                  Some(anchor) => {
                    let idx = labels.length()
                    labels.push({
                      target: XLabelTarget::EdgeHead(edge_key_value),
                      width: label_w,
                      height: label_h,
                      pos: point(0.0, 0.0),
                      set: false,
                    })
                    objects.push({
                      pos: anchor,
                      width: 0.0,
                      height: 0.0,
                      label_index: Some(idx),
                    })
                  }
                  None => ()
                }
              None => ()
            }
          }
      }
      match edge_layout.xlabel_pos {
        Some(pos) =>
          match xlabel_metrics_for_edge(edge) {
            Some((label_w, label_h)) => {
              let pos_ll = point(pos.x - label_w / 2.0, pos.y - label_h / 2.0)
              objects.push({
                pos: pos_ll,
                width: label_w,
                height: label_h,
                label_index: None,
              })
            }
            None => ()
          }
        None =>
          if has_geometry {
            match xlabel_metrics_for_edge(edge) {
              Some((label_w, label_h)) =>
                match edge_midpoint_for_layout(edge_layout, splines) {
                  Some(anchor) => {
                    let idx = labels.length()
                    labels.push({
                      target: XLabelTarget::EdgeXlabel(edge_key_value),
                      width: label_w,
                      height: label_h,
                      pos: point(0.0, 0.0),
                      set: false,
                    })
                    objects.push({
                      pos: anchor,
                      width: 0.0,
                      height: 0.0,
                      label_index: Some(idx),
                    })
                  }
                  None => ()
                }
              None => ()
            }
          }
      }
    }
  }
  collect_cluster_label_objects(layout, objects)
  if labels.length() > 0 {
    let force = parse_forcelabels(graph)
    place_labels(objects, labels, force)
  }
  let mut bbox = layout.bbox
  for node_layout in layout.nodes {
    match node_layout.xlabel_pos {
      Some(pos) =>
        match xlabel_metrics_for_node(node_layout.node) {
          Some((width, height)) =>
            bbox = expand_bbox_for_label_pos(bbox, Some(pos), Some((width, height)))
          None => ()
        }
      None => ()
    }
  }
  for edge_layout in layout.edges {
    match edge_layout.xlabel_pos {
      Some(pos) =>
        match xlabel_metrics_for_edge(edge_layout.edge) {
          Some((width, height)) =>
            bbox = expand_bbox_for_label_pos(bbox, Some(pos), Some((width, height)))
          None => ()
        }
      None => ()
    }
  }
  for label in labels {
    if !label.set {
      continue
    }
    let center =
      point(label.pos.x + label.width / 2.0, label.pos.y + label.height / 2.0)
    bbox = expand_bbox_for_label_pos(bbox, Some(center), Some((label.width, label.height)))
    match label.target {
      XLabelTarget::Node(name) => node_updates[name] = center
      XLabelTarget::EdgeMid(key) => edge_mid_updates[key] = center
      XLabelTarget::EdgeHead(key) => edge_head_updates[key] = center
      XLabelTarget::EdgeTail(key) => edge_tail_updates[key] = center
      XLabelTarget::EdgeXlabel(key) => edge_xlabel_updates[key] = center
    }
  }
  let updated =
    apply_xlabel_updates(
      layout,
      node_updates,
      edge_mid_updates,
      edge_head_updates,
      edge_tail_updates,
      edge_xlabel_updates,
    )
  {
    graph: updated.graph,
    bbox,
    label_pos: updated.label_pos,
    nodes: updated.nodes,
    edges: updated.edges,
    subgraphs: updated.subgraphs,
  }
}

///|
/// Graphviz parity: xlabels placement aligned to refs/graphviz/lib/common/postproc.c
/// (addXLabels) + lib/label/xlabels.c (placeLabels).
/// Do not change behavior without updating fixtures/tests.
fn place_xlabels(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  splines : SplinesMode,
) -> DotLayoutGraph {
  apply_xlabels(graph, layout, splines)
}
