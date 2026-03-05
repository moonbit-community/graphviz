///|
/// Layout bbox aggregation/expansion helpers plus rank-based dot bbox helpers.

priv struct BBoxAccumulator {
  set : Bool
  min_x : Double
  max_x : Double
  min_y : Double
  max_y : Double
}

fn bbox_is_zero_sentinel(bbox : @geom.Rect) -> Bool {
  bbox.llx == 0.0 && bbox.lly == 0.0 && bbox.urx == 0.0 && bbox.ury == 0.0
}

fn bbox_acc_empty() -> BBoxAccumulator {
  { set: false, min_x: 0.0, max_x: 0.0, min_y: 0.0, max_y: 0.0 }
}

fn bbox_acc_from_bbox(bbox : @geom.Rect) -> BBoxAccumulator {
  if bbox_is_zero_sentinel(bbox) {
    bbox_acc_empty()
  } else {
    {
      set: true,
      min_x: bbox.llx,
      max_x: bbox.urx,
      min_y: bbox.lly,
      max_y: bbox.ury,
    }
  }
}

fn bbox_acc_include_point(
  acc : BBoxAccumulator,
  p : @geom.Point,
) -> BBoxAccumulator {
  if !acc.set {
    {
      set: true,
      min_x: p.x,
      max_x: p.x,
      min_y: p.y,
      max_y: p.y,
    }
  } else {
    {
      set: true,
      min_x: if p.x < acc.min_x { p.x } else { acc.min_x },
      max_x: if p.x > acc.max_x { p.x } else { acc.max_x },
      min_y: if p.y < acc.min_y { p.y } else { acc.min_y },
      max_y: if p.y > acc.max_y { p.y } else { acc.max_y },
    }
  }
}

fn bbox_acc_to_rect(acc : BBoxAccumulator) -> @geom.Rect {
  if acc.set {
    { llx: acc.min_x, lly: acc.min_y, urx: acc.max_x, ury: acc.max_y }
  } else {
    { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
}

///|
/// Graphviz parity: bbox aggregation aligned to refs/graphviz/lib/common/utils.c (compute_bb),
/// with label/cluster expansion handled in f_postprocess helpers.
/// Do not change behavior without updating fixtures/tests.
fn compute_bbox(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut acc = bbox_acc_empty()
  for node in nodes {
    let half_w = node.width_in * 72.0 / 2.0
    let half_h = node.height_in * 72.0 / 2.0
    let left = node.pos.x - half_w
    let right = node.pos.x + half_w
    let bottom = node.pos.y - half_h
    let top = node.pos.y + half_h
    acc = bbox_acc_include_point(acc, { x: left, y: bottom })
    acc = bbox_acc_include_point(acc, { x: right, y: top })
  }
  for edge in edges {
    for spline in edge.splines {
      let update = (p : @geom.Point) => {
        acc = bbox_acc_include_point(acc, p)
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
  bbox_acc_to_rect(acc)
}

///|
/// Graphviz parity: edge splines expand bbox like refs/graphviz/lib/dotgen/dotsplines.c
/// (update_bb_bz) after dot_compute_bb.
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_with_edges(
  bbox : @geom.Rect,
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut acc = bbox_acc_from_bbox(bbox)
  let update = (p : @geom.Point) => {
    acc = bbox_acc_include_point(acc, p)
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
  bbox_acc_to_rect(acc)
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
fn expand_bbox_with_clusters(
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
      result = expand_bbox_with_clusters(result, subgraph.subgraphs)
    }
  }
  result
}

///|
/// Spline bounding-box helpers used by layout bbox aggregation.

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

fn bezier_controls_near_line(
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

priv struct CubicBezierSegment {
  p0 : @geom.Point
  p1 : @geom.Point
  p2 : @geom.Point
  p3 : @geom.Point
}

priv struct SplitBezierHalf {
  left : CubicBezierSegment
  right : CubicBezierSegment
}

fn split_bezier_half(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> SplitBezierHalf {
  let p01 = @edge_spline.point((p0.x + p1.x) / 2.0, (p0.y + p1.y) / 2.0)
  let p12 = @edge_spline.point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
  let p23 = @edge_spline.point((p2.x + p3.x) / 2.0, (p2.y + p3.y) / 2.0)
  let p012 = @edge_spline.point((p01.x + p12.x) / 2.0, (p01.y + p12.y) / 2.0)
  let p123 = @edge_spline.point((p12.x + p23.x) / 2.0, (p12.y + p23.y) / 2.0)
  let p0123 = @edge_spline.point((p012.x + p123.x) / 2.0, (p012.y + p123.y) / 2.0)
  {
    left: { p0, p1: p01, p2: p012, p3: p0123 },
    right: { p0: p0123, p1: p123, p2: p23, p3 },
  }
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
    if bezier_controls_near_line(p0, p1, p2, p3) {
      out = expand_bbox_with_point(out, p0)
      out = expand_bbox_with_point(out, p1)
      out = expand_bbox_with_point(out, p2)
      out = expand_bbox_with_point(out, p3)
    } else {
      let split = split_bezier_half(p0, p1, p2, p3)
      let left =
        update_bbox_with_bezier(
          out,
          split.left.p0,
          split.left.p1,
          split.left.p2,
          split.left.p3,
        )
      out =
        update_bbox_with_bezier(
          left,
          split.right.p0,
          split.right.p1,
          split.right.p2,
          split.right.p3,
        )
    }
  }
  out
}

///|
/// Rank-based bbox helper shared by routing precompute and final geometry.

///|
/// Graphviz parity: rank-based bbox input keeps node/rank geometry snapshots
/// grouped for deterministic dot_compute_bb bounds reconstruction.
priv struct DotBBoxInput {
  nodes_out : Array[DotLayoutNode]
  all_ranks : Array[Int]
  sizes : Map[String, NodeSize]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
/// Graphviz parity: rank-based bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_bbox(
  input : DotBBoxInput,
) -> @geom.Rect {
  if input.nodes_out.length() == 0 {
    return { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut first = true
  for node_layout in input.nodes_out {
    let name = node_layout.node.name()
    let left = @dot_shared.node_left_pt(name, input.sizes)
    let right = @dot_shared.node_right_pt(name, input.sizes)
    let llx = node_layout.pos.x - left
    let urx = node_layout.pos.x + right
    if first {
      min_x = llx
      max_x = urx
      first = false
    } else {
      if llx < min_x { min_x = llx }
      if urx > max_x { max_x = urx }
    }
  }
  let mut min_y = 0.0
  let mut max_y = 0.0
  if input.all_ranks.length() > 0 {
    let min_rank = input.all_ranks[0]
    let max_rank = input.all_ranks[input.all_ranks.length() - 1]
    let max_rank_y = match input.rank_y.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    let min_rank_y = match input.rank_y.get(min_rank) {
      Some(value) => value
      None => 0.0
    }
    let ht1 = match input.rank_ht1.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    let ht2 = match input.rank_ht2.get(min_rank) {
      Some(value) => value
      None => 0.0
    }
    min_y = max_rank_y - ht1
    max_y = min_rank_y + ht2
  }
  { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
}
