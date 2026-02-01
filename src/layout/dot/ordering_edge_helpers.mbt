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
