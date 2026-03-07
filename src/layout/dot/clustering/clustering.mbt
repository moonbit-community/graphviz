pub const CLUSTER_MARGIN_PT : Double = 8.0

///|
pub fn cluster_margin_pt(graph : @cgraph.Graph) -> Double {
  match graph.get_attr("margin") {
    Some(value) => {
      let margin = @numeric.parse_first_double(value, CLUSTER_MARGIN_PT)
      if margin < 0.0 {
        CLUSTER_MARGIN_PT
      } else {
        margin
      }
    }
    None => CLUSTER_MARGIN_PT
  }
}

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
        if @cluster_graph.is_cluster_graph(value) {
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
    if @cluster_graph.is_cluster_graph(current) {
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
pub(all) struct ClusterMembershipMaps {
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
}

///|
/// Graphviz parity: cluster membership maps mirror per-node outer/local
/// cluster ownership used across clustered ordering and compound-edge paths.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_membership_maps(
  nodes : Array[@cgraph.Node],
) -> ClusterMembershipMaps {
  let cluster_keys : Map[String, String] = Map::new()
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    let name = node.name()
    cluster_keys[name] = node_cluster_key(node)
    intercluster_keys[name] = node_local_cluster_key(node)
  }
  { cluster_keys, intercluster_keys }
}

///|
pub(all) struct ClusterNodeRankBounds {
  min_rank : Map[String, Int]
  max_rank : Map[String, Int]
  first_order : Map[String, Int]
}

///|
/// Graphviz parity: cluster min/max rank and first order are collected from
/// member node rank snapshots before clustered reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_rank_bounds(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> ClusterNodeRankBounds {
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let cluster_first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = cluster_keys.get(name).unwrap_or_default()
    if cluster == "" {
      continue
    }
    let rank = ranks.get(name).unwrap_or_default()
    match cluster_min_rank.get(cluster) {
      Some(current) => if rank < current { cluster_min_rank[cluster] = rank }
      None => cluster_min_rank[cluster] = rank
    }
    match cluster_max_rank.get(cluster) {
      Some(current) => if rank > current { cluster_max_rank[cluster] = rank }
      None => cluster_max_rank[cluster] = rank
    }
    if cluster_first_order.get(cluster) is None {
      cluster_first_order[cluster] = node_order.get(name).unwrap_or_default()
    }
  }
  {
    min_rank: cluster_min_rank,
    max_rank: cluster_max_rank,
    first_order: cluster_first_order,
  }
}

///|
/// Graphviz parity: initial cluster node order seeds follow GD_nlist traversal
/// with optional graphviz_flip reversal before clustered reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn seed_cluster_node_order(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
  node_order : Map[String, Int],
) -> Unit {
  let total_nodes = nodes.length()
  for i, node in nodes {
    let name = node.name()
    let cluster = cluster_keys.get(name).unwrap_or_default()
    if cluster == "" {
      continue
    }
    let base_order = i
    let order_value =
      if graphviz_flip {
        total_nodes - 1 - base_order
      } else {
        base_order
      }
    node_order[name] = order_value
  }
}

///|
/// Graphviz parity: each cluster contributes one skeleton node per rank
/// (first node encountered in rank order).
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_skeleton(
  groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[String, Bool] {
  let cluster_skeleton : Map[String, Bool] = Map::new()
  let cluster_rank_seen : Map[String, Bool] = Map::new()
  for rank, names in groups {
    for name in names {
      let cluster = cluster_keys.get(name).unwrap_or_default()
      if cluster == "" {
        continue
      }
      let key = "\{cluster}@\{rank}"
      if cluster_rank_seen.get(key) is None {
        cluster_rank_seen[key] = true
        cluster_skeleton[name] = true
      }
    }
  }
  cluster_skeleton
}

///|
/// Graphviz parity: optional cluster order base expansion follows the
/// DOT_CLUSTER_ORDER_BASE debug path used for deterministic cluster spacing.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_order_base(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  cluster_min_rank : Map[String, Int],
  cluster_first_order : Map[String, Int],
  node_order : Map[String, Int],
  cluster_order_base_enabled : Bool,
) -> Unit {
  let cluster_order_list : Array[(String, Int, Int)] = []
  for cluster, rank in cluster_min_rank {
    let order = cluster_first_order.get(cluster).unwrap_or_default()
    cluster_order_list.push((cluster, rank, order))
  }
  if cluster_order_list.length() <= 1 || !cluster_order_base_enabled {
    return
  }
  cluster_order_list.sort_by((a, b) => {
    let (_name_a, rank_a, order_a) = a
    let (_name_b, rank_b, order_b) = b
    if rank_a < rank_b {
      -1
    } else if rank_a > rank_b {
      1
    } else if order_a < order_b {
      -1
    } else if order_a > order_b {
      1
    } else {
      0
    }
  })
  let step = nodes.length() + 1
  let cluster_order_base : Map[String, Int] = Map::new()
  let mut base = 0
  for entry in cluster_order_list {
    let (cluster, _rank, _order) = entry
    cluster_order_base[cluster] = base
    base = base + step
  }
  for node in nodes {
    let name = node.name()
    let cluster = cluster_keys.get(name).unwrap_or_default()
    if cluster == "" {
      continue
    }
    let base_order = cluster_order_base.get(cluster).unwrap_or_default()
    let inner = node_order.get(name).unwrap_or_default()
    node_order[name] = base_order + inner
  }
}

