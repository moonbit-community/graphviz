///|
const NONE_EDGE : Int = -1

///|
priv struct NsEdge {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
  mut cutvalue : Int
  mut tree_index : Int
}

///|
priv struct NsNode {
  mut rank : Int
  in_edges : Array[Int]
  out_edges : Array[Int]
  tree_in : Array[Int]
  tree_out : Array[Int]
  mut par_edge : Int
  mut low : Int
  mut lim : Int
  mut priority : Int
}

///|
priv struct NsGraph {
  nodes : Array[NsNode]
  edges : Array[NsEdge]
  tree_edges : Array[Int]
}

///|
fn new_graph() -> NsGraph {
  { nodes: [], edges: [], tree_edges: [] }
}

///|
fn add_node(graph : NsGraph, _name : String) -> Int {
  let idx = graph.nodes.length()
  graph.nodes.push({
    rank: 0,
    in_edges: [],
    out_edges: [],
    tree_in: [],
    tree_out: [],
    par_edge: NONE_EDGE,
    low: 0,
    lim: 0,
    priority: 0,
  })
  idx
}

///|
fn add_edge(
  graph : NsGraph,
  tail : Int,
  head : Int,
  minlen : Int,
  weight : Int,
) -> Int {
  let idx = graph.edges.length()
  graph.edges.push({
    tail,
    head,
    minlen,
    weight,
    cutvalue: 0,
    tree_index: NONE_EDGE,
  })
  graph.nodes[tail].out_edges.push(idx)
  graph.nodes[head].in_edges.push(idx)
  idx
}

///|
fn edge_length(graph : NsGraph, edge_idx : Int) -> Int {
  let edge = graph.edges[edge_idx]
  graph.nodes[edge.head].rank - graph.nodes[edge.tail].rank
}

///|
fn edge_slack(graph : NsGraph, edge_idx : Int) -> Int {
  edge_length(graph, edge_idx) - graph.edges[edge_idx].minlen
}

///|
fn is_tree_edge(graph : NsGraph, edge_idx : Int) -> Bool {
  graph.edges[edge_idx].tree_index >= 0
}

///|
fn add_tree_edge(graph : NsGraph, edge_idx : Int) -> Unit {
  if is_tree_edge(graph, edge_idx) {
    return ()
  }
  let index = graph.tree_edges.length()
  graph.edges[edge_idx].tree_index = index
  graph.tree_edges.push(edge_idx)
}

///|
fn rebuild_tree_lists(graph : NsGraph) -> Unit {
  for i in 0..<graph.nodes.length() {
    graph.nodes[i].tree_in.clear()
    graph.nodes[i].tree_out.clear()
  }
  for edge_idx in graph.tree_edges {
    let edge = graph.edges[edge_idx]
    graph.nodes[edge.tail].tree_out.push(edge_idx)
    graph.nodes[edge.head].tree_in.push(edge_idx)
  }
}

///|
fn exchange_tree_edges(
  graph : NsGraph,
  leaving : Int,
  entering : Int,
) -> Unit {
  let idx = graph.edges[leaving].tree_index
  if idx < 0 {
    return ()
  }
  graph.edges[entering].tree_index = idx
  graph.edges[leaving].tree_index = NONE_EDGE
  graph.tree_edges[idx] = entering
  rebuild_tree_lists(graph)
}

///|
fn init_graph(graph : NsGraph) -> Bool {
  graph.tree_edges.clear()
  let mut feasible = true
  for i in 0..<graph.nodes.length() {
    graph.nodes[i].priority = graph.nodes[i].in_edges.length()
    graph.nodes[i].tree_in.clear()
    graph.nodes[i].tree_out.clear()
    graph.nodes[i].par_edge = NONE_EDGE
  }
  for i in 0..<graph.edges.length() {
    graph.edges[i].cutvalue = 0
    graph.edges[i].tree_index = NONE_EDGE
    let edge = graph.edges[i]
    let tail_rank = graph.nodes[edge.tail].rank
    let head_rank = graph.nodes[edge.head].rank
    if head_rank - tail_rank < edge.minlen {
      feasible = false
    }
  }
  feasible
}

///|
fn init_rank(graph : NsGraph) -> Unit {
  let queue : Array[Int] = []
  for i in 0..<graph.nodes.length() {
    if graph.nodes[i].priority == 0 {
      queue.push(i)
    }
  }
  let mut idx = 0
  while idx < queue.length() {
    let v = queue[idx]
    idx = idx + 1
    let mut rank = 0
    for edge_idx in graph.nodes[v].in_edges {
      let edge = graph.edges[edge_idx]
      let tail_rank = graph.nodes[edge.tail].rank
      let candidate = tail_rank + edge.minlen
      if candidate > rank {
        rank = candidate
      }
    }
    graph.nodes[v].rank = rank
    for edge_idx in graph.nodes[v].out_edges {
      let head = graph.edges[edge_idx].head
      graph.nodes[head].priority = graph.nodes[head].priority - 1
      if graph.nodes[head].priority <= 0 {
        queue.push(head)
      }
    }
  }
}

