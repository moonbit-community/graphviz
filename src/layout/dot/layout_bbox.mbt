///|
/// Graphviz parity: spline bbox uses update_bb_bz refinement aligned to
/// refs/graphviz/lib/common/emit.c (update_bb_bz).
/// Do not change behavior without updating fixtures/tests.
fn spline_bbox(points : Array[@geom.Point]) -> @geom.Rect? {
  if points.length() == 0 {
    return None
  }
  if points.length() % 3 != 1 {
    let mut min_x = points[0].x
    let mut max_x = points[0].x
    let mut min_y = points[0].y
    let mut max_y = points[0].y
    for p in points {
      if p.x < min_x { min_x = p.x }
      if p.x > max_x { max_x = p.x }
      if p.y < min_y { min_y = p.y }
      if p.y > max_y { max_y = p.y }
    }
    return Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
  }
  let mut bbox : @geom.Rect = {
    llx: points[0].x,
    lly: points[0].y,
    urx: points[0].x,
    ury: points[0].y,
  }
  let mut i = 0
  while i + 3 < points.length() {
    let p0 = points[i]
    let p1 = points[i + 1]
    let p2 = points[i + 2]
    let p3 = points[i + 3]
    bbox = update_bbox_with_bezier(bbox, p0, p1, p2, p3)
    i = i + 3
  }
  Some(bbox)
}

fn expand_bbox_with_point(bbox : @geom.Rect, p : @geom.Point) -> @geom.Rect {
  {
    llx: if p.x < bbox.llx { p.x } else { bbox.llx },
    lly: if p.y < bbox.lly { p.y } else { bbox.lly },
    urx: if p.x > bbox.urx { p.x } else { bbox.urx },
    ury: if p.y > bbox.ury { p.y } else { bbox.ury },
  }
}

fn pt_to_line2(a : @geom.Point, b : @geom.Point, p : @geom.Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let a2 = (p.y - a.y) * dx - (p.x - a.x) * dy
  let a2_sq = a2 * a2
  if a2_sq < 0.0000000001 {
    0.0
  } else {
    let denom = dx * dx + dy * dy
    if denom == 0.0 { 0.0 } else { a2_sq / denom }
  }
}

