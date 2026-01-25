///|
const NONE_EDGE : Int = -1

///|
const NO_HEAP : Int = -1

///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128


///|
const CLUSTER_LN_PREFIX : String = "_mbt_cluster_ln_"

///|
const CLUSTER_RN_PREFIX : String = "_mbt_cluster_rn_"

///|
priv enum BalanceMode {
  LR
  TB
}

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
priv struct ConstraintEdge {
  tail : String
  head : String
  minlen : Int
  weight : Int
  tail_port : String?
  head_port : String?
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
  let edge = graph.edges[edge_idx]
  graph.nodes[edge.tail].tree_out.push(edge_idx)
  graph.nodes[edge.head].tree_in.push(edge_idx)
}

///|
fn remove_tree_edge(list : Array[Int], edge_idx : Int) -> Unit {
  let mut i = 0
  while i < list.length() {
    if list[i] == edge_idx {
      let last = list.length() - 1
      list[i] = list[last]
      let _ = list.pop()
      return ()
    }
    i = i + 1
  }
}

///|
fn exchange_tree_edges(graph : NsGraph, leaving : Int, entering : Int) -> Unit {
  let idx = graph.edges[leaving].tree_index
  if idx < 0 {
    return ()
  }
  graph.edges[entering].tree_index = idx
  graph.edges[leaving].tree_index = NONE_EDGE
  graph.tree_edges[idx] = entering
  let leaving_tail = graph.edges[leaving].tail
  let leaving_head = graph.edges[leaving].head
  remove_tree_edge(graph.nodes[leaving_tail].tree_out, leaving)
  remove_tree_edge(graph.nodes[leaving_head].tree_in, leaving)
  let entering_tail = graph.edges[entering].tail
  let entering_head = graph.edges[entering].head
  graph.nodes[entering_tail].tree_out.push(entering)
  graph.nodes[entering_head].tree_in.push(entering)
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
priv struct Subtree {
  rep : Int
  mut size : Int
  mut heap_index : Int
  mut parent : Int
}

///|
priv struct TightState {
  node : Int
  mut in_i : Int
  mut out_i : Int
  mut rv : Int
}

///|
priv struct DfsState {
  node : Int
  par_edge : Int
  mut lim : Int
  mut tree_out_i : Int
  mut tree_in_i : Int
}

///|
fn subtree_on_heap(subtrees : Array[Subtree], idx : Int) -> Bool {
  subtrees[idx].heap_index != NO_HEAP
}

///|
fn subtree_find(subtrees : Array[Subtree], idx : Int) -> Int {
  let mut root = idx
  while subtrees[root].parent != root {
    root = subtrees[root].parent
  }
  let mut cur = idx
  while subtrees[cur].parent != cur {
    let parent = subtrees[cur].parent
    subtrees[cur].parent = root
    cur = parent
  }
  root
}

///|
fn subtree_union(subtrees : Array[Subtree], a : Int, b : Int) -> Int {
  let r0 = subtree_find(subtrees, a)
  let r1 = subtree_find(subtrees, b)
  if r0 == r1 {
    return r0
  }
  let mut root = r1
  let on0 = subtree_on_heap(subtrees, r0)
  let on1 = subtree_on_heap(subtrees, r1)
  if !on1 {
    root = r0
  } else if !on0 {
    root = r1
  } else if subtrees[r1].size < subtrees[r0].size {
    root = r0
  }
  subtrees[r0].parent = root
  subtrees[r1].parent = root
  subtrees[root].size = subtrees[r0].size + subtrees[r1].size
  root
}

///|
fn heapify_down(
  heap : Array[Int],
  subtrees : Array[Subtree],
  start : Int,
) -> Unit {
  let mut idx = start
  let size = heap.length()
  while true {
    let left = idx * 2 + 1
    let right = idx * 2 + 2
    let mut smallest = idx
    if left < size && subtrees[heap[left]].size < subtrees[heap[smallest]].size {
      smallest = left
    }
    if right < size &&
      subtrees[heap[right]].size < subtrees[heap[smallest]].size {
      smallest = right
    }
    if smallest == idx {
      break
    }
    let tmp = heap[idx]
    heap[idx] = heap[smallest]
    heap[smallest] = tmp
    subtrees[heap[idx]].heap_index = idx
    subtrees[heap[smallest]].heap_index = smallest
    idx = smallest
  }
}

///|
fn build_heap(subtrees : Array[Subtree]) -> Array[Int] {
  let heap : Array[Int] = []
  for i in 0..<subtrees.length() {
    heap.push(i)
    subtrees[i].heap_index = i
  }
  if heap.length() == 0 {
    return heap
  }
  let mut idx = heap.length() / 2
  while idx > 0 {
    idx = idx - 1
    heapify_down(heap, subtrees, idx)
  }
  heap
}

///|
fn heap_extract_min(heap : Array[Int], subtrees : Array[Subtree]) -> Int {
  let min_idx = heap[0]
  subtrees[min_idx].heap_index = NO_HEAP
  let last = heap[heap.length() - 1]
  heap[0] = last
  let _ = heap.pop()
  if heap.length() > 0 {
    subtrees[last].heap_index = 0
    heapify_down(heap, subtrees, 0)
  }
  min_idx
}

///|
fn tree_adjust(graph : NsGraph, start : Int, from : Int, delta : Int) -> Unit {
  let stack : Array[(Int, Int)] = [(start, from)]
  while stack.length() > 0 {
    let (v, parent) = stack[stack.length() - 1]
    let _ = stack.pop()
    graph.nodes[v].rank = graph.nodes[v].rank + delta
    for edge_idx in graph.nodes[v].tree_in {
      let tail = graph.edges[edge_idx].tail
      if tail != parent {
        stack.push((tail, v))
      }
    }
    for edge_idx in graph.nodes[v].tree_out {
      let head = graph.edges[edge_idx].head
      if head != parent {
        stack.push((head, v))
      }
    }
  }
}

///|
fn tight_subtree_search(
  graph : NsGraph,
  start : Int,
  node_subtree : Array[Int],
  subtree_id : Int,
) -> Int {
  let stack : Array[TightState] = [{ node: start, in_i: 0, out_i: 0, rv: 1 }]
  node_subtree[start] = subtree_id
  let mut result = 1
  while stack.length() > 0 {
    let last = stack.length() - 1
    let state = stack[last]
    let mut updated = false
    while state.in_i < graph.nodes[state.node].in_edges.length() {
      let edge_idx = graph.nodes[state.node].in_edges[state.in_i]
      state.in_i = state.in_i + 1
      if is_tree_edge(graph, edge_idx) || edge_slack(graph, edge_idx) != 0 {
        continue
      }
      let tail = graph.edges[edge_idx].tail
      if node_subtree[tail] == NONE_EDGE {
        node_subtree[tail] = subtree_id
        add_tree_edge(graph, edge_idx)
        stack[last] = state
        stack.push({ node: tail, in_i: 0, out_i: 0, rv: 1 })
        updated = true
        break
      }
    }
    if updated {
      continue
    }
    while state.out_i < graph.nodes[state.node].out_edges.length() {
      let edge_idx = graph.nodes[state.node].out_edges[state.out_i]
      state.out_i = state.out_i + 1
      if is_tree_edge(graph, edge_idx) || edge_slack(graph, edge_idx) != 0 {
        continue
      }
      let head = graph.edges[edge_idx].head
      if node_subtree[head] == NONE_EDGE {
        node_subtree[head] = subtree_id
        add_tree_edge(graph, edge_idx)
        stack[last] = state
        stack.push({ node: head, in_i: 0, out_i: 0, rv: 1 })
        updated = true
        break
      }
    }
    if updated {
      continue
    }
    let done = stack.pop()
    match done {
      None => ()
      Some(value) =>
        if stack.length() == 0 {
          result = value.rv
        } else {
          let parent = stack.length() - 1
          let parent_state = stack[parent]
          parent_state.rv = parent_state.rv + value.rv
          stack[parent] = parent_state
        }
    }
  }
  result
}

///|
fn inter_tree_edge_search(
  graph : NsGraph,
  node_subtree : Array[Int],
  subtrees : Array[Subtree],
  root : Int,
  v : Int,
  from : Int,
  best : Int?,
) -> Int? {
  let mut current = best
  match current {
    Some(edge_idx) => if edge_slack(graph, edge_idx) == 0 { return current }
    None => ()
  }
  for edge_idx in graph.nodes[v].out_edges {
    if is_tree_edge(graph, edge_idx) {
      let head = graph.edges[edge_idx].head
      if head != from {
        current = inter_tree_edge_search(
          graph, node_subtree, subtrees, root, head, v, current,
        )
        match current {
          Some(found) => if edge_slack(graph, found) == 0 { return current }
          None => ()
        }
      }
      continue
    }
    let head = graph.edges[edge_idx].head
    let head_sub = node_subtree[head]
    if head_sub != NONE_EDGE && subtree_find(subtrees, head_sub) != root {
      let slack = edge_slack(graph, edge_idx)
      match current {
        Some(best_edge) =>
          if slack < edge_slack(graph, best_edge) {
            current = Some(edge_idx)
          }
        None => current = Some(edge_idx)
      }
    }
  }
  for edge_idx in graph.nodes[v].in_edges {
    if is_tree_edge(graph, edge_idx) {
      let tail = graph.edges[edge_idx].tail
      if tail != from {
        current = inter_tree_edge_search(
          graph, node_subtree, subtrees, root, tail, v, current,
        )
        match current {
          Some(found) => if edge_slack(graph, found) == 0 { return current }
          None => ()
        }
      }
      continue
    }
    let tail = graph.edges[edge_idx].tail
    let tail_sub = node_subtree[tail]
    if tail_sub != NONE_EDGE && subtree_find(subtrees, tail_sub) != root {
      let slack = edge_slack(graph, edge_idx)
      match current {
        Some(best_edge) =>
          if slack < edge_slack(graph, best_edge) {
            current = Some(edge_idx)
          }
        None => current = Some(edge_idx)
      }
    }
  }
  current
}

///|
fn inter_tree_edge(
  graph : NsGraph,
  node_subtree : Array[Int],
  subtrees : Array[Subtree],
  subtree_id : Int,
) -> Int? {
  let root = subtree_find(subtrees, subtree_id)
  let start = subtrees[root].rep
  inter_tree_edge_search(
    graph,
    node_subtree,
    subtrees,
    root,
    start,
    NONE_EDGE,
    None,
  )
}

///|
fn merge_trees(
  graph : NsGraph,
  node_subtree : Array[Int],
  subtrees : Array[Subtree],
  edge_idx : Int,
) -> Int? {
  let edge = graph.edges[edge_idx]
  let tail_sub = subtree_find(subtrees, node_subtree[edge.tail])
  let head_sub = subtree_find(subtrees, node_subtree[edge.head])
  if tail_sub == head_sub {
    return Some(tail_sub)
  }
  let slack = edge_slack(graph, edge_idx)
  if !subtree_on_heap(subtrees, tail_sub) {
    if slack != 0 {
      tree_adjust(graph, subtrees[tail_sub].rep, NONE_EDGE, slack)
    }
  } else if slack != 0 {
    tree_adjust(graph, subtrees[head_sub].rep, NONE_EDGE, -slack)
  }
  add_tree_edge(graph, edge_idx)
  Some(subtree_union(subtrees, tail_sub, head_sub))
}

///|
fn feasible_tree(graph : NsGraph) -> Bool {
  let node_subtree : Array[Int] = []
  for _ in 0..<graph.nodes.length() {
    node_subtree.push(NONE_EDGE)
  }
  let subtrees : Array[Subtree] = []
  for node_idx in 0..<graph.nodes.length() {
    if node_subtree[node_idx] != NONE_EDGE {
      continue
    }
    let size = tight_subtree_search(
      graph,
      node_idx,
      node_subtree,
      subtrees.length(),
    )
    subtrees.push({
      rep: node_idx,
      size,
      heap_index: NO_HEAP,
      parent: subtrees.length(),
    })
  }
  let heap = build_heap(subtrees)
  while heap.length() > 1 {
    let tree_idx = heap_extract_min(heap, subtrees)
    let entering = inter_tree_edge(graph, node_subtree, subtrees, tree_idx)
    match entering {
      None => return false
      Some(edge_idx) => {
        let merged = merge_trees(graph, node_subtree, subtrees, edge_idx)
        match merged {
          None => return false
          Some(root) => {
            let heap_idx = subtrees[root].heap_index
            if heap_idx != NO_HEAP {
              heapify_down(heap, subtrees, heap_idx)
            }
          }
        }
      }
    }
  }
  init_cutvalues(graph)
  true
}

///|
fn dfs_range_init(graph : NsGraph, root : Int) -> Int {
  graph.nodes[root].par_edge = NONE_EDGE
  graph.nodes[root].low = 1
  let stack : Array[DfsState] = [
    { node: root, par_edge: NONE_EDGE, lim: 1, tree_out_i: 0, tree_in_i: 0 },
  ]
  let mut lim = 0
  while stack.length() > 0 {
    let last = stack.length() - 1
    let state = stack[last]
    let mut pushed = false
    while state.tree_out_i < graph.nodes[state.node].tree_out.length() {
      let edge_idx = graph.nodes[state.node].tree_out[state.tree_out_i]
      state.tree_out_i = state.tree_out_i + 1
      if edge_idx != state.par_edge {
        let head = graph.edges[edge_idx].head
        graph.nodes[head].par_edge = edge_idx
        graph.nodes[head].low = state.lim
        stack[last] = state
        stack.push({
          node: head,
          par_edge: edge_idx,
          lim: state.lim,
          tree_out_i: 0,
          tree_in_i: 0,
        })
        pushed = true
        break
      }
    }
    if pushed {
      continue
    }
    while state.tree_in_i < graph.nodes[state.node].tree_in.length() {
      let edge_idx = graph.nodes[state.node].tree_in[state.tree_in_i]
      state.tree_in_i = state.tree_in_i + 1
      if edge_idx != state.par_edge {
        let tail = graph.edges[edge_idx].tail
        graph.nodes[tail].par_edge = edge_idx
        graph.nodes[tail].low = state.lim
        stack[last] = state
        stack.push({
          node: tail,
          par_edge: edge_idx,
          lim: state.lim,
          tree_out_i: 0,
          tree_in_i: 0,
        })
        pushed = true
        break
      }
    }
    if pushed {
      continue
    }
    graph.nodes[state.node].lim = state.lim
    lim = state.lim
    let _ = stack.pop()
    if stack.length() > 0 {
      let parent_idx = stack.length() - 1
      let parent_state = stack[parent_idx]
      parent_state.lim = lim + 1
      stack[parent_idx] = parent_state
    }
  }
  lim + 1
}

///|
fn dfs_range(
  graph : NsGraph,
  node_idx : Int,
  parent_edge : Int,
  low : Int,
) -> Int {
  if graph.nodes[node_idx].par_edge == parent_edge &&
    graph.nodes[node_idx].low == low {
    return graph.nodes[node_idx].lim + 1
  }
  graph.nodes[node_idx].par_edge = parent_edge
  graph.nodes[node_idx].low = low
  let stack : Array[DfsState] = [
    {
      node: node_idx,
      par_edge: parent_edge,
      lim: low,
      tree_out_i: 0,
      tree_in_i: 0,
    },
  ]
  let mut lim = 0
  while stack.length() > 0 {
    let last = stack.length() - 1
    let state = stack[last]
    let mut processed = false
    while state.tree_out_i < graph.nodes[state.node].tree_out.length() {
      let edge_idx = graph.nodes[state.node].tree_out[state.tree_out_i]
      state.tree_out_i = state.tree_out_i + 1
      if edge_idx != state.par_edge {
        let head = graph.edges[edge_idx].head
        if graph.nodes[head].par_edge == edge_idx &&
          graph.nodes[head].low == state.lim {
          state.lim = graph.nodes[head].lim + 1
          stack[last] = state
        } else {
          graph.nodes[head].par_edge = edge_idx
          graph.nodes[head].low = state.lim
          stack[last] = state
          stack.push({
            node: head,
            par_edge: edge_idx,
            lim: state.lim,
            tree_out_i: 0,
            tree_in_i: 0,
          })
        }
        processed = true
        break
      }
    }
    if processed {
      continue
    }
    while state.tree_in_i < graph.nodes[state.node].tree_in.length() {
      let edge_idx = graph.nodes[state.node].tree_in[state.tree_in_i]
      state.tree_in_i = state.tree_in_i + 1
      if edge_idx != state.par_edge {
        let tail = graph.edges[edge_idx].tail
        if graph.nodes[tail].par_edge == edge_idx &&
          graph.nodes[tail].low == state.lim {
          state.lim = graph.nodes[tail].lim + 1
          stack[last] = state
        } else {
          graph.nodes[tail].par_edge = edge_idx
          graph.nodes[tail].low = state.lim
          stack[last] = state
          stack.push({
            node: tail,
            par_edge: edge_idx,
            lim: state.lim,
            tree_out_i: 0,
            tree_in_i: 0,
          })
        }
        processed = true
        break
      }
    }
    if processed {
      continue
    }
    graph.nodes[state.node].lim = state.lim
    lim = state.lim
    let _ = stack.pop()
    if stack.length() > 0 {
      let parent_idx = stack.length() - 1
      let parent_state = stack[parent_idx]
      parent_state.lim = lim + 1
      stack[parent_idx] = parent_state
    }
  }
  lim + 1
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
  if !seq(
      graph.nodes[node_idx].low,
      graph.nodes[other].lim,
      graph.nodes[node_idx].lim,
    ) {
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
  if graph.nodes.length() == 0 {
    return ()
  }
  let root = 0
  let _ = dfs_range_init(graph, root)
  dfs_cutval(graph, root, NONE_EDGE)
}

///|
fn invalidate_path(graph : NsGraph, lca : Int, to_node : Int) -> Unit {
  let mut current = to_node
  while true {
    if graph.nodes[current].low == -1 {
      break
    }
    graph.nodes[current].low = -1
    let parent_edge = graph.nodes[current].par_edge
    if parent_edge == NONE_EDGE {
      break
    }
    if graph.nodes[current].lim >= graph.nodes[lca].lim {
      break
    }
    let tail = graph.edges[parent_edge].tail
    let head = graph.edges[parent_edge].head
    if graph.nodes[tail].lim > graph.nodes[head].lim {
      current = tail
    } else {
      current = head
    }
  }
}

///|
fn treeupdate(
  graph : NsGraph,
  v : Int,
  w : Int,
  cutvalue : Int,
  dir : Bool,
) -> Int {
  let mut current = v
  while !seq(
          graph.nodes[current].low,
          graph.nodes[w].lim,
          graph.nodes[current].lim,
        ) {
    let edge_idx = graph.nodes[current].par_edge
    if edge_idx == NONE_EDGE {
      break
    }
    let tail = graph.edges[edge_idx].tail
    let head = graph.edges[edge_idx].head
    let sign = if tail == current { dir } else { !dir }
    if sign {
      graph.edges[edge_idx].cutvalue = graph.edges[edge_idx].cutvalue + cutvalue
    } else {
      graph.edges[edge_idx].cutvalue = graph.edges[edge_idx].cutvalue - cutvalue
    }
    if graph.nodes[tail].lim > graph.nodes[head].lim {
      current = tail
    } else {
      current = head
    }
  }
  current
}

///|
fn leave_edge(
  graph : NsGraph,
  search_index : Int,
  search_size : Int,
) -> (Int?, Int) {
  let total = graph.tree_edges.length()
  let mut idx = search_index
  let mut best_edge : Int? = None
  let mut best_cut = 0
  let mut count = 0
  while idx < total {
    let edge_idx = graph.tree_edges[idx]
    let cut = graph.edges[edge_idx].cutvalue
    if cut < 0 {
      if best_edge is None || cut < best_cut {
        best_edge = Some(edge_idx)
        best_cut = cut
      }
      count = count + 1
      if count >= search_size {
        return (best_edge, idx)
      }
    }
    idx = idx + 1
  }
  if search_index > 0 {
    idx = 0
    while idx < search_index {
      let edge_idx = graph.tree_edges[idx]
      let cut = graph.edges[edge_idx].cutvalue
      if cut < 0 {
        if best_edge is None || cut < best_cut {
          best_edge = Some(edge_idx)
          best_cut = cut
        }
        count = count + 1
        if count >= search_size {
          return (best_edge, idx)
        }
      }
      idx = idx + 1
    }
  }
  (best_edge, idx)
}

///|
fn dfs_enter_outedge(
  graph : NsGraph,
  start : Int,
  low : Int,
  lim : Int,
) -> Int? {
  let mut best_edge : Int? = None
  let mut best_slack = 0x7fffffff
  let stack : Array[Int] = [start]
  while stack.length() > 0 {
    let v = stack[stack.length() - 1]
    let _ = stack.pop()
    for edge_idx in graph.nodes[v].out_edges {
      let head = graph.edges[edge_idx].head
      if is_tree_edge(graph, edge_idx) {
        if graph.nodes[head].lim < graph.nodes[v].lim {
          stack.push(head)
        }
        continue
      }
      if seq(low, graph.nodes[head].lim, lim) {
        continue
      }
      let slack = edge_slack(graph, edge_idx)
      if slack < best_slack || best_edge is None {
        best_edge = Some(edge_idx)
        best_slack = slack
      }
    }
    if best_slack > 0 {
      for edge_idx in graph.nodes[v].tree_in {
        let tail = graph.edges[edge_idx].tail
        if graph.nodes[tail].lim < graph.nodes[v].lim {
          stack.push(tail)
        }
      }
    }
  }
  best_edge
}

///|
fn dfs_enter_inedge(graph : NsGraph, start : Int, low : Int, lim : Int) -> Int? {
  let mut best_edge : Int? = None
  let mut best_slack = 0x7fffffff
  let stack : Array[Int] = [start]
  while stack.length() > 0 {
    let v = stack[stack.length() - 1]
    let _ = stack.pop()
    for edge_idx in graph.nodes[v].in_edges {
      let tail = graph.edges[edge_idx].tail
      if is_tree_edge(graph, edge_idx) {
        if graph.nodes[tail].lim < graph.nodes[v].lim {
          stack.push(tail)
        }
        continue
      }
      if seq(low, graph.nodes[tail].lim, lim) {
        continue
      }
      let slack = edge_slack(graph, edge_idx)
      if slack < best_slack || best_edge is None {
        best_edge = Some(edge_idx)
        best_slack = slack
      }
    }
    if best_slack > 0 {
      for edge_idx in graph.nodes[v].tree_out {
        let head = graph.edges[edge_idx].head
        if graph.nodes[head].lim < graph.nodes[v].lim {
          stack.push(head)
        }
      }
    }
  }
  best_edge
}

///|
fn enter_edge(graph : NsGraph, leaving : Int) -> Int? {
  let edge = graph.edges[leaving]
  if graph.nodes[edge.tail].lim < graph.nodes[edge.head].lim {
    dfs_enter_inedge(
      graph,
      edge.tail,
      graph.nodes[edge.tail].low,
      graph.nodes[edge.tail].lim,
    )
  } else {
    dfs_enter_outedge(
      graph,
      edge.head,
      graph.nodes[edge.head].low,
      graph.nodes[edge.head].lim,
    )
  }
}

///|
fn rerank(graph : NsGraph, node_idx : Int, delta : Int) -> Unit {
  graph.nodes[node_idx].rank = graph.nodes[node_idx].rank - delta
  let parent_edge = graph.nodes[node_idx].par_edge
  for edge_idx in graph.nodes[node_idx].tree_out {
    if edge_idx == parent_edge {
      continue
    }
    rerank(graph, graph.edges[edge_idx].head, delta)
  }
  for edge_idx in graph.nodes[node_idx].tree_in {
    if edge_idx == parent_edge {
      continue
    }
    rerank(graph, graph.edges[edge_idx].tail, delta)
  }
}

///|
fn update(graph : NsGraph, leaving : Int, entering : Int) -> Unit {
  let delta = edge_slack(graph, entering)
  if delta > 0 {
    let tail = graph.edges[leaving].tail
    let head = graph.edges[leaving].head
    let tail_deg = graph.nodes[tail].tree_in.length() +
      graph.nodes[tail].tree_out.length()
    let head_deg = graph.nodes[head].tree_in.length() +
      graph.nodes[head].tree_out.length()
    if tail_deg == 1 {
      rerank(graph, tail, delta)
    } else if head_deg == 1 {
      rerank(graph, head, -delta)
    } else if graph.nodes[tail].lim < graph.nodes[head].lim {
      rerank(graph, tail, delta)
    } else {
      rerank(graph, head, -delta)
    }
  }
  let cutvalue = graph.edges[leaving].cutvalue
  let enter_tail = graph.edges[entering].tail
  let enter_head = graph.edges[entering].head
  let lca = treeupdate(graph, enter_tail, enter_head, cutvalue, true)
  let _ = treeupdate(graph, enter_head, enter_tail, cutvalue, false)
  let lca_low = graph.nodes[lca].low
  invalidate_path(graph, lca, enter_head)
  invalidate_path(graph, lca, enter_tail)
  graph.edges[entering].cutvalue = -cutvalue
  graph.edges[leaving].cutvalue = 0
  exchange_tree_edges(graph, leaving, entering)
  let _ = dfs_range(graph, lca, graph.nodes[lca].par_edge, lca_low)

}

///|
fn lr_balance(graph : NsGraph) -> Unit {
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
          rerank(graph, tail, delta / 2)
        } else {
          rerank(graph, head, -delta / 2)
        }
      }
    }
  }
}

