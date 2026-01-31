///|
const NONE_EDGE : Int = -1

///|
const NO_HEAP : Int = -1

///|
pub(all) enum BalanceMode {
  LR
  TB
}

///|
pub(all) enum NodeKind {
  Normal
  Virtual
  Slack
} derive(Eq)

///|
let root_override : Ref[Int?] = Ref::new(None)

///|
pub(all) struct NsEdge {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
  mut cutvalue : Int
  mut tree_index : Int
}

///|
pub(all) struct NsNode {
  kind : NodeKind
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
pub(all) struct NsGraph {
  nodes : Array[NsNode]
  edges : Array[NsEdge]
  tree_edges : Array[Int]
}

///|
pub fn new_graph() -> NsGraph {
  { nodes: [], edges: [], tree_edges: [] }
}

///|
pub fn add_node(
  graph : NsGraph,
  _name : String,
  kind? : NodeKind = NodeKind::Normal,
) -> Int {
  let idx = graph.nodes.length()
  graph.nodes.push({
    kind: kind,
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
pub fn add_edge(
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
pub fn node_rank(graph : NsGraph, idx : Int) -> Int {
  graph.nodes[idx].rank
}

///|
pub fn set_node_rank(graph : NsGraph, idx : Int, rank : Int) -> Unit {
  graph.nodes[idx].rank = rank
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
priv struct CutState {
  node : Int
  parent_edge : Int
  mut tree_out_i : Int
  mut tree_in_i : Int
}

///|
priv struct InterTreeState {
  node : Int
  parent : Int
  mut out_i : Int
  mut in_i : Int
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
  let stack : Array[InterTreeState] = [{ node: v, parent: from, out_i: 0, in_i: 0 }]
  while stack.length() > 0 {
    let last = stack.length() - 1
    let state = stack[last]
    let mut allow_descend = true
    match current {
      Some(edge_idx) =>
        if edge_slack(graph, edge_idx) == 0 {
          allow_descend = false
        }
      None => ()
    }
    let mut pushed = false
    while state.out_i < graph.nodes[state.node].out_edges.length() {
      let edge_idx = graph.nodes[state.node].out_edges[state.out_i]
      state.out_i = state.out_i + 1
      if is_tree_edge(graph, edge_idx) {
        let head = graph.edges[edge_idx].head
        if allow_descend && head != state.parent {
          stack[last] = state
          stack.push({ node: head, parent: state.node, out_i: 0, in_i: 0 })
          pushed = true
          break
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
    if pushed {
      continue
    }
    while state.in_i < graph.nodes[state.node].in_edges.length() {
      let edge_idx = graph.nodes[state.node].in_edges[state.in_i]
      state.in_i = state.in_i + 1
      if is_tree_edge(graph, edge_idx) {
        let tail = graph.edges[edge_idx].tail
        if allow_descend && tail != state.parent {
          stack[last] = state
          stack.push({ node: tail, parent: state.node, out_i: 0, in_i: 0 })
          pushed = true
          break
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
    if pushed {
      continue
    }
    let _ = stack.pop()
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
  let stack : Array[CutState] = [
    { node: node_idx, parent_edge, tree_out_i: 0, tree_in_i: 0 },
  ]
  while stack.length() > 0 {
    let last = stack.length() - 1
    let state = stack[last]
    let mut pushed = false
    while state.tree_out_i < graph.nodes[state.node].tree_out.length() {
      let edge_idx = graph.nodes[state.node].tree_out[state.tree_out_i]
      state.tree_out_i = state.tree_out_i + 1
      if edge_idx == state.parent_edge {
        continue
      }
      let head = graph.edges[edge_idx].head
      stack[last] = state
      stack.push({
        node: head,
        parent_edge: edge_idx,
        tree_out_i: 0,
        tree_in_i: 0,
      })
      pushed = true
      break
    }
    if pushed {
      continue
    }
    while state.tree_in_i < graph.nodes[state.node].tree_in.length() {
      let edge_idx = graph.nodes[state.node].tree_in[state.tree_in_i]
      state.tree_in_i = state.tree_in_i + 1
      if edge_idx == state.parent_edge {
        continue
      }
      let tail = graph.edges[edge_idx].tail
      stack[last] = state
      stack.push({
        node: tail,
        parent_edge: edge_idx,
        tree_out_i: 0,
        tree_in_i: 0,
      })
      pushed = true
      break
    }
    if pushed {
      continue
    }
    if state.parent_edge != NONE_EDGE {
      x_cutval(graph, state.parent_edge)
    }
    let _ = stack.pop()
  }
}

///|
fn init_cutvalues(graph : NsGraph) -> Unit {
  if graph.nodes.length() == 0 {
    return ()
  }
  let root = match root_override.val {
    Some(value) => value
    None => 0
  }
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
  let stack : Array[Int] = [node_idx]
  while stack.length() > 0 {
    let v = stack[stack.length() - 1]
    let _ = stack.pop()
    graph.nodes[v].rank = graph.nodes[v].rank - delta
    let parent_edge = graph.nodes[v].par_edge
    for edge_idx in graph.nodes[v].tree_out {
      if edge_idx == parent_edge {
        continue
      }
      stack.push(graph.edges[edge_idx].head)
    }
    for edge_idx in graph.nodes[v].tree_in {
      if edge_idx == parent_edge {
        continue
      }
      stack.push(graph.edges[edge_idx].tail)
    }
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
    if node.kind != NodeKind::Normal {
      continue
    }
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
fn sort_nodes_by_rank(graph : NsGraph, nodes : Array[Int]) -> Unit {
  if nodes.length() <= 1 {
    return ()
  }
  let tmp : Array[Int] = []
  for _ in 0..<nodes.length() {
    tmp.push(0)
  }
  merge_sort_nodes_by_rank(graph, nodes, tmp, 0, nodes.length())
}

///|
fn merge_sort_nodes_by_rank(
  graph : NsGraph,
  nodes : Array[Int],
  tmp : Array[Int],
  lo : Int,
  hi : Int,
) -> Unit {
  if hi - lo <= 1 {
    return ()
  }
  let mid = (lo + hi) / 2
  merge_sort_nodes_by_rank(graph, nodes, tmp, lo, mid)
  merge_sort_nodes_by_rank(graph, nodes, tmp, mid, hi)
  let mut i = lo
  let mut j = mid
  let mut k = lo
  while i < mid && j < hi {
    let left = nodes[i]
    let right = nodes[j]
    let left_rank = graph.nodes[left].rank
    let right_rank = graph.nodes[right].rank
    if left_rank <= right_rank {
      tmp[k] = left
      i = i + 1
    } else {
      tmp[k] = right
      j = j + 1
    }
    k = k + 1
  }
  while i < mid {
    tmp[k] = nodes[i]
    i = i + 1
    k = k + 1
  }
  while j < hi {
    tmp[k] = nodes[j]
    j = j + 1
    k = k + 1
  }
  let mut idx = lo
  while idx < hi {
    nodes[idx] = tmp[idx]
    idx = idx + 1
  }
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
    if node.kind == NodeKind::Normal {
      let rank = node.rank
      if rank >= 0 && rank <= max_rank {
        nrank[rank] = nrank[rank] + 1
      }
    }
  }
  let ordered : Array[Int] = []
  for i in 0..<graph.nodes.length() {
    ordered.push(i)
  }
  sort_nodes_by_rank(graph, ordered)
  for idx in ordered {
    let node = graph.nodes[idx]
    if node.kind != NodeKind::Normal {
      continue
    }
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
fn network_simplex_core(graph : NsGraph, max_iter : Int) -> Bool {
  let feasible = init_graph(graph)
  if !feasible {
    init_rank(graph)
  }
  if !feasible_tree(graph) {
    if @sys.get_env_var("DOT_TRACE") is Some(_) {
      println("xpos: feasible_tree failed")
    }
    return false
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
  true
}

///|
pub fn network_simplex(
  graph : NsGraph,
  max_iter : Int,
  balance : BalanceMode,
) -> Unit {
  if !network_simplex_core(graph, max_iter) {
    return ()
  }
  match balance {
    BalanceMode::LR => lr_balance(graph)
    BalanceMode::TB => tb_balance(graph)
  }
}

///|
pub fn network_simplex_with_root(
  graph : NsGraph,
  max_iter : Int,
  balance : BalanceMode,
  root_idx : Int,
) -> Unit {
  let prev = root_override.val
  root_override.val = Some(root_idx)
  network_simplex(graph, max_iter, balance)
  root_override.val = prev
}

///|
pub fn network_simplex_pre_balance(graph : NsGraph, max_iter : Int) -> Bool {
  network_simplex_core(graph, max_iter)
}

///|
pub fn normalize_ranks_for_test(graph : NsGraph) -> Int {
  normalize_ranks(graph)
}

///|
pub fn build_feasible_tree(graph : NsGraph) -> Bool {
  let feasible = init_graph(graph)
  if !feasible {
    init_rank(graph)
  }
  feasible_tree(graph)
}

///|
