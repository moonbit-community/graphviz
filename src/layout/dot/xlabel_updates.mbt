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

fn apply_xlabel_updates(
  layout : DotLayoutGraph,
  node_updates : Map[String, @geom.Point],
  edge_mid_updates : Map[String, @geom.Point],
  edge_head_updates : Map[String, @geom.Point],
  edge_tail_updates : Map[String, @geom.Point],
  edge_xlabel_updates : Map[String, @geom.Point],
) -> DotLayoutGraph {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let xlabel_pos = match node_updates.get(node_layout.node.name()) {
      Some(pos) => Some(pos)
      None => node_layout.xlabel_pos
    }
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
    let label_pos = match edge_mid_updates.get(key) {
      Some(pos) => Some(pos)
      None => edge_layout.label_pos
    }
    let head_label_pos = match edge_head_updates.get(key) {
      Some(pos) => Some(pos)
      None => edge_layout.head_label_pos
    }
    let tail_label_pos = match edge_tail_updates.get(key) {
      Some(pos) => Some(pos)
      None => edge_layout.tail_label_pos
    }
    let xlabel_pos = match edge_xlabel_updates.get(key) {
      Some(pos) => Some(pos)
      None => edge_layout.xlabel_pos
    }
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
        node_updates,
        edge_mid_updates,
        edge_head_updates,
        edge_tail_updates,
        edge_xlabel_updates,
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
