///|
priv struct EdgeVnodeInfo {
  vnode_ranks : Map[String, Int]
  vnode_sizes : Map[String, NodeSize]
  vnodes_by_rank : Map[Int, Array[String]]
  edge_vnodes : Map[String, Array[String]]
  vnode_clusters : Map[String, String]
}

///|
priv struct FlatLabelNodeInfo {
  tail : String
  head : String
  rank : Int
  order : Int
  place : Int
}

///|
///|
fn edge_polyline_points(
  edge : @cgraph.Edge,
  tail_name : String,
  head_name : String,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnode_positions : Map[String, @geom.Point],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  nodesep_pt : Double,
  label_width_pt : Double,
  dotted_weight : Double,
  use_cluster_tuning : Bool,
  split_label : Bool,
  same_local_cluster : Bool,
) -> Array[@geom.Point] {
  let points : Array[@geom.Point] = [tail_anchor]
  let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  let tail_rank_opt = ranks.get(tail_name)
  let head_rank_opt = ranks.get(head_name)
  if vnodes.length() > 0 {
    match (tail_rank_opt, head_rank_opt) {
      (Some(tail_rank), Some(head_rank)) => {
        let span = head_rank - tail_rank
        if span != 0 {
          let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
          let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
          let label_rank = if label_width_pt > 0.0 {
            (min_rank + max_rank) / 2
          } else {
            -1
          }
          let y_dir = if head_anchor.y < tail_anchor.y { 1.0 } else { -1.0 }
          let style_value = match edge.get_attr("style") {
            Some(value) => value.to_lower()
            None => ""
          }
          let is_dotted = style_value.contains("dotted")
          let has_explicit_port =
            port_is_explicit(tail_port) || port_is_explicit(head_port)
          let base_vnode_weight =
            if use_cluster_tuning {
              if is_dotted {
                if same_local_cluster { dotted_weight * 0.7 } else { dotted_weight }
              } else if split_label {
                0.3
              } else if label_width_pt > 0.0 && !has_explicit_port {
                if same_local_cluster {
                  1.0
                } else {
                  0.4
                }
              } else {
                0.0
              }
            } else {
              DEFAULT_VNODE_WEIGHT
            }
          let span_f = Double::from_int(span)
          let push_point = (name : String) => {
            match vnode_positions.get(name) {
              Some(pos) =>
                match vnode_ranks.get(name) {
                  Some(rank) => {
                    let t_raw = Double::from_int(rank - tail_rank) / span_f
                    let t =
                      if use_cluster_tuning && !is_dotted && head_anchor.x >= tail_anchor.x {
                        if split_label && rank == label_rank {
                          t_raw
                        } else {
                          t_raw * t_raw
                        }
                      } else {
                        t_raw
                      }
                    let interp_x = tail_anchor.x + (head_anchor.x - tail_anchor.x) * t
                    let base_y = match rank_y.get(rank) {
                      Some(value) => value
                      None => pos.y
                    }
                    let base_offset = match rank_ht1.get(rank) {
                      Some(value) => value
                      None => 0.0
                    }
                    let y = base_y + base_offset
                    let vnode_weight = base_vnode_weight
                    let x = pos.x * vnode_weight + interp_x * (1.0 - vnode_weight)
                    if split_label && rank == label_rank {
                      let split_width = label_width_pt * 1.5
                      let split_x = x - nodesep_pt * 1.25
                      points.push({
                        x: split_x - nodesep_pt,
                        y: y + nodesep_pt * y_dir,
                      })
                      points.push({
                        x: split_x + split_width * 0.5,
                        y: y - nodesep_pt * y_dir,
                      })
                    } else {
                      points.push({ x, y })
                    }
                  }
                  None => ()
                }
              None => ()
            }
          }
          if tail_rank <= head_rank {
            for name in vnodes {
              push_point(name)
            }
          } else {
            let mut idx = vnodes.length()
            while idx > 0 {
              idx = idx - 1
              let name = vnodes[idx]
              push_point(name)
            }
          }
        }
      }
      _ => ()
    }
  }
  points.push(head_anchor)
  points
}

///|
fn edge_swap_ends(
  tail : String,
  head : String,
  ranks : Map[String, Int],
  order_index : Map[String, Int],
) -> Bool {
  let tail_rank = match ranks.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_rank = match ranks.get(head) {
    Some(value) => value
    None => 0
  }
  if head_rank > tail_rank {
    return false
  }
  if head_rank < tail_rank {
    return true
  }
  let tail_order = match order_index.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_order = match order_index.get(head) {
    Some(value) => value
    None => 0
  }
  head_order < tail_order
}

///|
fn reverse_spline(spline : @geom.Spline) -> @geom.Spline {
  let reversed : Array[@geom.Point] = []
  let mut idx = spline.points.length()
  while idx > 0 {
    idx = idx - 1
    reversed.push(spline.points[idx])
  }
  { start: spline.end, end: spline.start, points: reversed }
}

///|
fn edge_parallel_key(
  tail : String,
  head : String,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
) -> String {
  let tail_port_key = port_key(tail_port)
  let head_port_key = port_key(head_port)
  "\{tail}|\{tail_port_key}|\{head}|\{head_port_key}"
}

///|
fn edge_parallel_offsets(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
  nodesep_pt : Double,
) -> Map[Int, Double] {
  let groups : Map[String, Array[Int]] = Map::new()
  for edge in edges {
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    if orig_tail == orig_head {
      continue
    }
    let tail_rank = match ranks.get(orig_tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(orig_head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    let swap = edge_swap_ends(orig_tail, orig_head, ranks, order_index)
    let (tail, head, tail_port, head_port) =
      if swap {
        (orig_head, orig_tail, edge.head_port(), edge.tail_port())
      } else {
        (orig_tail, orig_head, edge.tail_port(), edge.head_port())
      }
    let key = edge_parallel_key(tail, head, tail_port, head_port)
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
  }
  let offsets : Map[Int, Double] = Map::new()
  for _key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    ids.sort()
    let count = ids.length()
    let dx = nodesep_pt * Double::from_int(count - 1) / 2.0
    for i in 0..<count {
      let offset = dx - Double::from_int(i) * nodesep_pt
      offsets[ids[i]] = offset
    }
  }
  offsets
}

///|
fn adjust_intercluster_dotted_points(
  points : Array[@geom.Point],
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  head_size : NodeSize,
  nodesep_pt : Double,
) -> Array[@geom.Point] {
  if points.length() <= 2 {
    return points
  }
  let last_idx = points.length() - 2
  let head_left = head_anchor.x - head_size.width_pt / 2.0
  let head_right = head_anchor.x + head_size.width_pt / 2.0
  let offset = max_double(2.0, nodesep_pt * 0.5)
  let x = if head_anchor.x >= tail_anchor.x {
    head_left - offset
  } else {
    head_right + offset
  }
  let y = tail_anchor.y + (head_anchor.y - tail_anchor.y) * 0.5
  let adjusted = points.copy()
  adjusted[last_idx] = { x, y }
  adjusted
}

///|
fn adjust_intracluster_dotted_points(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  if points.length() <= 3 {
    return points
  }
  let adjusted = points.copy()
  let last = points.length() - 1
  let mid = points.length() / 2
  let mid_y = (points[0].y + points[last].y) / 2.0
  let left_weight = 0.2
  let right_weight = 0.8
  if points.length() % 2 == 0 {
    let left = mid - 1
    if left > 0 && left < last {
      let avg_y = (points[left - 1].y + points[left + 1].y) / 2.0
      adjusted[left] = {
        x: points[left].x,
        y: points[left].y * (1.0 - left_weight) + avg_y * left_weight,
      }
    }
    if mid > 0 && mid < last {
      adjusted[mid] = {
        x: points[mid].x,
        y: points[mid].y * (1.0 - right_weight) + mid_y * right_weight,
      }
    }
  } else if mid > 0 && mid < last {
    adjusted[mid] = {
      x: points[mid].x,
      y: points[mid].y * (1.0 - right_weight) + mid_y * right_weight,
    }
  }
  adjusted
}

///|
fn ordered_nodes(graph : @cgraph.Graph) -> Array[@cgraph.Node] {
  graph.nodes()
}

///|
fn node_cluster_key(node : @cgraph.Node) -> String {
  let mut graph = node.graph()
  let mut key = ""
  while !graph.is_root() {
    if is_cluster_graph(graph) {
      match graph.name() {
        Some(name) => key = name
        None => key = ""
      }
    }
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  key
}

///|
fn node_local_cluster_key(node : @cgraph.Node) -> String {
  let mut graph = node.graph()
  while !graph.is_root() {
    if is_cluster_graph(graph) {
      match graph.name() {
        Some(name) => return name
        None => return ""
      }
    }
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  ""
}

///|
fn graph_cluster_key(graph : @cgraph.Graph) -> String {
  let mut current = graph
  let mut key = ""
  while !current.is_root() {
    if is_cluster_graph(current) {
      match current.name() {
        Some(name) => key = name
        None => key = ""
      }
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  key
}

///|
fn collect_edge_cluster_keys(
  graph : @cgraph.Graph,
  edge_cluster_keys : Map[String, String],
) -> Unit {
  for child in graph.subgraphs() {
    collect_edge_cluster_keys(child, edge_cluster_keys)
  }
  if !is_cluster_graph(graph) {
    return ()
  }
  let cluster_key = graph_cluster_key(graph)
  if cluster_key == "" {
    return ()
  }
  let child_edges : Map[String, Bool] = Map::new()
  for child in graph.subgraphs() {
    for edge in child.edges() {
      child_edges[edge_key(edge)] = true
    }
  }
  for edge in graph.edges() {
    let key = edge_key(edge)
    if child_edges.get(key) is None {
      edge_cluster_keys[key] = cluster_key
    }
  }
}

///|
fn intercluster_edge_key(
  tail_cluster : String,
  head_cluster : String,
  tail_rank : Int,
  head_rank : Int,
) -> String {
  "\{tail_cluster}@\{tail_rank}->\{head_cluster}@\{head_rank}"
}

///|
fn cluster_rank_key(cluster : String, rank : Int) -> String {
  "\{cluster}@\{rank}"
}

///|
fn edge_is_constraint(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("constraint") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "false" && lower != "0" && lower != "no"
    }
    None => true
  }
}

///|
fn edge_weight(edge : @cgraph.Edge) -> Int {
  let weight_value = match edge.get_attr("weight") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let mut weight = weight_value.round().to_int()
  if weight < 0 {
    weight = 0
  }
  if !edge_is_constraint(edge) {
    return 0
  }
  let tail_group = match edge.tail().get_attr("group") {
    Some(value) => value
    None => ""
  }
  let head_group = match edge.head().get_attr("group") {
    Some(value) => value
    None => ""
  }
  if tail_group != "" && tail_group == head_group {
    weight = weight * 100
  }
  weight
}

///|
fn edge_xpenalty(edge : @cgraph.Edge) -> Int {
  let penalty_value = match edge.get_attr("xpenalty") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let mut penalty = penalty_value.round().to_int()
  if penalty < 0 {
    penalty = 0
  }
  if !edge_is_constraint(edge) {
    return 0
  }
  penalty
}

///|
fn edge_minlen(edge : @cgraph.Edge) -> Int {
  let minlen_value = match edge.get_attr("minlen") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let minlen = minlen_value.round().to_int()
  if minlen < 1 {
    1
  } else {
    minlen
  }
}

///|
fn edge_mid_label_text(edge : @cgraph.Edge) -> String? {
  match edge.get_attr("label") {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn edge_mid_label_width_pt(edge : @cgraph.Edge) -> Double {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  match edge_mid_label_text(edge) {
    Some(text) => {
      let (width, _height) = label_text_dimensions(text, font, font_size_pt)
      width
    }
    None => 0.0
  }
}

///|
fn edge_mid_label_metrics(edge : @cgraph.Edge) -> (Double, Double)? {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  match edge_mid_label_text(edge) {
    Some(text) => {
      let (width, height) = label_text_dimensions(text, font, font_size_pt)
      Some((width, height))
    }
    None => None
  }
}

///|
fn edge_label_height_pt(edge : @cgraph.Edge) -> Double {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  let mut max_height = 0.0
  let labels = ["label", "headlabel", "taillabel"]
  for name in labels {
    match edge.get_attr(name) {
      Some(text) =>
        if text != "" {
          let (_width, height) = label_text_dimensions(text, font, font_size_pt)
          if height > max_height {
            max_height = height
          }
        }
      None => ()
    }
  }
  max_height
}

///|
fn edge_has_label(edge : @cgraph.Edge) -> Bool {
  let labels = ["label", "headlabel", "taillabel"]
  for name in labels {
    match edge.get_attr(name) {
      Some(value) => if value != "" { return true }
      None => ()
    }
  }
  false
}

///|
fn graph_has_edge_labels(edges : Array[@cgraph.Edge]) -> Bool {
  for edge in edges {
    if edge_has_label(edge) {
      return true
    }
  }
  false
}

///|
fn self_edge_label_width_pt(edge : @cgraph.Edge, rankdir : RankDir) -> Double {
  match edge_mid_label_metrics(edge) {
    Some((width, height)) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        height
      } else {
        width
      }
    None => 0.0
  }
}

///|
fn build_port_maps_for_nodes(
  nodes : Array[@cgraph.Node],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Map[String, Map[String, RecordPort]] {
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  let port_maps : Map[String, Map[String, RecordPort]] = Map::new()
  for node in nodes {
    let label = label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    let has_record = is_record_shape(node)
    if !has_html && !has_record {
      continue
    }
    let name = node.name()
    let size = match sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    let ports =
      if has_html {
      html_ports(node, origin, size)
    } else {
      record_ports(node, origin, size, record_orientation)
    }
    if ports.length() > 0 {
      port_maps[name] = ports
    }
  }
  port_maps
}

///|
fn port_side_mask_for_self_edge(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  port_maps : Map[String, Map[String, RecordPort]],
) -> Int {
  match port {
    None => 0
    Some(value) =>
      match value.compass {
        Some(compass) => compass_side_mask(compass)
        None =>
          match value.name {
            Some(port_name) =>
              match port_maps.get(node.name()) {
                Some(ports) =>
                  match ports.get(port_name) {
                    Some(info) => info.sides
                    None => 0
                  }
                None => 0
              }
            None => 0
          }
      }
  }
}

///|
fn self_edge_right_space_for_edge(
  edge : @cgraph.Edge,
  rankdir : RankDir,
  port_maps : Map[String, Map[String, RecordPort]],
) -> Double {
  let tail_port = edge.tail_port()
  let head_port = edge.head_port()
  let tail_explicit = port_is_explicit(tail_port)
  let head_explicit = port_is_explicit(head_port)
  let label_width = self_edge_label_width_pt(edge, rankdir)
  if !tail_explicit && !head_explicit {
    return SELF_EDGE_SIZE_PT + label_width
  }
  let tail_sides = port_side_mask_for_self_edge(edge.tail(), tail_port, port_maps)
  let head_sides = port_side_mask_for_self_edge(edge.head(), head_port, port_maps)
  let tail_left = (tail_sides & PORT_SIDE_LEFT) != 0
  let head_left = (head_sides & PORT_SIDE_LEFT) != 0
  if !tail_left && !head_left {
    let same_side = tail_sides == head_sides
    let top_bottom = (tail_sides & (PORT_SIDE_TOP | PORT_SIDE_BOTTOM)) != 0
    if !same_side || !top_bottom {
      return SELF_EDGE_SIZE_PT + label_width
    }
  }
  0.0
}

///|
fn apply_self_edge_right_space(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, NodeSize] {
  let mut has_self_edges = false
  for edge in edges {
    if edge.tail().name() == edge.head().name() {
      has_self_edges = true
      break
    }
  }
  if !has_self_edges {
    return sizes
  }
  let port_maps = build_port_maps_for_nodes(nodes, sizes, record_orientation)
  let extra_right : Map[String, Double] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    if tail != edge.head().name() {
      continue
    }
    let extra = self_edge_right_space_for_edge(edge, rankdir, port_maps)
    if extra <= 0.0 {
      continue
    }
    let current = match extra_right.get(tail) {
      Some(value) => value
      None => 0.0
    }
    extra_right[tail] = current + extra
  }
  if extra_right.length() == 0 {
    return sizes
  }
  let adjusted : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    match extra_right.get(name) {
      Some(extra) => adjusted[name] = size_with_extra_right(size, extra)
      None => adjusted[name] = size
    }
  }
  adjusted
}

///|
fn self_edge_label_half_heights(
  edges : Array[@cgraph.Edge],
) -> Map[String, Double] {
  let heights : Map[String, Double] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail != head {
      continue
    }
    let half_height = edge_label_height_pt(edge) / 2.0
    let current = match heights.get(tail) {
      Some(value) => value
      None => 0.0
    }
    if half_height > current {
      heights[tail] = half_height
    }
  }
  heights
}

///|
fn node_half_height_pt(
  name : String,
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
) -> Double {
  let base_height = match sizes.get(name) {
    Some(value) => value.height_pt / 2.0
    None => 0.0
  }
  let label_height = match self_edge_labels.get(name) {
    Some(value) => value
    None => 0.0
  }
  if label_height > base_height {
    label_height
  } else {
    base_height
  }
}

///|
fn cluster_label_padding_pt(graph : @cgraph.Graph) -> (Double, Double) {
  match graph_label_metrics(graph) {
    Some((_width_pt, height_pt)) => {
      let loc = graph_label_loc(graph)
      let pad = CLUSTER_LABEL_PAD_PT
      match loc {
        LabelLoc::Top => (height_pt + pad, 0.0)
        LabelLoc::Bottom => (0.0, height_pt + pad)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
priv struct ClusterHeights {
  min_rank : Int
  max_rank : Int
  ht1 : Double
  ht2 : Double
}

///|
fn collect_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  seen : Map[String, Bool],
  rank_heights : Map[Int, Double],
  min_rank : Int?,
  max_rank : Int?,
) -> (Int?, Int?) {
  let mut next_min = min_rank
  let mut next_max = max_rank
  for node in graph.nodes() {
    let name = node.name()
    if seen.get(name) is Some(_) {
      continue
    }
    seen[name] = true
    match ranks.get(name) {
      Some(rank) => {
        let half_height = node_half_height_pt(name, sizes, self_edge_labels)
        let current = match rank_heights.get(rank) {
          Some(value) => value
          None => 0.0
        }
        if half_height > current {
          rank_heights[rank] = half_height
        }
        match next_min {
          Some(value) => if rank < value { next_min = Some(rank) }
          None => next_min = Some(rank)
        }
        match next_max {
          Some(value) => if rank > value { next_max = Some(rank) }
          None => next_max = Some(rank)
        }
      }
      None => ()
    }
  }
  for child in graph.subgraphs() {
    let (child_min, child_max) = collect_cluster_rank_heights(
      child, ranks, sizes, self_edge_labels, seen, rank_heights, next_min, next_max,
    )
    next_min = child_min
    next_max = child_max
  }
  (next_min, next_max)
}

///|
fn apply_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> ClusterHeights? {
  let is_cluster = is_cluster_graph(graph)
  let children = graph.subgraphs()
  if !is_cluster {
    for child in children {
      let _ = apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
      )

    }
    return None
  }
  let seen : Map[String, Bool] = Map::new()
  let rank_heights : Map[Int, Double] = Map::new()
  let (min_rank, max_rank) = collect_cluster_rank_heights(
    graph,
    ranks,
    sizes,
    self_edge_labels,
    seen,
    rank_heights,
    None,
    None,
  )
  let min_rank_value = match min_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights(
          child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
        )

      }
      return None
    }
  }
  let max_rank_value = match max_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights(
          child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
        )

      }
      return None
    }
  }
  let margin = cluster_margin_pt(graph)
  let base_top = match rank_heights.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let base_bottom = match rank_heights.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let mut ht1 = base_top + margin
  let mut ht2 = base_bottom + margin
  for child in children {
    match
      apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
      ) {
      Some(info) => {
        if info.max_rank == max_rank_value {
          let candidate = info.ht1 + margin
          if candidate > ht1 {
            ht1 = candidate
          }
        }
        if info.min_rank == min_rank_value {
          let candidate = info.ht2 + margin
          if candidate > ht2 {
            ht2 = candidate
          }
        }
      }
      None => ()
    }
  }
  let (label_top, label_bottom) = cluster_label_padding_pt(graph)
  ht1 = ht1 + label_bottom
  ht2 = ht2 + label_top
  let current_top = match rank_ht1.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht1 > current_top {
    rank_ht1[max_rank_value] = ht1
  }
  let current_bottom = match rank_ht2.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht2 > current_bottom {
    rank_ht2[min_rank_value] = ht2
  }
  Some({ min_rank: min_rank_value, max_rank: max_rank_value, ht1, ht2 })
}

///|
fn collect_rank_extremes(
  subgraph : @cgraph.Graph,
  min_nodes : Map[String, Bool],
  max_nodes : Map[String, Bool],
) -> Unit {
  match subgraph.get_attr("rank") {
    Some(value) => {
      let lower = value.to_lower()
      if lower == "min" || lower == "source" {
        for node in subgraph.nodes() {
          min_nodes[node.name()] = true
        }
      } else if lower == "max" || lower == "sink" {
        for node in subgraph.nodes() {
          max_nodes[node.name()] = true
        }
      }
    }
    None => ()
  }
  for child in subgraph.subgraphs() {
    collect_rank_extremes(child, min_nodes, max_nodes)
  }
}

///|
fn apply_rank_extremes(
  ranks : Map[String, Int],
  min_nodes : Map[String, Bool],
  max_nodes : Map[String, Bool],
) -> Unit {
  if ranks.length() == 0 {
    return ()
  }
  let mut max_rank = 0
  let mut seen = false
  for _name, rank in ranks {
    if !seen {
      max_rank = rank
      seen = true
    } else if rank > max_rank {
      max_rank = rank
    }
  }
  if min_nodes.length() > 0 {
    for name, _ in min_nodes {
      match ranks.get(name) {
        Some(_) => ranks[name] = 0
        None => ()
      }
    }
  }
  if max_nodes.length() > 0 {
    for name, _ in max_nodes {
      match ranks.get(name) {
        Some(_) => ranks[name] = max_rank
        None => ()
      }
    }
  }
}

///|
fn add_rank_same_constraints(
  rank_graph : NsGraph,
  index : Map[String, Int],
  subgraph : @cgraph.Graph,
) -> Unit {
  match subgraph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let nodes = subgraph.nodes()
        if nodes.length() > 1 {
          let mut i = 0
          while i < nodes.length() {
            let name_i = nodes[i].name()
            let idx_i = match index.get(name_i) {
              Some(value) => value
              None => -1
            }
            if idx_i >= 0 {
              let mut j = i + 1
              while j < nodes.length() {
                let name_j = nodes[j].name()
                let idx_j = match index.get(name_j) {
                  Some(value) => value
                  None => -1
                }
                if idx_j >= 0 {
                  let _ = add_edge(rank_graph, idx_i, idx_j, 0, 1000)
                  let _ = add_edge(rank_graph, idx_j, idx_i, 0, 1000)

                }
                j = j + 1
              }
            }
            i = i + 1
          }
        }
      }
    None => ()
  }
  for child in subgraph.subgraphs() {
    add_rank_same_constraints(rank_graph, index, child)
  }
}

///|
fn collect_rank_same_order(
  graph : @cgraph.Graph,
  group_ids : Map[String, Int],
  order_ids : Map[String, Int],
  next_group : Int,
) -> Int {
  let mut current_group = next_group
  match graph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let group_id = current_group
        current_group = current_group + 1
        let mut idx = 0
        for node in graph.nodes() {
          if group_ids.get(node.name()) is None {
            group_ids[node.name()] = group_id
            order_ids[node.name()] = idx
          }
          idx = idx + 1
        }
      }
    None => ()
  }
  for child in graph.subgraphs() {
    current_group = collect_rank_same_order(
      child, group_ids, order_ids, current_group,
    )
  }
  current_group
}

///|
fn remove_edge_at(list : Array[Int], idx : Int) -> Unit {
  let mut i = idx
  while i + 1 < list.length() {
    list[i] = list[i + 1]
    i = i + 1
  }
  let _ = list.pop()
}

