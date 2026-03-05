pub fn root_graph_for_node(node : @cgraph.Node) -> @cgraph.Graph {
  let mut graph = node.graph()
  while !graph.is_root() {
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  graph
}

fn graph_contains_node_raw(graph : @cgraph.Graph, node : @cgraph.Node) -> Bool {
  let target = node.name()
  for entry in graph.nodes() {
    if entry.name() == target {
      return true
    }
  }
  false
}

fn is_rankset_graph(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("rank") {
    Some(value) => {
      let lower = value.to_lower()
      lower == "same" ||
        lower == "min" ||
        lower == "max" ||
        lower == "source" ||
        lower == "sink"
    }
    None => false
  }
}

fn graph_is_within_cluster_name(graph : @cgraph.Graph, cluster_name : String) -> Bool {
  if cluster_name == "" {
    return false
  }
  let mut current : @cgraph.Graph? = Some(graph)
  while true {
    match current {
      Some(value) => {
        match value.name() {
          Some(name) =>
            if name == cluster_name {
              return true
            }
          None => ()
        }
        current = value.parent()
      }
      None => break
    }
  }
  false
}

fn node_outside_cluster_rankset(
  root : @cgraph.Graph,
  node : @cgraph.Node,
  cluster_name : String,
) -> Bool {
  if cluster_name == "" {
    return false
  }
  let stack : Array[@cgraph.Graph] = [root]
  while stack.length() > 0 {
    let current = stack[stack.length() - 1]
    let _ = stack.pop()
    if graph_contains_node_raw(current, node) {
      if is_rankset_graph(current) &&
        !graph_is_within_cluster_name(current, cluster_name) {
        return true
      }
      for child in current.subgraphs() {
        stack.push(child)
      }
    }
  }
  false
}

fn nearest_cluster_ancestor_name(graph : @cgraph.Graph) -> String {
  let mut current : @cgraph.Graph? = Some(graph)
  while true {
    match current {
      Some(value) => {
        if @shared.is_cluster_graph(value) {
          match value.name() {
            Some(name) => return name
            None => return ""
          }
        }
        current = value.parent()
      }
      None => break
    }
  }
  ""
}

pub fn graph_contains_node(graph : @cgraph.Graph, node : @cgraph.Node) -> Bool {
  if !graph_contains_node_raw(graph, node) {
    return false
  }
  let cluster_name = nearest_cluster_ancestor_name(graph)
  // Graphviz parity: nodes merged into an external rankset are removed
  // from clusters (dotgen/node_induce + mark_clusters).
  if cluster_name != "" &&
    node_outside_cluster_rankset(root_graph_for_node(node), node, cluster_name) {
    return false
  }
  true
}

priv struct NodeClusterKeys {
  outer : String
  inner : String
}

fn node_cluster_keys(node : @cgraph.Node) -> NodeClusterKeys {
  let root = root_graph_for_node(node)
  let mut outer = ""
  let mut inner = ""
  let stack : Array[@cgraph.Graph] = [root]
  while stack.length() > 0 {
    let current = stack[stack.length() - 1]
    let _ = stack.pop()
    if !graph_contains_node(current, node) {
      continue
    }
    if @shared.is_cluster_graph(current) {
      let name = match current.name() {
        Some(value) => value
        None => ""
      }
      if outer == "" {
        outer = name
      }
      inner = name
    }
    for child in current.subgraphs() {
      stack.push(child)
    }
  }
  { outer, inner }
}

///|
/// Graphviz parity: cluster membership is derived from subgraph node membership
/// (nodes referenced in a cluster belong to it), not node home graphs.
/// Do not change behavior without updating fixtures/tests.
pub fn node_cluster_key(node : @cgraph.Node) -> String {
  node_cluster_keys(node).outer
}

///|
/// Graphviz parity: local cluster key resolves to the deepest (innermost)
/// cluster containing the node.
/// Do not change behavior without updating fixtures/tests.
pub fn node_local_cluster_key(node : @cgraph.Node) -> String {
  node_cluster_keys(node).inner
}

///|
pub fn graph_cluster_key(graph : @cgraph.Graph) -> String {
  let mut current = graph
  let mut key = ""
  while !current.is_root() {
    if @shared.is_cluster_graph(current) {
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
pub fn collect_edge_cluster_keys(
  graph : @cgraph.Graph,
  edge_cluster_keys : Map[String, String],
) -> Unit {
  for child in graph.subgraphs() {
    collect_edge_cluster_keys(child, edge_cluster_keys)
  }
  if !@shared.is_cluster_graph(graph) {
    return ()
  }
  let cluster_key = graph_cluster_key(graph)
  if cluster_key == "" {
    return ()
  }
  let child_edges : Map[String, Bool] = Map::new()
  for child in graph.subgraphs() {
    for edge in child.edges() {
      child_edges[@shared.edge_key(edge)] = true
    }
  }
  for edge in graph.edges() {
    let key = @shared.edge_key(edge)
    if child_edges.get(key) is None {
      edge_cluster_keys[key] = cluster_key
    }
  }
}

fn collect_cluster_member_nodes(
  graph : @cgraph.Graph,
  nodes_out : Map[String, Bool],
) -> Unit {
  for node in graph.nodes() {
    if graph_contains_node(graph, node) {
      nodes_out[node.name()] = true
    }
  }
  for child in graph.subgraphs() {
    collect_cluster_member_nodes(child, nodes_out)
  }
}

///|
/// Graphviz parity: cluster membership is derived from all node references in
/// each cluster subgraph tree, filtered by graph_contains_node semantics.
pub fn collect_cluster_members(
  cluster_graphs : Map[String, @cgraph.Graph],
) -> Map[String, Map[String, Bool]] {
  let members : Map[String, Map[String, Bool]] = Map::new()
  for name, cluster_graph in cluster_graphs {
    let set : Map[String, Bool] = Map::new()
    collect_cluster_member_nodes(cluster_graph, set)
    if set.length() > 0 {
      members[name] = set
    }
  }
  members
}

///|
/// Graphviz parity: assign intercluster virtual nodes to the lowest common
/// ancestor cluster (mark_lowclusters + class2).
/// Do not change behavior without updating fixtures/tests.
pub fn cluster_lca(
  left : String,
  right : String,
  cluster_parents : Map[String, String?],
) -> String {
  if left == "" || right == "" {
    return ""
  }
  if left == right {
    return left
  }
  let seen : Map[String, Bool] = Map::new()
  let walk_seen : Map[String, Bool] = Map::new()
  let mut current = left
  while current != "" {
    if walk_seen.get(current) is Some(_) {
      break
    }
    walk_seen[current] = true
    seen[current] = true
    let parent = match cluster_parents.get(current) {
      Some(value) => value
      None => (None : String?)
    }
    match parent {
      Some(value) => current = value
      None => current = ""
    }
  }
  let mut probe = right
  let probe_seen : Map[String, Bool] = Map::new()
  while probe != "" {
    if probe_seen.get(probe) is Some(_) {
      break
    }
    probe_seen[probe] = true
    if seen.get(probe) is Some(_) {
      return probe
    }
    let parent = match cluster_parents.get(probe) {
      Some(value) => value
      None => (None : String?)
    }
    match parent {
      Some(value) => probe = value
      None => probe = ""
    }
  }
  ""
}

///|
/// Graphviz parity: cluster skeleton node names encode the cluster key.
pub fn is_cluster_skeleton_name(name : String) -> Bool {
  name.has_prefix(@shared.CLUSTER_SKELETON_PREFIX)
}

///|
/// Graphviz parity: cluster skeleton node names encode "<cluster>@<rank>".
pub fn cluster_skeleton_name(cluster : String, rank : Int) -> String {
  "\{@shared.CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
}

///|
/// Graphviz parity: cluster boundary slack nodes use dedicated ln/rn prefixes.
pub fn cluster_left_boundary_name(cluster : String) -> String {
  "\{@shared.CLUSTER_LN_PREFIX}\{cluster}"
}

///|
/// Graphviz parity: cluster boundary slack nodes use dedicated ln/rn prefixes.
pub fn cluster_right_boundary_name(cluster : String) -> String {
  "\{@shared.CLUSTER_RN_PREFIX}\{cluster}"
}

///|
/// Graphviz parity: boundary node identifiers must stay unique if cluster
/// names collide with existing graph nodes.
pub fn unique_cluster_boundary_name(
  base_name : String,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = base_name
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{base_name}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
}

///|
/// Graphviz parity: cluster boundary slack nodes are identified by ln/rn
/// prefixes in xpos constraint graphs.
pub fn is_cluster_boundary_name(name : String) -> Bool {
  name.has_prefix(@shared.CLUSTER_LN_PREFIX) ||
  name.has_prefix(@shared.CLUSTER_RN_PREFIX)
}

///|
/// Graphviz parity: left boundary nodes use the ln prefix.
pub fn is_cluster_left_boundary_name(name : String) -> Bool {
  name.has_prefix(@shared.CLUSTER_LN_PREFIX)
}

///|
/// Graphviz parity: boundary node names map back to cluster keys via longest
/// matching cluster-prefix fallback to preserve suffix-disambiguated names.
pub fn cluster_key_from_boundary(
  name : String,
  cluster_names : Map[String, Bool],
) -> String? {
  let mut rest : String? = None
  if name.has_prefix(@shared.CLUSTER_LN_PREFIX) {
    rest = Some(
      name.unsafe_substring(
        start=@shared.CLUSTER_LN_PREFIX.length(),
        end=name.length(),
      ),
    )
  } else if name.has_prefix(@shared.CLUSTER_RN_PREFIX) {
    rest = Some(
      name.unsafe_substring(
        start=@shared.CLUSTER_RN_PREFIX.length(),
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
/// Graphviz parity: cluster skeleton node names encode the cluster key.
pub fn cluster_key_from_skeleton(name : String) -> String? {
  if !is_cluster_skeleton_name(name) {
    return None
  }
  let rest = name.unsafe_substring(
    start=@shared.CLUSTER_SKELETON_PREFIX.length(),
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
/// Graphviz parity: collapse_sets walks subgraphs and only recurses into
/// non-cluster subgraphs when building the root cluster list.
pub fn collect_cluster_names_order(
  graph : @cgraph.Graph,
  out : Array[String],
) -> Unit {
  for subgraph in graph.subgraphs() {
    if @shared.is_cluster_graph(subgraph) {
      match subgraph.name() {
        Some(name) => out.push(name)
        None => ()
      }
    } else {
      collect_cluster_names_order(subgraph, out)
    }
  }
}
