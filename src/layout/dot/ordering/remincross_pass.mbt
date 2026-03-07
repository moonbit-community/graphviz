///|
/// Ordering domain: clustered ReMincross pass orchestration helpers used by
/// Stage C finalize flow before output group cleanup.

///|
/// Graphviz parity: clustered ReMincross build context keeps finalize-stage
/// snapshots unchanged and is paired with per-branch base groups at call time.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ReMincrossPassBuildContext {
  ratio : String
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_order : Array[String]
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
  local_cluster_order : Map[String, Int]
  cluster_parents : Map[String, String?]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_flat_constraints : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_sizes : Map[String, @node_primitives.NodeSize]
  order_sizes : Map[String, @node_primitives.NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  root_tail_order_override : Array[String]?
  root_cluster : String
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered ReMincross context-source bundle keeps finalize
/// snapshots paired with reorder setup and vnode metadata before call assembly.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ReMincrossPassBuildSources {
  ratio : String
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  reorder_setup : OrderingReorderSetup
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_order : Array[String]
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
  local_cluster_order : Map[String, Int]
  cluster_parents : Map[String, String?]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_flat_constraints : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_sizes : Map[String, @node_primitives.NodeSize]
  order_sizes : Map[String, @node_primitives.NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  root_tail_order_override : Array[String]?
  root_cluster : String
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered ReMincross source input keeps root/finalize
/// snapshots grouped before context-source assembly.
pub(all) struct ReMincrossPassSourceInput {
  ratio : String
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  reorder_setup : OrderingReorderSetup
  creation_order : Array[String]
  cluster_order : Array[String]
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
  local_cluster_order : Map[String, Int]
  cluster_parents : Map[String, String?]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_flat_constraints : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_sizes : Map[String, @node_primitives.NodeSize]
  order_sizes : Map[String, @node_primitives.NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  root_tail_order_override : Array[String]?
  root_cluster : String
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered ReMincross source assembly keeps finalize
/// snapshots and reorder setup data grouped before context conversion.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_pass_sources(
  input : ReMincrossPassSourceInput,
) -> ReMincrossPassBuildSources {
  {
    ratio: input.ratio,
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_reversed: input.edge_reversed,
    edge_tail_port_x: input.edge_tail_port_x,
    edge_head_port_x: input.edge_head_port_x,
    edge_tail_port_order: input.edge_tail_port_order,
    edge_head_port_order: input.edge_head_port_order,
    ranks: input.ranks,
    reorder_setup: input.reorder_setup,
    creation_order: input.creation_order,
    edges_by_tail: input.reorder_setup.class2_data.edges_by_tail,
    cluster_order: input.cluster_order,
    cluster_keys: input.cluster_keys,
    intercluster_keys: input.intercluster_keys,
    local_cluster_order: input.local_cluster_order,
    cluster_parents: input.cluster_parents,
    cluster_min_rank: input.cluster_min_rank,
    cluster_max_rank: input.cluster_max_rank,
    cluster_flat_constraints: input.cluster_flat_constraints,
    rank_same_groups: input.rank_same_groups,
    rank_same_order: input.rank_same_order,
    edge_vnodes: input.edge_vnodes,
    vnode_ranks: input.vnode_ranks,
    vnodes_by_rank: input.vnodes_by_rank,
    vnode_sizes: input.vnode_sizes,
    order_sizes: input.order_sizes,
    rank_same_constraints: input.rank_same_constraints,
    ordered_with_vnodes: input.ordered_with_vnodes,
    real_nodes: input.real_nodes,
    root_tail_order_override: input.root_tail_order_override,
    root_cluster: input.root_cluster,
    nodesep_pt: input.nodesep_pt,
    has_edge_labels: input.has_edge_labels,
    port_order_positions: input.port_order_positions,
    port_order_contrib: input.port_order_contrib,
  }
}

///|
/// Graphviz parity: clustered ReMincross context payload is assembled from one
/// finalize snapshot without changing Graphviz startpass=2 call order.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_pass_context_from_sources(
  sources : ReMincrossPassBuildSources,
) -> ReMincrossPassBuildContext {
  {
    ratio: sources.ratio,
    edges: sources.edges,
    edge_tail: sources.edge_tail,
    edge_head: sources.edge_head,
    edge_reversed: sources.edge_reversed,
    edge_tail_port_x: sources.edge_tail_port_x,
    edge_head_port_x: sources.edge_head_port_x,
    edge_tail_port_order: sources.edge_tail_port_order,
    edge_head_port_order: sources.edge_head_port_order,
    ranks: sources.ranks,
    order_with_vnodes: sources.reorder_setup.order_with_vnodes,
    creation_order: sources.creation_order,
    edges_by_tail: sources.edges_by_tail,
    cluster_order: sources.cluster_order,
    cluster_keys: sources.cluster_keys,
    intercluster_keys: sources.intercluster_keys,
    local_cluster_order: sources.local_cluster_order,
    cluster_parents: sources.cluster_parents,
    cluster_min_rank: sources.cluster_min_rank,
    cluster_max_rank: sources.cluster_max_rank,
    cluster_flat_constraints: sources.cluster_flat_constraints,
    rank_same_groups: sources.rank_same_groups,
    rank_same_order: sources.rank_same_order,
    edge_vnodes: sources.edge_vnodes,
    vnode_ranks: sources.vnode_ranks,
    vnodes_by_rank: sources.vnodes_by_rank,
    vnode_sizes: sources.vnode_sizes,
    order_sizes: sources.order_sizes,
    rank_same_constraints: sources.rank_same_constraints,
    ordered_with_vnodes: sources.ordered_with_vnodes,
    real_nodes: sources.real_nodes,
    root_tail_order_override: sources.root_tail_order_override,
    root_cluster: sources.root_cluster,
    graphviz_flip: sources.reorder_setup.graphviz_flip,
    nodesep_pt: sources.nodesep_pt,
    has_edge_labels: sources.has_edge_labels,
    port_order_positions: sources.port_order_positions,
    port_order_contrib: sources.port_order_contrib,
  }
}

///|
/// Graphviz parity: clustered ReMincross pass output keeps cleaned real-node
/// groups and vnode-inclusive groups after startpass=2 cleanup reorder.
pub(all) struct ReMincrossPassOutput {
  ordered_groups : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
/// Graphviz parity: Stage C finalize payload keeps root-cleanup sources,
/// cluster-rank replay maps, and ReMincross context snapshots unchanged.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredFinalizeInputs {
  order_with_clusters : Bool
  order_rank_keys : Array[Int]
  ordered : Map[Int, Array[String]]
  cluster_rank_order : Map[Int, Map[String, Int]]
  remincross_context : ReMincrossPassBuildContext
}

///|
/// Graphviz parity: clustered finalize input-source bundle keeps root rank
/// groups and ReMincross context snapshots paired before cleanup dispatch.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredFinalizeInputsBuildSources {
  reorder_setup : OrderingReorderSetup
  order_rank_keys : Array[Int]
  ordered : Map[Int, Array[String]]
  cluster_rank_order : Map[Int, Map[String, Int]]
  remincross_sources : ReMincrossPassBuildSources
}

///|
/// Graphviz parity: clustered finalize payload is assembled from one source
/// bundle before final group cleanup and ReMincross pass.
/// Do not change behavior without updating fixtures/tests.
pub fn build_clustered_finalize_inputs_from_sources(
  sources : ClusteredFinalizeInputsBuildSources,
) -> ClusteredFinalizeInputs {
  {
    order_with_clusters: sources.reorder_setup.order_with_clusters,
    order_rank_keys: sources.order_rank_keys,
    ordered: sources.ordered,
    cluster_rank_order: sources.cluster_rank_order,
    remincross_context:
      build_remincross_pass_context_from_sources(sources.remincross_sources),
  }
}

///|
/// Graphviz parity: clustered finalize source bundle keeps root-phase replay
/// snapshots paired with finalize cleanup/context inputs before dispatch.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredFinalizeInputsBuildRootPhaseSources {
  phase_base : RootRankOrderPhaseBase
  root_cluster_stage : RootAndClusterRanksOutput
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  real_nodes : Map[String, Bool]
  reorder_setup : OrderingReorderSetup
  order_rank_keys : Array[Int]
  remincross_sources : ReMincrossPassBuildSources
}