///|
fn acyclic_dfs(
  idx : Int,
  node_index : Map[String, Int],
  out_edges : Array[Array[Int]],
  edge_is_active : Array[Bool],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  marked : Array[Bool],
  onstack : Array[Bool],
) -> Unit {
  if marked[idx] {
    return ()
  }
  let stack : Array[(Int, Int)] = []
  marked[idx] = true
  onstack[idx] = true
  stack.push((idx, 0))
  while stack.length() > 0 {
    let top_idx = stack.length() - 1
    let (node_idx, edge_pos) = stack[top_idx]
    if edge_pos >= out_edges[node_idx].length() {
      onstack[node_idx] = false
      let _ = stack.pop()
      continue
    }
    let edge_idx = out_edges[node_idx][edge_pos]
    if !edge_is_active[edge_idx] {
      stack[top_idx] = (node_idx, edge_pos + 1)
      continue
    }
    let head_name = edge_head[edge_idx]
    let head_idx = match node_index.get(head_name) {
      Some(value) => value
      None => {
        stack[top_idx] = (node_idx, edge_pos + 1)
        continue
      }
    }
    if onstack[head_idx] {
      if head_idx == node_idx {
        stack[top_idx] = (node_idx, edge_pos + 1)
        continue
      }
      // Reverse the edge and update adjacency to match Graphviz's acyclic pass.
      let old_tail = edge_tail[edge_idx]
      edge_tail[edge_idx] = edge_head[edge_idx]
      edge_head[edge_idx] = old_tail
      edge_reversed[edge_idx] = !edge_reversed[edge_idx]
      remove_edge_at(out_edges[node_idx], edge_pos)
      out_edges[head_idx].push(edge_idx)
      continue
    }
    if !marked[head_idx] {
      stack[top_idx] = (node_idx, edge_pos + 1)
      marked[head_idx] = true
      onstack[head_idx] = true
      stack.push((head_idx, 0))
      continue
    }
    stack[top_idx] = (node_idx, edge_pos + 1)
  }
}

///|
fn acyclic_edge_directions(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (Array[String], Array[String], Array[Bool]) {
  let node_index : Map[String, Int] = Map::new()
  for i in 0..<nodes.length() {
    node_index[nodes[i].name()] = i
  }
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_reversed : Array[Bool] = []
  let edge_is_active : Array[Bool] = []
  let out_edges : Array[Array[Int]] = []
  for _ in 0..<nodes.length() {
    out_edges.push([])
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    edge_tail.push(tail)
    edge_head.push(head)
    edge_reversed.push(false)
    let active = edge_is_constraint(edge)
    edge_is_active.push(active)
    if active {
      match node_index.get(tail) {
        Some(idx) => out_edges[idx].push(edge_tail.length() - 1)
        None => ()
      }
    }
  }
  let marked : Array[Bool] = []
  let onstack : Array[Bool] = []
  for _ in 0..<nodes.length() {
    marked.push(false)
    onstack.push(false)
  }
  for i in 0..<nodes.length() {
    if !marked[i] {
      acyclic_dfs(
        i,
        node_index,
        out_edges,
        edge_is_active,
        edge_tail,
        edge_head,
        edge_reversed,
        marked,
        onstack,
      )
    }
  }
  (edge_tail, edge_head, edge_reversed)
}

///|
fn acyclic_edge_directions_for_names(
  node_names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_is_active : Array[Bool],
) -> (Array[String], Array[String], Array[Bool]) {
  let node_index : Map[String, Int] = Map::new()
  for i in 0..<node_names.length() {
    node_index[node_names[i]] = i
  }
  let tail = edge_tail.copy()
  let head = edge_head.copy()
  let edge_reversed : Array[Bool] = []
  let out_edges : Array[Array[Int]] = []
  for _ in 0..<node_names.length() {
    out_edges.push([])
  }
  for i in 0..<tail.length() {
    edge_reversed.push(false)
    if i < edge_is_active.length() && edge_is_active[i] {
      match node_index.get(tail[i]) {
        Some(idx) => out_edges[idx].push(i)
        None => ()
      }
    }
  }
  let marked : Array[Bool] = []
  let onstack : Array[Bool] = []
  for _ in 0..<node_names.length() {
    marked.push(false)
    onstack.push(false)
  }
  for i in 0..<node_names.length() {
    if !marked[i] {
      acyclic_dfs(
        i,
        node_index,
        out_edges,
        edge_is_active,
        tail,
        head,
        edge_reversed,
        marked,
        onstack,
      )
    }
  }
  (tail, head, edge_reversed)
}

///|
fn edge_endpoints_from_edges(
  edges : Array[@cgraph.Edge],
) -> (Array[String], Array[String], Array[Bool]) {
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_reversed : Array[Bool] = []
  for edge in edges {
    edge_tail.push(edge.tail().name())
    edge_head.push(edge.head().name())
    edge_reversed.push(false)
  }
  (edge_tail, edge_head, edge_reversed)
}

///|
fn compute_ranks_directed_base(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  _edge_reversed : Array[Bool],
) -> Map[String, Int] {
  let graph = new_graph()
  let index : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    index[name] = add_node(graph, name)
  }
  let merged_edges : Map[String, (Int, Int, Int, Int)] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if !edge_is_constraint(edge) {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_idx = match index.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_idx = match index.get(head) {
      Some(value) => value
      None => 0
    }
    let minlen_value = edge_minlen(edge)
    let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
    let weight = edge_weight(edge)
    let key = "\{tail_idx}:\{head_idx}"
    match merged_edges.get(key) {
      Some(entry) => {
        let (_tail_idx, _head_idx, current_minlen, current_weight) = entry
        let next_minlen = if minlen > current_minlen { minlen } else { current_minlen }
        merged_edges[key] = (tail_idx, head_idx, next_minlen, current_weight + weight)
      }
      None => merged_edges[key] = (tail_idx, head_idx, minlen, weight)
    }

  }
  for _key, entry in merged_edges {
    let (tail_idx, head_idx, minlen, weight) = entry
    let _ = add_edge(graph, tail_idx, head_idx, minlen, weight)
  }
  add_rank_same_constraints(graph, index, source)
  network_simplex(graph, 0x7fffffff, BalanceMode::TB)
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    let rank = node_rank(graph, idx)
    if !seen {
      min_rank = rank
      seen = true
    } else if rank < min_rank {
      min_rank = rank
    }
  }
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    let rank = node_rank(graph, idx) - min_rank
    ranks[name] = rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}

///|
fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> Map[String, Int] {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(source, None, cluster_graphs, cluster_parents)
  let root_cluster_name =
    if is_cluster_graph(source) {
    match source.name() {
      Some(value) => value
      None => ""
    }
  } else {
    ""
  }
  let top_clusters : Array[String] = []
  for name, parent in cluster_parents {
    match parent {
      None =>
        if name != root_cluster_name {
          top_clusters.push(name)
        }
      Some(_) => ()
    }
  }
  if top_clusters.length() == 0 {
    let (base_tail, base_head, base_reversed) =
      acyclic_edge_directions(nodes, edges)
    return compute_ranks_directed_base(
      source,
      nodes,
      edges,
      has_edge_labels,
      base_tail,
      base_head,
      base_reversed,
    )
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  let node_cluster : Map[String, String] = Map::new()
  for cluster_name in top_clusters {
    match cluster_members.get(cluster_name) {
      Some(members) =>
        for name, _ in members {
          node_cluster[name] = cluster_name
        }
      None => ()
    }
  }
  let local_ranks : Map[String, Int] = Map::new()
  let cluster_leaders : Map[String, String] = Map::new()
  for cluster_name in top_clusters {
    let members = match cluster_members.get(cluster_name) {
      Some(value) => value
      None => continue
    }
    let cluster_nodes : Array[@cgraph.Node] = []
    for node in nodes {
      if members.get(node.name()) is Some(_) {
        cluster_nodes.push(node)
      }
    }
    if cluster_nodes.length() == 0 {
      continue
    }
    let cluster_edges : Array[@cgraph.Edge] = []
    for edge in edges {
      let tail = edge.tail().name()
      let head = edge.head().name()
      if members.get(tail) is Some(_) && members.get(head) is Some(_) {
        cluster_edges.push(edge)
      }
    }
    let (cluster_tail, cluster_head, cluster_reversed) =
      acyclic_edge_directions(cluster_nodes, cluster_edges)
    let cluster_graph = match cluster_graphs.get(cluster_name) {
      Some(value) => value
      None => source
    }
    let cluster_ranks = compute_ranks_directed(
      cluster_graph,
      cluster_nodes,
      cluster_edges,
      has_edge_labels,
      cluster_tail,
      cluster_head,
      cluster_reversed,
    )
    for name, rank in cluster_ranks {
      local_ranks[name] = rank
    }
    let mut leader_name : String? = None
    for node in cluster_nodes {
      let name = node.name()
      match cluster_ranks.get(name) {
        Some(rank) =>
          if rank == 0 && leader_name is None {
            leader_name = Some(name)
          }
        None => ()
      }
    }
    let leader =
      match leader_name {
        Some(name) => name
        None => cluster_nodes[0].name()
      }
    cluster_leaders[cluster_name] = leader
  }
  let rank_graph = new_graph()
  let rank_index : Map[String, Int] = Map::new()
  let rank_names : Array[String] = []
  for node in nodes {
    let name = node.name()
    let cluster = match node_cluster.get(name) {
      Some(value) => value
      None => ""
    }
    let key =
      if cluster == "" {
        name
      } else {
        match cluster_leaders.get(cluster) {
          Some(value) => value
          None => name
        }
      }
    if rank_index.get(key) is None {
      rank_index[key] = add_node(rank_graph, key)
      rank_names.push(key)
    }
  }
  let direct_tail : Array[String] = []
  let direct_head : Array[String] = []
  let direct_minlen : Array[Int] = []
  let direct_weight : Array[Int] = []
  let direct_active : Array[Bool] = []
  let mut slack_id = 0
  for edge in edges {
    if !edge_is_constraint(edge) {
      continue
    }
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let tail_cluster = match node_cluster.get(tail_name) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match node_cluster.get(head_name) {
      Some(value) => value
      None => ""
    }
    let minlen_value = edge_minlen(edge)
    let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
    let weight = edge_weight(edge)
    if tail_cluster == head_cluster {
      if tail_cluster == "" && tail_name != head_name {
        direct_tail.push(tail_name)
        direct_head.push(head_name)
        direct_minlen.push(minlen)
        direct_weight.push(weight)
        direct_active.push(true)
      }
      continue
    }
    let tail_leader =
      if tail_cluster == "" {
        tail_name
      } else {
        match cluster_leaders.get(tail_cluster) {
          Some(value) => value
          None => tail_name
        }
      }
    let head_leader =
      if head_cluster == "" {
        head_name
      } else {
        match cluster_leaders.get(head_cluster) {
          Some(value) => value
          None => head_name
        }
      }
    let tail_local = match local_ranks.get(tail_name) {
      Some(value) => value
      None => 0
    }
    let head_local = match local_ranks.get(head_name) {
      Some(value) => value
      None => 0
    }
    let offset = minlen + tail_local - head_local
    let (t_len, h_len) =
      if offset > 0 { (0, offset) } else { (-offset, 0) }
    let slack_name = "_mbt_rank_slack_\{slack_id}"
    slack_id = slack_id + 1
    let slack_idx = add_node(rank_graph, slack_name, kind=NodeKind::Slack)
    let tail_idx = match rank_index.get(tail_leader) {
      Some(value) => value
      None => continue
    }
    let head_idx = match rank_index.get(head_leader) {
      Some(value) => value
      None => continue
    }
    let _ = add_edge(rank_graph, slack_idx, tail_idx, t_len, weight * CL_BACK)
    let _ = add_edge(rank_graph, slack_idx, head_idx, h_len, weight)
  }
  let (direct_tail_final, direct_head_final, _direct_rev) =
    acyclic_edge_directions_for_names(
      rank_names,
      direct_tail,
      direct_head,
      direct_active,
    )
  let merged_edges : Map[String, (Int, Int, Int, Int)] = Map::new()
  for i in 0..<direct_tail_final.length() {
    let tail_name = direct_tail_final[i]
    let head_name = direct_head_final[i]
    if tail_name == head_name {
      continue
    }
    let tail_idx = match rank_index.get(tail_name) {
      Some(value) => value
      None => continue
    }
    let head_idx = match rank_index.get(head_name) {
      Some(value) => value
      None => continue
    }
    let minlen = direct_minlen[i]
    let weight = direct_weight[i]
    let key = "\{tail_idx}:\{head_idx}"
    match merged_edges.get(key) {
      Some(entry) => {
        let (_tail_idx, _head_idx, current_minlen, current_weight) = entry
        let next_minlen =
          if minlen > current_minlen { minlen } else { current_minlen }
        merged_edges[key] =
          (tail_idx, head_idx, next_minlen, current_weight + weight)
      }
      None => merged_edges[key] = (tail_idx, head_idx, minlen, weight)
    }
  }
  for _key, entry in merged_edges {
    let (tail_idx, head_idx, minlen, weight) = entry
    let _ = add_edge(rank_graph, tail_idx, head_idx, minlen, weight)
  }
  let _ = network_simplex_pre_balance(rank_graph, 0x7fffffff)
  let leader_ranks : Map[String, Int] = Map::new()
  for name, idx in rank_index {
    leader_ranks[name] = node_rank(rank_graph, idx)
  }
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let cluster = match node_cluster.get(name) {
      Some(value) => value
      None => ""
    }
    let base_rank =
      if cluster == "" {
        match leader_ranks.get(name) {
          Some(value) => value
          None => 0
        }
      } else {
        let leader = match cluster_leaders.get(cluster) {
          Some(value) => value
          None => name
        }
        let leader_rank = match leader_ranks.get(leader) {
          Some(value) => value
          None => 0
        }
        let local_rank = match local_ranks.get(name) {
          Some(value) => value
          None => 0
        }
        leader_rank + local_rank
      }
    if !seen {
      min_rank = base_rank
      seen = true
    } else if base_rank < min_rank {
      min_rank = base_rank
    }
    ranks[name] = base_rank
  }
  for name, rank in ranks {
    ranks[name] = rank - min_rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}

///|
fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
) -> Map[String, Int] {
  if graph_has_cluster(source) {
    return compute_ranks_directed_with_clusters(
      source,
      nodes,
      edges,
      has_edge_labels,
    )
  }
  compute_ranks_directed_base(
    source,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
    edge_reversed,
  )
}

///|
fn dedup_ordering_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (Array[@cgraph.Edge], Array[String], Array[String]) {
  let seen : Map[String, Bool] = Map::new()
  let out_edges : Array[@cgraph.Edge] = []
  let out_tail : Array[String] = []
  let out_head : Array[String] = []
  for i in 0..<edges.length() {
    let tail =
      if i < edge_tail.length() { edge_tail[i] } else { edges[i].tail().name() }
    let head =
      if i < edge_head.length() { edge_head[i] } else { edges[i].head().name() }
    let key = "\{tail}|\{head}"
    if seen.get(key) is Some(_) {
      continue
    }
    seen[key] = true
    out_edges.push(edges[i])
    out_tail.push(tail)
    out_head.push(head)
  }
  (out_edges, out_tail, out_head)
}

///| 
///|
fn build_ordering_flat_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
) -> (Map[String, Bool], Bool) {
  let flat_constraints : Map[String, Bool] = Map::new()
  let out_edges : Map[String, Array[(Int, Int)]] = Map::new()
  let in_edges : Map[String, Array[(Int, Int)]] = Map::new()
  for node in nodes {
    let name = node.name()
    out_edges[name] = []
    in_edges[name] = []
  }
  for i in 0..<edges.length() {
    let tail =
      if i < edge_tail.length() { edge_tail[i] } else { edges[i].tail().name() }
    let head =
      if i < edge_head.length() { edge_head[i] } else { edges[i].head().name() }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster != head_cluster {
      continue
    }
    let edge_id = edges[i].id()
    match out_edges.get(tail) {
      Some(list) => list.push((edge_id, i))
      None => out_edges[tail] = [(edge_id, i)]
    }
    match in_edges.get(head) {
      Some(list) => list.push((edge_id, i))
      None => in_edges[head] = [(edge_id, i)]
    }
  }
  let apply_ordering = (name : String, mode : OrderingMode) => {
    let list = match mode {
      OrderingMode::Out => {
        match out_edges.get(name) {
          Some(items) => items
          None => []
        }
      }
      OrderingMode::In => {
        match in_edges.get(name) {
          Some(items) => items
          None => []
        }
      }
    }
    if list.length() <= 1 {
      return ()
    }
    let sorted = list.copy()
    sorted.sort_by((a, b) => {
      let (a_id, _a_idx) = a
      let (b_id, _b_idx) = b
      if a_id < b_id {
        -1
      } else if a_id > b_id {
        1
      } else {
        0
      }
    })
    let mut idx = 1
    while idx < sorted.length() {
      let (_prev_id, prev_idx) = sorted[idx - 1]
      let (_curr_id, curr_idx) = sorted[idx]
      let left = match mode {
        OrderingMode::Out =>
          if prev_idx < edge_head.length() {
          edge_head[prev_idx]
        } else {
          edges[prev_idx].head().name()
        }
        OrderingMode::In =>
          if prev_idx < edge_tail.length() {
          edge_tail[prev_idx]
        } else {
          edges[prev_idx].tail().name()
        }
      }
      let right = match mode {
        OrderingMode::Out =>
          if curr_idx < edge_head.length() {
          edge_head[curr_idx]
        } else {
          edges[curr_idx].head().name()
        }
        OrderingMode::In =>
          if curr_idx < edge_tail.length() {
          edge_tail[curr_idx]
        } else {
          edges[curr_idx].tail().name()
        }
      }
      if left != right {
        flat_constraints["\{left}|\{right}"] = true
      }
      idx = idx + 1
    }
  }
  let graph_ordering = match graph.get_attr("ordering") {
    Some(value) => parse_ordering_mode(value)
    None => None
  }
  let mut ordering_set = false
  match graph_ordering {
    Some(mode) => {
      ordering_set = true
      for node in nodes {
        apply_ordering(node.name(), mode)
      }
    }
    None => {
      for node in nodes {
        match node.get_attr("ordering") {
          Some(value) =>
            match parse_ordering_mode(value) {
              Some(mode) => {
                ordering_set = true
                apply_ordering(node.name(), mode)
              }
              None => ()
            }
          None => ()
        }
      }
    }
  }
  (flat_constraints, ordering_set)
}

///|
///|
fn build_edge_index_for_order(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    parents[name] = []
    children[name] = []
  }
  for edge_idx in 0..<edges.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    match parents.get(head) {
      Some(list) => list.push(tail)
      None => parents[head] = [tail]
    }
    match children.get(tail) {
      Some(list) => list.push(head)
      None => children[tail] = [head]
    }
  }
  (parents, children)
}

///|
fn build_edge_index_for_order_names(
  node_names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for name in node_names {
    parents[name] = []
    children[name] = []
  }
  for edge_idx in 0..<edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    match parents.get(head) {
      Some(list) => list.push(tail)
      None => parents[head] = [tail]
    }
    match children.get(tail) {
      Some(list) => list.push(head)
      None => children[tail] = [head]
    }
  }
  (parents, children)
}

///|
fn add_order_edge(
  graph : @cgraph.Graph,
  node_map : Map[String, @cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  tail_name : String,
  head_name : String,
  xpenalty : Int,
  constraint : Bool,
) -> Unit {
  if tail_name == head_name {
    return ()
  }
  match node_map.get(tail_name) {
    Some(tail_node) =>
      match node_map.get(head_name) {
        Some(head_node) => {
          let edge = graph.edge(tail_node, head_node)
          edge.set_attr("xpenalty", "\{xpenalty}")
          if !constraint {
            edge.set_attr("constraint", "false")
          }
          edges.push(edge)
          edge_tail.push(tail_name)
          edge_head.push(head_name)
        }
        None => ()
      }
    None => ()
  }
}

///|
fn build_edge_index_for_order_with_vnodes(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    parents[name] = []
    children[name] = []
  }
  for vnode, _ in vnode_ranks {
    parents[vnode] = []
    children[vnode] = []
  }
  for edge_idx in 0..<edges.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    let (low, high) = if tail_rank <= head_rank { (tail, head) } else { (head, tail) }
    let vnodes = match edge_vnodes.get(edge_vnode_key(edges[edge_idx])) {
      Some(list) => list
      None => []
    }
    let mut prev = low
    for vnode in vnodes {
      match parents.get(vnode) {
        Some(list) => list.push(prev)
        None => parents[vnode] = [prev]
      }
      match children.get(prev) {
        Some(list) => list.push(vnode)
        None => children[prev] = [vnode]
      }
      prev = vnode
    }
    match parents.get(high) {
      Some(list) => list.push(prev)
      None => parents[high] = [prev]
    }
    match children.get(prev) {
      Some(list) => list.push(high)
      None => children[prev] = [high]
    }
  }
  (parents, children)
}

///|
fn position_key(
  name : String,
  desired : Map[String, Double],
  x_positions : Map[String, Double],
) -> Double {
  match desired.get(name) {
    Some(value) => value
    None =>
      match x_positions.get(name) {
        Some(value) => value
        None => 0.0
      }
  }
}

///|
fn is_edge_vnode_name(name : String) -> Bool {
  name.has_prefix(EDGE_VNODE_PREFIX)
}

///|
priv struct PositionSortInfo {
  name : String
  key : Double
  is_vnode : Bool
  degree : Int
  secondary : Int
  penalty : Int
  ported : Bool
  node_order : Int
  original_index : Int
  port_order : Double?
  rank_same_group : Int?
  rank_same_order : Int
}

///|
fn sort_by_positions_fast(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  node_order : Map[String, Int],
  reverse_ties : Bool,
) -> Array[String] {
  let infos : Array[PositionSortInfo] = []
  for i in 0..<names.length() {
    let name = names[i]
    let key = position_key(name, desired, x_positions)
    let degree = match primary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let secondary_degree = match secondary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let penalty = match node_penalty.get(name) {
      Some(value) => value
      None => 0
    }
    let ported = port_edge_nodes.get(name) is Some(_)
    let is_vnode = is_edge_vnode_name(name)
    let order_value = match node_order.get(name) {
      Some(value) => value
      None => i
    }
    infos.push({
      name,
      key,
      is_vnode,
      degree,
      secondary: secondary_degree,
      penalty,
      ported,
      node_order: order_value,
      original_index: i,
      port_order: None,
      rank_same_group: None,
      rank_same_order: 0,
    })
  }
  let eps = 0.000001
  infos.sort_by((a, b) => {
    let diff = a.key - b.key
    if Double::abs(diff) > eps {
      if diff < 0.0 { -1 } else { 1 }
    } else if a.is_vnode != b.is_vnode {
      if a.is_vnode { -1 } else { 1 }
    } else if a.degree != b.degree {
      if a.degree > b.degree { -1 } else { 1 }
    } else if a.ported != b.ported {
      if a.ported { -1 } else { 1 }
    } else if a.secondary != b.secondary {
      if a.secondary > b.secondary { -1 } else { 1 }
    } else if a.penalty != b.penalty {
      if a.penalty > b.penalty { -1 } else { 1 }
    } else if a.node_order != b.node_order {
      if reverse_ties {
        if a.node_order < b.node_order { 1 } else { -1 }
      } else {
        if a.node_order < b.node_order { -1 } else { 1 }
      }
    } else if a.original_index != b.original_index {
      if reverse_ties {
        if a.original_index < b.original_index { 1 } else { -1 }
      } else {
        if a.original_index < b.original_index { -1 } else { 1 }
      }
    } else {
      0
    }
  })
  let sorted : Array[String] = []
  for info in infos {
    sorted.push(info.name)
  }
  sorted
}

