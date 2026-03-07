///|
/// Graphviz parity: exterior label placement aligned to refs/graphviz/lib/label/xlabels.c
/// + lib/common/postproc.c (addXLabels/edgeMidpoint).
/// Do not change behavior without updating fixtures/tests.

type LayoutTree = @shared.LayoutTree
type RankDir = @shared.RankDir


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

pub fn apply_xlabels(
  layout : LayoutTree,
  splines : SplinesMode,
) -> LayoutTree {
  let rankdir = @shared.graph_rankdir(layout.graph)
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let labels : Array[XLabel] = []
  let objects : Array[XObject] = []
  collect_xlabel_candidates(layout, splines, flip, labels, objects)
  collect_cluster_label_objects(layout, objects, flip)
  if labels.length() > 0 {
    let force = parse_forcelabels(layout.graph)
    @xlabel_solver.place_labels(objects, labels, force)
  }
  finalize_xlabels(layout, labels, flip)
}
///|
/// Xlabel finalization: merge existing/new xlabel positions into layout output
/// and expand the graph bbox accordingly.

fn finalize_xlabels(
  layout : LayoutTree,
  labels : Array[XLabel],
  flip : Bool,
) -> LayoutTree {
  let updates = make_xlabel_update_maps()
  let mut bbox =
    expand_bbox_for_existing_node_xlabels(layout.bbox, layout.nodes, flip)
  bbox =
    expand_bbox_for_existing_edge_xlabels(bbox, layout.edges, flip)
  for label in labels {
    if !label.set {
      continue
    }
    let center = @xlabel_solver.xlabel_center(label)
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
  layout : LayoutTree,
  updates : XLabelUpdateMaps,
) -> LayoutTree {
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
    let key = @shared.edge_key(edge_layout.edge)
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
  let subgraphs : Array[LayoutTree] = []
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
  layout : LayoutTree,
  objects : Array[XObject],
  flip : Bool,
) -> Unit {
  for subgraph in layout.subgraphs {
    match subgraph.label_pos {
      Some(pos) =>
        match @label_metrics.graph_label_metrics(subgraph.graph) {
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
fn collect_xlabel_candidates(
  layout : LayoutTree,
  splines : SplinesMode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let edges_by_tail = build_edges_by_tail(layout.edges)
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
