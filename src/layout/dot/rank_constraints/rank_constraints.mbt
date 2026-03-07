///|
/// Graphviz rank-constraint and nlist-order helpers shared by rank assignment
/// and ordering stages.

///|
pub fn parse_flat_constraint_key(key : String) -> (String, String)? {
  match key.find("|") {
    Some(pos) => {
      let len = key.length()
      let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
      let head =
        if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
          ""
        }
      Some((tail, head))
    }
    None => None
  }
}

///|
/// Graphviz parity: approximate decompose DFS order over fast graph edges.
/// Do not change behavior without updating fixtures/tests.
pub fn build_graphviz_nlist_order_from_edges(
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
  // Graphviz parity: ND_out/ND_in lists follow edge sequence (AGSEQ) order
  // within a fixed tail/head, so preserve edge_creation insertion order.
  // Do not change behavior without updating fixtures/tests.
  for key, _ in flat_constraints {
    match parse_flat_constraint_key(key) {
      Some((tail, head)) => {
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
  let visit_from = (start : String) => {
    if visited.get(start) == Some(true) {
      return ()
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
  // Graphviz parity: agfstnode iteration follows creation order.
  for start in tail_order {
    visit_from(start)
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
/// Graphviz parity: rank=same merges nodes into one representative set.
/// Do not change behavior without updating fixtures/tests.
pub fn build_rank_same_reps(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
) -> Map[String, String] {
  let parent : Map[String, String] = Map::new()
  for node in nodes {
    let name = node.name()
    parent[name] = name
  }
  let find = (name : String) => {
    let mut current = name
    let mut next = match parent.get(current) {
      Some(value) => value
      None => current
    }
    while next != current {
      current = next
      next = match parent.get(current) {
        Some(value) => value
        None => current
      }
    }
    // Path compression
    let mut cursor = name
    let mut parent_name = match parent.get(cursor) {
      Some(value) => value
      None => cursor
    }
    while parent_name != current {
      parent[cursor] = current
      cursor = parent_name
      parent_name = match parent.get(cursor) {
        Some(value) => value
        None => current
      }
    }
    current
  }
  let union = (a : String, b : String) => {
    let ra = find(a)
    let rb = find(b)
    if ra != rb {
      parent[rb] = ra
    }
  }
  let stack : Array[@cgraph.Graph] = [graph]
  while stack.length() > 0 {
    let current = stack[stack.length() - 1]
    let _ = stack.pop()
    match current.get_attr("rank") {
      Some(value) => {
        let rank_value = value.to_lower()
        if rank_value == "same" ||
          rank_value == "min" ||
          rank_value == "max" ||
          rank_value == "source" ||
          rank_value == "sink" {
          // Graphviz parity: collapse_rankset merges same/min/max/source/sink
          // subgraph members into one representative before ranking.
          let members = current.nodes()
          let mut leader : String? = None
          for node in members {
            let name = node.name()
            if parent.get(name) is None {
              continue
            }
            match leader {
              Some(lead) => union(lead, name)
              None => leader = Some(name)
            }
          }
          // Graphviz parity: rankset edge statements imply endpoint membership;
          // include their endpoints when explicit node statements are omitted.
          for edge in current.edges() {
            let tail_name = edge.tail().name()
            if parent.get(tail_name) is Some(_) {
              match leader {
                Some(lead) => union(lead, tail_name)
                None => leader = Some(tail_name)
              }
            }
            let head_name = edge.head().name()
            if parent.get(head_name) is Some(_) {
              match leader {
                Some(lead) => union(lead, head_name)
                None => leader = Some(head_name)
              }
            }
          }
        }
      }
      None => ()
    }
    for child in current.subgraphs() {
      stack.push(child)
    }
  }
  let reps : Map[String, String] = Map::new()
  for name, _ in parent {
    reps[name] = find(name)
  }
  reps
}
