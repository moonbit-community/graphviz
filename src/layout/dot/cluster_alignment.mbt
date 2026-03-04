///|
/// Graphviz parity: intercluster alignment payload keeps rank and cluster maps
/// grouped so cross-cluster x-shift wiring remains explicit and stable.
priv struct InterclusterAlignmentInput {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  x_positions : Map[String, Double]
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
}

///|
fn adjust_intercluster_alignment(
  input : InterclusterAlignmentInput,
) -> Unit {
  let cluster_rank_nodes : Map[String, Array[String]] = Map::new()
  let cluster_rank_value : Map[String, Int] = Map::new()
  for node in input.nodes {
    let name = node.name()
    let cluster = match input.cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match input.ranks.get(name) {
      Some(value) => value
      None => continue
    }
    let key = cluster_rank_key(cluster, rank)
    cluster_rank_value[key] = rank
    match cluster_rank_nodes.get(key) {
      Some(list) => list.push(name)
      None => cluster_rank_nodes[key] = [name]
    }
  }
  let cluster_rank_targets : Map[String, Map[String, Bool]] = Map::new()
  for edge in input.edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_cluster = match input.intercluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match input.intercluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster == "" || tail_cluster == head_cluster {
      continue
    }
    let tail_rank = match input.ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let key = cluster_rank_key(tail_cluster, tail_rank)
    match cluster_rank_targets.get(key) {
      Some(targets) => targets[head] = true
      None => {
        let targets : Map[String, Bool] = Map::new()
        targets[head] = true
        cluster_rank_targets[key] = targets
      }
    }
  }
  let eps = 0.01
  for key, names in cluster_rank_nodes {
    if names.length() < 2 {
      continue
    }
    let targets = match cluster_rank_targets.get(key) {
      Some(value) => value
      None => continue
    }
    if targets.length() != 1 {
      continue
    }
    let mut target_name = ""
    for name, _ in targets {
      target_name = name
      break
    }
    let target_x = match input.x_positions.get(target_name) {
      Some(value) => value
      None => continue
    }
    let mut aligned = false
    for name in names {
      match input.x_positions.get(name) {
        Some(value) =>
          if Double::abs(value - target_x) <= eps {
            aligned = true
            break
          }
        None => ()
      }
    }
    if !aligned {
      continue
    }
    let rank = match cluster_rank_value.get(key) {
      Some(value) => value
      None => continue
    }
    let shift = rank_nodesep_pt(rank, input.nodesep_pt, input.has_edge_labels)
    for name in names {
      match input.x_positions.get(name) {
        Some(value) => input.x_positions[name] = value - shift
        None => ()
      }
    }
  }
}

///|
fn compute_nodes_bbox(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
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
fn shift_graph_positions(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_clusters : Map[String, String],
  dx : Double,
  dy : Double,
) -> Unit {
  let members : Map[String, Bool] = Map::new()
  @dot_shared.collect_graph_nodes(graph, members)
  for name, _ in members {
    match positions.get(name) {
      Some(pos) => positions[name] = shift_point(pos, dx, dy)
      None => ()
    }
  }
  let clusters : Map[String, Bool] = Map::new()
  collect_cluster_names(graph, clusters)
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
/// Graphviz parity: cluster-position adjustment input keeps the recursive
/// graph walk payload grouped so bbox expansion and center-shift propagation
/// remain explicit and stable.
priv struct ClusterPositionAdjustInput {
  graph : @cgraph.Graph
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_clusters : Map[String, String]
  sizes : Map[String, NodeSize]
}

///|
fn adjust_cluster_positions(
  input : ClusterPositionAdjustInput,
) -> @geom.Rect? {
  let mut bbox = compute_nodes_bbox(input.graph, input.positions, input.sizes)
  for child in input.graph.subgraphs() {
    match adjust_cluster_positions(
      {
        graph: child,
        positions: input.positions,
        vnode_positions: input.vnode_positions,
        vnode_clusters: input.vnode_clusters,
        sizes: input.sizes,
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
  if @dot_shared.is_cluster_graph(input.graph) {
    let pad = cluster_margin_pt(input.graph)
    current = {
      llx: current.llx - pad,
      lly: current.lly - pad,
      urx: current.urx + pad,
      ury: current.ury + pad,
    }
    match graph_label_metrics(input.graph) {
      Some(metrics) => {
        let loc = graph_label_loc(input.graph)
        current =
          expand_bbox_for_label(
            current,
            metrics.width_pt,
            metrics.height_pt,
            loc,
          )
      }
      None => ()
    }
    let rounded = round_bbox(current)
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
    return Some(round_bbox(current))
  }
  Some(current)
}

///|
fn collect_cluster_bboxes(
  subgraphs : Array[DotLayoutGraph],
  out : Map[String, @geom.Rect],
) -> Unit {
  for layout in subgraphs {
    if @dot_shared.is_cluster_graph(layout.graph) {
      match layout.graph.name() {
        Some(name) => out[name] = layout.bbox
        None => ()
      }
    }
    if layout.subgraphs.length() > 0 {
      collect_cluster_bboxes(layout.subgraphs, out)
    }
  }
}