///|
fn normalize_ranks(graph : NsGraph) -> Int {
  let mut min_rank = 0
  let mut max_rank = 0
  let mut seen = false
  for node in graph.nodes {
    let rank = node.rank
    if !seen {
      min_rank = rank
      max_rank = rank
      seen = true
    } else {
      if rank < min_rank {
        min_rank = rank
      }
      if rank > max_rank {
        max_rank = rank
      }
    }
  }
  if !seen {
    return 0
  }
  if min_rank != 0 {
    for node in graph.nodes {
      node.rank = node.rank - min_rank
    }
    max_rank = max_rank - min_rank
  }
  max_rank
}

///|
fn tb_balance(graph : NsGraph) -> Unit {
  let max_rank = normalize_ranks(graph)
  if max_rank <= 0 {
    return ()
  }
  let nrank : Array[Int] = []
  for _ in 0..<(max_rank + 1) {
    nrank.push(0)
  }
  for node in graph.nodes {
    let rank = node.rank
    if rank >= 0 && rank <= max_rank {
      nrank[rank] = nrank[rank] + 1
    }
  }
  let nodes_by_rank : Map[Int, Array[Int]] = Map::new()
  for i in 0..<graph.nodes.length() {
    let rank = graph.nodes[i].rank
    match nodes_by_rank.get(rank) {
      Some(list) => list.push(i)
      None => nodes_by_rank[rank] = [i]
    }
  }
  let ordered : Array[Int] = []
  for rank in 0..=max_rank {
    match nodes_by_rank.get(rank) {
      Some(list) =>
        for idx in list {
          ordered.push(idx)
        }
      None => ()
    }
  }
  for idx in ordered {
    let node = graph.nodes[idx]
    let mut inweight = 0
    let mut outweight = 0
    let mut low = 0
    let mut high = max_rank
    for edge_idx in node.in_edges {
      let edge = graph.edges[edge_idx]
      inweight = inweight + edge.weight
      let candidate = graph.nodes[edge.tail].rank + edge.minlen
      if candidate > low {
        low = candidate
      }
    }
    for edge_idx in node.out_edges {
      let edge = graph.edges[edge_idx]
      outweight = outweight + edge.weight
      let candidate = graph.nodes[edge.head].rank - edge.minlen
      if candidate < high {
        high = candidate
      }
    }
    if inweight != outweight {
      continue
    }
    if low < 0 {
      low = 0
    }
    if high > max_rank {
      high = max_rank
    }
    if low > high {
      continue
    }
    let mut choice = low
    let mut r = low + 1
    while r <= high {
      if nrank[r] < nrank[choice] {
        choice = r
      }
      r = r + 1
    }
    let current = graph.nodes[idx].rank
    if choice != current {
      if current >= 0 && current <= max_rank {
        nrank[current] = nrank[current] - 1
      }
      nrank[choice] = nrank[choice] + 1
      graph.nodes[idx].rank = choice
    }
  }
}

