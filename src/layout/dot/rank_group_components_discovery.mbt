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
fn prepare_rank_group_component_discovery_graphviz(
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
fn discover_rank_group_components_from_neighbors_graphviz(
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
fn discover_rank_group_components_graphviz(
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
  let prepared = prepare_rank_group_component_discovery_graphviz(
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
  discover_rank_group_components_from_neighbors_graphviz(
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
