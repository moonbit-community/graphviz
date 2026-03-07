///|
/// Rank domain: acyclic edge-direction preprocessing helpers.

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
fn edge_pair_key(tail : String, head : String) -> String {
  "\{tail}|\{head}"
}

///|
fn edge_pair_lookup(
  edge_by_pair : Map[String, Int],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_active : Array[Bool],
  key : String,
) -> Int? {
  match edge_by_pair.get(key) {
    Some(idx) =>
      if idx >= 0 && idx < edge_tail.length() &&
        idx < edge_head.length() &&
        idx < edge_active.length() &&
        edge_active[idx] &&
        edge_pair_key(edge_tail[idx], edge_head[idx]) == key {
        Some(idx)
      } else {
        None
      }
    None => None
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
/// Graphviz parity: acyclic DFS operates on fast-graph edges (class1/fastgr),
/// merging parallel edges and reverse-edge merge_oneway behavior.
/// Do not change behavior without updating fixtures/tests.
fn acyclic_dfs_fast(
  idx : Int,
  rep_index : Map[String, Int],
  out_edges : Array[Array[Int]],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_members : Array[Array[Int]],
  edge_active : Array[Bool],
  edge_by_pair : Map[String, Int],
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
    if edge_idx < 0 || edge_idx >= edge_active.length() || !edge_active[edge_idx] {
      stack[top_idx] = (node_idx, edge_pos + 1)
      continue
    }
    let head_name = edge_head[edge_idx]
    let head_idx = match rep_index.get(head_name) {
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
      let old_tail = edge_tail[edge_idx]
      let old_head = edge_head[edge_idx]
      // Reverse and apply to all merged members.
      let member_indices = edge_members[edge_idx]
      for edge_member_idx in member_indices {
        if edge_member_idx >= 0 && edge_member_idx < edge_reversed.length() {
          edge_reversed[edge_member_idx] = !edge_reversed[edge_member_idx]
        }
      }
      remove_edge_at(out_edges[node_idx], edge_pos)
      let reverse_key = edge_pair_key(old_head, old_tail)
      match edge_pair_lookup(
        edge_by_pair,
        edge_tail,
        edge_head,
        edge_active,
        reverse_key,
      ) {
        Some(existing_idx) => {
          // Merge into existing opposite edge (merge_oneway).
          edge_active[edge_idx] = false
          let existing_members = edge_members[existing_idx]
          for edge_member_idx in member_indices {
            existing_members.push(edge_member_idx)
          }
          edge_members[edge_idx] = []
          continue
        }
        None => {
          edge_tail[edge_idx] = old_head
          edge_head[edge_idx] = old_tail
          edge_by_pair[reverse_key] = edge_idx
          out_edges[head_idx].push(edge_idx)
          continue
        }
      }
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

pub struct AcyclicDirectionsWithOrder {
  tail : Array[String]
  head : Array[String]
  reversed : Array[Bool]
  out_edges : Array[Array[Int]]
  in_edges : Array[Array[Int]]
}

///|
pub fn acyclic_edge_directions_with_order(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> AcyclicDirectionsWithOrder {
  let _ = graph
  let node_index : Map[String, Int] = Map::new()
  let node_names : Array[String] = []
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    node_index[name] = i
    node_names.push(name)
  }
  let rank_same_reps = @shared.build_rank_same_reps(graph, nodes)
  let rep_names : Array[String] = []
  let rep_seen : Map[String, Bool] = Map::new()
  for name in node_names {
    let rep = match rank_same_reps.get(name) {
      Some(value) => value
      None => name
    }
    if rep_seen.get(rep) is None {
      rep_seen[rep] = true
      rep_names.push(rep)
    }
  }
  let edge_tail_orig : Array[String] = []
  let edge_head_orig : Array[String] = []
  let edge_reversed : Array[Bool] = []
  let edge_is_active : Array[Bool] = []
  let out_edges_all_orig : Array[Array[Int]] = []
  let in_edges_all_orig : Array[Array[Int]] = []
  for _ in 0..<nodes.length() {
    out_edges_all_orig.push([])
    in_edges_all_orig.push([])
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    edge_tail_orig.push(tail)
    edge_head_orig.push(head)
    edge_reversed.push(false)
    let active = @edge_semantics.edge_is_constraint(edge)
    edge_is_active.push(active)
    let edge_idx = edge_tail_orig.length() - 1
    match node_index.get(tail) {
      Some(idx) => {
        out_edges_all_orig[idx].push(edge_idx)
      }
      None => ()
    }
    match node_index.get(head) {
      Some(idx) => {
        in_edges_all_orig[idx].push(edge_idx)
      }
      None => ()
    }
  }
  // Graphviz parity: agfstout/agnxtout order edges by head node AGSEQ
  // (creation order), then edge AGSEQ; agfstin/agnxtin orders by tail
  // node AGSEQ, then edge AGSEQ (cgraph agedgeseqcmpf).
  // Do not change behavior without updating fixtures/tests.
  let sort_out_list = (list : Array[Int]) => {
    if list.length() > 1 {
      list.sort_by((a, b) => {
        let head_a = edge_head_orig[a]
        let head_b = edge_head_orig[b]
        let idx_a = match node_index.get(head_a) {
          Some(value) => value
          None => 0
        }
        let idx_b = match node_index.get(head_b) {
          Some(value) => value
          None => 0
        }
        if idx_a < idx_b {
          -1
        } else if idx_a > idx_b {
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
  let sort_in_list = (list : Array[Int]) => {
    if list.length() > 1 {
      list.sort_by((a, b) => {
        let tail_a = edge_tail_orig[a]
        let tail_b = edge_tail_orig[b]
        let idx_a = match node_index.get(tail_a) {
          Some(value) => value
          None => 0
        }
        let idx_b = match node_index.get(tail_b) {
          Some(value) => value
          None => 0
        }
        if idx_a < idx_b {
          -1
        } else if idx_a > idx_b {
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
  for i in 0..<out_edges_all_orig.length() {
    sort_out_list(out_edges_all_orig[i])
    sort_in_list(in_edges_all_orig[i])
  }
  // Build fast-graph edges (unique directed pairs) in agfstout order.
  let rep_index : Map[String, Int] = Map::new()
  for i in 0..<rep_names.length() {
    rep_index[rep_names[i]] = i
  }
  let fast_edge_tail : Array[String] = []
  let fast_edge_head : Array[String] = []
  let fast_edge_members : Array[Array[Int]] = []
  let fast_edge_active : Array[Bool] = []
  let fast_edge_by_pair : Map[String, Int] = Map::new()
  let fast_out_edges : Array[Array[Int]] = []
  for _ in 0..<rep_names.length() {
    fast_out_edges.push([])
  }
  for tail_idx in 0..<node_names.length() {
    let edge_list = out_edges_all_orig[tail_idx]
    for edge_idx in edge_list {
      if edge_idx < 0 || edge_idx >= edge_is_active.length() {
        continue
      }
      if !edge_is_active[edge_idx] {
        continue
      }
      let tail = edge_tail_orig[edge_idx]
      let head = edge_head_orig[edge_idx]
      let tail_rep = match rank_same_reps.get(tail) {
        Some(value) => value
        None => tail
      }
      let head_rep = match rank_same_reps.get(head) {
        Some(value) => value
        None => head
      }
      if tail_rep == head_rep {
        continue
      }
      let key = edge_pair_key(tail_rep, head_rep)
      match fast_edge_by_pair.get(key) {
        Some(existing) => {
          fast_edge_members[existing].push(edge_idx)
        }
        None => {
          let id = fast_edge_tail.length()
          fast_edge_tail.push(tail_rep)
          fast_edge_head.push(head_rep)
          fast_edge_members.push([edge_idx])
          fast_edge_active.push(true)
          fast_edge_by_pair[key] = id
          match rep_index.get(tail_rep) {
            Some(rep_idx) => fast_out_edges[rep_idx].push(id)
            None => ()
          }
        }
      }
    }
  }
  // Graphviz parity: acyclic traverses nodes in GD_nlist order from decompose,
  // which is based on rank-same representatives and fast-graph edges.
  let edge_creation : Array[(String, String)] = []
  for edge_idx in 0..<fast_edge_tail.length() {
    let tail_rep = fast_edge_tail[edge_idx]
    let head_rep = fast_edge_head[edge_idx]
    edge_creation.push((tail_rep, head_rep))
  }
  let acyclic_order = @shared.build_graphviz_nlist_order_from_edges(
    rep_names,
    rep_names,
    edge_creation,
    Map::new(),
  )
  let marked : Array[Bool] = []
  let onstack : Array[Bool] = []
  for _ in 0..<rep_names.length() {
    marked.push(false)
    onstack.push(false)
  }
  for name in acyclic_order {
    match rep_index.get(name) {
      Some(i) =>
        if !marked[i] {
        acyclic_dfs_fast(
          i,
          rep_index,
          fast_out_edges,
          fast_edge_tail,
          fast_edge_head,
          fast_edge_members,
          fast_edge_active,
          fast_edge_by_pair,
          edge_reversed,
          marked,
          onstack,
        )
      }
      None => ()
    }
  }
  let edge_tail_out = edge_tail_orig.copy()
  let edge_head_out = edge_head_orig.copy()
  for i in 0..<edge_reversed.length() {
    if edge_reversed[i] {
      let tmp = edge_tail_out[i]
      edge_tail_out[i] = edge_head_out[i]
      edge_head_out[i] = tmp
    }
  }
  // Graphviz parity: class2 processes edges in original tail order
  // (agfstout on cgraph), independent of acyclic reversals.
  {
    tail: edge_tail_out,
    head: edge_head_out,
    reversed: edge_reversed,
    out_edges: out_edges_all_orig,
    in_edges: in_edges_all_orig,
  }
}

///|
pub struct AcyclicNameDirections {
  tail : Array[String]
  head : Array[String]
  reversed : Array[Bool]
}

///|
pub fn acyclic_edge_directions_for_names(
  node_names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_is_active : Array[Bool],
) -> AcyclicNameDirections {
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
  { tail, head, reversed: edge_reversed }
}
