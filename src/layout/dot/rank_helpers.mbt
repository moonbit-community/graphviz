///|
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
fn add_rank_same_constraints(
  rank_graph : NsGraph,
  index : Map[String, Int],
  subgraph : @cgraph.Graph,
) -> Unit {
  match subgraph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let nodes = subgraph.nodes()
        if nodes.length() > 1 {
          // Graphviz parity: rank=same collapses nodes into a single set;
          // a star of zero-length constraints preserves equality without
          // quadratic edge blowup.
          let mut leader_idx = -1
          let mut leader_pos = 0
          while leader_pos < nodes.length() {
            let name = nodes[leader_pos].name()
            match index.get(name) {
              Some(value) => {
                leader_idx = value
                break
              }
              None => ()
            }
            leader_pos = leader_pos + 1
          }
          if leader_idx >= 0 {
            let mut i = 0
            while i < nodes.length() {
              let name_i = nodes[i].name()
              let idx_i = match index.get(name_i) {
                Some(value) => value
                None => -1
              }
              if idx_i >= 0 && idx_i != leader_idx {
                let _ = add_edge(rank_graph, leader_idx, idx_i, 0, 1000)
                let _ = add_edge(rank_graph, idx_i, leader_idx, 0, 1000)
              }
              i = i + 1
            }
          }
        }
      }
    None => ()
  }
  for child in subgraph.subgraphs() {
    add_rank_same_constraints(rank_graph, index, child)
  }
}

///|
/// Graphviz parity: rank=same merges nodes into a single union set (rank.c).
/// Do not change behavior without updating fixtures/tests.
fn build_rank_same_reps(
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
