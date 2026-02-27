///|
fn resolve_rank_group_component_order_index(
  name : String,
  node_order : Map[String, Int],
  fallback_order : Map[String, Int],
) -> Int {
  match node_order.get(name) {
    Some(value) => value
    None =>
      match fallback_order.get(name) {
        Some(value) => value
        None => 0
      }
  }
}

///|
fn build_rank_group_component_discovery_order(
  nodes : Array[String],
  node_order : Map[String, Int],
) -> (Array[String], Map[String, Int]) {
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in nodes {
    fallback_order[name] = i
  }
  let ordered_nodes = nodes.copy()
  if ordered_nodes.length() > 1 {
    ordered_nodes.sort_by((a, b) => {
      let a_idx = resolve_rank_group_component_order_index(
        a,
        node_order,
        fallback_order,
      )
      let b_idx = resolve_rank_group_component_order_index(
        b,
        node_order,
        fallback_order,
      )
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
  }
  (ordered_nodes, fallback_order)
}

///|
fn build_rank_group_component_discovery_neighbors(
  nodes : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
) -> (
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Bool],
) {
  let node_set : Map[String, Bool] = Map::new()
  for name in nodes {
    node_set[name] = true
  }
  let mut use_graphviz_neighbors = false
  for _key, _ in graphviz_out_neighbors {
    use_graphviz_neighbors = true
    break
  }
  if !use_graphviz_neighbors {
    for _key, _ in graphviz_in_neighbors {
      use_graphviz_neighbors = true
      break
    }
  }
  let out_neighbors : Map[String, Array[String]] = Map::new()
  let in_neighbors : Map[String, Array[String]] = Map::new()
  for name in nodes {
    out_neighbors[name] = []
    in_neighbors[name] = []
  }
  if use_graphviz_neighbors {
    for name in nodes {
      match graphviz_out_neighbors.get(name) {
        Some(list) => out_neighbors[name] = list.copy()
        None => ()
      }
      match graphviz_in_neighbors.get(name) {
        Some(list) => in_neighbors[name] = list.copy()
        None => ()
      }
    }
  } else {
    for idx in 0..<edge_tail.length() {
      let tail = edge_tail[idx]
      let head = edge_head[idx]
      if node_set.get(tail) is None || node_set.get(head) is None {
        continue
      }
      match out_neighbors.get(tail) {
        Some(list) => list.push(head)
        None => out_neighbors[tail] = [head]
      }
      match in_neighbors.get(head) {
        Some(list) => list.push(tail)
        None => in_neighbors[head] = [tail]
      }
    }
  }
  (out_neighbors, in_neighbors, node_set)
}

///|
fn collect_rank_group_component_skeleton_nodes(
  ordered_nodes : Array[String],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  fallback_order : Map[String, Int],
) -> Map[String, Array[String]] {
  let cluster_skeleton_nodes : Map[String, Array[String]] = Map::new()
  for name in ordered_nodes {
    if cluster_skeleton.get(name) == Some(true) {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster != "" {
        match cluster_skeleton_nodes.get(cluster) {
          Some(list) => list.push(name)
          None => cluster_skeleton_nodes[cluster] = [name]
        }
      }
    }
  }
  for _key, list in cluster_skeleton_nodes {
    if list.length() > 1 {
      list.sort_by((a, b) => {
        let a_rank = match node_ranks.get(a) {
          Some(value) => value
          None => 0
        }
        let b_rank = match node_ranks.get(b) {
          Some(value) => value
          None => 0
        }
        if a_rank < b_rank {
          -1
        } else if a_rank > b_rank {
          1
        } else {
          let a_idx = resolve_rank_group_component_order_index(
            a,
            node_order,
            fallback_order,
          )
          let b_idx = resolve_rank_group_component_order_index(
            b,
            node_order,
            fallback_order,
          )
          if a_idx < b_idx {
            -1
          } else if a_idx > b_idx {
            1
          } else {
            0
          }
        }
      })
    }
  }
  cluster_skeleton_nodes
}

///|
fn build_rank_group_component_flat_constraint_neighbors(
  nodes : Array[String],
  node_set : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for name in nodes {
    flat_out[name] = []
    flat_in[name] = []
  }
  for key, value in flat_constraints {
    if !value {
      continue
    }
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
        if tail == "" || head == "" {
          continue
        }
        if node_set.get(tail) is None || node_set.get(head) is None {
          continue
        }
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
  (flat_out, flat_in)
}
