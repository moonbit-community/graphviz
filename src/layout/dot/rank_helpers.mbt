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
          let mut i = 0
          while i < nodes.length() {
            let name_i = nodes[i].name()
            let idx_i = match index.get(name_i) {
              Some(value) => value
              None => -1
            }
            if idx_i >= 0 {
              let mut j = i + 1
              while j < nodes.length() {
                let name_j = nodes[j].name()
                let idx_j = match index.get(name_j) {
                  Some(value) => value
                  None => -1
                }
                if idx_j >= 0 {
                  let _ = add_edge(rank_graph, idx_i, idx_j, 0, 1000)
                  let _ = add_edge(rank_graph, idx_j, idx_i, 0, 1000)

                }
                j = j + 1
              }
            }
            i = i + 1
          }
        }
      }
    None => ()
  }
  for child in subgraph.subgraphs() {
    add_rank_same_constraints(rank_graph, index, child)
  }
}
