///|
/// Stage D positioning stage file: orchestrator/shared context plus x/y/output
/// wiring helpers.

///|
/// Graphviz parity: position stage payload keeps stage B/C outputs grouped so
/// Stage D wiring remains explicit and stable.
priv struct PositionStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

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

///|
/// Graphviz parity: final projection stage input keeps x-stage bundle and
/// pipeline contexts grouped for one y/x solve and output map assembly pass.
priv struct ProjectionBuildInput {
  pipeline : PositionPipelineContext
  x_data : XWithFlatLabelData
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
        flat_label_ranks: x_data.flat_label_ranks,
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
  input : PositionStageInput,
) -> PositionResult {
  let graph = input.graph
  let prep = input.prep
  let rank_data = input.rank_data
  let rank_heights = input.rank_heights
  let cluster_meta = input.cluster_meta
  let ordering = input.ordering
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

///|
/// Stage D x-position stage helpers for mode gating, reorder preparation,
/// flat-label augmentation, and xpos solve.

///|
priv struct XWithFlatLabelData {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, NodeSize]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_ranks : Map[String, Int]
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Stage D x-position mode/seed/reorder-cleanup helpers used by the stage
/// orchestrator.

///|
/// Graphviz parity: x-stage precompute in compute_positions keeps mode flags,
/// reorder/transpose, and flat-label augmentation in Graphviz-aligned order
/// and wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_x_with_flat_labels(
  pipeline : PositionPipelineContext,
) -> XWithFlatLabelData {
  let mode_flags =
    @positioning.build_position_mode_flags(
      {
        has_edge_labels: pipeline.prep.has_edge_labels,
        has_port_edges: pipeline.prep.has_port_edges,
        vnode_count: pipeline.ordering.vnode_count,
        max_xpos_vnodes: MAX_XPOS_VNODES,
        max_xpos_reorder_vnodes: MAX_XPOS_REORDER_VNODES,
        rankdir: pipeline.prep.rankdir,
      },
    )
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
    flat_label_ranks: flat_label_augmentation.flat_label_ranks,
    flat_label_edge_vnodes: flat_label_augmentation.flat_label_edge_vnodes,
  }
}

///|
/// Stage D x-stage seed data helpers.

///|
/// Graphviz parity: x-stage seed input keeps vnode mode plus ordering/rank
/// context grouped before order-index, vnode-order, and edge-port precompute.
priv struct XSeedBuildInput {
  use_vnodes_for_xpos : Bool
  pipeline : PositionPipelineContext
}

///|
/// Graphviz parity: pre-reorder x-stage setup keeps order-index build, vnode
/// order probing, edge-port metadata, and initial group/cluster maps unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_seed_data(
  input : XSeedBuildInput,
) -> @positioning.XPositionSeedData {
  let pipeline = input.pipeline
  @positioning.build_x_seed_data_from_sources(
    {
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      ordered_groups: pipeline.ordering.ordered_groups,
      ordered_groups_with_vnodes: pipeline.ordering.ordered_groups_with_vnodes,
      edges: pipeline.prep.edges,
      edge_tail: pipeline.rank_data.edge_tail,
      edge_head: pipeline.rank_data.edge_head,
      edge_reversed: pipeline.rank_data.edge_reversed,
      ranks: pipeline.rank_data.ranks,
      intercluster_keys: pipeline.cluster_meta.intercluster_keys,
      cluster_parents: pipeline.cluster_meta.cluster_parents,
      edge_vnodes: pipeline.ordering.vnode_info.edge_vnodes,
      vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
      nodes: pipeline.prep.nodes,
      sizes: pipeline.prep.sizes,
      vnode_sizes: pipeline.ordering.vnode_info.vnode_sizes,
      apply_size_adjustment_fn: (nodes, edges, sizes) =>
        apply_self_edge_right_space(
          nodes,
          edges,
          sizes,
          pipeline.prep.rankdir,
          pipeline.prep.record_orientation,
        ),
      compute_port_positions_fn: (nodes, edges, edge_tail, edge_head, sizes) => {
        let samples =
          compute_edge_port_positions(nodes, edges, edge_tail, edge_head, sizes)
        (samples.tail_values, samples.head_values)
      },
      compute_port_orders_fn: (nodes, edges, edge_tail, edge_head, sizes) => {
        let samples =
          compute_edge_port_orders(nodes, edges, edge_tail, edge_head, sizes)
        (samples.tail_values, samples.head_values)
      },
      vnodes_by_rank: pipeline.ordering.vnode_info.vnodes_by_rank,
      has_clusters: pipeline.cluster_meta.has_clusters,
      is_cluster_skeleton_name:
        (name) => @clustering.cluster_key_from_skeleton(name) is Some(_),
      cluster_keys: pipeline.cluster_meta.cluster_keys,
      vnode_clusters: pipeline.ordering.vnode_info.vnode_clusters,
    },
  )
}