///|
fn sort_by_positions_large(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  node_order : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  let infos : Array[PositionSortInfo] = []
  for i in 0..<names.length() {
    let name = names[i]
    let key = position_key(name, desired, x_positions)
    let degree = match primary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let secondary_degree = match secondary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let penalty = match node_penalty.get(name) {
      Some(value) => value
      None => 0
    }
    let ported = port_edge_nodes.get(name) is Some(_)
    let is_vnode = is_edge_vnode_name(name)
    let order_value = match node_order.get(name) {
      Some(value) => value
      None => i
    }
    let port_order = port_order_positions.get(name)
    let rank_group = rank_same_groups.get(name)
    let rank_order = match rank_same_order.get(name) {
      Some(value) => value
      None => 0
    }
    infos.push({
      name,
      key,
      is_vnode,
      degree,
      secondary: secondary_degree,
      penalty,
      ported,
      node_order: order_value,
      original_index: i,
      port_order,
      rank_same_group: rank_group,
      rank_same_order: rank_order,
    })
  }
  let eps = 0.000001
  infos.sort_by((a, b) => {
    let diff = a.key - b.key
    if Double::abs(diff) > eps {
      if diff < 0.0 { -1 } else { 1 }
    } else {
      let port_cmp = match a.port_order {
        Some(a_port) =>
          match b.port_order {
            Some(b_port) =>
              if a_port != b_port {
                if a_port < b_port { -1 } else { 1 }
              } else {
                0
              }
            None => 0
          }
        None => 0
      }
      if port_cmp != 0 {
        port_cmp
      } else if a.is_vnode != b.is_vnode {
        if a.is_vnode { -1 } else { 1 }
      } else if a.degree != b.degree {
        if a.degree > b.degree { -1 } else { 1 }
      } else if a.ported != b.ported {
        if a.ported { -1 } else { 1 }
      } else if a.secondary != b.secondary {
        if a.secondary > b.secondary { -1 } else { 1 }
      } else if a.penalty != b.penalty {
        if a.penalty > b.penalty { -1 } else { 1 }
      } else if a.ported && b.ported && a.node_order != b.node_order {
        if reverse_ties {
          if a.node_order < b.node_order { 1 } else { -1 }
        } else {
          if a.node_order < b.node_order { -1 } else { 1 }
        }
      } else {
        match a.rank_same_group {
          Some(group) =>
            match b.rank_same_group {
              Some(other_group) =>
                if group == other_group && a.rank_same_order != b.rank_same_order {
                  if a.rank_same_order < b.rank_same_order { -1 } else { 1 }
                } else if a.node_order != b.node_order {
                  if reverse_ties {
                    if a.node_order < b.node_order { 1 } else { -1 }
                  } else {
                    if a.node_order < b.node_order { -1 } else { 1 }
                  }
                } else if a.original_index != b.original_index {
                  if reverse_ties {
                    if a.original_index < b.original_index { 1 } else { -1 }
                  } else {
                    if a.original_index < b.original_index { -1 } else { 1 }
                  }
                } else {
                  0
                }
              None =>
                if a.node_order != b.node_order {
                  if reverse_ties {
                    if a.node_order < b.node_order { 1 } else { -1 }
                  } else {
                    if a.node_order < b.node_order { -1 } else { 1 }
                  }
                } else if a.original_index != b.original_index {
                  if reverse_ties {
                    if a.original_index < b.original_index { 1 } else { -1 }
                  } else {
                    if a.original_index < b.original_index { -1 } else { 1 }
                  }
                } else {
                  0
                }
            }
          None =>
            if a.node_order != b.node_order {
              if reverse_ties {
                if a.node_order < b.node_order { 1 } else { -1 }
              } else {
                if a.node_order < b.node_order { -1 } else { 1 }
              }
            } else if a.original_index != b.original_index {
              if reverse_ties {
                if a.original_index < b.original_index { 1 } else { -1 }
              } else {
                if a.original_index < b.original_index { -1 } else { 1 }
              }
            } else {
              0
            }
        }
      }
    }
  })
  let sorted : Array[String] = []
  for info in infos {
    sorted.push(info.name)
  }
  sorted
}

///|
fn sort_by_positions(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  parents_map : Map[String, Array[String]],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  edge_pair_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let mut has_port_order = false
  for _name, _ in port_order_positions {
    has_port_order = true
    break
  }
  let mut has_rank_same = false
  for _name, _ in rank_same_groups {
    has_rank_same = true
    break
  }
  let mut has_ported_nodes = false
  for _name, _ in port_edge_nodes {
    has_ported_nodes = true
    break
  }
  if sorted.length() >= LARGE_SORT_THRESHOLD {
    return sort_by_positions_large(
      sorted,
      desired,
      x_positions,
      primary,
      secondary,
      node_penalty,
      port_edge_nodes,
      node_order,
      rank_same_groups,
      rank_same_order,
      port_order_positions,
      reverse_ties,
    )
  }
  if sorted.length() >= 64 && !has_port_order && !has_rank_same && !has_ported_nodes {
    return sort_by_positions_fast(
      sorted,
      desired,
      x_positions,
      primary,
      secondary,
      node_penalty,
      port_edge_nodes,
      node_order,
      reverse_ties,
    )
  }
  let _ = edge_order
  let mut i = 1
  while i < sorted.length() {
    let current = sorted[i]
    let current_key = position_key(current, desired, x_positions)
    let mut j = i
    let current_degree = match primary.get(current) {
      Some(list) => list.length()
      None => 0
    }
    let current_secondary = match secondary.get(current) {
      Some(list) => list.length()
      None => 0
    }
    let current_penalty = match node_penalty.get(current) {
      Some(value) => value
      None => 0
    }
    while j > 0 {
      let prev = sorted[j - 1]
      let prev_has_desired = desired.get(prev) is Some(_)
      let current_has_desired = desired.get(current) is Some(_)
      if !prev_has_desired || !current_has_desired {
        break
      }
      let prev_key = position_key(prev, desired, x_positions)
      let diff = prev_key - current_key
      if diff < -0.000001 {
        break
      }
      if Double::abs(diff) <= 0.000001 {
        match port_order_positions.get(prev) {
          Some(prev_port) =>
            match port_order_positions.get(current) {
              Some(current_port) =>
                if prev_port != current_port {
                  if prev_port <= current_port {
                    break
                  }
                }
              None => ()
            }
          None => ()
        }
        let prev_vnode = is_edge_vnode_name(prev)
        let current_vnode = is_edge_vnode_name(current)
        if prev_vnode != current_vnode {
          if prev_vnode {
            break
          }
        }
        let prev_degree = match primary.get(prev) {
          Some(list) => list.length()
          None => 0
        }
        if prev_degree < current_degree {
          // move current left
        } else if prev_degree > current_degree {
          break
        } else {
          let prev_ported = port_edge_nodes.get(prev) is Some(_)
          let current_ported = port_edge_nodes.get(current) is Some(_)
          if prev_ported != current_ported {
            if !current_ported {
              break
            }
          } else {
            let prev_secondary = match secondary.get(prev) {
              Some(list) => list.length()
              None => 0
            }
            if prev_secondary < current_secondary {
              // move current left
            } else if prev_secondary > current_secondary {
              break
            } else {
              let prev_penalty = match node_penalty.get(prev) {
                Some(value) => value
                None => 0
              }
              if prev_penalty < current_penalty {
                // move current left
              } else if prev_penalty > current_penalty {
                break
              } else {
              let mut decided = false
              if prev_ported && current_ported {
                let prev_idx = match node_order.get(prev) {
                  Some(value) => value
                  None => 0
                }
                let current_idx = match node_order.get(current) {
                  Some(value) => value
                  None => 0
                }
                decided = true
                let keep_order =
                  if reverse_ties { prev_idx >= current_idx } else { prev_idx <= current_idx }
                if keep_order {
                  break
                }
              }
              if !decided {
                match rank_same_groups.get(prev) {
                  Some(prev_group) =>
                    match rank_same_groups.get(current) {
                      Some(current_group) =>
                        if prev_group == current_group {
                          let prev_idx = match rank_same_order.get(prev) {
                            Some(value) => value
                            None => 0
                          }
                          let current_idx = match rank_same_order.get(current) {
                            Some(value) => value
                            None => 0
                          }
                          decided = true
                          let keep_order = prev_idx <= current_idx
                          if keep_order {
                            break
                          }
                        }
                      None => ()
                    }
                  None => ()
                }
              }
              if !decided {
                let prev_parents = match parents_map.get(prev) {
                  Some(list) => list
                  None => []
                }
                let current_parents = match parents_map.get(current) {
                  Some(list) => list
                  None => []
                }
                for parent in prev_parents {
                  let mut shared = false
                  for candidate in current_parents {
                    if candidate == parent {
                      shared = true
                      break
                    }
                  }
                  if !shared {
                    continue
                  }
                  let prev_key = "\{parent}|\{prev}"
                  let current_key = "\{parent}|\{current}"
                  match edge_pair_order.get(prev_key) {
                    Some(prev_idx) =>
                      match edge_pair_order.get(current_key) {
                        Some(current_idx) => {
                          decided = true
                          let keep_order =
                            if reverse_ties {
                              prev_idx >= current_idx
                            } else {
                              prev_idx <= current_idx
                            }
                          if keep_order {
                            break
                          }
                        }
                        None => ()
                      }
                    None => ()
                  }
                  if decided {
                    break
                  }
                }
              }
              if !decided {
                if !reverse_ties {
                  break
                }
              }
              }
            }
          }
        }
      }
      sorted[j] = prev
      j = j - 1
    }
    sorted[j] = current
    i = i + 1
  }
  sorted
}

///|
fn median_value(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let sorted = values.copy()
  sorted.sort()
  let mid = sorted.length() / 2
  if sorted.length() % 2 == 0 {
    Some((sorted[mid - 1] + sorted[mid]) / 2.0)
  } else {
    Some(sorted[mid])
  }
}

///|
fn median_value_graphviz(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let sorted = values.copy()
  sorted.sort()
  if sorted.length() == 1 {
    return Some(sorted[0])
  }
  if sorted.length() == 2 {
    return Some((sorted[0] + sorted[1]) / 2.0)
  }
  let mid = sorted.length() / 2
  if sorted.length() % 2 == 1 {
    return Some(sorted[mid])
  }
  let rm = mid
  let lm = rm - 1
  let rspan = sorted[sorted.length() - 1] - sorted[rm]
  let lspan = sorted[lm] - sorted[0]
  if lspan == rspan {
    Some((sorted[lm] + sorted[rm]) / 2.0)
  } else {
    let weighted = sorted[lm] * rspan + sorted[rm] * lspan
    Some(weighted / (lspan + rspan))
  }
}

///|
///|
fn collect_edge_order(edges : Array[@cgraph.Edge]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  let mut idx = 0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if order.get(tail) is None {
      order[tail] = idx
    }
    if order.get(head) is None {
      order[head] = idx
    }
    idx = idx + 1
  }
  order
}

///|
fn order_rank_by_cluster(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  parents_map : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  edge_pair_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  if names.length() < 2 {
    return names.copy()
  }
  let group_keys : Array[String] = []
  let group_nodes : Array[Array[String]] = []
  let group_order : Array[Int] = []
  let group_index : Map[String, Int] = Map::new()
  let mut next_index = 0
  for name in names {
    let cluster_key = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    let group_key = if cluster_key == "" { name } else { cluster_key }
    let idx = match group_index.get(group_key) {
      Some(value) => value
      None => {
        let index = next_index
        next_index = next_index + 1
        group_index[group_key] = index
        group_keys.push(group_key)
        group_nodes.push([])
        group_order.push(index)
        index
      }
    }
    group_nodes[idx].push(name)
  }
  let group_values : Array[Double] = []
  let group_secondary : Array[Int] = []
  for i in 0..<group_nodes.length() {
    let values : Array[Double] = []
    let mut secondary_total = 0
    for name in group_nodes[i] {
      match desired.get(name) {
        Some(value) => values.push(value)
        None =>
          match x_positions.get(name) {
            Some(value) => values.push(value)
            None => ()
          }
      }
      match secondary.get(name) {
        Some(list) => secondary_total = secondary_total + list.length()
        None => ()
      }
    }
    let value = match median_value(values) {
      Some(val) => val
      None => 0.0
    }
    group_values.push(value)
    group_secondary.push(secondary_total)
  }
  let order : Array[Int] = []
  for i in 0..<group_nodes.length() {
    order.push(i)
  }
  let mut i = 1
  while i < order.length() {
    let current = order[i]
    let current_val = group_values[current]
    let mut j = i
    while j > 0 {
      let prev = order[j - 1]
      let prev_val = group_values[prev]
      if prev_val < current_val {
        break
      }
      if prev_val == current_val {
        let prev_secondary = group_secondary[prev]
        let current_secondary = group_secondary[current]
        if prev_secondary < current_secondary {
          // move current left
        } else if prev_secondary > current_secondary {
          break
        } else {
          let keep_order =
            if reverse_ties {
              group_order[prev] >= group_order[current]
            } else {
              group_order[prev] <= group_order[current]
            }
          if keep_order {
            break
          }
        }
      }
      order[j] = prev
      j = j - 1
    }
    order[j] = current
    i = i + 1
  }
  let result : Array[String] = []
  for idx in order {
    let group = group_nodes[idx]
    let ordered_group = sort_by_positions(
      group, desired, x_positions, primary, secondary, node_penalty, parents_map,
      rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
      edge_pair_order, port_order_positions,
      reverse_ties,
    )
    for name in ordered_group {
      result.push(name)
    }
  }
  result
}

///|
fn left2right_constraint(
  left : String,
  right : String,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> Bool {
  let left_cluster = match cluster_keys.get(left) {
    Some(value) => value
    None => ""
  }
  let right_cluster = match cluster_keys.get(right) {
    Some(value) => value
    None => ""
  }
  if left_cluster != "" && right_cluster != "" && left_cluster != right_cluster {
    let left_skel = cluster_skeleton.get(left) == Some(true)
    let right_skel = cluster_skeleton.get(right) == Some(true)
    if !left_skel && !right_skel {
      return true
    }
  }
  let key = "\{left}|\{right}"
  flat_constraints.get(key) == Some(true)
}

///|
fn reorder_by_medians(
  names : Array[String],
  desired : Map[String, Double],
  reverse : Bool,
  hasfixed : Bool,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let mut ep = sorted.length()
  let mut nelt = sorted.length() - 1
  while nelt >= 0 {
    let mut lp = 0
    while lp < ep {
      while lp < ep && desired.get(sorted[lp]) is None {
        lp = lp + 1
      }
      if lp >= ep {
        break
      }
      let mut rp = lp + 1
      let mut muststay = false
      let mut sawclust = false
      while rp < ep {
        let mut rp_cluster = ""
        match cluster_keys.get(sorted[rp]) {
          Some(value) => rp_cluster = value
          None => ()
        }
        if sawclust && rp_cluster != "" {
          rp = rp + 1
          continue
        }
        if left2right_constraint(
          sorted[lp],
          sorted[rp],
          cluster_keys,
          cluster_skeleton,
          flat_constraints,
        ) {
          muststay = true
          break
        }
        if desired.get(sorted[rp]) is Some(_) {
          break
        }
        if rp_cluster != "" {
          sawclust = true
        }
        rp = rp + 1
      }
      if rp >= ep {
        break
      }
      if !muststay {
        let p1 = match desired.get(sorted[lp]) {
          Some(value) => value
          None => -1.0
        }
        let p2 = match desired.get(sorted[rp]) {
          Some(value) => value
          None => -1.0
        }
        if p1 > p2 || (p1 >= p2 && reverse) {
          let tmp = sorted[lp]
          sorted[lp] = sorted[rp]
          sorted[rp] = tmp
        }
      }
      lp = rp
    }
    if !hasfixed && !reverse {
      ep = ep - 1
    }
    nelt = nelt - 1
  }
  sorted
}

///|
fn compute_desired_positions(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  x_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    match preferred_positions.get(name) {
      Some(value) => {
        desired[name] = value
        continue
      }
      None => ()
    }
    match port_order_contrib.get(name) {
      Some(list) => {
        let mut sum = 0.0
        let mut count = 0
        for entry in list {
          let (anchor, offset) = entry
          match x_positions.get(anchor) {
            Some(anchor_pos) => {
              sum = sum + anchor_pos + offset
              count = count + 1
            }
            None => ()
          }
        }
        if count > 0 {
          desired[name] = sum / count.to_double()
          continue
        }
      }
      None => ()
    }
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    let values : Array[Double] = []
    for neighbor in list {
      match x_positions.get(neighbor) {
        Some(value) => values.push(value)
        None => ()
      }
    }
    match median_value(values) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

///|
fn compute_desired_positions_graphviz(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  x_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    let values : Array[Double] = []
    for neighbor in list {
      match x_positions.get(neighbor) {
        Some(value) => values.push(value)
        None => ()
      }
    }
    match median_value_graphviz(values) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

///|
fn compute_desired_positions_with_rank_fallback(
  names : Array[String],
  children : Map[String, Array[String]],
  parents : Map[String, Array[String]],
  x_positions : Map[String, Double],
  ranks : Map[String, Int],
  rank_sizes : Map[Int, Int],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    match preferred_positions.get(name) {
      Some(value) => {
        desired[name] = value
        continue
      }
      None => ()
    }
    match port_order_contrib.get(name) {
      Some(list) => {
        let mut sum = 0.0
        let mut count = 0
        for entry in list {
          let (anchor, offset) = entry
          match x_positions.get(anchor) {
            Some(anchor_pos) => {
              sum = sum + anchor_pos + offset
              count = count + 1
            }
            None => ()
          }
        }
        if count > 0 {
          desired[name] = sum / count.to_double()
          continue
        }
      }
      None => ()
    }
    let child_list = match children.get(name) {
      Some(value) => value
      None => []
    }
    let mut use_children = false
    for child in child_list {
      match ranks.get(child) {
        Some(rank) =>
          match rank_sizes.get(rank) {
            Some(size) =>
              if size > 1 {
                use_children = true
                break
              }
            None => ()
          }
        None => ()
      }
    }
    let primary = if use_children { children } else { parents }
    let fallback = if use_children { parents } else { children }
    let list = match primary.get(name) {
      Some(value) => value
      None => []
    }
    let values : Array[Double] = []
    for neighbor in list {
      match x_positions.get(neighbor) {
        Some(value) => values.push(value)
        None => ()
      }
    }
    match median_value(values) {
      Some(value) => desired[name] = value
      None => ()
    }
    if desired.get(name) is None {
      let fallback_list = match fallback.get(name) {
        Some(value) => value
        None => []
      }
      let fallback_values : Array[Double] = []
      for neighbor in fallback_list {
        match x_positions.get(neighbor) {
          Some(value) => fallback_values.push(value)
          None => ()
        }
      }
      match median_value(fallback_values) {
        Some(value) => desired[name] = value
        None => ()
      }
    }
  }
  desired
}

///|

///|
fn node_left_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.left_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn node_right_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.right_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

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
fn rank_nodesep_pt(
  rank : Int,
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Double {
  if has_edge_labels && rank % 2 != 0 {
    EDGE_LABEL_NODESEP_PT
  } else {
    nodesep_pt
  }
}

///|
fn fill_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  all_ranks : Array[Int],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
  y_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> Unit {
  if all_ranks.length() == 0 {
    return ()
  }
  let max_rank = all_ranks[all_ranks.length() - 1]
  let start_y = match rank_ht1.get(max_rank) {
    Some(value) => value
    None => 0.0
  }
  rank_y[max_rank] = start_y
  let mut idx = all_ranks.length() - 1
  while idx > 0 {
    let upper = all_ranks[idx]
    let lower = all_ranks[idx - 1]
    let upper_pht = match rank_pht.get(upper) {
      Some(value) => value
      None => 0.0
    }
    let lower_pht = match rank_pht.get(lower) {
      Some(value) => value
      None => 0.0
    }
    let upper_ht2 = match rank_ht2.get(upper) {
      Some(value) => value
      None => 0.0
    }
    let lower_ht1 = match rank_ht1.get(lower) {
      Some(value) => value
      None => 0.0
    }
    let d0 = upper_pht + lower_pht + ranksep_pt
    let d1 = upper_ht2 + lower_ht1 + CLUSTER_MARGIN_PT
    let delta = if d0 > d1 { d0 } else { d1 }
    let base_y = match rank_y.get(upper) {
      Some(value) => value
      None => 0.0
    }
    rank_y[lower] = base_y + delta
    idx = idx - 1
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let pos_y = match rank_y.get(rank) {
      Some(value) => value
      None => 0.0
    }
    for name in names {
      y_positions[name] = pos_y
    }
  }
}

///|
fn compute_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    if names.length() == 0 {
      continue
    }
    let first = names[0]
    positions[first] = 0.0
    let mut current = 0
    let mut prev = first
    let mut i = 1
    let rank_nodesep = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    while i < names.length() {
      let name = names[i]
      let tail_right = node_right_pt(prev, sizes)
      let head_left = node_left_pt(name, sizes)
      let width = tail_right + head_left + rank_nodesep
      current = trunc_int(current.to_double() + width)
      positions[name] = current.to_double()
      prev = name
      i = i + 1
    }
  }
  positions
}

///|
fn unique_virtual_node_name(
  prefix : String,
  edge_index : Int,
  rank : Int,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = "\{prefix}\{edge_index}_\{rank}"
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{prefix}\{edge_index}_\{rank}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
}
///|
fn build_vnode_order_keys(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  let keys : Map[String, Double] = Map::new()
  let mut edge_idx = 0
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = if current_idx < edge_tail.length() { edge_tail[current_idx] } else {
      edge.tail().name()
    }
    let head = if current_idx < edge_head.length() { edge_head[current_idx] } else {
      edge.head().name()
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_order = match order_index.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_order = match order_index.get(head) {
      Some(value) => value
      None => 0
    }
    let (low_rank, high_rank, low_order, high_order) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_order, head_order)
    } else {
      (head_rank, tail_rank, head_order, tail_order)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    let low_order_f = Double::from_int(low_order)
    let high_order_f = Double::from_int(high_order)
    let same_order = low_order == high_order
    let offset = if same_order { 0.01 } else { 0.0 }
    let reversed =
      if current_idx < edge_reversed.length() { edge_reversed[current_idx] } else { false }
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let base_key =
        if same_order {
          low_order_f - offset + t * offset * 2.0
        } else {
          low_order_f + (high_order_f - low_order_f) * t
        }
      let key = if reversed { base_key + 0.5 } else { base_key }
      keys[vnode] = key
    }
  }
  keys
}

///|
fn flat_label_adjacent(
  rank : Int,
  tail : String,
  head : String,
  ordered_groups : Map[Int, Array[String]],
) -> Bool {
  let names = match ordered_groups.get(rank) {
    Some(list) => list
    None => []
  }
  if names.length() == 0 {
    return false
  }
  let mut tail_idx = -1
  let mut head_idx = -1
  for i in 0..<names.length() {
    if names[i] == tail {
      tail_idx = i
    }
    if names[i] == head {
      head_idx = i
    }
  }
  if tail_idx < 0 || head_idx < 0 {
    return false
  }
  let diff = if tail_idx > head_idx {
    tail_idx - head_idx
  } else {
    head_idx - tail_idx
  }
  diff <= 1
}

///|
fn collect_vnode_out_heads(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out_heads : Map[String, Array[String]] = Map::new()
  let mut edge_idx = 0
  for edge in edges {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else { edge.tail().name() }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else { edge.head().name() }
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let path : Array[String] = []
    path.push(tail)
    if tail_rank <= head_rank {
      for vnode in vnodes {
        path.push(vnode)
      }
    } else {
      let mut idx = vnodes.length()
      while idx > 0 {
        idx = idx - 1
        path.push(vnodes[idx])
      }
    }
    path.push(head)
    let mut i = 0
    while i + 1 < path.length() {
      let from = path[i]
      let to = path[i + 1]
      if is_edge_vnode_name(from) {
        match out_heads.get(from) {
          Some(list) => list.push(to)
          None => out_heads[from] = [to]
        }
      }
      i = i + 1
    }
  }
  out_heads
}