fn bezier_control_points_near_line(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> Bool {
  let hw = 2.0
  let dis1 = pt_to_line2(p0, p3, p1)
  let dis2 = pt_to_line2(p0, p3, p2)
  dis1 < hw * hw && dis2 < hw * hw
}

fn split_bezier_half(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> (
  (@geom.Point, @geom.Point, @geom.Point, @geom.Point),
  (@geom.Point, @geom.Point, @geom.Point, @geom.Point),
) {
  let p01 = @edge_spline.point((p0.x + p1.x) / 2.0, (p0.y + p1.y) / 2.0)
  let p12 = @edge_spline.point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
  let p23 = @edge_spline.point((p2.x + p3.x) / 2.0, (p2.y + p3.y) / 2.0)
  let p012 = @edge_spline.point((p01.x + p12.x) / 2.0, (p01.y + p12.y) / 2.0)
  let p123 = @edge_spline.point((p12.x + p23.x) / 2.0, (p12.y + p23.y) / 2.0)
  let p0123 = @edge_spline.point((p012.x + p123.x) / 2.0, (p012.y + p123.y) / 2.0)
  (
    (p0, p01, p012, p0123),
    (p0123, p123, p23, p3),
  )
}

fn update_bbox_with_bezier(
  bbox : @geom.Rect,
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> @geom.Rect {
  let mut out = bbox
  if p0.x > out.urx || p0.x < out.llx || p0.y > out.ury || p0.y < out.lly ||
    p1.x > out.urx || p1.x < out.llx || p1.y > out.ury || p1.y < out.lly ||
    p2.x > out.urx || p2.x < out.llx || p2.y > out.ury || p2.y < out.lly ||
    p3.x > out.urx || p3.x < out.llx || p3.y > out.ury || p3.y < out.lly {
    if bezier_control_points_near_line(p0, p1, p2, p3) {
      out = expand_bbox_with_point(out, p0)
      out = expand_bbox_with_point(out, p1)
      out = expand_bbox_with_point(out, p2)
      out = expand_bbox_with_point(out, p3)
    } else {
      let ((l0, l1, l2, l3), (r0, r1, r2, r3)) =
        split_bezier_half(p0, p1, p2, p3)
      let left = update_bbox_with_bezier(out, l0, l1, l2, l3)
      out = update_bbox_with_bezier(left, r0, r1, r2, r3)
    }
  }
  out
}

///|
/// Graphviz parity: bbox aggregation aligned to refs/graphviz/lib/common/utils.c (compute_bb),
/// with label/cluster expansion handled in f_postprocess helpers.
/// Do not change behavior without updating fixtures/tests.
fn compute_bbox(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut bbox_set = false
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  for node in nodes {
    let half_w = node.width_in * 72.0 / 2.0
    let half_h = node.height_in * 72.0 / 2.0
    let left = node.pos.x - half_w
    let right = node.pos.x + half_w
    let bottom = node.pos.y - half_h
    let top = node.pos.y + half_h
    if !bbox_set {
      min_x = left
      max_x = right
      min_y = bottom
      max_y = top
      bbox_set = true
    } else {
      if left < min_x {
        min_x = left
      }
      if right > max_x {
        max_x = right
      }
      if bottom < min_y {
        min_y = bottom
      }
      if top > max_y {
        max_y = top
      }
    }
  }
  for edge in edges {
    for spline in edge.splines {
      let update = (p : @geom.Point) => {
        if !bbox_set {
          min_x = p.x
          max_x = p.x
          min_y = p.y
          max_y = p.y
          bbox_set = true
        } else {
          if p.x < min_x { min_x = p.x }
          if p.x > max_x { max_x = p.x }
          if p.y < min_y { min_y = p.y }
          if p.y > max_y { max_y = p.y }
        }
      }
      match spline.start {
        Some(point) => update(point)
        None => ()
      }
      match spline.end {
        Some(point) => update(point)
        None => ()
      }
      match spline_bbox(spline.points) {
        Some(rect) => {
          update({ x: rect.llx, y: rect.lly })
          update({ x: rect.urx, y: rect.ury })
        }
        None => ()
      }
    }
  }
  if bbox_set {
    { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
  } else {
    { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
}

///|
/// Graphviz parity: edge splines expand bbox like refs/graphviz/lib/dotgen/dotsplines.c
/// (update_bb_bz) after dot_compute_bb.
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_with_edges(
  bbox : @geom.Rect,
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut min_x = bbox.llx
  let mut max_x = bbox.urx
  let mut min_y = bbox.lly
  let mut max_y = bbox.ury
  let mut bbox_set =
    !(bbox.llx == 0.0 && bbox.lly == 0.0 && bbox.urx == 0.0 && bbox.ury == 0.0)
  let update = (p : @geom.Point) => {
    if !bbox_set {
      min_x = p.x
      max_x = p.x
      min_y = p.y
      max_y = p.y
      bbox_set = true
    } else {
      if p.x < min_x { min_x = p.x }
      if p.x > max_x { max_x = p.x }
      if p.y < min_y { min_y = p.y }
      if p.y > max_y { max_y = p.y }
    }
  }
  for edge in edges {
    for spline in edge.splines {
      match spline.start {
        Some(point) => update(point)
        None => ()
      }
      match spline.end {
        Some(point) => update(point)
        None => ()
      }
      match spline_bbox(spline.points) {
        Some(rect) => {
          update({ x: rect.llx, y: rect.lly })
          update({ x: rect.urx, y: rect.ury })
        }
        None => ()
      }
    }
  }
  if bbox_set {
    { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
  } else {
    { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
}

///|
fn merge_bbox(base : @geom.Rect, other : @geom.Rect) -> @geom.Rect {
  {
    llx: if base.llx < other.llx {
      base.llx
    } else {
      other.llx
    },
    lly: if base.lly < other.lly {
      base.lly
    } else {
      other.lly
    },
    urx: if base.urx > other.urx {
      base.urx
    } else {
      other.urx
    },
    ury: if base.ury > other.ury {
      base.ury
    } else {
      other.ury
    },
  }
}

///|
fn round_bbox(bbox : @geom.Rect) -> @geom.Rect {
  {
    llx: bbox.llx.round(),
    lly: bbox.lly,
    urx: bbox.urx.round(),
    ury: bbox.ury,
  }
}

///|
fn expand_bbox_with_subgraphs(
  bbox : @geom.Rect,
  subgraphs : Array[DotLayoutGraph],
) -> @geom.Rect {
  let mut result = bbox
  for subgraph in subgraphs {
    result = merge_bbox(result, subgraph.bbox)
    if subgraph.subgraphs.length() > 0 {
      result = expand_bbox_with_subgraphs(result, subgraph.subgraphs)
    }
  }
  result
}

///|
/// Graphviz parity: root bbox only expands to include cluster subgraphs
/// (dot_compute_bb uses GD_clust list, not generic subgraphs).
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_with_cluster_subgraphs(
  bbox : @geom.Rect,
  subgraphs : Array[DotLayoutGraph],
) -> @geom.Rect {
  let mut result = bbox
  for subgraph in subgraphs {
    if @dot_shared.is_cluster_graph(subgraph.graph) {
      // Graphviz parity: dot_compute_bb expands root bbox by CL_OFFSET for
      // cluster subgraphs in x direction.
      let padded : @geom.Rect = {
        llx: subgraph.bbox.llx - CLUSTER_MARGIN_PT,
        lly: subgraph.bbox.lly,
        urx: subgraph.bbox.urx + CLUSTER_MARGIN_PT,
        ury: subgraph.bbox.ury,
      }
      result = merge_bbox(result, padded)
    }
    if subgraph.subgraphs.length() > 0 {
      result = expand_bbox_with_cluster_subgraphs(result, subgraph.subgraphs)
    }
  }
  result
}

///|
/// Graphviz parity: rankdir coordinate transform aligned to
/// refs/graphviz/lib/common/postproc.c (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn transform_point(
  point : @geom.Point,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point {
  match rankdir {
    RankDir::TB => point
    RankDir::BT => { x: point.x, y: bbox.lly + bbox.ury - point.y }
    RankDir::LR => { x: bbox.lly + bbox.ury - point.y, y: point.x }
    RankDir::RL => { x: point.y, y: point.x }
  }
}

///|
fn transform_optional_point(
  point : @geom.Point?,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point? {
  match point {
    Some(value) => Some(transform_point(value, bbox, rankdir))
    None => None
  }
}

///|
fn transform_spline(
  spline : @geom.Spline,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(transform_point(point, bbox, rankdir))
  }
  {
    start: transform_optional_point(spline.start, bbox, rankdir),
    end: transform_optional_point(spline.end, bbox, rankdir),
    points,
  }
}

///|
fn shift_point(point : @geom.Point, dx : Double, dy : Double) -> @geom.Point {
  { x: point.x + dx, y: point.y + dy }
}

///|
fn shift_optional_point(
  point : @geom.Point?,
  dx : Double,
  dy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(shift_point(value, dx, dy))
    None => None
  }
}

///|
fn shift_spline(
  spline : @geom.Spline,
  dx : Double,
  dy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(shift_point(point, dx, dy))
  }
  {
    start: shift_optional_point(spline.start, dx, dy),
    end: shift_optional_point(spline.end, dx, dy),
    points,
  }
}

///|
/// Graphviz parity: layout translation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn shift_layout_graph(
  layout : DotLayoutGraph,
  dx : Double,
  dy : Double,
) -> DotLayoutGraph {
  let shifted_nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    shifted_nodes.push({
      node: node_layout.node,
      pos: shift_point(node_layout.pos, dx, dy),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: shift_optional_point(node_layout.label_pos, dx, dy),
      xlabel_pos: shift_optional_point(node_layout.xlabel_pos, dx, dy),
    })
  }
  let shifted_edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(shift_spline(spline, dx, dy))
    }
    shifted_edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: shift_optional_point(edge_layout.label_pos, dx, dy),
      head_label_pos: shift_optional_point(edge_layout.head_label_pos, dx, dy),
      tail_label_pos: shift_optional_point(edge_layout.tail_label_pos, dx, dy),
      xlabel_pos: shift_optional_point(edge_layout.xlabel_pos, dx, dy),
    })
  }
  let shifted_subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    shifted_subgraphs.push(shift_layout_graph(subgraph, dx, dy))
  }
  let shifted_bbox : @geom.Rect = {
    llx: layout.bbox.llx + dx,
    lly: layout.bbox.lly + dy,
    urx: layout.bbox.urx + dx,
    ury: layout.bbox.ury + dy,
  }
  {
    graph: layout.graph,
    bbox: shifted_bbox,
    label_pos: shift_optional_point(layout.label_pos, dx, dy),
    nodes: shifted_nodes,
    edges: shifted_edges,
    subgraphs: shifted_subgraphs,
  }
}

