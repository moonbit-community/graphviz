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
  let solve_input =
    @positioning.build_x_position_solve_input(
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
      },
    )
  compute_x_positions(solve_input)
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
      cluster_margin_pt_for: @positioning.cluster_margin_pt,
      cluster_label_padding_for: cluster_label_padding_for_layout,
      node_half_height_pt_for: @positioning.node_half_height_pt,
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
      cluster_rounding_enabled: @positioning.cluster_rounding_enabled(),
      vnode_clusters: input.pipeline.ordering.vnode_info.vnode_clusters,
      sizes: input.pipeline.prep.sizes,
      cluster_margin_pt_for: @positioning.cluster_margin_pt,
      expand_cluster_label_bbox:
        (graph, bbox) =>
          match graph_label_metrics(graph) {
            Some(metrics) =>
              @dot_shared.expand_bbox_for_label(
                bbox,
                metrics.width_pt,
                metrics.height_pt,
                @dot_shared.graph_label_loc(graph),
              )
            None => bbox
          },
    },
  )
}
///|
/// X-position port geometry, offset, and ordering helpers.

///|
fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> Map[String, Map[String, RecordPort]] {
  @positioning.build_port_offsets_for_nodes(
    nodes,
    output_sizes,
    (node, rankdir) => {
      let record_orientation = record_layout_orientation(rankdir)
      node_size(node, record_orientation)
    },
    (node, origin, base_size, rankdir) => {
      let record_orientation = record_layout_orientation(rankdir)
      raw_label_ports_for_node(node, origin, base_size, record_orientation)
    },
    layout_port_offset,
    swap_node_size,
  )
}

///|
fn compass_uses_shape_clipping(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      true
    "diamond"
    | "mdiamond"
    | "triangle"
    | "invtriangle"
    | "trapezium"
    | "invtrapezium"
    | "parallelogram"
    | "egg"
    | "house"
    | "invhouse"
    | "pentagon"
    | "hexagon"
    | "septagon"
    | "octagon"
    | "doubleoctagon"
    | "tripleoctagon" =>
      true
    "polygon" => {
      let attrs = polygon_shape_attrs(node)
      if attrs.sides < 3 {
        true
      } else {
        !polygon_is_box_like(
          attrs.sides,
          attrs.orientation,
          attrs.distortion,
          attrs.skew,
        )
      }
    }
    _ => false
  }
}

///|
fn compass_port_point_for_layout(
  node_name : String,
  node : @cgraph.Node?,
  compass : @cgraph.Compass,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
) -> @geom.Point {
  @positioning.compass_port_point(
    node_name,
    node,
    compass,
    sizes,
    rankdir,
    compass_uses_shape_clipping,
    (shape_node, size, shape_compass, shape_rankdir) =>
      @edge_spline.compass_port_point_on_shape(
        shape_node,
        @edge_spline.point(0.0, 0.0),
        size,
        shape_compass,
        shape_rankdir,
      ),
    layout_port_offset,
  )
}

///|
fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  @positioning.edge_port_offset(
    node_name,
    port,
    offsets,
    compass =>
      @positioning.compass_port_offset(
        compass,
        node_name,
        sizes,
        rankdir,
        nodes_by_name.get(node_name),
        compass_port_point_for_layout,
        node =>
          @dot_shared.is_record_shape(node) ||
          @html_label.is_html_label_text(label_text(node)),
        layout_port_offset,
      ),
  )
}

///|
fn edge_port_order(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  @positioning.edge_port_order(
    node_name,
    port,
    offsets,
    compass =>
      compass_port_point_for_layout(
        node_name,
        nodes_by_name.get(node_name),
        compass,
        sizes,
        rankdir,
      ),
  )
}
///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128

///|
const ROOT_COMPRESS_WEIGHT : Int = 1000

