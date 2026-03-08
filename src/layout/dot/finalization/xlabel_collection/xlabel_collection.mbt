///|
/// Xlabel candidate collection kernels: label metrics, rankdir-aware
/// dimensions, obstacle construction, and edge-anchor candidate assembly.

type DotLayoutNode = @shared.DotLayoutNode
type DotLayoutEdge = @shared.DotLayoutEdge
type SplinesMode = @shared.SplinesMode
type XLabelTarget = @xlabel_solver.XLabelTarget
type XLabel = @xlabel_solver.XLabel
type XObject = @xlabel_solver.XObject

///|
/// Xlabel dimension metrics and rankdir-flip helpers shared by candidate,
/// update, and finalization stages.

pub struct XLabelMetrics {
  width : Double
  height : Double
}

pub struct LabelDims {
  width : Double
  height : Double
}


pub fn xlabel_metrics_for_node(node : @cgraph.Node) -> XLabelMetrics? {
  match node.get_attr("xlabel") {
    Some(text) =>
      if text == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
        let font = @attrs.font_name(node.get_attr("fontname"))
        let (width, height) = @label_metrics.label_text_dimensions(text, font, font_size_pt)
        Some({ width, height })
      }
    None => None
  }
}

pub fn xlabel_metrics_for_edge(edge : @cgraph.Edge) -> XLabelMetrics? {
  match @edge_label_metrics.edge_label_metrics_for_attr(edge, "xlabel", false) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

pub fn maybe_flip_dims(
  width : Double,
  height : Double,
  flip : Bool,
) -> LabelDims {
  if flip {
    { width: height, height: width }
  } else {
    { width, height }
  }
}
///|
/// Xlabel candidate collection from node/edge geometry and existing label
/// placements before running xlabels.c-style search.

pub fn build_edges_by_tail(
  edges : Array[DotLayoutEdge],
) -> Map[String, Array[DotLayoutEdge]] {
  let edges_by_tail : Map[String, Array[DotLayoutEdge]] = Map::new()
  for edge_layout in edges {
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
  match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

fn edge_attr_metrics_for_xlabel(
  edge : @cgraph.Edge,
  key : String,
) -> XLabelMetrics? {
  match @edge_label_metrics.edge_label_metrics_for_attr(edge, key, true) {
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

///|
priv struct EdgeLabelAnchors {
  has_geometry : Bool
  mid_anchor : @geom.Point?
  tail_anchor : @geom.Point?
  head_anchor : @geom.Point?
}

///|
pub fn build_node_obstacle_with_xlabel_slot(
  node_layout : DotLayoutNode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> XObject {
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
  {
    pos: @edge_spline.point(llx, lly),
    width: obj_dims.width,
    height: obj_dims.height,
    label_index,
  }
}

///|
fn collect_edge_label_anchors(
  edge_layout : DotLayoutEdge,
  splines : SplinesMode,
) -> EdgeLabelAnchors {
  let has_geometry = edge_layout.splines.length() > 0
  if !has_geometry {
    return {
      has_geometry,
      mid_anchor: None,
      tail_anchor: None,
      head_anchor: None,
    }
  }
  let use_spline_midpoint =
    splines == SplinesMode::Spline || splines == SplinesMode::Curved
  {
    has_geometry,
    mid_anchor: @edge_label.edge_midpoint_for_layout(edge_layout, use_spline_midpoint),
    tail_anchor: @edge_label.edge_tail_point_for_layout(edge_layout),
    head_anchor: @edge_label.edge_head_point_for_layout(edge_layout),
  }
}

///|
pub fn collect_edge_xlabel_candidates(
  edge_layout : DotLayoutEdge,
  splines : SplinesMode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let edge = edge_layout.edge
  let edge_key = @edge_identity.edge_key(edge)
  let anchors = collect_edge_label_anchors(edge_layout, splines)
  collect_edge_label_candidate(
    XLabelTarget::EdgeMid(edge_key),
    edge_layout.label_pos,
    edge_mid_metrics_for_xlabel(edge),
    anchors.mid_anchor,
    anchors.has_geometry,
    flip,
    labels,
    objects,
  )
  collect_edge_label_candidate(
    XLabelTarget::EdgeTail(edge_key),
    edge_layout.tail_label_pos,
    edge_attr_metrics_for_xlabel(edge, "taillabel"),
    anchors.tail_anchor,
    anchors.has_geometry,
    flip,
    labels,
    objects,
  )
  collect_edge_label_candidate(
    XLabelTarget::EdgeHead(edge_key),
    edge_layout.head_label_pos,
    edge_attr_metrics_for_xlabel(edge, "headlabel"),
    anchors.head_anchor,
    anchors.has_geometry,
    flip,
    labels,
    objects,
  )
  collect_edge_label_candidate(
    XLabelTarget::EdgeXlabel(edge_key),
    edge_layout.xlabel_pos,
    xlabel_metrics_for_edge(edge),
    anchors.mid_anchor,
    anchors.has_geometry,
    flip,
    labels,
    objects,
  )
}

