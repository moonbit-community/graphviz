///|
/// Graphviz parity: intercluster x alignment gate uses DOT_INTERCLUSTER_ALIGN
/// env parsing once, preserving Graphviz-compatible truthy/falsy semantics.
pub fn intercluster_alignment_enabled() -> Bool {
  @shared.env_flag_enabled(@sys.get_env_var("DOT_INTERCLUSTER_ALIGN"), false)
}

///|
/// Graphviz parity: intercluster alignment payload keeps rank and cluster maps
/// grouped so cross-cluster x-shift wiring remains explicit and stable.
priv struct InterclusterAlignmentInput {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  x_positions : Map[String, Double]
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
}

///|
fn cluster_rank_key(cluster : String, rank : Int) -> String {
  "\{cluster}@\{rank}"
}

///|
/// Graphviz parity: dotted-edge intercluster alignment follows dot rules for
/// same-rank cluster groups that share a single external target.
fn adjust_intercluster_alignment(
  input : InterclusterAlignmentInput,
) -> Unit {
  let cluster_rank_nodes : Map[String, Array[String]] = Map::new()
  let cluster_rank_value : Map[String, Int] = Map::new()
  for node in input.nodes {
    let name = node.name()
    let cluster = input.cluster_keys.get(name).unwrap_or_default()
    if cluster == "" {
      continue
    }
    let rank = match input.ranks.get(name) {
      Some(value) => value
      None => continue
    }
    let key = cluster_rank_key(cluster, rank)
    cluster_rank_value[key] = rank
    match cluster_rank_nodes.get(key) {
      Some(list) => list.push(name)
      None => cluster_rank_nodes[key] = [name]
    }
  }
  let cluster_rank_targets : Map[String, Map[String, Bool]] = Map::new()
  for edge in input.edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_cluster = input.intercluster_keys.get(tail).unwrap_or_default()
    let head_cluster = input.intercluster_keys.get(head).unwrap_or_default()
    if tail_cluster == "" || tail_cluster == head_cluster {
      continue
    }
    let tail_rank = match input.ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let key = cluster_rank_key(tail_cluster, tail_rank)
    match cluster_rank_targets.get(key) {
      Some(targets) => targets[head] = true
      None => {
        let targets : Map[String, Bool] = Map::new()
        targets[head] = true
        cluster_rank_targets[key] = targets
      }
    }
  }
  let eps = 0.01
  for key, names in cluster_rank_nodes {
    if names.length() < 2 {
      continue
    }
    let targets = match cluster_rank_targets.get(key) {
      Some(value) => value
      None => continue
    }
    if targets.length() != 1 {
      continue
    }
    let mut target_name = ""
    for name, _ in targets {
      target_name = name
      break
    }
    let target_x = match input.x_positions.get(target_name) {
      Some(value) => value
      None => continue
    }
    let mut aligned = false
    for name in names {
      match input.x_positions.get(name) {
        Some(value) =>
          if Double::abs(value - target_x) <= eps {
            aligned = true
            break
          }
        None => ()
      }
    }
    if !aligned {
      continue
    }
    let rank = match cluster_rank_value.get(key) {
      Some(value) => value
      None => continue
    }
    let shift = rank_nodesep_pt(rank, input.nodesep_pt, input.has_edge_labels)
    for name in names {
      match input.x_positions.get(name) {
        Some(value) => input.x_positions[name] = value - shift
        None => ()
      }
    }
  }
}

