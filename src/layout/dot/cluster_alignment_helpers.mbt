///|
fn adjust_intercluster_alignment(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  x_positions : Map[String, Double],
  cluster_keys : Map[String, String],
  intercluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Unit {
  let cluster_rank_nodes : Map[String, Array[String]] = Map::new()
  let cluster_rank_value : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
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
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_cluster = match intercluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match intercluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster == "" || tail_cluster == head_cluster {
      continue
    }
    let tail_rank = match ranks.get(tail) {
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
    let target_x = match x_positions.get(target_name) {
      Some(value) => value
      None => continue
    }
    let mut aligned = false
    for name in names {
      match x_positions.get(name) {
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
    let shift = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    for name in names {
      match x_positions.get(name) {
        Some(value) => x_positions[name] = value - shift
        None => ()
      }
    }
  }
}

///|
fn reorder_groups_by_cluster_order(
  groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
  cluster_order_base : Map[String, Int],
  node_order : Map[String, Int],
) -> Unit {
  let mut has_order = false
  for _name, _ in cluster_order_base {
    has_order = true
    break
  }
  if !has_order {
    return ()
  }
  for _rank, names in groups {
    if names.length() <= 1 {
      continue
    }
    let mut all_cluster = true
    for name in names {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" || cluster_order_base.get(cluster) is None {
        all_cluster = false
        break
      }
    }
    if !all_cluster {
      continue
    }
    let original_index : Map[String, Int] = Map::new()
    for i in 0..<names.length() {
      original_index[names[i]] = i
    }
    names.sort_by((a, b) => {
      let a_cluster = match cluster_keys.get(a) {
        Some(value) => value
        None => ""
      }
      let b_cluster = match cluster_keys.get(b) {
        Some(value) => value
        None => ""
      }
      let a_order = match cluster_order_base.get(a_cluster) {
        Some(value) => value
        None => 0
      }
      let b_order = match cluster_order_base.get(b_cluster) {
        Some(value) => value
        None => 0
      }
      if a_order < b_order {
        -1
      } else if a_order > b_order {
        1
      } else {
        let a_idx = match original_index.get(a) {
          Some(value) => value
          None => 0
        }
        let b_idx = match original_index.get(b) {
          Some(value) => value
          None => 0
        }
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      }
    })
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
  collect_graph_nodes(graph, members)
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
fn adjust_cluster_positions_for_rounding(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_clusters : Map[String, String],
  sizes : Map[String, NodeSize],
) -> @geom.Rect? {
  let mut bbox = compute_nodes_bbox(graph, positions, sizes)
  for child in graph.subgraphs() {
    match adjust_cluster_positions_for_rounding(
      child,
      positions,
      vnode_positions,
      vnode_clusters,
      sizes,
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
  if is_cluster_graph(graph) {
    let pad = cluster_margin_pt(graph)
    current = {
      llx: current.llx - pad,
      lly: current.lly - pad,
      urx: current.urx + pad,
      ury: current.ury + pad,
    }
    match graph_label_metrics(graph) {
      Some((width_pt, height_pt)) => {
        let loc = graph_label_loc(graph)
        current = expand_bbox_for_label(current, width_pt, height_pt, loc)
      }
      None => ()
    }
    let rounded = round_bbox(current)
    let center_shift = (rounded.llx + rounded.urx) / 2.0 -
      (current.llx + current.urx) / 2.0
    if center_shift != 0.0 {
      shift_graph_positions(
        graph,
        positions,
        vnode_positions,
        vnode_clusters,
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
    if is_cluster_graph(layout.graph) {
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