///|
/// Graphviz parity: clustered finalize inputs derive cluster-rank replay maps
/// from root phase outputs before final group cleanup/ReMincross assembly.
/// Do not change behavior without updating fixtures/tests.
pub fn build_clustered_finalize_inputs_from_root_phase_sources(
  sources : ClusteredFinalizeInputsBuildRootPhaseSources,
) -> ClusteredFinalizeInputs {
  let cluster_rank_order =
    build_cluster_rank_order_from_root_phase(
      {
        phase_base: sources.phase_base,
        root_cluster_stage: sources.root_cluster_stage,
        order_cluster_keys: sources.order_cluster_keys,
        order_cluster_skeleton: sources.order_cluster_skeleton,
        real_nodes: sources.real_nodes,
      },
    )
  build_clustered_finalize_inputs_from_sources(
    {
      reorder_setup: sources.reorder_setup,
      order_rank_keys: sources.order_rank_keys,
      ordered: sources.root_cluster_stage.ordered,
      cluster_rank_order,
      remincross_sources: sources.remincross_sources,
    },
  )
}

///|
/// Graphviz parity: clustered finalize stage source bundle keeps root-phase
/// cleanup snapshots and ReMincross source input together for one finalize
/// stage run.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredFinalizeStageRootSources {
  phase_base : RootRankOrderPhaseBase
  root_cluster_stage : RootAndClusterRanksOutput
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  real_nodes : Map[String, Bool]
  reorder_setup : OrderingReorderSetup
  order_rank_keys : Array[Int]
  remincross_source_input : ReMincrossPassSourceInput
}

