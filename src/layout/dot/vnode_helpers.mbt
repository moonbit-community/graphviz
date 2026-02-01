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
fn is_edge_vnode_name(name : String) -> Bool {
  name.has_prefix(EDGE_VNODE_PREFIX)
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
