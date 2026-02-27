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