///|
/// Graphviz parity: clustered finalize stage source assembly keeps pre-root
/// snapshots, root-phase output, and ReMincross context grouped before one
/// deterministic finalize run.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredFinalizeStageBuildSources {
  phase_base : RootRankOrderPhaseBase
  root_cluster_stage : RootAndClusterRanksOutput
  root_tail_order_override : Array[String]?
  pre_root_stage : ClusteredPreRootStageOutput
  real_nodes : Map[String, Bool]
  ratio : String
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  reorder_setup : OrderingReorderSetup
  local_cluster_order : Map[String, Int]
  cluster_order : Array[String]
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_flat_constraints : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_sizes : Map[String, @node_primitives.NodeSize]
  order_sizes : Map[String, @node_primitives.NodeSize]
  rank_same_constraints : Map[String, Bool]
  root_cluster : String
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered finalize stage source bundle is assembled from
/// one root/pre-root snapshot without changing ReMincross input field mapping.
/// Do not change behavior without updating fixtures/tests.
pub fn build_clustered_finalize_stage_from_sources(
  sources : ClusteredFinalizeStageBuildSources,
) -> ClusteredFinalizeStageRootSources {
  {
    phase_base: sources.phase_base,
    root_cluster_stage: sources.root_cluster_stage,
    order_cluster_keys: sources.pre_root_stage.order_cluster_keys,
    order_cluster_skeleton: sources.pre_root_stage.order_cluster_skeleton,
    real_nodes: sources.real_nodes,
    reorder_setup: sources.reorder_setup,
    order_rank_keys: sources.pre_root_stage.reorder_context.order_rank_keys,
    remincross_source_input:
      {
        ratio: sources.ratio,
        edges: sources.edges,
        edge_tail: sources.edge_tail,
        edge_head: sources.edge_head,
        edge_reversed: sources.edge_reversed,
        edge_tail_port_x: sources.edge_tail_port_x,
        edge_head_port_x: sources.edge_head_port_x,
        edge_tail_port_order: sources.edge_tail_port_order,
        edge_head_port_order: sources.edge_head_port_order,
        ranks: sources.ranks,
        reorder_setup: sources.reorder_setup,
        creation_order: sources.pre_root_stage.reorder_context.creation_order,
        cluster_order: sources.cluster_order,
        cluster_keys: sources.cluster_keys,
        intercluster_keys: sources.intercluster_keys,
        local_cluster_order: sources.local_cluster_order,
        cluster_parents: sources.cluster_parents,
        cluster_min_rank: sources.cluster_min_rank,
        cluster_max_rank: sources.cluster_max_rank,
        cluster_flat_constraints: sources.cluster_flat_constraints,
        rank_same_groups: sources.rank_same_groups,
        rank_same_order: sources.rank_same_order,
        edge_vnodes: sources.edge_vnodes,
        vnode_ranks: sources.vnode_ranks,
        vnodes_by_rank: sources.vnodes_by_rank,
        vnode_sizes: sources.vnode_sizes,
        order_sizes: sources.order_sizes,
        rank_same_constraints: sources.rank_same_constraints,
        ordered_with_vnodes: sources.root_cluster_stage.ordered_with_vnodes,
        real_nodes: sources.real_nodes,
        root_tail_order_override: sources.root_tail_order_override,
        root_cluster: sources.root_cluster,
        nodesep_pt: sources.nodesep_pt,
        has_edge_labels: sources.has_edge_labels,
        port_order_positions: sources.port_order_positions,
        port_order_contrib: sources.port_order_contrib,
      },
  }
}

///|
/// Graphviz parity: clustered finalize stage derives root-phase cleanup maps,
/// builds ReMincross context from one source snapshot, then runs finalize
/// group cleanup + startpass=2 reorder in fixed order.
/// Do not change behavior without updating fixtures/tests.
pub fn run_clustered_finalize_stage_from_root_phase_sources(
  sources : ClusteredFinalizeStageRootSources,
  capture_call : (ReMincrossCleanupCaptureInputs) -> Unit,
  reorder_call : (ReMincrossCleanupReorderInputs) -> Map[Int, Array[String]],
) -> ReMincrossPassOutput {
  let finalize_inputs =
    build_clustered_finalize_inputs_from_root_phase_sources(
      {
        phase_base: sources.phase_base,
        root_cluster_stage: sources.root_cluster_stage,
        order_cluster_keys: sources.order_cluster_keys,
        order_cluster_skeleton: sources.order_cluster_skeleton,
        real_nodes: sources.real_nodes,
        reorder_setup: sources.reorder_setup,
        order_rank_keys: sources.order_rank_keys,
        remincross_sources:
          build_remincross_pass_sources(sources.remincross_source_input),
      },
    )
  run_clustered_finalize_order_groups(
    finalize_inputs,
    capture_call,
    reorder_call,
  )
}

///|
/// Graphviz parity: clustered ReMincross group-selection inputs capture seeded
/// fallback context and vnode-injection context for the current cleanup pass.
pub(all) struct ReMincrossGroupInputs {
  ratio : String
  cluster_order : Array[String]
  ordered_with_vnodes : Map[Int, Array[String]]
  cluster_keys : Map[String, String]
  vnode_group_inputs : ReMincrossVnodeGroupInputs
}

///|
/// Graphviz parity: clustered ReMincross rank groups can seed from current
/// vnode-inclusive order for single-cluster or ratio=fill scenarios, with
/// fallback to full rebuild when seeded output is empty.
pub fn build_remincross_groups(
  inputs : ReMincrossGroupInputs,
) -> Map[Int, Array[String]] {
  // Graphviz parity: ratio=fill enables seeded vnode-inclusive reorder input
  // in clustered ReMincross (Graphviz fill-specific branch behavior).
  let prefer_seeded_from_ordered_with_vnodes = inputs.ratio == "fill"
  // Graphviz parity: seeded-group path is considered only when vnode ordering
  // is enabled and graph shape matches single-cluster or ratio=fill scenarios.
  let should_try_seeded =
    inputs.vnode_group_inputs.order_with_vnodes &&
    (inputs.cluster_order.length() == 1 ||
    prefer_seeded_from_ordered_with_vnodes)
  if should_try_seeded {
    let seeded =
      build_seeded_remincross(
        inputs.vnode_group_inputs.final_groups,
        inputs.ordered_with_vnodes,
        inputs.cluster_keys,
      )
    if seeded.length() > 0 {
      return seeded
    }
  }
  // Graphviz parity: clustered ReMincross rebuilt groups come from base real
  // groups plus optional vnode injection with trailing-vnode adjustments.
  build_remincross_vnode_groups(inputs.vnode_group_inputs)
}

///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
pub fn run_clustered_finalize_order_groups(
  inputs : ClusteredFinalizeInputs,
  capture_call : (ReMincrossCleanupCaptureInputs) -> Unit,
  reorder_call : (ReMincrossCleanupReorderInputs) -> Map[Int, Array[String]],
) -> ReMincrossPassOutput {
  let cleaned_groups =
    collect_real_only_rank_groups(
      inputs.order_rank_keys,
      inputs.ordered,
      inputs.remincross_context.real_nodes,
    )
  if !inputs.order_with_clusters {
    return {
      ordered_groups: cleaned_groups,
      ordered_with_vnodes: inputs.remincross_context.ordered_with_vnodes,
    }
  }
  let final_groups =
    build_clustered_finalize_groups(
      cleaned_groups,
      inputs.cluster_rank_order,
      inputs.remincross_context.cluster_keys,
      inputs.remincross_context.intercluster_keys,
      inputs.remincross_context.local_cluster_order,
    )
  run_remincross_pass(
    inputs.remincross_context,
    final_groups,
    capture_call,
    reorder_call,
  )
}

