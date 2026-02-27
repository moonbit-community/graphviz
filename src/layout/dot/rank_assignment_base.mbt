///|
/// Graphviz parity: rank.c tb_balance uses qsort(rank-only), which can move
/// tie-equivalent chain nodes one rank further than stable ordering.
/// Keep this local post-pass scoped to rank assignment.
fn tb_tie_adjust_rank_assignment_graphviz(graph : NsGraph) -> Unit {
  let max_rank = normalize_ranks_for_test(graph)
  if max_rank <= 0 {
    return ()
  }
  let nrank : Array[Int] = []
  for _ in 0..<(max_rank + 1) {
    nrank.push(0)
  }
  for node in graph.nodes {
    if node.kind == NodeKind::Normal {
      let rank = node.rank
      if rank >= 0 && rank <= max_rank {
        nrank[rank] = nrank[rank] + 1
      }
    }
  }
  for idx in 0..<graph.nodes.length() {
    let node = graph.nodes[idx]
    if node.kind != NodeKind::Normal {
      continue
    }
    if node.in_edges.length() != 1 || node.out_edges.length() != 1 {
      continue
    }
    let in_edge = graph.edges[node.in_edges[0]]
    let out_edge = graph.edges[node.out_edges[0]]
    if in_edge.weight != out_edge.weight {
      continue
    }
    let mut low = graph.nodes[in_edge.tail].rank + in_edge.minlen
    let high = graph.nodes[out_edge.head].rank - out_edge.minlen
    let current = graph.nodes[idx].rank
    if low < 0 {
      low = 0
    }
    if current < 0 || current > max_rank || high < 0 || high > max_rank {
      continue
    }
    if low != current || high != current + 1 {
      continue
    }
    if nrank[high] == nrank[current] {
      nrank[current] = nrank[current] - 1
      nrank[high] = nrank[high] + 1
      graph.nodes[idx].rank = high
    }
  }
}

