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
  let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  let tail_rank_opt = ranks.get(tail_name)
  let head_rank_opt = ranks.get(head_name)
  if vnodes.length() > 0 {
    match (tail_rank_opt, head_rank_opt) {
      (Some(tail_rank), Some(head_rank)) => {
        let span = head_rank - tail_rank
        if span == 0 {
          let push_flat_point = (name : String) => {
            match vnode_positions.get(name) {
              Some(pos) =>
                if label_width_pt > 0.0 {
                  let half = label_width_pt / 2.0
                  let bend_y =
                    match edge_mid_label_metrics(edge) {
                      Some(metrics) => {
                        let label_top = pos.y + metrics.height / 2.0
                        let source_y =
                          if tail_anchor.x <= head_anchor.x {
                            tail_anchor.y
                          } else {
                            head_anchor.y
                          }
                        let ydelta = (pos.y - source_y) / 6.0
                        let lift = if ydelta > 5.0 { ydelta } else { 5.0 }
                        label_top - lift
                      }
                      None => pos.y
                    }
                  if tail_anchor.x <= head_anchor.x {
                    points.push({ x: pos.x - half, y: bend_y })
                    points.push({ x: pos.x + half, y: bend_y })
                  } else {
                    points.push({ x: pos.x + half, y: bend_y })
                    points.push({ x: pos.x - half, y: bend_y })
                  }
                } else {
                  points.push(pos)
                }
              None => ()
            }
          }
          if tail_anchor.x <= head_anchor.x {
            for name in vnodes {
              push_flat_point(name)
            }
          } else {
            let mut idx = vnodes.length()
            while idx > 0 {
              idx = idx - 1
              let name = vnodes[idx]
              push_flat_point(name)
            }
          }
        } else {
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
            @dot_shared.port_is_explicit(tail_port) || @dot_shared.port_is_explicit(head_port)
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
/// Graphviz parity: parallel edge keys are unordered tail/head + port pairs.
/// Do not change behavior without updating fixtures/tests.
fn edge_parallel_key(
  tail : String,
  head : String,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
) -> String {
  let tail_port_key = @dot_shared.port_key(tail_port)
  let head_port_key = @dot_shared.port_key(head_port)
  let a = "\{tail}|\{tail_port_key}"
  let b = "\{head}|\{head_port_key}"
  if a <= b {
    "\{a}|\{b}"
  } else {
    "\{b}|\{a}"
  }
}

///|
fn edge_has_sameport_mark(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("samehead") {
    Some(value) => value != ""
    None =>
      match edge.get_attr("sametail") {
        Some(value) => value != ""
        None => false
      }
  }
}

///|
/// Graphviz parity: remap pass keeps sameport-tagged edges separate from plain
/// parallels while preserving class2 endpoint/port grouping.
/// Do not change behavior without updating fixtures/tests.
fn edge_parallel_group_key(edge : @cgraph.Edge) -> String {
  let base =
    edge_parallel_key(
      edge.tail().name(),
      edge.head().name(),
      edge.tail_port(),
      edge.head_port(),
    )
  let sameport_mark = edge_has_sameport_mark(edge)
  if sameport_mark {
    "\{base}|sameport"
  } else {
    "\{base}|plain"
  }
}

///|
/// Graphviz parity: parallel offsets group by unordered endpoints/ports (set of
/// tail/head), and only for unlabeled edges (class2 merge_chain).
/// Do not change behavior without updating fixtures/tests.
fn edge_parallel_offsets(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  _order_index : Map[String, Int],
  nodesep_pt : Double,
  edge_reversed_by_id : Map[Int, Bool],
  cluster_keys : Map[String, String],
) -> Map[Int, Double] {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_dir_attr : Map[String, String] = Map::new()
  let group_has_mixed_dir_attr : Map[String, Bool] = Map::new()
  let sameport_marked : Map[Int, Bool] = Map::new()
  let edge_by_id : Map[Int, @cgraph.Edge] = Map::new()
  let has_self_edge : Map[String, Bool] = Map::new()
  for edge in edges {
    edge_by_id[edge.id()] = edge
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      has_self_edge[tail] = true
    }
  }
  for edge in edges {
    if edge_has_label(edge) {
      continue
    }
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
    let key =
      edge_parallel_key(
        orig_tail,
        orig_head,
        edge.tail_port(),
        edge.head_port(),
      )
    let dir_attr = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
    let mark = edge_has_sameport_mark(edge)
    sameport_marked[edge.id()] = mark
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_dir_attr.get(key) {
      Some(first_dir) =>
        if first_dir != dir_attr {
          group_has_mixed_dir_attr[key] = true
        }
      None => {
        group_first_dir_attr[key] = dir_attr
        group_has_mixed_dir_attr[key] = false
      }
    }
  }
  let offsets : Map[Int, Double] = Map::new()
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    ids.sort_by((a, b) => {
      let a_mark = match sameport_marked.get(a) {
        Some(value) => if value { 1 } else { 0 }
        None => 0
      }
      let b_mark = match sameport_marked.get(b) {
        Some(value) => if value { 1 } else { 0 }
        None => 0
      }
      if a_mark != b_mark {
        b_mark - a_mark
      } else {
        a - b
      }
    })
    let mixed_dir = match group_has_mixed_dir_attr.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_dir {
      let mut left = 0
      let mut right = ids.length()
      while left + 1 < right {
        right = right - 1
        let tmp = ids[left]
        ids[left] = ids[right]
        ids[right] = tmp
        left = left + 1
      }
    }
    // Graphviz parity: for reverse-edge pairs, prefer the tail without a
    // self-loop first. This matches class2/dotsplines slot assignment on NaN.gv.
    if ids.length() == 2 {
      let edge0 = edge_by_id.get(ids[0])
      let edge1 = edge_by_id.get(ids[1])
      match (edge0, edge1) {
        (Some(a), Some(b)) => {
          let a_tail = a.tail().name()
          let a_head = a.head().name()
          let b_tail = b.tail().name()
          let b_head = b.head().name()
          if a_tail == b_head && a_head == b_tail {
            let a_tail_cluster = match cluster_keys.get(a_tail) {
              Some(value) => value
              None => ""
            }
            let a_head_cluster = match cluster_keys.get(a_head) {
              Some(value) => value
              None => ""
            }
            let intercluster =
              a_tail_cluster != a_head_cluster &&
              (a_tail_cluster != "" || a_head_cluster != "")
            let a_tail_has_self = match has_self_edge.get(a_tail) {
              Some(value) => value
              None => false
            }
            let b_tail_has_self = match has_self_edge.get(b_tail) {
              Some(value) => value
              None => false
            }
            // Graphviz parity: reverse-pair slot ordering applies to regular
            // intra-cluster pairs (rowe), but cluster-crossing pairs (clust2)
            // keep cluster-constrained ordering.
            if !intercluster && a_tail_has_self == b_tail_has_self {
              let a_reversed = match edge_reversed_by_id.get(ids[0]) {
                Some(value) => value
                None => false
              }
              let b_reversed = match edge_reversed_by_id.get(ids[1]) {
                Some(value) => value
                None => false
              }
              if !a_reversed && b_reversed {
                let tmp = ids[0]
                ids[0] = ids[1]
                ids[1] = tmp
              }
            }
            if a_tail_has_self && !b_tail_has_self {
              let tmp = ids[0]
              ids[0] = ids[1]
              ids[1] = tmp
            }
          }
        }
        _ => ()
      }
    }
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
fn adjust_intercluster_dots(
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
fn adjust_intracluster_dots(
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
