///|
/// Graphviz parity: exterior label placement aligned to refs/graphviz/lib/label/xlabels.c
/// + lib/common/postproc.c (addXLabels/edgeMidpoint).
/// Do not change behavior without updating fixtures/tests.

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

///|
priv struct XLabelUpdateMaps {
  node_updates : Map[String, @geom.Point]
  edge_mid_updates : Map[String, @geom.Point]
  edge_head_updates : Map[String, @geom.Point]
  edge_tail_updates : Map[String, @geom.Point]
  edge_xlabel_updates : Map[String, @geom.Point]
}

///|
fn make_xlabel_update_maps() -> XLabelUpdateMaps {
  {
    node_updates: Map::new(),
    edge_mid_updates: Map::new(),
    edge_head_updates: Map::new(),
    edge_tail_updates: Map::new(),
    edge_xlabel_updates: Map::new(),
  }
}

///|
fn xlabel_center(label : XLabel) -> @geom.Point {
  @edge_spline.point(label.pos.x + label.width / 2.0, label.pos.y + label.height / 2.0)
}

///|
fn record_xlabel_update(
  updates : XLabelUpdateMaps,
  target : XLabelTarget,
  center : @geom.Point,
) -> Unit {
  match target {
    XLabelTarget::Node(name) => updates.node_updates[name] = center
    XLabelTarget::EdgeMid(key) => updates.edge_mid_updates[key] = center
    XLabelTarget::EdgeHead(key) => updates.edge_head_updates[key] = center
    XLabelTarget::EdgeTail(key) => updates.edge_tail_updates[key] = center
    XLabelTarget::EdgeXlabel(key) => updates.edge_xlabel_updates[key] = center
  }
}

///|
fn expand_bbox_for_existing_xlabel(
  bbox : @geom.Rect,
  pos : @geom.Point?,
  metrics : XLabelMetrics?,
  flip : Bool,
) -> @geom.Rect {
  let mut expanded = bbox
  match pos {
    Some(value) =>
      match metrics {
        Some(label_metrics) => {
          let dims =
            maybe_flip_dims(label_metrics.width, label_metrics.height, flip)
          expanded =
            @routing.expand_bbox_for_label_pos(
              expanded,
              Some(value),
              Some({ width: dims.width, height: dims.height }),
            )
        }
        None => ()
      }
    None => ()
  }
  expanded
}

///|
fn expand_bbox_for_existing_node_xlabels(
  bbox : @geom.Rect,
  nodes : Array[DotLayoutNode],
  flip : Bool,
) -> @geom.Rect {
  let mut expanded = bbox
  for node_layout in nodes {
    expanded =
      expand_bbox_for_existing_xlabel(
        expanded,
        node_layout.xlabel_pos,
        xlabel_metrics_for_node(node_layout.node),
        flip,
      )
  }
  expanded
}

///|
fn expand_bbox_for_existing_edge_xlabels(
  bbox : @geom.Rect,
  edges : Array[DotLayoutEdge],
  flip : Bool,
) -> @geom.Rect {
  let mut expanded = bbox
  for edge_layout in edges {
    expanded =
      expand_bbox_for_existing_xlabel(
        expanded,
        edge_layout.xlabel_pos,
        xlabel_metrics_for_edge(edge_layout.edge),
        flip,
      )
  }
  expanded
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
  collect_xlabel_candidates(layout, splines, flip, labels, objects)
  collect_cluster_label_objects(layout, objects, flip)
  if labels.length() > 0 {
    let force = parse_forcelabels(graph)
    place_labels(objects, labels, force)
  }
  finalize_xlabels(layout, labels, flip)
}
///|
/// Xlabel finalization: merge existing/new xlabel positions into layout output
/// and expand the graph bbox accordingly.

