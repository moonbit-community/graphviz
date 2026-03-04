///|
/// Stage C Phase C3 split: cluster-local neighbor map merge helpers.

///|
/// Graphviz parity: cluster-local ND_out/ND_in maps append raw graph AGSEQ
/// neighbors after order-graph replay, skipping duplicates to mirror fixture
/// out_all/in_all merge behavior.
/// Do not change behavior without updating fixtures/tests.
priv struct LocalNeighborMapsOutput {
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
}

///|
/// Graphviz parity: cluster-local neighbor sources keep order-graph ND_out/ND_in
/// together with raw graph AGSEQ ND_out/ND_in for deterministic merge.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalNeighborSources {
  source_out_neighbors : Map[String, Array[String]]
  source_in_neighbors : Map[String, Array[String]]
  raw_out_neighbors : Map[String, Array[String]]
  raw_in_neighbors : Map[String, Array[String]]
}

///|
/// Stage C Phase C3 split: raw Graphviz ND_out/ND_in neighbor map bundle used
/// by local-cluster neighbor replay before per-cluster merge.
priv struct GraphvizNeighborMaps {
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
}

///|
fn append_neighbor_edge(
  out_neighbors : Map[String, Array[String]],
  in_neighbors : Map[String, Array[String]],
  tail : String,
  head : String,
) -> Unit {
  match out_neighbors.get(tail) {
    Some(list) => list.push(head)
    None => out_neighbors[tail] = [head]
  }
  match in_neighbors.get(head) {
    Some(list) => list.push(tail)
    None => in_neighbors[head] = [tail]
  }
}

///|
/// Graphviz parity: raw-graph ND_out/ND_in maps preserve AGSEQ edge replay
/// order for local cluster median-anchor fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_raw_graphviz_neighbor_maps(graph : @cgraph.Graph) -> GraphvizNeighborMaps {
  let raw_graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let raw_graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for node in graph.nodes() {
    let name = node.name()
    raw_graphviz_out_neighbors[name] = []
    raw_graphviz_in_neighbors[name] = []
  }
  for edge in graph.edges() {
    append_neighbor_edge(
      raw_graphviz_out_neighbors,
      raw_graphviz_in_neighbors,
      edge.tail().name(),
      edge.head().name(),
    )
  }
  {
    out_neighbors: raw_graphviz_out_neighbors,
    in_neighbors: raw_graphviz_in_neighbors,
  }
}

///|
/// Graphviz parity: neighbor list append preserves first occurrence order.
fn append_unique_neighbor_name(
  list : Array[String],
  value : String,
) -> Unit {
  for item in list {
    if item == value {
      return ()
    }
  }
  list.push(value)
}

///|
/// Graphviz parity: unresolved neighbors from not-yet-expanded clusters are
/// collapsed onto the shared external anchor name.
fn normalize_external_neighbor_name(
  other : String,
  cluster : String,
  expanded_clusters : Map[String, Bool],
  intercluster_keys : Map[String, String],
  external_anchor_name : String,
) -> String {
  let other_cluster = @ordering.cluster_key_or_empty(intercluster_keys, other)
  if other_cluster != "" && other_cluster != cluster &&
    expanded_clusters.get(other_cluster) is None {
    external_anchor_name
  } else {
    other
  }
}

///|
/// Graphviz parity: raw AGSEQ neighbors are merged only when source ND_out/in
/// does not already expose an external anchor.
fn has_external_neighbor(
  neighbors : Array[String],
  cluster_node_set : Map[String, Bool],
) -> Bool {
  for other in neighbors {
    if cluster_node_set.get(other) is None {
      return true
    }
  }
  false
}

///|
/// Graphviz parity: raw AGSEQ neighbors are merged only when source ND_out/in
/// does not already expose an external anchor.
fn has_source_external_anchor(
  name : String,
  cluster_node_set : Map[String, Bool],
  source_out_neighbors : Map[String, Array[String]],
  source_in_neighbors : Map[String, Array[String]],
) -> Bool {
  let out = source_out_neighbors.get(name).unwrap_or_default()
  if has_external_neighbor(out, cluster_node_set) {
    return true
  }
  let inn = source_in_neighbors.get(name).unwrap_or_default()
  has_external_neighbor(inn, cluster_node_set)
}

