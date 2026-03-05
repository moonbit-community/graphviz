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
    let (tail, head) =
      @ordering.edge_endpoints_at(
        edge,
        edge_idx,
        edge_tail,
        edge_head,
      )
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
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
      if @dot_shared.is_edge_vnode_name(from) {
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
    if !is_flat && !@dot_shared.is_edge_vnode_name(name) {
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
