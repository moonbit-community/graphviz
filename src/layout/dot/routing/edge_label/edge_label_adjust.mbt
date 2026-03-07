///|
/// Graphviz parity: edge-label adjust output keeps updated edge list plus
/// keyed label-position map so callers can propagate updates across subgraphs.
pub(all) struct AdjustedEdgeLabels {
  edges : Array[DotLayoutEdge]
  updates : Map[String, @geom.Point]
}

///|
priv struct EdgeLabelEntry {
  key : String
  pos : @geom.Point
  base_axis : Double
  half_axis : Double
}

///|
priv struct RectOverlapAmount {
  overlap_x : Double
  overlap_y : Double
}

///|
priv struct LabelRectNudge {
  label_pos : @geom.Point
  label_rect : @geom.Rect
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
fn rect_overlap_amount(
  a : @geom.Rect,
  b : @geom.Rect,
) -> RectOverlapAmount? {
  let overlap_x =
    (if a.urx < b.urx { a.urx } else { b.urx }) -
    (if a.llx > b.llx { a.llx } else { b.llx })
  let overlap_y =
    (if a.ury < b.ury { a.ury } else { b.ury }) -
    (if a.lly > b.lly { a.lly } else { b.lly })
  if overlap_x > 0.0 && overlap_y > 0.0 {
    Some({ overlap_x, overlap_y })
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
) -> LabelRectNudge {
  match rect_overlap_amount(label_rect, other_rect) {
    Some(overlap) => {
      let other_center : @geom.Point = {
        x: (other_rect.llx + other_rect.urx) / 2.0,
        y: (other_rect.lly + other_rect.ury) / 2.0,
      }
      if overlap.overlap_x < overlap.overlap_y {
        let dir = if label_pos.x < other_center.x { -1.0 } else { 1.0 }
        let shift = overlap.overlap_x + pad
        let new_pos : @geom.Point = {
          x: label_pos.x + dir * shift,
          y: label_pos.y,
        }
        {
          label_pos: new_pos,
          label_rect: rect_from_center(new_pos, label_width, label_height, pad),
        }
      } else {
        let dir = if label_pos.y < other_center.y { -1.0 } else { 1.0 }
        let shift = overlap.overlap_y + pad
        let new_pos : @geom.Point = {
          x: label_pos.x,
          y: label_pos.y + dir * shift,
        }
        {
          label_pos: new_pos,
          label_rect: rect_from_center(new_pos, label_width, label_height, pad),
        }
      }
    }
    None => { label_pos, label_rect }
  }
}

///|
/// Graphviz parity: edge-label cluster-collision nudge mirrors local
/// postprocess adjustments driven by cluster/root label rect obstacles.
pub fn adjust_edge_label_positions(
  edges : Array[DotLayoutEdge],
  label_rects : Array[@geom.Rect],
  pad : Double,
  edge_mid_label_metrics_for : (@cgraph.Edge) -> LabelExtent?,
) -> AdjustedEdgeLabels {
  let adjusted : Array[DotLayoutEdge] = []
  let updates : Map[String, @geom.Point] = Map::new()
  for edge_layout in edges {
    let mut label_pos = edge_layout.label_pos
    match label_pos {
      Some(pos) =>
        match (edge_mid_label_metrics_for)(edge_layout.edge) {
          Some(metrics) => {
            let mut current_pos = pos
            let mut current_rect =
              rect_from_center(current_pos, metrics.width, metrics.height, pad)
            for rect in label_rects {
              let nudge = nudge_label_rect(
                current_pos,
                current_rect,
                rect,
                metrics.width,
                metrics.height,
                pad,
              )
              current_pos = nudge.label_pos
              current_rect = nudge.label_rect
            }
            label_pos = Some(current_pos)
          }
          None => ()
        }
      None => ()
    }
    match label_pos {
      Some(pos) => updates[@edge_identity.edge_key(edge_layout.edge)] = pos
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
  { edges: adjusted, updates }
}

///|
pub fn apply_label_updates_to_edges(
  edges : Array[DotLayoutEdge],
  updates : Map[String, @geom.Point],
) -> Array[DotLayoutEdge] {
  let adjusted : Array[DotLayoutEdge] = []
  for edge_layout in edges {
    let label_pos = match updates.get(@edge_identity.edge_key(edge_layout.edge)) {
      Some(pos) => Some(pos)
      None => edge_layout.label_pos
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
  adjusted
}

///|
/// Graphviz parity: sibling edge-label anti-overlap adjustment keeps
/// tail-grouped ordering and axis-gap expansion behavior unchanged.
pub fn adjust_edge_label_overlaps(
  edges : Array[DotLayoutEdge],
  nodesep_pt : Double,
  rankdir : @dot_shared.RankDir,
  edge_mid_label_metrics_for : (@cgraph.Edge) -> LabelExtent?,
  edge_tail_point_for_layout : (DotLayoutEdge) -> @geom.Point?,
) -> AdjustedEdgeLabels {
  let axis_is_x = match rankdir {
    @dot_shared.RankDir::TB | @dot_shared.RankDir::BT => true
    @dot_shared.RankDir::LR | @dot_shared.RankDir::RL => false
  }
  let tail_pad = if 2.0 > nodesep_pt * 0.3 { 2.0 } else { nodesep_pt * 0.3 }
  let gap = if 4.0 > nodesep_pt * 0.8 { 4.0 } else { nodesep_pt * 0.8 }
  let groups : Map[String, Array[EdgeLabelEntry]] = Map::new()
  for edge_layout in edges {
    match edge_layout.label_pos {
      Some(pos) =>
        match (edge_mid_label_metrics_for)(edge_layout.edge) {
          Some(metrics) => {
            let pos_axis = if axis_is_x { pos.x } else { pos.y }
            let tail_axis = match (edge_tail_point_for_layout)(edge_layout) {
              Some(point) => if axis_is_x { point.x } else { point.y }
              None => pos_axis
            }
            let base_axis =
              if tail_axis + tail_pad > pos_axis { tail_axis + tail_pad } else { pos_axis }
            let half_axis =
              if axis_is_x { metrics.width / 2.0 } else { metrics.height / 2.0 }
            let entry = {
              key: @edge_identity.edge_key(edge_layout.edge),
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
    { edges, updates }
  } else {
    {
      edges: apply_label_updates_to_edges(edges, updates),
      updates,
    }
  }
}
