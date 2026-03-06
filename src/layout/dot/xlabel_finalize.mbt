///|
/// Xlabel finalization: merge existing/new xlabel positions into layout output
/// and expand the graph bbox accordingly.

fn finalize_xlabels(
  layout : DotLayoutGraph,
  labels : Array[XLabel],
  flip : Bool,
) -> DotLayoutGraph {
  let node_updates : Map[String, @geom.Point] = Map::new()
  let edge_mid_updates : Map[String, @geom.Point] = Map::new()
  let edge_head_updates : Map[String, @geom.Point] = Map::new()
  let edge_tail_updates : Map[String, @geom.Point] = Map::new()
  let edge_xlabel_updates : Map[String, @geom.Point] = Map::new()
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