///|
/// Graphviz parity: bbox rotation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_bb/map_point).
/// Do not change behavior without updating fixtures/tests.
fn transform_bbox_with_root(
  bbox : @geom.Rect,
  root_bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Rect {
  if rankdir == RankDir::TB {
    return bbox
  }
  let points : Array[@geom.Point] = [
    { x: bbox.llx, y: bbox.lly },
    { x: bbox.llx, y: bbox.ury },
    { x: bbox.urx, y: bbox.lly },
    { x: bbox.urx, y: bbox.ury },
  ]
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  let mut first = true
  for point in points {
    let mapped = transform_point(point, root_bbox, rankdir)
    if first {
      min_x = mapped.x
      max_x = mapped.x
      min_y = mapped.y
      max_y = mapped.y
      first = false
    } else {
      if mapped.x < min_x { min_x = mapped.x }
      if mapped.x > max_x { max_x = mapped.x }
      if mapped.y < min_y { min_y = mapped.y }
      if mapped.y > max_y { max_y = mapped.y }
    }
  }
  { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
}

///|
/// Graphviz parity: rankdir rotation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/map_point).
/// Do not change behavior without updating fixtures/tests.
fn rotate_layout_graph(
  layout : DotLayoutGraph,
  root_bbox : @geom.Rect,
  rankdir : RankDir,
) -> DotLayoutGraph {
  if rankdir == RankDir::TB {
    return layout
  }
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    nodes.push({
      node: node_layout.node,
      pos: transform_point(node_layout.pos, root_bbox, rankdir),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: transform_optional_point(
        node_layout.label_pos,
        root_bbox,
        rankdir,
      ),
      xlabel_pos: transform_optional_point(
        node_layout.xlabel_pos,
        root_bbox,
        rankdir,
      ),
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(transform_spline(spline, root_bbox, rankdir))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: transform_optional_point(
        edge_layout.label_pos,
        root_bbox,
        rankdir,
      ),
      head_label_pos: transform_optional_point(
        edge_layout.head_label_pos,
        root_bbox,
        rankdir,
      ),
      tail_label_pos: transform_optional_point(
        edge_layout.tail_label_pos,
        root_bbox,
        rankdir,
      ),
      xlabel_pos: transform_optional_point(
        edge_layout.xlabel_pos,
        root_bbox,
        rankdir,
      ),
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(rotate_layout_graph(subgraph, root_bbox, rankdir))
  }
  {
    graph: layout.graph,
    bbox: transform_bbox_with_root(layout.bbox, root_bbox, rankdir),
    label_pos: transform_optional_point(layout.label_pos, root_bbox, rankdir),
    nodes,
    edges,
    subgraphs,
  }
}