///|
fn flat_limits(
  rank_nodes : Array[String],
  order_index : Map[String, Int],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  vnode_out_heads : Map[String, Array[String]],
  tail : String,
  head : String,
) -> Int {
  let tail_pos = match order_index.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_pos = match order_index.get(head) {
    Some(value) => value
    None => 0
  }
  let lpos = if tail_pos <= head_pos { tail_pos } else { head_pos }
  let rpos = if tail_pos <= head_pos { head_pos } else { tail_pos }
  let n = rank_nodes.length()
  if n == 0 {
    return 0
  }
  let mut lnode = 0
  let mut rnode = n - 1
  let bounds : Array[Int] = [lnode - 1, rnode + 1, lnode - 1, rnode + 1]
  let setbounds = (name : String) => {
    let is_flat = flat_label_nodes.get(name) is Some(_)
    if !is_flat && !is_edge_vnode_name(name) {
      return ()
    }
    let ord = match order_index.get(name) {
      Some(value) => value
      None => return ()
    }
    match flat_label_nodes.get(name) {
      Some(info) => {
        let tail_ord = match order_index.get(info.tail) {
          Some(value) => value
          None => return ()
        }
        let head_ord = match order_index.get(info.head) {
          Some(value) => value
          None => return ()
        }
        let left = if tail_ord <= head_ord { tail_ord } else { head_ord }
        let right = if tail_ord <= head_ord { head_ord } else { tail_ord }
        if right <= lpos {
          bounds[2] = ord
          bounds[0] = ord
        } else if left >= rpos {
          bounds[3] = ord
          bounds[1] = ord
        } else if left < lpos && right > rpos {
          ()
        } else {
          if left < lpos || (left == lpos && right < rpos) {
            bounds[2] = ord
          }
          if right > rpos || (right == rpos && left > lpos) {
            bounds[3] = ord
          }
        }
      }
      None => {
        let heads = match vnode_out_heads.get(name) {
          Some(list) => list
          None => []
        }
        let mut onleft = false
        let mut onright = false
        for head_name in heads {
          let head_ord = match order_index.get(head_name) {
            Some(value) => value
            None => continue
          }
          if head_ord <= lpos {
            onleft = true
          }
          if head_ord >= rpos {
            onright = true
          }
        }
        if onleft && !onright {
          bounds[0] = ord + 1
        }
        if onright && !onleft {
          bounds[1] = ord - 1
        }
      }
    }
  }
  while lnode <= rnode {
    setbounds(rank_nodes[lnode])
    if lnode != rnode {
      setbounds(rank_nodes[rnode])
    }
    lnode = lnode + 1
    rnode = rnode - 1
    if bounds[1] - bounds[0] <= 1 {
      break
    }
  }
  if bounds[0] <= bounds[1] {
    (bounds[0] + bounds[1] + 1) / 2
  } else {
    (bounds[2] + bounds[3] + 1) / 2
  }
}

///|
fn vnode_positions_from_endpoints(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  node_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> Map[String, @geom.Point] {
  let positions : Map[String, @geom.Point] = Map::new()
  for edge in edges {
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_pos = match node_positions.get(tail) {
      Some(value) => value
      None => 0.0
    }
    let head_pos = match node_positions.get(head) {
      Some(value) => value
      None => 0.0
    }
    let (low_rank, high_rank, low_pos, high_pos) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_pos, head_pos)
    } else {
      (head_rank, tail_rank, head_pos, tail_pos)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let pos_x = low_pos + (high_pos - low_pos) * t
      let pos_y = match rank_y.get(vnode_rank) {
        Some(value) => value
        None => 0.0
      }
      positions[vnode] = { x: pos_x, y: pos_y }
    }
  }
  positions
}
///|
///|
fn build_edge_vnodes(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  existing_names : Map[String, Bool],
  edge_cluster_keys : Map[String, String],
) -> EdgeVnodeInfo {
  let vnode_ranks : Map[String, Int] = Map::new()
  let vnode_sizes : Map[String, NodeSize] = Map::new()
  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  let vnode_clusters : Map[String, String] = Map::new()
  let mut edge_index = 0
  let plain_width = 1.0 + nodesep_pt / 2.0
  for edge in edges {
    let key = edge_vnode_key(edge)
    match edge_vnodes.get(key) {
      Some(list) => {
        let delta = nodesep_pt / 2.0
        for name in list {
          match vnode_sizes.get(name) {
            Some(size) => {
              let left = size.left_pt + delta
              let right = size.right_pt + delta
              vnode_sizes[name] =
                vnode_size_from_widths_with_height(left, right, size.height_pt)
            }
            None => ()
          }
        }
        edge_index = edge_index + 1
        continue
      }
      None => ()
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_cluster = node_cluster_key(edge.tail())
    let head_cluster = node_cluster_key(edge.head())
    let edge_cluster = match edge_cluster_keys.get(edge_key(edge)) {
      Some(value) => value
      None => ""
    }
    let use_cluster_plain =
      tail_cluster != "" && tail_cluster == head_cluster
    let plain_width_for_edge = if use_cluster_plain { 1.0 } else { plain_width }
    let vnode_cluster =
      if tail_cluster != "" && tail_cluster == head_cluster {
        tail_cluster
      } else if edge_cluster != "" &&
        tail_cluster == edge_cluster &&
        head_cluster == edge_cluster {
        edge_cluster
      } else {
        ""
      }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => {
        edge_index = edge_index + 1
        continue
      }
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => {
        edge_index = edge_index + 1
        continue
      }
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      edge_index = edge_index + 1
      continue
    }
    let label_metrics = edge_mid_label_metrics(edge)
    let (label_width, label_height) = match label_metrics {
      Some((width, height)) =>
        if rankdir == RankDir::LR || rankdir == RankDir::RL {
          (height, width)
        } else {
          (width, height)
        }
      None => (0.0, 0.0)
    }
    let label_rank = if label_width > 0.0 { (min_rank + max_rank) / 2 } else { -1 }
    let names : Array[String] = []
    let mut rank = min_rank + 1
    while rank < max_rank {
      let is_label_rank = rank == label_rank && label_width > 0.0
      let name = unique_virtual_node_name(
        EDGE_VNODE_PREFIX,
        edge_index,
        rank,
        existing_names,
      )
      vnode_ranks[name] = rank
      vnode_sizes[name] =
        if is_label_rank {
        vnode_size_from_widths_with_height(
          nodesep_pt,
          label_width,
          label_height,
        )
      } else {
        vnode_size_from_widths(plain_width_for_edge, plain_width_for_edge)
      }
      vnode_clusters[name] = vnode_cluster
      match vnodes_by_rank.get(rank) {
        Some(list) => list.push(name)
        None => vnodes_by_rank[rank] = [name]
      }
      names.push(name)
      rank = rank + 1
    }
    if names.length() > 0 {
      match edge_vnodes.get(key) {
        Some(list) =>
          for name in names {
            list.push(name)
          }
        None => edge_vnodes[key] = names
      }
    }
    edge_index = edge_index + 1
  }
  { vnode_ranks, vnode_sizes, vnodes_by_rank, edge_vnodes, vnode_clusters }
}

///|
fn add_flat_label_vnodes(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  ordered_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  rankdir : RankDir,
  sizes : Map[String, NodeSize],
  edge_cluster_keys : Map[String, String],
  existing_names : Map[String, Bool],
  vnode_info : EdgeVnodeInfo,
  x_groups : Map[Int, Array[String]],
) -> (
  Map[Int, Array[String]],
  Map[String, FlatLabelNodeInfo],
  Map[String, String],
  Array[ConstraintEdge],
) {
  let order_index = build_order_index(x_groups)
  let vnode_out_heads =
    collect_vnode_out_heads(edges, edge_tail, edge_head, ranks, vnode_info.edge_vnodes)
  let flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let flat_label_edges : Map[String, String] = Map::new()
  let extra_edges : Array[ConstraintEdge] = []
  let mut edge_idx = 0
  let insert_at = (names : Array[String], pos : Int, value : String) => {
    let result : Array[String] = []
    let mut idx = 0
    let insert_pos =
      if pos < 0 {
      0
    } else if pos > names.length() {
      names.length()
    } else {
      pos
    }
    while idx < insert_pos {
      result.push(names[idx])
      idx = idx + 1
    }
    result.push(value)
    while idx < names.length() {
      result.push(names[idx])
      idx = idx + 1
    }
    result
  }
  let rebuild_order = (names : Array[String]) => {
    for i in 0..<names.length() {
      order_index[names[i]] = i
    }
  }
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let tail =
      if current_idx < edge_tail.length() { edge_tail[current_idx] } else {
        edge.tail().name()
      }
    let head =
      if current_idx < edge_head.length() { edge_head[current_idx] } else {
        edge.head().name()
      }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    if tail_rank != head_rank {
      continue
    }
    let metrics = match edge_mid_label_metrics(edge) {
      Some(value) => value
      None => continue
    }
    let (metric_width, metric_height) = metrics
    let (label_width, label_height) =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      (metric_height, metric_width)
    } else {
      (metric_width, metric_height)
    }
    if label_width <= 0.0 {
      continue
    }
    let is_adjacent = flat_label_adjacent(tail_rank, tail, head, ordered_groups)
    let left =
      match (order_index.get(tail), order_index.get(head)) {
        (Some(tail_pos), Some(head_pos)) =>
          if tail_pos <= head_pos { tail } else { head }
        _ => tail
      }
    let right = if left == tail { head } else { tail }
    let left_right = node_right_pt(left, sizes)
    let right_left = node_left_pt(right, sizes)
    let width = left_right + right_left
    let base_minlen =
      Double::from_int(edge_minlen(edge)) * nodesep_pt + width
    if is_adjacent {
      let label_minlen = width + nodesep_pt + label_width
      let minlen =
        round_int(if base_minlen > label_minlen { base_minlen } else { label_minlen })
      extra_edges.push({
        tail: left,
        head: right,
        minlen,
        weight: edge_weight(edge),
        tail_port: None,
        head_port: None,
      })
      continue
    }
    let label_rank = tail_rank - 1
    let names = match x_groups.get(label_rank) {
      Some(list) => list.copy()
      None => []
    }
    let place =
      flat_limits(names, order_index, flat_label_nodes, vnode_out_heads, tail, head)
    let name = unique_virtual_node_name(
      EDGE_VNODE_PREFIX,
      current_idx,
      label_rank,
      existing_names,
    )
    let half_width = label_width / 2.0
    vnode_info.vnode_ranks[name] = label_rank
    vnode_info.vnode_sizes[name] =
      vnode_size_from_widths_with_height(half_width, half_width, label_height)
    let tail_cluster = node_cluster_key(edge.tail())
    let head_cluster = node_cluster_key(edge.head())
    let edge_cluster = match edge_cluster_keys.get(edge_key(edge)) {
      Some(value) => value
      None => ""
    }
    let vnode_cluster =
      if tail_cluster != "" && tail_cluster == head_cluster {
        tail_cluster
      } else if edge_cluster != "" &&
        tail_cluster == edge_cluster &&
        head_cluster == edge_cluster {
        edge_cluster
      } else {
        ""
      }
    vnode_info.vnode_clusters[name] = vnode_cluster
    match vnode_info.vnodes_by_rank.get(label_rank) {
      Some(list) => list.push(name)
      None => vnode_info.vnodes_by_rank[label_rank] = [name]
    }
    let updated_rank = insert_at(names, place, name)
    x_groups[label_rank] = updated_rank
    rebuild_order(updated_rank)
    let order = match order_index.get(name) {
      Some(value) => value
      None => place
    }
    flat_label_nodes[name] = {
      tail,
      head,
      rank: label_rank,
      order,
      place,
    }
    flat_label_edges[edge_key(edge)] = name
    let m0 = Double::from_int(edge_minlen(edge)) * nodesep_pt / 2.0
    let minlen_left = round_int(m0 + left_right + half_width)
    let minlen_right = round_int(m0 + half_width + right_left)
    extra_edges.push({
      tail: left,
      head: name,
      minlen: minlen_left,
      weight: edge_weight(edge),
      tail_port: None,
      head_port: None,
    })
    extra_edges.push({
      tail: name,
      head: right,
      minlen: minlen_right,
      weight: edge_weight(edge),
      tail_port: None,
      head_port: None,
    })
  }
  (x_groups, flat_label_nodes, flat_label_edges, extra_edges)
}

///|
///|
fn build_node_singletons(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> Map[String, Bool] {
  let counts : Map[String, Int] = Map::new()
  for node in nodes {
    counts[node.name()] = 0
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_count = match counts.get(tail) {
      Some(value) => value
      None => 0
    }
    counts[tail] = tail_count + 1
    let head_count = match counts.get(head) {
      Some(value) => value
      None => 0
    }
    counts[head] = head_count + 1
  }
  let singletons : Map[String, Bool] = Map::new()
  for name, count in counts {
    if count <= 1 {
      singletons[name] = true
    }
  }
  singletons
}

///|
fn virtual_endpoint_class(
  name : String,
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
) -> Int {
  if vnode_ranks.get(name) is Some(_) {
    2
  } else if node_singletons.get(name) is Some(_) {
    1
  } else {
    0
  }
}

///|
fn virtual_weight_scale(
  tail : String,
  head : String,
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
) -> Int {
  let tail_class = virtual_endpoint_class(tail, vnode_ranks, node_singletons)
  let head_class = virtual_endpoint_class(head, vnode_ranks, node_singletons)
  if tail_class == 0 {
    1
  } else if tail_class == 1 {
    if head_class == 0 { 1 } else { 2 }
  } else {
    if head_class == 2 {
      4
    } else if head_class == 1 {
      2
    } else {
      1
    }
  }
}

///|
fn edge_port_name(port : @cgraph.Port?) -> String? {
  match port {
    Some(value) => value.name
    None => None
  }
}

///|
fn endpoint_port_name(
  node_name : String,
  tail_name : String,
  head_name : String,
  tail_port : String?,
  head_port : String?,
) -> String? {
  if node_name == tail_name {
    tail_port
  } else if node_name == head_name {
    head_port
  } else {
    None
  }
}

///|
fn build_virtual_slack_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
  cluster_keys : Map[String, String],
) -> Array[ConstraintEdge] {
  let extra : Array[ConstraintEdge] = []
  let mut edge_idx = 0
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = if current_idx < edge_tail.length() { edge_tail[current_idx] } else {
      edge.tail().name()
    }
    let head = if current_idx < edge_head.length() { edge_head[current_idx] } else {
      edge.head().name()
    }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    let tail_port_name =
      if tail == orig_tail {
      edge_port_name(edge.tail_port())
    } else {
      edge_port_name(edge.head_port())
    }
    let head_port_name =
      if head == orig_head {
      edge_port_name(edge.head_port())
    } else {
      edge_port_name(edge.tail_port())
    }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let low = if tail_rank <= head_rank { tail } else { head }
    let high = if tail_rank <= head_rank { head } else { tail }
    let base_weight = edge_weight(edge)
    let reversed = current_idx < edge_reversed.length() && edge_reversed[current_idx]
    let mut prev = low
    for vnode in vnodes {
      let scale = virtual_weight_scale(prev, vnode, vnode_ranks, node_singletons)
      let tail_port = endpoint_port_name(
        prev,
        tail,
        head,
        tail_port_name,
        head_port_name,
      )
      let head_port = endpoint_port_name(
        vnode,
        tail,
        head,
        tail_port_name,
        head_port_name,
      )
      let mut weight = base_weight * scale
      if vnode_ranks.get(prev) is None && vnode_ranks.get(vnode) is Some(_) {
        weight = weight * VNODE_ENDPOINT_WEIGHT
        if reversed {
          weight = weight * BACKWARD_PENALTY
        }
      }
      extra.push({
        tail: prev,
        head: vnode,
        minlen: 1,
        weight,
        tail_port,
        head_port,
      })
      prev = vnode
    }
    let scale = virtual_weight_scale(prev, high, vnode_ranks, node_singletons)
    let tail_port = endpoint_port_name(
      prev,
      tail,
      head,
      tail_port_name,
      head_port_name,
    )
    let head_port = endpoint_port_name(
      high,
      tail,
      head,
      tail_port_name,
      head_port_name,
    )
    let mut weight = base_weight * scale
    if vnode_ranks.get(prev) is Some(_) && vnode_ranks.get(high) is None {
      weight = weight * VNODE_ENDPOINT_WEIGHT
      if reversed {
        weight = weight * BACKWARD_PENALTY
      }
    }
    extra.push({
      tail: prev,
      head: high,
      minlen: 1,
      weight,
      tail_port,
      head_port,
    })
  }
  extra
}

///|
fn merge_sizes_with_vnodes(
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  let merged : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    merged[name] = size
  }
  for name, size in vnode_sizes {
    merged[name] = size
  }
  merged
}

///|
fn sort_rank_items(items : Array[(Double, Int, String)]) -> Array[String] {
  let sorted = items.copy()
  if sorted.length() > 1 {
    let eps = 0.000001
    sorted.sort_by((a, b) => {
      let (a_key, a_tie, _a_name) = a
      let (b_key, b_tie, _b_name) = b
      let diff = a_key - b_key
      if Double::abs(diff) <= eps {
        if a_tie < b_tie {
          -1
        } else if a_tie > b_tie {
          1
        } else {
          0
        }
      } else if diff < 0.0 {
        -1
      } else {
        1
      }
    })
  }
  let names : Array[String] = []
  for item in sorted {
    let (_key, _tie, name) = item
    names.push(name)
  }
  names
}

///|
fn build_x_groups_with_vnodes(
  ordered_groups : Map[Int, Array[String]],
  order_index : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys : Map[String, Double],
) -> Map[Int, Array[String]] {
  let result : Map[Int, Array[String]] = Map::new()
  let rank_set : Map[Int, Bool] = Map::new()
  for rank, _names in ordered_groups {
    rank_set[rank] = true
  }
  for rank, _names in vnodes_by_rank {
    rank_set[rank] = true
  }
  let ranks : Array[Int] = []
  for rank, _ in rank_set {
    ranks.push(rank)
  }
  ranks.sort()
  for rank in ranks {
    let names = match ordered_groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    let vnodes = match vnodes_by_rank.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    if vnodes.length() == 0 {
      if names.length() > 0 {
        result[rank] = names
      }
      continue
    }
    let items : Array[(Double, Int, String)] = []
    let mut idx = 0
    for name in names {
      let key = match order_index.get(name) {
        Some(value) => value.to_double()
        None => idx.to_double()
      }
      items.push((key, idx, name))
      idx = idx + 1
    }
    let tie_offset = names.length() + 1
    let mut v_idx = 0
    for name in vnodes {
      let key = match vnode_order_keys.get(name) {
        Some(value) => value
        None => 0.0
      }
      items.push((key, tie_offset + v_idx, name))
      v_idx = v_idx + 1
    }
    result[rank] = sort_rank_items(items)
  }
  result
}

///|
fn collect_rank_keys(groups : Map[Int, Array[String]]) -> Array[Int] {
  let keys : Array[Int] = []
  for rank, _ in groups {
    keys.push(rank)
  }
  keys.sort()
  keys
}

///|
fn build_vnode_extra_nodes(
  vnode_ranks : Map[String, Int],
) -> Array[(String, Int)] {
  let extra : Array[(String, Int)] = []
  for name, rank in vnode_ranks {
    extra.push((name, rank))
  }
  extra
}

///|
fn clone_rank_groups(
  groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let cloned : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    cloned[rank] = names.copy()
  }
  cloned
}

///|
fn build_node_ranks(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let ranks : Map[String, Int] = Map::new()
  for rank, names in groups {
    for name in names {
      ranks[name] = rank
    }
  }
  ranks
}

///|
fn build_order_index(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      order[names[i]] = i
    }
  }
  order
}

///|
fn order_positions_from_groups(
  groups : Map[Int, Array[String]],
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      positions[names[i]] = i.to_double()
    }
  }
  positions
}

///|
fn count_inversions(values : Array[Int]) -> Int {
  let n = values.length()
  if n < 2 {
    return 0
  }
  let mut src = values.copy()
  let mut dst = Array::make(n, 0)
  let mut size = 1
  let mut total = 0
  while size < n {
    let mut i = 0
    while i < n {
      let left = i
      let mid = {
        let next = i + size
        if next < n { next } else { n }
      }
      let right = {
        let next = i + size + size
        if next < n { next } else { n }
      }
      let mut a = left
      let mut b = mid
      let mut k = left
      while a < mid && b < right {
        if src[a] <= src[b] {
          dst[k] = src[a]
          a = a + 1
        } else {
          dst[k] = src[b]
          b = b + 1
          total = total + (mid - a)
        }
        k = k + 1
      }
      while a < mid {
        dst[k] = src[a]
        a = a + 1
        k = k + 1
      }
      while b < right {
        dst[k] = src[b]
        b = b + 1
        k = k + 1
      }
      i = i + size + size
    }
    let tmp = src
    src = dst
    dst = tmp
    size = size + size
  }
  total
}

///|
fn count_crossings(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Int {
  let order = build_order_index(groups)
  let edge_groups : Map[(Int, Int), Array[(Int, Int)]] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if !edge_is_constraint(edge) {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    if tail_rank == head_rank {
      continue
    }
    let low_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let high_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    let low_node = if tail_rank < head_rank { tail } else { head }
    let high_node = if tail_rank < head_rank { head } else { tail }
    let low_order = match order.get(low_node) {
      Some(value) => value
      None => continue
    }
    let high_order = match order.get(high_node) {
      Some(value) => value
      None => continue
    }
    let key = (low_rank, high_rank)
    match edge_groups.get(key) {
      Some(list) => list.push((low_order, high_order))
      None => edge_groups[key] = [(low_order, high_order)]
    }
  }
  let mut crossings = 0
  for _key, list in edge_groups {
    if list.length() < 2 {
      continue
    }
    list.sort_by((a, b) => {
      let (a0, a1) = a
      let (b0, b1) = b
      if a0 == b0 { a1 - b1 } else { a0 - b0 }
    })
    let heads : Array[Int] = []
    for pair in list {
      let (_, h) = pair
      heads.push(h)
    }
    crossings = crossings + count_inversions(heads)
  }
  crossings
}

///|
fn count_crossings_graphviz(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Int {
  let order = build_order_index(groups)
  let rank_keys : Array[Int] = []
  for rank, _ in groups {
    rank_keys.push(rank)
  }
  if rank_keys.length() == 0 {
    return 0
  }
  rank_keys.sort()
  let edge_out : Map[String, Array[Int]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      edge_out[name] = []
    }
  }
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if !edge_is_constraint(edge) {
      continue
    }
    if edge_xpenalty(edge) <= 0 {
      continue
    }
    let tail = edge_tail[edge_idx]
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
  }
  let mut crossings = 0
  let mut idx = 0
  while idx + 1 < rank_keys.length() {
    let rank = rank_keys[idx]
    let next_rank = rank_keys[idx + 1]
    let top_nodes = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let next_nodes = match groups.get(next_rank) {
      Some(list) => list
      None => []
    }
    let count = Array::make(next_nodes.length() + 1, 0)
    let mut max_order = 0
    for top in top_nodes {
      let outs = match edge_out.get(top) {
        Some(list) => list
        None => []
      }
      if max_order > 0 {
        for edge_idx in outs {
          let head = edge_head[edge_idx]
          if ranks.get(head) != Some(next_rank) {
            continue
          }
          let inv = match order.get(head) {
            Some(value) => value
            None => continue
          }
          let penalty = edge_xpenalty(edges[edge_idx])
          if penalty <= 0 {
            continue
          }
          let mut k = inv + 1
          while k <= max_order {
            crossings = crossings + count[k] * penalty
            k = k + 1
          }
        }
      }
      for edge_idx in outs {
        let head = edge_head[edge_idx]
        if ranks.get(head) != Some(next_rank) {
          continue
        }
        let inv = match order.get(head) {
          Some(value) => value
          None => continue
        }
        let penalty = edge_xpenalty(edges[edge_idx])
        if penalty <= 0 {
          continue
        }
        if inv > max_order {
          max_order = inv
        }
        count[inv] = count[inv] + penalty
      }
    }
    idx = idx + 1
  }
  crossings
}

///|
fn count_pairs_greater(left : Array[Int], right : Array[Int]) -> Int {
  if left.length() == 0 || right.length() == 0 {
    return 0
  }
  let mut count = 0
  let mut j = 0
  for i in 0..<left.length() {
    let l = left[i]
    while j < right.length() && right[j] < l {
      j = j + 1
    }
    count = count + j
  }
  count
}

///|
fn build_neighbor_order_index(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order : Map[String, Int],
  target_rank : Int,
) -> Map[String, Array[Int]] {
  let result : Map[String, Array[Int]] = Map::new()
  for name in names {
    let orders : Array[Int] = []
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    for neighbor in list {
      if ranks.get(neighbor) != Some(target_rank) {
        continue
      }
      match order.get(neighbor) {
        Some(idx) => orders.push(idx)
        None => ()
      }
    }
    if orders.length() > 1 {
      orders.sort()
    }
    result[name] = orders
  }
  result
}

///|
fn crossing_for_pair(
  left : String,
  right : String,
  parent_orders : Map[String, Array[Int]],
  child_orders : Map[String, Array[Int]],
) -> Int {
  let left_parents = match parent_orders.get(left) {
    Some(value) => value
    None => []
  }
  let right_parents = match parent_orders.get(right) {
    Some(value) => value
    None => []
  }
  let left_children = match child_orders.get(left) {
    Some(value) => value
    None => []
  }
  let right_children = match child_orders.get(right) {
    Some(value) => value
    None => []
  }
  count_pairs_greater(left_parents, right_parents) +
    count_pairs_greater(left_children, right_children)
}

