///|
/// Stage F finalization stage file: postprocess payload + pre/post-rotation
/// finalize pipeline helpers.

type RankData = @rank_assignment.RankData
type RankHeights = @rank_assignment.RankHeights
type PositionResult = @positioning.PositionResult
type DotRoutingStageOutput = @routing_stage.DotRoutingStageOutput

///|
/// Graphviz parity: final postprocess payload keeps stage outputs and layout
/// options grouped so finalize pipeline wiring remains explicit and stable.
priv struct FinalizeLayoutInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  rankdir : RankDir
  splines : SplinesMode
  all_ranks : Array[Int]
  ranks : Map[String, Int]
  sizes : Map[String, NodeSize]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  nodesep_pt : Double
  port_pad_below : Double
  port_pad_above : Double
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Graphviz parity: Stage F source payload keeps upstream stage outputs grouped
/// so final postprocess input assembly stays explicit and stable.
priv struct FinalizeLayoutBuildSources {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  positions_state : PositionResult
  routing_stage_output : DotRoutingStageOutput
}

///|
/// Graphviz parity: Stage F input assembly keeps Stage A-E outputs mapped in
/// one deterministic projection before finalize layout postprocess.
/// Do not change behavior without updating fixtures/tests.
fn build_finalize_layout_input_from_sources(
  sources : FinalizeLayoutBuildSources,
) -> FinalizeLayoutInput {
  {
    graph: sources.graph,
    nodes: sources.prep.nodes,
    nodes_out: sources.routing_stage_output.nodes_out,
    edges_out: sources.routing_stage_output.edges_out,
    rankdir: sources.prep.rankdir,
    splines: sources.prep.splines,
    all_ranks: sources.rank_data.all_ranks,
    ranks: sources.rank_data.ranks,
    sizes: sources.prep.sizes,
    cluster_ln_x: sources.positions_state.cluster_ln_x,
    cluster_rn_x: sources.positions_state.cluster_rn_x,
    cluster_bbox_heights: sources.positions_state.cluster_bbox_heights,
    rank_y: sources.positions_state.rank_y,
    rank_ht1: sources.positions_state.rank_ht1,
    rank_ht2: sources.positions_state.rank_ht2,
    nodesep_pt: sources.rank_heights.nodesep_pt,
    port_pad_below: sources.routing_stage_output.port_pad_below,
    port_pad_above: sources.routing_stage_output.port_pad_above,
    flat_label_edge_vnodes: sources.positions_state.flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: pre-rotation assembly keeps dot_compute_bb + label/ratio
/// interactions in one place before rankdir transforms are applied.
/// Do not change behavior without updating fixtures/tests.
priv struct PreRotationLayoutData {
  layout : DotLayoutGraph
  rank_bbox : @geom.Rect
  subgraph_base_bbox : @geom.Rect
}

///|
priv struct RootPaddedLayoutData {
  layout_with_root_pad : DotLayoutGraph
  ratio_bbox : @geom.Rect
}

///|
/// Graphviz parity: root port padding + root cluster padding are assembled in
/// pre-rotation dot coordinates before ratio/label postprocessing.
/// Do not change behavior without updating fixtures/tests.
fn build_root_padded_layout_data(
  input : FinalizeLayoutInput,
  final_geometry : FinalLayoutGeometry,
  subgraphs_and_bbox : SubgraphsAndBBox,
) -> RootPaddedLayoutData {
  let graph = input.graph
  let rankdir = input.rankdir
  let (root_cluster_pad_top, root_cluster_pad_bottom) =
    @root_geometry.root_cluster_padding_for_rankdir(
      rankdir,
      @root_geometry.compute_root_cluster_padding(
        graph,
        input.nodes,
        input.all_ranks,
        input.ranks,
      ),
    )
  let bbox =
    @root_geometry.apply_root_port_padding(
      graph,
      subgraphs_and_bbox.base_bbox,
      rankdir,
      input.port_pad_below,
      input.port_pad_above,
    )
  let layout_with_root_pad =
    dot_layout_graph_from_layout_tree(
      @coordinate_transform.apply_root_cluster_padding(
        {
          layout: layout_tree_from_dot_layout_graph({
            graph,
            bbox,
            label_pos: None,
            nodes: final_geometry.final_nodes,
            edges: final_geometry.final_edges,
            subgraphs: subgraphs_and_bbox.subgraphs,
          }),
          root_cluster_pad_top,
          root_cluster_pad_bottom,
        },
      ),
    )
  // Graphviz parity: ratio=fill uses pre-spline bbox; include rank/cluster
  // padding that is part of set_ycoords before final edge bbox expansion.
  let ratio_bbox = layout_with_root_pad.bbox
  { layout_with_root_pad, ratio_bbox }
}

///|
/// Graphviz parity: assemble final pre-rotation layout in dot coordinate space
/// before rankdir transforms and cluster mirror policy.
/// Do not change behavior without updating fixtures/tests.
fn build_pre_rotation_layout_data(
  input : FinalizeLayoutInput,
) -> PreRotationLayoutData {
  let graph = input.graph
  let rankdir = input.rankdir
  let final_geometry =
    build_final_layout_geometry(
      {
        nodes_out: input.nodes_out,
        edges_out: input.edges_out,
        all_ranks: input.all_ranks,
        sizes: input.sizes,
        rank_y: input.rank_y,
        rank_ht1: input.rank_ht1,
        rank_ht2: input.rank_ht2,
      },
    )
  let subgraphs_and_bbox =
    build_subgraphs_and_bbox(
      {
        graph,
        nodes: final_geometry.final_nodes,
        edges: final_geometry.final_edges,
        bbox: final_geometry.rank_bbox,
        cluster_ln_x: input.cluster_ln_x,
        cluster_rn_x: input.cluster_rn_x,
        cluster_bbox_heights: input.cluster_bbox_heights,
        rankdir,
        ranks: input.ranks,
        rank_y: input.rank_y,
        rank_ht1: input.rank_ht1,
        rank_ht2: input.rank_ht2,
      },
    )
  let root_padded =
    build_root_padded_layout_data(input, final_geometry, subgraphs_and_bbox)
  let layout =
    apply_pre_rotation_layout_postprocess(input, root_padded)
  {
    layout: {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    },
    rank_bbox: final_geometry.rank_bbox,
    subgraph_base_bbox: subgraphs_and_bbox.base_bbox,
  }
}

///|
/// Graphviz parity: pre-rotation postprocess applies edge bbox expansion,
/// ratio scaling, edge-label adjustment, exterior xlabels, and root label bbox
/// in fixed Graphviz-equivalent order.
/// Do not change behavior without updating fixtures/tests.
fn apply_pre_rotation_layout_postprocess(
  input : FinalizeLayoutInput,
  root_padded : RootPaddedLayoutData,
) -> DotLayoutGraph {
  let graph = input.graph
  let rankdir = input.rankdir
  let layout_with_root_pad = root_padded.layout_with_root_pad
  // Graphviz parity: edge splines update bbox after dot_compute_bb (dotsplines.c).
  let bbox =
    @bbox.expand_bbox_with_edges(layout_with_root_pad.bbox, layout_with_root_pad.edges)
  let layout = {
    graph: layout_with_root_pad.graph,
    bbox,
    label_pos: layout_with_root_pad.label_pos,
    nodes: layout_with_root_pad.nodes,
    edges: layout_with_root_pad.edges,
    subgraphs: layout_with_root_pad.subgraphs,
  }
  let layout =
    dot_layout_graph_from_layout_tree(
      @coordinate_transform.apply_ratio_fill_scale(
        layout_tree_from_dot_layout_graph(layout),
        rankdir,
        root_padded.ratio_bbox,
      ),
    )
  let adjusted_tree =
    @routing.adjust_edge_labels_if_enabled(
      layout_tree_from_dot_layout_graph(layout),
      input.nodesep_pt,
      rankdir,
    )
  let labeled =
    dot_layout_graph_from_layout_tree(
      @routing.expand_layout_tree_bbox_for_edge_labels(
        adjusted_tree,
        input.ranks,
        input.flat_label_edge_vnodes,
      ),
    )
  let with_xlabels = apply_xlabels(graph, labeled, input.splines)
  let root_label_bbox =
    @root_geometry.apply_root_label_bbox(graph, with_xlabels.bbox, rankdir)
  {
    graph: with_xlabels.graph,
    bbox: root_label_bbox.bbox,
    label_pos: root_label_bbox.label_pos,
    nodes: with_xlabels.nodes,
    edges: with_xlabels.edges,
    subgraphs: with_xlabels.subgraphs,
  }
}

///|
/// Graphviz parity: postprocess rankdir transform keeps TB passthrough,
/// non-TB rotation, and LR cluster mirror policy in fixed order.
/// Do not change behavior without updating fixtures/tests.
fn rotate_and_mirror_final_layout(
  graph : @cgraph.Graph,
  rankdir : RankDir,
  pre_rotation : PreRotationLayoutData,
) -> DotLayoutGraph {
  let rotated = if rankdir == RankDir::TB {
    pre_rotation.layout
  } else {
    dot_layout_graph_from_layout_tree(
      @coordinate_transform.rotate_layout_graph(
        layout_tree_from_dot_layout_graph(pre_rotation.layout),
        pre_rotation.layout.bbox,
        rankdir,
      ),
    )
  }
  dot_layout_graph_from_layout_tree(
    @coordinate_transform.apply_cluster_lr_mirror_after_rotation(
      {
        graph,
        rankdir,
        rotated: layout_tree_from_dot_layout_graph(rotated),
        pre_rotation_bbox: pre_rotation.layout.bbox,
        rank_bbox: pre_rotation.rank_bbox,
        subgraph_base_bbox: pre_rotation.subgraph_base_bbox,
      },
    ),
  )
}

///|
/// Graphviz parity: postprocess pipeline aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess) + dotgen/position.c (cluster/label spacing).
/// Do not change behavior without updating fixtures/tests.
fn finalize_layout_graph(
  input : FinalizeLayoutInput,
) -> DotLayoutGraph {
  let graph = input.graph
  let rankdir = input.rankdir
  let pre_rotation = build_pre_rotation_layout_data(input)
  let rotated =
    rotate_and_mirror_final_layout(graph, rankdir, pre_rotation)
  dot_layout_graph_from_layout_tree(
    @coordinate_transform.finalize_root_coordinates(
      layout_tree_from_dot_layout_graph(rotated),
    ),
  )
}