fn finalize_xlabels(
  layout : DotLayoutGraph,
  labels : Array[XLabel],
  flip : Bool,
) -> DotLayoutGraph {
  let updates = make_xlabel_update_maps()
  let mut bbox =
    expand_bbox_for_existing_node_xlabels(layout.bbox, layout.nodes, flip)
  bbox =
    expand_bbox_for_existing_edge_xlabels(bbox, layout.edges, flip)
  for label in labels {
    if !label.set {
      continue
    }
    let center = xlabel_center(label)
    bbox = @routing.expand_bbox_for_label_pos(
      bbox,
      Some(center),
      Some({ width: label.width, height: label.height }),
    )
    record_xlabel_update(updates, label.target, center)
  }
  let updated =
    apply_xlabel_updates(
      layout,
      updates,
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
///|
/// Xlabel layout update and cluster-label obstacle collection helpers.

///|
priv struct XObject {
  pos : @geom.Point
  width : Double
  height : Double
  label_index : Int?
}

fn parse_int_prefix(value : String) -> Int? {
  let mut acc = 0
  let mut seen = false
  for c in value {
    if c.is_ascii_digit() {
      seen = true
      acc = acc * 10 + (c.to_int() - '0'.to_int())
    } else {
      break
    }
  }
  if seen {
    Some(acc)
  } else {
    None
  }
}

fn parse_bool_attr(value : String, default_value : Bool) -> Bool {
  if value == "" {
    return default_value
  }
  let lower = value.to_lower()
  if lower == "false" || lower == "no" {
    return false
  }
  if lower == "true" || lower == "yes" {
    return true
  }
  match lower.get_char(0) {
    Some(c) =>
      if c.is_ascii_digit() {
        match parse_int_prefix(lower) {
          Some(number) => number != 0
          None => default_value
        }
      } else {
        default_value
      }
    None => default_value
  }
}

fn parse_forcelabels(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("forcelabels") {
    None => true
    Some(text) => parse_bool_attr(text, false)
  }
}

///|
fn apply_xlabel_updates(
  layout : DotLayoutGraph,
  updates : XLabelUpdateMaps,
) -> DotLayoutGraph {
  let update_or_fallback =
    (
      update_map : Map[String, @geom.Point],
      key : String,
      fallback : @geom.Point?,
    ) =>
      match update_map.get(key) {
        Some(pos) => Some(pos)
        None => fallback
      }
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let xlabel_pos =
      update_or_fallback(
        updates.node_updates,
        node_layout.node.name(),
        node_layout.xlabel_pos,
      )
    nodes.push({
      node: node_layout.node,
      pos: node_layout.pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: node_layout.label_pos,
      xlabel_pos,
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let key = @dot_shared.edge_key(edge_layout.edge)
    let label_pos =
      update_or_fallback(
        updates.edge_mid_updates,
        key,
        edge_layout.label_pos,
      )
    let head_label_pos =
      update_or_fallback(
        updates.edge_head_updates,
        key,
        edge_layout.head_label_pos,
      )
    let tail_label_pos =
      update_or_fallback(
        updates.edge_tail_updates,
        key,
        edge_layout.tail_label_pos,
      )
    let xlabel_pos =
      update_or_fallback(
        updates.edge_xlabel_updates,
        key,
        edge_layout.xlabel_pos,
      )
    edges.push({
      edge: edge_layout.edge,
      splines: edge_layout.splines,
      label_pos,
      head_label_pos,
      tail_label_pos,
      xlabel_pos,
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(
      apply_xlabel_updates(
        subgraph,
        updates,
      ),
    )
  }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes,
    edges,
    subgraphs,
  }
}

fn collect_cluster_label_objects(
  layout : DotLayoutGraph,
  objects : Array[XObject],
  flip : Bool,
) -> Unit {
  for subgraph in layout.subgraphs {
    match subgraph.label_pos {
      Some(pos) =>
        match graph_label_metrics(subgraph.graph) {
          Some(metrics) => {
            let dims =
              maybe_flip_dims(metrics.width_pt, metrics.height_pt, flip)
            let llx = pos.x - dims.width / 2.0
            let lly = pos.y - dims.height / 2.0
            objects.push({
              pos: @edge_spline.point(llx, lly),
              width: dims.width,
              height: dims.height,
              label_index: None,
            })
          }
          None => ()
        }
      None => ()
    }
    collect_cluster_label_objects(subgraph, objects, flip)
  }
}
///|
/// Xlabel dimension metrics and rankdir-flip helpers shared by candidate,
/// update, and finalization stages.

priv struct XLabelMetrics {
  width : Double
  height : Double
}

priv struct LabelDims {
  width : Double
  height : Double
}


fn xlabel_metrics_for_node(node : @cgraph.Node) -> XLabelMetrics? {
  match node.get_attr("xlabel") {
    Some(text) =>
      if text == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
        let font = @attrs.font_name(node.get_attr("fontname"))
        let (width, height) = label_text_dimensions(text, font, font_size_pt)
        Some({ width, height })
      }
    None => None
  }
}

fn xlabel_metrics_for_edge(edge : @cgraph.Edge) -> XLabelMetrics? {
  match edge_label_metrics_for_attr(edge, "xlabel", false) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

fn maybe_flip_dims(
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

///|
priv struct EdgeLabelAnchors {
  has_geometry : Bool
  mid_anchor : @geom.Point?
  tail_anchor : @geom.Point?
  head_anchor : @geom.Point?
}

///|
fn build_node_obstacle_with_xlabel_slot(
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
    mid_anchor: @routing.edge_midpoint_for_layout(edge_layout, use_spline_midpoint),
    tail_anchor: @routing.edge_tail_point_for_layout(edge_layout),
    head_anchor: @routing.edge_head_point_for_layout(edge_layout),
  }
}

///|
fn collect_edge_xlabel_candidates(
  edge_layout : DotLayoutEdge,
  splines : SplinesMode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let edge = edge_layout.edge
  let edge_key = @dot_shared.edge_key(edge)
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

fn collect_xlabel_candidates(
  layout : DotLayoutGraph,
  splines : SplinesMode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let edges_by_tail = build_edges_by_tail(layout)
  for node_layout in layout.nodes {
    objects.push(
      build_node_obstacle_with_xlabel_slot(
        node_layout,
        flip,
        labels,
        objects,
      ),
    )

    let edges_for_node = match edges_by_tail.get(node_layout.node.name()) {
      Some(value) => value
      None => []
    }
    for edge_layout in edges_for_node {
      collect_edge_xlabel_candidates(edge_layout, splines, flip, labels, objects)
    }
  }
}
///|
/// Exterior-label placement core: xlabel metrics, overlap scoring, candidate
/// search, and xlabels.c-style candidate selection.

const XLXDENOM : Double = 8.0

///|
const XLYDENOM : Double = 2.0

const XLPXPY : Int = 0
const XLCXPY : Int = 1
const XLNXPY : Int = 2
const XLPXCY : Int = 3
const XLNXCY : Int = 5
const XLPXNY : Int = 6
const XLCXNY : Int = 7
const XLNXNY : Int = 8

///|
priv struct XBestPos {
  n : Int
  area : Double
  pos : @geom.Point
}

fn rect_overlap_area(a : @geom.Rect, b : @geom.Rect) -> Double {
  let min_x = if a.llx > b.llx { a.llx } else { b.llx }
  let max_x = if a.urx < b.urx { a.urx } else { b.urx }
  let min_y = if a.lly > b.lly { a.lly } else { b.lly }
  let max_y = if a.ury < b.ury { a.ury } else { b.ury }
  if max_x > min_x && max_y > min_y {
    (max_x - min_x) * (max_y - min_y)
  } else {
    0.0
  }
}

fn rect_from_object(obj : XObject) -> @geom.Rect {
  let llx = obj.pos.x.round()
  let lly = obj.pos.y.round()
  let urx = (obj.pos.x + obj.width).round()
  let ury = (obj.pos.y + obj.height).round()
  { llx, lly, urx, ury }
}

fn rect_from_label(label : XLabel) -> @geom.Rect {
  let llx = label.pos.x.round()
  let lly = label.pos.y.round()
  let urx = (label.pos.x + label.width).round()
  let ury = (label.pos.y + label.height).round()
  { llx, lly, urx, ury }
}

fn label_encloses_point(label : XLabel, point_obj : XObject) -> Bool {
  let px = point_obj.pos.x
  let py = point_obj.pos.y
  px > label.pos.x &&
    px < label.pos.x + label.width &&
    py > label.pos.y &&
    py < label.pos.y + label.height
}

fn get_intrsx_index(
  op : XObject,
  cp : XObject,
  labels : Array[XLabel],
) -> Int {
  let op_set = match op.label_index {
    Some(idx) => labels[idx].set
    None => false
  }
  let cp_set = match cp.label_index {
    Some(idx) => labels[idx].set
    None => false
  }
  if !op_set || !cp_set {
    return -1
  }
  if (op.pos.x == 0.0 && op.pos.y == 0.0) ||
    (cp.pos.x == 0.0 && cp.pos.y == 0.0) {
    return -1
  }
  if cp.pos.y < op.pos.y {
    if cp.pos.x < op.pos.x {
      return XLPXPY
    }
    if cp.pos.x > op.pos.x {
      return XLNXPY
    }
    return XLCXPY
  }
  if cp.pos.y > op.pos.y {
    if cp.pos.x < op.pos.x {
      return XLPXNY
    }
    if cp.pos.x > op.pos.x {
      return XLNXNY
    }
    return XLCXNY
  }
  if cp.pos.x < op.pos.x {
    return XLPXCY
  }
  if cp.pos.x > op.pos.x {
    return XLNXCY
  }
  -1
}

fn record_intersection_slot(
  objs : Array[XObject],
  labels : Array[XLabel],
  op_idx : Int,
  cp_idx : Int,
  rect : @geom.Rect,
  area : Double,
  intrsx : Array[Int?],
) -> Double {
  let op = objs[op_idx]
  let cp = objs[cp_idx]
  let mut idx = get_intrsx_index(op, cp, labels)
  if idx < 0 {
    // Graphviz parity: default to XLNXCY when get_intrsx_index returns -1.
    idx = XLNXCY
  }
  match intrsx[idx] {
    Some(existing_idx) => {
      let mut max_area = 0.0
      let srect = rect_from_object(objs[existing_idx])
      let sa = rect_overlap_area(rect, srect)
      if sa > area {
        max_area = sa
      }
      match objs[existing_idx].label_index {
        Some(label_idx) => {
          let existing_label = labels[label_idx]
          let srect = rect_from_label(existing_label)
          let sa = rect_overlap_area(rect, srect)
          if sa > area && sa > max_area {
            max_area = sa
          }
        }
        None => ()
      }
      if max_area > 0.0 {
        return max_area
      }
      intrsx[idx] = Some(cp_idx)
      area
    }
    None => {
      intrsx[idx] = Some(cp_idx)
      area
    }
  }
}

fn xlintersections(
  objs : Array[XObject],
  labels : Array[XLabel],
  obj_idx : Int,
  intrsx : Array[Int?],
) -> XBestPos {
  let obj = objs[obj_idx]
  let label_idx = match obj.label_index {
    Some(value) => value
    None => return { n: 0, area: 0.0, pos: @edge_spline.point(0.0, 0.0) }
  }
  let label = labels[label_idx]
  let mut count = 0
  let mut area = 0.0
  for i in 0..<objs.length() {
    if i == obj_idx {
      continue
    }
    let other = objs[i]
    if other.width > 0.0 && other.height > 0.0 {
      continue
    }
    if label_encloses_point(label, other) {
      count = count + 1
    }
  }
  let rect = rect_from_label(label)
  for i in 0..<objs.length() {
    if i == obj_idx {
      continue
    }
    let other = objs[i]
    let srect = rect_from_object(other)
    let overlap = rect_overlap_area(rect, srect)
    if overlap > 0.0 {
      let ra =
        record_intersection_slot(objs, labels, obj_idx, i, rect, overlap, intrsx)
      count = count + 1
      area = area + ra
    }
    match other.label_index {
      Some(other_label_idx) => {
        let other_label = labels[other_label_idx]
        if other_label.set {
          let srect = rect_from_label(other_label)
          let overlap = rect_overlap_area(rect, srect)
          if overlap > 0.0 {
            let ra =
              record_intersection_slot(
                objs,
                labels,
                obj_idx,
                i,
                rect,
                overlap,
                intrsx,
              )
            count = count + 1
            area = area + ra
          }
        }
      }
      None => ()
    }
  }
  { n: count, area, pos: label.pos }
}

fn xladjust(
  objs : Array[XObject],
  labels : Array[XLabel],
  obj_idx : Int,
) -> XBestPos {
  let obj = objs[obj_idx]
  let label_idx = match obj.label_index {
    Some(value) => value
    None => return { n: 0, area: 0.0, pos: @edge_spline.point(0.0, 0.0) }
  }
  let label = labels[label_idx]
  let xincr = (2.0 * label.width + obj.width) / XLXDENOM
  let yincr = (2.0 * label.height + obj.height) / XLYDENOM
  let intrsx : Array[Int?] = []
  for _ in 0..<9 {
    intrsx.push(None)
  }
  let set_label = (pos : @geom.Point) => {
    let updated = {
      target: label.target,
      width: label.width,
      height: label.height,
      pos,
      set: label.set,
    }
    labels[label_idx] = updated
  }
  // x left
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y + obj.height))
  let mut best = xlintersections(objs, labels, obj_idx, intrsx)
  if best.n == 0 {
    return best
  }
  // mid
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y))
  let mut candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // x mid
  set_label(@edge_spline.point(obj.pos.x, obj.pos.y + obj.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // x right
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y + obj.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // mid
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // sliding from top left
  if intrsx[XLPXNY] is Some(_) ||
    intrsx[XLCXNY] is Some(_) ||
    intrsx[XLNXNY] is Some(_) ||
    intrsx[XLPXCY] is Some(_) ||
    intrsx[XLPXPY] is Some(_) {
    if intrsx[XLCXNY] is None && intrsx[XLNXNY] is None {
      let mut x = obj.pos.x - label.width
      while x <= obj.pos.x + obj.width {
        set_label(@edge_spline.point(x, obj.pos.y + obj.height))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        x = x + xincr
      }
    }
    if intrsx[XLPXCY] is None && intrsx[XLPXPY] is None {
      let mut y = obj.pos.y + obj.height
      while y >= obj.pos.y - label.height {
        set_label(@edge_spline.point(obj.pos.x - label.width, y))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        y = y - yincr
      }
    }
  }

  // sliding from bottom right
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y - label.height))
  if intrsx[XLNXPY] is Some(_) ||
    intrsx[XLCXPY] is Some(_) ||
    intrsx[XLPXPY] is Some(_) ||
    intrsx[XLNXCY] is Some(_) ||
    intrsx[XLNXNY] is Some(_) {
    if intrsx[XLCXPY] is None && intrsx[XLPXPY] is None {
      let mut x = obj.pos.x + obj.width
      while x >= obj.pos.x - label.width {
        set_label(@edge_spline.point(x, obj.pos.y - label.height))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        x = x - xincr
      }
    }
    if intrsx[XLNXCY] is None && intrsx[XLNXNY] is None {
      let mut y = obj.pos.y - label.height
      while y <= obj.pos.y + obj.height {
        set_label(@edge_spline.point(obj.pos.x + obj.width, y))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        y = y + yincr
      }
    }
  }
  best
}

fn place_labels(
  objs : Array[XObject],
  labels : Array[XLabel],
  force : Bool,
) -> Unit {
  for i in 0..<objs.length() {
    let obj = objs[i]
    let label_idx = match obj.label_index {
      Some(value) => value
      None => continue
    }
    let best = xladjust(objs, labels, i)
    if best.n == 0 {
      let label = labels[label_idx]
      labels[label_idx] = {
        target: label.target,
        width: label.width,
        height: label.height,
        pos: label.pos,
        set: true,
      }
    } else if best.area == 0.0 || force {
      let label = labels[label_idx]
      labels[label_idx] = {
        target: label.target,
        width: label.width,
        height: label.height,
        pos: best.pos,
        set: true,
      }
    }
  }
}