///|
fn network_simplex(
  graph : NsGraph,
  max_iter : Int,
  balance : BalanceMode,
) -> Unit {
  let feasible = init_graph(graph)
  if !feasible {
    init_rank(graph)
  }
  if !feasible_tree(graph) {
    return ()
  }
  init_cutvalues(graph)
  let mut iter = 0
  let mut search_index = 0
  let search_size = 30
  while iter < max_iter {
    let (leaving, next_index) = leave_edge(graph, search_index, search_size)
    search_index = next_index
    match leaving {
      None => break
      Some(leaving_idx) => {
        let entering = enter_edge(graph, leaving_idx)
        match entering {
          None => break
          Some(entering_idx) => update(graph, leaving_idx, entering_idx)
        }
      }
    }
    iter = iter + 1
  }
  match balance {
    BalanceMode::LR => lr_balance(graph)
    BalanceMode::TB => tb_balance(graph)
  }
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
fn trunc_int(value : Double) -> Int {
  if value >= 0.0 {
    value.floor().to_int()
  } else {
    value.ceil().to_int()
  }
}

///|
fn nodesep_minlen(
  tail_name : String,
  head_name : String,
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  cluster_keys : Map[String, String],
) -> Int {
  let tail_size = sizes.get(tail_name)
  let head_size = sizes.get(head_name)
  let tail_right = match tail_size {
    Some(value) => value.right_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
  let head_left = match head_size {
    Some(value) => value.left_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
  let tail_is_vnode = match tail_size {
    Some(value) => value.height_pt == 0.0
    None => false
  }
  let head_is_vnode = match head_size {
    Some(value) => value.height_pt == 0.0
    None => false
  }
  let same_cluster = match (cluster_keys.get(tail_name), cluster_keys.get(head_name)) {
    (Some(left), Some(right)) => left != "" && left == right
    _ => false
  }
  let sep = if tail_is_vnode || head_is_vnode {
    if same_cluster { 0.0 } else { nodesep_pt }
  } else {
    nodesep_pt
  }
  let minlen = tail_right + head_left + sep
  if minlen <= 0.0 {
    0
  } else {
    minlen.ceil().to_int()
  }
}

///|
fn cluster_margin_pt(graph : @cgraph.Graph) -> Double {
  match graph.get_attr("margin") {
    Some(value) => {
      let margin = parse_first_double(value, CLUSTER_MARGIN_PT)
      if margin < 0.0 {
        CLUSTER_MARGIN_PT
      } else {
        margin
      }
    }
    None => CLUSTER_MARGIN_PT
  }
}

///|
fn unique_cluster_node_name(
  prefix : String,
  cluster_name : String,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = "\{prefix}\{cluster_name}"
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{prefix}\{cluster_name}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
}

///|
fn collect_cluster_graphs(
  graph : @cgraph.Graph,
  parent : String?,
  clusters : Map[String, @cgraph.Graph],
  parents : Map[String, String?],
) -> Unit {
  let mut next_parent = parent
  if is_cluster_graph(graph) {
    match graph.name() {
      Some(name) => {
        clusters[name] = graph
        parents[name] = parent
        next_parent = Some(name)
      }
      None => ()
    }
  }
  for child in graph.subgraphs() {
    collect_cluster_graphs(child, next_parent, clusters, parents)
  }
}

///|
fn collect_graph_nodes(
  graph : @cgraph.Graph,
  nodes_out : Map[String, Bool],
) -> Unit {
  for node in graph.nodes() {
    nodes_out[node.name()] = true
  }
  for child in graph.subgraphs() {
    collect_graph_nodes(child, nodes_out)
  }
}

///|
fn collect_cluster_members(
  cluster_graphs : Map[String, @cgraph.Graph],
) -> Map[String, Map[String, Bool]] {
  let members : Map[String, Map[String, Bool]] = Map::new()
  for name, cluster_graph in cluster_graphs {
    let set : Map[String, Bool] = Map::new()
    collect_graph_nodes(cluster_graph, set)
    if set.length() > 0 {
      members[name] = set
    }
  }
  members
}

///|
///|
fn build_cluster_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  edge_vnodes : Map[String, Array[String]],
) -> (Array[(String, Int)], Array[ConstraintEdge]) {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  if cluster_graphs.length() == 0 {
    return ([], [])
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  if cluster_members.length() == 0 {
    return ([], [])
  }
  let cluster_related : Map[String, Map[String, Bool]] = Map::new()
  let cluster_edges : Map[String, Map[String, Bool]] = Map::new()
  for name, members in cluster_members {
    let related : Map[String, Bool] = Map::new()
    for node_name, _ in members {
      related[node_name] = true
    }
    cluster_related[name] = related
  }
  for name, cluster_graph in cluster_graphs {
    let child_edges : Map[String, Bool] = Map::new()
    for child in cluster_graph.subgraphs() {
      for edge in child.edges() {
        child_edges[edge_key(edge)] = true
      }
    }
    let edges_set : Map[String, Bool] = Map::new()
    for edge in cluster_graph.edges() {
      let key = edge_key(edge)
      if child_edges.get(key) is None {
        edges_set[key] = true
      }
    }
    cluster_edges[name] = edges_set
  }
  if edge_vnodes.length() > 0 {
    for edge in edges {
      let vnodes = match edge_vnodes.get(edge_key(edge)) {
        Some(list) => list
        None => []
      }
      if vnodes.length() == 0 {
        continue
      }
      let tail = edge.tail().name()
      let head = edge.head().name()
      for name, members in cluster_members {
        let tail_in = members.get(tail) is Some(_)
        let head_in = members.get(head) is Some(_)
        let edge_in_cluster = match cluster_edges.get(name) {
          Some(edges_set) => edges_set.get(edge_key(edge)) is Some(_)
          None => false
        }
        if edge_in_cluster || tail_in || head_in {
          match cluster_related.get(name) {
            Some(related) =>
              for vnode in vnodes {
                related[vnode] = true
              }
            None => ()
          }
        }
        if edge_in_cluster {
          for vnode in vnodes {
            members[vnode] = true
          }
        }
      }
    }
  }
  let node_in_any_cluster : Map[String, Bool] = Map::new()
  for _name, members in cluster_members {
    for node_name, _ in members {
      node_in_any_cluster[node_name] = true
    }
  }
  let base_positions = compute_rank_positions(
    rank_keys, groups, sizes, nodesep_pt, has_edge_labels,
  )
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let cluster_nodes : Map[String, (String, String)] = Map::new()
  let cluster_margins : Map[String, Double] = Map::new()
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let extra_nodes : Array[(String, Int)] = []
  let extra_edges : Array[ConstraintEdge] = []
  for name, cluster_graph in cluster_graphs {
    cluster_margins[name] = cluster_margin_pt(cluster_graph)
  }
  for name, members in cluster_members {
    let mut min_rank : Int? = None
    let mut max_rank : Int? = None
    let mut min_left : Double? = None
    let mut max_right : Double? = None
    for node_name, _ in members {
      match ranks.get(node_name) {
        Some(value) => {
          match min_rank {
            Some(current) => if value < current { min_rank = Some(value) }
            None => min_rank = Some(value)
          }
          match max_rank {
            Some(current) => if value > current { max_rank = Some(value) }
            None => max_rank = Some(value)
          }
        }
        None => ()
      }
      match base_positions.get(node_name) {
        Some(pos) => {
          let left_width = node_left_pt(node_name, sizes)
          let right_width = node_right_pt(node_name, sizes)
          let left = pos - left_width
          let right = pos + right_width
          match min_left {
            Some(current) => if left < current { min_left = Some(left) }
            None => min_left = Some(left)
          }
          match max_right {
            Some(current) => if right > current { max_right = Some(right) }
            None => max_right = Some(right)
          }
        }
        None => ()
      }
    }
    match (min_left, max_right) {
      (Some(left), Some(right)) => {
        let ln_name = unique_cluster_node_name(
          CLUSTER_LN_PREFIX,
          name,
          existing_names,
        )
        let rn_name = unique_cluster_node_name(
          CLUSTER_RN_PREFIX,
          name,
          existing_names,
        )
        cluster_nodes[name] = (ln_name, rn_name)
        let margin = match cluster_margins.get(name) {
          Some(value) => value
          None => CLUSTER_MARGIN_PT
        }
        extra_nodes.push((ln_name, trunc_int(left - margin)))
        extra_nodes.push((rn_name, trunc_int(right + margin)))
        match min_rank {
          Some(value) => cluster_min_rank[name] = value
          None => ()
        }
        match max_rank {
          Some(value) => cluster_max_rank[name] = value
          None => ()
        }
      }
      _ => ()
    }
  }
  if cluster_nodes.length() == 0 {
    return ([], [])
  }
  for name, pair in cluster_nodes {
    let (ln_name, rn_name) = pair
    match cluster_graphs.get(name) {
      Some(cluster_graph) =>
        match graph_label_metrics(cluster_graph) {
          Some((width_pt, _height_pt)) => {
            let label_width = width_pt + CLUSTER_LABEL_PAD_PT * 2.0
            let minlen = round_int(label_width)
            if minlen > 0 {
              extra_edges.push({
                tail: ln_name,
                head: rn_name,
                minlen,
                weight: 0,
                tail_port: None,
                head_port: None,
              })
            }
          }
          None => ()
        }
      None => ()
    }
    extra_edges.push({
      tail: ln_name,
      head: rn_name,
      minlen: 1,
      weight: CLUSTER_COMPACT_WEIGHT,
      tail_port: None,
      head_port: None,
    })
    let margin = match cluster_margins.get(name) {
      Some(value) => value
      None => CLUSTER_MARGIN_PT
    }
    match (cluster_members.get(name), cluster_related.get(name)) {
      (Some(members), Some(related)) =>
        for rank in rank_keys {
          let names = match groups.get(rank) {
            Some(list) => list
            None => []
          }
          let mut left_idx = -1
          let mut right_idx = -1
          let mut i = 0
          while i < names.length() {
            let node_name = names[i]
            if members.get(node_name) is Some(_) {
              if left_idx < 0 {
                left_idx = i
              }
              right_idx = i
            }
            i = i + 1
          }
          if left_idx < 0 {
            continue
          }
          let left_name = names[left_idx]
          let right_name = names[right_idx]
          let left_minlen = round_int(
            node_left_pt(left_name, sizes) + margin,
          )
          extra_edges.push({
            tail: ln_name,
            head: left_name,
            minlen: left_minlen,
            weight: 0,
            tail_port: None,
            head_port: None,
          })
          let right_minlen = round_int(
            node_right_pt(right_name, sizes) + margin,
          )
          extra_edges.push({
            tail: right_name,
            head: rn_name,
            minlen: right_minlen,
            weight: 0,
            tail_port: None,
            head_port: None,
          })
          let mut j = left_idx - 1
          while j >= 0 {
            let outside = names[j]
            if related.get(outside) is None {
              // Skip nodes already contained in other clusters; cluster separation already adds bounds.
              if node_in_any_cluster.get(outside) is Some(_) {
                j = j - 1
                continue
              }
              let minlen = round_int(
                node_right_pt(outside, sizes) + margin,
              )
              extra_edges.push({
                tail: outside,
                head: ln_name,
                minlen,
                weight: 0,
                tail_port: None,
                head_port: None,
              })
              break
            }
            j = j - 1
          }
          j = right_idx + 1
          while j < names.length() {
            let outside = names[j]
            if related.get(outside) is None {
              // Skip nodes already contained in other clusters; cluster separation already adds bounds.
              if node_in_any_cluster.get(outside) is Some(_) {
                j = j + 1
                continue
              }
              let minlen = round_int(
                node_left_pt(outside, sizes) + margin,
              )
              extra_edges.push({
                tail: rn_name,
                head: outside,
                minlen,
                weight: 0,
                tail_port: None,
                head_port: None,
              })
              break
            }
            j = j + 1
          }
        }
      _ => ()
    }
  }
  for name, parent in cluster_parents {
    match parent {
      Some(parent_name) =>
        match cluster_nodes.get(parent_name) {
          Some(parent_pair) =>
            match cluster_nodes.get(name) {
              Some(child_pair) => {
                let (parent_ln, parent_rn) = parent_pair
                let (child_ln, child_rn) = child_pair
                let margin = match cluster_margins.get(parent_name) {
                  Some(value) => value
                  None => CLUSTER_MARGIN_PT
                }
                let minlen = round_int(margin)
                extra_edges.push({
                  tail: parent_ln,
                  head: child_ln,
                  minlen,
                  weight: 0,
                  tail_port: None,
                  head_port: None,
                })
                extra_edges.push({
                  tail: child_rn,
                  head: parent_rn,
                  minlen,
                  weight: 0,
                  tail_port: None,
                  head_port: None,
                })
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  let parent_children : Map[String, Array[String]] = Map::new()
  for name, parent in cluster_parents {
    let key = match parent {
      Some(value) => value
      None => ""
    }
    match parent_children.get(key) {
      Some(list) => list.push(name)
      None => parent_children[key] = [name]
    }
  }
  let root_margin = cluster_margin_pt(graph)
  for parent_key, children in parent_children {
    let margin = if parent_key == "" {
      root_margin
    } else {
      match cluster_margins.get(parent_key) {
        Some(value) => value
        None => CLUSTER_MARGIN_PT
      }
    }
    let mut i = 0
    while i + 1 < children.length() {
      let name_i = children[i]
      match cluster_min_rank.get(name_i) {
        None => {
          i = i + 1
          continue
        }
        Some(min_i) =>
          match cluster_max_rank.get(name_i) {
            None => {
              i = i + 1
              continue
            }
            Some(max_i) =>
              match cluster_members.get(name_i) {
                None => {
                  i = i + 1
                  continue
                }
                Some(members_i) => {
                  let mut j = i + 1
                  while j < children.length() {
                    let name_j = children[j]
                    match cluster_min_rank.get(name_j) {
                      None => {
                        j = j + 1
                        continue
                      }
                      Some(min_j) =>
                        match cluster_max_rank.get(name_j) {
                          None => {
                            j = j + 1
                            continue
                          }
                          Some(max_j) =>
                            if min_i <= max_j && min_j <= max_i {
                              match cluster_members.get(name_j) {
                                None => {
                                  j = j + 1
                                  continue
                                }
                                Some(members_j) => {
                                  let start = if min_i > min_j {
                                    min_i
                                  } else {
                                    min_j
                                  }
                                  let end = if max_i < max_j {
                                    max_i
                                  } else {
                                    max_j
                                  }
                                  let mut chosen_first_i = -1
                                  let mut chosen_first_j = -1
                                  let mut r = start
                                  while r <= end {
                                    let names = match groups.get(r) {
                                      Some(list) => list
                                      None => []
                                    }
                                    let mut idx = 0
                                    let mut first_i = -1
                                    let mut first_j = -1
                                    while idx < names.length() &&
                                          (first_i < 0 || first_j < 0) {
                                      let node_name = names[idx]
                                      if first_i < 0 &&
                                        members_i.get(node_name) is Some(_) {
                                        first_i = idx
                                      }
                                      if first_j < 0 &&
                                        members_j.get(node_name) is Some(_) {
                                        first_j = idx
                                      }
                                      idx = idx + 1
                                    }
                                    if first_i >= 0 && first_j >= 0 {
                                      chosen_first_i = first_i
                                      chosen_first_j = first_j
                                      break
                                    }
                                    r = r + 1
                                  }
                                  if chosen_first_i >= 0 && chosen_first_j >= 0 {
                                    let (left_name, right_name) = if chosen_first_i <
                                      chosen_first_j {
                                      (name_i, name_j)
                                    } else {
                                      (name_j, name_i)
                                    }
                                    match cluster_nodes.get(left_name) {
                                      None => {
                                        j = j + 1
                                        continue
                                      }
                                      Some(left_pair) =>
                                        match cluster_nodes.get(right_name) {
                                          None => {
                                            j = j + 1
                                            continue
                                          }
                                          Some(right_pair) => {
                                            let (_left_ln, left_rn) = left_pair
                                            let (right_ln, _right_rn) = right_pair
                                            let minlen = round_int(margin)
                                            extra_edges.push({
                                              tail: left_rn,
                                              head: right_ln,
                                              minlen,
                                              weight: 0,
                                              tail_port: None,
                                              head_port: None,
                                            })
                                          }
                                        }
                                    }
                                  }
                                }
                              }
                            }
                        }
                    }
                    j = j + 1
                  }
                }
              }
          }
      }
      i = i + 1
    }
  }
  (extra_nodes, extra_edges)
}

///|
fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
) -> Map[String, Map[String, RecordPort]] {
  let offsets : Map[String, Map[String, RecordPort]] = Map::new()
  let rankdir = if nodes.length() > 0 {
    graph_rankdir(nodes[0].graph())
  } else {
    RankDir::TB
  }
  let record_orientation = record_layout_orientation(rankdir)
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  for node in nodes {
    let name = node.name()
    let base_size = node_size(node, record_orientation)
    let ports = if is_record_shape(node) {
      record_ports(node, origin, base_size, record_orientation)
    } else {
      html_ports(node, origin, base_size)
    }
    if ports.length() > 0 {
      let node_offsets : Map[String, RecordPort] = Map::new()
      for port_name, port_info in ports {
        let offset = layout_port_offset(port_info.center, rankdir)
        let size = match rankdir {
          RankDir::LR | RankDir::RL => swap_node_size(port_info.size)
          _ => port_info.size
        }
        node_offsets[port_name] = { center: offset, size }
      }
      offsets[name] = node_offsets
    }
  }
  offsets
}

///|
fn compass_port_offset(
  compass : @cgraph.Compass,
  node_name : String,
  sizes : Map[String, NodeSize],
) -> Double {
  match compass {
    @cgraph.Compass::E
    | @cgraph.Compass::NE
    | @cgraph.Compass::SE => node_right_pt(node_name, sizes)
    @cgraph.Compass::W
    | @cgraph.Compass::NW
    | @cgraph.Compass::SW => -node_left_pt(node_name, sizes)
    _ => 0.0
  }
}

///|
fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
) -> Double {
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match offsets.get(node_name) {
            Some(node_offsets) =>
              match node_offsets.get(name) {
                Some(port_info) =>
                  match value.compass {
                    Some(compass) =>
                      match compass {
                        @cgraph.Compass::E
                        | @cgraph.Compass::NE
                        | @cgraph.Compass::SE => {
                          let half = port_info.size.width_pt / 2.0
                          port_info.center.x + half
                        }
                        @cgraph.Compass::W
                        | @cgraph.Compass::NW
                        | @cgraph.Compass::SW => {
                          let half = port_info.size.width_pt / 2.0
                          port_info.center.x - half
                        }
                        _ => port_info.center.x
                      }
                    None => port_info.center.x
                  }
                None =>
                  match value.compass {
                    Some(compass) => compass_port_offset(compass, node_name, sizes)
                    None => 0.0
                  }
              }
            None =>
              match value.compass {
                Some(compass) => compass_port_offset(compass, node_name, sizes)
                None => 0.0
              }
          }
        None =>
          match value.compass {
            Some(compass) => compass_port_offset(compass, node_name, sizes)
            None => 0.0
          }
      }
    None => 0.0
  }
}

///|
fn edge_port_offset_by_name(
  node_name : String,
  port_name : String?,
  offsets : Map[String, Map[String, RecordPort]],
) -> Double {
  match port_name {
    Some(name) =>
      match offsets.get(node_name) {
        Some(node_offsets) =>
          match node_offsets.get(name) {
            Some(port_info) => port_info.center.x
            None => 0.0
          }
        None => 0.0
      }
    None => 0.0
  }
}

///|
fn build_constraint_graph(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  extra_nodes : Array[(String, Int)],
  extra_edges : Array[ConstraintEdge],
  extra_slack_edges : Array[ConstraintEdge],
  edge_vnodes : Map[String, Array[String]],
) -> (NsGraph, Map[String, Int]) {
  let graph = new_graph()
  let ordered_nodes = nodes
  let outgoing_edges : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    match outgoing_edges.get(tail) {
      Some(list) => list.push(edge)
      None => outgoing_edges[tail] = [edge]
    }
  }
  let port_offsets = port_offsets_for_nodes(ordered_nodes)
  let actual_names : Map[String, Bool] = Map::new()
  for node in ordered_nodes {
    actual_names[node.name()] = true
  }
  let slack_edges : Array[@cgraph.Edge] = []
  let intercluster_seen : Map[String, Bool] = Map::new()
  for node in ordered_nodes {
    let tail_name = node.name()
    let list = match outgoing_edges.get(tail_name) {
      Some(value) => value
      None => []
    }
    for edge in list {
      match edge_vnodes.get(edge_key(edge)) {
        Some(_) => continue
        None => ()
      }
      let head_name = edge.head().name()
      let tail_cluster = match cluster_keys.get(tail_name) {
        Some(value) => value
        None => ""
      }
      let head_cluster = match cluster_keys.get(head_name) {
        Some(value) => value
        None => ""
      }
      if tail_cluster != head_cluster && (tail_cluster != "" || head_cluster != "") {
        let tail_rank = match ranks.get(tail_name) {
          Some(value) => value
          None => 0
        }
        let head_rank = match ranks.get(head_name) {
          Some(value) => value
          None => 0
        }
        let key = intercluster_edge_key(
          tail_cluster,
          head_cluster,
          tail_rank,
          head_rank,
        )
        if intercluster_seen.get(key) is Some(_) {
          continue
        }
        intercluster_seen[key] = true
      }
      slack_edges.push(edge)
    }
  }
  let slack_indices : Array[Int] = []
  for _ in 0..<slack_edges.length() {
    slack_indices.push(0)
  }
  let mut slack_rev = slack_edges.length()
  while slack_rev > 0 {
    slack_rev = slack_rev - 1
    let slack_idx = add_node(graph, "")
    slack_indices[slack_rev] = slack_idx
  }
  let base_positions = compute_rank_positions(
    rank_keys, groups, sizes, nodesep_pt, has_edge_labels,
  )
  let index : Map[String, Int] = Map::new()
  for node in ordered_nodes {
    let name = node.name()
    let idx = add_node(graph, name)
    index[name] = idx
    let pos = match base_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    graph.nodes[idx].rank = trunc_int(pos)
  }
  for pair in extra_nodes {
    let (name, rank) = pair
    let idx = add_node(graph, name)
    index[name] = idx
    let pos = match base_positions.get(name) {
      Some(value) => value
      None => rank.to_double()
    }
    graph.nodes[idx].rank = trunc_int(pos)
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let rank_nodesep = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
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
      let minlen = nodesep_minlen(
        tail,
        head,
        sizes,
        rank_nodesep,
        cluster_keys,
      )
      let _ = add_edge(graph, tail_idx, head_idx, minlen, 0)
      i = i + 1
    }
  }
  for edge in extra_edges {
    match index.get(edge.tail) {
      Some(tail_idx) =>
        match index.get(edge.head) {
          Some(head_idx) => {
            let _ = add_edge(
              graph,
              tail_idx,
              head_idx,
              edge.minlen,
              edge.weight,
            )

          }
          None => ()
        }
      None => ()
    }
  }
  ignore(ranks)
  for i in 0..<slack_edges.length() {
    let edge = slack_edges[i]
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let (tail_node, use_tail_port) =
      (tail_name, actual_names.get(tail_name) is Some(_))
    let (head_node, use_head_port) =
      (head_name, actual_names.get(head_name) is Some(_))
    let tail_idx = match index.get(tail_node) {
      Some(value) => value
      None => 0
    }
    let head_idx = match index.get(head_node) {
      Some(value) => value
      None => 0
    }
    let slack_idx = slack_indices[i]
    let tail_offset =
      if use_tail_port {
        edge_port_offset(
          tail_name,
          edge.tail_port(),
          port_offsets,
          sizes,
        )
      } else {
        0.0
      }
    let head_offset =
      if use_head_port {
        edge_port_offset(
          head_name,
          edge.head_port(),
          port_offsets,
          sizes,
        )
      } else {
        0.0
      }
    let delta = head_offset - tail_offset
    let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
    let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
    let tail_rank = graph.nodes[tail_idx].rank
    let head_rank = graph.nodes[head_idx].rank
    let base_tail = tail_rank - m0 - 1
    let base_head = head_rank - m1 - 1
    graph.nodes[slack_idx].rank = if base_tail < base_head {
      base_tail
    } else {
      base_head
    }
    let weight = edge_weight(edge)
    let _ = add_edge(graph, slack_idx, tail_idx, m0 + 1, weight)
    let _ = add_edge(graph, slack_idx, head_idx, m1 + 1, weight)

  }
  for extra in extra_slack_edges {
    let (tail_node, use_tail_port) =
      (extra.tail, actual_names.get(extra.tail) is Some(_))
    let (head_node, use_head_port) =
      (extra.head, actual_names.get(extra.head) is Some(_))
    let tail_port = if use_tail_port { extra.tail_port } else { None }
    let head_port = if use_head_port { extra.head_port } else { None }
    let tail_idx = match index.get(tail_node) {
      Some(value) => value
      None => 0
    }
    let head_idx = match index.get(head_node) {
      Some(value) => value
      None => 0
    }
    let slack_idx = add_node(graph, "")
    let tail_offset = edge_port_offset_by_name(
      tail_node,
      tail_port,
      port_offsets,
    )
    let head_offset = edge_port_offset_by_name(
      head_node,
      head_port,
      port_offsets,
    )
    let delta = head_offset - tail_offset
    let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
    let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
    let tail_rank = graph.nodes[tail_idx].rank
    let head_rank = graph.nodes[head_idx].rank
    let minlen = if extra.minlen > 0 { extra.minlen } else { 1 }
    let base_tail = tail_rank - m0 - minlen
    let base_head = head_rank - m1 - minlen
    graph.nodes[slack_idx].rank = if base_tail < base_head {
      base_tail
    } else {
      base_head
    }
    let _ = add_edge(graph, slack_idx, tail_idx, m0 + minlen, extra.weight)
    let _ = add_edge(graph, slack_idx, head_idx, m1 + minlen, extra.weight)

  }
  (graph, index)
}

///|
fn x_positions_from_simplex(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  extra_nodes : Array[(String, Int)],
  extra_edges : Array[ConstraintEdge],
  extra_slack_edges : Array[ConstraintEdge],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Double] {
  let (graph, index) = build_constraint_graph(
    nodes,
    edges,
    ranks,
    rank_keys,
    groups,
    sizes,
    cluster_keys,
    nodesep_pt,
    has_edge_labels,
    extra_nodes,
    extra_edges,
    extra_slack_edges,
    edge_vnodes,
  )
  network_simplex(graph, 0x7fffffff, BalanceMode::LR)
  let positions : Map[String, Double] = Map::new()
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    positions[name] = graph.nodes[idx].rank.to_double()
  }
  for pair in extra_nodes {
    let (name, _rank) = pair
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
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  extra_nodes : Array[(String, Int)],
  edge_vnodes : Map[String, Array[String]],
  extra_slack_edges : Array[ConstraintEdge],
) -> Map[String, Double] {
  let (cluster_nodes, extra_edges) = build_cluster_constraints(
    graph, nodes, edges, ranks, rank_keys, groups, sizes, nodesep_pt, has_edge_labels,
    edge_vnodes,
  )
  let all_extra_nodes = extra_nodes.copy()
  for pair in cluster_nodes {
    all_extra_nodes.push(pair)
  }
  x_positions_from_simplex(
    nodes,
    edges,
    ranks,
    rank_keys,
    groups,
    sizes,
    cluster_keys,
    nodesep_pt,
    has_edge_labels,
    all_extra_nodes,
    extra_edges,
    extra_slack_edges,
    edge_vnodes,
  )
}
