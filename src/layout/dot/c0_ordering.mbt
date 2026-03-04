///|
/// Stage C Phase C0 split: stage contract type
/// definitions for cluster metadata and ordering outputs.

///|
priv struct OrderingDispatchOutput {
  ordered_groups : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
priv struct ClusterMetadata {
  has_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
priv struct OrderingResult {
  ordered_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  vnode_info : @routing.EdgeVnodeInfo
  vnode_count : Int
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  edge_order : Map[String, Int]
  edge_cluster_keys : Map[String, String]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
priv struct OrderingRuntimeContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : @routing.EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: ordering pre-pass derives real-node and existing-name maps
/// directly from the graph node array before vnode creation.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingNodeNameSets {
  real_nodes : Map[String, Bool]
  existing_names : Map[String, Bool]
}

///|
/// Graphviz parity: ordering pre-pass derives real-node/existing-name sets
/// from the node array before vnode creation and class2 preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_node_name_sets(
  nodes : Array[@cgraph.Node],
) -> OrderingNodeNameSets {
  let real_nodes : Map[String, Bool] = Map::new()
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    let name = node.name()
    real_nodes[name] = true
    existing_names[name] = true
  }
  { real_nodes, existing_names }
}

///|
/// Graphviz parity: explicit-port endpoints are tracked before class2 to keep
/// port-order constraints available during ordering setup.
/// Do not change behavior without updating fixtures/tests.
fn build_port_edge_nodes_for_ordering(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Map[String, Bool] {
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = @dot_shared.port_is_explicit(edge.tail_port()) ||
      @dot_shared.port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  port_edge_nodes
}

///|
/// Graphviz parity: setup probes vnode tail constraints in setup order even
/// when the probe output is only used for parity diagnostics.
/// Do not change behavior without updating fixtures/tests.
fn probe_vnode_tail_constraints_for_ordering(
  vnode_info : @routing.EdgeVnodeInfo,
  edge_tail : Array[String],
) -> Unit {
  let _ =
    if vnode_info.vnode_ranks.length() > 0 {
      build_vnode_tail_constraints(vnode_info.vnodes_by_rank, edge_tail)
    } else {
      Map::new()
    }
}

///|
/// Stage C Phase C0 split: ordering setup context
/// and dispatch preparation helpers.

///|
/// Graphviz parity: ordering runtime prep keeps vnode tail-constraint derivation
/// in the same position as Graphviz ordering setup, even when only used for
/// parity diagnostics.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingRuntimeContext {
  let node_name_sets = build_ordering_node_name_sets(nodes)
  let real_nodes = node_name_sets.real_nodes
  let existing_names = node_name_sets.existing_names
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
    cluster_meta.cluster_parents,
  )
  let port_edge_nodes =
    build_port_edge_nodes_for_ordering(
      edges,
      edge_tail,
      edge_head,
    )
  let local_cluster_order = @ordering.build_local_cluster_order(
    nodes,
    cluster_meta.intercluster_keys,
    ranks,
    node_order,
  )
  // Graphviz parity: rank=same does not inject extra flat constraints at this stage.
  let rank_same_constraints : Map[String, Bool] = Map::new()
  let runtime_context : OrderingRuntimeContext =
    {
      real_nodes,
      edge_cluster_keys,
      vnode_info,
      port_edge_nodes,
      local_cluster_order,
      rank_same_constraints,
    }
  probe_vnode_tail_constraints_for_ordering(runtime_context.vnode_info, edge_tail)
  runtime_context
}


///|
/// Graphviz parity: ordering pipeline context keeps runtime expansion, edge-port
/// extraction, and reorder-setup snapshots together for C0 dispatch/replay.
priv struct OrderingPipelineContext {
  runtime_context : OrderingRuntimeContext
  edge_port_data : @ordering.OrderingEdgePortData
  reorder_setup : @ordering.OrderingReorderSetup
}

