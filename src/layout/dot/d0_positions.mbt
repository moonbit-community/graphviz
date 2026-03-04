///|
/// Stage D Phase D0 split: position/xpos stage-local
/// type definitions shared across Stage D helper phases.

///|
priv struct PositionResult {
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  flat_label_edge_vnodes : Map[String, String]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
}

///|
priv struct XposComputationInput {
  x_sizes : Map[String, NodeSize]
  x_rank_keys : Array[Int]
  x_ranks : Map[String, Int]
  x_extra_nodes : Array[@ordering.ExtraConstraintNode]
  x_edge_vnodes : Map[String, Array[String]]
}

///|
priv struct XposVNodeOrderState {
  vnode_order_keys : Map[String, Double]
  has_vnode_order : Bool
}

///|
priv struct XposOrderEdgePortData {
  x_base_sizes : Map[String, NodeSize]
  x_order_sizes : Map[String, NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
}

///|
priv struct XPositionSeedData {
  has_vnode_order : Bool
  x_base_sizes : Map[String, NodeSize]
  x_order_sizes : Map[String, NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
}

///|
/// Graphviz parity: x-stage seed input keeps vnode mode plus ordering/rank
/// context grouped before order-index, vnode-order, and edge-port precompute.
priv struct XSeedBuildInput {
  use_vnodes_for_xpos : Bool
  pipeline : PositionPipelineContext
}

///|
/// Graphviz parity: vnode-order probe input keeps order-index plus x-seed
/// contexts grouped before Graphviz-compatible vnode-order derivation.
priv struct VnodeOrderBuildInput {
  use_vnodes_for_xpos : Bool
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  pipeline : PositionPipelineContext
  order_index : Map[String, Int]
}

///|
/// Graphviz parity: initial x-group assembly input keeps ordered groups,
/// vnode order, and cluster cleanup gate together before xpos constraints.
priv struct InitialXGroupsBuildInput {
  use_vnodes_for_xpos : Bool
  ordered_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  order_index : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_order_keys : Map[String, Double]
  cluster_meta : ClusterMetadata
}

///|
/// Graphviz parity: x-stage flat-label augmentation input keeps reorder flags,
/// stage contexts, and seed snapshots grouped for one reorder+augmentation
/// pass.
priv struct XFlatLabelBuildInput {
  xpos_reorder_enabled : Bool
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
  pipeline : PositionPipelineContext
  x_seed : XPositionSeedData
}

///|
/// Graphviz parity: flat-label augmentation input keeps x-stage pipeline,
/// vnode-xpos gate, and mutable x-group/cluster-key snapshots grouped for one
/// augmentation pass.
priv struct FlatLabelAugmentationBuildInput {
  pipeline : PositionPipelineContext
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, NodeSize]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
}

///|
priv struct XposFlatLabelAugmentation {
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Graphviz parity: shared position pipeline context keeps graph/rank/cluster
/// snapshots grouped so x/y/output stages consume the same base inputs.
priv struct PositionPipelineContext {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

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
priv struct XWithFlatLabelData {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, NodeSize]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Graphviz parity: final projection stage input keeps x-stage bundle and
/// pipeline contexts grouped for one y/x solve and output map assembly pass.
priv struct ProjectionBuildInput {
  pipeline : PositionPipelineContext
  x_data : XWithFlatLabelData
}

///|
/// Graphviz parity: x-position solve input keeps x-stage bundle plus ordering
/// and rank context grouped for one compute_x_positions invocation.
priv struct XPositionBuildInput {
  pipeline : PositionPipelineContext
  x_data : XWithFlatLabelData
}

///|
priv struct PositionModeFlags {
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
}


///|
/// Stage D Phase D1/D2/D3/D5 split: xpos mode/seed/reorder-cleanup
/// helpers used by the Stage D position orchestrator.

///|
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once from prep+ordering and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_flags(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> PositionModeFlags {
  let use_vnodes_for_xpos =
    prep.has_edge_labels || prep.has_port_edges ||
    ordering.vnode_count <= MAX_XPOS_VNODES
  let allow_xpos_reorder =
    !use_vnodes_for_xpos || ordering.vnode_count <= MAX_XPOS_REORDER_VNODES
  let graphviz_flip = prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL
  {
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    graphviz_flip,
  }
}


///|
/// Graphviz parity: x-stage precompute in compute_positions keeps mode flags,
/// reorder/transpose, and flat-label augmentation in Graphviz-aligned order
/// and wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_x_with_flat_labels(
  pipeline : PositionPipelineContext,
) -> XWithFlatLabelData {
  let mode_flags = build_position_mode_flags(pipeline.prep, pipeline.ordering)
  let x_seed =
    build_x_seed_data(
      {
        use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
        pipeline,
      },
    )
  let flat_label_augmentation =
    build_x_flat_labels(
      {
        xpos_reorder_enabled: false,
        use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
        allow_xpos_reorder: mode_flags.allow_xpos_reorder,
        graphviz_flip: mode_flags.graphviz_flip,
        pipeline,
        x_seed,
      },
    )
  {
    use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
    x_base_sizes: x_seed.x_base_sizes,
    x_groups: flat_label_augmentation.x_groups,
    x_cluster_keys: flat_label_augmentation.x_cluster_keys,
    flat_label_edges: flat_label_augmentation.flat_label_edges,
    flat_label_nodes: flat_label_augmentation.flat_label_nodes,
    flat_label_edge_vnodes: flat_label_augmentation.flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: vnode order-key derivation follows Graphviz: explicit
/// ordered_groups_with_vnodes means vnode order is present; otherwise build
/// keys from edge-vnode chains and mark presence by non-empty key map.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_state(
  input : VnodeOrderBuildInput,
) -> XposVNodeOrderState {
  let pipeline = input.pipeline
  let mut vnode_order_keys : Map[String, Double] = Map::new()
  let mut has_vnode_order = false
  if input.use_vnodes_for_xpos && input.ordered_groups_with_vnodes.length() == 0 {
    vnode_order_keys = build_vnode_order_keys(
      pipeline.prep.edges,
      pipeline.rank_data.edge_tail,
      pipeline.rank_data.edge_head,
      pipeline.rank_data.edge_reversed,
      pipeline.rank_data.ranks,
      input.order_index,
      pipeline.cluster_meta.intercluster_keys,
      pipeline.cluster_meta.cluster_parents,
      pipeline.ordering.vnode_info.edge_vnodes,
      pipeline.ordering.vnode_info.vnode_ranks,
    )
    for _name, _ in vnode_order_keys {
      has_vnode_order = true
      break
    }
  }
  if input.use_vnodes_for_xpos && input.ordered_groups_with_vnodes.length() > 0 {
    has_vnode_order = true
  }
  { vnode_order_keys, has_vnode_order }
}

///|
/// Graphviz parity: x-order sizes and edge port position/order arrays are
/// derived from layout-coordinate sizes before any xpos reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_x_order_edge_port_data(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
) -> XposOrderEdgePortData {
  // Graphviz parity: x-positioning uses layout-coordinate node sizes,
  // so rankdir flip is handled via prep.sizes (not ordering-space widths).
  let x_base_sizes = apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    prep.sizes,
    prep.rankdir,
    prep.record_orientation,
  )
  let x_order_sizes =
    if use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let x_edge_port_x_samples =
    compute_edge_port_positions(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let x_edge_tail_port_x = x_edge_port_x_samples.tail_values
  let x_edge_head_port_x = x_edge_port_x_samples.head_values
  let x_edge_port_order_samples =
    compute_edge_port_orders(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let x_edge_tail_port_order = x_edge_port_order_samples.tail_values
  let x_edge_head_port_order = x_edge_port_order_samples.head_values
  {
    x_base_sizes,
    x_order_sizes,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
  }
}


///|
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, and vnode cluster-key overlay only on vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_label_augmentation(
  input : FlatLabelAugmentationBuildInput,
) -> XposFlatLabelAugmentation {
  let pipeline = input.pipeline
  let mut next_x_groups = input.x_groups
  let mut flat_label_edges : Array[ConstraintEdge] = []
  let mut flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let mut flat_label_edge_vnodes : Map[String, String] = Map::new()
  let next_x_cluster_keys = input.x_cluster_keys
  let existing_names : Map[String, Bool] = Map::new()
  for node in pipeline.prep.nodes {
    existing_names[node.name()] = true
  }
  for vnode, _ in pipeline.ordering.vnode_info.vnode_ranks {
    existing_names[vnode] = true
  }
  if input.use_vnodes_for_xpos {
    let flat_label_vnodes = add_flat_label_vnodes(
      pipeline.prep.edges,
      pipeline.rank_data.edge_tail,
      pipeline.rank_data.edge_head,
      pipeline.rank_data.ranks,
      pipeline.ordering.ordered_groups,
      pipeline.rank_heights.nodesep_pt,
      pipeline.prep.rankdir,
      input.x_base_sizes,
      pipeline.ordering.edge_cluster_keys,
      pipeline.cluster_meta.cluster_parents,
      existing_names,
      pipeline.ordering.vnode_info,
      next_x_groups,
    )
    next_x_groups = flat_label_vnodes.x_groups
    flat_label_edges = flat_label_vnodes.flat_label_edges
    flat_label_nodes = flat_label_vnodes.flat_label_nodes
    flat_label_edge_vnodes = flat_label_vnodes.flat_label_edge_vnodes
    for name, key in pipeline.ordering.vnode_info.vnode_clusters {
      next_x_cluster_keys[name] = key
    }
  }
  {
    x_groups: next_x_groups,
    x_cluster_keys: next_x_cluster_keys,
    flat_label_edges,
    flat_label_nodes,
    flat_label_edge_vnodes,
  }
}

///|
/// Stage D Phase D0 split: position orchestrator helpers
/// for x/y solve assembly and final result wiring.

///|
priv struct ClusterBoundaryXOutput {
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
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
/// Graphviz parity: initial x-groups must preserve vnode-aware ordering and
/// strip cluster skeleton placeholders before xpos constraints run.
/// Do not change behavior without updating fixtures/tests.
fn build_initial_x_groups(
  input : InitialXGroupsBuildInput,
) -> Map[Int, Array[String]] {
  let mut x_groups =
    if input.use_vnodes_for_xpos {
      if input.ordered_groups_with_vnodes.length() > 0 {
        @ordering.clone_rank_groups(input.ordered_groups_with_vnodes)
      } else {
        @ordering.build_x_groups_with_vnodes(
          input.ordered_groups,
          input.order_index,
          input.vnodes_by_rank,
          input.vnode_order_keys,
        )
      }
    } else {
      input.ordered_groups
    }
  if input.cluster_meta.has_clusters {
    let cleaned : Map[Int, Array[String]] = Map::new()
    for rank, names in x_groups {
      let filtered : Array[String] = []
      for name in names {
        if cluster_key_from_skeleton(name) is None {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        cleaned[rank] = filtered
      }
    }
    x_groups = cleaned
  }
  x_groups
}

///|
/// Graphviz parity: pre-reorder x-stage setup keeps order-index build, vnode
/// order probing, edge-port metadata, and initial group/cluster maps unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_seed_data(
  input : XSeedBuildInput,
) -> XPositionSeedData {
  let pipeline = input.pipeline
  let order_index = @ordering.build_order_index(pipeline.ordering.ordered_groups)
  let vnode_order_state =
    build_vnode_order_state(
      {
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        ordered_groups_with_vnodes: pipeline.ordering.ordered_groups_with_vnodes,
        pipeline,
        order_index,
      },
    )
  let has_vnode_order = vnode_order_state.has_vnode_order
  let x_order_edge_port_data =
    build_x_order_edge_port_data(
      input.use_vnodes_for_xpos,
      pipeline.prep,
      pipeline.rank_data,
      pipeline.ordering,
    )
  let x_groups =
    build_initial_x_groups(
      {
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        ordered_groups: pipeline.ordering.ordered_groups,
        ordered_groups_with_vnodes: pipeline.ordering.ordered_groups_with_vnodes,
        order_index,
        vnodes_by_rank: pipeline.ordering.vnode_info.vnodes_by_rank,
        vnode_order_keys: vnode_order_state.vnode_order_keys,
        cluster_meta: pipeline.cluster_meta,
      },
    )
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in pipeline.cluster_meta.cluster_keys {
    x_cluster_keys[name] = key
  }
  if input.use_vnodes_for_xpos {
    for name, key in pipeline.ordering.vnode_info.vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  {
    has_vnode_order,
    x_base_sizes: x_order_edge_port_data.x_base_sizes,
    x_order_sizes: x_order_edge_port_data.x_order_sizes,
    x_edge_tail_port_x: x_order_edge_port_data.x_edge_tail_port_x,
    x_edge_head_port_x: x_order_edge_port_data.x_edge_head_port_x,
    x_edge_tail_port_order: x_order_edge_port_data.x_edge_tail_port_order,
    x_edge_head_port_order: x_order_edge_port_data.x_edge_head_port_order,
    x_groups,
    x_cluster_keys,
  }
}

///|
/// Graphviz parity: x-stage reorder pipeline input maps x-seed snapshots plus
/// shared stage context to the positioning subpackage in one explicit boundary.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_reorder_pipeline_input(
  input : XFlatLabelBuildInput,
) -> @positioning.XposReorderPipelineInput {
  let pipeline = input.pipeline
  @positioning.build_xpos_reorder_pipeline_input(
    input.xpos_reorder_enabled,
    input.use_vnodes_for_xpos,
    input.allow_xpos_reorder,
    input.x_seed.has_vnode_order,
    pipeline.cluster_meta.ordering_set,
    pipeline.cluster_meta.has_clusters,
    input.x_seed.x_groups,
    input.x_seed.x_order_sizes,
    input.x_seed.x_cluster_keys,
    pipeline.cluster_meta.cluster_min_rank,
    pipeline.cluster_meta.cluster_max_rank,
    pipeline.prep.node_order,
    CLUSTER_SKELETON_PREFIX,
    vnode_size_from_widths(1.0, 1.0),
    pipeline.prep.edges,
    pipeline.rank_data.edge_tail,
    pipeline.rank_data.edge_head,
    pipeline.rank_data.ranks,
    pipeline.ordering.vnode_info.edge_vnodes,
    pipeline.ordering.vnode_info.vnode_ranks,
    input.x_seed.x_edge_tail_port_x,
    input.x_seed.x_edge_head_port_x,
    input.x_seed.x_edge_tail_port_order,
    input.x_seed.x_edge_head_port_order,
    CL_CROSS,
    pipeline.cluster_meta.rank_same_groups,
    pipeline.cluster_meta.rank_same_order,
    pipeline.rank_heights.nodesep_pt,
    pipeline.prep.has_edge_labels,
    pipeline.cluster_meta.flat_constraints,
    input.graphviz_flip,
    pipeline.prep.nodes,
    pipeline.ordering.order_edges,
    pipeline.ordering.order_edge_tail,
    pipeline.ordering.order_edge_head,
    pipeline.ordering.edge_order,
    pipeline.prep.port_order_positions,
    pipeline.prep.port_order_contrib,
    pipeline.cluster_meta.cluster_skeleton,
    4,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder uses edge-port x-position samples
/// derived from compass/record port geometry before reorder scoring.
/// Do not change behavior without updating fixtures/tests.
fn compute_xpos_reorder_port_positions(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  let samples = compute_edge_port_positions(nodes, edges, edge_tail, edge_head, sizes)
  (samples.tail_values, samples.head_values)
}

///|
/// Graphviz parity: non-cluster xpos reorder uses edge-port order fractions to
/// break mincross scoring ties consistently with Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn compute_xpos_reorder_port_orders(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  let samples = compute_edge_port_orders(nodes, edges, edge_tail, edge_head, sizes)
  (samples.tail_values, samples.head_values)
}

///|
/// Graphviz parity: x-stage reorder and transpose-cleanup are applied in
/// fixed order before flat-label augmentation consumes updated x_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_x_groups_after_reorder(
  input : XFlatLabelBuildInput,
) -> Map[Int, Array[String]] {
  @positioning.build_x_groups_after_reorder(
    build_xpos_reorder_pipeline_input(input),
    compute_xpos_reorder_port_positions,
    compute_xpos_reorder_port_orders,
  )
}

///|
/// Graphviz parity: x-stage reorder + transpose cleanup + flat-label vnode
/// augmentation must run in the same order and with the same inputs as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_x_flat_labels(
  input : XFlatLabelBuildInput,
) -> XposFlatLabelAugmentation {
  let x_groups = build_x_groups_after_reorder(input)
  build_flat_label_augmentation(
    {
      pipeline: input.pipeline,
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      x_base_sizes: input.x_seed.x_base_sizes,
      x_groups,
      x_cluster_keys: input.x_seed.x_cluster_keys,
    },
  )
}

///|
/// Graphviz parity: xpos solver inputs must preserve vnode-size merge,
/// rank-map/key derivation, and vnode-edge/slack toggles.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_computation_input(
  input : XPositionBuildInput,
) -> XposComputationInput {
  let x_sizes =
    if input.x_data.use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(
        input.x_data.x_base_sizes,
        input.pipeline.ordering.vnode_info.vnode_sizes,
      )
    } else {
      input.x_data.x_base_sizes
    }
  let x_rank_keys = @ordering.collect_rank_keys(input.x_data.x_groups)
  let x_ranks = @ordering.build_node_ranks(input.x_data.x_groups)
  let vnode_extra_nodes =
    if input.x_data.use_vnodes_for_xpos {
      @ordering.build_vnode_extra_nodes(
        input.pipeline.ordering.vnode_creation_order,
        input.pipeline.ordering.vnode_info.vnode_ranks,
      )
    } else {
      []
    }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes =
    if input.x_data.use_vnodes_for_xpos {
      input.pipeline.ordering.vnode_info.edge_vnodes
    } else {
      Map::new()
    }
  { x_sizes, x_rank_keys, x_ranks, x_extra_nodes, x_edge_vnodes }
}

///|
/// Graphviz parity: x-position stage must use identical xpos input assembly,
/// and solver invocation as Graphviz-aligned pipeline order.
/// Do not change behavior without updating fixtures/tests.
fn compute_layout_x_positions(
  input : XPositionBuildInput,
) -> Map[String, Double] {
  let xpos_input = build_xpos_computation_input(input)
  let x_positions = compute_x_positions(
    input.pipeline.graph,
    input.pipeline.prep.nodes,
    input.pipeline.prep.edges,
    input.pipeline.rank_data.edge_tail,
    input.pipeline.rank_data.edge_head,
    input.pipeline.rank_data.edge_out_order,
    input.pipeline.ordering.nlist_order,
    input.pipeline.ordering.gdnlist_order,
    xpos_input.x_ranks,
    xpos_input.x_rank_keys,
    input.x_data.x_groups,
    xpos_input.x_sizes,
    input.pipeline.prep.output_sizes,
    input.x_data.x_cluster_keys,
    input.pipeline.rank_heights.nodesep_pt,
    input.pipeline.prep.has_edge_labels,
    xpos_input.x_extra_nodes,
    input.x_data.flat_label_edges,
    xpos_input.x_edge_vnodes,
  )
  x_positions
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

///|
/// Graphviz parity: final projection stage in compute_positions keeps y/x solve
/// projection and result assembly sequencing identical to Graphviz-aligned flow.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result(
  input : ProjectionBuildInput,
) -> PositionResult {
  let pipeline = input.pipeline
  let x_data = input.x_data
  let y_position_data =
    build_y_position_data(
      {
        pipeline,
        flat_label_nodes: x_data.flat_label_nodes,
      },
    )
  let x_positions =
    compute_layout_x_positions(
      {
        pipeline,
        x_data,
      },
    )
  let position_output_maps =
    build_position_output_maps(
      {
        pipeline,
        use_vnodes_for_xpos: x_data.use_vnodes_for_xpos,
        x_positions,
        y_positions: y_position_data.y_positions,
        rank_y: y_position_data.rank_y,
      },
    )
  {
    x_groups: x_data.x_groups,
    rank_y: y_position_data.rank_y,
    positions: position_output_maps.positions,
    vnode_positions: position_output_maps.vnode_positions,
    cluster_ln_x: position_output_maps.cluster_ln_x,
    cluster_rn_x: position_output_maps.cluster_rn_x,
    flat_label_edge_vnodes: x_data.flat_label_edge_vnodes,
    rank_ht1: pipeline.rank_heights.rank_ht1,
    rank_ht2: pipeline.rank_heights.rank_ht2,
    cluster_bbox_heights: y_position_data.cluster_bbox_heights,
  }
}

///|
/// Graphviz parity: x-positioning aligned to refs/graphviz/lib/dotgen/position.c + dotgen/cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> PositionResult {
  let pipeline : PositionPipelineContext = {
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
  }
  let x_data =
    build_x_with_flat_labels(pipeline)
  build_projection_result(
    {
      pipeline,
      x_data,
    },
  )
}
