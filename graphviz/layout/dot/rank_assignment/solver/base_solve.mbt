// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
priv struct MergedRankEdge {
  tail_idx : Int
  head_idx : Int
  minlen : Int
  weight : Int
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/rank.c + common/ns.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_ranks_directed_base(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Map[String, Int] {
  let node_by_name : Map[String, @cgraph.Node] = Map([])
  let tail_order : Array[String] = []
  let node_order_index : Map[String, Int] = Map([])
  for node in nodes {
    let name = node.name()
    node_by_name[name] = node
    node_order_index[name] = tail_order.length()
    tail_order.push(name)
  }
  let head_order_by_edge : Array[Int] = []
  for edge_idx in 0..<edges.length() {
    let head_name = if edge_idx < edge_head.length() {
      edge_head[edge_idx]
    } else {
      ""
    }
    head_order_by_edge.push(node_order_index.get(head_name).unwrap_or_default())
  }
  let edges_by_tail : Map[String, Array[Int]] = Map([])
  for edge_idx in 0..<edges.length() {
    let tail = edge_tail[edge_idx]
    match edges_by_tail.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edges_by_tail[tail] = [edge_idx]
    }
  }
  for _tail, indices in edges_by_tail {
    if indices.length() > 1 {
      indices.sort_by((a, b) => {
        let idx_a = head_order_by_edge[a]
        let idx_b = head_order_by_edge[b]
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
  let edge_creation : Array[(String, String)] = []
  let original_edges_by_tail : Map[String, Array[@cgraph.Edge]] = Map([])
  for edge in edges {
    guard @edge_semantics.edge_is_constraint(edge) else { continue }
    let tail = edge.tail().name()
    if original_edges_by_tail.get(tail) is Some(list) {
      list.push(edge)
    } else {
      original_edges_by_tail[tail] = [edge]
    }
  }
  for tail in tail_order {
    let original_edges = original_edges_by_tail.get(tail).unwrap_or_default()
    original_edges.sort_by((a, b) => {
      let a_order = node_order_index.get(a.head().name()).unwrap_or_default()
      let b_order = node_order_index.get(b.head().name()).unwrap_or_default()
      a_order.compare(b_order)
    })
    // rank.c decomposes before acyclic reverses the fast edges.
    for edge in original_edges {
      edge_creation.push((tail, edge.head().name()))
    }
  }
  // Graphviz parity: decompose ordering uses DFS over flat/in/out neighbors
  // driven by agfstnode/agfstout ordering.
  let rank_node_names = @rank_constraints.build_graphviz_nlist_order_from_edges(
    tail_order,
    tail_order,
    edge_creation,
    Map([]),
  )
  let rank_nodes : Array[@cgraph.Node] = []
  let seen : Map[String, Bool] = Map([])
  for name in rank_node_names {
    match node_by_name.get(name) {
      Some(node) => {
        rank_nodes.push(node)
        seen[name] = true
      }
      None => ()
    }
  }
  if rank_nodes.length() < nodes.length() {
    for node in nodes {
      let name = node.name()
      if seen.get(name) is None {
        rank_nodes.push(node)
        seen[name] = true
      }
    }
  }
  let rank_same_reps = @rank_constraints.build_rank_same_reps(source, nodes)
  let rep_index : Map[String, Int] = Map([])
  let rep_order : Array[String] = []
  let index : Map[String, Int] = Map([])
  let mut has_rank_same_groups = false
  for node in rank_nodes {
    let name = node.name()
    let rep = match rank_same_reps.get(name) {
      Some(value) => value
      None => name
    }
    if rep != name {
      has_rank_same_groups = true
    }
    let idx = match rep_index.get(rep) {
      Some(value) => value
      None => {
        let value = rep_order.length()
        rep_order.push(rep)
        rep_index[rep] = value
        value
      }
    }
    index[name] = idx
  }
  let merged_edges : Map[String, MergedRankEdge] = Map([])
  let merged_edge_order : Array[String] = []
  for tail_name in rank_node_names {
    let indices = match edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for edge_idx in indices {
      let edge = edges[edge_idx]
      if !@edge_semantics.edge_is_constraint(edge) {
        continue
      }
      let tail = edge_tail[edge_idx]
      let head = edge_head[edge_idx]
      // Graphviz parity: ignore self edges in rank constraints (compile_edges Xt==Xh).
      if tail == head {
        continue
      }
      let tail_idx = match index.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_idx = match index.get(head) {
        Some(value) => value
        None => 0
      }
      if tail_idx == head_idx {
        continue
      }
      let minlen_value = @edge_semantics.edge_minlen(edge)
      let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
      let weight = @edge_semantics.edge_weight(edge)
      let key = "\{tail_idx}:\{head_idx}"
      match merged_edges.get(key) {
        Some(entry) => {
          let next_minlen = if minlen > entry.minlen {
            minlen
          } else {
            entry.minlen
          }
          merged_edges[key] = {
            tail_idx,
            head_idx,
            minlen: next_minlen,
            weight: entry.weight + weight,
          }
        }
        None => {
          merged_edges[key] = { tail_idx, head_idx, minlen, weight, }
          merged_edge_order.push(key)
        }
      }
    }
  }
  let adjacency : Array[Array[Int]] = []
  for _ in 0..<rep_order.length() {
    adjacency.push([])
  }
  let components : Array[Array[Int]] = []
  if has_rank_same_groups {
    let component : Array[Int] = []
    let collapsed_edges : Array[(String, String)] = []
    let seen_edges : Map[String, Bool] = Map([])
    // decompose visits the fast graph after rank-set representatives merge.
    for tail in tail_order {
      for edge_idx in edges_by_tail.get(tail).unwrap_or_default() {
        guard @edge_semantics.edge_is_constraint(edges[edge_idx]) else {
          continue
        }
        let head = edge_head[edge_idx]
        let tail = rank_same_reps.get(tail).unwrap_or(tail)
        let head = rank_same_reps.get(head).unwrap_or(head)
        let key = "\{tail}|\{head}"
        guard tail != head && seen_edges.get(key) is None else { continue }
        seen_edges[key] = true
        collapsed_edges.push((tail, head))
      }
    }
    let collapsed_order = @rank_constraints.build_graphviz_nlist_order_from_edges(
      rep_order,
      rep_order,
      collapsed_edges,
      {},
    )
    for name in collapsed_order {
      component.push(rep_index[name])
    }
    components.push(component)
  } else {
    for key in merged_edge_order {
      let entry = match merged_edges.get(key) {
        Some(value) => value
        None => continue
      }
      if entry.tail_idx >= 0 &&
        entry.tail_idx < adjacency.length() &&
        entry.head_idx >= 0 &&
        entry.head_idx < adjacency.length() {
        adjacency[entry.tail_idx].push(entry.head_idx)
        adjacency[entry.head_idx].push(entry.tail_idx)
      }
    }
    let visited : Array[Bool] = []
    for _ in 0..<rep_order.length() {
      visited.push(false)
    }
    for start in 0..<rep_order.length() {
      if visited[start] {
        continue
      }
      visited[start] = true
      let stack : Array[Int] = [start]
      let component : Array[Int] = []
      while stack.length() > 0 {
        let top = stack.length() - 1
        let idx = stack[top]
        let _ = stack.pop()
        component.push(idx)
        for other in adjacency[idx] {
          if other >= 0 && other < visited.length() && !visited[other] {
            visited[other] = true
            stack.push(other)
          }
        }
      }
      component.sort_by((a, b) => if a < b { -1 } else if a > b { 1 } else { 0 })
      components.push(component)
    }
  }
  let rep_ranks : Map[String, Int] = Map([])
  // Graphviz parity: rank1 runs network simplex per connected component
  // (refs/graphviz/lib/dotgen/rank.c), and each component is normalized
  // independently before readout.
  for component in components {
    let graph = @network_simplex.new_graph()
    let local_index : Map[Int, Int] = Map([])
    for rep_idx in component {
      let rep_name = rep_order[rep_idx]
      local_index[rep_idx] = @network_simplex.add_node(graph, rep_name)
    }
    for key in merged_edge_order {
      let entry = match merged_edges.get(key) {
        Some(value) => value
        None => continue
      }
      let tail_local = match local_index.get(entry.tail_idx) {
        Some(value) => value
        None => continue
      }
      let head_local = match local_index.get(entry.head_idx) {
        Some(value) => value
        None => continue
      }
      let _ = @network_simplex.add_edge(
        graph,
        tail_local,
        head_local,
        entry.minlen,
        entry.weight,
      )
    }
    @network_simplex.network_simplex(
      graph,
      0x7fffffff,
      @network_simplex.BalanceMode::TB,
    )
    let mut component_min_rank = 0
    let mut component_seen = false
    for rep_idx in component {
      let local_idx = match local_index.get(rep_idx) {
        Some(value) => value
        None => continue
      }
      let rank = @network_simplex.node_rank(graph, local_idx)
      if !component_seen {
        component_min_rank = rank
        component_seen = true
      } else if rank < component_min_rank {
        component_min_rank = rank
      }
    }
    for rep_idx in component {
      let local_idx = match local_index.get(rep_idx) {
        Some(value) => value
        None => continue
      }
      let rep_name = rep_order[rep_idx]
      rep_ranks[rep_name] = @network_simplex.node_rank(graph, local_idx) -
        component_min_rank
    }
  }
  let default_rank = if rep_order.length() > 0 {
    rep_ranks.get(rep_order[0]).unwrap_or_default()
  } else {
    0
  }
  let rank_for_name = (name : String) => {
    let rep = match rank_same_reps.get(name) {
      Some(value) => value
      None => name
    }
    match rep_ranks.get(rep) {
      Some(value) => value
      None => default_rank
    }
  }
  let ranks : Map[String, Int] = Map([])
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let rank = rank_for_name(node.name())
    if !seen {
      min_rank = rank
      seen = true
    } else if rank < min_rank {
      min_rank = rank
    }
  }
  for node in nodes {
    let name = node.name()
    ranks[name] = rank_for_name(name) - min_rank
  }
  let min_nodes : Map[String, Bool] = Map([])
  let max_nodes : Map[String, Bool] = Map([])
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}
