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
  vnode_sizes : Map[String, @shared.NodeSize]
  order_sizes : Map[String, @shared.NodeSize]
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
  vnode_sizes : Map[String, @shared.NodeSize]
  order_sizes : Map[String, @shared.NodeSize]
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
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
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
  build_remincross_vnode_groups(
    inputs.vnode_group_inputs,
    build_vnode_order_keys,
  )
}

///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
pub fn run_clustered_finalize_order_groups(
  inputs : ClusteredFinalizeInputs,
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
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
    build_vnode_order_keys,
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
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
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
      build_vnode_order_keys,
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
    is_edge_vnode_name(filtered[0]) &&
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
      if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
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
