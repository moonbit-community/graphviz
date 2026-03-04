///|
/// Layout bbox aggregation and expansion helpers.

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
