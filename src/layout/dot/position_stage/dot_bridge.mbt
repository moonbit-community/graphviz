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
      @shared.graph_rankdir(root_graph),
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
    edge => @label_metrics.edge_mid_label_metrics(edge) is Some(_),
    edge =>
      if @shared.edge_dir_for(edge, edge.tail().graph().kind()) is @shared.EdgeDir::Both {
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
      match @label_metrics.edge_mid_label_metrics(edge) {
        Some(value) => Some((value.width, value.height))
        None => None
      },
    compute_x_positions: compute_x_positions_for_stage,
    cluster_label_padding_for: @clustering.cluster_label_padding_for_layout,
    cluster_label_width_with_pad_for: @clustering.cluster_label_width_with_pad_for_layout,
    expand_cluster_label_bbox: @clustering.expand_cluster_label_bbox_for_position_stage,
  }
}