///|
/// Graphviz parity: ordering dispatch setup keeps edge-port extraction and
/// reorder setup sequence identical to Graphviz class2/mincross preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> @ordering.OrderingEdgePortData {
  @ordering.build_ordering_edge_port_data(
    nodes,
    edges,
    edge_tail,
    edge_head,
    order_sizes,
    (nodes, edges, edge_tail, edge_head, sizes) => {
      let samples =
        compute_edge_port_positions(nodes, edges, edge_tail, edge_head, sizes)
      (samples.tail_values, samples.head_values)
    },
    (nodes, edges, edge_tail, edge_head, sizes) => {
      let samples =
        compute_edge_port_orders(nodes, edges, edge_tail, edge_head, sizes)
      (samples.tail_values, samples.head_values)
    },
  )
}

///|
/// Graphviz parity: reorder setup keeps vnode-key derivation and class2 wiring
/// in the same order as Graphviz clustered/noncluster mincross preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_reorder_setup(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  cluster_meta : ClusterMetadata,
  rankdir : RankDir,
  runtime_context : OrderingRuntimeContext,
  edge_port_data : @ordering.OrderingEdgePortData,
) -> @ordering.OrderingReorderSetup {
  let graphviz_flip = rankdir == RankDir::RL || rankdir == RankDir::LR
  @ordering.build_ordering_reorder_setup(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    groups,
    node_order,
    runtime_context.port_edge_nodes,
    runtime_context.vnode_info.vnode_ranks.length(),
    graphviz_flip,
    cluster_meta.has_clusters,
    cluster_meta.cluster_min_rank,
    cluster_meta.cluster_max_rank,
    cluster_meta.cluster_keys,
    cluster_meta.cluster_order,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    runtime_context.vnode_info.edge_vnodes,
    edge_port_data,
    (base_order_index) =>
      build_vnode_order_keys(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        base_order_index,
        cluster_meta.cluster_keys,
        cluster_meta.cluster_parents,
        runtime_context.vnode_info.edge_vnodes,
        runtime_context.vnode_info.vnode_ranks,
      ),
    (ordering_groups_base, base_order_index, nlist_order_index) =>
      build_vnode_keys_from_nlist(
        ordering_groups_base,
        runtime_context.vnode_info.vnodes_by_rank,
        base_order_index,
        nlist_order_index,
        Map::new(),
        false,
      ),
  )
}

///|
/// Graphviz parity: ordering pipeline context assembles runtime expansion,
/// edge-port snapshots, and reorder setup in the same sequence as Graphviz.
fn build_ordering_pipeline_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingPipelineContext {
  let runtime_context =
    build_ordering_context(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      ranks,
      node_order,
      nodesep_pt,
      rankdir,
      cluster_meta,
    )
  let edge_port_data =
    build_ordering_edge_port_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  let reorder_setup =
    build_ordering_reorder_setup(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_out_order,
      ranks,
      groups,
      node_order,
      cluster_meta,
      rankdir,
      runtime_context,
      edge_port_data,
    )
  { runtime_context, edge_port_data, reorder_setup }
}

///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// stage-dispatch type definitions for phase orchestration.

///|
/// Graphviz parity: clustered pre-root stage output carries grouped sizes,
/// cluster skeleton maps, reorder context, and materialized edges unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredPreRootData {
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  reorder_context : @ordering.OrderReorderContext
  materialized : @ordering.OrderMaterializationData
}

///|
/// Graphviz parity: clustered ordering stage dispatch context keeps complete
/// clustered ordering payload ordering unchanged before stage execution.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredDispatchContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  edge_port_data : @ordering.OrderingEdgePortData
  reorder_setup : @ordering.OrderingReorderSetup
}

///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// pre-root/root/finalize stage orchestration helpers.