///|
/// Graphviz parity: raw AGSEQ neighbors merge with duplicate suppression and
/// one external anchor per external cluster in each direction list.
fn append_raw_neighbors_with_external_anchor(
  neighbors : Array[String],
  raw_neighbors : Array[String],
  merge_context : LocalNeighborMergeContext,
) -> Unit {
  let external_cluster_seen : Map[String, Bool] = Map::new()
  for other in raw_neighbors {
    if is_edge_vnode_name(other) || other.has_prefix(CLUSTER_SKELETON_PREFIX) {
      continue
    }
    let normalized =
      normalize_external_neighbor_name(
        other,
        merge_context.cluster,
        merge_context.expanded_clusters,
        merge_context.intercluster_keys,
        merge_context.external_anchor_name,
      )
    if normalized == merge_context.external_anchor_name {
      let external_cluster =
        @ordering.cluster_key_or_empty(merge_context.intercluster_keys, other)
      if external_cluster == "" ||
        external_cluster_seen.get(external_cluster) is Some(_) {
        continue
      }
      external_cluster_seen[external_cluster] = true
      neighbors.push(normalized)
    } else {
      append_unique_neighbor_name(neighbors, normalized)
    }
  }
}

///|
priv struct LocalNeighborLists {
  out_neighbors : Array[String]
  in_neighbors : Array[String]
}

///|
/// Graphviz parity: local neighbor merge context keeps one cluster-scoped
/// source snapshot while per-node lists decide raw AGSEQ merge eligibility.
priv struct LocalNeighborMergeContext {
  cluster : String
  cluster_node_set : Map[String, Bool]
  expanded_clusters : Map[String, Bool]
  neighbor_sources : ClusterLocalNeighborSources
  intercluster_keys : Map[String, String]
  allow_raw_neighbors : Bool
  external_anchor_name : String
}

///|
/// Graphviz parity: per-node local neighbor lists start from order-graph
/// ND_out/ND_in and only then merge raw AGSEQ neighbors when allowed.
fn build_local_neighbor_lists_for_name(
  name : String,
  merge_context : LocalNeighborMergeContext,
) -> LocalNeighborLists {
  let out_neighbors =
    merge_context.neighbor_sources.source_out_neighbors
      .get(name)
      .unwrap_or_default()
      .copy()
  let in_neighbors =
    merge_context.neighbor_sources.source_in_neighbors
      .get(name)
      .unwrap_or_default()
      .copy()
  if !merge_context.allow_raw_neighbors ||
    has_source_external_anchor(
      name,
      merge_context.cluster_node_set,
      merge_context.neighbor_sources.source_out_neighbors,
      merge_context.neighbor_sources.source_in_neighbors,
    ) {
    return { out_neighbors, in_neighbors }
  }
  let raw_out =
    merge_context.neighbor_sources.raw_out_neighbors.get(name).unwrap_or_default()
  append_raw_neighbors_with_external_anchor(
    out_neighbors,
    raw_out,
    merge_context,
  )
  let raw_in =
    merge_context.neighbor_sources.raw_in_neighbors.get(name).unwrap_or_default()
  append_raw_neighbors_with_external_anchor(
    in_neighbors,
    raw_in,
    merge_context,
  )
  { out_neighbors, in_neighbors }
}

///|
/// Graphviz parity: cluster-local ND_out/ND_in maps append raw graph AGSEQ
/// neighbors after order-graph replay, skipping duplicates to mirror fixture
/// out_all/in_all merge behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_local_neighbor_maps(
  cluster : String,
  expanded_clusters : Map[String, Bool],
  cluster_nodes : Array[String],
  neighbor_sources : ClusterLocalNeighborSources,
  intercluster_keys : Map[String, String],
  allow_raw_neighbors : Bool,
) -> LocalNeighborMapsOutput {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  let cluster_node_set = build_name_set(cluster_nodes)
  let merge_context : LocalNeighborMergeContext = {
    cluster,
    cluster_node_set,
    expanded_clusters,
    neighbor_sources,
    intercluster_keys,
    allow_raw_neighbors,
    external_anchor_name: "%0",
  }
  for name in cluster_nodes {
    let local_neighbor_lists =
      build_local_neighbor_lists_for_name(
        name,
        merge_context,
      )
    graphviz_out_neighbors[name] = local_neighbor_lists.out_neighbors
    graphviz_in_neighbors[name] = local_neighbor_lists.in_neighbors
  }
  { graphviz_out_neighbors, graphviz_in_neighbors }
}
