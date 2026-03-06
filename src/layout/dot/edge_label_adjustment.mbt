///|
/// Edge-label collision adjustment and bbox expansion helpers for cluster and
/// sibling-overlap postprocessing.

///|
priv struct EdgeLabelEntry {
  key : String
  pos : @geom.Point
  base_axis : Double
  half_axis : Double
}

///|
priv struct AdjustedEdgeLabels {
  edges : Array[DotLayoutEdge]
  updates : Map[String, @geom.Point]
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
          Some(metrics) =>
            rects.push(
              rect_from_center(
                pos,
                metrics.width_pt,
                metrics.height_pt,
                pad,
              ),
            )
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
) -> AdjustedEdgeLabels {
  let adjusted : Array[DotLayoutEdge] = []
  let updates : Map[String, @geom.Point] = Map::new()
  for edge_layout in edges {
    let mut label_pos = edge_layout.label_pos
    match label_pos {
      Some(pos) =>
        match edge_mid_label_metrics(edge_layout.edge) {
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
  { edges: adjusted, updates }
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
fn adjust_labels_for_clusters(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
) -> DotLayoutGraph {
  let pad = if nodesep_pt * 0.2 < 2.0 { 2.0 } else { nodesep_pt * 0.2 }
  let label_rects : Array[@geom.Rect] = []
  match layout.label_pos {
    Some(pos) =>
      match graph_label_metrics(layout.graph) {
        Some(metrics) =>
          label_rects.push(
            rect_from_center(pos, metrics.width_pt, metrics.height_pt, pad),
          )
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
        adjust_labels_for_clusters(subgraph, nodesep_pt),
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
    let adjusted_labels = adjust_edge_label_positions(
      layout.edges,
      label_rects,
      pad,
    )
    let updated_subgraphs =
      apply_edge_label_updates(layout.subgraphs, adjusted_labels.updates)
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in updated_subgraphs {
      subgraphs.push(
        adjust_labels_for_clusters(subgraph, nodesep_pt),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: adjusted_labels.edges,
      subgraphs,
    }
  }
}

///|
fn adjust_labels_for_overlaps(
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
          Some(metrics) => {
            let pos_axis = if axis_is_x { pos.x } else { pos.y }
            let tail_axis = match edge_tail_point(edge_layout) {
              Some(point) => if axis_is_x { point.x } else { point.y }
              None => pos_axis
            }
            let base_axis =
              if tail_axis + tail_pad > pos_axis { tail_axis + tail_pad } else { pos_axis }
            let half_axis =
              if axis_is_x { metrics.width / 2.0 } else { metrics.height / 2.0 }
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
        adjust_labels_for_overlaps(subgraph, nodesep_pt, rankdir),
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
        adjust_labels_for_overlaps(subgraph, nodesep_pt, rankdir),
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
  @dot_shared.env_flag_enabled_nonempty(@sys.get_env_var("DOT_ADJUST_EDGE_LABELS"))
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
