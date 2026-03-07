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
type XposFlatLabelAugmentation = @x_flat_labels.XFlatLabelAugmentationOutput

///|
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, and vnode cluster-key overlay only on vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_label_augmentation(
  input : FlatLabelAugmentationBuildInput,
  deps : PositionStageDeps,
) -> XposFlatLabelAugmentation {
  let pipeline = input.pipeline
  @x_flat_labels.build_x_flat_label_augmentation(
    {
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      x_groups: input.x_groups,
      x_cluster_keys: input.x_cluster_keys,
      nodes: pipeline.prep.nodes,
      vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
      vnode_clusters: pipeline.ordering.vnode_info.vnode_clusters,
      build_flat_label_vnodes_fn:
        (existing_names, x_groups) => {
          @x_flat_labels.build_flat_label_vnodes_for_positioning(
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
            {
              edge_mid_label_metrics_for: (edge) => (deps.edge_mid_label_metrics_for)(edge),
            },
          )
        },
    },
  )
}

///|
/// Graphviz parity: x-stage reorder source bundle keeps field ordering and
/// values unchanged before clustered/non-clustered reorder dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_x_flat_label_reorder_sources(
  input : XFlatLabelBuildInput,
  deps : PositionStageDeps,
) -> @x_reorder.XposReorderPipelineSources {
  let pipeline = input.pipeline
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
    cluster_skeleton_size: @shared.vnode_size_from_widths(1.0, 1.0),
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
    cluster_skeleton_penalty: deps.cluster_skeleton_penalty,
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
    order_edge_tail_port_x: input.x_seed.order_edge_tail_port_x,
    order_edge_head_port_x: input.x_seed.order_edge_head_port_x,
    order_edge_tail_port_order: input.x_seed.order_edge_tail_port_order,
    order_edge_head_port_order: input.x_seed.order_edge_head_port_order,
    edge_order: pipeline.ordering.edge_order,
    port_order_positions: pipeline.prep.port_order_positions,
    port_order_contrib: pipeline.prep.port_order_contrib,
    cluster_skeleton: pipeline.cluster_meta.cluster_skeleton,
    transpose_max_passes: 4,
  }
}

///|
/// Graphviz parity: x-stage reorder + transpose cleanup + flat-label vnode
/// augmentation must run in the same order and with the same inputs as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_x_flat_labels(
  input : XFlatLabelBuildInput,
  deps : PositionStageDeps,
) -> XposFlatLabelAugmentation {
  let reorder_sources =
    build_x_flat_label_reorder_sources(input, deps)
  @x_flat_labels.build_x_flat_label_pipeline(
    {
      reorder_sources,
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
            deps,
          ),
    },
  )
}