///|
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
pub fn run_remincross_pass(
  context : ReMincrossPassBuildContext,
  base_groups : Map[Int, Array[String]],
  capture_call : (ReMincrossCleanupCaptureInputs) -> Unit,
  reorder_call : (ReMincrossCleanupReorderInputs) -> Map[Int, Array[String]],
) -> ReMincrossPassOutput {
  let rem_groups =
    build_remincross_groups(
      {
        ratio: context.ratio,
        cluster_order: context.cluster_order,
        ordered_with_vnodes: context.ordered_with_vnodes,
        cluster_keys: context.cluster_keys,
        vnode_group_inputs: {
          final_groups: base_groups,
          order_with_vnodes: context.order_with_vnodes,
          edges: context.edges,
          edge_tail: context.edge_tail,
          edge_head: context.edge_head,
          edge_reversed: context.edge_reversed,
          ranks: context.ranks,
          intercluster_keys: context.intercluster_keys,
          cluster_parents: context.cluster_parents,
          cluster_min_rank: context.cluster_min_rank,
          cluster_max_rank: context.cluster_max_rank,
          edge_vnodes: context.edge_vnodes,
          vnode_ranks: context.vnode_ranks,
          vnodes_by_rank: context.vnodes_by_rank,
        },
      },
    )
  let rem_rank_keys = collect_rank_keys(rem_groups)
  if rem_rank_keys.length() <= 1 {
    {
      ordered_groups: base_groups,
      ordered_with_vnodes: context.ordered_with_vnodes,
    }
  } else {
    // Graphviz parity: clustered ReMincross multi-rank branch materializes
    // remapped edges and executes clustered cleanup reorder in startpass=2.
    let materialized_inputs =
      build_remincross_materialized_inputs(
        {
          rem_rank_keys,
          rem_groups,
          creation_order: context.creation_order,
          edges: context.edges,
          edge_tail: context.edge_tail,
          edge_head: context.edge_head,
          edge_tail_port_x: context.edge_tail_port_x,
          edge_head_port_x: context.edge_head_port_x,
          edge_tail_port_order: context.edge_tail_port_order,
          edge_head_port_order: context.edge_head_port_order,
          ranks: context.ranks,
          edge_vnodes: context.edge_vnodes,
          order_with_vnodes: context.order_with_vnodes,
          intercluster_keys: context.intercluster_keys,
          cluster_order: context.cluster_order,
          order_with_clusters: true,
          edges_by_tail: context.edges_by_tail,
          root_tail_order_override: context.root_tail_order_override,
          root_cluster: context.root_cluster,
          cluster_parents: context.cluster_parents,
          order_sizes: context.order_sizes,
          vnode_sizes: context.vnode_sizes,
          cluster_flat_constraints: context.cluster_flat_constraints,
          rank_same_constraints: context.rank_same_constraints,
        },
      )
    let rem_ordered =
      run_remincross_cleanup(
        {
          rem_rank_keys,
          rem_groups,
          materialized_inputs,
          rank_same_groups: context.rank_same_groups,
          rank_same_order: context.rank_same_order,
          nodesep_pt: context.nodesep_pt,
          has_edge_labels: context.has_edge_labels,
          port_order_positions: context.port_order_positions,
          port_order_contrib: context.port_order_contrib,
          graphviz_flip: context.graphviz_flip,
        },
        capture_call,
        reorder_call,
      )
    let rem_cleaned =
      collect_real_only_rank_groups(
        rem_rank_keys,
        rem_ordered,
        context.real_nodes,
      )
    {
      ordered_groups: rem_cleaned,
      ordered_with_vnodes: rem_ordered,
    }
  }
}

///|
/// Graphviz parity: ReMincross cleanup capture payload records the same
/// rematerialized edge snapshot passed into clustered startpass=2 reorder.
pub(all) struct ReMincrossCleanupCaptureInputs {
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  rem_cluster_keys : Map[String, String]
}

