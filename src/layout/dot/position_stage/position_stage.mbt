///|
type LayoutPrep = @shared.LayoutPrep
type RankDir = @rankdir.RankDir
type RecordOrientation = @shared.RecordOrientation
type NodeSize = @node_primitives.NodeSize
type RankData = @rank_assignment.RankData
type RankHeights = @rank_assignment.RankHeights
type ClusterMetadata = @ordering.DotClusterMetadata
type OrderingResult = @ordering.OrderingResult
type EdgePortSampleBundle = @ordering.EdgePortSampleBundle
type PositionResult = @positioning.PositionResult
type ConstraintEdge = @x_constraints.ConstraintEdge
type ClusterLabelPadding = @clustering.ClusterLabelPadding

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
/// Graphviz parity: Stage D dependency payload groups root-boundary geometry
/// and cluster-label bridges so the subpackage owns stage-internal
/// orchestration without importing the root dot package.
pub(all) struct PositionStageDeps {
  max_xpos_vnodes : Int
  max_xpos_reorder_vnodes : Int
  cluster_skeleton_penalty : Int
  build_x_seed_port_samples : (
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Array[String],
    Array[String],
    Map[String, NodeSize],
  ) -> EdgePortSampleBundle
  apply_self_edge_right_space : (
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Map[String, NodeSize],
    RankDir,
    RecordOrientation,
  ) -> Map[String, NodeSize]
  edge_mid_label_metrics_for : (@cgraph.Edge) -> (Double, Double)?
  compute_x_positions : (@x_constraints.XPositionSolveInput) -> Map[String, Double]
  cluster_label_padding_for : (@cgraph.Graph, RankDir) -> ClusterLabelPadding
  cluster_label_width_with_pad_for : (@cgraph.Graph) -> Double?
  expand_cluster_label_bbox : (@cgraph.Graph, @geom.Rect) -> @geom.Rect
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
  deps : PositionStageDeps,
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
  (deps.compute_x_positions)(solve_input)
}

///|
/// Graphviz parity: x-stage precompute in compute_positions keeps mode flags,
/// reorder/transpose, and flat-label augmentation in Graphviz-aligned order
/// and wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_x_with_flat_labels(
  pipeline : PositionPipelineContext,
  deps : PositionStageDeps,
) -> XWithFlatLabelData {
  let mode_flags =
    @positioning.build_position_mode_flags(
      {
        has_edge_labels: pipeline.prep.has_edge_labels,
        has_port_edges: pipeline.prep.has_port_edges,
        vnode_count: pipeline.ordering.vnode_count,
        max_xpos_vnodes: deps.max_xpos_vnodes,
        max_xpos_reorder_vnodes: deps.max_xpos_reorder_vnodes,
        rankdir: pipeline.prep.rankdir,
      },
    )
  let x_seed =
    build_x_seed_data(
      {
        use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
        pipeline,
      },
      deps,
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
      deps,
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
/// Dot-owned bridge logic for position_stage default dependencies: x-seed port
/// sampling, x-constraint solving, and stage-default dependency assembly.

const CL_CROSS : Int = 1000

const MAX_XPOS_VNODES : Int = 100000

const MAX_XPOS_REORDER_VNODES : Int = 5000

const CLUSTER_MARGIN_PT : Double = 8.0

const CLUSTER_COMPACT_WEIGHT : Int = 128

const ROOT_COMPRESS_WEIGHT : Int = 1000

///|
fn build_x_seed_port_samples_for_stage(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  x_order_sizes : Map[String, NodeSize],
) -> @ordering.EdgePortSampleBundle {
  @positioning.build_edge_port_sample_bundle(
    nodes,
    edges,
    edge_tail,
    edge_head,
    x_order_sizes,
    @port_bridge.port_offsets_for_nodes,
    @port_bridge.edge_port_offset,
    @port_bridge.edge_port_order,
  )
}

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
) -> Map[String, Double] {
  let port_offsets =
    if @shared.scan_edge_flags(input.edges).has_port_edges {
      @port_bridge.port_offsets_for_nodes(input.nodes, input.output_sizes)
    } else {
      Map::new()
    }
  let (rankdir, root_margin) =
    resolve_x_simplex_root_context(input.nodes)
  @x_constraints.compute_x_positions_with_prepared_constraints(
    input,
    {
      cluster_label_borders_for: @clustering.cluster_label_borders_for_xpos_constraints,
      cluster_label_width_with_pad_for: @clustering.cluster_label_width_with_pad_for_layout,
      cluster_compact_weight: CLUSTER_COMPACT_WEIGHT,
    },
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
fn build_position_stage_deps() -> PositionStageDeps {
  {
    max_xpos_vnodes: MAX_XPOS_VNODES,
    max_xpos_reorder_vnodes: MAX_XPOS_REORDER_VNODES,
    cluster_skeleton_penalty: CL_CROSS,
    build_x_seed_port_samples: build_x_seed_port_samples_for_stage,
    apply_self_edge_right_space: @port_bridge.apply_self_edge_right_space,
    edge_mid_label_metrics_for: edge =>
      match @edge_label_metrics.edge_mid_label_metrics(edge) {
        Some(value) => Some((value.width, value.height))
        None => None
      },
    compute_x_positions: compute_x_positions_for_stage,
    cluster_label_padding_for: @clustering.cluster_label_padding_for_layout,
    cluster_label_width_with_pad_for: @clustering.cluster_label_width_with_pad_for_layout,
    expand_cluster_label_bbox: @clustering.expand_cluster_label_bbox_for_position_stage,
  }
}

///|
/// Graphviz parity: x-positioning aligned to refs/graphviz/lib/dotgen/position.c + dotgen/cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_positions(
  input : PositionStageInput,
  deps? : PositionStageDeps = build_position_stage_deps(),
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
    build_x_with_flat_labels(pipeline, deps)
  build_projection_result(
    {
      pipeline,
      x_data,
    },
    deps,
  )
}
