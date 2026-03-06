///|
/// Xlabel candidate collection from node/edge geometry and existing label
/// placements before running xlabels.c-style search.

fn build_edges_by_tail(
  layout : DotLayoutGraph,
) -> Map[String, Array[DotLayoutEdge]] {
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
  edges_by_tail
}

fn edge_mid_metrics_for_xlabel(edge : @cgraph.Edge) -> XLabelMetrics? {
  match edge_mid_label_metrics(edge) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

fn edge_attr_metrics_for_xlabel(
  edge : @cgraph.Edge,
  key : String,
) -> XLabelMetrics? {
  match edge_label_metrics_for_attr(edge, key, true) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

fn push_existing_label_object(
  pos : @geom.Point,
  metrics : XLabelMetrics,
  flip : Bool,
  objects : Array[XObject],
) -> Unit {
  let label_dims =
    maybe_flip_dims(metrics.width, metrics.height, flip)
  let pos_ll =
    @edge_spline.point(
      pos.x - label_dims.width / 2.0,
      pos.y - label_dims.height / 2.0,
    )
  objects.push({
    pos: pos_ll,
    width: label_dims.width,
    height: label_dims.height,
    label_index: None,
  })
}

fn push_unset_xlabel_label(
  target : XLabelTarget,
  metrics : XLabelMetrics,
  flip : Bool,
  labels : Array[XLabel],
) -> Int {
  let label_dims =
    maybe_flip_dims(metrics.width, metrics.height, flip)
  let idx = labels.length()
  labels.push({
    target,
    width: label_dims.width,
    height: label_dims.height,
    pos: @edge_spline.point(0.0, 0.0),
    set: false,
  })
  idx
}

fn push_deferred_label_anchor(
  target : XLabelTarget,
  metrics : XLabelMetrics,
  anchor : @geom.Point,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let idx =
    push_unset_xlabel_label(target, metrics, flip, labels)
  objects.push({
    pos: anchor,
    width: 0.0,
    height: 0.0,
    label_index: Some(idx),
  })
}

fn collect_edge_label_candidate(
  target : XLabelTarget,
  current_pos : @geom.Point?,
  metrics : XLabelMetrics?,
  anchor : @geom.Point?,
  has_geometry : Bool,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  match current_pos {
    Some(pos) =>
      match metrics {
        Some(value) => push_existing_label_object(pos, value, flip, objects)
        None => ()
      }
    None =>
      if has_geometry {
        match (metrics, anchor) {
          (Some(value), Some(point)) =>
            push_deferred_label_anchor(
              target,
              value,
              point,
              flip,
              labels,
              objects,
            )
          _ => ()
        }
      }
  }
}

fn collect_xlabel_candidates(
  layout : DotLayoutGraph,
  splines : SplinesMode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let edges_by_tail = build_edges_by_tail(layout)
  for node_layout in layout.nodes {
    let node = node_layout.node
    let width_pt = node_layout.width_in * 72.0
    let height_pt = node_layout.height_in * 72.0
    let obj_dims = maybe_flip_dims(width_pt, height_pt, flip)
    let llx = node_layout.pos.x - obj_dims.width / 2.0
    let lly = node_layout.pos.y - obj_dims.height / 2.0
    let mut label_index : Int? = None
    match xlabel_metrics_for_node(node) {
      Some(metrics) =>
        match node_layout.xlabel_pos {
          Some(pos) =>
            push_existing_label_object(pos, metrics, flip, objects)
          None =>
            label_index = Some(
              push_unset_xlabel_label(
                XLabelTarget::Node(node.name()),
                metrics,
                flip,
                labels,
              ),
            )
        }
      None => ()
    }
    objects.push({
      pos: @edge_spline.point(llx, lly),
      width: obj_dims.width,
      height: obj_dims.height,
      label_index,
    })

    let edges_for_node = match edges_by_tail.get(node.name()) {
      Some(value) => value
      None => []
    }
    for edge_layout in edges_for_node {
      let edge = edge_layout.edge
      let edge_key = @dot_shared.edge_key(edge)
      let has_geometry = edge_layout.splines.length() > 0
      let mid_anchor =
        if has_geometry {
          edge_midpoint_for_layout(edge_layout, splines)
        } else {
          None
        }
      let tail_anchor =
        if has_geometry {
          edge_tail_point_for_layout(edge_layout)
        } else {
          None
        }
      let head_anchor =
        if has_geometry {
          edge_head_point_for_layout(edge_layout)
        } else {
          None
        }
      collect_edge_label_candidate(
        XLabelTarget::EdgeMid(edge_key),
        edge_layout.label_pos,
        edge_mid_metrics_for_xlabel(edge),
        mid_anchor,
        has_geometry,
        flip,
        labels,
        objects,
      )
      collect_edge_label_candidate(
        XLabelTarget::EdgeTail(edge_key),
        edge_layout.tail_label_pos,
        edge_attr_metrics_for_xlabel(edge, "taillabel"),
        tail_anchor,
        has_geometry,
        flip,
        labels,
        objects,
      )
      collect_edge_label_candidate(
        XLabelTarget::EdgeHead(edge_key),
        edge_layout.head_label_pos,
        edge_attr_metrics_for_xlabel(edge, "headlabel"),
        head_anchor,
        has_geometry,
        flip,
        labels,
        objects,
      )
      collect_edge_label_candidate(
        XLabelTarget::EdgeXlabel(edge_key),
        edge_layout.xlabel_pos,
        xlabel_metrics_for_edge(edge),
        mid_anchor,
        has_geometry,
        flip,
        labels,
        objects,
      )
    }
  }
}
