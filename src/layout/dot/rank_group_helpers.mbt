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
  // Graphviz parity: GD_flip reverses rank order for horizontal rankdir.
  if flip {
    for _rank, names in ordered {
      if names.length() > 1 {
        let mut left = 0
        let mut right = names.length() - 1
        while left < right {
          let tmp = names[left]
          names[left] = names[right]
          names[right] = tmp
          left = left + 1
          right = right - 1
        }
      }
    }
  }
  ordered
}

///|
/// Graphviz parity: decompose/build_ranks operate per connected component.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_groups_graphviz_components(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  pass : Int,
  flat_constraints : Map[String, Bool],
  flip? : Bool = false,
  graphviz_out_neighbors? : Map[String, Array[String]] = Map::new(),
  graphviz_in_neighbors? : Map[String, Array[String]] = Map::new(),
) -> Map[Int, Array[String]] {
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
  if nodes.length() == 0 {
    let empty : Map[Int, Array[String]] = Map::new()
    for rank in rank_keys {
      empty[rank] = []
    }
    return empty
  }
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in nodes {
    fallback_order[name] = i
  }
  let ordered_nodes = nodes.copy()
  if ordered_nodes.length() > 1 {
    ordered_nodes.sort_by((a, b) => {
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
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for name in nodes {
    flat_out[name] = []
    flat_in[name] = []
  }
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
  let visited : Map[String, Bool] = Map::new()
  for name in nodes {
    visited[name] = false
  }
  let components : Array[Array[String]] = []
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
  let start_nodes : Array[String] = []
  for name in ordered_nodes {
    if cluster_skeleton.get(name) == Some(true) {
      continue
    }
    if name.has_prefix(EDGE_VNODE_PREFIX) {
      continue
    }
    start_nodes.push(name)
  }
  let starts = if start_nodes.length() > 0 { start_nodes } else { ordered_nodes }
  for start in starts {
    if visited.get(start) == Some(true) {
      continue
    }
    let component : Array[String] = []
    stack.push(start)
    while stack.length() > 0 {
      let current = stack[stack.length() - 1]
      let _ = stack.pop()
      if visited.get(current) == Some(true) {
        continue
      }
      visited[current] = true
      component.push(current)
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
    if cluster_skeleton_nodes.length() > 0 {
      let component_set : Map[String, Bool] = Map::new()
      let component_clusters : Map[String, Bool] = Map::new()
      for name in component {
        component_set[name] = true
        let cluster = match cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster != "" {
          component_clusters[cluster] = true
        }
      }
      for cluster, _ in component_clusters {
        let skels = match cluster_skeleton_nodes.get(cluster) {
          Some(list) => list
          None => []
        }
        for skel in skels {
          if component_set.get(skel) is None {
            component_set[skel] = true
            component.push(skel)
          }
        }
      }
    }
    components.push(component)
  }
  if components.length() <= 1 {
    return build_rank_groups_graphviz(
      rank_keys,
      groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      pass,
      flip=flip,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
    )
  }
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    merged[rank] = []
  }
  for component in components {
    let component_set : Map[String, Bool] = Map::new()
    for name in component {
      component_set[name] = true
    }
    let component_groups : Map[Int, Array[String]] = Map::new()
    for rank in rank_keys {
      let names = match groups.get(rank) {
        Some(list) => list
        None => []
      }
      let filtered : Array[String] = []
      for name in names {
        if component_set.get(name) is Some(_) {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        component_groups[rank] = filtered
      }
    }
    let filtered_out : Map[String, Array[String]] = Map::new()
    let filtered_in : Map[String, Array[String]] = Map::new()
    for name in component {
      let out = match graphviz_out_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      let filtered_out_list : Array[String] = []
      for other in out {
        if component_set.get(other) is Some(_) {
          filtered_out_list.push(other)
        }
      }
      filtered_out[name] = filtered_out_list
      let inn = match graphviz_in_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      let filtered_in_list : Array[String] = []
      for other in inn {
        if component_set.get(other) is Some(_) {
          filtered_in_list.push(other)
        }
      }
      filtered_in[name] = filtered_in_list
    }
    let ordered_component = build_rank_groups_graphviz(
      rank_keys,
      component_groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      pass,
      flip=flip,
      graphviz_out_neighbors=filtered_out,
      graphviz_in_neighbors=filtered_in,
    )
    for rank in rank_keys {
      let names = match ordered_component.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() == 0 {
        continue
      }
      let merged_list = match merged.get(rank) {
        Some(list) => list
        None => []
      }
      for name in names {
        merged_list.push(name)
      }
      merged[rank] = merged_list
    }
  }
  // Graphviz parity: cluster rankleaders should appear once per cluster.
  let seen : Map[String, Bool] = Map::new()
  for rank in rank_keys {
    let names = match merged.get(rank) {
      Some(list) => list
      None => []
    }
    let unique : Array[String] = []
    for name in names {
      if seen.get(name) is None {
        seen[name] = true
        unique.push(name)
      }
    }
    merged[rank] = unique
  }
  merged
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