///|
fn transpose_rank(
  rank : Int,
  names : Array[String],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  order : Map[String, Int],
  reverse : Bool,
) -> Bool {
  let mut changed = false
  let parent_orders =
    build_neighbor_order_index(names, parents, ranks, order, rank - 1)
  let child_orders =
    build_neighbor_order_index(names, children, ranks, order, rank + 1)
  let mut i = 0
  while i + 1 < names.length() {
    let left = names[i]
    let right = names[i + 1]
    let c0 = crossing_for_pair(
      left, right, parent_orders, child_orders,
    )
    let c1 = crossing_for_pair(
      right, left, parent_orders, child_orders,
    )
    if c1 < c0 || (reverse && c1 == c0 && c0 > 0) {
      names[i] = right
      names[i + 1] = left
      order[left] = i + 1
      order[right] = i
      changed = true
    }
    i = i + 1
  }
  changed
}

///|
fn transpose_rank_groups_limited(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  reverse : Bool,
  max_passes : Int,
) -> Bool {
  let mut changed_any = false
  let mut changed = true
  let mut passes = 0
  while changed {
    if passes >= max_passes {
      break
    }
    passes = passes + 1
    changed = false
    let order = build_order_index(ordered)
    for rank in rank_keys {
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() < 2 {
        continue
      }
      if transpose_rank(rank, names, parents, children, ranks, order, reverse) {
        ordered[rank] = names
        changed = true
        changed_any = true
      }
    }
  }
  changed_any
}

///|
fn in_cross_graphviz(
  left : String,
  right : String,
  rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_penalty : Array[Int],
) -> Int {
  let right_in = match edge_in.get(right) {
    Some(value) => value
    None => []
  }
  let left_in = match edge_in.get(left) {
    Some(value) => value
    None => []
  }
  let mut cross = 0
  for edge_idx in right_in {
    let cnt = edge_penalty[edge_idx]
    if cnt <= 0 {
      continue
    }
    let tail_rank = match ranks.get(edge_tail[edge_idx]) {
      Some(value) => value
      None => rank - 1
    }
    if tail_rank != rank - 1 {
      continue
    }
    let inv = match order.get(edge_tail[edge_idx]) {
      Some(value) => value
      None => 0
    }
    for edge_idx2 in left_in {
      let weight = edge_penalty[edge_idx2]
      if weight <= 0 {
        continue
      }
      let tail_rank2 = match ranks.get(edge_tail[edge_idx2]) {
        Some(value) => value
        None => rank - 1
      }
      if tail_rank2 != rank - 1 {
        continue
      }
      let tail_order = match order.get(edge_tail[edge_idx2]) {
        Some(value) => value
        None => 0
      }
      let t = tail_order - inv
      if t > 0 {
        cross = cross + weight * cnt
      }
    }
  }
  cross
}

///|
fn out_cross_graphviz(
  left : String,
  right : String,
  rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  edge_out : Map[String, Array[Int]],
  edge_head : Array[String],
  edge_penalty : Array[Int],
) -> Int {
  let right_out = match edge_out.get(right) {
    Some(value) => value
    None => []
  }
  let left_out = match edge_out.get(left) {
    Some(value) => value
    None => []
  }
  let mut cross = 0
  for edge_idx in right_out {
    let cnt = edge_penalty[edge_idx]
    if cnt <= 0 {
      continue
    }
    let head_rank = match ranks.get(edge_head[edge_idx]) {
      Some(value) => value
      None => rank + 1
    }
    if head_rank != rank + 1 {
      continue
    }
    let inv = match order.get(edge_head[edge_idx]) {
      Some(value) => value
      None => 0
    }
    for edge_idx2 in left_out {
      let weight = edge_penalty[edge_idx2]
      if weight <= 0 {
        continue
      }
      let head_rank2 = match ranks.get(edge_head[edge_idx2]) {
        Some(value) => value
        None => rank + 1
      }
      if head_rank2 != rank + 1 {
        continue
      }
      let head_order = match order.get(edge_head[edge_idx2]) {
        Some(value) => value
        None => 0
      }
      let t = head_order - inv
      if t > 0 {
        cross = cross + weight * cnt
      }
    }
  }
  cross
}

