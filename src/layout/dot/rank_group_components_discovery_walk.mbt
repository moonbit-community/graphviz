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
