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
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  tail_name : String,
  head_name : String,
  xpenalty : Int,
  constraint : Bool,
  tail_port_x : Double,
  head_port_x : Double,
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
          edge_tail_port_x.push(tail_port_x)
          edge_head_port_x.push(head_port_x)
        }
        None => ()
      }
    None => ()
  }
}

///|
fn collect_edge_indices_by_tail(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
) -> Map[String, Array[Int]] {
  let out : Map[String, Array[Int]] = Map::new()
  for i in 0..<edges.length() {
    let tail =
      if i < edge_tail.length() { edge_tail[i] } else { edges[i].tail().name() }
    match out.get(tail) {
      Some(list) => list.push(i)
      None => out[tail] = [i]
    }
  }
  out
}

///|
/// Graphviz parity: GD_nlist order is reverse creation order in class2.
/// Do not change behavior without updating fixtures/tests.
fn build_graphviz_nlist_order(
  tail_order : Array[String],
  _cluster_keys : Map[String, String],
  cluster_skeleton_creation : Array[String],
  vnode_creation_by_tail : Map[String, Array[String]],
) -> Array[String] {
  let creation : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in cluster_skeleton_creation {
    if seen.get(name) is None {
      seen[name] = true
      creation.push(name)
    }
  }
  for tail_name in tail_order {
    if seen.get(tail_name) is None {
      seen[tail_name] = true
      creation.push(tail_name)
    }
    let vnodes = match vnode_creation_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for vnode in vnodes {
      if seen.get(vnode) is None {
        seen[vnode] = true
        creation.push(vnode)
      }
    }
  }
  // GD_nlist is reverse of creation order (fast_node inserts at head).
  let out : Array[String] = []
  let mut idx = creation.length()
  while idx > 0 {
    idx = idx - 1
    out.push(creation[idx])
  }
  out
}

///|
/// Graphviz parity: approximate decompose DFS order over fast graph edges.
/// Do not change behavior without updating fixtures/tests.
fn build_graphviz_nlist_order_from_edges(
  tail_order : Array[String],
  order_nodes : Array[String],
  edge_creation : Array[(String, String)],
  flat_constraints : Map[String, Bool],
) -> Array[String] {
  let out_neighbors : Map[String, Array[String]] = Map::new()
  let in_neighbors : Map[String, Array[String]] = Map::new()
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    out_neighbors[name] = []
    in_neighbors[name] = []
    flat_out[name] = []
    flat_in[name] = []
  }
  for edge in edge_creation {
    let (tail, head) = edge
    match out_neighbors.get(tail) {
      Some(list) => list.push(head)
      None => out_neighbors[tail] = [head]
    }
    match in_neighbors.get(head) {
      Some(list) => list.push(tail)
      None => in_neighbors[head] = [tail]
    }
  }
  for key, _ in flat_constraints {
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
        match flat_out.get(tail) {
          Some(list) => list.push(head)
          None => flat_out[tail] = [head]
        }
        match flat_in.get(head) {
          Some(list) => list.push(tail)
          None => flat_in[head] = [tail]
        }
      }
      None => ()
    }
  }
  let visited : Map[String, Bool] = Map::new()
  for name in order_nodes {
    visited[name] = false
  }
  let nlist : Array[String] = []
  let stack : Array[String] = []
  let push_neighbors = (list : Array[String]) => {
    let mut idx = list.length()
    while idx > 0 {
      idx = idx - 1
      let other = list[idx]
      if visited.get(other) != Some(true) {
        stack.push(other)
      }
    }
  }
  for start in tail_order {
    if visited.get(start) == Some(true) {
      continue
    }
    stack.push(start)
    while stack.length() > 0 {
      let current = stack[stack.length() - 1]
      let _ = stack.pop()
      if visited.get(current) == Some(true) {
        continue
      }
      visited[current] = true
      nlist.push(current)
      let fin = match flat_in.get(current) {
        Some(list) => list
        None => []
      }
      let fout = match flat_out.get(current) {
        Some(list) => list
        None => []
      }
      let inn = match in_neighbors.get(current) {
        Some(list) => list
        None => []
      }
      let out = match out_neighbors.get(current) {
        Some(list) => list
        None => []
      }
      push_neighbors(fin)
      push_neighbors(fout)
      push_neighbors(inn)
      push_neighbors(out)
    }
  }
  if nlist.length() < order_nodes.length() {
    for name in order_nodes {
      if visited.get(name) != Some(true) {
        nlist.push(name)
        visited[name] = true
      }
    }
  }
  nlist
}

