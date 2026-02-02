///|
/// Graphviz parity: spline bbox uses midpoints like refs/graphviz/lib/common/emit.c (bezier_bb).
/// Do not change behavior without updating fixtures/tests.
fn spline_bbox(points : Array[@geom.Point]) -> @geom.Rect? {
  if points.length() == 0 {
    return None
  }
  let mut min_x = points[0].x
  let mut max_x = points[0].x
  let mut min_y = points[0].y
  let mut max_y = points[0].y
  let update = (p : @geom.Point) => {
    if p.x < min_x { min_x = p.x }
    if p.x > max_x { max_x = p.x }
    if p.y < min_y { min_y = p.y }
    if p.y > max_y { max_y = p.y }
  }
  if points.length() % 3 != 1 {
    for p in points {
      update(p)
    }
    return Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
  }
  let mut i = 1
  while i + 2 < points.length() {
    let p1 = points[i]
    let p2 = points[i + 1]
    let mid = point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
    update(mid)
    update(points[i + 2])
    i = i + 3
  }
  Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
}

///|
/// Graphviz parity: bbox aggregation aligned to refs/graphviz/lib/common/utils.c (compute_bb),
/// with label/cluster expansion handled in layout_postprocess_helpers.
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
fn transform_point(
  point : @geom.Point,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point {
  match rankdir {
    RankDir::TB => point
    RankDir::BT => { x: point.x, y: bbox.lly + bbox.ury - point.y }
    RankDir::LR => { x: bbox.lly + bbox.ury - point.y, y: point.x }
    RankDir::RL => { x: point.y, y: bbox.llx + bbox.urx - point.x }
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
/// Graphviz parity: rankdir transform aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn transform_layout(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> (Array[DotLayoutNode], Array[DotLayoutEdge], @geom.Rect) {
  let transformed_nodes : Array[DotLayoutNode] = []
  for node_layout in nodes {
    transformed_nodes.push({
      node: node_layout.node,
      pos: transform_point(node_layout.pos, bbox, rankdir),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: transform_optional_point(node_layout.label_pos, bbox, rankdir),
    })
  }
  let transformed_edges : Array[DotLayoutEdge] = []
  for edge_layout in edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(transform_spline(spline, bbox, rankdir))
    }
    transformed_edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: transform_optional_point(edge_layout.label_pos, bbox, rankdir),
      head_label_pos: transform_optional_point(
        edge_layout.head_label_pos,
        bbox,
        rankdir,
      ),
      tail_label_pos: transform_optional_point(
        edge_layout.tail_label_pos,
        bbox,
        rankdir,
      ),
    })
  }
  let transformed_bbox = compute_bbox(transformed_nodes, transformed_edges)
  if transformed_bbox.llx == 0.0 && transformed_bbox.lly == 0.0 {
    (transformed_nodes, transformed_edges, transformed_bbox)
  } else {
    let dx = -transformed_bbox.llx
    let dy = -transformed_bbox.lly
    let shifted_nodes : Array[DotLayoutNode] = []
    for node_layout in transformed_nodes {
      shifted_nodes.push({
        node: node_layout.node,
        pos: shift_point(node_layout.pos, dx, dy),
        width_in: node_layout.width_in,
        height_in: node_layout.height_in,
        label_pos: shift_optional_point(node_layout.label_pos, dx, dy),
      })
    }
    let shifted_edges : Array[DotLayoutEdge] = []
    for edge_layout in transformed_edges {
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
      })
    }
    let shifted_bbox = compute_bbox(shifted_nodes, shifted_edges)
    (shifted_nodes, shifted_edges, shifted_bbox)
  }
}