///|
fn tight_component(
  graph : NsGraph,
  start : Int,
  subtree : Array[Int],
  subtree_id : Int,
) -> Array[Int] {
  let nodes_in : Array[Int] = []
  let stack : Array[Int] = [start]
  subtree[start] = subtree_id
  while stack.length() > 0 {
    let v = stack[stack.length() - 1]
    let _ = stack.pop()
    nodes_in.push(v)
    let mut index = 0
    let edges = graph.nodes[v].out_edges
    while index < edges.length() {
      let edge_idx = edges[index]
      if !is_tree_edge(graph, edge_idx) && edge_slack(graph, edge_idx) == 0 {
        let head = graph.edges[edge_idx].head
        if subtree[head] == NONE_EDGE {
          subtree[head] = subtree_id
          add_tree_edge(graph, edge_idx)
          stack.push(head)
        }
      }
      index = index + 1
    }
    index = 0
    let in_edges = graph.nodes[v].in_edges
    while index < in_edges.length() {
      let edge_idx = in_edges[index]
      if !is_tree_edge(graph, edge_idx) && edge_slack(graph, edge_idx) == 0 {
        let tail = graph.edges[edge_idx].tail
        if subtree[tail] == NONE_EDGE {
          subtree[tail] = subtree_id
          add_tree_edge(graph, edge_idx)
          stack.push(tail)
        }
      }
      index = index + 1
    }
  }
  nodes_in
}

///|
fn merge_subtrees(
  graph : NsGraph,
  subtree : Array[Int],
  subtrees : Array[Array[Int]],
) -> Bool {
  let active : Array[Int] = []
  for i in 0..<subtrees.length() {
    if subtrees[i].length() > 0 {
      active.push(i)
    }
  }
  while active.length() > 1 {
    let mut best_edge = NONE_EDGE
    let mut best_slack = 0
    let mut best_a = NONE_EDGE
    let mut best_b = NONE_EDGE
    for edge_idx in 0..<graph.edges.length() {
      if is_tree_edge(graph, edge_idx) {
        continue
      }
      let edge = graph.edges[edge_idx]
      let a = subtree[edge.tail]
      let b = subtree[edge.head]
      if a == b {
        continue
      }
      let slack = edge_slack(graph, edge_idx)
      if best_edge == NONE_EDGE || slack < best_slack {
        best_edge = edge_idx
        best_slack = slack
        best_a = a
        best_b = b
      }
    }
    if best_edge == NONE_EDGE {
      return false
    }
    let mut keep = best_a
    let mut drop = best_b
    if subtrees[best_b].length() > subtrees[best_a].length() {
      keep = best_b
      drop = best_a
    }
    if best_slack != 0 {
      let edge = graph.edges[best_edge]
      if subtree[edge.tail] == drop {
        for node in subtrees[drop] {
          graph.nodes[node].rank = graph.nodes[node].rank + best_slack
        }
      } else {
        for node in subtrees[drop] {
          graph.nodes[node].rank = graph.nodes[node].rank - best_slack
        }
      }
    }
    add_tree_edge(graph, best_edge)
    for node in subtrees[drop] {
      subtree[node] = keep
      subtrees[keep].push(node)
    }
    subtrees[drop] = []
    let mut i = 0
    while i < active.length() {
      if active[i] == drop {
        let last = active.length() - 1
        active[i] = active[last]
        let _ = active.pop()
        break
      }
      i = i + 1
    }
  }
  true
}

///|
fn feasible_tree(graph : NsGraph) -> Bool {
  let subtree : Array[Int] = []
  for _ in 0..<graph.nodes.length() {
    subtree.push(NONE_EDGE)
  }
  let subtrees : Array[Array[Int]] = []
  for i in 0..<graph.nodes.length() {
    if subtree[i] != NONE_EDGE {
      continue
    }
    let nodes_in = tight_component(graph, i, subtree, subtrees.length())
    subtrees.push(nodes_in)
  }
  let ok = merge_subtrees(graph, subtree, subtrees)
  if ok {
    rebuild_tree_lists(graph)
  }
  ok
}

