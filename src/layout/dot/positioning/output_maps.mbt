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
