///|
/// Graphviz parity: build_ranks/enqueue_neighbors ordering from ND_out/ND_in lists (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_rank_groups_by_neighbors(
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

///|
/// Graphviz parity: decompose/build_ranks operate per connected component.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_groups_by_components(
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
  let nodes = collect_rank_group_component_nodes(rank_keys, groups)
  if nodes.length() == 0 {
    return build_empty_rank_group_map(rank_keys)
  }
  let components = discover_rank_group_components(
    nodes,
    edge_tail,
    edge_head,
    node_ranks,
    node_order,
    cluster_keys,
    cluster_skeleton,
    flat_constraints,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
  )
  if components.length() <= 1 {
    return build_rank_groups_by_neighbors(
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
  merge_rank_groups_graphviz_components(
    rank_keys,
    groups,
    edge_tail,
    edge_head,
    node_ranks,
    node_order,
    cluster_keys,
    cluster_skeleton,
    pass,
    flip,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    components,
  )
}
///|
fn collect_rank_group_component_nodes(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
) -> Array[String] {
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
  nodes
}

///|
fn build_empty_rank_group_map(rank_keys : Array[Int]) -> Map[Int, Array[String]] {
  let empty : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    empty[rank] = []
  }
  empty
}


///|
priv struct RankGroupComponentDiscoveryPrepared {
  ordered_nodes : Array[String]
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
  flat_out : Map[String, Array[String]]
  flat_in : Map[String, Array[String]]
  cluster_skeleton_nodes : Map[String, Array[String]]
}

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

///|
/// Graphviz parity: prepare decompose inputs with Graphviz-compatible node
/// ordering, edge neighborhoods, flat constraints, and cluster rankleaders.
/// Do not change behavior without updating fixtures/tests.
fn prepare_rank_group_component_discovery(
  nodes : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
) -> RankGroupComponentDiscoveryPrepared {
  let (ordered_nodes, fallback_order) = build_rank_group_component_discovery_order(
    nodes,
    node_order,
  )
  let (out_neighbors, in_neighbors, node_set) =
    build_rank_group_component_discovery_neighbors(
      nodes,
      edge_tail,
      edge_head,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
    )
  let cluster_skeleton_nodes = collect_rank_group_component_skeleton_nodes(
    ordered_nodes,
    cluster_keys,
    cluster_skeleton,
    node_ranks,
    node_order,
    fallback_order,
  )
  let (flat_out, flat_in) = build_rank_group_component_flat_constraint_neighbors(
    nodes,
    node_set,
    flat_constraints,
  )
  {
    ordered_nodes,
    out_neighbors,
    in_neighbors,
    flat_out,
    flat_in,
    cluster_skeleton_nodes,
  }
}

///|
/// Graphviz parity: component walk follows decompose-style DFS over flat and
/// edge neighborhoods, then closes each component over cluster rankleaders.
/// Do not change behavior without updating fixtures/tests.
fn discover_rank_group_components_from_neighbors(
  nodes : Array[String],
  ordered_nodes : Array[String],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  cluster_skeleton_nodes : Map[String, Array[String]],
  out_neighbors : Map[String, Array[String]],
  in_neighbors : Map[String, Array[String]],
  flat_out : Map[String, Array[String]],
  flat_in : Map[String, Array[String]],
) -> Array[Array[String]] {
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
  components
}

///|
/// Graphviz parity: component discovery follows Graphviz's decompose-style DFS
/// over edge and flat-constraint neighborhoods with cluster rankleader closure.
/// Do not change behavior without updating fixtures/tests.
fn discover_rank_group_components(
  nodes : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_out_neighbors? : Map[String, Array[String]] = Map::new(),
  graphviz_in_neighbors? : Map[String, Array[String]] = Map::new(),
) -> Array[Array[String]] {
  let prepared = prepare_rank_group_component_discovery(
    nodes,
    edge_tail,
    edge_head,
    node_ranks,
    node_order,
    cluster_keys,
    cluster_skeleton,
    flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
  )
  discover_rank_group_components_from_neighbors(
    nodes,
    prepared.ordered_nodes,
    cluster_keys,
    cluster_skeleton,
    prepared.cluster_skeleton_nodes,
    prepared.out_neighbors,
    prepared.in_neighbors,
    prepared.flat_out,
    prepared.flat_in,
  )
}
///|
priv struct RankGroupComponentMergeInputs {
  component_groups : Map[Int, Array[String]]
  filtered_out : Map[String, Array[String]]
  filtered_in : Map[String, Array[String]]
}

///|
/// Graphviz parity: component-local merge inputs preserve rank-group filtering
/// and in/out neighbor projection constrained to the component node set.
/// Do not change behavior without updating fixtures/tests.
fn prepare_rank_group_component_merge_inputs(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  component : Array[String],
) -> RankGroupComponentMergeInputs {
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
  {
    component_groups,
    filtered_out,
    filtered_in,
  }
}

///|
fn append_rank_group_component_order_to_merged(
  rank_keys : Array[Int],
  merged : Map[Int, Array[String]],
  ordered_component : Map[Int, Array[String]],
) -> Unit {
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

///|
/// Graphviz parity: merged per-rank order keeps first-seen occurrence globally
/// so cluster rankleaders appear once across all ranks/components.
/// Do not change behavior without updating fixtures/tests.
fn dedup_rank_groups_graphviz_merged(
  rank_keys : Array[Int],
  merged : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
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
/// Graphviz parity: per-component rank-group ordering preserves component-local
/// neighbor filtering and merge order before final deduplication.
/// Do not change behavior without updating fixtures/tests.
fn merge_rank_groups_graphviz_components(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  pass : Int,
  flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  components : Array[Array[String]],
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    merged[rank] = []
  }
  for component in components {
    let prepared = prepare_rank_group_component_merge_inputs(
      rank_keys,
      groups,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      component,
    )
    let ordered_component = build_rank_groups_by_neighbors(
      rank_keys,
      prepared.component_groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      pass,
      flip=flip,
      graphviz_out_neighbors=prepared.filtered_out,
      graphviz_in_neighbors=prepared.filtered_in,
    )
    append_rank_group_component_order_to_merged(
      rank_keys,
      merged,
      ordered_component,
    )
  }
  dedup_rank_groups_graphviz_merged(rank_keys, merged)
}