///|
fn dfs_range_impl(
  graph : NsGraph,
  node_idx : Int,
  parent_edge : Int,
  counter : Int,
) -> Int {
  graph.nodes[node_idx].par_edge = parent_edge
  graph.nodes[node_idx].low = counter
  let mut cur = counter
  for edge_idx in graph.nodes[node_idx].tree_out {
    if edge_idx == parent_edge {
      continue
    }
    let head = graph.edges[edge_idx].head
    cur = dfs_range_impl(graph, head, edge_idx, cur)
  }
  for edge_idx in graph.nodes[node_idx].tree_in {
    if edge_idx == parent_edge {
      continue
    }
    let tail = graph.edges[edge_idx].tail
    cur = dfs_range_impl(graph, tail, edge_idx, cur)
  }
  graph.nodes[node_idx].lim = cur
  cur + 1
}

///|
fn dfs_range_init(graph : NsGraph, root : Int) -> Unit {
  let _ = dfs_range_impl(graph, root, NONE_EDGE, 1)
}

///|
fn seq(a : Int, b : Int, c : Int) -> Bool {
  a <= b && b <= c
}

///|
fn x_val(graph : NsGraph, edge_idx : Int, node_idx : Int, dir : Int) -> Int {
  let edge = graph.edges[edge_idx]
  let other = if edge.tail == node_idx { edge.head } else { edge.tail }
  let mut rv = 0
  let mut flip = false
  if !seq(graph.nodes[node_idx].low, graph.nodes[other].lim, graph.nodes[node_idx].lim) {
    rv = edge.weight
    flip = true
  } else {
    rv = if is_tree_edge(graph, edge_idx) {
      graph.edges[edge_idx].cutvalue
    } else {
      0
    }
    rv = rv - edge.weight
  }
  let mut sign = 1
  if dir > 0 {
    sign = if edge.head == node_idx { 1 } else { -1 }
  } else {
    sign = if edge.tail == node_idx { 1 } else { -1 }
  }
  if flip {
    sign = -sign
  }
  if sign < 0 {
    rv = -rv
  }
  rv
}

///|
fn x_cutval(graph : NsGraph, edge_idx : Int) -> Unit {
  let edge = graph.edges[edge_idx]
  let tail = edge.tail
  let head = edge.head
  let (v, dir) = if graph.nodes[tail].par_edge == edge_idx {
    (tail, 1)
  } else {
    (head, -1)
  }
  let mut sum = 0
  for e in graph.nodes[v].out_edges {
    sum = sum + x_val(graph, e, v, dir)
  }
  for e in graph.nodes[v].in_edges {
    sum = sum + x_val(graph, e, v, dir)
  }
  graph.edges[edge_idx].cutvalue = sum
}

///|
fn dfs_cutval(graph : NsGraph, node_idx : Int, parent_edge : Int) -> Unit {
  for edge_idx in graph.nodes[node_idx].tree_out {
    if edge_idx == parent_edge {
      continue
    }
    dfs_cutval(graph, graph.edges[edge_idx].head, edge_idx)
  }
  for edge_idx in graph.nodes[node_idx].tree_in {
    if edge_idx == parent_edge {
      continue
    }
    dfs_cutval(graph, graph.edges[edge_idx].tail, edge_idx)
  }
  if parent_edge != NONE_EDGE {
    x_cutval(graph, parent_edge)
  }
}

///|
fn init_cutvalues(graph : NsGraph) -> Unit {
  dfs_range_init(graph, 0)
  dfs_cutval(graph, 0, NONE_EDGE)
}

///|
fn leave_edge(graph : NsGraph) -> Int? {
  let mut best_edge : Int? = None
  let mut best_cut = 0
  for edge_idx in graph.tree_edges {
    let cut = graph.edges[edge_idx].cutvalue
    if cut < best_cut {
      best_cut = cut
      best_edge = Some(edge_idx)
    }
  }
  best_edge
}

///|
fn enter_edge(graph : NsGraph, leaving : Int) -> Int? {
  let edge = graph.edges[leaving]
  let root = if graph.nodes[edge.tail].lim < graph.nodes[edge.head].lim {
    edge.tail
  } else {
    edge.head
  }
  let low = graph.nodes[root].low
  let lim = graph.nodes[root].lim
  let mut best_edge : Int? = None
  let mut best_slack = 0
  for edge_idx in 0..<graph.edges.length() {
    if is_tree_edge(graph, edge_idx) {
      continue
    }
    let e = graph.edges[edge_idx]
    let tail_in = seq(low, graph.nodes[e.tail].lim, lim)
    let head_in = seq(low, graph.nodes[e.head].lim, lim)
    if tail_in == head_in {
      continue
    }
    let slack = edge_slack(graph, edge_idx)
    if best_edge is None || slack < best_slack {
      best_edge = Some(edge_idx)
      best_slack = slack
    }
  }
  best_edge
}