///|
/// Graphviz parity: clustered pre-root ordering preparation keeps order-group
/// expansion, reorder context, and materialization sequence aligned to Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root(
  dispatch_context : ClusteredDispatchContext,
) -> ClusteredPreRootData {
  let runtime_context = dispatch_context.runtime_context
  let order_seed_stage =
    @ordering.build_clustered_order_seed_stage_from_sources(
      {
        reorder_setup: dispatch_context.reorder_setup,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        cluster_order: dispatch_context.cluster_meta.cluster_order,
        cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
        cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
        vnode_clusters: runtime_context.vnode_info.vnode_clusters,
        vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
        order_sizes: dispatch_context.order_sizes,
        vnode_sizes: runtime_context.vnode_info.vnode_sizes,
        // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
        skeleton_size: vnode_size_from_widths(1.0, 1.0),
      },
    )
  let order_groups = order_seed_stage.order_groups
  let order_sizes_out = order_seed_stage.order_sizes_out
  let order_cluster_keys = order_seed_stage.order_cluster_keys
  let order_cluster_skeleton = order_seed_stage.order_cluster_skeleton
  let materialized_stage =
    @ordering.build_clustered_materialized_stage_from_sources(
      {
        reorder_setup: dispatch_context.reorder_setup,
        class2_data: dispatch_context.reorder_setup.class2_data,
        order_groups,
        node_order: dispatch_context.node_order,
        real_nodes: runtime_context.real_nodes,
        has_clusters: dispatch_context.cluster_meta.has_clusters,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        port_edge_nodes: runtime_context.port_edge_nodes,
        flat_constraints: dispatch_context.cluster_meta.flat_constraints,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        nodes: dispatch_context.nodes,
        intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
      },
    )
  let reorder_context = materialized_stage.reorder_context
  let materialized = materialized_stage.materialized
  {
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
    reorder_context,
    materialized,
  }
}

///|
/// Stage C Phase C4/C6 split: clustered root and finalize phase helpers.

///|
/// Graphviz parity: clustered root phase output carries root+cluster rank
/// groups together with optional root tail-order override for ReMincross.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredRootPhaseOutput {
  root_cluster_stage : @ordering.RootAndClusterRanksOutput
  root_tail_order_override : Array[String]?
  root_rank_order_phase_base : @ordering.RootRankOrderPhaseBase
}

///|
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_root_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> ClusteredRootPhaseOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let root_rank_order_phase_base =
    @ordering.build_root_rank_order_phase_base_from_sources(
      {
        reorder_setup,
        class2_data: reorder_setup.class2_data,
        order_rank_keys: pre_root_stage.reorder_context.order_rank_keys,
        order_cluster_keys: pre_root_stage.order_cluster_keys,
        order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
        edges: dispatch_context.edges,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        edge_vnodes: dispatch_context.runtime_context.vnode_info.edge_vnodes,
        vnodes_by_rank: dispatch_context.runtime_context.vnode_info.vnodes_by_rank,
        ranks: dispatch_context.ranks,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        order_sizes_out: pre_root_stage.order_sizes_out,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        order_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
      },
    )
  let (root_reorder_output, root_rank_order_phase_output) =
    @ordering.run_root_reorder_and_rank_order_from_base(
      root_rank_order_phase_base,
      pre_root_stage.order_groups,
    )
  let root_phase_overrides =
    @ordering.build_clustered_root_phase_overrides(
      reorder_setup.order_with_clusters,
      root_reorder_output,
      root_rank_order_phase_output,
    )
  let root_cluster_stage =
    run_root_and_cluster_ranks(
      dispatch_context,
      pre_root_stage,
      root_phase_overrides.root_groups_override_for_root_pass,
    )
  {
    root_cluster_stage,
    root_tail_order_override: root_phase_overrides.root_tail_order_override,
    root_rank_order_phase_base,
  }
}

