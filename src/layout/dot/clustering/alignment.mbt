///|
/// Graphviz parity: cluster-alignment input keeps geometry maps and callbacks
/// grouped so recursive rounding/label expansion wiring stays explicit.
pub(all) struct ClusterAlignmentInput {
  graph : @cgraph.Graph
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_clusters : Map[String, String]
  sizes : Map[String, @shared.NodeSize]
  cluster_margin_pt_for : (@cgraph.Graph) -> Double
  expand_cluster_label_bbox : (@cgraph.Graph, @geom.Rect) -> @geom.Rect
}

///|
fn compute_nodes_bbox(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  sizes : Map[String, @shared.NodeSize],
) -> @geom.Rect? {
  let mut bbox_set = false
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  for node in graph.nodes() {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => continue
    }
    let size = match sizes.get(name) {
      Some(value) => value
      None => continue
    }
    let half_w = size.width_pt / 2.0
    let half_h = size.height_pt / 2.0
    let left = pos.x - half_w
    let right = pos.x + half_w
    let bottom = pos.y - half_h
    let top = pos.y + half_h
    if !bbox_set {
      min_x = left
      max_x = right
      min_y = bottom
      max_y = top
      bbox_set = true
    } else {
      if left < min_x {
        min_x = left
      }
      if right > max_x {
        max_x = right
      }
      if bottom < min_y {
        min_y = bottom
      }
      if top > max_y {
        max_y = top
      }
    }
  }
  if bbox_set {
    Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
  } else {
    None
  }
}

///|
fn shift_point(point : @geom.Point, dx : Double, dy : Double) -> @geom.Point {
  { x: point.x + dx, y: point.y + dy }
}

///|
fn round_bbox_x_only(bbox : @geom.Rect) -> @geom.Rect {
  {
    llx: bbox.llx.round(),
    lly: bbox.lly,
    urx: bbox.urx.round(),
    ury: bbox.ury,
  }
}

///|
fn merge_bbox(base : @geom.Rect, other : @geom.Rect) -> @geom.Rect {
  {
    llx: if base.llx < other.llx {
      base.llx
    } else {
      other.llx
    },
    lly: if base.lly < other.lly {
      base.lly
    } else {
      other.lly
    },
    urx: if base.urx > other.urx {
      base.urx
    } else {
      other.urx
    },
    ury: if base.ury > other.ury {
      base.ury
    } else {
      other.ury
    },
  }
}

///|
fn shift_graph_positions(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_clusters : Map[String, String],
  dx : Double,
  dy : Double,
) -> Unit {
  let members : Map[String, Bool] = Map::new()
  @shared.collect_graph_nodes(graph, members)
  for name, _ in members {
    match positions.get(name) {
      Some(pos) => positions[name] = shift_point(pos, dx, dy)
      None => ()
    }
  }
  let clusters : Map[String, Bool] = Map::new()
  @shared.collect_cluster_names(graph, clusters)
  for vnode, key in vnode_clusters {
    if clusters.get(key) is Some(_) {
      match vnode_positions.get(vnode) {
        Some(pos) => vnode_positions[vnode] = shift_point(pos, dx, dy)
        None => ()
      }
    }
  }
}

///|
/// Graphviz parity: cluster bbox rounding/center alignment follows dot postproc
/// cluster pass ordering; callback-owned margin/label expansion must preserve
/// existing behavior from the caller package.
pub fn adjust_cluster_positions(
  input : ClusterAlignmentInput,
) -> @geom.Rect? {
  let mut bbox = compute_nodes_bbox(input.graph, input.positions, input.sizes)
  for child in input.graph.subgraphs() {
    match
      adjust_cluster_positions(
        {
          graph: child,
          positions: input.positions,
          vnode_positions: input.vnode_positions,
          vnode_clusters: input.vnode_clusters,
          sizes: input.sizes,
          cluster_margin_pt_for: input.cluster_margin_pt_for,
          expand_cluster_label_bbox: input.expand_cluster_label_bbox,
        },
      ) {
      Some(child_bbox) =>
        bbox = Some(match bbox {
          Some(current) => merge_bbox(current, child_bbox)
          None => child_bbox
        })
      None => ()
    }
  }
  let mut current = match bbox {
    Some(value) => value
    None => return None
  }
  if @shared.is_cluster_graph(input.graph) {
    let pad = (input.cluster_margin_pt_for)(input.graph)
    current = {
      llx: current.llx - pad,
      lly: current.lly - pad,
      urx: current.urx + pad,
      ury: current.ury + pad,
    }
    current = (input.expand_cluster_label_bbox)(input.graph, current)
    let rounded = round_bbox_x_only(current)
    let center_shift = (rounded.llx + rounded.urx) / 2.0 -
      (current.llx + current.urx) / 2.0
    if center_shift != 0.0 {
      shift_graph_positions(
        input.graph,
        input.positions,
        input.vnode_positions,
        input.vnode_clusters,
        center_shift,
        0.0,
      )
      current = {
        llx: current.llx + center_shift,
        lly: current.lly,
        urx: current.urx + center_shift,
        ury: current.ury,
      }
    }
    return Some(round_bbox_x_only(current))
  }
  Some(current)
}