///|
/// Stage D x-stage reorder pipeline wiring helpers.

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
  x_seed : @positioning.XPositionSeedData
}

///|
/// Stage D x-stage flat-label augmentation helpers.

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
type XposFlatLabelAugmentation = @positioning.XFlatLabelAugmentationOutput

///|
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, and vnode cluster-key overlay only on vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_label_augmentation(
  input : FlatLabelAugmentationBuildInput,
) -> XposFlatLabelAugmentation {
  let pipeline = input.pipeline
  @positioning.build_x_flat_label_augmentation(
    {
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      x_groups: input.x_groups,
      x_cluster_keys: input.x_cluster_keys,
      nodes: pipeline.prep.nodes,
      vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
      vnode_clusters: pipeline.ordering.vnode_info.vnode_clusters,
      build_flat_label_vnodes_fn:
        (existing_names, x_groups) => {
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
            x_groups,
          )
          let flat_label_ranks : Map[String, Int] = Map::new()
          for name, info in flat_label_vnodes.flat_label_nodes {
            flat_label_ranks[name] = info.rank
          }
          {
            x_groups: flat_label_vnodes.x_groups,
            flat_label_edges: flat_label_vnodes.flat_label_edges,
            flat_label_ranks,
            flat_label_edge_vnodes: flat_label_vnodes.flat_label_edge_vnodes,
          }
        },
    },
  )
}

///|
/// Graphviz parity: x-stage reorder + transpose cleanup + flat-label vnode
/// augmentation must run in the same order and with the same inputs as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_x_flat_labels(
  input : XFlatLabelBuildInput,
) -> XposFlatLabelAugmentation {
  let pipeline = input.pipeline
  @positioning.build_x_flat_label_pipeline(
    {
      reorder_sources:
        {
          xpos_reorder_enabled: input.xpos_reorder_enabled,
          use_vnodes_for_xpos: input.use_vnodes_for_xpos,
          allow_xpos_reorder: input.allow_xpos_reorder,
          has_vnode_order: input.x_seed.has_vnode_order,
          ordering_set: pipeline.cluster_meta.ordering_set,
          has_clusters: pipeline.cluster_meta.has_clusters,
          x_groups: input.x_seed.x_groups,
          x_order_sizes: input.x_seed.x_order_sizes,
          x_cluster_keys: input.x_seed.x_cluster_keys,
          cluster_min_rank: pipeline.cluster_meta.cluster_min_rank,
          cluster_max_rank: pipeline.cluster_meta.cluster_max_rank,
          node_order: pipeline.prep.node_order,
          cluster_skeleton_size: vnode_size_from_widths(1.0, 1.0),
          edges: pipeline.prep.edges,
          edge_tail: pipeline.rank_data.edge_tail,
          edge_head: pipeline.rank_data.edge_head,
          ranks: pipeline.rank_data.ranks,
          edge_vnodes: pipeline.ordering.vnode_info.edge_vnodes,
          vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
          edge_tail_port_x: input.x_seed.x_edge_tail_port_x,
          edge_head_port_x: input.x_seed.x_edge_head_port_x,
          edge_tail_port_order: input.x_seed.x_edge_tail_port_order,
          edge_head_port_order: input.x_seed.x_edge_head_port_order,
          cluster_skeleton_penalty: CL_CROSS,
          rank_same_groups: pipeline.cluster_meta.rank_same_groups,
          rank_same_order: pipeline.cluster_meta.rank_same_order,
          nodesep_pt: pipeline.rank_heights.nodesep_pt,
          has_edge_labels: pipeline.prep.has_edge_labels,
          flat_constraints: pipeline.cluster_meta.flat_constraints,
          graphviz_flip: input.graphviz_flip,
          nodes: pipeline.prep.nodes,
          order_edges: pipeline.ordering.order_edges,
          order_edge_tail: pipeline.ordering.order_edge_tail,
          order_edge_head: pipeline.ordering.order_edge_head,
          edge_order: pipeline.ordering.edge_order,
          port_order_positions: pipeline.prep.port_order_positions,
          port_order_contrib: pipeline.prep.port_order_contrib,
          cluster_skeleton: pipeline.cluster_meta.cluster_skeleton,
          transpose_max_passes: 4,
        },
      compute_port_samples:
        (sample_input) =>
        @positioning.build_xpos_port_samples(
          sample_input,
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
        ),
      augment_from_groups_fn:
        (x_groups) =>
          build_flat_label_augmentation(
            {
              pipeline: input.pipeline,
              use_vnodes_for_xpos: input.use_vnodes_for_xpos,
              x_base_sizes: input.x_seed.x_base_sizes,
              x_groups,
              x_cluster_keys: input.x_seed.x_cluster_keys,
            },
          ),
    },
  )
}

