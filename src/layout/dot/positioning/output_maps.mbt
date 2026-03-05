///|
/// Graphviz parity: intercluster x alignment gate uses DOT_INTERCLUSTER_ALIGN
/// env parsing once, preserving Graphviz-compatible truthy/falsy semantics.
pub fn intercluster_alignment_enabled() -> Bool {
  match @sys.get_env_var("DOT_INTERCLUSTER_ALIGN") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
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
/// callbacks grouped before one deterministic assembly pass.
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
  vnode_clusters : Map[String, String]
  sizes : Map[String, @shared.NodeSize]
  cluster_ln_prefix : String
  cluster_rn_prefix : String
  collect_cluster_names_fn : (@cgraph.Graph, Map[String, Bool]) -> Unit
  cluster_key_from_boundary_fn : (String, Map[String, Bool]) -> String?
  adjust_intercluster_alignment_fn : (
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Map[String, Int],
    Map[String, Double],
    Map[String, String],
    Map[String, String],
    Double,
    Bool,
  ) -> Unit
  vnode_positions_from_edges_fn : (
    Array[@cgraph.Edge],
    Map[String, Int],
    Map[String, Int],
    Map[String, Array[String]],
    Map[String, Double],
    Map[Int, Double],
  ) -> Map[String, @geom.Point]
  cluster_rounding_enabled_fn : () -> Bool
  adjust_cluster_positions_fn : (
    @cgraph.Graph,
    Map[String, @geom.Point],
    Map[String, @geom.Point],
    Map[String, String],
    Map[String, @shared.NodeSize],
  ) -> @geom.Rect?
}

///|
/// Graphviz parity: final output map assembly keeps intercluster alignment,
/// cluster boundary capture, vnode projection, and rounding-adjust order
/// unchanged.
/// Do not change behavior without updating fixtures/tests.
pub fn build_position_output_maps_from_sources(
  sources : PositionOutputBuildSources,
) -> PositionOutputMaps {
  if sources.has_clusters && sources.has_dotted_edges && intercluster_alignment_enabled() {
    (sources.adjust_intercluster_alignment_fn)(
      sources.nodes,
      sources.edges,
      sources.ranks,
      sources.x_positions,
      sources.cluster_keys,
      sources.intercluster_keys,
      sources.nodesep_pt,
      sources.has_edge_labels,
    )
  }
  // Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
  let cluster_names : Map[String, Bool] = Map::new()
  if sources.has_clusters {
    (sources.collect_cluster_names_fn)(sources.graph, cluster_names)
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
          (name) => (sources.cluster_key_from_boundary_fn)(name, cluster_names),
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
          (sources.vnode_positions_from_edges_fn)(
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
  if sources.has_clusters && (sources.cluster_rounding_enabled_fn)() {
    let _ =
      (sources.adjust_cluster_positions_fn)(
        sources.graph,
        positions,
        vnode_positions,
        sources.vnode_clusters,
        sources.sizes,
      )
  }
  {
    positions,
    vnode_positions,
    cluster_ln_x: cluster_boundary_x.cluster_ln_x,
    cluster_rn_x: cluster_boundary_x.cluster_rn_x,
  }
}