///|
/// Graphviz parity: ReMincross cleanup reorder payload keeps edge-index maps
/// and clustered reorder inputs built from one rematerialized snapshot.
pub(all) struct ReMincrossCleanupReorderInputs {
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  rem_parents : Map[String, Array[String]]
  rem_children : Map[String, Array[String]]
  rem_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  rem_edge_order : Map[String, Int]
  rem_node_order : Map[String, Int]
  rem_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  rem_flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: clustered ReMincross cleanup inputs keep rematerialized
/// arrays, rank=same maps, and layout knobs unchanged before startpass=2 call.
pub(all) struct ReMincrossCleanupInputs {
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  materialized_inputs : ReMincrossCleanupMaterializedInputs
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: ReMincross clustered cleanup reorder captures rematerialized
/// inputs, builds edge index maps, then executes startpass=2 reorder.
/// Do not change behavior without updating fixtures/tests.
pub fn run_remincross_cleanup(
  inputs : ReMincrossCleanupInputs,
  capture_call : (ReMincrossCleanupCaptureInputs) -> Unit,
  reorder_call : (ReMincrossCleanupReorderInputs) -> Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let materialized_inputs = inputs.materialized_inputs
  let rem_edge_indices =
    build_edge_indices_and_order(
      materialized_inputs.rem_nodes,
      materialized_inputs.rem_edge_tail_out,
      materialized_inputs.rem_edge_head_out,
      materialized_inputs.rem_ranks,
      materialized_inputs.rem_edges_out,
    )
  // Graphviz parity: ReMincross clustered reorder executes startpass=2 on the
  // same rematerialized edge snapshot captured for fixture/debug parity.
  capture_call(
    {
      rem_rank_keys: inputs.rem_rank_keys,
      rem_groups: inputs.rem_groups,
      rem_edges_out: materialized_inputs.rem_edges_out,
      rem_edge_tail_out: materialized_inputs.rem_edge_tail_out,
      rem_edge_head_out: materialized_inputs.rem_edge_head_out,
      rem_edge_tail_port_x: materialized_inputs.rem_edge_tail_port_x,
      rem_edge_head_port_x: materialized_inputs.rem_edge_head_port_x,
      rem_edge_tail_port_order: materialized_inputs.rem_edge_tail_port_order,
      rem_edge_head_port_order: materialized_inputs.rem_edge_head_port_order,
      rem_cluster_keys: materialized_inputs.rem_cluster_keys,
    },
  )
  reorder_call(
    {
      rem_rank_keys: inputs.rem_rank_keys,
      rem_groups: inputs.rem_groups,
      rem_edges_out: materialized_inputs.rem_edges_out,
      rem_edge_tail_out: materialized_inputs.rem_edge_tail_out,
      rem_edge_head_out: materialized_inputs.rem_edge_head_out,
      rem_edge_tail_port_x: materialized_inputs.rem_edge_tail_port_x,
      rem_edge_head_port_x: materialized_inputs.rem_edge_head_port_x,
      rem_edge_tail_port_order: materialized_inputs.rem_edge_tail_port_order,
      rem_edge_head_port_order: materialized_inputs.rem_edge_head_port_order,
      rem_parents: rem_edge_indices.parents,
      rem_children: rem_edge_indices.children,
      rem_cluster_keys: materialized_inputs.rem_cluster_keys,
      rank_same_groups: inputs.rank_same_groups,
      rank_same_order: inputs.rank_same_order,
      rem_edge_order: rem_edge_indices.edge_order,
      rem_node_order: materialized_inputs.rem_node_order,
      rem_sizes: materialized_inputs.rem_sizes,
      nodesep_pt: inputs.nodesep_pt,
      has_edge_labels: inputs.has_edge_labels,
      port_order_positions: inputs.port_order_positions,
      port_order_contrib: inputs.port_order_contrib,
      rem_flat_constraints: materialized_inputs.rem_flat_constraints,
      graphviz_flip: inputs.graphviz_flip,
    },
  )
}

///|
/// Graphviz parity: seeded vnode-inclusive rank rebuilding anchors synthetic
/// names between nearest real-node predecessors/successors from base order.
priv struct NeighborRealIndices {
  prev_real : Array[Int?]
  next_real_by_pos : Array[Int?]
}

///|
/// Graphviz parity: seeded vnode-inclusive rank rebuilding anchors synthetic
/// names between nearest real-node predecessors/successors from base order.
fn build_neighbor_real_indices(
  filtered : Array[String],
  real_order : Map[String, Int],
) -> NeighborRealIndices {
  let prev_real : Array[Int?] = []
  let mut last_real : Int? = None
  for name in filtered {
    match real_order.get(name) {
      Some(idx) => last_real = Some(idx)
      None => ()
    }
    prev_real.push(last_real)
  }
  let next_rev : Array[Int?] = []
  let mut next_real : Int? = None
  let mut rev_idx = filtered.length()
  while rev_idx > 0 {
    rev_idx = rev_idx - 1
    let name = filtered[rev_idx]
    match real_order.get(name) {
      Some(idx) => next_real = Some(idx)
      None => ()
    }
    next_rev.push(next_real)
  }
  let next_real_by_pos : Array[Int?] = []
  let mut idx = next_rev.length()
  while idx > 0 {
    idx = idx - 1
    next_real_by_pos.push(next_rev[idx])
  }
  { prev_real, next_real_by_pos }
}

///|
/// Graphviz parity: when a mixed root/cluster rank begins with one synthetic
/// vnode, keep root real first, cluster reals next, and trail that vnode.
fn try_build_special_seed_order(
  filtered : Array[String],
  base_real : Array[String],
  real_order : Map[String, Int],
  cluster_keys : Map[String, String],
) -> Array[String]? {
  let mut root_real_count = 0
  let mut cluster_real_count = 0
  let mut root_real_name = ""
  let cluster_real_names : Array[String] = []
  for name in base_real {
    if cluster_key_or_empty(cluster_keys, name) == "" {
      root_real_count = root_real_count + 1
      root_real_name = name
    } else {
      cluster_real_count = cluster_real_count + 1
      cluster_real_names.push(name)
    }
  }
  let mut synthetic_count = 0
  let mut synthetic_name = ""
  for name in filtered {
    if real_order.get(name) is None {
      synthetic_count = synthetic_count + 1
      synthetic_name = name
    }
  }
  if filtered.length() == 4 &&
    @edge_identity.is_edge_vnode_name(filtered[0]) &&
    root_real_count == 1 &&
    cluster_real_count >= 2 &&
    synthetic_count == 1 &&
    synthetic_name != "" &&
    root_real_name != "" {
    let special_order : Array[String] = [root_real_name]
    for name in cluster_real_names {
      special_order.push(name)
    }
    special_order.push(synthetic_name)
    return Some(special_order)
  }
  None
}

///|
/// Graphviz parity: seeded rank merge key places real nodes on even slots,
/// synthetic nodes after nearest previous/next real anchors.
fn seeded_rank_merge_key(
  index : Int,
  name : String,
  real_order : Map[String, Int],
  prev_real : Array[Int?],
  next_real_by_pos : Array[Int?],
) -> Int {
  match real_order.get(name) {
    Some(real_idx) => real_idx * 2
    None =>
      match prev_real[index] {
        Some(prev_idx) => prev_idx * 2 + 1
        None =>
          match next_real_by_pos[index] {
            Some(next_idx) => next_idx * 2 - 1
            None => index * 2
          }
      }
  }
}

///|
/// Graphviz parity: seeded rank rebuild first applies special mixed handoff
/// ordering, then falls back to key-based synthetic/real merge replay.
fn build_seeded_rank_order(
  filtered : Array[String],
  base_real : Array[String],
  cluster_keys : Map[String, String],
) -> Array[String] {
  let real_order : Map[String, Int] = Map::new()
  for i in 0..<base_real.length() {
    real_order[base_real[i]] = i
  }
  // Graphviz parity: special mixed rank handoff keeps root/cluster/vnode
  // sequence aligned with Graphviz before generic key-based placement.
  match try_build_special_seed_order(
    filtered,
    base_real,
    real_order,
    cluster_keys,
  ) {
    Some(special_order) => special_order
    None => {
      let neighbor_indices =
        build_neighbor_real_indices(filtered, real_order)
      let keyed : Array[(String, Int, Int)] = []
      for i in 0..<filtered.length() {
        let name = filtered[i]
        let key =
          seeded_rank_merge_key(
            i,
            name,
            real_order,
            neighbor_indices.prev_real,
            neighbor_indices.next_real_by_pos,
          )
        keyed.push((name, key, i))
      }
      // Graphviz parity: seeded rank replay uses keyed sort output order
      // directly as the vnode-inclusive rank sequence.
      keyed.sort_by((a, b) => {
        // Graphviz parity: keyed sort keeps merge-key primary order and
        // original index tie-break so equal keys preserve input order.
        let (_, key_a, idx_a) = a
        let (_, key_b, idx_b) = b
        if key_a < key_b {
          -1
        } else if key_a > key_b {
          1
        } else if idx_a < idx_b {
          -1
        } else if idx_a > idx_b {
          1
        } else {
          0
        }
      })
      let ordered_rank : Array[String] = []
      for entry in keyed {
        let (name, _, _) = entry
        ordered_rank.push(name)
      }
      ordered_rank
    }
  }
}

///|
/// Graphviz parity: ReMincross can seed from current vnode-inclusive rank
/// order while keeping real-node relative order from cleaned base groups.
/// Do not change behavior without updating fixtures/tests.
pub fn build_seeded_remincross(
  base_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let rem_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in ordered_with_vnodes {
    // Graphviz parity: seeded rank replay drops cluster skeleton placeholders
    // and keeps remaining name order unchanged.
    let filtered : Array[String] = []
    for name in names {
      if !@cluster_identity.is_cluster_skeleton_name(name) {
        filtered.push(name)
      }
    }
    if filtered.length() == 0 {
      continue
    }
    let base_real = base_groups.get(rank).unwrap_or_default()
    if base_real.length() == 0 {
      rem_groups[rank] = filtered
      continue
    }
    let ordered_rank =
      build_seeded_rank_order(
        filtered,
        base_real,
        cluster_keys,
      )
    rem_groups[rank] = ordered_rank
  }
  rem_groups
}

///|
/// Ordering domain: clustered ReMincross vnode-group rebuild helpers used by
/// Stage C cleanup dispatch when seeded groups are not reused.

///|
/// Graphviz parity: cluster containment walk for intercluster vnode tagging.
fn cluster_contains(
  ancestor : String,
  target : String,
  cluster_parents : Map[String, String?],
) -> Bool {
  if ancestor == "" {
    return true
  }
  if target == "" {
    return false
  }
  let mut current : String? = Some(target)
  let seen : Map[String, Bool] = Map::new()
  while current is Some(name) {
    if seen.get(name) is Some(_) {
      return false
    }
    seen[name] = true
    if name == ancestor {
      return true
    }
    let parent = match cluster_parents.get(name) {
      Some(value) => value
      None => None
    }
    current = parent
  }
  false
}

///|
/// Graphviz parity: edge is internal to a cluster when tail/head clusters are
/// equal or ancestor/descendant related.
fn edge_internal_to_cluster(
  tail_cluster : String,
  head_cluster : String,
  cluster_parents : Map[String, String?],
) -> Bool {
  if tail_cluster == head_cluster {
    return true
  }
  if cluster_contains(tail_cluster, head_cluster, cluster_parents) {
    return true
  }
  if cluster_contains(head_cluster, tail_cluster, cluster_parents) {
    return true
  }
  false
}

///|
/// Graphviz parity: seed vnode order from GD_nlist order within each rank.
/// Do not change behavior without updating fixtures/tests.
pub fn build_vnode_keys_from_nlist(
  ordered_groups : Map[Int, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  order_index : Map[String, Int],
  nlist_order_index : Map[String, Int],
  _intercluster_vnodes : Map[String, Bool],
  _has_clusters : Bool,
) -> Map[String, Double] {
  let keys : Map[String, Double] = Map::new()
  let rank_set : Map[Int, Bool] = Map::new()
  for rank, _ in ordered_groups {
    rank_set[rank] = true
  }
  for rank, _ in vnodes_by_rank {
    rank_set[rank] = true
  }
  let ranks : Array[Int] = []
  for rank, _ in rank_set {
    ranks.push(rank)
  }
  ranks.sort()
  let get_order = (name : String) => {
    match order_index.get(name) {
      Some(value) => value
      None => -1
    }
  }
  let get_nlist = (name : String) => {
    match nlist_order_index.get(name) {
      Some(value) => value
      None => 1_000_000_000
    }
  }
  let is_intercluster = (name : String) => {
    _has_clusters && _intercluster_vnodes.get(name) == Some(true)
  }
  // Graphviz parity: ignore cluster skeleton nodes when seeding vnode order keys.
  let is_skeleton = (name : String) => {
    @cluster_identity.is_cluster_skeleton_name(name)
  }
  let assign_interval = (
    vnodes : Array[String],
    left_key : Double,
    right_key : Double,
  ) => {
    let count = vnodes.length()
    if count == 0 {
      return ()
    }
    let span = right_key - left_key
    let denom = (count + 1).to_double()
    for i in 0..<count {
      let t = (i + 1).to_double() / denom
      keys[vnodes[i]] = left_key + span * t
    }
  }
  for rank in ranks {
    let real_names = match ordered_groups.get(rank) {
      Some(list) => list.filter(name => !is_skeleton(name))
      None => []
    }
    let vnodes = match vnodes_by_rank.get(rank) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let real_set : Map[String, Bool] = Map::new()
    for name in real_names {
      real_set[name] = true
    }
    let combined : Array[String] = []
    for name in real_names {
      combined.push(name)
    }
    for name in vnodes {
      combined.push(name)
    }
    combined.sort_by((a, b) => {
      let a_inter = is_intercluster(a)
      let b_inter = is_intercluster(b)
      if a_inter != b_inter {
        if a_inter {
          1
        } else {
          -1
        }
      } else {
        let a_idx = get_nlist(a)
        let b_idx = get_nlist(b)
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      }
    })
    if real_names.length() == 0 {
      let mut idx = 0
      for name in combined {
        if real_set.get(name) is None {
          keys[name] = idx.to_double()
          idx = idx + 1
        }
      }
      continue
    }
    let interval : Array[String] = []
    let mut prev_order = -1
    let mut first_real_order : Int? = None
    for name in combined {
      if real_set.get(name) == Some(true) {
        let ord = get_order(name)
        if ord >= 0 && first_real_order is None {
          first_real_order = Some(ord)
        }
        let left_key =
          if prev_order >= 0 {
          prev_order.to_double()
        } else {
          let base = match first_real_order {
            Some(value) => value
            None => ord
          }
          (base - 1).to_double()
        }
        let right_key = ord.to_double()
        assign_interval(interval, left_key, right_key)
        interval.clear()
        prev_order = ord
      } else {
        interval.push(name)
      }
    }
    if interval.length() > 0 {
      let left_key = prev_order.to_double()
      let right_key = (prev_order + 1).to_double()
      assign_interval(interval, left_key, right_key)
    }
  }
  keys
}

///|
/// Graphviz parity: vnode order keys interpolate tail/head order values while
/// preserving cluster-internal edge treatment and trailing-root vnode placement.
/// Do not change behavior without updating fixtures/tests.
pub fn build_vnode_order_keys(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  let _ = edge_reversed
  let keys : Map[String, Double] = Map::new()
  let max_order_by_rank : Map[Int, Int] = Map::new()
  for name, order in order_index {
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    match max_order_by_rank.get(rank) {
      Some(current) =>
        if order > current {
          max_order_by_rank[rank] = order
        }
      None => max_order_by_rank[rank] = order
    }
  }
  let mut edge_idx = 0
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let vnodes = edge_vnodes.get(@edge_identity.edge_vnode_key(edge)).unwrap_or_default()
    if vnodes.length() == 0 {
      continue
    }
    let (tail, head) =
      edge_endpoints_at(
        edge,
        current_idx,
        edge_tail,
        edge_head,
      )
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_cluster = cluster_keys.get(tail).unwrap_or_default()
    let head_cluster = cluster_keys.get(head).unwrap_or_default()
    let tail_order = order_index.get(tail).unwrap_or_default()
    let head_order = order_index.get(head).unwrap_or_default()
    let (low_rank, high_rank, low_order, high_order) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_order, head_order)
    } else {
      (head_rank, tail_rank, head_order, tail_order)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    let low_order_f = Double::from_int(low_order)
    let high_order_f = Double::from_int(high_order)
    let same_order = low_order == high_order
    let internal =
      tail_cluster != "" && head_cluster != "" &&
      edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
    let trail_external =
      !internal &&
      ((tail_cluster == "" && head_cluster != "") ||
        (tail_cluster != "" && head_cluster == ""))
    let edge_offset = Double::from_int(current_idx) * 0.001
    let mut vnode_seq = 0
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let mut base_key =
        if same_order {
          // Graphviz parity: when tail/head orders match, vnodes precede
          // nodes with that order in the intermediate ranks.
          low_order_f - (1.0 - t)
        } else {
          low_order_f + (high_order_f - low_order_f) * t
        }
      if trail_external {
        // Graphviz parity: edges crossing cluster boundaries from/to root
        // place vnodes after real nodes on the rank.
        let max_order = max_order_by_rank.get(vnode_rank).unwrap_or(-1)
        let min_key = Double::from_int(max_order + 1)
        let vnode_offset = Double::from_int(vnode_seq) * 0.000001
        if base_key < min_key {
          base_key = min_key + edge_offset + vnode_offset
        } else {
          base_key = base_key + edge_offset + vnode_offset
        }
      }
      keys[vnode] = base_key
      vnode_seq = vnode_seq + 1
    }
  }
  keys
}