///|
/// Graphviz parity: root mincross reordering is followed by clustered
/// build_ranks application on the unmapped order graph before final cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_ranks(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_groups_override : Map[Int, Array[String]]?,
) -> @ordering.RootAndClusterRanksOutput {
  let call_inputs =
    @ordering.build_root_and_cluster_ranks_call_inputs_from_sources(
      {
        reorder_setup: dispatch_context.reorder_setup,
        reorder_context: pre_root_stage.reorder_context,
        materialized: pre_root_stage.materialized,
        order_groups: pre_root_stage.order_groups,
        order_cluster_keys: pre_root_stage.order_cluster_keys,
        order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
        order_sizes_out: pre_root_stage.order_sizes_out,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        root_groups_override,
      },
    )
  let root_cluster_stage =
    @ordering.run_root_and_cluster_ranks_from_call_inputs_with_pass0_capture(
      call_inputs,
      capture_root_mincross_pass_snapshot,
    )
  apply_cluster_local_rank_replay_after_root(
    dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
  root_cluster_stage
}

///|
/// Graphviz parity: clustered finalize ReMincross source snapshot keeps
/// pre-root creation order and cluster/vnode metadata unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_finalize_remincross_sources(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_phase_output : ClusteredRootPhaseOutput,
) -> @ordering.ReMincrossPassBuildSources {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  {
    ratio: dispatch_context.graph.get_attr("ratio").unwrap_or_default(),
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    edge_reversed: dispatch_context.edge_reversed,
    edge_tail_port_x: dispatch_context.edge_port_data.edge_tail_port_x,
    edge_head_port_x: dispatch_context.edge_port_data.edge_head_port_x,
    edge_tail_port_order: dispatch_context.edge_port_data.edge_tail_port_order,
    edge_head_port_order: dispatch_context.edge_port_data.edge_head_port_order,
    ranks: dispatch_context.ranks,
    reorder_setup,
    creation_order: pre_root_stage.reorder_context.creation_order,
    edges_by_tail: reorder_setup.class2_data.edges_by_tail,
    cluster_order: dispatch_context.cluster_meta.cluster_order,
    cluster_keys: dispatch_context.cluster_meta.cluster_keys,
    intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
    local_cluster_order: runtime_context.local_cluster_order,
    cluster_parents: dispatch_context.cluster_meta.cluster_parents,
    cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
    cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
    cluster_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
    rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
    rank_same_order: dispatch_context.cluster_meta.rank_same_order,
    edge_vnodes: runtime_context.vnode_info.edge_vnodes,
    vnode_ranks: runtime_context.vnode_info.vnode_ranks,
    vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
    vnode_sizes: runtime_context.vnode_info.vnode_sizes,
    order_sizes: dispatch_context.order_sizes,
    rank_same_constraints: runtime_context.rank_same_constraints,
    ordered_with_vnodes: root_phase_output.root_cluster_stage.ordered_with_vnodes,
    real_nodes: runtime_context.real_nodes,
    root_tail_order_override: root_phase_output.root_tail_order_override,
    root_cluster: dispatch_context.graph.name().unwrap_or("__root__"),
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
  }
}

///|
/// Graphviz parity: clustered finalize phase first applies root cluster-rank
/// ordering, then runs final clustered ReMincross with unchanged call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_finalize_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_phase_output : ClusteredRootPhaseOutput,
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  let finalize_inputs =
    @ordering.build_clustered_finalize_inputs_from_root_phase_sources(
      {
        phase_base: root_phase_output.root_rank_order_phase_base,
        root_cluster_stage: root_phase_output.root_cluster_stage,
        order_cluster_keys: pre_root_stage.order_cluster_keys,
        order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
        real_nodes: runtime_context.real_nodes,
        reorder_setup,
        order_rank_keys: pre_root_stage.reorder_context.order_rank_keys,
        remincross_sources:
          build_clustered_finalize_remincross_sources(
            dispatch_context,
            pre_root_stage,
            root_phase_output,
          ),
      },
    )
  let finalize_output =
    @ordering.run_clustered_finalize_order_groups(
      finalize_inputs,
      build_vnode_order_keys,
      capture_remincross_snapshot,
      @ordering.run_remincross_cleanup_reorder,
    )
  {
    ordered_groups: finalize_output.ordered_groups,
    ordered_with_vnodes: finalize_output.ordered_with_vnodes,
  }
}