///|
fn cluster_label_borders_for_xpos_constraints(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> (Double, Double) {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if !flip {
    return (0.0, 0.0)
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let border = metrics.height_pt + CLUSTER_LABEL_PAD_PT
      match @dot_shared.graph_label_loc(graph) {
        LabelLoc::Top => (0.0, border)
        LabelLoc::Bottom => (border, 0.0)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
/// Graphviz parity: xpos payload keeps rank/group/cluster snapshots grouped so
/// position.c/cluster.c constraint wiring remains explicit and stable.
type XPositionsInput = @positioning.XPositionSolveInput

///|
type ConstraintEdge = @positioning.ConstraintEdge

///|
fn resolve_x_simplex_root_context(
  nodes : Array[@cgraph.Node],
) -> (RankDir, Double) {
  if nodes.length() > 0 {
    let root_graph = nodes[0].graph()
    (
      @dot_shared.graph_rankdir(root_graph),
      @positioning.cluster_margin_pt(root_graph),
    )
  } else {
    (RankDir::TB, CLUSTER_MARGIN_PT)
  }
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/position.c + cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_x_positions(
  input : XPositionsInput,
) -> Map[String, Double] {
  let edge_flags = scan_edge_flags(input.edges)
  let port_offsets =
    if edge_flags.has_port_edges {
      port_offsets_for_nodes(input.nodes, input.output_sizes)
    } else {
      Map::new()
    }
  let (rankdir, root_margin) =
    resolve_x_simplex_root_context(input.nodes)
  @positioning.compute_x_positions_with_prepared_constraints(
    input,
    {
      cluster_label_borders_for: cluster_label_borders_for_xpos_constraints,
      cluster_label_width_with_pad_for: cluster_label_width_with_pad_for_layout,
      cluster_compact_weight: CLUSTER_COMPACT_WEIGHT,
    },
    root_margin,
    ROOT_COMPRESS_WEIGHT,
    (segment, real_by_name) =>
      @positioning.segment_slack_minlen(
        segment,
        (node_name, port) =>
          edge_port_offset(
            node_name,
            port,
            port_offsets,
            input.sizes,
            rankdir,
            real_by_name,
          ),
      ),
    edge => edge_mid_label_metrics(edge) is Some(_),
    edge =>
      if @dot_shared.edge_dir_for(edge, edge.tail().graph().kind()) is @dot_shared.EdgeDir::Both {
        2
      } else {
        1
      },
    @positioning.should_capture_xpos_snapshot(input.graph),
  )
}
///|
fn build_port_maps_for_nodes(
  nodes : Array[@cgraph.Node],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Map[String, Map[String, RecordPort]] {
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  let port_maps : Map[String, Map[String, RecordPort]] = Map::new()
  for node in nodes {
    let name = node.name()
    let size = resolve_node_output_size(sizes, node, record_orientation)
    let ports =
      raw_label_ports_for_node(
        node,
        origin,
        size,
        record_orientation,
      )
    if ports.length() > 0 {
      port_maps[name] = ports
    }
  }
  port_maps
}

///|
fn port_side_mask_for_self_edge(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  port_maps : Map[String, Map[String, RecordPort]],
) -> Int {
  match port {
    None => 0
    Some(value) =>
      match value.compass {
        Some(compass) => compass_side_mask(compass)
        None =>
          match value.name {
            Some(port_name) =>
              match port_maps.get(node.name()) {
                Some(ports) =>
                  match ports.get(port_name) {
                    Some(info) => info.sides
                    None => 0
                  }
                None => 0
              }
            None => 0
          }
      }
  }
}

///|
/// Graphviz parity: self-edge right-side spacing aligned to
/// refs/graphviz/lib/dotgen/position.c (self-edge width padding).
/// Do not change behavior without updating fixtures/tests.
fn apply_self_edge_right_space(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, NodeSize] {
  let port_maps = build_port_maps_for_nodes(nodes, sizes, record_orientation)
  @routing.apply_self_edge_right_space(
    {
      edges,
      sizes,
      rankdir,
      self_edge_size_pt: SELF_EDGE_SIZE_PT,
      self_edge_label_width_for: self_edge_label_width_pt,
      port_side_mask_for:
        (node, port) => port_side_mask_for_self_edge(node, port, port_maps),
    },
  )
}