///|
fn cluster_key_from_boundary(
  name : String,
  cluster_names : Map[String, Bool],
  cluster_ln_prefix : String,
  cluster_rn_prefix : String,
) -> String? {
  let mut rest : String? = None
  if name.has_prefix(cluster_ln_prefix) {
    rest = Some(
      name.unsafe_substring(
        start=cluster_ln_prefix.length(),
        end=name.length(),
      ),
    )
  } else if name.has_prefix(cluster_rn_prefix) {
    rest = Some(
      name.unsafe_substring(
        start=cluster_rn_prefix.length(),
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
fn vnode_positions_from_edges(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  node_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> Map[String, @geom.Point] {
  let positions : Map[String, @geom.Point] = Map::new()
  for edge in edges {
    let vnodes = match edge_vnodes.get(@shared.edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_pos = node_positions.get(tail).unwrap_or_default()
    let head_pos = node_positions.get(head).unwrap_or_default()
    let (low_rank, high_rank, low_pos, high_pos) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_pos, head_pos)
    } else {
      (head_rank, tail_rank, head_pos, tail_pos)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let pos_x = low_pos + (high_pos - low_pos) * t
      let pos_y = rank_y.get(vnode_rank).unwrap_or_default()
      positions[vnode] = { x: pos_x, y: pos_y }
    }
  }
  positions
}

///|
/// Graphviz parity: final node position projection maps x/y by graph node list
/// order and defaults missing coordinates to 0.0 exactly as before.
pub fn build_node_positions_map(
  nodes : Array[@cgraph.Node],
  x_positions : Map[String, Double],
  y_positions : Map[String, Double],
) -> Map[String, @geom.Point] {
  let positions : Map[String, @geom.Point] = Map::new()
  for node in nodes {
    let name = node.name()
    let pos_x = x_positions.get(name).unwrap_or_default()
    let pos_y = y_positions.get(name).unwrap_or_default()
    positions[name] = { x: pos_x, y: pos_y }
  }
  positions
}

///|
/// Graphviz parity: vnode output positions are either direct xpos/rank pairs
/// (when xpos consumed vnode graph) or endpoint-interpolated fallback.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct VnodePositionsInput {
  use_vnodes_for_xpos : Bool
  vnode_ranks : Map[String, Int]
  x_positions : Map[String, Double]
  rank_y : Map[Int, Double]
  fallback_fn : () -> Map[String, @geom.Point]
}

///|
/// Graphviz parity: vnode output positions keep direct-vnode projection and
/// fallback projection branch order aligned with Graphviz.
pub fn build_vnode_positions(
  input : VnodePositionsInput,
) -> Map[String, @geom.Point] {
  if input.use_vnodes_for_xpos {
    let positions : Map[String, @geom.Point] = Map::new()
    for name, rank in input.vnode_ranks {
      let pos_x = input.x_positions.get(name).unwrap_or_default()
      let pos_y = input.rank_y.get(rank).unwrap_or_default()
      positions[name] = { x: pos_x, y: pos_y }
    }
    positions
  } else {
    (input.fallback_fn)()
  }
}

///|
pub struct ClusterBoundaryXOutput {
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
}

///|
/// Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusterBoundaryXInput {
  has_clusters : Bool
  x_positions : Map[String, Double]
  is_cluster_boundary : (String) -> Bool
  boundary_cluster_key : (String) -> String?
  is_left_boundary : (String) -> Bool
}

///|
/// Graphviz parity: cluster boundary projection keeps boundary-node filtering
/// and key mapping stable before writing ln/rn x maps.
pub fn build_cluster_boundary_x(
  input : ClusterBoundaryXInput,
) -> ClusterBoundaryXOutput {
  let cluster_ln_x : Map[String, Double] = Map::new()
  let cluster_rn_x : Map[String, Double] = Map::new()
  if !input.has_clusters {
    return { cluster_ln_x, cluster_rn_x }
  }
  for name, pos_x in input.x_positions {
    if !(input.is_cluster_boundary)(name) {
      continue
    }
    match (input.boundary_cluster_key)(name) {
      Some(cluster_key) =>
        if (input.is_left_boundary)(name) {
          cluster_ln_x[cluster_key] = pos_x
        } else {
          cluster_rn_x[cluster_key] = pos_x
        }
      None => ()
    }
  }
  { cluster_ln_x, cluster_rn_x }
}

///|
/// Graphviz parity: final Stage D output payload keeps node/vnode projection
/// maps and cluster boundary x-extents grouped for one return object.
pub struct PositionOutputMaps {
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
}

///|
/// Graphviz parity: final output map source bundle keeps dotted-edge
/// alignment, cluster-boundary capture, vnode projection, and cluster-rounding
/// prerequisites grouped before one deterministic assembly pass.
pub(all) struct PositionOutputBuildSources {
  has_clusters : Bool
  has_dotted_edges : Bool
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  x_positions : Map[String, Double]
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  use_vnodes_for_xpos : Bool
  vnode_ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  cluster_ln_prefix : String
  cluster_rn_prefix : String
}

///|
/// Graphviz parity: final output map assembly keeps intercluster alignment,
/// cluster boundary capture, and vnode projection order unchanged.
/// Do not change behavior without updating fixtures/tests.
pub fn build_position_output_maps_from_sources(
  sources : PositionOutputBuildSources,
) -> PositionOutputMaps {
  if sources.has_clusters && sources.has_dotted_edges && intercluster_alignment_enabled() {
    adjust_intercluster_alignment(
      {
        nodes: sources.nodes,
        edges: sources.edges,
        ranks: sources.ranks,
        x_positions: sources.x_positions,
        cluster_keys: sources.cluster_keys,
        intercluster_keys: sources.intercluster_keys,
        nodesep_pt: sources.nodesep_pt,
        has_edge_labels: sources.has_edge_labels,
      },
    )
  }
  // Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
  let cluster_names : Map[String, Bool] = Map::new()
  if sources.has_clusters {
    @shared.collect_cluster_names(sources.graph, cluster_names)
  }
  let cluster_boundary_x =
    build_cluster_boundary_x(
      {
        has_clusters: sources.has_clusters && cluster_names.length() > 0,
        x_positions: sources.x_positions,
        is_cluster_boundary:
          (name) =>
            name.has_prefix(sources.cluster_ln_prefix) ||
            name.has_prefix(sources.cluster_rn_prefix),
        boundary_cluster_key:
          (name) =>
            cluster_key_from_boundary(
              name,
              cluster_names,
              sources.cluster_ln_prefix,
              sources.cluster_rn_prefix,
            ),
        is_left_boundary: (name) => name.has_prefix(sources.cluster_ln_prefix),
      },
    )
  // Let the final bounding-box translation handle normalization, matching Graphviz.
  let vnode_positions =
    build_vnode_positions(
      {
        use_vnodes_for_xpos: sources.use_vnodes_for_xpos,
        vnode_ranks: sources.vnode_ranks,
        x_positions: sources.x_positions,
        rank_y: sources.rank_y,
        fallback_fn: () =>
          vnode_positions_from_edges(
            sources.edges,
            sources.ranks,
            sources.vnode_ranks,
            sources.edge_vnodes,
            sources.x_positions,
            sources.rank_y,
          ),
      },
    )
  let positions =
    build_node_positions_map(
      sources.nodes,
      sources.x_positions,
      sources.y_positions,
    )
  {
    positions,
    vnode_positions,
    cluster_ln_x: cluster_boundary_x.cluster_ln_x,
    cluster_rn_x: cluster_boundary_x.cluster_rn_x,
  }
}
