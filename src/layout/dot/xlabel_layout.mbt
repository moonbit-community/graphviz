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

fn apply_xlabels(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  splines : SplinesMode,
) -> DotLayoutGraph {
  let rankdir = @dot_shared.graph_rankdir(graph)
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
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
  collect_cluster_label_objects(layout, objects, flip)
  if labels.length() > 0 {
    let force = parse_forcelabels(graph)
    place_labels(objects, labels, force)
  }
  let mut bbox = layout.bbox
  for node_layout in layout.nodes {
    match node_layout.xlabel_pos {
      Some(pos) =>
        match xlabel_metrics_for_node(node_layout.node) {
          Some(metrics) => {
            let dims =
              maybe_flip_dims(metrics.width, metrics.height, flip)
            bbox =
              expand_bbox_for_label_pos(
                bbox,
                Some(pos),
                Some({ width: dims.width, height: dims.height }),
              )
          }
          None => ()
        }
      None => ()
    }
  }
  for edge_layout in layout.edges {
    match edge_layout.xlabel_pos {
      Some(pos) =>
        match xlabel_metrics_for_edge(edge_layout.edge) {
          Some(metrics) => {
            let dims =
              maybe_flip_dims(metrics.width, metrics.height, flip)
            bbox =
              expand_bbox_for_label_pos(
                bbox,
                Some(pos),
                Some({ width: dims.width, height: dims.height }),
              )
          }
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
      @edge_spline.point(label.pos.x + label.width / 2.0, label.pos.y + label.height / 2.0)
    bbox = expand_bbox_for_label_pos(
      bbox,
      Some(center),
      Some({ width: label.width, height: label.height }),
    )
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
