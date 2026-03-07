///|
type LayoutPrep = @shared.LayoutPrep
type RankDir = @rankdir.RankDir
type NodeSize = @node_primitives.NodeSize
type RankData = @rank_assignment.RankData
type RankHeights = @rank_assignment.RankHeights
type ClusterMetadata = @ordering.DotClusterMetadata
type OrderingResult = @ordering.OrderingResult
type PositionResult = @positioning.PositionResult
type ConstraintEdge = @x_constraints.ConstraintEdge

///|
/// Graphviz parity: position stage payload keeps stage B/C outputs grouped so
/// Stage D wiring remains explicit and stable.
pub(all) struct PositionStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
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
/// Graphviz parity: x-position stage must use identical xpos input assembly,
/// and solver invocation as Graphviz-aligned pipeline order.
/// Do not change behavior without updating fixtures/tests.
fn compute_layout_x_positions(
  pipeline : PositionPipelineContext,
  x_data : XWithFlatLabelData,
) -> Map[String, Double] {
  let solve_input =
    @x_constraints.build_x_position_solve_input(
      {
        use_vnodes_for_xpos: x_data.use_vnodes_for_xpos,
        x_base_sizes: x_data.x_base_sizes,
        x_groups: x_data.x_groups,
        vnode_sizes: pipeline.ordering.vnode_info.vnode_sizes,
        vnode_creation_order: pipeline.ordering.vnode_creation_order,
        vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
        edge_vnodes: pipeline.ordering.vnode_info.edge_vnodes,
        graph: pipeline.graph,
        nodes: pipeline.prep.nodes,
        edges: pipeline.prep.edges,
        edge_tail: pipeline.rank_data.edge_tail,
        edge_head: pipeline.rank_data.edge_head,
        edge_out_order: pipeline.rank_data.edge_out_order,
        nlist_order: pipeline.ordering.nlist_order,
        gdnlist_order: pipeline.ordering.gdnlist_order,
        cluster_keys: x_data.x_cluster_keys,
        nodesep_pt: pipeline.rank_heights.nodesep_pt,
        has_edge_labels: pipeline.prep.has_edge_labels,
        output_sizes: pipeline.prep.output_sizes,
        flat_label_edges: x_data.flat_label_edges,
      },
    )
  compute_x_positions_for_stage(solve_input, pipeline.prep.has_port_edges)
}

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
  let build_x_base_sizes : () -> Map[String, NodeSize] =
    () =>
      @port_bridge.apply_self_edge_right_space(
        pipeline.prep.nodes,
        pipeline.prep.edges,
        pipeline.prep.sizes,
        pipeline.prep.rankdir,
        pipeline.prep.record_orientation,
      )
  let build_x_port_samples : (Map[String, NodeSize]) -> @positioning.XSeedPortSamples =
    (x_order_sizes : Map[String, NodeSize]) => {
      let build_port_sample_bundle =
        (edges, edge_tail, edge_head) =>
          @port_bridge.build_edge_port_sample_bundle(
            pipeline.prep.nodes,
            edges,
            edge_tail,
            edge_head,
            x_order_sizes,
          )
      let x_port_samples =
        build_port_sample_bundle(
          pipeline.prep.edges,
          pipeline.rank_data.edge_tail,
          pipeline.rank_data.edge_head,
        )
      let order_edge_port_samples =
        build_port_sample_bundle(
          pipeline.ordering.order_edges,
          pipeline.ordering.order_edge_tail,
          pipeline.ordering.order_edge_head,
        )
      {
        x_edge_tail_port_x: x_port_samples.tail_port_x,
        x_edge_head_port_x: x_port_samples.head_port_x,
        x_edge_tail_port_order: x_port_samples.tail_port_order,
        x_edge_head_port_order: x_port_samples.head_port_order,
        order_edge_tail_port_x: order_edge_port_samples.tail_port_x,
        order_edge_head_port_x: order_edge_port_samples.head_port_x,
        order_edge_tail_port_order: order_edge_port_samples.tail_port_order,
        order_edge_head_port_order: order_edge_port_samples.head_port_order,
      }
    }
  let x_seed =
    @positioning.build_x_seed_data(
      {
        use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
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
        vnodes_by_rank: pipeline.ordering.vnode_info.vnodes_by_rank,
        has_clusters: pipeline.cluster_meta.has_clusters,
        cluster_keys: pipeline.cluster_meta.cluster_keys,
        vnode_clusters: pipeline.ordering.vnode_info.vnode_clusters,
        vnode_sizes: pipeline.ordering.vnode_info.vnode_sizes,
      },
      build_x_base_sizes,
      build_x_port_samples,
    )
  let flat_label_augmentation =
    @x_flat_labels.build_positioning_x_flat_label_pipeline(
      {
        xpos_reorder_enabled: false,
        use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
        allow_xpos_reorder: mode_flags.allow_xpos_reorder,
        graphviz_flip: mode_flags.graphviz_flip,
        has_vnode_order: x_seed.has_vnode_order,
        ordering_set: pipeline.cluster_meta.ordering_set,
        has_clusters: pipeline.cluster_meta.has_clusters,
        x_groups: x_seed.x_groups,
        x_base_sizes: x_seed.x_base_sizes,
        x_order_sizes: x_seed.x_order_sizes,
        x_cluster_keys: x_seed.x_cluster_keys,
        cluster_min_rank: pipeline.cluster_meta.cluster_min_rank,
        cluster_max_rank: pipeline.cluster_meta.cluster_max_rank,
        node_order: pipeline.prep.node_order,
        edges: pipeline.prep.edges,
        edge_tail: pipeline.rank_data.edge_tail,
        edge_head: pipeline.rank_data.edge_head,
        ranks: pipeline.rank_data.ranks,
        edge_vnodes: pipeline.ordering.vnode_info.edge_vnodes,
        vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
        edge_tail_port_x: x_seed.x_edge_tail_port_x,
        edge_head_port_x: x_seed.x_edge_head_port_x,
        edge_tail_port_order: x_seed.x_edge_tail_port_order,
        edge_head_port_order: x_seed.x_edge_head_port_order,
        rank_same_groups: pipeline.cluster_meta.rank_same_groups,
        rank_same_order: pipeline.cluster_meta.rank_same_order,
        nodesep_pt: pipeline.rank_heights.nodesep_pt,
        has_edge_labels: pipeline.prep.has_edge_labels,
        flat_constraints: pipeline.cluster_meta.flat_constraints,
        nodes: pipeline.prep.nodes,
        order_edges: pipeline.ordering.order_edges,
        order_edge_tail: pipeline.ordering.order_edge_tail,
        order_edge_head: pipeline.ordering.order_edge_head,
        order_edge_tail_port_x: x_seed.order_edge_tail_port_x,
        order_edge_head_port_x: x_seed.order_edge_head_port_x,
        order_edge_tail_port_order: x_seed.order_edge_tail_port_order,
        order_edge_head_port_order: x_seed.order_edge_head_port_order,
        edge_order: pipeline.ordering.edge_order,
        port_order_positions: pipeline.prep.port_order_positions,
        port_order_contrib: pipeline.prep.port_order_contrib,
        cluster_skeleton: pipeline.cluster_meta.cluster_skeleton,
        vnode_clusters: pipeline.ordering.vnode_info.vnode_clusters,
        ordered_groups: pipeline.ordering.ordered_groups,
        rankdir: pipeline.prep.rankdir,
        edge_cluster_keys: pipeline.ordering.edge_cluster_keys,
        cluster_parents: pipeline.cluster_meta.cluster_parents,
        vnode_info: pipeline.ordering.vnode_info,
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
/// Stage D constants and x-constraint helpers stay with the position stage so
/// the owner package keeps algorithm-specific thresholds and solve wiring.
const MAX_XPOS_VNODES : Int = 100000

const MAX_XPOS_REORDER_VNODES : Int = 5000

const CLUSTER_MARGIN_PT : Double = 8.0


const ROOT_COMPRESS_WEIGHT : Int = 1000

///|
fn resolve_x_simplex_root_context(
  nodes : Array[@cgraph.Node],
) -> (RankDir, Double) {
  if nodes.length() > 0 {
    let root_graph = nodes[0].graph()
    (
      @rankdir.graph_rankdir(root_graph),
      @clustering.cluster_margin_pt(root_graph),
    )
  } else {
    (RankDir::TB, CLUSTER_MARGIN_PT)
  }
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/position.c + cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_x_positions_for_stage(
  input : @x_constraints.XPositionSolveInput,
  has_port_edges : Bool,
) -> Map[String, Double] {
  let port_offsets =
    if has_port_edges {
      @port_bridge.port_offsets_for_nodes(input.nodes, input.output_sizes)
    } else {
      Map::new()
    }
  let (rankdir, root_margin) =
    resolve_x_simplex_root_context(input.nodes)
  @x_constraints.compute_x_positions_with_prepared_constraints(
    input,
    root_margin,
    ROOT_COMPRESS_WEIGHT,
    (segment, real_by_name) =>
      @x_constraints.segment_slack_minlen(
        segment,
        (node_name, port) =>
          @port_bridge.edge_port_offset(
            node_name,
            port,
            port_offsets,
            input.sizes,
            rankdir,
            real_by_name,
          ),
      ),
    edge => @edge_label_metrics.edge_mid_label_metrics(edge) is Some(_),
    edge =>
      if @edge_semantics.edge_dir_for(edge, edge.tail().graph().kind()) is @edge_semantics.EdgeDir::Both {
        2
      } else {
        1
      },
    @x_constraints.should_capture_xpos_snapshot(input.graph),
  )
}

///|
/// Graphviz parity: x-positioning aligned to refs/graphviz/lib/dotgen/position.c + dotgen/cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_positions(
  input : PositionStageInput,
) -> PositionResult {
  let pipeline : PositionPipelineContext = {
    graph: input.graph,
    prep: input.prep,
    rank_data: input.rank_data,
    rank_heights: input.rank_heights,
    cluster_meta: input.cluster_meta,
    ordering: input.ordering,
  }
  let x_data =
    build_x_with_flat_labels(pipeline)
  build_projection_result({
    pipeline,
    x_data,
  })
}
