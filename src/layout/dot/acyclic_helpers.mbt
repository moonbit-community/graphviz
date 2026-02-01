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
