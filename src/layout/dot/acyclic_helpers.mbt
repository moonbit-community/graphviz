///|
///|
/// Graphviz parity: adjacency removal uses zapinlist (swap with last), not stable delete.
fn remove_edge_at(list : Array[Int], idx : Int) -> Unit {
  let last = list.length() - 1
  if idx < 0 || idx > last {
    return ()
  }
  if idx != last {
    list[idx] = list[last]
  }
  let _ = list.pop()
}

///|
fn remove_edge_value(list : Array[Int], value : Int) -> Unit {
  let mut i = 0
  while i < list.length() {
    if list[i] == value {
      remove_edge_at(list, i)
      return ()
    }
    i = i + 1
  }
}

///|
fn acyclic_dfs(
  idx : Int,
  node_index : Map[String, Int],
  out_edges : Array[Array[Int]],
  out_edges_all : Array[Array[Int]],
  in_edges_all : Array[Array[Int]],
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
      remove_edge_value(out_edges_all[node_idx], edge_idx)
      out_edges_all[head_idx].push(edge_idx)
      remove_edge_value(in_edges_all[head_idx], edge_idx)
      in_edges_all[node_idx].push(edge_idx)
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
  let (edge_tail, edge_head, edge_reversed, _out_edges, _in_edges) =
    acyclic_edge_directions_with_order(nodes, edges)
  (edge_tail, edge_head, edge_reversed)
}

///|
fn acyclic_edge_directions_with_order(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (
  Array[String],
  Array[String],
  Array[Bool],
  Array[Array[Int]],
  Array[Array[Int]],
) {
  let node_index : Map[String, Int] = Map::new()
  for i in 0..<nodes.length() {
    node_index[nodes[i].name()] = i
  }
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_reversed : Array[Bool] = []
  let edge_is_active : Array[Bool] = []
  let out_edges : Array[Array[Int]] = []
  let out_edges_all : Array[Array[Int]] = []
  let in_edges_all : Array[Array[Int]] = []
  for _ in 0..<nodes.length() {
    out_edges.push([])
    out_edges_all.push([])
    in_edges_all.push([])
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    edge_tail.push(tail)
    edge_head.push(head)
    edge_reversed.push(false)
    let active = edge_is_constraint(edge)
    edge_is_active.push(active)
    let edge_idx = edge_tail.length() - 1
    match node_index.get(tail) {
      Some(idx) => {
        out_edges_all[idx].push(edge_idx)
        if active {
          out_edges[idx].push(edge_idx)
        }
      }
      None => ()
    }
    match node_index.get(head) {
      Some(idx) => {
        in_edges_all[idx].push(edge_idx)
      }
      None => ()
    }
  }
  // Graphviz parity: agfstout/agnxtout order edges by head node sequence (AGSEQ),
  // and agfstin/agnxtin order by tail node sequence. Use node creation order.
  // Do not change behavior without updating fixtures/tests.
  for i in 0..<nodes.length() {
    let out_list = out_edges_all[i]
    if out_list.length() > 1 {
      out_list.sort_by((a, b) => {
        let ha = edge_head[a]
        let hb = edge_head[b]
        let ha_idx = match node_index.get(ha) {
          Some(value) => value
          None => 0
        }
        let hb_idx = match node_index.get(hb) {
          Some(value) => value
          None => 0
        }
        if ha_idx < hb_idx {
          -1
        } else if ha_idx > hb_idx {
          1
        } else if a < b {
          -1
        } else if a > b {
          1
        } else {
          0
        }
      })
    }
    let in_list = in_edges_all[i]
    if in_list.length() > 1 {
      in_list.sort_by((a, b) => {
        let ta = edge_tail[a]
        let tb = edge_tail[b]
        let ta_idx = match node_index.get(ta) {
          Some(value) => value
          None => 0
        }
        let tb_idx = match node_index.get(tb) {
          Some(value) => value
          None => 0
        }
        if ta_idx < tb_idx {
          -1
        } else if ta_idx > tb_idx {
          1
        } else if a < b {
          -1
        } else if a > b {
          1
        } else {
          0
        }
      })
    }
    let active_list = out_edges[i]
    if active_list.length() > 1 {
      active_list.sort_by((a, b) => {
        let ha = edge_head[a]
        let hb = edge_head[b]
        let ha_idx = match node_index.get(ha) {
          Some(value) => value
          None => 0
        }
        let hb_idx = match node_index.get(hb) {
          Some(value) => value
          None => 0
        }
        if ha_idx < hb_idx {
          -1
        } else if ha_idx > hb_idx {
          1
        } else if a < b {
          -1
        } else if a > b {
          1
        } else {
          0
        }
      })
    }
  }
  let out_edges_all_orig : Array[Array[Int]] = []
  let in_edges_all_orig : Array[Array[Int]] = []
  for i in 0..<nodes.length() {
    out_edges_all_orig.push(out_edges_all[i].copy())
    in_edges_all_orig.push(in_edges_all[i].copy())
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
        out_edges_all,
        in_edges_all,
        edge_is_active,
        edge_tail,
        edge_head,
        edge_reversed,
        marked,
        onstack,
      )
    }
  }
  // Graphviz parity: class2 processes edges in original tail order
  // (agfstout on cgraph), independent of acyclic reversals.
  (edge_tail, edge_head, edge_reversed, out_edges_all_orig, in_edges_all_orig)
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
  let out_edges_all : Array[Array[Int]] = []
  let in_edges_all : Array[Array[Int]] = []
  for _ in 0..<node_names.length() {
    out_edges.push([])
    out_edges_all.push([])
    in_edges_all.push([])
  }
  for i in 0..<tail.length() {
    edge_reversed.push(false)
    match node_index.get(tail[i]) {
      Some(idx) => out_edges_all[idx].push(i)
      None => ()
    }
    match node_index.get(head[i]) {
      Some(idx) => in_edges_all[idx].push(i)
      None => ()
    }
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
        out_edges_all,
        in_edges_all,
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
