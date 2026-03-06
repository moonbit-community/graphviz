///|
/// Xlabel candidate collection from node/edge geometry and existing label
/// placements before running xlabels.c-style search.

fn collect_xlabel_candidates(
  layout : DotLayoutGraph,
  splines : SplinesMode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
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
    let obj_dims = maybe_flip_dims(width_pt, height_pt, flip)
    let llx = node_layout.pos.x - obj_dims.width / 2.0
    let lly = node_layout.pos.y - obj_dims.height / 2.0
    let mut label_index : Int? = None
    let mut label_object : XObject? = None
    match xlabel_metrics_for_node(node) {
      Some(metrics) => {
        let label_dims =
          maybe_flip_dims(metrics.width, metrics.height, flip)
        match node_layout.xlabel_pos {
          Some(pos) => {
            let pos_ll =
              @edge_spline.point(
                pos.x - label_dims.width / 2.0,
                pos.y - label_dims.height / 2.0,
              )
            label_object = Some({
              pos: pos_ll,
              width: label_dims.width,
              height: label_dims.height,
              label_index: None,
            })
          }
          None => {
            let idx = labels.length()
            labels.push({
              target: XLabelTarget::Node(node.name()),
              width: label_dims.width,
              height: label_dims.height,
              pos: @edge_spline.point(0.0, 0.0),
              set: false,
            })
            label_index = Some(idx)
          }
        }
      }
      None => ()
    }
    objects.push({
      pos: @edge_spline.point(llx, lly),
      width: obj_dims.width,
      height: obj_dims.height,
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
      let edge_key_value = @dot_shared.edge_key(edge)
      let has_geometry = edge_layout.splines.length() > 0
      match edge_layout.label_pos {
        Some(pos) =>
          match edge_mid_label_metrics(edge) {
            Some(metrics) => {
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
            None => ()
          }
        None =>
          if has_geometry {
            match edge_mid_label_metrics(edge) {
              Some(metrics) =>
                match edge_midpoint_for_layout(edge_layout, splines) {
                  Some(anchor) => {
                    let label_dims =
                      maybe_flip_dims(metrics.width, metrics.height, flip)
                    let idx = labels.length()
                    labels.push({
                      target: XLabelTarget::EdgeMid(edge_key_value),
                      width: label_dims.width,
                      height: label_dims.height,
                      pos: @edge_spline.point(0.0, 0.0),
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
            Some(metrics) => {
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
            None => ()
          }
        None =>
          if has_geometry {
            match edge_label_metrics_for_attr(edge, "taillabel", true) {
              Some(metrics) =>
                match edge_tail_point_for_layout(edge_layout) {
                  Some(anchor) => {
                    let label_dims =
                      maybe_flip_dims(metrics.width, metrics.height, flip)
                    let idx = labels.length()
                    labels.push({
                      target: XLabelTarget::EdgeTail(edge_key_value),
                      width: label_dims.width,
                      height: label_dims.height,
                      pos: @edge_spline.point(0.0, 0.0),
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
            Some(metrics) => {
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
            None => ()
          }
        None =>
          if has_geometry {
            match edge_label_metrics_for_attr(edge, "headlabel", true) {
              Some(metrics) =>
                match edge_head_point_for_layout(edge_layout) {
                  Some(anchor) => {
                    let label_dims =
                      maybe_flip_dims(metrics.width, metrics.height, flip)
                    let idx = labels.length()
                    labels.push({
                      target: XLabelTarget::EdgeHead(edge_key_value),
                      width: label_dims.width,
                      height: label_dims.height,
                      pos: @edge_spline.point(0.0, 0.0),
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
            Some(metrics) => {
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
            None => ()
          }
        None =>
          if has_geometry {
            match xlabel_metrics_for_edge(edge) {
              Some(metrics) =>
                match edge_midpoint_for_layout(edge_layout, splines) {
                  Some(anchor) => {
                    let label_dims =
                      maybe_flip_dims(metrics.width, metrics.height, flip)
                    let idx = labels.length()
                    labels.push({
                      target: XLabelTarget::EdgeXlabel(edge_key_value),
                      width: label_dims.width,
                      height: label_dims.height,
                      pos: @edge_spline.point(0.0, 0.0),
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
}
