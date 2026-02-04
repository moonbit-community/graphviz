///|
fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn graph_has_cluster(graph : @cgraph.Graph) -> Bool {
  for subgraph in graph.subgraphs() {
    if is_cluster_graph(subgraph) {
      return true
    }
    if graph_has_cluster(subgraph) {
      return true
    }
  }
  false
}

///|
fn node_cluster_key(node : @cgraph.Node) -> String {
  let mut graph = node.graph()
  let mut key = ""
  while !graph.is_root() {
    if is_cluster_graph(graph) {
      match graph.name() {
        Some(name) => key = name
        None => key = ""
      }
    }
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  key
}

///|
fn node_local_cluster_key(node : @cgraph.Node) -> String {
  let mut graph = node.graph()
  while !graph.is_root() {
    if is_cluster_graph(graph) {
      match graph.name() {
        Some(name) => return name
        None => return ""
      }
    }
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  ""
}

///|
fn graph_cluster_key(graph : @cgraph.Graph) -> String {
  let mut current = graph
  let mut key = ""
  while !current.is_root() {
    if is_cluster_graph(current) {
      match current.name() {
        Some(name) => key = name
        None => key = ""
      }
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  key
}

///|
fn collect_edge_cluster_keys(
  graph : @cgraph.Graph,
  edge_cluster_keys : Map[String, String],
) -> Unit {
  for child in graph.subgraphs() {
    collect_edge_cluster_keys(child, edge_cluster_keys)
  }
  if !is_cluster_graph(graph) {
    return ()
  }
  let cluster_key = graph_cluster_key(graph)
  if cluster_key == "" {
    return ()
  }
  let child_edges : Map[String, Bool] = Map::new()
  for child in graph.subgraphs() {
    for edge in child.edges() {
      child_edges[edge_key(edge)] = true
    }
  }
  for edge in graph.edges() {
    let key = edge_key(edge)
    if child_edges.get(key) is None {
      edge_cluster_keys[key] = cluster_key
    }
  }
}

///|
fn intercluster_edge_key(
  tail_cluster : String,
  head_cluster : String,
  tail_rank : Int,
  head_rank : Int,
) -> String {
  "\{tail_cluster}@\{tail_rank}->\{head_cluster}@\{head_rank}"
}

///|
fn cluster_rank_key(cluster : String, rank : Int) -> String {
  "\{cluster}@\{rank}"
}

///|
/// Graphviz parity: cluster skeleton node names encode the cluster key.
fn cluster_key_from_skeleton_name(name : String) -> String? {
  if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
    return None
  }
  let rest = name.unsafe_substring(
    start=CLUSTER_SKELETON_PREFIX.length(),
    end=name.length(),
  )
  for part in rest.split("@") {
    let value = part.to_string()
    if value != "" {
      return Some(value)
    }
  }
  None
}

///|
/// Graphviz parity: cluster boundary node names preserve the cluster key.
fn cluster_key_from_boundary_name(
  name : String,
  cluster_names : Map[String, Bool],
) -> String? {
  let mut rest : String? = None
  if name.has_prefix(CLUSTER_LN_PREFIX) {
    rest = Some(
      name.unsafe_substring(
        start=CLUSTER_LN_PREFIX.length(),
        end=name.length(),
      ),
    )
  } else if name.has_prefix(CLUSTER_RN_PREFIX) {
    rest = Some(
      name.unsafe_substring(
        start=CLUSTER_RN_PREFIX.length(),
        end=name.length(),
      ),
    )
  }
  let rest = match rest {
    Some(value) => value
    None => return None
  }
  match cluster_names.get(rest) {
    Some(_) => return Some(rest)
    None => ()
  }
  let mut best : String? = None
  let mut best_len = -1
  for cluster, _ in cluster_names {
    if !rest.has_prefix(cluster) {
      continue
    }
    let suffix = rest.unsafe_substring(
      start=cluster.length(),
      end=rest.length(),
    )
    if suffix == "" {
      if cluster.length() > best_len {
        best = Some(cluster)
        best_len = cluster.length()
      }
      continue
    }
    if !suffix.has_prefix("_") {
      continue
    }
    let digits = suffix.unsafe_substring(start=1, end=suffix.length())
    if digits == "" {
      continue
    }
    let mut all_digits = true
    for ch in digits {
      if ch < '0' || ch > '9' {
        all_digits = false
        break
      }
    }
    if all_digits && cluster.length() > best_len {
      best = Some(cluster)
      best_len = cluster.length()
    }
  }
  best
}

///|
fn collect_cluster_names(
  graph : @cgraph.Graph,
  out : Map[String, Bool],
) -> Unit {
  if is_cluster_graph(graph) {
    match graph.name() {
      Some(name) => out[name] = true
      None => ()
    }
  }
  for child in graph.subgraphs() {
    collect_cluster_names(child, out)
  }
}

///|
/// Graphviz parity: collapse_sets walks subgraphs and only recurses into
/// non-cluster subgraphs when building the root cluster list.
fn collect_cluster_names_graphviz_order(
  graph : @cgraph.Graph,
  out : Array[String],
) -> Unit {
  for subgraph in graph.subgraphs() {
    if is_cluster_graph(subgraph) {
      match subgraph.name() {
        Some(name) => out.push(name)
        None => ()
      }
    } else {
      collect_cluster_names_graphviz_order(subgraph, out)
    }
  }
}