///|
/// Graphviz parity: cluster core metadata payload keeps cluster ownership,
/// rank bounds, traversal order, and parent mapping grouped for ordering setup.
pub(all) struct ClusterCoreOrderingMetadata {
  has_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
}

///|
/// Graphviz parity: cluster core metadata and node-order seeding/base expansion
/// are collected before clustered ordering dispatch with Graphviz order intact.
/// Do not change behavior without updating fixtures/tests.
pub fn build_cluster_core_metadata_for_ordering(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  graphviz_flip : Bool,
  cluster_order_base_enabled : Bool,
) -> ClusterCoreOrderingMetadata {
  let has_clusters = @cluster_graph.graph_has_cluster(graph)
  let cluster_membership = build_cluster_membership_maps(nodes)
  let cluster_keys = cluster_membership.cluster_keys
  let intercluster_keys = cluster_membership.intercluster_keys
  seed_cluster_node_order(nodes, cluster_keys, graphviz_flip, node_order)
  let cluster_skeleton = build_cluster_skeleton(groups, cluster_keys)
  let cluster_rank_bounds =
    collect_cluster_rank_bounds(nodes, cluster_keys, ranks, node_order)
  let cluster_min_rank = cluster_rank_bounds.min_rank
  let cluster_max_rank = cluster_rank_bounds.max_rank
  let cluster_first_order = cluster_rank_bounds.first_order
  let cluster_traversal_metadata = collect_cluster_traversal_metadata(graph)
  let cluster_order = cluster_traversal_metadata.cluster_order
  let cluster_parents = cluster_traversal_metadata.cluster_parents
  apply_cluster_order_base(
    nodes,
    cluster_keys,
    cluster_min_rank,
    cluster_first_order,
    node_order,
    cluster_order_base_enabled,
  )
  {
    has_clusters,
    cluster_keys,
    cluster_skeleton,
    cluster_min_rank,
    cluster_max_rank,
    cluster_order,
    cluster_parents,
    intercluster_keys,
  }
}

///|
fn graph_cluster_key(graph : @cgraph.Graph) -> String {
  let mut current = graph
  let mut key = ""
  while !current.is_root() {
    if @cluster_graph.is_cluster_graph(current) {
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
  if !@cluster_graph.is_cluster_graph(graph) {
    return ()
  }
  let cluster_key = graph_cluster_key(graph)
  if cluster_key == "" {
    return ()
  }
  let child_edges : Map[String, Bool] = Map::new()
  for child in graph.subgraphs() {
    for edge in child.edges() {
      child_edges[@edge_identity.edge_key(edge)] = true
    }
  }
  for edge in graph.edges() {
    let key = @edge_identity.edge_key(edge)
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
/// Graphviz parity: collapse_sets walks subgraphs and only recurses into
/// non-cluster subgraphs when building the root cluster list.
pub fn collect_cluster_names_order(
  graph : @cgraph.Graph,
  out : Array[String],
) -> Unit {
  for subgraph in graph.subgraphs() {
    if @cluster_graph.is_cluster_graph(subgraph) {
      match subgraph.name() {
        Some(name) => out.push(name)
        None => ()
      }
    } else {
      collect_cluster_names_order(subgraph, out)
    }
  }
}

///|
pub(all) struct ClusterTraversalMetadata {
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
}

///|
/// Graphviz parity: cluster order traversal and parent mapping are collected
/// before clustered ordering stages with Graphviz traversal order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_traversal_metadata(
  graph : @cgraph.Graph,
) -> ClusterTraversalMetadata {
  let cluster_order : Array[String] = []
  collect_cluster_names_order(graph, cluster_order)
  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(graph)
  {
    cluster_order,
    cluster_parents: cluster_maps.cluster_parents,
  }
}