///|
/// Graphviz parity: build order-graph edges in class2 tail/edge iteration order.
/// Do not change behavior without updating fixtures/tests.
fn build_order_edges_by_tail_graphviz(
  tail_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  map_clusters : Bool,
  map_intercluster : Bool,
  edges_by_tail : Map[String, Array[Int]],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  let out : Map[String, Array[(String, String, Int, Bool, Double, Double)]] =
    Map::new()
  let vnode_seen : Map[String, Bool] = Map::new()
  let vnode_creation_by_tail : Map[String, Array[String]] = Map::new()
  let edge_creation : Array[(String, String)] = []
  let use_mapping = order_with_clusters && map_clusters
  for tail_name in tail_order {
    let created_for_tail : Array[String] = []
    let indices = match edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for idx in indices {
      let edge = edges[idx]
      let tail =
        if idx < edge_tail.length() { edge_tail[idx] } else { edge.tail().name() }
      let head =
        if idx < edge_head.length() { edge_head[idx] } else { edge.head().name() }
      let tail_cluster =
        if order_with_clusters {
        match cluster_keys.get(tail) {
          Some(value) => value
          None => ""
        }
      } else {
        ""
      }
      let head_cluster =
        if order_with_clusters {
        match cluster_keys.get(head) {
          Some(value) => value
          None => ""
        }
      } else {
        ""
      }
      if use_mapping && tail_cluster != "" && tail_cluster == head_cluster {
        continue
      }
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
      // Graphviz parity: intercluster edges map to cluster rankleaders
      // in ordering (class2/interclrep).
      let intercluster =
        order_with_clusters && tail_cluster != head_cluster &&
        (tail_cluster != "" || head_cluster != "")
      let map_edge = use_mapping || (map_intercluster && intercluster)
      let mapped_tail =
        if map_edge && tail_cluster != "" {
        "\{CLUSTER_SKELETON_PREFIX}\{tail_cluster}@\{tail_rank}"
      } else {
        tail
      }
      let mapped_head =
        if map_edge && head_cluster != "" {
        "\{CLUSTER_SKELETON_PREFIX}\{head_cluster}@\{head_rank}"
      } else {
        head
      }
      let penalty = edge_xpenalty(edge)
      let constraint = edge_is_constraint(edge)
      let tail_port_x =
        if idx < edge_tail_port_x.length() { edge_tail_port_x[idx] } else {
          0.0
        }
      let head_port_x =
        if idx < edge_head_port_x.length() { edge_head_port_x[idx] } else {
          0.0
        }
      let vnodes =
        if order_with_vnodes {
        match edge_vnodes.get(edge_vnode_key(edge)) {
          Some(list) => list
          None => []
        }
      } else {
        []
      }
      if order_with_vnodes && vnodes.length() > 0 {
        for vnode in vnodes {
          if vnode_seen.get(vnode) is None {
            vnode_seen[vnode] = true
            created_for_tail.push(vnode)
          }
        }
      }
      let chain : Array[String] = []
      let (chain_tail, chain_head) =
        if tail_rank <= head_rank { (mapped_tail, mapped_head) } else {
          (mapped_head, mapped_tail)
        }
      chain.push(chain_tail)
      if order_with_vnodes && vnodes.length() > 0 {
        for vnode in vnodes {
          chain.push(vnode)
        }
      }
      chain.push(chain_head)
      let mut i = 0
      while i + 1 < chain.length() {
        let t = chain[i]
        let h = chain[i + 1]
        if t != h {
          let seg_tail_port =
            if t == tail && mapped_tail == tail {
              tail_port_x
            } else if t == head && mapped_head == head {
              head_port_x
            } else {
              0.0
            }
          let seg_head_port =
            if h == head && mapped_head == head {
              head_port_x
            } else if h == tail && mapped_tail == tail {
              tail_port_x
            } else {
              0.0
            }
          match out.get(t) {
            Some(list) =>
              list.push((t, h, penalty, constraint, seg_tail_port, seg_head_port))
            None =>
              out[t] = [(t, h, penalty, constraint, seg_tail_port, seg_head_port)]
          }
          edge_creation.push((t, h))
        }
        i = i + 1
      }
    }
    if created_for_tail.length() > 0 {
      vnode_creation_by_tail[tail_name] = created_for_tail
    }
  }
  (out, vnode_creation_by_tail, edge_creation)
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