///|
fn transpose_rank_graphviz(
  rank : Int,
  ranks : Map[String, Int],
  names : Array[String],
  order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_penalty : Array[Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  reverse : Bool,
) -> (Int, Bool) {
  let mut changed = false
  let mut delta = 0
  let mut i = 0
  while i + 1 < names.length() {
    let left = names[i]
    let right = names[i + 1]
    if left2right_constraint(
      left,
      right,
      cluster_keys,
      cluster_skeleton,
      flat_constraints,
    ) {
      i = i + 1
      continue
    }
    let mut c0 = 0
    let mut c1 = 0
    c0 = c0 + in_cross_graphviz(
      left, right, rank, ranks, order, edge_in, edge_tail, edge_penalty,
    )
    c1 = c1 + in_cross_graphviz(
      right, left, rank, ranks, order, edge_in, edge_tail, edge_penalty,
    )
    c0 = c0 + out_cross_graphviz(
      left, right, rank, ranks, order, edge_out, edge_head, edge_penalty,
    )
    c1 = c1 + out_cross_graphviz(
      right, left, rank, ranks, order, edge_out, edge_head, edge_penalty,
    )
    if c1 < c0 || (reverse && c1 == c0 && c0 > 0) {
      names[i] = right
      names[i + 1] = left
      order[left] = i + 1
      order[right] = i
      changed = true
      delta = delta + (c0 - c1)
    }
    i = i + 1
  }
  (delta, changed)
}

///|
fn transpose_rank_groups_graphviz(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_penalty : Array[Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  reverse : Bool,
  max_passes : Int,
) -> Bool {
  let mut changed_any = false
  let mut passes = 0
  let rank_len = rank_keys.length()
  let candidate = Array::make(rank_len, true)
  while true {
    if max_passes > 0 && passes >= max_passes {
      break
    }
    passes = passes + 1
    let order = build_order_index(ordered)
    let mut delta = 0
    let mut idx = 0
    while idx < rank_len {
      if !candidate[idx] {
        idx = idx + 1
        continue
      }
      candidate[idx] = false
      let rank = rank_keys[idx]
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() < 2 {
        idx = idx + 1
        continue
      }
      let (rank_delta, changed) = transpose_rank_graphviz(
        rank,
        ranks,
        names,
        order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        reverse,
      )
      if changed {
        ordered[rank] = names
        changed_any = true
        candidate[idx] = true
        if idx > 0 {
          candidate[idx - 1] = true
        }
        if idx + 1 < rank_len {
          candidate[idx + 1] = true
        }
      }
      delta = delta + rank_delta
      idx = idx + 1
    }
    if delta < 1 {
      break
    }
  }
  changed_any
}

///|
fn build_rank_groups_graphviz(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  pass : Int,
) -> Map[Int, Array[String]] {
  let ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    ordered[rank] = []
  }
  let nodes : Array[String] = []
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      nodes.push(name)
    }
  }
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in nodes {
    fallback_order[name] = i
  }
  let nlist = nodes.copy()
  if nlist.length() > 1 {
    nlist.sort_by((a, b) => {
      let a_idx = match node_order.get(a) {
        Some(value) => value
        None =>
          match fallback_order.get(a) {
            Some(value) => value
            None => 0
          }
      }
      let b_idx = match node_order.get(b) {
        Some(value) => value
        None =>
          match fallback_order.get(b) {
            Some(value) => value
            None => 0
          }
      }
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
  }
  let out_neighbors : Map[String, Array[String]] = Map::new()
  let in_neighbors : Map[String, Array[String]] = Map::new()
  for name in nlist {
    out_neighbors[name] = []
    in_neighbors[name] = []
  }
  for edge_idx in 0..<edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    match out_neighbors.get(tail) {
      Some(list) => list.push(head)
      None => out_neighbors[tail] = [head]
    }
    match in_neighbors.get(head) {
      Some(list) => list.push(tail)
      None => in_neighbors[head] = [tail]
    }
  }
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  let cluster_has_skeleton : Map[String, Bool] = Map::new()
  for name in nlist {
    if cluster_skeleton.get(name) == Some(true) {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster != "" {
        cluster_has_skeleton[cluster] = true
      }
    }
  }
  for name in nlist {
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster != "" && cluster_has_skeleton.get(cluster) == Some(true) {
      match cluster_nodes.get(cluster) {
        Some(list) => list.push(name)
        None => cluster_nodes[cluster] = [name]
      }
    }
  }
  for _key, list in cluster_nodes {
    if list.length() > 1 {
      list.sort_by((a, b) => {
        let a_rank = match node_ranks.get(a) {
          Some(value) => value
          None => 0
        }
        let b_rank = match node_ranks.get(b) {
          Some(value) => value
          None => 0
        }
        if a_rank < b_rank {
          -1
        } else if a_rank > b_rank {
          1
        } else {
          let a_idx = match node_order.get(a) {
            Some(value) => value
            None =>
              match fallback_order.get(a) {
                Some(value) => value
                None => 0
              }
          }
          let b_idx = match node_order.get(b) {
            Some(value) => value
            None =>
              match fallback_order.get(b) {
                Some(value) => value
                None => 0
              }
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
  let installed : Map[String, Bool] = Map::new()
  let marks : Map[String, Bool] = Map::new()
  let installed_clusters : Map[String, Bool] = Map::new()
  for node in nlist {
    let other =
      if pass == 0 {
        match in_neighbors.get(node) {
          Some(list) => list
          None => []
        }
      } else {
        match out_neighbors.get(node) {
          Some(list) => list
          None => []
        }
      }
    if other.length() > 0 {
      continue
    }
    if marks.get(node) == Some(true) {
      continue
    }
    marks[node] = true
    let queue : Array[String] = [node]
    let mut q_idx = 0
    while q_idx < queue.length() {
      let current = queue[q_idx]
      q_idx = q_idx + 1
      if cluster_skeleton.get(current) == Some(true) {
        let cluster = match cluster_keys.get(current) {
          Some(value) => value
          None => ""
        }
        if cluster != "" && installed_clusters.get(cluster) != Some(true) {
          installed_clusters[cluster] = true
          let cluster_list = match cluster_nodes.get(cluster) {
            Some(list) => list
            None => []
          }
          for cluster_node in cluster_list {
            if installed.get(cluster_node) != Some(true) {
              let rank = match node_ranks.get(cluster_node) {
                Some(value) => value
                None => 0
              }
              match ordered.get(rank) {
                Some(list) => list.push(cluster_node)
                None => ordered[rank] = [cluster_node]
              }
              installed[cluster_node] = true
            }
            marks[cluster_node] = true
          }
          for cluster_node in cluster_list {
            let neighbors =
              if pass == 0 {
                match out_neighbors.get(cluster_node) {
                  Some(list) => list
                  None => []
                }
              } else {
                match in_neighbors.get(cluster_node) {
                  Some(list) => list
                  None => []
                }
              }
            for neighbor in neighbors {
              if marks.get(neighbor) != Some(true) {
                marks[neighbor] = true
                queue.push(neighbor)
              }
            }
          }
        }
        continue
      }
      if installed.get(current) != Some(true) {
        let rank = match node_ranks.get(current) {
          Some(value) => value
          None => 0
        }
        match ordered.get(rank) {
          Some(list) => list.push(current)
          None => ordered[rank] = [current]
        }
        installed[current] = true
      }
      let neighbors =
        if pass == 0 {
          match out_neighbors.get(current) {
            Some(list) => list
            None => []
          }
        } else {
          match in_neighbors.get(current) {
            Some(list) => list
            None => []
          }
        }
      for neighbor in neighbors {
        if marks.get(neighbor) != Some(true) {
          marks[neighbor] = true
          queue.push(neighbor)
        }
      }
    }
  }
  for name in nlist {
    if installed.get(name) != Some(true) {
      let rank = match node_ranks.get(name) {
        Some(value) => value
        None => 0
      }
      match ordered.get(rank) {
        Some(list) => list.push(name)
        None => ordered[rank] = [name]
      }
      installed[name] = true
    }
  }
  ordered
}

///|
fn reorder_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let mut ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    ordered[rank] = names
  }
  let rank_sizes : Map[Int, Int] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    rank_sizes[rank] = names.length()
  }
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = port_is_explicit(edge.tail_port()) ||
      port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  let mut has_ported_nodes = false
  for _name, _ in port_edge_nodes {
    has_ported_nodes = true
    break
  }
  let edge_pair_order : Map[String, Int] = Map::new()
  let mut edge_idx = 0
  for _edge in edges {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    edge_pair_order["\{tail}|\{head}"] = edge_idx
    edge_idx = edge_idx + 1
  }
  let node_penalty : Map[String, Int] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = edge_xpenalty(edge)
    if penalty <= 0 {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_sum = match node_penalty.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_sum = match node_penalty.get(head) {
      Some(value) => value
      None => 0
    }
    node_penalty[tail] = tail_sum + penalty
    node_penalty[head] = head_sum + penalty
  }
  let node_ranks = build_node_ranks(ordered)
  let mut best_ordered = clone_rank_groups(ordered)
  let mut order_positions = order_positions_from_groups(ordered)
  let mut has_port_order = false
  for _name, _ in port_order_positions {
    has_port_order = true
    break
  }
  let mut has_rank_same = false
  for _name, _ in rank_same_groups {
    has_rank_same = true
    break
  }
  let mut has_preferred = false
  for _name, _ in preferred_positions {
    has_preferred = true
    break
  }
  let mut has_port_contrib = false
  for _name, _ in port_order_contrib {
    has_port_contrib = true
    break
  }
  let graphviz_style = !has_rank_same && !has_port_order && !has_ported_nodes &&
    !has_preferred && !has_port_contrib
  let median_parents : Map[String, Array[String]] = Map::new()
  let median_children : Map[String, Array[String]] = Map::new()
  let edge_penalty : Array[Int] = []
  let edge_in : Map[String, Array[Int]] = Map::new()
  let edge_out : Map[String, Array[Int]] = Map::new()
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      if graphviz_style {
        median_parents[name] = []
        median_children[name] = []
      }
      edge_in[name] = []
      edge_out[name] = []
    }
  }
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if penalty <= 0 || !edge_is_constraint(edge) {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match node_ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match node_ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    if graphviz_style {
      match median_parents.get(head) {
        Some(list) => list.push(tail)
        None => median_parents[head] = [tail]
      }
      match median_children.get(tail) {
        Some(list) => list.push(head)
        None => median_children[tail] = [head]
      }
    }
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
    match edge_in.get(head) {
      Some(list) => list.push(edge_idx)
      None => edge_in[head] = [edge_idx]
    }
  }
  let mut best_cross =
    if graphviz_style {
    count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
  } else {
    count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if !graphviz_style && rank_keys.length() > 1 {
    ordered = build_rank_groups_graphviz(
      rank_keys,
      groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      0,
    )
    order_positions = order_positions_from_groups(ordered)
    let seed_cross =
      count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
    if seed_cross > 0 {
      let _ = transpose_rank_groups_graphviz(
        rank_keys,
        ordered,
        node_ranks,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
      )
      order_positions = order_positions_from_groups(ordered)
    }
    best_ordered = clone_rank_groups(ordered)
    best_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if graphviz_style && rank_keys.length() > 1 {
    let max_iter = 24
    let min_quit = 8
    let convergence = 0.995
    let mut cur_cross = best_cross
    let mut pass = 0
    while pass <= 2 {
      let max_this_pass =
        if pass <= 1 {
        if max_iter < 4 { max_iter } else { 4 }
      } else {
        max_iter
      }
      if pass <= 1 {
        ordered = build_rank_groups_graphviz(
          rank_keys,
          groups,
          edge_tail,
          edge_head,
          node_ranks,
          node_order,
          cluster_keys,
          cluster_skeleton,
          pass,
        )
        order_positions = order_positions_from_groups(ordered)
        if !has_port_order {
          let cross =
            count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
          if cross > 0 {
            let _ = transpose_rank_groups_graphviz(
              rank_keys,
              ordered,
              node_ranks,
              edge_in,
              edge_out,
              edge_tail,
              edge_head,
              edge_penalty,
              cluster_keys,
              cluster_skeleton,
              flat_constraints,
              false,
              0,
            )
            order_positions = order_positions_from_groups(ordered)
          }
        }
        cur_cross =
          count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
        if cur_cross <= best_cross {
          best_cross = cur_cross
          best_ordered = clone_rank_groups(ordered)
        }
      } else {
        if cur_cross > best_cross {
          for rank in rank_keys {
            let names = match best_ordered.get(rank) {
              Some(list) => list.copy()
              None => []
            }
            ordered[rank] = names
          }
          order_positions = order_positions_from_groups(ordered)
        }
        cur_cross = best_cross
      }
      let mut trying = 0
      let mut iter = 0
      while iter < max_this_pass {
        if trying >= min_quit || cur_cross == 0 {
          break
        }
        trying = trying + 1
        let reverse = iter % 4 < 2
        if iter % 2 == 0 {
          let mut idx = 1
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_parents,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            idx = idx + 1
          }
        } else {
          let mut idx = rank_keys.length() - 2
          while true {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_children,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if !has_port_order {
          let _ = transpose_rank_groups_graphviz(
            rank_keys,
            ordered,
            node_ranks,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            !reverse,
            0,
          )
          order_positions = order_positions_from_groups(ordered)
        }
        cur_cross =
          count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
        if cur_cross <= best_cross {
          let prev_best = best_cross
          best_cross = cur_cross
          best_ordered = clone_rank_groups(ordered)
          if prev_best > 0 &&
            cur_cross.to_double() < convergence * prev_best.to_double() {
            trying = 0
          }
        }
        iter = iter + 1
      }
      if cur_cross == 0 {
        break
      }
      pass = pass + 1
    }
    if cur_cross > best_cross {
      for rank in rank_keys {
        let names = match best_ordered.get(rank) {
          Some(list) => list.copy()
          None => []
        }
        ordered[rank] = names
      }
      order_positions = order_positions_from_groups(ordered)
    }
    if best_cross > 0 && !has_port_order {
      let _ = transpose_rank_groups_graphviz(
        rank_keys,
        ordered,
        node_ranks,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
      )
    }
    return clone_rank_groups(ordered)
  }
  if !graphviz_style && rank_keys.length() > 1 {
    let iterations = if rank_keys.length() > 2 { 2 } else { 1 }
    let mut iter = 0
    while iter < iterations {
      let reverse_ties = iter % 2 == 1
      if graphviz_style {
        if iter % 2 == 0 {
          let mut idx = 1
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_parents,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            idx = idx + 1
          }
        } else {
          let mut idx = rank_keys.length() - 2
          while true {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_children,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if !has_port_order {
          let _ = transpose_rank_groups_graphviz(
            rank_keys,
            ordered,
            node_ranks,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            !reverse_ties,
            0,
          )
          order_positions = order_positions_from_groups(ordered)
        }
        let cross =
          count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
        if cross <= best_cross {
          best_cross = cross
          best_ordered = clone_rank_groups(ordered)
        }
      } else {
        let mut idx = rank_keys.length() - 1
        while idx > 0 {
          let rank = rank_keys[idx - 1]
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              parents,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
          }
          idx = idx - 1
        }
        if !has_port_order {
          let _ = transpose_rank_groups_limited(
            rank_keys, ordered, parents, children, node_ranks, true, 2,
          )
        }
        for rank in rank_keys {
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              parents,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
          }
        }
        let down_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
        if down_cross < best_cross {
          best_cross = down_cross
          best_ordered = clone_rank_groups(ordered)
        }
        let mut j = 1
        while j < rank_keys.length() {
          let rank = rank_keys[j]
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              children,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
          }
          j = j + 1
        }
        if !has_port_order {
          let _ = transpose_rank_groups_limited(
            rank_keys, ordered, parents, children, node_ranks, false, 2,
          )
        }
        for rank in rank_keys {
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              children,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
          }
        }
        let up_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
        if up_cross < best_cross {
          best_cross = up_cross
          best_ordered = clone_rank_groups(ordered)
        }
      }
      iter = iter + 1
    }
  }
  clone_rank_groups(best_ordered)
}

///|
fn reorder_groups_by_cluster_order(
  groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
  cluster_order_base : Map[String, Int],
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
fn build_rank_groups(
  nodes : Array[@cgraph.Node],
  ranks : Map[String, Int],
) -> Map[Int, Array[String]] {
  let groups : Map[Int, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match groups.get(rank) {
      Some(list) => list.push(name)
      None => groups[rank] = [name]
    }
  }
  groups
}

///|
fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn graph_has_cluster(graph : @cgraph.Graph) -> Bool {
  for subgraph in graph.subgraphs() {
    if is_cluster_graph(subgraph) {
      return true
    }
    if graph_has_cluster(subgraph) {
      return true
    }
  }
  false
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
fn collect_cluster_names(
  graph : @cgraph.Graph,
  out : Map[String, Bool],
) -> Unit {
  if is_cluster_graph(graph) {
    match graph.name() {
      Some(name) => out[name] = true
      None => ()
    }
  }
  for child in graph.subgraphs() {
    collect_cluster_names(child, out)
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
fn layout_subgraphs(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
) -> Array[DotLayoutGraph] {
  let result : Array[DotLayoutGraph] = []
  for subgraph in graph.subgraphs() {
    let node_set : Map[String, Bool] = Map::new()
    for node in subgraph.nodes() {
      node_set[node.name()] = true
    }
    let edge_set : Map[String, Bool] = Map::new()
    for edge in subgraph.edges() {
      edge_set[edge_key(edge)] = true
    }
    let sub_nodes : Array[DotLayoutNode] = []
    for node_layout in nodes_out {
      if node_set.get(node_layout.node.name()) is Some(_) {
        sub_nodes.push(node_layout)
      }
    }
    let sub_edges : Array[DotLayoutEdge] = []
    for edge_layout in edges_out {
      if edge_set.get(edge_key(edge_layout.edge)) is Some(_) {
        let tail_name = edge_layout.edge.tail().name()
        let head_name = edge_layout.edge.head().name()
        if node_set.get(tail_name) is Some(_) &&
          node_set.get(head_name) is Some(_) {
          sub_edges.push(edge_layout)
        }
      }
    }
    let mut bbox = compute_bbox(sub_nodes, sub_edges)
    let mut label_pos : @geom.Point? = None
    let mut label_info : (Double, Double, LabelLoc, LabelJust)? = None
    let sub_subgraphs = layout_subgraphs(subgraph, nodes_out, edges_out)
    if sub_subgraphs.length() > 0 {
      bbox = expand_bbox_with_subgraphs(bbox, sub_subgraphs)
    }
    if is_cluster_graph(subgraph) {
      let pad = cluster_margin_pt(subgraph)
      let llx = bbox.llx - pad
      let lly = bbox.lly - pad
      let urx = bbox.urx + pad
      let ury = bbox.ury + pad
      bbox = { llx, lly, urx, ury }
      match graph_label_metrics(subgraph) {
        Some((width_pt, height_pt)) => {
          let loc = graph_label_loc(subgraph)
          let just = graph_label_just(subgraph)
          bbox = expand_bbox_for_label(bbox, width_pt, height_pt, loc)
          let pad = CLUSTER_LABEL_PAD_PT
          let padded_width = width_pt + pad * 2.0
          let padded_height = height_pt + pad
          label_info = Some((padded_width, padded_height, loc, just))
        }
        None => ()
      }
      bbox = round_bbox(bbox)
    }
    match label_info {
      Some((width_pt, height_pt, loc, just)) =>
        label_pos = Some(graph_label_pos(bbox, width_pt, height_pt, loc, just))
      None => ()
    }
    result.push({
      graph: subgraph,
      bbox,
      label_pos,
      nodes: sub_nodes,
      edges: sub_edges,
      subgraphs: sub_subgraphs,
    })
  }
  result
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

///|

///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  { rankdir: None, nodesep: None, ranksep: None, splines: None }
}

///|
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  validate_layout_graph(graph)
  reset_label_caches()
  let rankdir = match opts.rankdir {
    Some(value) => value
    None =>
      match graph.get_attr("rankdir") {
        Some(value) =>
          match parse_rankdir(value) {
            Some(parsed) => parsed
            None => RankDir::TB
          }
        None => RankDir::TB
      }
  }
  let nodesep_in = match opts.nodesep {
    Some(value) => value
    None =>
      match graph.get_attr("nodesep") {
        Some(value) => parse_first_double(value, default_nodesep_in())
        None => default_nodesep_in()
      }
  }
  let ranksep_in = match opts.ranksep {
    Some(value) => value
    None =>
      match graph.get_attr("ranksep") {
        Some(value) => parse_first_double(value, default_ranksep_in())
        None => default_ranksep_in()
      }
  }
  if nodesep_in < 0.0 {
    raise DotLayoutError::InvalidGraph(message="nodesep must be non-negative")
  }
  if ranksep_in < 0.0 {
    raise DotLayoutError::InvalidGraph(message="ranksep must be non-negative")
  }
  let splines = match opts.splines {
    Some(value) => value
    None =>
      match graph.get_attr("splines") {
        Some(value) =>
          match parse_splines(value) {
            Some(parsed) => parsed
            None => SplinesMode::Spline
          }
        None => SplinesMode::Spline
      }
  }
  let _ = splines
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  dot_trace("layout_dot: start nodes=\{nodes.length()} edges=\{edges.length()}")
  let mut has_dotted_edges = false
  let mut has_port_edges = false
  for edge in edges {
    match edge.get_attr("style") {
      Some(value) =>
        if value.to_lower().contains("dotted") {
          has_dotted_edges = true
        }
      None => ()
    }
    if !has_port_edges {
      let tail_port = port_is_explicit(edge.tail_port())
      let head_port = port_is_explicit(edge.head_port())
      if tail_port || head_port {
        has_port_edges = true
      }
    }
  }
  let has_edge_labels = graph_has_edge_labels(edges)
  let node_order : Map[String, Int] = Map::new()
  for i in 0..<nodes.length() {
    node_order[nodes[i].name()] = i
  }
  if rankdir == RankDir::RL {
    let total = nodes.length()
    for node in nodes {
      let name = node.name()
      let base = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = total - 1 - base
    }
  }
  let layout_rankdir = RankDir::TB
  let record_orientation = record_layout_orientation(rankdir)
  let output_sizes : Map[String, NodeSize] = Map::new()
  let order_sizes : Map[String, NodeSize] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let size = node_size(node, record_orientation)
    output_sizes[node.name()] = size
    order_sizes[node.name()] = size
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      swap_node_size(size)
    } else {
      size
    }
  }
  let port_order_positions : Map[String, Double] = Map::new()
  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  if (rankdir == RankDir::LR || rankdir == RankDir::RL) && has_port_edges {
    let record_port_order : Map[String, Map[String, Double]] = Map::new()
    for node in nodes {
      let label = label_text(node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html || is_record_shape(node) {
        let name = node.name()
        let size = match output_sizes.get(name) {
          Some(value) => value
          None => node_size(node, record_orientation)
        }
        let raw_ports =
          if has_html {
            html_ports(node, { x: 0.0, y: 0.0 }, size)
          } else {
            record_ports(node, { x: 0.0, y: 0.0 }, size, record_orientation)
          }
        let order_map : Map[String, Double] = Map::new()
        for port_name, port in raw_ports {
          let offset = layout_port_offset(port.center, rankdir)
          order_map[port_name] = offset.x
        }
        record_port_order[name] = order_map
      }
    }
    let order_sum : Map[String, (Double, Int)] = Map::new()
    let update_order = (target : String, anchor : String, port : @cgraph.Port?) => {
      match port {
        Some(value) =>
          match value.name {
            Some(port_name) =>
              match record_port_order.get(anchor) {
                Some(ports) =>
                  match ports.get(port_name) {
                    Some(order) => {
                      let (sum, count) = match order_sum.get(target) {
                        Some(value) => value
                        None => (0.0, 0)
                      }
                      order_sum[target] = (sum + order, count + 1)
                      match port_order_contrib.get(target) {
                        Some(list) => list.push((anchor, order))
                        None => port_order_contrib[target] = [(anchor, order)]
                      }
                    }
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
        None => ()
      }
    }
    for edge in edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
        update_order(head_name, tail_name, edge.tail_port())
      }
      if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
        update_order(tail_name, head_name, edge.head_port())
      }
    }
  for name, entry in order_sum {
    let (sum, count) = entry
    if count > 0 {
    port_order_positions[name] = sum / count.to_double()
  }
}
}
  let (edge_tail, edge_head, edge_reversed) =
    if graph.kind() == @cgraph.GraphKind::Directed {
    acyclic_edge_directions(nodes, edges)
  } else {
    edge_endpoints_from_edges(edges)
  }
  let ranks = if graph.kind() == @cgraph.GraphKind::Directed {
    compute_ranks_directed(
      graph,
      nodes,
      edges,
      has_edge_labels,
      edge_tail,
      edge_head,
      edge_reversed,
    )
  } else {
    let base : Map[String, Int] = Map::new()
    for node in nodes {
      base[node.name()] = 0
    }
    base
  }
  dot_trace("layout_dot: ranks computed")
  dot_trace_edges(edges, edge_tail, edge_head, ranks)
  let groups = build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  let self_edge_labels = self_edge_label_half_heights(edges)
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_half = 0.0
    for name in names {
      let half_height = node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
  if has_edge_labels {
    for edge in edges {
      if !edge_has_label(edge) {
        continue
      }
      let tail = edge.tail().name()
      let head = edge.head().name()
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => continue
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => continue
      }
      let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
      let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
      if max_rank - min_rank <= 1 {
        continue
      }
      let label_rank = (min_rank + max_rank) / 2
      let half_height = edge_label_height_pt(edge) / 2.0
      let current = match rank_pht.get(label_rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[label_rank] = half_height
      }
    }
  }
  let vnode_half_height = VNODE_HEIGHT_PT / 2.0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      continue
    }
    for rank in (min_rank + 1)..<max_rank {
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if vnode_half_height > current {
        rank_pht[rank] = vnode_half_height
      }
    }
  }
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = match rank_pht.get(rank) {
      Some(value) => value
      None => 0.0
    }
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  let _ = apply_cluster_rank_heights(
    graph, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
  )
  let nodesep_pt = nodesep_in * 72.0
  let has_clusters = graph_has_cluster(graph)
  let mut ranksep_pt = ranksep_in * 72.0
  if has_edge_labels {
    ranksep_pt = (ranksep_pt + 1.0) / 2.0
  }
  let y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  let cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    cluster_keys[node.name()] = node_cluster_key(node)
  }
  let cluster_skeleton : Map[String, Bool] = Map::new()
  let cluster_rank_seen : Map[String, Bool] = Map::new()
  for rank, names in groups {
    for name in names {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let key = "\{cluster}@\{rank}"
      if cluster_rank_seen.get(key) is None {
        cluster_rank_seen[key] = true
        cluster_skeleton[name] = true
      }
    }
  }
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let cluster_first_order : Map[String, Int] = Map::new()
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
      None => 0
    }
    match cluster_min_rank.get(cluster) {
      Some(current) => if rank < current { cluster_min_rank[cluster] = rank }
      None => cluster_min_rank[cluster] = rank
    }
    match cluster_max_rank.get(cluster) {
      Some(current) => if rank > current { cluster_max_rank[cluster] = rank }
      None => cluster_max_rank[cluster] = rank
    }
    if cluster_first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      cluster_first_order[cluster] = order_value
    }
  }
  let cluster_order_list : Array[(String, Int, Int)] = []
  for cluster, rank in cluster_min_rank {
    let order = match cluster_first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    cluster_order_list.push((cluster, rank, order))
  }
  let cluster_order_base : Map[String, Int] = Map::new()
  if cluster_order_list.length() > 1 {
    cluster_order_list.sort_by((a, b) => {
      let (_name_a, rank_a, order_a) = a
      let (_name_b, rank_b, order_b) = b
      if rank_a < rank_b {
        -1
      } else if rank_a > rank_b {
        1
      } else if order_a < order_b {
        -1
      } else if order_a > order_b {
        1
      } else {
        0
      }
    })
    let step = nodes.length() + 1
    let mut base = 0
    for entry in cluster_order_list {
      let (cluster, _rank, _order) = entry
      cluster_order_base[cluster] = base
      base = base + step
    }
    for node in nodes {
      let name = node.name()
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let base_order = match cluster_order_base.get(cluster) {
        Some(value) => value
        None => 0
      }
      let inner = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = base_order + inner
    }
  }
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    intercluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let rank_same_groups : Map[String, Int] = Map::new()
  let rank_same_order : Map[String, Int] = Map::new()
  let _ = collect_rank_same_order(graph, rank_same_groups, rank_same_order, 0)
  let edge_order = collect_edge_order(edges)
  let (order_edges, order_edge_tail, order_edge_head) =
    dedup_ordering_edges(edges, edge_tail, edge_head)
  let (flat_constraints, ordering_set) = build_ordering_flat_constraints(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    cluster_keys,
  )
  let (parents, children) =
    build_edge_index_for_order(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
    )
  let ordered_groups_internal = reorder_rank_groups(
    rank_keys,
    groups,
    order_edges,
    order_edge_tail,
    order_edge_head,
    parents,
    children,
    cluster_keys,
    rank_same_groups,
    rank_same_order,
    edge_order,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    cluster_skeleton,
    flat_constraints,
  )
  let ordered_groups =
    if has_clusters {
    let ordering_groups : Map[Int, Array[String]] = Map::new()
    let ordering_sizes : Map[String, NodeSize] = Map::new()
    let ordering_node_order : Map[String, Int] = Map::new()
    let ordering_cluster_keys : Map[String, String] = Map::new()
    let ordering_cluster_skeleton : Map[String, Bool] = Map::new()
    let skeleton_lookup : Map[String, String] = Map::new()
    let skeleton_cluster : Map[String, String] = Map::new()
    let skeleton_size = vnode_size_from_widths(0.0, 0.0)
    for rank in rank_keys {
      let names = match groups.get(rank) {
        Some(list) => list
        None => []
      }
      let list : Array[String] = []
      for name in names {
        let cluster = match cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster != "" {
          continue
        }
        list.push(name)
        let size = match order_sizes.get(name) {
          Some(value) => value
          None => vnode_size_from_widths(0.0, 0.0)
        }
        ordering_sizes[name] = size
        let order_value = match node_order.get(name) {
          Some(value) => value
          None => 0
        }
        ordering_node_order[name] = order_value
        ordering_cluster_keys[name] = ""
      }
      ordering_groups[rank] = list
    }
    let mut has_cluster_skeleton = false
    for cluster, min_rank in cluster_min_rank {
      let max_rank = match cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      for rank in min_rank..=max_rank {
        let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
        let key = "\{cluster}@\{rank}"
        skeleton_lookup[key] = name
        skeleton_cluster[name] = cluster
        ordering_sizes[name] = skeleton_size
        ordering_node_order[name] = rank
        ordering_cluster_keys[name] = cluster
        ordering_cluster_skeleton[name] = true
        match ordering_groups.get(rank) {
          Some(list) => list.push(name)
          None => ordering_groups[rank] = [name]
        }
        has_cluster_skeleton = true
      }
    }
    if !has_cluster_skeleton {
      ordered_groups_internal
    } else {
      let ordering_rank_keys = collect_rank_keys(ordering_groups)
      let ordering_ranks = build_node_ranks(ordering_groups)
      let ordering_nodes : Array[String] = []
      for rank in ordering_rank_keys {
        let names = match ordering_groups.get(rank) {
          Some(list) => list
          None => []
        }
        for name in names {
          ordering_nodes.push(name)
        }
      }
      let ordering_graph =
        @cgraph.Graph::new(@cgraph.GraphKind::Directed, name="xpos_cluster_order", strict=false)
      let ordering_node_map : Map[String, @cgraph.Node] = Map::new()
      for name in ordering_nodes {
        ordering_node_map[name] = ordering_graph.node(name)
      }
      let ordering_edges : Array[@cgraph.Edge] = []
      let ordering_edge_tail : Array[String] = []
      let ordering_edge_head : Array[String] = []
      let mut edge_idx = 0
      for edge in order_edges {
        let tail = order_edge_tail[edge_idx]
        let head = order_edge_head[edge_idx]
        let tail_cluster = match cluster_keys.get(tail) {
          Some(value) => value
          None => ""
        }
        let head_cluster = match cluster_keys.get(head) {
          Some(value) => value
          None => ""
        }
        if tail_cluster != "" && tail_cluster == head_cluster {
          edge_idx = edge_idx + 1
          continue
        }
        let mapped_tail =
          if tail_cluster != "" {
            let rank = match ranks.get(tail) {
              Some(value) => value
              None => 0
            }
            let key = "\{tail_cluster}@\{rank}"
            match skeleton_lookup.get(key) {
              Some(value) => value
              None => tail
            }
          } else {
            tail
          }
        let mapped_head =
          if head_cluster != "" {
            let rank = match ranks.get(head) {
              Some(value) => value
              None => 0
            }
            let key = "\{head_cluster}@\{rank}"
            match skeleton_lookup.get(key) {
              Some(value) => value
              None => head
            }
          } else {
            head
          }
        let penalty = edge_xpenalty(edge)
        let constraint = edge_is_constraint(edge)
        add_order_edge(
          ordering_graph,
          ordering_node_map,
          ordering_edges,
          ordering_edge_tail,
          ordering_edge_head,
          mapped_tail,
          mapped_head,
          penalty,
          constraint,
        )
        edge_idx = edge_idx + 1
      }
      for cluster, min_rank in cluster_min_rank {
        let max_rank = match cluster_max_rank.get(cluster) {
          Some(value) => value
          None => min_rank
        }
        let mut rank = min_rank
        while rank < max_rank {
          let tail_key = "\{cluster}@\{rank}"
          let head_key = "\{cluster}@\{rank + 1}"
          match (skeleton_lookup.get(tail_key), skeleton_lookup.get(head_key)) {
            (Some(tail_name), Some(head_name)) =>
              add_order_edge(
                ordering_graph,
                ordering_node_map,
                ordering_edges,
                ordering_edge_tail,
                ordering_edge_head,
                tail_name,
                head_name,
                CL_CROSS,
                true,
              )
            _ => ()
          }
          rank = rank + 1
        }
      }
      let (ordering_parents, ordering_children) =
        build_edge_index_for_order_names(
          ordering_nodes,
          ordering_edge_tail,
          ordering_edge_head,
          ordering_ranks,
        )
      let ordering_edge_order = collect_edge_order(ordering_edges)
      let ordered_cluster_groups = reorder_rank_groups(
        ordering_rank_keys,
        ordering_groups,
        ordering_edges,
        ordering_edge_tail,
        ordering_edge_head,
        ordering_parents,
        ordering_children,
        ordering_cluster_keys,
        Map::new(),
        Map::new(),
        ordering_edge_order,
        ordering_node_order,
        ordering_sizes,
        nodesep_pt,
        has_edge_labels,
        Map::new(),
        Map::new(),
        Map::new(),
        ordering_cluster_skeleton,
        Map::new(),
      )
      let cluster_nodes_by_rank : Map[String, Map[Int, Array[String]]] = Map::new()
      for rank in rank_keys {
        let names = match ordered_groups_internal.get(rank) {
          Some(list) => list
          None => []
        }
        for name in names {
          let cluster = match cluster_keys.get(name) {
            Some(value) => value
            None => ""
          }
          if cluster == "" {
            continue
          }
          let rank_map = match cluster_nodes_by_rank.get(cluster) {
            Some(map) => map
            None => {
              let map : Map[Int, Array[String]] = Map::new()
              cluster_nodes_by_rank[cluster] = map
              map
            }
          }
          match rank_map.get(rank) {
            Some(list) => list.push(name)
            None => rank_map[rank] = [name]
          }
        }
      }
      let expanded_groups : Map[Int, Array[String]] = Map::new()
      for rank in rank_keys {
        let names = match ordered_cluster_groups.get(rank) {
          Some(list) => list
          None => []
        }
        let expanded : Array[String] = []
        for name in names {
          match skeleton_cluster.get(name) {
            Some(cluster) =>
              match cluster_nodes_by_rank.get(cluster) {
                Some(rank_map) =>
                  match rank_map.get(rank) {
                    Some(list) =>
                      for node in list {
                        expanded.push(node)
                      }
                    None => ()
                  }
                None => ()
              }
            None => expanded.push(name)
          }
        }
        expanded_groups[rank] = expanded
      }
      expanded_groups
    }
  } else {
    ordered_groups_internal
  }
  dot_trace("layout_dot: rank order computed")
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    edges,
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
  )
  let vnode_count = vnode_info.vnode_ranks.length()
  let use_vnodes_for_xpos =
    has_edge_labels || has_port_edges || vnode_count <= MAX_XPOS_VNODES
  let allow_xpos_reorder =
    !use_vnodes_for_xpos || vnode_count <= MAX_XPOS_REORDER_VNODES
  dot_trace("layout_dot: vnodes built count=\{vnode_count}")
  let virtual_slack_edges =
    if use_vnodes_for_xpos {
      let node_singletons = build_node_singletons(nodes, edges)
      let edges_out = build_virtual_slack_edges(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        vnode_info.edge_vnodes,
        vnode_info.vnode_ranks,
        node_singletons,
        cluster_keys,
      )
      dot_trace("layout_dot: virtual slack edges=\{edges_out.length()}")
      edges_out
    } else {
      dot_trace("layout_dot: virtual slack edges=0 (skipped)")
      []
    }
  let order_index = build_order_index(ordered_groups)
  let vnode_order_keys =
    if use_vnodes_for_xpos {
      build_vnode_order_keys(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        order_index,
        vnode_info.edge_vnodes,
        vnode_info.vnode_ranks,
      )
    } else {
      Map::new()
    }
  let mut has_vnode_order = false
  for _name, _ in vnode_order_keys {
    has_vnode_order = true
    break
  }
  let x_base_sizes = apply_self_edge_right_space(
    nodes,
    edges,
    order_sizes,
    rankdir,
    record_orientation,
  )
  let x_order_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(x_base_sizes, vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let mut x_groups =
    if use_vnodes_for_xpos {
      build_x_groups_with_vnodes(
        ordered_groups,
        order_index,
        vnode_info.vnodes_by_rank,
        vnode_order_keys,
      )
    } else {
      ordered_groups
    }
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_keys {
    x_cluster_keys[name] = key
  }
  if use_vnodes_for_xpos {
    for name, key in vnode_info.vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  if use_vnodes_for_xpos && allow_xpos_reorder && !ordering_set {
    let order_groups : Map[Int, Array[String]] = Map::new()
    for rank, names in x_groups {
      order_groups[rank] = names.copy()
    }
    let order_sizes : Map[String, NodeSize] = Map::new()
    for name, size in x_order_sizes {
      order_sizes[name] = size
    }
    let order_cluster_keys : Map[String, String] = Map::new()
    for name, key in x_cluster_keys {
      order_cluster_keys[name] = key
    }
    let order_cluster_skeleton : Map[String, Bool] = Map::new()
    let skeleton_size = vnode_size_from_widths(0.0, 0.0)
    for cluster, min_rank in cluster_min_rank {
      let max_rank = match cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      for rank in min_rank..=max_rank {
        let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
        order_cluster_keys[name] = cluster
        order_cluster_skeleton[name] = true
        order_sizes[name] = skeleton_size
        match order_groups.get(rank) {
          Some(list) => list.push(name)
          None => order_groups[rank] = [name]
        }
      }
    }
    let order_node_order : Map[String, Int] = Map::new()
    for name, value in node_order {
      order_node_order[name] = value
    }
    let order_index = build_order_index(order_groups)
    for name, idx in order_index {
      if order_node_order.get(name) is None {
        order_node_order[name] = idx
      }
    }
    let order_rank_keys = collect_rank_keys(order_groups)
    let order_ranks = build_node_ranks(order_groups)
    let order_nodes : Array[String] = []
    for rank in order_rank_keys {
      let names = match order_groups.get(rank) {
        Some(list) => list
        None => []
      }
      for name in names {
        order_nodes.push(name)
      }
    }
    let order_graph =
      @cgraph.Graph::new(@cgraph.GraphKind::Directed, name="xpos_order", strict=false)
    let order_node_map : Map[String, @cgraph.Node] = Map::new()
    for name in order_nodes {
      order_node_map[name] = order_graph.node(name)
    }
    let order_edges_out : Array[@cgraph.Edge] = []
    let order_edge_tail_out : Array[String] = []
    let order_edge_head_out : Array[String] = []
    let mut edge_idx = 0
    for edge in edges {
      let tail =
        if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
          edge.tail().name()
        }
      let head =
        if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
          edge.head().name()
        }
      let penalty = edge_xpenalty(edge)
      let constraint = edge_is_constraint(edge)
      let vnodes = match vnode_info.edge_vnodes.get(edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      if vnodes.length() == 0 {
        add_order_edge(
          order_graph,
          order_node_map,
          order_edges_out,
          order_edge_tail_out,
          order_edge_head_out,
          tail,
          head,
          penalty,
          constraint,
        )
      } else {
        let tail_rank = match ranks.get(tail) {
          Some(value) => value
          None => 0
        }
        let head_rank = match ranks.get(head) {
          Some(value) => value
          None => 0
        }
        let chain : Array[String] = []
        chain.push(tail)
        if tail_rank <= head_rank {
          for vnode in vnodes {
            chain.push(vnode)
          }
        } else {
          let mut i = vnodes.length()
          while i > 0 {
            i = i - 1
            chain.push(vnodes[i])
          }
        }
        chain.push(head)
        let mut idx = 0
        while idx + 1 < chain.length() {
          add_order_edge(
            order_graph,
            order_node_map,
            order_edges_out,
            order_edge_tail_out,
            order_edge_head_out,
            chain[idx],
            chain[idx + 1],
            penalty,
            constraint,
          )
          idx = idx + 1
        }
      }
      edge_idx = edge_idx + 1
    }
    for cluster, min_rank in cluster_min_rank {
      let max_rank = match cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      let mut rank = min_rank
      while rank < max_rank {
        let tail_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
        let head_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank + 1}"
        add_order_edge(
          order_graph,
          order_node_map,
          order_edges_out,
          order_edge_tail_out,
          order_edge_head_out,
          tail_name,
          head_name,
          CL_CROSS,
          true,
        )
        rank = rank + 1
      }
    }
    let (parents, children) = build_edge_index_for_order_names(
      order_nodes,
      order_edge_tail_out,
      order_edge_head_out,
      order_ranks,
    )
    let edge_order = collect_edge_order(order_edges_out)
    let ordered_groups = reorder_rank_groups(
      order_rank_keys,
      order_groups,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      parents,
      children,
      order_cluster_keys,
      rank_same_groups,
      rank_same_order,
      edge_order,
      order_node_order,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      Map::new(),
      Map::new(),
      Map::new(),
      order_cluster_skeleton,
      flat_constraints,
    )
    let cleaned_groups : Map[Int, Array[String]] = Map::new()
    for rank in order_rank_keys {
      let names = match ordered_groups.get(rank) {
        Some(list) => list
        None => []
      }
      let cleaned : Array[String] = []
      for name in names {
        if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
          cleaned.push(name)
        }
      }
      cleaned_groups[rank] = cleaned
    }
    x_groups = cleaned_groups
  } else if allow_xpos_reorder && !ordering_set && !has_vnode_order && !has_clusters {
    let (parents, children) = build_edge_index_for_order_with_vnodes(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
    )
    let tmp_rank_keys = collect_rank_keys(x_groups)
    x_groups = reorder_rank_groups(
      tmp_rank_keys,
      x_groups,
      order_edges,
      order_edge_tail,
      order_edge_head,
      parents,
      children,
      x_cluster_keys,
      rank_same_groups,
      rank_same_order,
      edge_order,
      node_order,
      x_order_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      Map::new(),
      cluster_skeleton,
      flat_constraints,
    )
  }
  dot_trace_groups("x-groups", x_groups)
  if use_vnodes_for_xpos && allow_xpos_reorder && !ordering_set {
    let (parents, children) = build_edge_index_for_order_with_vnodes(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
    )
    let tmp_rank_keys = collect_rank_keys(x_groups)
    let tmp_ranks = build_node_ranks(x_groups)
    let _ = transpose_rank_groups_limited(
      tmp_rank_keys,
      x_groups,
      parents,
      children,
      tmp_ranks,
      false,
      4,
    )
    let _ = transpose_rank_groups_limited(
      tmp_rank_keys,
      x_groups,
      parents,
      children,
      tmp_ranks,
      true,
      4,
    )
  }
  let mut flat_label_edges : Array[ConstraintEdge] = []
  let mut flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let mut flat_label_edge_vnodes : Map[String, String] = Map::new()
  if use_vnodes_for_xpos {
    let (
      updated_groups,
      label_nodes,
      label_edge_vnodes,
      extra_edges,
    ) = add_flat_label_vnodes(
      edges,
      edge_tail,
      edge_head,
      ranks,
      ordered_groups,
      nodesep_pt,
      rankdir,
      x_base_sizes,
      edge_cluster_keys,
      existing_names,
      vnode_info,
      x_groups,
    )
    x_groups = updated_groups
    flat_label_edges = extra_edges
    flat_label_nodes = label_nodes
    flat_label_edge_vnodes = label_edge_vnodes
    for name, key in vnode_info.vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  if flat_label_nodes.length() > 0 {
    for name, info in flat_label_nodes {
      let size = match vnode_info.vnode_sizes.get(name) {
        Some(value) => value
        None => continue
      }
      let half_height = size.height_pt / 2.0
      let rank = info.rank
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[rank] = half_height
      }
      let current_ht1 = match rank_ht1.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current_ht1 {
        rank_ht1[rank] = half_height
      }
      let current_ht2 = match rank_ht2.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current_ht2 {
        rank_ht2[rank] = half_height
      }
    }
  }
  let y_all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let mut min_rank = rank_keys[0]
    let mut max_rank = rank_keys[rank_keys.length() - 1]
    if flat_label_nodes.length() > 0 {
      for _name, info in flat_label_nodes {
        if info.rank < min_rank {
          min_rank = info.rank
        }
        if info.rank > max_rank {
          max_rank = info.rank
        }
      }
    }
    for rank in min_rank..=max_rank {
      y_all_ranks.push(rank)
    }
  }
  fill_rank_positions(
    rank_keys,
    groups,
    y_all_ranks,
    rank_pht,
    rank_ht1,
    rank_ht2,
    ranksep_pt,
    y_positions,
    rank_y,
  )
  let x_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(x_base_sizes, vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let x_rank_keys = collect_rank_keys(x_groups)
  let x_ranks = build_node_ranks(x_groups)
  let vnode_extra_nodes =
    if use_vnodes_for_xpos {
      build_vnode_extra_nodes(vnode_info.vnode_ranks)
    } else {
      []
    }
  let x_edge_vnodes =
    if use_vnodes_for_xpos {
      vnode_info.edge_vnodes
    } else {
      Map::new()
    }
  let x_slack_edges =
    if use_vnodes_for_xpos {
      virtual_slack_edges
    } else {
      []
    }
  let x_positions = compute_x_positions(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    x_ranks,
    x_rank_keys,
    x_groups,
    x_sizes,
    output_sizes,
    x_cluster_keys,
    nodesep_pt,
    has_edge_labels,
    vnode_extra_nodes,
    flat_label_edges,
    x_edge_vnodes,
    x_slack_edges,
  )
  dot_trace("layout_dot: x positions computed")
  dot_trace_positions("xpos", x_positions)
  let intercluster_align_enabled = match @sys.get_env_var("DOT_INTERCLUSTER_ALIGN") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
  if has_clusters && has_dotted_edges && intercluster_align_enabled {
    adjust_intercluster_alignment(
      nodes,
      edges,
      ranks,
      x_positions,
      cluster_keys,
      intercluster_keys,
      nodesep_pt,
      has_edge_labels,
    )
  }
  let vnode_names : Array[String] = []
  for pair in vnode_extra_nodes {
    let (name, _rank) = pair
    vnode_names.push(name)
  }
  // Let the final bounding-box translation handle normalization, matching Graphviz.
  let vnode_positions =
    if use_vnodes_for_xpos {
      let positions : Map[String, @geom.Point] = Map::new()
      for name, rank in vnode_info.vnode_ranks {
        let pos_x = match x_positions.get(name) {
          Some(value) => value
          None => 0.0
        }
        let pos_y = match rank_y.get(rank) {
          Some(value) => value
          None => 0.0
        }
        positions[name] = { x: pos_x, y: pos_y }
      }
      positions
    } else {
      vnode_positions_from_endpoints(
        edges,
        ranks,
        vnode_info.vnode_ranks,
        vnode_info.edge_vnodes,
        x_positions,
        rank_y,
      )
    }
  let positions : Map[String, @geom.Point] = Map::new()
  for node in nodes {
    let name = node.name()
    let pos_x = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = match y_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    positions[name] = { x: pos_x, y: pos_y }
  }
  if has_clusters && cluster_rounding_enabled() {
    let _ = adjust_cluster_positions_for_rounding(
      graph,
      positions,
      vnode_positions,
      vnode_info.vnode_clusters,
      sizes,
    )
  }
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = match output_sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
    })
  }
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  let label_ports_raw : Map[String, Map[String, RecordPort]] = Map::new()
  if has_port_edges {
    for node_layout in nodes_out {
      let name = node_layout.node.name()
      let final_size = match output_sizes.get(name) {
        Some(value) => value
        None => node_size(node_layout.node, record_orientation)
      }
      let label = label_text(node_layout.node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html {
        let raw_ports = html_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      } else if is_record_shape(node_layout.node) {
        let raw_ports = record_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
          record_orientation,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      }
    }
  }
  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  if graph_has_cluster(graph) {
    let cluster_layouts = layout_subgraphs(graph, nodes_out, [])
    collect_cluster_bboxes(cluster_layouts, cluster_bboxes)
  }
  let label_edge_counts : Map[String, Int] = Map::new()
  for edge in edges {
    if edge_mid_label_text(edge) is Some(_) {
      let tail = edge.tail().name()
      let current = match label_edge_counts.get(tail) {
        Some(value) => value
        None => 0
      }
      label_edge_counts[tail] = current + 1
    }
  }
  let enable_complex_tuning =
    match @sys.get_env_var("DOT_COMPLEX_TUNING") {
      Some(value) => {
        let lower = value.to_lower()
        lower != "0" && lower != "false" && lower != "no"
      }
      None => false
    }
  let (port_pad_below, port_pad_above) =
    if has_clusters || !has_port_edges {
    (0.0, 0.0)
  } else {
    record_port_padding_y(edges, positions, label_ports_map)
  }
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if enable_complex_tuning {
    for edge in edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      let head_port = port_key(edge.head_port())
      let key =
        if head_port == "" {
        if is_record_shape(edge.head()) { head_name } else { "" }
      } else {
        "\{head_name}:\{head_port}"
      }
      if key == "" {
        continue
      }
      let tail_pos = match positions.get(tail_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let head_pos = match positions.get(head_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let tail_size = match sizes.get(tail_name) {
        Some(value) => value
        None => node_size(edge.tail(), record_orientation)
      }
      let head_size = match sizes.get(head_name) {
        Some(value) => value
        None => node_size(edge.head(), record_orientation)
      }
      let (tail_anchor, _) = port_geometry(
        tail_name,
        edge.tail_port(),
        label_ports_map,
        tail_pos,
        tail_size,
      )
      let (head_anchor, _) = port_geometry(
        head_name,
        edge.head_port(),
        label_ports_map,
        head_pos,
        head_size,
      )
      let dx = head_anchor.x - tail_anchor.x
      let dy = head_anchor.y - tail_anchor.y
      let dist = Double::sqrt(dx * dx + dy * dy)
      let current = match head_port_counts.get(key) {
        Some(value) => value
        None => 0
      }
      head_port_counts[key] = current + 1
      let mut min_dist = match head_port_min_dist.get(key) {
        Some(value) => value
        None => dist
      }
      let mut max_dist = match head_port_max_dist.get(key) {
        Some(value) => value
        None => dist
      }
      if dist < min_dist {
        min_dist = dist
      }
      if dist > max_dist {
        max_dist = dist
      }
      head_port_min_dist[key] = min_dist
      head_port_max_dist[key] = max_dist
    }
  }
  let path_order_index = build_order_index(x_groups)
  let path_adjacency =
    @routesplines.build_path_adjacency(edges, vnode_info.edge_vnodes)
  let pathplan_sizes =
    apply_self_edge_right_space(
      nodes,
      edges,
      sizes,
      rankdir,
      record_orientation,
    )
  let path_cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    path_cluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let path_vnode_clusters : Map[String, String] = Map::new()
  for edge in edges {
    let key = edge_vnode_key(edge)
    let vnodes = match vnode_info.edge_vnodes.get(key) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail_cluster = node_local_cluster_key(edge.tail())
    let head_cluster = node_local_cluster_key(edge.head())
    for vnode in vnodes {
      let pos = match vnode_positions.get(vnode) {
        Some(value) => value
        None => continue
      }
      let mut vnode_cluster = ""
      if tail_cluster != "" {
        match cluster_bboxes.get(tail_cluster) {
          Some(rect) =>
            if pos.x >= rect.llx && pos.x <= rect.urx &&
              pos.y >= rect.lly && pos.y <= rect.ury {
              vnode_cluster = tail_cluster
            }
          None => ()
        }
      }
      if vnode_cluster == "" && head_cluster != "" {
        match cluster_bboxes.get(head_cluster) {
          Some(rect) =>
            if pos.x >= rect.llx && pos.x <= rect.urx &&
              pos.y >= rect.lly && pos.y <= rect.ury {
              vnode_cluster = head_cluster
            }
          None => ()
        }
      }
      path_vnode_clusters[vnode] = vnode_cluster
    }
  }
  let parallel_offsets =
    edge_parallel_offsets(edges, ranks, order_index, nodesep_pt)
  let edges_out : Array[DotLayoutEdge] = []
  dot_trace("layout_dot: routing edges")
  for edge in edges {
    let parallel_offset = match parallel_offsets.get(edge.id()) {
      Some(value) => value
      None => 0.0
    }
    let orig_tail_name = edge.tail().name()
    let orig_head_name = edge.head().name()
    let swap_ends = edge_swap_ends(orig_tail_name, orig_head_name, ranks, order_index)
    let (tail_name, head_name, tail_port, head_port, tail_node, head_node) =
      if swap_ends {
        (orig_head_name, orig_tail_name, edge.head_port(), edge.tail_port(), edge.head(), edge.tail())
      } else {
        (orig_tail_name, orig_head_name, edge.tail_port(), edge.head_port(), edge.tail(), edge.head())
      }
    let tail_pos = match positions.get(tail_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let head_pos = match positions.get(head_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let tail_size = match sizes.get(tail_name) {
      Some(value) => value
      None => node_size(tail_node, record_orientation)
    }
    let head_size = match sizes.get(head_name) {
      Some(value) => value
      None => node_size(head_node, record_orientation)
    }
    let (raw_tail_anchor, raw_tail_anchor_size) = port_geometry(
      tail_name,
      tail_port,
      label_ports_map,
      tail_pos,
      tail_size,
    )
    let (raw_head_anchor, raw_head_anchor_size) = port_geometry(
      head_name,
      head_port,
      label_ports_map,
      head_pos,
      head_size,
    )
    let tail_port_rect = port_rect_from_geometry(
      tail_port,
      raw_tail_anchor,
      raw_tail_anchor_size,
      tail_size,
    )
    let head_port_rect = port_rect_from_geometry(
      head_port,
      raw_head_anchor,
      raw_head_anchor_size,
      head_size,
    )
    let tail_port_sides = match tail_port_rect {
      Some(rect) => port_side_count(rect, tail_pos, tail_size)
      None => 0
    }
    let head_port_sides = match head_port_rect {
      Some(rect) => port_side_count(rect, head_pos, head_size)
      None => 0
    }
    let force_segmented = tail_port_sides >= 3 || head_port_sides >= 3
    let tail_anchor_size = raw_tail_anchor_size
    let head_anchor_size = raw_head_anchor_size
    let tail_cluster_name = match edge.get_attr("ltail") {
      Some(value) => value
      None => ""
    }
    let head_cluster_name = match edge.get_attr("lhead") {
      Some(value) => value
      None => ""
    }
    let tail_rank = match ranks.get(tail_name) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head_name) {
      Some(value) => value
      None => 0
    }
    let is_flat_edge = tail_rank == head_rank
    let has_cluster = tail_cluster_name != "" || head_cluster_name != ""
    let vnodes = match vnode_info.edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    let has_vnodes = vnodes.length() > 0
    let use_pathplan = match @sys.get_env_var("DOT_USE_PATHPLAN") {
      Some(value) => {
        let lower = value.to_lower()
        lower != "0" && lower != "false" && lower != "no"
      }
      None => true
    }
    let allow_offset =
      !is_flat_edge &&
      !has_cluster &&
      !port_is_explicit(tail_port) &&
      !port_is_explicit(head_port) &&
      !use_pathplan
    let (tail_offset, head_offset) = if allow_offset {
      (
        layout_port_offset(point(0.0, -1.0), layout_rankdir),
        layout_port_offset(point(0.0, 1.0), layout_rankdir),
      )
    } else {
      (point(0.0, 0.0), point(0.0, 0.0))
    }
    let tail_cluster_bbox : @geom.Rect? =
      if tail_cluster_name == "" {
      None
    } else {
      cluster_bboxes.get(tail_cluster_name)
    }
    let head_cluster_bbox : @geom.Rect? =
      if head_cluster_name == "" {
      None
    } else {
      cluster_bboxes.get(head_cluster_name)
    }
    let (tail_side_anchor, tail_dynamic_side, tail_dynamic) =
      dynamic_port_anchor_for_edge(
        tail_port,
        tail_name,
        label_ports_raw,
        tail_pos,
        head_pos,
        layout_rankdir,
        "tail",
      )
    let (head_side_anchor, head_dynamic_side, head_dynamic) =
      dynamic_port_anchor_for_edge(
        head_port,
        head_name,
        label_ports_raw,
        head_pos,
        tail_pos,
        layout_rankdir,
        "head",
      )
    let tail_anchor_base = match tail_side_anchor {
      Some(pos) => pos
      None => raw_tail_anchor
    }
    let head_anchor_base = match head_side_anchor {
      Some(pos) => pos
      None => raw_head_anchor
    }
    let tail_port_side =
      if tail_dynamic {
      tail_dynamic_side
    } else {
      port_side_for_edge(
        tail_port,
        tail_port_rect,
        tail_pos,
        tail_size,
        None,
      )
    }
    let head_port_side =
      if head_dynamic {
      head_dynamic_side
    } else {
      port_side_for_edge(
        head_port,
        head_port_rect,
        head_pos,
        head_size,
        None,
      )
    }
    let tail_anchor = point_add(tail_anchor_base, tail_offset)
    let head_anchor = point_add(head_anchor_base, head_offset)
    let tail_clip_center = raw_tail_anchor
    let tail_clip_size = tail_anchor_size
    let head_clip_center = raw_head_anchor
    let head_clip_size = head_anchor_size
    let tail_target = match tail_port_rect {
      Some(_) => head_pos
      None => head_anchor
    }
    let head_target = match head_port_rect {
      Some(_) => tail_pos
      None => tail_anchor
    }
    let tail_slope = endpoint_slope_for_anchor(
      tail_port,
      tail_anchor,
      tail_pos,
      tail_size,
      tail_target,
      layout_rankdir,
      true,
      tail_port_rect,
    )
    let head_slope = endpoint_slope_for_anchor(
      head_port,
      head_anchor,
      head_pos,
      head_size,
      head_target,
      layout_rankdir,
      false,
      head_port_rect,
    )
    let tail_clip_target =
      if port_is_explicit(tail_port) &&
        (tail_slope.x != 0.0 || tail_slope.y != 0.0) {
        point_add(tail_clip_center, tail_slope)
      } else {
        head_anchor
      }
    let head_clip_target =
      if port_is_explicit(head_port) &&
        (head_slope.x != 0.0 || head_slope.y != 0.0) {
        point_add(head_clip_center, head_slope)
      } else {
        tail_anchor
      }
    let tail_clip = match tail_cluster_bbox {
      Some(rect) => clip_to_bbox(tail_anchor, rect, head_anchor)
      None =>
        match tail_side_anchor {
          Some(pos) => pos
          None => clip_to_rect(tail_clip_center, tail_clip_size, tail_clip_target)
        }
    }
    let head_clip = match head_cluster_bbox {
      Some(rect) => clip_to_bbox(head_anchor, rect, tail_anchor)
      None =>
        match head_side_anchor {
          Some(pos) => pos
          None => clip_to_rect(head_clip_center, head_clip_size, head_clip_target)
        }
    }
    let out_tail_anchor = if swap_ends { head_anchor } else { tail_anchor }
    let out_head_anchor = if swap_ends { tail_anchor } else { head_anchor }
    let out_tail_clip = if swap_ends { head_clip } else { tail_clip }
    let out_head_clip = if swap_ends { tail_clip } else { head_clip }
    let out_tail_pos = match positions.get(orig_tail_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let out_head_pos = match positions.get(orig_head_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let out_tail_size = match sizes.get(orig_tail_name) {
      Some(value) => value
      None => node_size(edge.tail(), record_orientation)
    }
    let out_head_size = match sizes.get(orig_head_name) {
      Some(value) => value
      None => node_size(edge.head(), record_orientation)
    }
    let dir = edge_dir_for(edge, graph.kind())
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => true
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => true
      _ => false
    }
    let (route_include_tail, route_include_head) =
      if swap_ends { (include_head, include_tail) } else { (include_tail, include_head) }
    let arrow_len_override : Double? =
      if include_tail || include_head {
      if tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_) {
        let base = arrow_length_for_edge(edge)
        let span = point_dist(tail_clip, head_clip)
        let max_len = span * 0.25
        if max_len > 0.0 && max_len < base {
          Some(max_len)
        } else {
          None
        }
      } else {
        None
      }
    } else {
      None
    }
    let style_value = if enable_complex_tuning {
      match edge.get_attr("style") {
        Some(value) => value.to_lower()
        None => ""
      }
    } else {
      ""
    }
    let is_dotted = enable_complex_tuning && style_value.contains("dotted")
    let same_outer_cluster =
      node_cluster_key(tail_node) == node_cluster_key(head_node)
    let diff_local_cluster =
      node_local_cluster_key(tail_node) != node_local_cluster_key(head_node)
    let same_local_cluster = !diff_local_cluster
    let mut label_pad_boost = 0.0
    let mut using_pathplan = false
    let mut pathplan_boxes : Array[@geom.Rect] = []
    let mut pathplan_points : Array[@geom.Point] = []
    let mut raw_bezier : Array[@geom.Point] = []
    let mut apply_dotted_adjustment = false
    let mut spline = match splines {
      SplinesMode::None | SplinesMode::Polyline =>
        edge_spline_for_polyline(
          edge,
          tail_clip_center,
          head_clip_center,
          tail_clip_size,
          head_clip_size,
          tail_clip,
          head_clip,
          layout_rankdir,
          false,
          route_include_tail,
          route_include_head,
          arrow_len_override=arrow_len_override,
          tail_cluster_bbox=tail_cluster_bbox,
          head_cluster_bbox=head_cluster_bbox,
          parallel_offset=parallel_offset,
        )
      SplinesMode::Ortho =>
        edge_spline_for_polyline(
          edge,
          tail_clip_center,
          head_clip_center,
          tail_clip_size,
          head_clip_size,
          tail_clip,
          head_clip,
          layout_rankdir,
          true,
          route_include_tail,
          route_include_head,
          arrow_len_override=arrow_len_override,
          tail_cluster_bbox=tail_cluster_bbox,
          head_cluster_bbox=head_cluster_bbox,
          parallel_offset=parallel_offset,
        )
      _ => {
        let label_width_pt = edge_mid_label_width_pt(edge)
        let has_explicit_port =
          port_is_explicit(tail_port) || port_is_explicit(head_port)
        let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
        let split_label = enable_complex_tuning &&
          label_width_pt > 0.0 &&
          same_outer_cluster &&
          diff_local_cluster &&
          abs_dx > label_width_pt
        if split_label {
          label_pad_boost = nodesep_pt * 1.2
        }
        let dotted_weight = if enable_complex_tuning { 1.0 } else { 0.8 }
        let guide_points = edge_polyline_points(
          edge,
          tail_name,
          head_name,
          tail_port,
          head_port,
          tail_anchor,
          head_anchor,
          ranks,
          vnode_info.edge_vnodes,
          vnode_info.vnode_ranks,
          vnode_positions,
          rank_y,
          rank_ht1,
          nodesep_pt,
          label_width_pt,
          dotted_weight,
          enable_complex_tuning,
          split_label,
          same_local_cluster,
        )
        let use_pathplan = use_pathplan
        let mut route_barriers : Array[(@geom.Point, @geom.Point)] = []
        let (points, pathplan_used) =
          if use_pathplan && !is_flat_edge {
          match @routesplines.edge_pathplan_polyline(
            edge,
            tail_name,
            head_name,
            tail_anchor,
            head_anchor,
            layout_rankdir,
            tail_port_side,
            head_port_side,
            ranksep_pt,
            ranks,
            vnode_info.vnode_ranks,
            vnode_info.edge_vnodes,
            positions,
            vnode_positions,
            pathplan_sizes,
            sizes,
            vnode_info.vnode_sizes,
            path_cluster_keys,
            path_vnode_clusters,
            cluster_bboxes,
            x_groups,
            path_order_index,
            path_adjacency.out_edges,
            path_adjacency.in_edges,
            rank_y,
            rank_ht1,
            rank_ht2,
            nodesep_pt,
          ) {
            Some((path_points, barriers, path_boxes)) => {
              route_barriers = barriers
              pathplan_boxes = path_boxes
              pathplan_points = path_points.copy()
              (path_points, true)
            }
            None => (guide_points, false)
          }
        } else {
          (
            guide_points,
            false,
          )
        }
        using_pathplan = pathplan_used
        let mut points = points
        let touch_eps = max_double(RECORD_BORDER_PT + 0.01, 1.5)
        let head_lr_touch =
          match head_port_rect {
            Some(rect) => {
              let node_rect = port_side_rect(head_pos, head_size)
              Double::abs(rect.llx - node_rect.llx) <= touch_eps ||
                Double::abs(rect.urx - node_rect.urx) <= touch_eps
            }
            None => false
          }
        let head_tb_touch =
          match head_port_rect {
            Some(rect) => {
              let node_rect = port_side_rect(head_pos, head_size)
              Double::abs(rect.lly - node_rect.lly) <= touch_eps ||
                Double::abs(rect.ury - node_rect.ury) <= touch_eps
            }
            None => false
          }
        let detour_ok =
          match layout_rankdir {
            RankDir::TB | RankDir::BT => head_tb_touch && !head_lr_touch
            RankDir::LR | RankDir::RL => head_lr_touch && !head_tb_touch
          }
        if points.length() <= 2 && has_explicit_port && detour_ok {
          let tail_rect = port_side_rect(tail_pos, tail_size)
          let head_rect = port_side_rect(head_pos, head_size)
          let anchor_eps = 0.02
          let needs_detour =
            segment_intersects_rect(
              tail_anchor,
              head_anchor,
              head_rect,
              anchor_eps,
            )
          if needs_detour {
            points =
              detour_polyline_for_rects(
                tail_anchor,
                head_anchor,
                tail_rect,
                head_rect,
                nodesep_pt,
                layout_rankdir,
              )
          }
        }
        if is_dotted && !same_outer_cluster && !using_pathplan {
          points = adjust_intercluster_dotted_points(
            points,
            tail_anchor,
            head_anchor,
            head_anchor_size,
            nodesep_pt,
          )
        }
        dot_trace_route_points(edge, points)
        let has_side_anchor =
          tail_side_anchor is Some(_) || head_side_anchor is Some(_)
        if has_explicit_port && has_side_anchor && points.length() <= 2 {
          let offset = max_double(4.0, nodesep_pt * 0.5)
          let kinked : Array[@geom.Point] = [tail_anchor]
          if tail_slope.x != 0.0 || tail_slope.y != 0.0 {
            kinked.push(point_add(tail_anchor, point_scale(tail_slope, offset)))
          }
          if head_slope.x != 0.0 || head_slope.y != 0.0 {
            kinked.push(point_add(head_anchor, point_scale(head_slope, -offset)))
          }
          kinked.push(head_anchor)
          points = kinked
        }
        let curve_offset_for = () => {
          let mut curve_offset = 0.0
          let mut curve_skew = 1.0
          if enable_complex_tuning {
            let head_port_key = port_key(edge.head_port())
            let key =
              if head_port_key == "" {
              if is_record_shape(edge.head()) { orig_head_name } else { "" }
            } else {
              "\{orig_head_name}:\{head_port_key}"
            }
            if key != "" {
              let count = match head_port_counts.get(key) {
                Some(value) => value
                None => 0
              }
              if count > 1 {
                let dx = head_anchor.x - tail_anchor.x
                let dy = head_anchor.y - tail_anchor.y
                let dist = Double::sqrt(dx * dx + dy * dy)
                let min_dist = match head_port_min_dist.get(key) {
                  Some(value) => value
                  None => dist
                }
                let max_dist = match head_port_max_dist.get(key) {
                  Some(value) => value
                  None => dist
                }
                let span = max_dist - min_dist
                if span > 0.0 {
                  let t = (dist - min_dist) / span
                  let label_factor = if label_width_pt > 0.0 { 1.0 } else { 0.5 }
                  let port_scale = if head_port_key == "" { 0.6 } else { 0.6 }
                  curve_offset = nodesep_pt * t * t * label_factor * port_scale
                  if head_port_key != "" {
                    match rankdir {
                      RankDir::TB | RankDir::BT =>
                        if dx < 0.0 {
                          curve_skew = 0.5
                        }
                      RankDir::LR | RankDir::RL =>
                        if dy < 0.0 {
                          curve_skew = 0.5
                        }
                    }
                  }
                }
              }
            }
          }
          (curve_offset, curve_skew)
        }
        let (curve_offset, curve_skew) = curve_offset_for()
        let routed_spline = if points.length() > 2 {
          let clipped = points
          let simplify_tol = nodesep_pt * 0.8
          let tail_label_edges = match label_edge_counts.get(orig_tail_name) {
            Some(value) => value > 1
            None => false
          }
        let keep_label_kink =
          label_width_pt > 0.0 &&
          (has_explicit_port ||
            (same_outer_cluster &&
                (abs_dx < nodesep_pt || (tail_label_edges && abs_dx < label_width_pt))))
          let simplified =
            if using_pathplan {
              clipped
            } else if enable_complex_tuning &&
              has_vnodes &&
              !split_label &&
              !keep_label_kink {
              simplify_polyline(clipped, simplify_tol)
            } else {
              clipped
            }
          let adjusted =
            if !using_pathplan && is_dotted && same_outer_cluster {
              adjust_intracluster_dotted_points(simplified)
            } else {
              simplified
            }
          if adjusted.length() <= 2 {
            let tail_slope_line =
              if port_is_explicit(tail_port) {
                tail_slope
              } else {
                point(0.0, 0.0)
              }
            let head_slope_line =
              if port_is_explicit(head_port) {
                head_slope
              } else {
                point(0.0, 0.0)
              }
            let record_port_edge =
              (is_record_shape(tail_node) && port_is_explicit(tail_port)) ||
                (is_record_shape(head_node) && port_is_explicit(head_port))
            let needs_record_detour =
              !is_flat_edge &&
              record_port_edge &&
              (match layout_rankdir {
                RankDir::TB | RankDir::BT =>
                  Double::abs(tail_slope_line.x) > 0.01 ||
                    Double::abs(head_slope_line.x) > 0.01
                RankDir::LR | RankDir::RL =>
                  Double::abs(tail_slope_line.y) > 0.01 ||
                    Double::abs(head_slope_line.y) > 0.01
              })
            if needs_record_detour {
              let tail_rect = port_side_rect(tail_clip_center, tail_clip_size)
              let head_rect = port_side_rect(head_clip_center, head_clip_size)
              let detour_offset = nodesep_pt * 0.5
              let detour_points =
                match layout_rankdir {
                  RankDir::TB | RankDir::BT => {
                    let mut side = tail_clip.x - tail_clip_center.x
                    if Double::abs(side) <= 0.01 {
                      side = head_clip.x - head_clip_center.x
                    }
                    if Double::abs(side) <= 0.01 {
                      side = head_clip.x - tail_clip.x
                    }
                    let detour_x =
                      if side < 0.0 {
                        min_double(tail_rect.llx, head_rect.llx) - detour_offset
                      } else {
                        max_double(tail_rect.urx, head_rect.urx) + detour_offset
                      }
                    [
                      tail_clip,
                      point(detour_x, tail_clip.y),
                      point(detour_x, head_clip.y),
                      head_clip,
                    ]
                  }
                  RankDir::LR | RankDir::RL => {
                    let mut side = tail_clip.y - tail_clip_center.y
                    if Double::abs(side) <= 0.01 {
                      side = head_clip.y - head_clip_center.y
                    }
                    if Double::abs(side) <= 0.01 {
                      side = head_clip.y - tail_clip.y
                    }
                    let detour_y =
                      if side < 0.0 {
                        min_double(tail_rect.lly, head_rect.lly) - detour_offset
                      } else {
                        max_double(tail_rect.ury, head_rect.ury) + detour_offset
                      }
                    [
                      tail_clip,
                      point(tail_clip.x, detour_y),
                    point(head_clip.x, detour_y),
                    head_clip,
                  ]
                }
              }
              if using_pathplan {
                raw_bezier =
                  edge_spline_raw_for_points(
                    detour_points,
                    tail_slope_line,
                    head_slope_line,
                    true,
                    route_barriers=route_barriers,
                  )
              }
              edge_spline_for_points(
                edge,
                detour_points,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                true,
                route_include_tail,
                route_include_head,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
              )
            } else {
              if using_pathplan {
                let line_points = adjusted
                raw_bezier =
                  edge_spline_raw_for_points(
                    line_points,
                    tail_slope_line,
                    head_slope_line,
                    force_segmented,
                    route_barriers=route_barriers,
                  )
                edge_spline_for_points(
                  edge,
                  line_points,
                  tail_clip_center,
                  head_clip_center,
                  tail_clip_size,
                  head_clip_size,
                  tail_slope_line,
                  head_slope_line,
                  force_segmented,
                  route_include_tail,
                  route_include_head,
                  route_barriers=route_barriers,
                  arrow_len_override=arrow_len_override,
                  tail_cluster_bbox=tail_cluster_bbox,
                  head_cluster_bbox=head_cluster_bbox,
                  parallel_offset=parallel_offset,
                )
              } else {
                edge_spline_for_line(
                  edge,
                  adjusted[0],
                  adjusted[adjusted.length() - 1],
                  tail_clip_center,
                  head_clip_center,
                  tail_clip_size,
                  head_clip_size,
                  tail_slope_line,
                  head_slope_line,
                  route_include_tail,
                  route_include_head,
                  layout_rankdir,
                  curve_offset,
                  curve_skew,
                  arrow_len_override=arrow_len_override,
                  tail_cluster_bbox=tail_cluster_bbox,
                  head_cluster_bbox=head_cluster_bbox,
                  parallel_offset=parallel_offset,
                )
              }
            }
          } else {
            let tail_slope_for =
              if port_is_explicit(tail_port) {
                tail_slope
              } else {
                point(0.0, 0.0)
              }
          let head_slope_for =
            if port_is_explicit(head_port) {
              head_slope
            } else {
              point(0.0, 0.0)
            }
          let edge_force_segmented = force_segmented
          if using_pathplan {
            raw_bezier =
              edge_spline_raw_for_points(
                adjusted,
                tail_slope_for,
                head_slope_for,
                edge_force_segmented,
                route_barriers=route_barriers,
              )
          }
          let spline =
            edge_spline_for_points(
              edge,
              adjusted,
              tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_for,
                head_slope_for,
                edge_force_segmented,
                route_include_tail,
                route_include_head,
                route_barriers=route_barriers,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
              )
          apply_dotted_adjustment = true
          spline
          }
        } else {
          let tail_slope_line =
            if port_is_explicit(tail_port) {
              tail_slope
            } else {
              point(0.0, 0.0)
            }
          let head_slope_line =
            if port_is_explicit(head_port) {
              head_slope
            } else {
              point(0.0, 0.0)
            }
          let record_port_edge =
            (is_record_shape(tail_node) && port_is_explicit(tail_port)) ||
              (is_record_shape(head_node) && port_is_explicit(head_port))
          let needs_record_detour =
            !is_flat_edge &&
            record_port_edge &&
            (match layout_rankdir {
              RankDir::TB | RankDir::BT =>
                Double::abs(tail_slope_line.x) > 0.01 ||
                  Double::abs(head_slope_line.x) > 0.01
              RankDir::LR | RankDir::RL =>
                Double::abs(tail_slope_line.y) > 0.01 ||
                  Double::abs(head_slope_line.y) > 0.01
            })
          if needs_record_detour {
            let tail_rect = port_side_rect(tail_clip_center, tail_clip_size)
            let head_rect = port_side_rect(head_clip_center, head_clip_size)
            let detour_offset = nodesep_pt * 0.5
            let detour_points =
              match layout_rankdir {
                RankDir::TB | RankDir::BT => {
                  let mut side = tail_clip.x - tail_clip_center.x
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.x - head_clip_center.x
                  }
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.x - tail_clip.x
                  }
                  let detour_x =
                    if side < 0.0 {
                      min_double(tail_rect.llx, head_rect.llx) - detour_offset
                    } else {
                      max_double(tail_rect.urx, head_rect.urx) + detour_offset
                    }
                  [
                    tail_clip,
                    point(detour_x, tail_clip.y),
                    point(detour_x, head_clip.y),
                    head_clip,
                  ]
                }
                RankDir::LR | RankDir::RL => {
                  let mut side = tail_clip.y - tail_clip_center.y
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.y - head_clip_center.y
                  }
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.y - tail_clip.y
                  }
                  let detour_y =
                    if side < 0.0 {
                      min_double(tail_rect.lly, head_rect.lly) - detour_offset
                    } else {
                      max_double(tail_rect.ury, head_rect.ury) + detour_offset
                    }
                  [
                    tail_clip,
                    point(tail_clip.x, detour_y),
                  point(head_clip.x, detour_y),
                  head_clip,
                ]
              }
            }
            if using_pathplan {
              raw_bezier =
                edge_spline_raw_for_points(
                  detour_points,
                  tail_slope_line,
                  head_slope_line,
                  true,
                  route_barriers=route_barriers,
                )
            }
            edge_spline_for_points(
              edge,
              detour_points,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              true,
              route_include_tail,
              route_include_head,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
            )
          } else {
            let line_start =
              if using_pathplan && points.length() >= 2 {
                points[0]
              } else {
                tail_anchor
              }
            let line_end =
              if using_pathplan && points.length() >= 2 {
                points[points.length() - 1]
              } else {
                head_anchor
              }
            if using_pathplan {
              let line_points : Array[@geom.Point] =
                if points.length() >= 2 { points } else { [line_start, line_end] }
              raw_bezier =
                edge_spline_raw_for_points(
                  line_points,
                  tail_slope_line,
                  head_slope_line,
                  force_segmented,
                  route_barriers=route_barriers,
                )
              edge_spline_for_points(
                edge,
                line_points,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                force_segmented,
                route_include_tail,
                route_include_head,
                route_barriers=route_barriers,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
              )
            } else {
              edge_spline_for_line(
                edge,
                line_start,
                line_end,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                route_include_tail,
                route_include_head,
                layout_rankdir,
                curve_offset,
                curve_skew,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
              )
            }
          }
        }
        routed_spline
      }
    }
    if swap_ends {
      spline = reverse_spline(spline)
    }
    if apply_dotted_adjustment && is_dotted && !same_outer_cluster &&
      spline.points.length() > 1 {
      let tuned = spline.points.copy()
      let tail_bias = 0.7
      tuned[1] = {
        x: tuned[1].x,
        y: tuned[1].y * (1.0 - tail_bias) + out_tail_anchor.y * tail_bias,
      }
      let head_bias = 0.7
      let last = tuned.length() - 2
      tuned[last] = {
        x: tuned[last].x,
        y: tuned[last].y * (1.0 - head_bias) + out_head_anchor.y * head_bias,
      }
      spline = { start: spline.start, end: spline.end, points: tuned }
    }
    if using_pathplan &&
      pathplan_boxes.length() > 0 &&
      raw_bezier.length() >= 4 {
      let limited_boxes =
        @routesplines.limit_boxes_for_spline(
          pathplan_boxes,
          raw_bezier,
          fallback_polyline=pathplan_points,
        )
      let ordered_vnodes =
        if tail_rank <= head_rank {
        vnodes.copy()
      } else {
        let reversed : Array[String] = []
        let mut idx = vnodes.length()
        while idx > 0 {
          idx = idx - 1
          reversed.push(vnodes[idx])
        }
        reversed
      }
      if @sys.get_env_var("DOT_TRACE_SLACK") is Some(_) &&
        edge.tail().name() == "foo_agent" &&
        edge.head().name() == "zzz_worker" {
        println(
          "slack edge front_end_jz -> tunnel_ingress raw_bezier=\{raw_bezier.length()} boxes=\{limited_boxes.length()}",
        )
        let mut bi = 0
        for box in limited_boxes {
          println(
            "  box[\{bi}] llx=\{box.llx} lly=\{box.lly} urx=\{box.urx} ury=\{box.ury}",
          )
          bi = bi + 1
        }
        for vnode in ordered_vnodes {
          let vnode_rank = match vnode_info.vnode_ranks.get(vnode) {
            Some(value) => value
            None => continue
          }
          let vnode_y = match rank_y.get(vnode_rank) {
            Some(value) => value
            None => continue
          }
          let size = match vnode_info.vnode_sizes.get(vnode) {
            Some(value) => value
            None => continue
          }
          let is_label = size.height_pt > 0.0
          println(
            "  vnode=\{vnode} rank=\{vnode_rank} y=\{vnode_y} label=\{is_label}",
          )
        }
      }
      recover_slack_vnodes(
        edge,
        ordered_vnodes,
        limited_boxes,
        ranks,
        vnode_info.vnode_ranks,
        rank_y,
        vnode_positions,
        vnode_info.vnode_sizes,
        path_adjacency,
      )
    }
    let label_rank_info = edge_label_rank_info(edge, ranks)
    let label_rank_y = edge_label_rank_y(edge, ranks, rank_y)
    let label_rank_x = match label_rank_info {
      Some((label_rank, span)) =>
        if span > 1 {
          edge_label_rank_x(
            edge,
            label_rank,
            vnode_info.vnode_ranks,
            vnode_info.edge_vnodes,
            vnode_positions,
          )
        } else {
          None
        }
      None => None
    }
    if @sys.get_env_var("DOT_TRACE_SLACK") is Some(_) &&
      edge.tail().name() == "foo_agent" &&
      edge.head().name() == "zzz_worker" {
      let (rank_label, span) = match label_rank_info {
        Some(value) => value
        None => (-1, 0)
      }
      let rank_x_text = match label_rank_x {
        Some(value) => "\{value}"
        None => "None"
      }
      let rank_y_text = match label_rank_y {
        Some(value) => "\{value}"
        None => "None"
      }
      println(
        "label_rank=\{rank_label} span=\{span} label_rank_x=\{rank_x_text} label_rank_y=\{rank_y_text}",
      )
    }
    let apply_label_pad = has_clusters
    let label_pos : @geom.Point? = match edge.get_attr("label") {
      Some(value) =>
        if value == "" {
          None
        } else {
          match (label_rank_x, label_rank_y, edge_mid_label_metrics(edge)) {
            (Some(rank_x), Some(rank_y), Some((width, height))) => {
              Some(
                edge_label_pos_from_vnode(
                  point(rank_x, rank_y),
                  width,
                  height,
                  layout_rankdir,
                ),
              )
            }
            _ =>
              if is_flat_edge {
                match flat_label_edge_vnodes.get(edge_key(edge)) {
                  Some(vnode_name) =>
                    match vnode_positions.get(vnode_name) {
                      Some(pos) => Some(pos)
                      None =>
                        match edge_mid_label_metrics(edge) {
                          Some((_width, height)) => {
                          Some(
                            flat_edge_label_pos_simple(
                                out_tail_pos,
                                out_head_pos,
                                out_tail_size.right_pt,
                                out_head_size.left_pt,
                                height,
                              ),
                            )
                          }
                          None =>
                            edge_label_pos(
                              edge,
                              spline,
                              out_tail_clip,
                              out_head_clip,
                              layout_rankdir,
                              label_rank_y,
                              label_rank_x,
                              apply_label_pad,
                              nodesep_pt,
                              label_pad_boost,
                            )
                        }
                    }
                  None =>
                    match edge_mid_label_metrics(edge) {
                      Some((_width, height)) => {
                        Some(
                          flat_edge_label_pos_simple(
                            out_tail_pos,
                            out_head_pos,
                            out_tail_size.right_pt,
                            out_head_size.left_pt,
                            height,
                          ),
                        )
                      }
                      None =>
                        edge_label_pos(
                          edge,
                          spline,
                          out_tail_clip,
                          out_head_clip,
                          layout_rankdir,
                          label_rank_y,
                          label_rank_x,
                          apply_label_pad,
                          nodesep_pt,
                          label_pad_boost,
                        )
                    }
                }
              } else {
                edge_label_pos(
                  edge,
                  spline,
                  out_tail_clip,
                  out_head_clip,
                  layout_rankdir,
                  label_rank_y,
                  label_rank_x,
                  apply_label_pad,
                  nodesep_pt,
                  label_pad_boost,
                )
              }
          }
        }
      None => None
    }
    let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
      Some(value) =>
        if value == "" {
          None
        } else {
          edge_port_label_pos(edge, spline, true)
        }
      None => None
    }
    let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
      Some(value) =>
        if value == "" {
          None
        } else {
          edge_port_label_pos(edge, spline, false)
        }
      None => None
    }
  edges_out.push({
      edge,
      splines: [spline],
      label_pos,
      head_label_pos,
      tail_label_pos,
    })
  }
  dot_trace("layout_dot: edges routed")
  let base_bbox = compute_bbox(nodes_out, edges_out)
  let (final_nodes, final_edges, bbox) = if rankdir == RankDir::TB {
    (nodes_out, edges_out, base_bbox)
  } else {
    transform_layout(nodes_out, edges_out, base_bbox, rankdir)
  }
  let subgraphs = layout_subgraphs(graph, final_nodes, final_edges)
  let mut final_bbox = if subgraphs.length() > 0 {
    expand_bbox_with_subgraphs(bbox, subgraphs)
  } else {
    bbox
  }
  let (root_cluster_pad_top, root_cluster_pad_bottom) =
    if graph.is_root() && graph_has_cluster(graph) && all_ranks.length() > 0 {
    let min_rank = all_ranks[0]
    let max_rank = all_ranks[all_ranks.length() - 1]
    let mut cluster_at_min = false
    let mut cluster_at_max = false
    for node in nodes {
      let cluster_key = node_local_cluster_key(node)
      if cluster_key == "" {
        continue
      }
      match ranks.get(node.name()) {
        Some(rank) => {
          if rank == min_rank {
            cluster_at_min = true
          }
          if rank == max_rank {
            cluster_at_max = true
          }
        }
        None => ()
      }
      if cluster_at_min && cluster_at_max {
        break
      }
    }
    let pad = cluster_margin_pt(graph)
    (
      if cluster_at_min { pad } else { 0.0 },
      if cluster_at_max { pad } else { 0.0 },
    )
  } else {
    (0.0, 0.0)
  }
  if graph.is_root() && (rankdir == RankDir::TB || rankdir == RankDir::BT) {
    if port_pad_below > 0.0 || port_pad_above > 0.0 {
      final_bbox = {
        llx: final_bbox.llx,
        lly: final_bbox.lly - port_pad_below,
        urx: final_bbox.urx,
        ury: final_bbox.ury + port_pad_above,
      }
    }
  }
  let mut label_pos : @geom.Point? = None
  if graph.is_root() {
    match graph_label_metrics(graph) {
      Some((width_pt, height_pt)) => {
        let loc = graph_label_loc(graph)
        let just = graph_label_just(graph)
        let pad = CLUSTER_LABEL_PAD_PT
        let padded_width = width_pt + pad * 2.0
        let padded_height = height_pt + pad
        final_bbox = expand_bbox_for_label(final_bbox, width_pt, height_pt, loc)
        label_pos = Some(
          graph_label_pos(final_bbox, padded_width, padded_height, loc, just),
        )
      }
      None => ()
    }
  }
  if graph.is_root() {
    let margin_x = if graph_has_cluster(graph) {
      graph_margin_x_pt(graph)
    } else {
      0.0
    }
    if margin_x > 0.0 {
      final_bbox = {
        llx: final_bbox.llx - margin_x,
        lly: final_bbox.lly,
        urx: final_bbox.urx + margin_x,
        ury: final_bbox.ury,
      }
    }
  }
  let layout = {
    graph,
    bbox: final_bbox,
    label_pos,
    nodes: final_nodes,
    edges: final_edges,
    subgraphs,
  }
  let adjusted =
    if edge_label_adjust_enabled() {
      let adjusted_for_clusters =
        adjust_edge_labels_for_cluster_labels(layout, nodesep_pt)
      adjust_edge_labels_for_label_overlaps(
        adjusted_for_clusters,
        nodesep_pt,
        rankdir,
      )
    } else {
      layout
    }
  if graph.is_root() {
    let dx = -adjusted.bbox.llx
    let dy = -adjusted.bbox.lly
    let shifted =
      if dx != 0.0 || dy != 0.0 {
      shift_layout_graph(adjusted, dx, dy)
    } else {
      adjusted
    }
    if root_cluster_pad_top > 0.0 || root_cluster_pad_bottom > 0.0 {
      let padded = shift_layout_graph(shifted, 0.0, root_cluster_pad_bottom)
      let padded_bbox : @geom.Rect = {
        llx: shifted.bbox.llx,
        lly: shifted.bbox.lly,
        urx: shifted.bbox.urx,
        ury: shifted.bbox.ury + root_cluster_pad_bottom + root_cluster_pad_top,
      }
      let label_pos = match graph_label_metrics(graph) {
        Some((width_pt, height_pt)) => {
          let loc = graph_label_loc(graph)
          let just = graph_label_just(graph)
          let pad = CLUSTER_LABEL_PAD_PT
          let padded_width = width_pt + pad * 2.0
          let padded_height = height_pt + pad
          Some(
            graph_label_pos(padded_bbox, padded_width, padded_height, loc, just),
          )
        }
        None => padded.label_pos
      }
      {
        graph: padded.graph,
        bbox: padded_bbox,
        label_pos,
        nodes: padded.nodes,
        edges: padded.edges,
        subgraphs: padded.subgraphs,
      }
    } else {
      shifted
    }
  } else {
    adjusted
  }
}