///|
/// Graphviz parity: clustered ordering path keeps build_ranks/mincross phase
/// boundaries unchanged while delegating each phase to base helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered(
  dispatch_context : ClusteredDispatchContext,
) -> OrderingDispatchOutput {
  let pre_root_stage = build_clustered_pre_root(dispatch_context)
  let root_phase_output = run_clustered_root_phase(dispatch_context, pre_root_stage)
  run_clustered_finalize_phase(
    dispatch_context,
    pre_root_stage,
    root_phase_output,
  )
}


///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the same
/// flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch(
  dispatch_context : ClusteredDispatchContext,
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
  if reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters {
    run_clustered(dispatch_context)
  } else {
    let noncluster_inputs =
      @ordering.build_noncluster_reorder_inputs_from_sources(
        {
          nodes: dispatch_context.nodes,
          edges: dispatch_context.edges,
          edge_head: dispatch_context.edge_head,
          edge_out_order: dispatch_context.edge_out_order,
          ranks: dispatch_context.ranks,
          rank_keys: dispatch_context.rank_keys,
          groups: dispatch_context.groups,
          node_order: dispatch_context.node_order,
          cluster_keys: dispatch_context.cluster_meta.cluster_keys,
          cluster_skeleton: dispatch_context.cluster_meta.cluster_skeleton,
          rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
          rank_same_order: dispatch_context.cluster_meta.rank_same_order,
          order_sizes: dispatch_context.order_sizes,
          nodesep_pt: dispatch_context.nodesep_pt,
          has_edge_labels: dispatch_context.has_edge_labels,
          port_order_positions: dispatch_context.port_order_positions,
          port_order_contrib: dispatch_context.port_order_contrib,
          flat_constraints: dispatch_context.cluster_meta.flat_constraints,
          reorder_setup: dispatch_context.reorder_setup,
          edge_port_data: dispatch_context.edge_port_data,
        },
      )
    let ordered_groups =
      @ordering.run_noncluster_reorder_pass(noncluster_inputs)
    {
      ordered_groups,
      ordered_with_vnodes: Map::new(),
    }
  }
}


///|
/// Graphviz parity: ordering + vnode expansion aligned to refs/graphviz/lib/dotgen/mincross.c + dotgen/flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_ordering_and_vnodes(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> OrderingResult {
  let pipeline_context =
    build_ordering_pipeline_context(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_out_order,
      ranks,
      groups,
      node_order,
      order_sizes,
      nodesep_pt,
      rankdir,
      cluster_meta,
    )
  let dispatch_context : ClusteredDispatchContext = {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    rank_keys,
    groups,
    ranks,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context: pipeline_context.runtime_context,
    edge_port_data: pipeline_context.edge_port_data,
    reorder_setup: pipeline_context.reorder_setup,
  }
  let dispatch_output =
    run_ordering_dispatch(dispatch_context)
  {
    ordered_groups: dispatch_output.ordered_groups,
    ordered_groups_with_vnodes: dispatch_output.ordered_with_vnodes,
    vnode_info: pipeline_context.runtime_context.vnode_info,
    vnode_count: pipeline_context.runtime_context.vnode_info.vnode_ranks.length(),
    order_edges: pipeline_context.edge_port_data.order_edges,
    order_edge_tail: pipeline_context.edge_port_data.order_edge_tail,
    order_edge_head: pipeline_context.edge_port_data.order_edge_head,
    edge_order: pipeline_context.edge_port_data.edge_order,
    edge_cluster_keys: pipeline_context.runtime_context.edge_cluster_keys,
    nlist_order: pipeline_context.reorder_setup.class2_data.nlist_order,
    gdnlist_order: pipeline_context.reorder_setup.gdnlist_order,
    vnode_creation_order:
      pipeline_context.reorder_setup.class2_data.vnode_creation_order,
  }
}