///|
fn rerank(
  graph : NsGraph,
  node_idx : Int,
  delta : Int,
  parent_edge : Int,
) -> Unit {
  graph.nodes[node_idx].rank = graph.nodes[node_idx].rank - delta
  for edge_idx in graph.nodes[node_idx].tree_out {
    if edge_idx == parent_edge {
      continue
    }
    rerank(graph, graph.edges[edge_idx].head, delta, edge_idx)
  }
  for edge_idx in graph.nodes[node_idx].tree_in {
    if edge_idx == parent_edge {
      continue
    }
    rerank(graph, graph.edges[edge_idx].tail, delta, edge_idx)
  }
}

///|
fn update(
  graph : NsGraph,
  leaving : Int,
  entering : Int,
) -> Unit {
  let delta = edge_slack(graph, entering)
  if delta > 0 {
    let tail = graph.edges[leaving].tail
    let head = graph.edges[leaving].head
    let tail_deg = graph.nodes[tail].tree_in.length() + graph.nodes[tail].tree_out.length()
    let head_deg = graph.nodes[head].tree_in.length() + graph.nodes[head].tree_out.length()
    if tail_deg == 1 {
      rerank(graph, tail, delta, leaving)
    } else if head_deg == 1 {
      rerank(graph, head, -delta, leaving)
    } else if graph.nodes[tail].lim < graph.nodes[head].lim {
      rerank(graph, tail, delta, leaving)
    } else {
      rerank(graph, head, -delta, leaving)
    }
  }
  exchange_tree_edges(graph, leaving, entering)
}

///|
fn lr_balance(graph : NsGraph) -> Unit {
  init_cutvalues(graph)
  for edge_idx in graph.tree_edges {
    if graph.edges[edge_idx].cutvalue != 0 {
      continue
    }
    let entering = enter_edge(graph, edge_idx)
    match entering {
      None => ()
      Some(value) => {
        let delta = edge_slack(graph, value)
        if delta <= 1 {
          continue
        }
        let tail = graph.edges[edge_idx].tail
        let head = graph.edges[edge_idx].head
        if graph.nodes[tail].lim < graph.nodes[head].lim {
          rerank(graph, tail, delta / 2, edge_idx)
        } else {
          rerank(graph, head, -delta / 2, edge_idx)
        }
      }
    }
  }
}

///|
fn network_simplex(graph : NsGraph, max_iter : Int) -> Unit {
  let feasible = init_graph(graph)
  if !feasible {
    init_rank(graph)
  }
  if !feasible_tree(graph) {
    return ()
  }
  init_cutvalues(graph)
  let mut iter = 0
  while iter < max_iter {
    let leaving = leave_edge(graph)
    match leaving {
      None => break
      Some(leaving_idx) => {
        let entering = enter_edge(graph, leaving_idx)
        match entering {
          None => break
          Some(entering_idx) => {
            update(graph, leaving_idx, entering_idx)
            init_cutvalues(graph)
          }
        }
      }
    }
    iter = iter + 1
  }
  lr_balance(graph)
}

///|
fn round_int(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
fn nodesep_minlen(
  tail_name : String,
  head_name : String,
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
) -> Int {
  let tail_width = match sizes.get(tail_name) {
    Some(value) => value.width_pt
    None => default_node_width_in() * 72.0
  }
  let head_width = match sizes.get(head_name) {
    Some(value) => value.width_pt
    None => default_node_width_in() * 72.0
  }
  let minlen = tail_width / 2.0 + head_width / 2.0 + nodesep_pt
  round_int(minlen)
}

///|
fn build_constraint_graph(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
) -> (NsGraph, Map[String, Int]) {
  let graph = new_graph()
  let index : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    index[name] = add_node(graph, name)
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut i = 0
    while i + 1 < names.length() {
      let tail = names[i]
      let head = names[i + 1]
      let tail_idx = match index.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_idx = match index.get(head) {
        Some(value) => value
        None => 0
      }
      let minlen = nodesep_minlen(tail, head, sizes, nodesep_pt)
      let _ = add_edge(graph, tail_idx, head_idx, minlen, 0)
      i = i + 1
    }
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_idx = match index.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_idx = match index.get(head) {
      Some(value) => value
      None => 0
    }
    let slack_idx = add_node(graph, "")
    let _ = add_edge(graph, slack_idx, tail_idx, 1, 1)
    let _ = add_edge(graph, slack_idx, head_idx, 1, 1)
  }
  (graph, index)
}

///|
fn x_positions_from_simplex(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
) -> Map[String, Double] {
  let (graph, index) = build_constraint_graph(
    nodes,
    edges,
    rank_keys,
    groups,
    sizes,
    nodesep_pt,
  )
  network_simplex(graph, 1000)
  let positions : Map[String, Double] = Map::new()
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    positions[name] = graph.nodes[idx].rank.to_double()
  }
  positions
}

///|
fn compute_x_positions(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
) -> Map[String, Double] {
  x_positions_from_simplex(nodes, edges, rank_keys, groups, sizes, nodesep_pt)
}