///|
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  let mut write_bb = self.graph.is_root()
  if !write_bb {
    match self.graph.name() {
      Some(name) => if name.has_prefix("cluster") { write_bb = true }
      None => ()
    }
  }
  let record_orientation =
    record_layout_orientation(graph_rankdir(self.graph))
  if write_bb {
    self.graph.set_attr("bb", format_rect(self.bbox))
  }
  match self.label_pos {
    Some(pos) => self.graph.set_attr("lp", format_point(pos))
    None => ()
  }
  for node_layout in self.nodes {
    let node = node_layout.node
    node.set_attr("pos", format_point(node_layout.pos))
    node.set_attr("width", format_dim(node_layout.width_in))
    node.set_attr("height", format_dim(node_layout.height_in))
    if is_record_shape(node) && !@html_label.is_html_label_text(label_text(node)) {
      let size = node_size_from_points(
        node_layout.width_in * 72.0,
        node_layout.height_in * 72.0,
      )
      let rects = record_rects(
        node,
        node_layout.pos,
        size,
        record_orientation,
      )
      if rects.length() > 0 {
        node.set_attr("rects", format_rects(rects))
      }
    }
    match node_layout.label_pos {
      Some(pos) => node.set_attr("lp", format_point(pos))
      None => ()
    }
  }
  for edge_layout in self.edges {
    let edge = edge_layout.edge
    let dir = edge_dir_for(edge, self.graph.kind())
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => true
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => true
      _ => false
    }
    let segments : Array[String] = []
    for spline in edge_layout.splines {
      let parts : Array[String] = []
      if include_tail {
        match spline.start {
          Some(point) => parts.push("s,\{format_point(point)}")
          None => ()
        }
      }
      if include_head {
        match spline.end {
          Some(point) => parts.push("e,\{format_point(point)}")
          None => ()
        }
      }
      for point in spline.points {
        parts.push(format_point(point))
      }
      segments.push(parts.join(" "))
    }
    let pos = segments.join(";")
    edge.set_attr("pos", pos)
    match edge_layout.label_pos {
      Some(pos) => edge.set_attr("lp", format_point(pos))
      None => ()
    }
    match edge_layout.head_label_pos {
      Some(pos) => edge.set_attr("head_lp", format_point(pos))
      None => ()
    }
    match edge_layout.tail_label_pos {
      Some(pos) => edge.set_attr("tail_lp", format_point(pos))
      None => ()
    }
  }
  for subgraph in self.subgraphs {
    subgraph.apply()
  }
}
