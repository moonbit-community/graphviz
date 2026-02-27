///|
/// Graphviz parity: build_ranks/enqueue_neighbors ordering from ND_out/ND_in lists (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_rank_groups_graphviz(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  pass : Int,
  flip? : Bool = false,
  graphviz_out_neighbors? : Map[String, Array[String]] = Map::new(),
  graphviz_in_neighbors? : Map[String, Array[String]] = Map::new(),
) -> Map[Int, Array[String]] {
  let ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    ordered[rank] = []
  }
  let nodes : Array[String] = []
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      nodes.push(name)
    }
  }
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in nodes {
    fallback_order[name] = i
  }
  let nlist = nodes.copy()
  if nlist.length() > 1 {
    nlist.sort_by((a, b) => {
      let a_idx = match node_order.get(a) {
        Some(value) => value
        None =>
          match fallback_order.get(a) {
            Some(value) => value
            None => 0
          }
      }
      let b_idx = match node_order.get(b) {
        Some(value) => value
        None =>
          match fallback_order.get(b) {
            Some(value) => value
            None => 0
          }
      }
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
  }
  let out_neighbors : Map[String, Array[String]] = Map::new()
  let in_neighbors : Map[String, Array[String]] = Map::new()
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
  if use_graphviz_neighbors {
    for name in nlist {
      match graphviz_out_neighbors.get(name) {
        Some(list) => out_neighbors[name] = list.copy()
        None => out_neighbors[name] = []
      }
      match graphviz_in_neighbors.get(name) {
        Some(list) => in_neighbors[name] = list.copy()
        None => in_neighbors[name] = []
      }
    }
  } else {
    for name in nlist {
      out_neighbors[name] = []
      in_neighbors[name] = []
    }
    for edge_idx in 0..<edge_tail.length() {
      let tail = edge_tail[edge_idx]
      let head = edge_head[edge_idx]
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
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  let cluster_has_skeleton : Map[String, Bool] = Map::new()
  for name in nlist {
    if cluster_skeleton.get(name) == Some(true) {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster != "" {
        cluster_has_skeleton[cluster] = true
      }
    }
  }
  for name in nlist {
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster != "" && cluster_has_skeleton.get(cluster) == Some(true) &&
      cluster_skeleton.get(name) == Some(true) {
      // Graphviz parity: install_cluster only enqueues rankleader (skeleton) nodes,
      // not all nodes in the cluster.
      match cluster_nodes.get(cluster) {
        Some(list) => list.push(name)
        None => cluster_nodes[cluster] = [name]
      }
    }
  }
  for _key, list in cluster_nodes {
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
          let a_idx = match node_order.get(a) {
            Some(value) => value
            None =>
              match fallback_order.get(a) {
                Some(value) => value
                None => 0
              }
          }
          let b_idx = match node_order.get(b) {
            Some(value) => value
            None =>
              match fallback_order.get(b) {
                Some(value) => value
                None => 0
              }
          }
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
  let installed : Map[String, Bool] = Map::new()
  let marks : Map[String, Bool] = Map::new()
  let installed_clusters : Map[String, Bool] = Map::new()
  for node in nlist {
    let other =
      if pass == 0 {
        match in_neighbors.get(node) {
          Some(list) => list
          None => []
        }
      } else {
        match out_neighbors.get(node) {
          Some(list) => list
          None => []
        }
      }
    if other.length() > 0 {
      continue
    }
    if marks.get(node) == Some(true) {
      continue
    }
    marks[node] = true
    let queue : Array[String] = [node]
    let mut q_idx = 0
    while q_idx < queue.length() {
      let current = queue[q_idx]
      q_idx = q_idx + 1
      let cluster = match cluster_keys.get(current) {
        Some(value) => value
        None => ""
      }
      if cluster != "" && installed_clusters.get(cluster) != Some(true) {
        // Graphviz parity (fixtures): install_cluster triggers when a cluster node
        // is visited and inserts the pre-collected cluster queue for that cluster.
        installed_clusters[cluster] = true
        let cluster_list = match cluster_nodes.get(cluster) {
          Some(list) => list
          None => []
        }
        for cluster_node in cluster_list {
          if installed.get(cluster_node) != Some(true) {
            let rank = match node_ranks.get(cluster_node) {
              Some(value) => value
              None => 0
            }
            match ordered.get(rank) {
              Some(list) => list.push(cluster_node)
              None => ordered[rank] = [cluster_node]
            }
            installed[cluster_node] = true
          }
          marks[cluster_node] = true
        }
        for cluster_node in cluster_list {
          let neighbors =
            if pass == 0 {
              match out_neighbors.get(cluster_node) {
                Some(list) => list
                None => []
              }
            } else {
              match in_neighbors.get(cluster_node) {
                Some(list) => list
                None => []
              }
            }
          for neighbor in neighbors {
            if marks.get(neighbor) != Some(true) {
              marks[neighbor] = true
              queue.push(neighbor)
            }
          }
        }
      }
      // Graphviz parity: rankleader/skeleton nodes are installed like other
      // nodes once discovered in the component walk.
      if installed.get(current) != Some(true) {
        let rank = match node_ranks.get(current) {
          Some(value) => value
          None => 0
        }
        match ordered.get(rank) {
          Some(list) => list.push(current)
          None => ordered[rank] = [current]
        }
        installed[current] = true
      }
      let neighbors =
        if pass == 0 {
          match out_neighbors.get(current) {
            Some(list) => list
            None => []
          }
        } else {
          match in_neighbors.get(current) {
            Some(list) => list
            None => []
          }
        }
      for neighbor in neighbors {
        if marks.get(neighbor) != Some(true) {
          marks[neighbor] = true
          queue.push(neighbor)
        }
      }
    }
  }
  for name in nlist {
    if installed.get(name) != Some(true) {
      let rank = match node_ranks.get(name) {
        Some(value) => value
        None => 0
      }
      match ordered.get(rank) {
        Some(list) => list.push(name)
        None => ordered[rank] = [name]
      }
      installed[name] = true
    }
  }
  // Graphviz parity: flip reverses each rank order (mincross.c install_in_rank).
  if flip {
    for rank, names in ordered {
      if names.length() > 1 {
        let reversed : Array[String] = []
        let mut idx = names.length()
        while idx > 0 {
          idx = idx - 1
          reversed.push(names[idx])
        }
        ordered[rank] = reversed
      }
    }
  }
  ordered
}

///|
fn build_rank_groups(
  nodes : Array[@cgraph.Node],
  ranks : Map[String, Int],
) -> Map[Int, Array[String]] {
  let groups : Map[Int, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match groups.get(rank) {
      Some(list) => list.push(name)
      None => groups[rank] = [name]
    }
  }
  groups
}