///|
/// Graphviz parity: intercluster trailing-vnode checks use inclusive overlap
/// over each cluster's min/max rank bounds with min-rank fallback.
fn cluster_rank_ranges_overlap(
  tail_cluster : String,
  head_cluster : String,
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Bool {
  let tail_min = cluster_min_rank.get(tail_cluster).unwrap_or_default()
  let tail_max = cluster_max_rank.get(tail_cluster).unwrap_or(tail_min)
  let head_min = cluster_min_rank.get(head_cluster).unwrap_or_default()
  let head_max = cluster_max_rank.get(head_cluster).unwrap_or(head_min)
  tail_min <= head_max && head_min <= tail_max
}

///|
/// Graphviz parity: trailing-vnode candidate set comes from intercluster edge
/// vnode chains on edges that satisfy the rank-range overlap gate.
fn collect_remincross_trailing(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_vnodes : Map[String, Array[String]],
  remincross_cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Map[String, Bool] {
  let intercluster_vnodes : Map[String, Bool] = Map::new()
  for edge_idx, edge in edges {
    let (tail, head) =
      edge_endpoints_at(
        edge,
        edge_idx,
        edge_tail,
        edge_head,
      )
    let tail_cluster = remincross_cluster_keys.get(tail).unwrap_or_default()
    let head_cluster = remincross_cluster_keys.get(head).unwrap_or_default()
    // Graphviz parity: trailing-vnode tagging applies only to non-internal,
    // non-root, cross-cluster edges whose cluster rank ranges do not overlap.
    let internal =
      tail_cluster != "" && head_cluster != "" &&
      edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
    if internal ||
      tail_cluster == head_cluster ||
      tail_cluster == "" ||
      head_cluster == "" {
      continue
    }
    if cluster_rank_ranges_overlap(
      tail_cluster,
      head_cluster,
      cluster_min_rank,
      cluster_max_rank,
    ) {
      continue
    }
    let vnodes =
      edge_vnodes.get(@edge_identity.edge_vnode_key(edge)).unwrap_or_default()
    for vnode in vnodes {
      intercluster_vnodes[vnode] = true
    }
  }
  intercluster_vnodes
}

///|
/// Graphviz parity: trailing intercluster vnodes are floored behind real-node
/// positions on their rank using stable sequence offsets.
fn apply_remincross_floor(
  keys : Map[String, Double],
  intercluster_vnodes : Map[String, Bool],
  rem_base_order_index : Map[String, Int],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> Unit {
  if intercluster_vnodes.length() == 0 {
    return ()
  }
  // Graphviz parity: trailing-vnode floor uses maximum real-node order per
  // rank from the current ReMincross base order index.
  let max_order_by_rank : Map[Int, Int] = Map::new()
  for name, order in rem_base_order_index {
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    match max_order_by_rank.get(rank) {
      Some(current) =>
        if order > current {
          max_order_by_rank[rank] = order
        }
      None => max_order_by_rank[rank] = order
    }
  }
  let mut seq = 0
  for vnode, _ in intercluster_vnodes {
    let rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let max_order = max_order_by_rank.get(rank).unwrap_or(-1)
    let base = Double::from_int(max_order + 1)
    let offset = Double::from_int(seq) * 0.000001
    let min_key = base + offset
    match keys.get(vnode) {
      Some(current) =>
        if current < min_key {
          keys[vnode] = min_key
        }
      None => keys[vnode] = min_key
    }
    seq = seq + 1
  }
}

///|
/// Graphviz parity: clustered ReMincross vnode-group rebuild inputs keep the
/// base groups and cluster/vnode context unchanged before vnode merge replay.
pub(all) struct ReMincrossVnodeGroupInputs {
  final_groups : Map[Int, Array[String]]
  order_with_vnodes : Bool
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  ranks : Map[String, Int]
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
}

///|
/// Graphviz parity: ReMincross vnode order keys come from base vnode-order
/// scoring plus trailing-vnode floor adjustments for selected intercluster
/// vnode chains.
fn build_remincross_vnode_keys(
  inputs : ReMincrossVnodeGroupInputs,
  rem_base_order_index : Map[String, Int],
) -> Map[String, Double] {
  let remincross_cluster_keys : Map[String, String] = Map::new()
  for name, key in inputs.intercluster_keys {
    remincross_cluster_keys[name] = key
  }
  let intercluster_vnodes =
    collect_remincross_trailing(
      inputs.edges,
      inputs.edge_tail,
      inputs.edge_head,
      inputs.edge_vnodes,
      remincross_cluster_keys,
      inputs.cluster_parents,
      inputs.cluster_min_rank,
      inputs.cluster_max_rank,
    )
  let keys = build_vnode_order_keys(
    inputs.edges,
    inputs.edge_tail,
    inputs.edge_head,
    inputs.edge_reversed,
    inputs.ranks,
    rem_base_order_index,
    remincross_cluster_keys,
    inputs.cluster_parents,
    inputs.edge_vnodes,
    inputs.vnode_ranks,
  )
  apply_remincross_floor(
    keys,
    intercluster_vnodes,
    rem_base_order_index,
    inputs.ranks,
    inputs.vnode_ranks,
  )
  keys
}

///|
/// Graphviz parity: ReMincross rank groups start from real-node groups and
/// optionally inject edge-vnodes using vnode order keys from cluster-aware
/// trailing-vnode adjustments.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_vnode_groups(
  inputs : ReMincrossVnodeGroupInputs,
) -> Map[Int, Array[String]] {
  let rem_base_groups = clone_rank_groups(inputs.final_groups)
  let rem_base_order_index = build_order_index(rem_base_groups)
  let rem_vnode_order_keys =
    if !inputs.order_with_vnodes {
      Map::new()
    } else {
      build_remincross_vnode_keys(
        inputs,
        rem_base_order_index,
      )
    }
  if inputs.order_with_vnodes {
    build_x_groups_with_vnodes(
      rem_base_groups,
      rem_base_order_index,
      inputs.vnodes_by_rank,
      rem_vnode_order_keys,
    )
  } else {
    rem_base_groups
  }
}