///|
/// Graphviz parity: clustered path branch selection happens before non-cluster
/// base rank assignment, matching rank.c control flow.
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
) -> Map[String, Int] {
  if rank_assignment_has_cluster(source) {
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
/// Graphviz parity: rank=min/max/source/sink extrema are collected from
/// subgraph attributes before final rank projection.
/// Do not change behavior without updating fixtures/tests.
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
/// Graphviz parity: collected rank extrema override projected ranks after
/// normalization, matching rank.c postprocessing.
/// Do not change behavior without updating fixtures/tests.
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
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/rank.c + common/ns.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_directed_base(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  _edge_reversed : Array[Bool],
) -> Map[String, Int] {
  let graph_name = match source.name() {
    Some(value) => value
    None => ""
  }
  let node_by_name : Map[String, @cgraph.Node] = Map::new()
  let tail_order : Array[String] = []
  let node_order_index : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    node_by_name[name] = node
    node_order_index[name] = tail_order.length()
    tail_order.push(name)
  }
  let edges_by_tail : Map[String, Array[Int]] = Map::new()
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
        let head_a =
          if a >= 0 && a < edge_head.length() { edge_head[a] } else { "" }
        let head_b =
          if b >= 0 && b < edge_head.length() { edge_head[b] } else { "" }
        let idx_a = match node_order_index.get(head_a) {
          Some(value) => value
          None => 0
        }
        let idx_b = match node_order_index.get(head_b) {
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
  let edge_creation : Array[(String, String)] = []
  for tail in tail_order {
    let indices = match edges_by_tail.get(tail) {
      Some(list) => list
      None => []
    }
    // Graphviz parity: agfstout/agnxtout use edge sequence (AGSEQ) order
    // within a fixed tail. Do not change behavior without updating fixtures/tests.
    for edge_idx in indices {
      edge_creation.push((tail, edge_head[edge_idx]))
    }
  }
  // Graphviz parity: decompose ordering uses DFS over flat/in/out neighbors
  // driven by agfstnode/agfstout ordering.
  let rank_node_names = build_graphviz_nlist_order_from_edges(
    tail_order,
    tail_order,
    edge_creation,
    Map::new(),
  )
  let rank_nodes : Array[@cgraph.Node] = []
  let seen : Map[String, Bool] = Map::new()
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
  let rank_same_reps = @dot_shared.build_rank_same_reps(source, nodes)
  let rep_index : Map[String, Int] = Map::new()
  let rep_order : Array[String] = []
  let index : Map[String, Int] = Map::new()
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
  let merged_edges : Map[String, (Int, Int, Int, Int)] = Map::new()
  let merged_edge_order : Array[String] = []
  for tail_name in rank_node_names {
    let indices = match edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for edge_idx in indices {
      let edge = edges[edge_idx]
      if !edge_is_constraint(edge) {
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
        None => {
          merged_edges[key] = (tail_idx, head_idx, minlen, weight)
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
    for i in 0..<rep_order.length() {
      component.push(i)
    }
    components.push(component)
  } else {
    for key in merged_edge_order {
      let entry = match merged_edges.get(key) {
        Some(value) => value
        None => continue
      }
      let (tail_idx, head_idx, _minlen, _weight) = entry
      if tail_idx >= 0 && tail_idx < adjacency.length() &&
        head_idx >= 0 && head_idx < adjacency.length() {
        adjacency[tail_idx].push(head_idx)
        adjacency[head_idx].push(tail_idx)
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
      component.sort_by((a, b) =>
        if a < b {
          -1
        } else if a > b {
          1
        } else {
          0
        })
      components.push(component)
    }
  }
  if @sys.get_env_var("DOT_TRACE_RANK_COMPONENTS") is Some(_) {
    let sizes : Array[Int] = []
    for component in components {
      sizes.push(component.length())
    }
    println(
      "rank-components graph=\{graph_name} reps=\{rep_order.length()} has_rank_same=\{has_rank_same_groups} sizes=\{sizes}",
    )
  }
  let rep_ranks : Map[String, Int] = Map::new()
  // Graphviz parity: rank1 runs network simplex per connected component
  // (refs/graphviz/lib/dotgen/rank.c), and each component is normalized
  // independently before readout.
  for component in components {
    let graph = new_graph()
    let local_index : Map[Int, Int] = Map::new()
    for rep_idx in component {
      let rep_name =
        if rep_idx >= 0 && rep_idx < rep_order.length() {
          rep_order[rep_idx]
        } else {
          ""
        }
      local_index[rep_idx] = add_node(graph, rep_name)
    }
    for key in merged_edge_order {
      let entry = match merged_edges.get(key) {
        Some(value) => value
        None => continue
      }
      let (tail_idx, head_idx, minlen, weight) = entry
      let tail_local = match local_index.get(tail_idx) {
        Some(value) => value
        None => continue
      }
      let head_local = match local_index.get(head_idx) {
        Some(value) => value
        None => continue
      }
      let _ = add_edge(graph, tail_local, head_local, minlen, weight)
    }
    network_simplex(graph, 0x7fffffff, BalanceMode::TB)
    tb_tie_adjust_rank_assignment_graphviz(graph)
    let mut component_min_rank = 0
    let mut component_seen = false
    for rep_idx in component {
      let local_idx = match local_index.get(rep_idx) {
        Some(value) => value
        None => continue
      }
      let rank = node_rank(graph, local_idx)
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
      let rep_name =
        if rep_idx >= 0 && rep_idx < rep_order.length() {
          rep_order[rep_idx]
        } else {
          ""
        }
      rep_ranks[rep_name] = node_rank(graph, local_idx) - component_min_rank
    }
  }
  let default_rank =
    if rep_order.length() > 0 {
      match rep_ranks.get(rep_order[0]) {
        Some(value) => value
        None => 0
      }
    } else {
      0
    }
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let rep = match rank_same_reps.get(name) {
      Some(value) => value
      None => name
    }
    let rank = match rep_ranks.get(rep) {
      Some(value) => value
      None => default_rank
    }
    if !seen {
      min_rank = rank
      seen = true
    } else if rank < min_rank {
      min_rank = rank
    }
  }
  for node in nodes {
    let name = node.name()
    let rep = match rank_same_reps.get(name) {
      Some(value) => value
      None => name
    }
    let base_rank = match rep_ranks.get(rep) {
      Some(value) => value
      None => default_rank
    }
    ranks[name] = base_rank - min_rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}