///|
/// Stage D y-rank placement and flip-adjustment helpers.

///|
/// Stage D x-position solver input assembly and invocation.

///|
/// Graphviz parity: x-position solve input keeps x-stage bundle plus ordering
/// and rank context grouped for one compute_x_positions invocation.
priv struct XPositionBuildInput {
  pipeline : PositionPipelineContext
  x_data : XWithFlatLabelData
}

///|
/// Graphviz parity: x-position stage must use identical xpos input assembly,
/// and solver invocation as Graphviz-aligned pipeline order.
/// Do not change behavior without updating fixtures/tests.
fn compute_layout_x_positions(
  input : XPositionBuildInput,
) -> Map[String, Double] {
  @positioning.build_x_position_pipeline(
    {
      use_vnodes_for_xpos: input.x_data.use_vnodes_for_xpos,
      x_base_sizes: input.x_data.x_base_sizes,
      x_groups: input.x_data.x_groups,
      vnode_sizes: input.pipeline.ordering.vnode_info.vnode_sizes,
      vnode_creation_order: input.pipeline.ordering.vnode_creation_order,
      vnode_ranks: input.pipeline.ordering.vnode_info.vnode_ranks,
      edge_vnodes: input.pipeline.ordering.vnode_info.edge_vnodes,
      graph: input.pipeline.graph,
      nodes: input.pipeline.prep.nodes,
      edges: input.pipeline.prep.edges,
      edge_tail: input.pipeline.rank_data.edge_tail,
      edge_head: input.pipeline.rank_data.edge_head,
      edge_out_order: input.pipeline.rank_data.edge_out_order,
      nlist_order: input.pipeline.ordering.nlist_order,
      gdnlist_order: input.pipeline.ordering.gdnlist_order,
      cluster_keys: input.x_data.x_cluster_keys,
      nodesep_pt: input.pipeline.rank_heights.nodesep_pt,
      has_edge_labels: input.pipeline.prep.has_edge_labels,
      output_sizes: input.pipeline.prep.output_sizes,
      flat_label_edges: input.x_data.flat_label_edges,
      compute_x_positions_fn:
        (solve_input) =>
          compute_x_positions(
            {
              graph: solve_input.graph,
              nodes: solve_input.nodes,
              edges: solve_input.edges,
              edge_tail: solve_input.edge_tail,
              edge_head: solve_input.edge_head,
              edge_out_order: solve_input.edge_out_order,
              nlist_order: solve_input.nlist_order,
              gdnlist_order: solve_input.gdnlist_order,
              ranks: solve_input.ranks,
              rank_keys: solve_input.rank_keys,
              groups: solve_input.groups,
              sizes: solve_input.sizes,
              output_sizes: solve_input.output_sizes,
              cluster_keys: solve_input.cluster_keys,
              nodesep_pt: solve_input.nodesep_pt,
              has_edge_labels: solve_input.has_edge_labels,
              extra_nodes: solve_input.extra_nodes,
              flat_label_edges: solve_input.flat_label_edges,
              edge_vnodes: solve_input.edge_vnodes,
            },
          ),
    },
  )
}

