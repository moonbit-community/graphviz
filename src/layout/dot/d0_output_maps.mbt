///|
/// Stage D Phase D0 split: output map assembly helpers
/// for intercluster alignment, vnode projection, and final position maps.

///|
priv struct PositionOutputMaps {
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
}

///|
/// Graphviz parity: final output map assembly input keeps cluster/rank/xpos
/// snapshots grouped so intercluster alignment, boundary capture, vnode
/// projection, and rounding run in Graphviz-equivalent order.
priv struct PositionOutputBuildInput {
  pipeline : PositionPipelineContext
  use_vnodes_for_xpos : Bool
  x_positions : Map[String, Double]
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
}

///|
/// Graphviz parity: vnode position projection input keeps x/y rank maps and
/// vnode context grouped so direct/fallback vnode projection follows the same
/// branch gating and data sources as Graphviz.
priv struct VnodePositionBuildInput {
  pipeline : PositionPipelineContext
  use_vnodes_for_xpos : Bool
  x_positions : Map[String, Double]
  rank_y : Map[Int, Double]
}

///|
priv struct ClusterBoundaryXOutput {
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
}

///|
/// Graphviz parity: intercluster x alignment gate uses DOT_INTERCLUSTER_ALIGN
/// env parsing once, preserving Graphviz-compatible truthy/falsy semantics.
fn intercluster_alignment_enabled() -> Bool {
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
fn build_node_positions_map(
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
/// Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_boundary_x(
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  x_positions : Map[String, Double],
) -> ClusterBoundaryXOutput {
  let cluster_ln_x : Map[String, Double] = Map::new()
  let cluster_rn_x : Map[String, Double] = Map::new()
  if cluster_meta.has_clusters {
    let cluster_names : Map[String, Bool] = Map::new()
    collect_cluster_names(graph, cluster_names)
    if cluster_names.length() > 0 {
      for name, pos_x in x_positions {
        if name.has_prefix(CLUSTER_LN_PREFIX) ||
          name.has_prefix(CLUSTER_RN_PREFIX) {
          match cluster_key_from_boundary(name, cluster_names) {
            Some(cluster_key) =>
              if name.has_prefix(CLUSTER_LN_PREFIX) {
                cluster_ln_x[cluster_key] = pos_x
              } else {
                cluster_rn_x[cluster_key] = pos_x
              }
            None => ()
          }
        }
      }
    }
  }
  { cluster_ln_x, cluster_rn_x }
}

///|
/// Graphviz parity: vnode output positions are either direct xpos/rank pairs
/// (when xpos consumed vnode graph) or endpoint-interpolated fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_positions(
  input : VnodePositionBuildInput,
) -> Map[String, @geom.Point] {
  if input.use_vnodes_for_xpos {
    let positions : Map[String, @geom.Point] = Map::new()
    for name, rank in input.pipeline.ordering.vnode_info.vnode_ranks {
      let pos_x = input.x_positions.get(name).unwrap_or_default()
      let pos_y = input.rank_y.get(rank).unwrap_or_default()
      positions[name] = { x: pos_x, y: pos_y }
    }
    positions
  } else {
    vnode_positions_from_edges(
      input.pipeline.prep.edges,
      input.pipeline.rank_data.ranks,
      input.pipeline.ordering.vnode_info.vnode_ranks,
      input.pipeline.ordering.vnode_info.edge_vnodes,
      input.x_positions,
      input.rank_y,
    )
  }
}

///|
/// Graphviz parity: final output map assembly keeps intercluster alignment,
/// cluster boundary capture, vnode projection, and rounding adjustment order.
/// Do not change behavior without updating fixtures/tests.
fn build_position_output_maps(
  input : PositionOutputBuildInput,
) -> PositionOutputMaps {
  if input.pipeline.cluster_meta.has_clusters && input.pipeline.prep.has_dotted_edges &&
    intercluster_alignment_enabled() {
    adjust_intercluster_alignment(
      input.pipeline.prep.nodes,
      input.pipeline.prep.edges,
      input.pipeline.rank_data.ranks,
      input.x_positions,
      input.pipeline.cluster_meta.cluster_keys,
      input.pipeline.cluster_meta.intercluster_keys,
      input.pipeline.rank_heights.nodesep_pt,
      input.pipeline.prep.has_edge_labels,
    )
  }
  // Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
  let cluster_boundary_x =
    build_cluster_boundary_x(
      input.pipeline.graph,
      input.pipeline.cluster_meta,
      input.x_positions,
    )
  // Let the final bounding-box translation handle normalization, matching Graphviz.
  let vnode_positions =
    build_vnode_positions(
      {
        pipeline: input.pipeline,
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        x_positions: input.x_positions,
        rank_y: input.rank_y,
      },
    )
  let positions =
    build_node_positions_map(
      input.pipeline.prep.nodes,
      input.x_positions,
      input.y_positions,
    )
  if input.pipeline.cluster_meta.has_clusters && cluster_rounding_enabled() {
    let _ = adjust_cluster_positions(
      input.pipeline.graph,
      positions,
      vnode_positions,
      input.pipeline.ordering.vnode_info.vnode_clusters,
      input.pipeline.prep.sizes,
    )
  }
  {
    positions,
    vnode_positions,
    cluster_ln_x: cluster_boundary_x.cluster_ln_x,
    cluster_rn_x: cluster_boundary_x.cluster_rn_x,
  }
}