///|
/// Stage D y-position stage helpers for rank-height adjustments and y-coordinate
/// solve wiring.

///|
type YPositionComputationData = @positioning.YPositionPipelineOutput

///|
/// Graphviz parity: y-position pre-solve input keeps rank metadata, cluster
/// gates, and flat-label adjustments grouped before y sweep.
priv struct YPositionBuildInput {
  pipeline : PositionPipelineContext
  flat_label_ranks : Map[String, Int]
}

///|
/// Graphviz parity: y-position pre-solve in compute_positions keeps cluster bbox
/// derivation, flat-label rank-height updates, and y-sweep wiring unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_y_position_data(
  input : YPositionBuildInput,
) -> YPositionComputationData {
  @positioning.build_y_position_pipeline(
    {
      has_clusters: input.pipeline.cluster_meta.has_clusters,
      graph: input.pipeline.graph,
      rankdir: input.pipeline.prep.rankdir,
      rank_keys: input.pipeline.rank_data.rank_keys,
      groups: input.pipeline.rank_data.groups,
      ranks: input.pipeline.rank_data.ranks,
      sizes: input.pipeline.prep.sizes,
      self_edge_labels: input.pipeline.rank_data.self_edge_labels,
      rank_pht: input.pipeline.rank_heights.rank_pht,
      rank_ht1: input.pipeline.rank_heights.rank_ht1,
      rank_ht2: input.pipeline.rank_heights.rank_ht2,
      ranksep_pt: input.pipeline.rank_heights.ranksep_pt,
      flat_label_ranks: input.flat_label_ranks,
      vnode_sizes: input.pipeline.ordering.vnode_info.vnode_sizes,
      cluster_margin_pt_for: cluster_margin_pt,
      cluster_label_padding_for: cluster_label_padding_for_layout,
      node_half_height_pt_for: node_half_height_pt,
      cluster_label_width_pt_for: cluster_label_width_with_pad_for_layout,
    },
  )
}

///|
/// Stage D output map assembly helpers for intercluster alignment, vnode
/// projection, and final position maps.

type PositionOutputMaps = @positioning.PositionOutputMaps

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
/// Graphviz parity: final output map assembly keeps intercluster alignment,
/// cluster boundary capture, vnode projection, and rounding adjustment order.
/// Do not change behavior without updating fixtures/tests.
fn build_position_output_maps(
  input : PositionOutputBuildInput,
) -> PositionOutputMaps {
  @positioning.build_position_output_pipeline(
    {
      has_clusters: input.pipeline.cluster_meta.has_clusters,
      has_dotted_edges: input.pipeline.prep.has_dotted_edges,
      graph: input.pipeline.graph,
      nodes: input.pipeline.prep.nodes,
      edges: input.pipeline.prep.edges,
      ranks: input.pipeline.rank_data.ranks,
      x_positions: input.x_positions,
      y_positions: input.y_positions,
      rank_y: input.rank_y,
      cluster_keys: input.pipeline.cluster_meta.cluster_keys,
      intercluster_keys: input.pipeline.cluster_meta.intercluster_keys,
      nodesep_pt: input.pipeline.rank_heights.nodesep_pt,
      has_edge_labels: input.pipeline.prep.has_edge_labels,
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      vnode_ranks: input.pipeline.ordering.vnode_info.vnode_ranks,
      edge_vnodes: input.pipeline.ordering.vnode_info.edge_vnodes,
      cluster_rounding_enabled: cluster_rounding_enabled(),
      vnode_clusters: input.pipeline.ordering.vnode_info.vnode_clusters,
      sizes: input.pipeline.prep.sizes,
      cluster_margin_pt_for: cluster_margin_pt,
      expand_cluster_label_bbox:
        (graph, bbox) =>
          match graph_label_metrics(graph) {
            Some(metrics) =>
              expand_bbox_for_label(
                bbox,
                metrics.width_pt,
                metrics.height_pt,
                graph_label_loc(graph),
              )
            None => bbox
          },
    },
  )
}

///|
fn cluster_rounding_enabled() -> Bool {
  @dot_shared.env_flag_enabled_nonempty(
    @sys.get_env_var("DOT_ADJUST_CLUSTER_ROUNDING"),
  )
}
