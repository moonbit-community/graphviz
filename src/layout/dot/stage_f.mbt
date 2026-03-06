///|
/// Stage F finalization stage file: postprocess payload + pre/post-rotation
/// finalize pipeline helpers.

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
    root_cluster_padding_for_rankdir(
      rankdir,
      compute_root_cluster_padding(
        {
          graph,
          nodes: input.nodes,
          all_ranks: input.all_ranks,
          ranks: input.ranks,
        },
      ),
    )
  let bbox =
    apply_root_port_padding(
      {
        graph,
        bbox: subgraphs_and_bbox.base_bbox,
        rankdir,
        port_pad_below: input.port_pad_below,
        port_pad_above: input.port_pad_above,
      },
    )
  let layout_with_root_pad =
    apply_root_cluster_padding(
      {
        graph,
        layout: {
          graph,
          bbox,
          label_pos: None,
          nodes: final_geometry.final_nodes,
          edges: final_geometry.final_edges,
          subgraphs: subgraphs_and_bbox.subgraphs,
        },
        root_cluster_pad_top,
        root_cluster_pad_bottom,
      },
    )
  // Graphviz parity: ratio=fill uses pre-spline bbox; include rank/cluster
  // padding that is part of set_ycoords before final edge bbox expansion.
  let ratio_bbox = layout_with_root_pad.bbox
  { layout_with_root_pad, ratio_bbox }
}

///|
fn root_cluster_padding_for_rankdir(
  rankdir : RankDir,
  root_cluster_padding : RootClusterPadding,
) -> (Double, Double) {
  // Graphviz parity: rankdir=BT flips top/bottom cluster padding
  // because ranks are inverted before postprocess transform.
  if rankdir == RankDir::BT {
    (
      root_cluster_padding.root_cluster_pad_bottom,
      root_cluster_padding.root_cluster_pad_top,
    )
  } else {
    (
      root_cluster_padding.root_cluster_pad_top,
      root_cluster_padding.root_cluster_pad_bottom,
    )
  }
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
    expand_bbox_with_edges(layout_with_root_pad.bbox, layout_with_root_pad.edges)
  let layout = {
    graph: layout_with_root_pad.graph,
    bbox,
    label_pos: layout_with_root_pad.label_pos,
    nodes: layout_with_root_pad.nodes,
    edges: layout_with_root_pad.edges,
    subgraphs: layout_with_root_pad.subgraphs,
  }
  let layout =
    apply_ratio_fill_scale(graph, layout, rankdir, root_padded.ratio_bbox)
  let adjusted = adjust_edge_labels_if_enabled(layout, input.nodesep_pt, rankdir)
  let labeled =
    expand_bbox_for_edge_labels(
      graph,
      adjusted,
      input.ranks,
      input.flat_label_edge_vnodes,
    )
  let with_xlabels = apply_xlabels(graph, labeled, input.splines)
  let root_label_bbox =
    apply_root_label_bbox(graph, with_xlabels.bbox, rankdir)
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
    rotate_layout_graph(pre_rotation.layout, pre_rotation.layout.bbox, rankdir)
  }
  apply_cluster_lr_mirror_after_rotation(
    {
      graph,
      rankdir,
      rotated,
      pre_rotation_bbox: pre_rotation.layout.bbox,
      rank_bbox: pre_rotation.rank_bbox,
      subgraph_base_bbox: pre_rotation.subgraph_base_bbox,
    },
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
  finalize_root_coordinates(
    graph,
    rotated,
  )
}
///|
/// Graphviz parity: cluster bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
priv struct SubgraphsAndBBox {
  subgraphs : Array[DotLayoutGraph]
  base_bbox : @geom.Rect
}

///|
/// Graphviz parity: Stage F subgraph-bbox payload keeps cluster/rank snapshots
/// grouped so final cluster-bbox assembly wiring remains explicit and stable.
priv struct SubgraphsAndBBoxInput {
  graph : @cgraph.Graph
  nodes : Array[DotLayoutNode]
  edges : Array[DotLayoutEdge]
  bbox : @geom.Rect
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
  rankdir : RankDir
  ranks : Map[String, Int]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
/// Graphviz parity: Stage F subgraph+bbox assembly delegates recursive cluster
/// layout to layout_subgraphs, then applies root cluster-bbox expansion.
/// Do not change behavior without updating fixtures/tests.
fn build_subgraphs_and_bbox(
  input : SubgraphsAndBBoxInput,
) -> SubgraphsAndBBox {
  let subgraphs =
    layout_subgraphs(
      {
        graph: input.graph,
        nodes_out: input.nodes,
        edges_out: input.edges,
        cluster_ln_x: input.cluster_ln_x,
        cluster_rn_x: input.cluster_rn_x,
        cluster_bbox_heights: input.cluster_bbox_heights,
        rankdir: input.rankdir,
        ranks: input.ranks,
        rank_y: input.rank_y,
        rank_ht1: input.rank_ht1,
        rank_ht2: input.rank_ht2,
      },
    )
  let expanded = if subgraphs.length() > 0 {
    expand_bbox_with_clusters(input.bbox, subgraphs)
  } else {
    input.bbox
  }
  { subgraphs, base_bbox: expanded }
}

///|
/// Final geometry helpers for postprocess.

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
priv struct FinalLayoutGeometry {
  final_nodes : Array[DotLayoutNode]
  final_edges : Array[DotLayoutEdge]
  rank_bbox : @geom.Rect
}

///|
/// Graphviz parity: final-geometry input keeps rank-bbox dependencies grouped
/// before postprocess assembles subgraphs and root padding.
priv struct FinalLayoutGeometryInput {
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  all_ranks : Array[Int]
  sizes : Map[String, NodeSize]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn build_final_layout_geometry(
  input : FinalLayoutGeometryInput,
) -> FinalLayoutGeometry {
  let base_bbox = compute_dot_bbox(
    {
      nodes_out: input.nodes_out,
      all_ranks: input.all_ranks,
      sizes: input.sizes,
      rank_y: input.rank_y,
      rank_ht1: input.rank_ht1,
      rank_ht2: input.rank_ht2,
    },
  )
  {
    final_nodes: input.nodes_out,
    final_edges: input.edges_out,
    rank_bbox: base_bbox,
  }
}
///|
/// Final-layout ratio=fill scaling helpers used by postprocess.

fn scale_layout_graph(
  layout : DotLayoutGraph,
  sx : Double,
  sy : Double,
  round_node_pos : Bool,
) -> DotLayoutGraph {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let scaled_pos =
      if round_node_pos {
        scale_point_value_rounded(node_layout.pos, sx, sy)
      } else {
        scale_point_value(node_layout.pos, sx, sy)
      }
    nodes.push({
      node: node_layout.node,
      pos: scaled_pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: scale_optional_point_value(node_layout.label_pos, sx, sy),
      xlabel_pos: scale_optional_point_value(node_layout.xlabel_pos, sx, sy),
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(scale_spline_value(spline, sx, sy))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: scale_optional_point_value(edge_layout.label_pos, sx, sy),
      head_label_pos: scale_optional_point_value(
        edge_layout.head_label_pos,
        sx,
        sy,
      ),
      tail_label_pos: scale_optional_point_value(
        edge_layout.tail_label_pos,
        sx,
        sy,
      ),
      xlabel_pos: scale_optional_point_value(edge_layout.xlabel_pos, sx, sy),
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(scale_layout_graph(subgraph, sx, sy, round_node_pos))
  }
  {
    graph: layout.graph,
    bbox: {
      llx: layout.bbox.llx * sx,
      lly: layout.bbox.lly * sy,
      urx: layout.bbox.urx * sx,
      ury: layout.bbox.ury * sy,
    },
    label_pos: scale_optional_point_value(layout.label_pos, sx, sy),
    nodes,
    edges,
    subgraphs,
  }
}

///|
/// Graphviz parity: root ratio=fill scaling aligned to refs/graphviz/lib/dotgen/position.c
/// (set_aspect R_FILL branch + ND_coord rounding).
fn apply_ratio_fill_scale(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  rankdir : RankDir,
  ratio_bbox : @geom.Rect,
) -> DotLayoutGraph {
  if !graph.is_root() {
    return layout
  }
  match @dot_shared.ratio_fill_scale_factors(graph, ratio_bbox, rankdir) {
    Some(scale_factors) => {
      if scale_factors.sx == 1.0 && scale_factors.sy == 1.0 {
        layout
      } else {
        // Graphviz parity: set_aspect rounds ND_coord after scaling.
        scale_layout_graph(layout, scale_factors.sx, scale_factors.sy, true)
      }
    }
    None => layout
  }
}
///|
/// Edge-label bbox expansion helpers used in final postprocess.

///|
/// Graphviz parity: edge label bbox expansion aligned to refs/graphviz/lib/common/utils.c
/// (addLabelBB/compute_bb) + dotgen/dotsplines.c (updateBB for edge labels).
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_for_edge_labels(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  ranks : Map[String, Int],
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutGraph {
  if !graph.is_root() {
    return layout
  }
  let bbox =
    @routing.expand_bbox_for_edge_labels(
      {
        bbox: layout.bbox,
        edges: layout.edges,
        ranks,
        flat_label_edge_vnodes,
        rankdir: @dot_shared.graph_rankdir(graph),
      },
      {
        edge_mid_label_metrics_for:
          edge =>
            match edge_mid_label_metrics(edge) {
              Some(metrics) => Some({ width: metrics.width, height: metrics.height })
              None => None
            },
        edge_label_metrics_for_attr:
          (edge, label_attr) =>
            match edge_label_metrics_for_attr(edge, label_attr, true) {
              Some(metrics) => Some({ width: metrics.width, height: metrics.height })
              None => None
            },
        node_half_height_pt_for:
          (node, rankdir) => {
            let orientation = record_layout_orientation(rankdir)
            node_size(node, orientation).height_pt / 2.0
          },
      },
    )
  if bbox == layout.bbox {
    layout
  } else {
    {
      graph: layout.graph,
      bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    }
  }
}

///|
/// Exterior edge-label nudge heuristic (DOT_ADJUST_EDGE_LABELS only).
fn adjust_edge_labels_if_enabled(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  if edge_label_adjust_enabled() {
    let adjusted_for_clusters =
      adjust_labels_for_clusters(layout, nodesep_pt)
    adjust_labels_for_overlaps(
      adjusted_for_clusters,
      nodesep_pt,
      rankdir,
    )
  } else {
    layout
  }
}
///|
fn set_edge_label_pos_if_present(
  edge : @cgraph.Edge,
  label_attr : String,
  pos_attr : String,
  pos : @geom.Point?,
) -> Unit {
  match pos {
    Some(value) =>
      match edge.get_attr(label_attr) {
        Some(text) => if text != "" { edge.set_attr(pos_attr, format_point(value)) }
        None => ()
      }
    None => ()
  }
}

///|
/// Graphviz parity: final writeback preserves Graphviz attribute emission order
/// for graph/node/edge geometry and label positions.
/// Do not change behavior without updating fixtures/tests.
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  let mut write_bb = self.graph.is_root()
  if !write_bb {
    match self.graph.name() {
      Some(name) => if name.has_prefix("cluster") { write_bb = true }
      None => ()
    }
  }
  let record_orientation =
    record_layout_orientation(@dot_shared.graph_rankdir(self.graph))
  if write_bb {
    self.graph.set_attr("bb", format_rect(self.bbox))
  }
  if write_bb {
    match graph_label_metrics(self.graph) {
      Some(metrics) => {
        self.graph.set_attr("lwidth", format_fixed(metrics.width_pt / 72.0, 2))
        self.graph.set_attr(
          "lheight",
          format_fixed(metrics.height_pt / 72.0, 2),
        )
      }
      None => ()
    }
  }
  match self.label_pos {
    Some(pos) => self.graph.set_attr("lp", format_point(pos))
    None => ()
  }
  for node_layout in self.nodes {
    let node = node_layout.node
    let output_pos : @geom.Point = match node.get_attr("shape") {
      // Graphviz rounds star-node centroids up at the 0.001 boundary.
      Some(shape) if shape.to_lower() == "star" =>
        { x: node_layout.pos.x, y: node_layout.pos.y + 0.0005 }
      _ => node_layout.pos
    }
    node.set_attr("pos", format_point(output_pos))
    node.set_attr("width", format_dim(node_layout.width_in))
    node.set_attr("height", format_dim(node_layout.height_in))
    let is_mrecord = match node.get_attr("shape") {
      Some(value) => value.to_lower() == "mrecord"
      None => false
    }
    if @dot_shared.is_record_shape(node) &&
      !is_mrecord &&
      !@html_label.is_html_label_text(label_text(node)) {
      let size = @dot_shared.node_size_from_points(
        node_layout.width_in * 72.0,
        node_layout.height_in * 72.0,
      )
      let rects = record_rects(
        node,
        node_layout.pos,
        size,
        record_orientation,
      )
      if rects.length() > 0 {
        node.set_attr("rects", format_rects(rects))
      }
    }
    match node_layout.label_pos {
      Some(pos) => node.set_attr("lp", format_point(pos))
      None => ()
    }
    match node_layout.xlabel_pos {
      Some(pos) => node.set_attr("xlp", format_point(pos))
      None => ()
    }
  }
  for edge_layout in self.edges {
    let edge = edge_layout.edge
    // Graphviz parity: omit e/s markers when arrowhead/arrowtail is none.
    let include_tail = @dot_shared.edge_has_tail_marker(edge, self.graph.kind())
    let include_head = @dot_shared.edge_has_head_marker(edge, self.graph.kind())
    let segments : Array[String] = []
    for spline in edge_layout.splines {
      let parts : Array[String] = []
      if include_tail {
        match spline.start {
          Some(point) => parts.push("s,\{format_point(point)}")
          None => ()
        }
      }
      if include_head {
        match spline.end {
          Some(point) => parts.push("e,\{format_point(point)}")
          None => ()
        }
      }
      for point in spline.points {
        parts.push(format_point(point))
      }
      segments.push(parts.join(" "))
    }
    let pos = segments.join(";")
    edge.set_attr("pos", pos)
    set_edge_label_pos_if_present(edge, "label", "lp", edge_layout.label_pos)
    set_edge_label_pos_if_present(
      edge,
      "headlabel",
      "head_lp",
      edge_layout.head_label_pos,
    )
    set_edge_label_pos_if_present(
      edge,
      "taillabel",
      "tail_lp",
      edge_layout.tail_label_pos,
    )
    set_edge_label_pos_if_present(edge, "xlabel", "xlp", edge_layout.xlabel_pos)
  }
  for subgraph in self.subgraphs {
    subgraph.apply()
  }
}
///|
/// Cluster-oriented mirror/label refresh helpers used by final postprocess.

///|
fn count_cluster_subgraphs(graph : @cgraph.Graph) -> Int {
  let mut count = 0
  for subgraph in graph.subgraphs() {
    if @dot_shared.is_cluster_graph(subgraph) {
      count = count + 1
    }
    count = count + count_cluster_subgraphs(subgraph)
  }
  count
}

///|
fn mirror_layout_points(
  layout : DotLayoutGraph,
  point_bbox : @geom.Rect,
  bbox_bbox : @geom.Rect,
) -> DotLayoutGraph {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    nodes.push({
      node: node_layout.node,
      pos: transform_point(node_layout.pos, point_bbox, RankDir::BT),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: transform_optional_point(
        node_layout.label_pos,
        point_bbox,
        RankDir::BT,
      ),
      xlabel_pos: transform_optional_point(
        node_layout.xlabel_pos,
        point_bbox,
        RankDir::BT,
      ),
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(transform_spline(spline, point_bbox, RankDir::BT))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: transform_optional_point(
        edge_layout.label_pos,
        point_bbox,
        RankDir::BT,
      ),
      head_label_pos: transform_optional_point(
        edge_layout.head_label_pos,
        point_bbox,
        RankDir::BT,
      ),
      tail_label_pos: transform_optional_point(
        edge_layout.tail_label_pos,
        point_bbox,
        RankDir::BT,
      ),
      xlabel_pos: transform_optional_point(
        edge_layout.xlabel_pos,
        point_bbox,
        RankDir::BT,
      ),
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(
      mirror_layout_points(subgraph, point_bbox, bbox_bbox),
    )
  }
  let mirrored_bbox =
    transform_bbox_with_root(layout.bbox, bbox_bbox, RankDir::BT)
  {
    graph: layout.graph,
    bbox: mirrored_bbox,
    label_pos: layout.label_pos,
    nodes,
    edges,
    subgraphs,
  }
}

///|
fn refresh_cluster_labels(
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(refresh_cluster_labels(subgraph))
  }
  let label_pos =
    if @dot_shared.is_cluster_graph(layout.graph) {
      match graph_label_metrics(layout.graph) {
        Some(metrics) => {
          let pad = CLUSTER_LABEL_PAD_PT
          Some(
            graph_label_pos(
              layout.bbox,
              metrics.width_pt + pad * 2.0,
              metrics.height_pt + pad,
              @dot_shared.graph_label_loc(layout.graph),
              @dot_shared.graph_label_just(layout.graph),
            ),
          )
        }
        None => layout.label_pos
      }
    } else {
      layout.label_pos
    }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs,
  }
}

///|
/// Graphviz parity: cluster LR/RL mirror input keeps pre/post-rotation bbox
/// snapshots grouped so mirror-path gating remains explicit and stable.
priv struct ClusterLRMirrorInput {
  graph : @cgraph.Graph
  rankdir : RankDir
  rotated : DotLayoutGraph
  pre_rotation_bbox : @geom.Rect
  rank_bbox : @geom.Rect
  subgraph_base_bbox : @geom.Rect
}

///|
/// Graphviz parity: clustered LR/RL layouts are mirrored back after rankdir
/// rotation (dotgen cluster decompose + postproc map_point ordering).
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_lr_mirror_after_rotation(
  input : ClusterLRMirrorInput,
) -> DotLayoutGraph {
  let use_cluster_point_mirror =
    input.subgraph_base_bbox.urx > input.rank_bbox.urx &&
    (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(input.graph)
  let use_lr_multi_cluster_creation_order_mode =
    (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
    count_cluster_subgraphs(input.graph) > 1
  if (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(input.graph) &&
    !use_lr_multi_cluster_creation_order_mode {
    if use_cluster_point_mirror {
      let cluster_mirror_bbox =
        transform_bbox_with_root(input.rank_bbox, input.pre_rotation_bbox, input.rankdir)
      refresh_cluster_labels(
        mirror_layout_points(
          input.rotated,
          cluster_mirror_bbox,
          input.rotated.bbox,
        ),
      )
    } else {
      rotate_layout_graph(input.rotated, input.rotated.bbox, RankDir::BT)
    }
  } else {
    input.rotated
  }
}

///|
/// Layout coordinate transforms/translation helpers used by postprocess.

///|
/// Graphviz parity: rankdir coordinate transform aligned to
/// refs/graphviz/lib/common/postproc.c (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn transform_point(
  point : @geom.Point,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point {
  match rankdir {
    RankDir::TB => point
    RankDir::BT => { x: point.x, y: bbox.lly + bbox.ury - point.y }
    RankDir::LR => { x: bbox.lly + bbox.ury - point.y, y: point.x }
    RankDir::RL => { x: point.y, y: point.x }
  }
}

///|
fn transform_optional_point(
  point : @geom.Point?,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point? {
  match point {
    Some(value) => Some(transform_point(value, bbox, rankdir))
    None => None
  }
}

///|
fn transform_spline(
  spline : @geom.Spline,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(transform_point(point, bbox, rankdir))
  }
  {
    start: transform_optional_point(spline.start, bbox, rankdir),
    end: transform_optional_point(spline.end, bbox, rankdir),
    points,
  }
}

///|
fn shift_point(point : @geom.Point, dx : Double, dy : Double) -> @geom.Point {
  { x: point.x + dx, y: point.y + dy }
}

///|
fn shift_optional_point(
  point : @geom.Point?,
  dx : Double,
  dy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(shift_point(value, dx, dy))
    None => None
  }
}

///|
fn shift_spline(
  spline : @geom.Spline,
  dx : Double,
  dy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(shift_point(point, dx, dy))
  }
  {
    start: shift_optional_point(spline.start, dx, dy),
    end: shift_optional_point(spline.end, dx, dy),
    points,
  }
}

///|
/// Graphviz parity: layout translation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn shift_layout_graph(
  layout : DotLayoutGraph,
  dx : Double,
  dy : Double,
) -> DotLayoutGraph {
  let shifted_nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    shifted_nodes.push({
      node: node_layout.node,
      pos: shift_point(node_layout.pos, dx, dy),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: shift_optional_point(node_layout.label_pos, dx, dy),
      xlabel_pos: shift_optional_point(node_layout.xlabel_pos, dx, dy),
    })
  }
  let shifted_edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(shift_spline(spline, dx, dy))
    }
    shifted_edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: shift_optional_point(edge_layout.label_pos, dx, dy),
      head_label_pos: shift_optional_point(edge_layout.head_label_pos, dx, dy),
      tail_label_pos: shift_optional_point(edge_layout.tail_label_pos, dx, dy),
      xlabel_pos: shift_optional_point(edge_layout.xlabel_pos, dx, dy),
    })
  }
  let shifted_subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    shifted_subgraphs.push(shift_layout_graph(subgraph, dx, dy))
  }
  let shifted_bbox : @geom.Rect = {
    llx: layout.bbox.llx + dx,
    lly: layout.bbox.lly + dy,
    urx: layout.bbox.urx + dx,
    ury: layout.bbox.ury + dy,
  }
  {
    graph: layout.graph,
    bbox: shifted_bbox,
    label_pos: shift_optional_point(layout.label_pos, dx, dy),
    nodes: shifted_nodes,
    edges: shifted_edges,
    subgraphs: shifted_subgraphs,
  }
}

///|
/// Graphviz parity: bbox rotation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_bb/map_point).
/// Do not change behavior without updating fixtures/tests.
fn transform_bbox_with_root(
  bbox : @geom.Rect,
  root_bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Rect {
  if rankdir == RankDir::TB {
    return bbox
  }
  let points : Array[@geom.Point] = [
    { x: bbox.llx, y: bbox.lly },
    { x: bbox.llx, y: bbox.ury },
    { x: bbox.urx, y: bbox.lly },
    { x: bbox.urx, y: bbox.ury },
  ]
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  let mut first = true
  for point in points {
    let mapped = transform_point(point, root_bbox, rankdir)
    if first {
      min_x = mapped.x
      max_x = mapped.x
      min_y = mapped.y
      max_y = mapped.y
      first = false
    } else {
      if mapped.x < min_x { min_x = mapped.x }
      if mapped.x > max_x { max_x = mapped.x }
      if mapped.y < min_y { min_y = mapped.y }
      if mapped.y > max_y { max_y = mapped.y }
    }
  }
  { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
}

///|
/// Graphviz parity: rankdir rotation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/map_point).
/// Do not change behavior without updating fixtures/tests.
fn rotate_layout_graph(
  layout : DotLayoutGraph,
  root_bbox : @geom.Rect,
  rankdir : RankDir,
) -> DotLayoutGraph {
  if rankdir == RankDir::TB {
    return layout
  }
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    nodes.push({
      node: node_layout.node,
      pos: transform_point(node_layout.pos, root_bbox, rankdir),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: transform_optional_point(
        node_layout.label_pos,
        root_bbox,
        rankdir,
      ),
      xlabel_pos: transform_optional_point(
        node_layout.xlabel_pos,
        root_bbox,
        rankdir,
      ),
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(transform_spline(spline, root_bbox, rankdir))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: transform_optional_point(
        edge_layout.label_pos,
        root_bbox,
        rankdir,
      ),
      head_label_pos: transform_optional_point(
        edge_layout.head_label_pos,
        root_bbox,
        rankdir,
      ),
      tail_label_pos: transform_optional_point(
        edge_layout.tail_label_pos,
        root_bbox,
        rankdir,
      ),
      xlabel_pos: transform_optional_point(
        edge_layout.xlabel_pos,
        root_bbox,
        rankdir,
      ),
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(rotate_layout_graph(subgraph, root_bbox, rankdir))
  }
  {
    graph: layout.graph,
    bbox: transform_bbox_with_root(layout.bbox, root_bbox, rankdir),
    label_pos: transform_optional_point(layout.label_pos, root_bbox, rankdir),
    nodes,
    edges,
    subgraphs,
  }
}
///|
/// Root-level postprocess adjustment helpers.

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterPadding {
  root_cluster_pad_top : Double
  root_cluster_pad_bottom : Double
}

///|
/// Graphviz parity: root-cluster padding input keeps rank-span and node-rank
/// snapshots grouped so top/bottom margin gates remain explicit and stable.
priv struct RootClusterPaddingInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  all_ranks : Array[Int]
  ranks : Map[String, Int]
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn compute_root_cluster_padding(
  input : RootClusterPaddingInput,
) -> RootClusterPadding {
  if input.graph.is_root() && @dot_shared.graph_has_cluster(input.graph) &&
    input.all_ranks.length() > 0 {
    let min_rank = input.all_ranks[0]
    let max_rank = input.all_ranks[input.all_ranks.length() - 1]
    let mut cluster_at_min = false
    let mut cluster_at_max = false
    for node in input.nodes {
      let cluster_key = @clustering.node_local_cluster_key(node)
      if cluster_key == "" {
        continue
      }
      match input.ranks.get(node.name()) {
        Some(rank) => {
          if rank == min_rank {
            cluster_at_min = true
          }
          if rank == max_rank {
            cluster_at_max = true
          }
        }
        None => ()
      }
      if cluster_at_min && cluster_at_max {
        break
      }
    }
    let pad = @positioning.cluster_margin_pt(input.graph)
    {
      root_cluster_pad_top: if cluster_at_min { pad } else { 0.0 },
      root_cluster_pad_bottom: if cluster_at_max { pad } else { 0.0 },
    }
  } else {
    { root_cluster_pad_top: 0.0, root_cluster_pad_bottom: 0.0 }
  }
}

///|
/// Graphviz parity: root-port padding input keeps root bbox/rankdir and
/// computed below/above pad deltas grouped before final bbox adjustment.
priv struct RootPortPaddingInput {
  graph : @cgraph.Graph
  bbox : @geom.Rect
  rankdir : RankDir
  port_pad_below : Double
  port_pad_above : Double
}

///|
/// Graphviz parity: record port padding impact aligned to refs/graphviz/lib/dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn apply_root_port_padding(
  input : RootPortPaddingInput,
) -> @geom.Rect {
  if input.graph.is_root() &&
    (input.rankdir == RankDir::TB || input.rankdir == RankDir::BT) {
    if input.port_pad_below > 0.0 || input.port_pad_above > 0.0 {
      {
        llx: input.bbox.llx,
        lly: input.bbox.lly - input.port_pad_below,
        urx: input.bbox.urx,
        ury: input.bbox.ury + input.port_pad_above,
      }
    } else {
      input.bbox
    }
  } else {
    input.bbox
  }
}

///|
/// Graphviz parity: translate to origin aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn shift_layout_to_origin(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  if graph.is_root() {
    let dx = -layout.bbox.llx
    let dy = -layout.bbox.lly
    if dx != 0.0 || dy != 0.0 {
      shift_layout_graph(layout, dx, dy)
    } else {
      layout
    }
  } else {
    layout
  }
}

///|
/// Graphviz parity: root-cluster padding apply input keeps root-layout and
/// top/bottom pad deltas grouped for one shift + bbox rebuild boundary.
priv struct RootClusterPaddingApplyInput {
  graph : @cgraph.Graph
  layout : DotLayoutGraph
  root_cluster_pad_top : Double
  root_cluster_pad_bottom : Double
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn apply_root_cluster_padding(
  input : RootClusterPaddingApplyInput,
) -> DotLayoutGraph {
  if input.graph.is_root() &&
    (input.root_cluster_pad_top > 0.0 || input.root_cluster_pad_bottom > 0.0) {
    let padded =
      shift_layout_graph(input.layout, 0.0, input.root_cluster_pad_bottom)
    let padded_bbox : @geom.Rect = {
      llx: input.layout.bbox.llx,
      lly: input.layout.bbox.lly,
      urx: input.layout.bbox.urx,
      ury:
        input.layout.bbox.ury + input.root_cluster_pad_bottom +
        input.root_cluster_pad_top,
    }
    let label_pos =
      match root_label_pos_for_bbox(input.graph, padded_bbox) {
        Some(pos) => Some(pos)
        None => padded.label_pos
      }
    {
      graph: padded.graph,
      bbox: padded_bbox,
      label_pos,
      nodes: padded.nodes,
      edges: padded.edges,
      subgraphs: padded.subgraphs,
    }
  } else {
    input.layout
  }
}

///|
fn refresh_root_label_position(
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  if layout.graph.is_root() {
    let label_pos =
      match root_label_pos_for_bbox(layout.graph, layout.bbox) {
        Some(pos) => Some(pos)
        None => layout.label_pos
      }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    }
  } else {
    layout
  }
}

///|
/// Graphviz parity: final root-coordinate frame applies margin, then origin
/// translation, then root label refresh.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_coordinates(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  let with_margin = {
    graph: layout.graph,
    bbox: apply_root_margin_x(graph, layout.bbox),
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs: layout.subgraphs,
  }
  refresh_root_label_position(
    shift_layout_to_origin(graph, with_margin),
  )
}

///|
/// Root-label bbox and margin helpers used by final postprocess.

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
fn expand_root_bbox_for_label(
  bbox : @geom.Rect,
  padded_width : Double,
  padded_height : Double,
  loc : LabelLoc,
  rankdir : RankDir,
) -> @geom.Rect {
  let mut llx = bbox.llx
  let mut lly = bbox.lly
  let mut urx = bbox.urx
  let mut ury = bbox.ury
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    match loc {
      LabelLoc::Top => urx = urx + padded_height
      LabelLoc::Bottom => llx = llx - padded_height
    }
    let span = ury - lly
    if padded_width > span {
      let diff = (padded_width - span) / 2.0
      lly = lly - diff
      ury = ury + diff
    }
  } else {
    match loc {
      LabelLoc::Top =>
        if rankdir == RankDir::TB {
          ury = ury + padded_height
        } else {
          lly = lly - padded_height
        }
      LabelLoc::Bottom =>
        if rankdir == RankDir::TB {
          lly = lly - padded_height
        } else {
          ury = ury + padded_height
        }
    }
    let span = urx - llx
    if padded_width > span {
      let diff = (padded_width - span) / 2.0
      llx = llx - diff
      urx = urx + diff
    }
  }
  { llx, lly, urx, ury }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
priv struct RootLabelBBoxOutput {
  bbox : @geom.Rect
  label_pos : @geom.Point?
}

///|
priv struct RootLabelPlacementSpec {
  padded_width : Double
  padded_height : Double
  loc : LabelLoc
  just : LabelJust
}

///|
/// Graphviz parity: root-label placement spec reads graph label metrics + attrs
/// once per call path before bbox/position emission.
fn root_label_placement_spec(
  graph : @cgraph.Graph,
) -> RootLabelPlacementSpec? {
  if !graph.is_root() {
    return None
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let pad = CLUSTER_LABEL_PAD_PT
      Some({
        padded_width: metrics.width_pt + pad * 2.0,
        padded_height: metrics.height_pt + pad,
        loc: @dot_shared.graph_label_loc(graph),
        just: @dot_shared.graph_label_just(graph),
      })
    }
    None => None
  }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
fn apply_root_label_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> RootLabelBBoxOutput {
  let mut bbox = bbox
  let mut label_pos : @geom.Point? = None
  match root_label_placement_spec(graph) {
    Some(spec) => {
      bbox =
        expand_root_bbox_for_label(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          rankdir,
        )
      label_pos = Some(
        graph_label_pos(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          spec.just,
        ),
      )
    }
    None => ()
  }
  { bbox, label_pos }
}

///|
/// Graphviz parity: root label placement aligned to refs/graphviz/lib/common/postproc.c
/// (place_root_label).
/// Do not change behavior without updating fixtures/tests.
fn root_label_pos_for_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Point? {
  match root_label_placement_spec(graph) {
    Some(spec) =>
      Some(
        graph_label_pos(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          spec.just,
        ),
      )
    None => None
  }
}

///|
/// Graphviz parity: root graph margin aligned to refs/graphviz/lib/common/input.c + dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn apply_root_margin_x(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Rect {
  if graph.is_root() {
    let margin_x = if @dot_shared.graph_has_cluster(graph) {
      graph_margin_x_pt(graph)
    } else {
      0.0
    }
    if margin_x > 0.0 {
      {
        llx: bbox.llx - margin_x,
        lly: bbox.lly,
        urx: bbox.urx + margin_x,
        ury: bbox.ury,
      }
    } else {
      bbox
    }
  } else {
    bbox
  }
}
///|
/// Edge-label collision adjustment and bbox expansion helpers for cluster and
/// sibling-overlap postprocessing.

///|
fn collect_cluster_label_rects(
  graphs : Array[DotLayoutGraph],
  pad : Double,
) -> Array[@geom.Rect] {
  let rects : Array[@geom.Rect] = []
  for subgraph in graphs {
    match subgraph.label_pos {
      Some(pos) =>
        match graph_label_metrics(subgraph.graph) {
          Some(metrics) =>
            rects.push(
              rect_from_center(
                pos,
                metrics.width_pt,
                metrics.height_pt,
                pad,
              ),
            )
          None => ()
        }
      None => ()
    }
    let nested = collect_cluster_label_rects(subgraph.subgraphs, pad)
    for rect in nested {
      rects.push(rect)
    }
  }
  rects
}

///|
fn apply_edge_label_updates(
  graphs : Array[DotLayoutGraph],
  updates : Map[String, @geom.Point],
) -> Array[DotLayoutGraph] {
  let updated : Array[DotLayoutGraph] = []
  for graph in graphs {
    let edges = @routing.apply_label_updates_to_edges(graph.edges, updates)
    let subgraphs = apply_edge_label_updates(graph.subgraphs, updates)
    updated.push({
      graph: graph.graph,
      bbox: graph.bbox,
      label_pos: graph.label_pos,
      nodes: graph.nodes,
      edges,
      subgraphs,
    })
  }
  updated
}

///|
fn map_layout_subgraphs(
  subgraphs : Array[DotLayoutGraph],
  mapper : (DotLayoutGraph) -> DotLayoutGraph,
) -> Array[DotLayoutGraph] {
  let mapped : Array[DotLayoutGraph] = []
  for subgraph in subgraphs {
    mapped.push(mapper(subgraph))
  }
  mapped
}

///|
fn rebuild_layout_edges_subgraphs(
  layout : DotLayoutGraph,
  edges : Array[DotLayoutEdge],
  subgraphs : Array[DotLayoutGraph],
) -> DotLayoutGraph {
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges,
    subgraphs,
  }
}

///|
fn adjust_labels_for_clusters(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
) -> DotLayoutGraph {
  let pad = if nodesep_pt * 0.2 < 2.0 { 2.0 } else { nodesep_pt * 0.2 }
  let label_rects : Array[@geom.Rect] = []
  match layout.label_pos {
    Some(pos) =>
      match graph_label_metrics(layout.graph) {
        Some(metrics) =>
          label_rects.push(
            rect_from_center(pos, metrics.width_pt, metrics.height_pt, pad),
          )
        None => ()
      }
    None => ()
  }
  let subgraph_rects = collect_cluster_label_rects(layout.subgraphs, pad)
  for rect in subgraph_rects {
    label_rects.push(rect)
  }
  if label_rects.length() == 0 {
    let subgraphs =
      map_layout_subgraphs(
        layout.subgraphs,
        subgraph => adjust_labels_for_clusters(subgraph, nodesep_pt),
      )
    rebuild_layout_edges_subgraphs(layout, layout.edges, subgraphs)
  } else {
    let adjusted_labels =
      @routing.adjust_edge_label_positions(
        layout.edges,
        label_rects,
        pad,
        edge =>
          match edge_mid_label_metrics(edge) {
            Some(metrics) => Some({ width: metrics.width, height: metrics.height })
            None => None
          },
      )
    let updated_subgraphs =
      apply_edge_label_updates(layout.subgraphs, adjusted_labels.updates)
    let subgraphs =
      map_layout_subgraphs(
        updated_subgraphs,
        subgraph => adjust_labels_for_clusters(subgraph, nodesep_pt),
      )
    rebuild_layout_edges_subgraphs(layout, adjusted_labels.edges, subgraphs)
  }
}

///|
fn adjust_labels_for_overlaps(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  let adjusted =
    @routing.adjust_edge_label_overlaps(
      layout.edges,
      nodesep_pt,
      rankdir,
      edge =>
        match edge_mid_label_metrics(edge) {
          Some(metrics) => Some({ width: metrics.width, height: metrics.height })
          None => None
        },
      @routing.edge_tail_point_for_layout,
    )
  if adjusted.updates.length() == 0 {
    let subgraphs =
      map_layout_subgraphs(
        layout.subgraphs,
        subgraph => adjust_labels_for_overlaps(subgraph, nodesep_pt, rankdir),
      )
    rebuild_layout_edges_subgraphs(layout, layout.edges, subgraphs)
  } else {
    let updated_subgraphs =
      apply_edge_label_updates(layout.subgraphs, adjusted.updates)
    let subgraphs =
      map_layout_subgraphs(
        updated_subgraphs,
        subgraph => adjust_labels_for_overlaps(subgraph, nodesep_pt, rankdir),
      )
    rebuild_layout_edges_subgraphs(layout, adjusted.edges, subgraphs)
  }
}

///|
fn edge_label_adjust_enabled() -> Bool {
  @dot_shared.env_flag_enabled_nonempty(@sys.get_env_var("DOT_ADJUST_EDGE_LABELS"))
}

///|
fn expand_bbox_for_label(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
) -> @geom.Rect {
  let pad = 8.0
  let mut llx = bbox.llx
  let mut lly = bbox.lly
  let mut urx = bbox.urx
  let mut ury = bbox.ury
  match loc {
    LabelLoc::Top => ury = ury + label_height_pt + pad
    LabelLoc::Bottom => lly = lly - label_height_pt - pad
  }
  let label_width = label_width_pt + pad * 2.0
  let current_width = urx - llx
  if label_width > current_width {
    let extra = label_width - current_width
    llx = llx - extra / 2.0
    urx = urx + extra / 2.0
  }
  { llx, lly, urx, ury }
}
///|
/// Graphviz parity: exterior label placement aligned to refs/graphviz/lib/label/xlabels.c
/// + lib/common/postproc.c (addXLabels/edgeMidpoint).
/// Do not change behavior without updating fixtures/tests.

///|
priv enum XLabelTarget {
  Node(String)
  EdgeMid(String)
  EdgeHead(String)
  EdgeTail(String)
  EdgeXlabel(String)
}

///|
priv struct XLabel {
  target : XLabelTarget
  width : Double
  height : Double
  pos : @geom.Point
  set : Bool
}

///|
priv struct XLabelUpdateMaps {
  node_updates : Map[String, @geom.Point]
  edge_mid_updates : Map[String, @geom.Point]
  edge_head_updates : Map[String, @geom.Point]
  edge_tail_updates : Map[String, @geom.Point]
  edge_xlabel_updates : Map[String, @geom.Point]
}

///|
fn make_xlabel_update_maps() -> XLabelUpdateMaps {
  {
    node_updates: Map::new(),
    edge_mid_updates: Map::new(),
    edge_head_updates: Map::new(),
    edge_tail_updates: Map::new(),
    edge_xlabel_updates: Map::new(),
  }
}

///|
fn xlabel_center(label : XLabel) -> @geom.Point {
  @edge_spline.point(label.pos.x + label.width / 2.0, label.pos.y + label.height / 2.0)
}

///|
fn record_xlabel_update(
  updates : XLabelUpdateMaps,
  target : XLabelTarget,
  center : @geom.Point,
) -> Unit {
  match target {
    XLabelTarget::Node(name) => updates.node_updates[name] = center
    XLabelTarget::EdgeMid(key) => updates.edge_mid_updates[key] = center
    XLabelTarget::EdgeHead(key) => updates.edge_head_updates[key] = center
    XLabelTarget::EdgeTail(key) => updates.edge_tail_updates[key] = center
    XLabelTarget::EdgeXlabel(key) => updates.edge_xlabel_updates[key] = center
  }
}

///|
fn expand_bbox_for_existing_xlabel(
  bbox : @geom.Rect,
  pos : @geom.Point?,
  metrics : XLabelMetrics?,
  flip : Bool,
) -> @geom.Rect {
  let mut expanded = bbox
  match pos {
    Some(value) =>
      match metrics {
        Some(label_metrics) => {
          let dims =
            maybe_flip_dims(label_metrics.width, label_metrics.height, flip)
          expanded =
            @routing.expand_bbox_for_label_pos(
              expanded,
              Some(value),
              Some({ width: dims.width, height: dims.height }),
            )
        }
        None => ()
      }
    None => ()
  }
  expanded
}

///|
fn expand_bbox_for_existing_node_xlabels(
  bbox : @geom.Rect,
  nodes : Array[DotLayoutNode],
  flip : Bool,
) -> @geom.Rect {
  let mut expanded = bbox
  for node_layout in nodes {
    expanded =
      expand_bbox_for_existing_xlabel(
        expanded,
        node_layout.xlabel_pos,
        xlabel_metrics_for_node(node_layout.node),
        flip,
      )
  }
  expanded
}

///|
fn expand_bbox_for_existing_edge_xlabels(
  bbox : @geom.Rect,
  edges : Array[DotLayoutEdge],
  flip : Bool,
) -> @geom.Rect {
  let mut expanded = bbox
  for edge_layout in edges {
    expanded =
      expand_bbox_for_existing_xlabel(
        expanded,
        edge_layout.xlabel_pos,
        xlabel_metrics_for_edge(edge_layout.edge),
        flip,
      )
  }
  expanded
}

fn apply_xlabels(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  splines : SplinesMode,
) -> DotLayoutGraph {
  let rankdir = @dot_shared.graph_rankdir(graph)
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let labels : Array[XLabel] = []
  let objects : Array[XObject] = []
  collect_xlabel_candidates(layout, splines, flip, labels, objects)
  collect_cluster_label_objects(layout, objects, flip)
  if labels.length() > 0 {
    let force = parse_forcelabels(graph)
    place_labels(objects, labels, force)
  }
  finalize_xlabels(layout, labels, flip)
}
///|
/// Xlabel finalization: merge existing/new xlabel positions into layout output
/// and expand the graph bbox accordingly.

fn finalize_xlabels(
  layout : DotLayoutGraph,
  labels : Array[XLabel],
  flip : Bool,
) -> DotLayoutGraph {
  let updates = make_xlabel_update_maps()
  let mut bbox =
    expand_bbox_for_existing_node_xlabels(layout.bbox, layout.nodes, flip)
  bbox =
    expand_bbox_for_existing_edge_xlabels(bbox, layout.edges, flip)
  for label in labels {
    if !label.set {
      continue
    }
    let center = xlabel_center(label)
    bbox = @routing.expand_bbox_for_label_pos(
      bbox,
      Some(center),
      Some({ width: label.width, height: label.height }),
    )
    record_xlabel_update(updates, label.target, center)
  }
  let updated =
    apply_xlabel_updates(
      layout,
      updates,
    )
  {
    graph: updated.graph,
    bbox,
    label_pos: updated.label_pos,
    nodes: updated.nodes,
    edges: updated.edges,
    subgraphs: updated.subgraphs,
  }
}
///|
/// Xlabel layout update and cluster-label obstacle collection helpers.

///|
priv struct XObject {
  pos : @geom.Point
  width : Double
  height : Double
  label_index : Int?
}

fn parse_int_prefix(value : String) -> Int? {
  let mut acc = 0
  let mut seen = false
  for c in value {
    if c.is_ascii_digit() {
      seen = true
      acc = acc * 10 + (c.to_int() - '0'.to_int())
    } else {
      break
    }
  }
  if seen {
    Some(acc)
  } else {
    None
  }
}

fn parse_bool_attr(value : String, default_value : Bool) -> Bool {
  if value == "" {
    return default_value
  }
  let lower = value.to_lower()
  if lower == "false" || lower == "no" {
    return false
  }
  if lower == "true" || lower == "yes" {
    return true
  }
  match lower.get_char(0) {
    Some(c) =>
      if c.is_ascii_digit() {
        match parse_int_prefix(lower) {
          Some(number) => number != 0
          None => default_value
        }
      } else {
        default_value
      }
    None => default_value
  }
}

fn parse_forcelabels(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("forcelabels") {
    None => true
    Some(text) => parse_bool_attr(text, false)
  }
}

///|
fn apply_xlabel_updates(
  layout : DotLayoutGraph,
  updates : XLabelUpdateMaps,
) -> DotLayoutGraph {
  let update_or_fallback =
    (
      update_map : Map[String, @geom.Point],
      key : String,
      fallback : @geom.Point?,
    ) =>
      match update_map.get(key) {
        Some(pos) => Some(pos)
        None => fallback
      }
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let xlabel_pos =
      update_or_fallback(
        updates.node_updates,
        node_layout.node.name(),
        node_layout.xlabel_pos,
      )
    nodes.push({
      node: node_layout.node,
      pos: node_layout.pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: node_layout.label_pos,
      xlabel_pos,
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let key = @dot_shared.edge_key(edge_layout.edge)
    let label_pos =
      update_or_fallback(
        updates.edge_mid_updates,
        key,
        edge_layout.label_pos,
      )
    let head_label_pos =
      update_or_fallback(
        updates.edge_head_updates,
        key,
        edge_layout.head_label_pos,
      )
    let tail_label_pos =
      update_or_fallback(
        updates.edge_tail_updates,
        key,
        edge_layout.tail_label_pos,
      )
    let xlabel_pos =
      update_or_fallback(
        updates.edge_xlabel_updates,
        key,
        edge_layout.xlabel_pos,
      )
    edges.push({
      edge: edge_layout.edge,
      splines: edge_layout.splines,
      label_pos,
      head_label_pos,
      tail_label_pos,
      xlabel_pos,
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(
      apply_xlabel_updates(
        subgraph,
        updates,
      ),
    )
  }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes,
    edges,
    subgraphs,
  }
}

fn collect_cluster_label_objects(
  layout : DotLayoutGraph,
  objects : Array[XObject],
  flip : Bool,
) -> Unit {
  for subgraph in layout.subgraphs {
    match subgraph.label_pos {
      Some(pos) =>
        match graph_label_metrics(subgraph.graph) {
          Some(metrics) => {
            let dims =
              maybe_flip_dims(metrics.width_pt, metrics.height_pt, flip)
            let llx = pos.x - dims.width / 2.0
            let lly = pos.y - dims.height / 2.0
            objects.push({
              pos: @edge_spline.point(llx, lly),
              width: dims.width,
              height: dims.height,
              label_index: None,
            })
          }
          None => ()
        }
      None => ()
    }
    collect_cluster_label_objects(subgraph, objects, flip)
  }
}
///|
/// Xlabel dimension metrics and rankdir-flip helpers shared by candidate,
/// update, and finalization stages.

priv struct XLabelMetrics {
  width : Double
  height : Double
}

priv struct LabelDims {
  width : Double
  height : Double
}


fn xlabel_metrics_for_node(node : @cgraph.Node) -> XLabelMetrics? {
  match node.get_attr("xlabel") {
    Some(text) =>
      if text == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
        let font = @attrs.font_name(node.get_attr("fontname"))
        let (width, height) = label_text_dimensions(text, font, font_size_pt)
        Some({ width, height })
      }
    None => None
  }
}

fn xlabel_metrics_for_edge(edge : @cgraph.Edge) -> XLabelMetrics? {
  match edge_label_metrics_for_attr(edge, "xlabel", false) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

fn maybe_flip_dims(
  width : Double,
  height : Double,
  flip : Bool,
) -> LabelDims {
  if flip {
    { width: height, height: width }
  } else {
    { width, height }
  }
}
///|
/// Xlabel candidate collection from node/edge geometry and existing label
/// placements before running xlabels.c-style search.

fn build_edges_by_tail(
  layout : DotLayoutGraph,
) -> Map[String, Array[DotLayoutEdge]] {
  let edges_by_tail : Map[String, Array[DotLayoutEdge]] = Map::new()
  for edge_layout in layout.edges {
    let tail_name = edge_layout.edge.tail().name()
    let list = match edges_by_tail.get(tail_name) {
      Some(value) => value
      None => []
    }
    list.push(edge_layout)
    edges_by_tail[tail_name] = list
  }
  edges_by_tail
}

fn edge_mid_metrics_for_xlabel(edge : @cgraph.Edge) -> XLabelMetrics? {
  match edge_mid_label_metrics(edge) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

fn edge_attr_metrics_for_xlabel(
  edge : @cgraph.Edge,
  key : String,
) -> XLabelMetrics? {
  match edge_label_metrics_for_attr(edge, key, true) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

fn push_existing_label_object(
  pos : @geom.Point,
  metrics : XLabelMetrics,
  flip : Bool,
  objects : Array[XObject],
) -> Unit {
  let label_dims =
    maybe_flip_dims(metrics.width, metrics.height, flip)
  let pos_ll =
    @edge_spline.point(
      pos.x - label_dims.width / 2.0,
      pos.y - label_dims.height / 2.0,
    )
  objects.push({
    pos: pos_ll,
    width: label_dims.width,
    height: label_dims.height,
    label_index: None,
  })
}

fn push_unset_xlabel_label(
  target : XLabelTarget,
  metrics : XLabelMetrics,
  flip : Bool,
  labels : Array[XLabel],
) -> Int {
  let label_dims =
    maybe_flip_dims(metrics.width, metrics.height, flip)
  let idx = labels.length()
  labels.push({
    target,
    width: label_dims.width,
    height: label_dims.height,
    pos: @edge_spline.point(0.0, 0.0),
    set: false,
  })
  idx
}

fn push_deferred_label_anchor(
  target : XLabelTarget,
  metrics : XLabelMetrics,
  anchor : @geom.Point,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let idx =
    push_unset_xlabel_label(target, metrics, flip, labels)
  objects.push({
    pos: anchor,
    width: 0.0,
    height: 0.0,
    label_index: Some(idx),
  })
}

fn collect_edge_label_candidate(
  target : XLabelTarget,
  current_pos : @geom.Point?,
  metrics : XLabelMetrics?,
  anchor : @geom.Point?,
  has_geometry : Bool,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  match current_pos {
    Some(pos) =>
      match metrics {
        Some(value) => push_existing_label_object(pos, value, flip, objects)
        None => ()
      }
    None =>
      if has_geometry {
        match (metrics, anchor) {
          (Some(value), Some(point)) =>
            push_deferred_label_anchor(
              target,
              value,
              point,
              flip,
              labels,
              objects,
            )
          _ => ()
        }
      }
  }
}

///|
priv struct EdgeLabelAnchors {
  has_geometry : Bool
  mid_anchor : @geom.Point?
  tail_anchor : @geom.Point?
  head_anchor : @geom.Point?
}

///|
fn build_node_obstacle_with_xlabel_slot(
  node_layout : DotLayoutNode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> XObject {
  let node = node_layout.node
  let width_pt = node_layout.width_in * 72.0
  let height_pt = node_layout.height_in * 72.0
  let obj_dims = maybe_flip_dims(width_pt, height_pt, flip)
  let llx = node_layout.pos.x - obj_dims.width / 2.0
  let lly = node_layout.pos.y - obj_dims.height / 2.0
  let mut label_index : Int? = None
  match xlabel_metrics_for_node(node) {
    Some(metrics) =>
      match node_layout.xlabel_pos {
        Some(pos) =>
          push_existing_label_object(pos, metrics, flip, objects)
        None =>
          label_index = Some(
            push_unset_xlabel_label(
              XLabelTarget::Node(node.name()),
              metrics,
              flip,
              labels,
            ),
          )
      }
    None => ()
  }
  {
    pos: @edge_spline.point(llx, lly),
    width: obj_dims.width,
    height: obj_dims.height,
    label_index,
  }
}

///|
fn collect_edge_label_anchors(
  edge_layout : DotLayoutEdge,
  splines : SplinesMode,
) -> EdgeLabelAnchors {
  let has_geometry = edge_layout.splines.length() > 0
  if !has_geometry {
    return {
      has_geometry,
      mid_anchor: None,
      tail_anchor: None,
      head_anchor: None,
    }
  }
  let use_spline_midpoint =
    splines == SplinesMode::Spline || splines == SplinesMode::Curved
  {
    has_geometry,
    mid_anchor: @routing.edge_midpoint_for_layout(edge_layout, use_spline_midpoint),
    tail_anchor: @routing.edge_tail_point_for_layout(edge_layout),
    head_anchor: @routing.edge_head_point_for_layout(edge_layout),
  }
}

///|
fn collect_edge_xlabel_candidates(
  edge_layout : DotLayoutEdge,
  splines : SplinesMode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let edge = edge_layout.edge
  let edge_key = @dot_shared.edge_key(edge)
  let anchors = collect_edge_label_anchors(edge_layout, splines)
  collect_edge_label_candidate(
    XLabelTarget::EdgeMid(edge_key),
    edge_layout.label_pos,
    edge_mid_metrics_for_xlabel(edge),
    anchors.mid_anchor,
    anchors.has_geometry,
    flip,
    labels,
    objects,
  )
  collect_edge_label_candidate(
    XLabelTarget::EdgeTail(edge_key),
    edge_layout.tail_label_pos,
    edge_attr_metrics_for_xlabel(edge, "taillabel"),
    anchors.tail_anchor,
    anchors.has_geometry,
    flip,
    labels,
    objects,
  )
  collect_edge_label_candidate(
    XLabelTarget::EdgeHead(edge_key),
    edge_layout.head_label_pos,
    edge_attr_metrics_for_xlabel(edge, "headlabel"),
    anchors.head_anchor,
    anchors.has_geometry,
    flip,
    labels,
    objects,
  )
  collect_edge_label_candidate(
    XLabelTarget::EdgeXlabel(edge_key),
    edge_layout.xlabel_pos,
    xlabel_metrics_for_edge(edge),
    anchors.mid_anchor,
    anchors.has_geometry,
    flip,
    labels,
    objects,
  )
}

fn collect_xlabel_candidates(
  layout : DotLayoutGraph,
  splines : SplinesMode,
  flip : Bool,
  labels : Array[XLabel],
  objects : Array[XObject],
) -> Unit {
  let edges_by_tail = build_edges_by_tail(layout)
  for node_layout in layout.nodes {
    objects.push(
      build_node_obstacle_with_xlabel_slot(
        node_layout,
        flip,
        labels,
        objects,
      ),
    )

    let edges_for_node = match edges_by_tail.get(node_layout.node.name()) {
      Some(value) => value
      None => []
    }
    for edge_layout in edges_for_node {
      collect_edge_xlabel_candidates(edge_layout, splines, flip, labels, objects)
    }
  }
}
///|
/// Exterior-label placement core: xlabel metrics, overlap scoring, candidate
/// search, and xlabels.c-style candidate selection.

const XLXDENOM : Double = 8.0

///|
const XLYDENOM : Double = 2.0

const XLPXPY : Int = 0
const XLCXPY : Int = 1
const XLNXPY : Int = 2
const XLPXCY : Int = 3
const XLNXCY : Int = 5
const XLPXNY : Int = 6
const XLCXNY : Int = 7
const XLNXNY : Int = 8

///|
priv struct XBestPos {
  n : Int
  area : Double
  pos : @geom.Point
}

fn rect_overlap_area(a : @geom.Rect, b : @geom.Rect) -> Double {
  let min_x = if a.llx > b.llx { a.llx } else { b.llx }
  let max_x = if a.urx < b.urx { a.urx } else { b.urx }
  let min_y = if a.lly > b.lly { a.lly } else { b.lly }
  let max_y = if a.ury < b.ury { a.ury } else { b.ury }
  if max_x > min_x && max_y > min_y {
    (max_x - min_x) * (max_y - min_y)
  } else {
    0.0
  }
}

fn rect_from_object(obj : XObject) -> @geom.Rect {
  let llx = obj.pos.x.round()
  let lly = obj.pos.y.round()
  let urx = (obj.pos.x + obj.width).round()
  let ury = (obj.pos.y + obj.height).round()
  { llx, lly, urx, ury }
}

fn rect_from_label(label : XLabel) -> @geom.Rect {
  let llx = label.pos.x.round()
  let lly = label.pos.y.round()
  let urx = (label.pos.x + label.width).round()
  let ury = (label.pos.y + label.height).round()
  { llx, lly, urx, ury }
}

fn label_encloses_point(label : XLabel, point_obj : XObject) -> Bool {
  let px = point_obj.pos.x
  let py = point_obj.pos.y
  px > label.pos.x &&
    px < label.pos.x + label.width &&
    py > label.pos.y &&
    py < label.pos.y + label.height
}

fn get_intrsx_index(
  op : XObject,
  cp : XObject,
  labels : Array[XLabel],
) -> Int {
  let op_set = match op.label_index {
    Some(idx) => labels[idx].set
    None => false
  }
  let cp_set = match cp.label_index {
    Some(idx) => labels[idx].set
    None => false
  }
  if !op_set || !cp_set {
    return -1
  }
  if (op.pos.x == 0.0 && op.pos.y == 0.0) ||
    (cp.pos.x == 0.0 && cp.pos.y == 0.0) {
    return -1
  }
  if cp.pos.y < op.pos.y {
    if cp.pos.x < op.pos.x {
      return XLPXPY
    }
    if cp.pos.x > op.pos.x {
      return XLNXPY
    }
    return XLCXPY
  }
  if cp.pos.y > op.pos.y {
    if cp.pos.x < op.pos.x {
      return XLPXNY
    }
    if cp.pos.x > op.pos.x {
      return XLNXNY
    }
    return XLCXNY
  }
  if cp.pos.x < op.pos.x {
    return XLPXCY
  }
  if cp.pos.x > op.pos.x {
    return XLNXCY
  }
  -1
}

fn record_intersection_slot(
  objs : Array[XObject],
  labels : Array[XLabel],
  op_idx : Int,
  cp_idx : Int,
  rect : @geom.Rect,
  area : Double,
  intrsx : Array[Int?],
) -> Double {
  let op = objs[op_idx]
  let cp = objs[cp_idx]
  let mut idx = get_intrsx_index(op, cp, labels)
  if idx < 0 {
    // Graphviz parity: default to XLNXCY when get_intrsx_index returns -1.
    idx = XLNXCY
  }
  match intrsx[idx] {
    Some(existing_idx) => {
      let mut max_area = 0.0
      let srect = rect_from_object(objs[existing_idx])
      let sa = rect_overlap_area(rect, srect)
      if sa > area {
        max_area = sa
      }
      match objs[existing_idx].label_index {
        Some(label_idx) => {
          let existing_label = labels[label_idx]
          let srect = rect_from_label(existing_label)
          let sa = rect_overlap_area(rect, srect)
          if sa > area && sa > max_area {
            max_area = sa
          }
        }
        None => ()
      }
      if max_area > 0.0 {
        return max_area
      }
      intrsx[idx] = Some(cp_idx)
      area
    }
    None => {
      intrsx[idx] = Some(cp_idx)
      area
    }
  }
}

fn xlintersections(
  objs : Array[XObject],
  labels : Array[XLabel],
  obj_idx : Int,
  intrsx : Array[Int?],
) -> XBestPos {
  let obj = objs[obj_idx]
  let label_idx = match obj.label_index {
    Some(value) => value
    None => return { n: 0, area: 0.0, pos: @edge_spline.point(0.0, 0.0) }
  }
  let label = labels[label_idx]
  let mut count = 0
  let mut area = 0.0
  for i in 0..<objs.length() {
    if i == obj_idx {
      continue
    }
    let other = objs[i]
    if other.width > 0.0 && other.height > 0.0 {
      continue
    }
    if label_encloses_point(label, other) {
      count = count + 1
    }
  }
  let rect = rect_from_label(label)
  for i in 0..<objs.length() {
    if i == obj_idx {
      continue
    }
    let other = objs[i]
    let srect = rect_from_object(other)
    let overlap = rect_overlap_area(rect, srect)
    if overlap > 0.0 {
      let ra =
        record_intersection_slot(objs, labels, obj_idx, i, rect, overlap, intrsx)
      count = count + 1
      area = area + ra
    }
    match other.label_index {
      Some(other_label_idx) => {
        let other_label = labels[other_label_idx]
        if other_label.set {
          let srect = rect_from_label(other_label)
          let overlap = rect_overlap_area(rect, srect)
          if overlap > 0.0 {
            let ra =
              record_intersection_slot(
                objs,
                labels,
                obj_idx,
                i,
                rect,
                overlap,
                intrsx,
              )
            count = count + 1
            area = area + ra
          }
        }
      }
      None => ()
    }
  }
  { n: count, area, pos: label.pos }
}

fn xladjust(
  objs : Array[XObject],
  labels : Array[XLabel],
  obj_idx : Int,
) -> XBestPos {
  let obj = objs[obj_idx]
  let label_idx = match obj.label_index {
    Some(value) => value
    None => return { n: 0, area: 0.0, pos: @edge_spline.point(0.0, 0.0) }
  }
  let label = labels[label_idx]
  let xincr = (2.0 * label.width + obj.width) / XLXDENOM
  let yincr = (2.0 * label.height + obj.height) / XLYDENOM
  let intrsx : Array[Int?] = []
  for _ in 0..<9 {
    intrsx.push(None)
  }
  let set_label = (pos : @geom.Point) => {
    let updated = {
      target: label.target,
      width: label.width,
      height: label.height,
      pos,
      set: label.set,
    }
    labels[label_idx] = updated
  }
  // x left
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y + obj.height))
  let mut best = xlintersections(objs, labels, obj_idx, intrsx)
  if best.n == 0 {
    return best
  }
  // mid
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y))
  let mut candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // x mid
  set_label(@edge_spline.point(obj.pos.x, obj.pos.y + obj.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // x right
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y + obj.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // mid
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // sliding from top left
  if intrsx[XLPXNY] is Some(_) ||
    intrsx[XLCXNY] is Some(_) ||
    intrsx[XLNXNY] is Some(_) ||
    intrsx[XLPXCY] is Some(_) ||
    intrsx[XLPXPY] is Some(_) {
    if intrsx[XLCXNY] is None && intrsx[XLNXNY] is None {
      let mut x = obj.pos.x - label.width
      while x <= obj.pos.x + obj.width {
        set_label(@edge_spline.point(x, obj.pos.y + obj.height))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        x = x + xincr
      }
    }
    if intrsx[XLPXCY] is None && intrsx[XLPXPY] is None {
      let mut y = obj.pos.y + obj.height
      while y >= obj.pos.y - label.height {
        set_label(@edge_spline.point(obj.pos.x - label.width, y))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        y = y - yincr
      }
    }
  }

  // sliding from bottom right
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y - label.height))
  if intrsx[XLNXPY] is Some(_) ||
    intrsx[XLCXPY] is Some(_) ||
    intrsx[XLPXPY] is Some(_) ||
    intrsx[XLNXCY] is Some(_) ||
    intrsx[XLNXNY] is Some(_) {
    if intrsx[XLCXPY] is None && intrsx[XLPXPY] is None {
      let mut x = obj.pos.x + obj.width
      while x >= obj.pos.x - label.width {
        set_label(@edge_spline.point(x, obj.pos.y - label.height))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        x = x - xincr
      }
    }
    if intrsx[XLNXCY] is None && intrsx[XLNXNY] is None {
      let mut y = obj.pos.y - label.height
      while y <= obj.pos.y + obj.height {
        set_label(@edge_spline.point(obj.pos.x + obj.width, y))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        y = y + yincr
      }
    }
  }
  best
}

fn place_labels(
  objs : Array[XObject],
  labels : Array[XLabel],
  force : Bool,
) -> Unit {
  for i in 0..<objs.length() {
    let obj = objs[i]
    let label_idx = match obj.label_index {
      Some(value) => value
      None => continue
    }
    let best = xladjust(objs, labels, i)
    if best.n == 0 {
      let label = labels[label_idx]
      labels[label_idx] = {
        target: label.target,
        width: label.width,
        height: label.height,
        pos: label.pos,
        set: true,
      }
    } else if best.area == 0.0 || force {
      let label = labels[label_idx]
      labels[label_idx] = {
        target: label.target,
        width: label.width,
        height: label.height,
        pos: best.pos,
        set: true,
      }
    }
  }
}
fn scale_point_value(point : @geom.Point, sx : Double, sy : Double) -> @geom.Point {
  { x: point.x * sx, y: point.y * sy }
}

///|
fn scale_point_value_rounded(
  point : @geom.Point,
  sx : Double,
  sy : Double,
) -> @geom.Point {
  let scaled = scale_point_value(point, sx, sy)
  { x: scaled.x.round(), y: scaled.y.round() }
}

///|
fn scale_optional_point_value(
  point : @geom.Point?,
  sx : Double,
  sy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(scale_point_value(value, sx, sy))
    None => None
  }
}

///|
fn scale_spline_value(
  spline : @geom.Spline,
  sx : Double,
  sy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(scale_point_value(point, sx, sy))
  }
  {
    start: scale_optional_point_value(spline.start, sx, sy),
    end: scale_optional_point_value(spline.end, sx, sy),
    points,
  }
}

///|
/// Graphviz parity: label placement aligned to refs/graphviz/lib/common/labels.c (fixtures).
/// Xlabel placement lives in xlabel_layout.mbt (refs/graphviz/lib/label/xlabels.c).
/// Do not change behavior without updating fixtures/tests.
///|
fn graph_label_metrics(graph : @cgraph.Graph) -> GraphLabelMetrics? {
  @dot_shared.graph_label_metrics_with(graph, label_text_dimensions)
}

///|
fn graph_label_pos(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
  just : LabelJust,
) -> @geom.Point {
  let x = match just {
    LabelJust::Left => bbox.llx + label_width_pt / 2.0
    LabelJust::Right => bbox.urx - label_width_pt / 2.0
    LabelJust::Center => (bbox.llx + bbox.urx) / 2.0
  }
  let y = match loc {
    LabelLoc::Top => bbox.ury - label_height_pt / 2.0
    LabelLoc::Bottom => bbox.lly + label_height_pt / 2.0
  }
  { x, y }
}

///|
/// Graphviz parity: flipped cluster label placement aligned to
/// refs/graphviz/lib/common/postproc.c (place_flip_graph_label).
/// Do not change behavior without updating fixtures/tests.
fn graph_label_pos_flip(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
  just : LabelJust,
) -> @geom.Point {
  let x = match loc {
    LabelLoc::Top => bbox.urx - label_width_pt / 2.0
    LabelLoc::Bottom => bbox.llx + label_width_pt / 2.0
  }
  let y = match just {
    LabelJust::Left => bbox.ury - label_height_pt / 2.0
    LabelJust::Right => bbox.lly + label_height_pt / 2.0
    LabelJust::Center => (bbox.lly + bbox.ury) / 2.0
  }
  { x, y }
}

///|
fn rect_from_center(
  center : @geom.Point,
  width : Double,
  height : Double,
  pad : Double,
) -> @geom.Rect {
  let half_w = width / 2.0 + pad
  let half_h = height / 2.0 + pad
  {
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  }
}
///|
/// Cluster subgraph geometry/layout helpers shared by routing and finalization.

///|
priv struct ClusterLabelPlacementInfo {
  width_pt : Double
  height_pt : Double
  loc : LabelLoc
  just : LabelJust
  flipped : Bool
}

///|
fn cluster_label_padding_for_layout(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> @clustering.ClusterLabelPadding {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    return { top: 0.0, bottom: 0.0 }
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let loc = @dot_shared.graph_label_loc(graph)
      let pad = CLUSTER_LABEL_PAD_PT
      match loc {
        LabelLoc::Top => { top: metrics.height_pt + pad, bottom: 0.0 }
        LabelLoc::Bottom => { top: 0.0, bottom: metrics.height_pt + pad }
      }
    }
    None => { top: 0.0, bottom: 0.0 }
  }
}

///|
fn cluster_label_width_with_pad_for_layout(graph : @cgraph.Graph) -> Double? {
  match graph_label_metrics(graph) {
    Some(metrics) => Some(metrics.width_pt + CLUSTER_LABEL_PAD_PT * 2.0)
    None => None
  }
}

///|
/// Graphviz parity: subgraph layout payload keeps cluster/rank snapshots
/// grouped so recursive cluster-bbox wiring remains explicit and stable.
priv struct LayoutSubgraphsInput {
  graph : @cgraph.Graph
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
  rankdir : RankDir
  ranks : Map[String, Int]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
/// Graphviz parity: cluster bbox + label placement aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + lib/common/input.c (cluster label borders) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
fn layout_subgraphs(
  input : LayoutSubgraphsInput,
) -> Array[DotLayoutGraph] {
  let graph = input.graph
  let nodes_out = input.nodes_out
  let edges_out = input.edges_out
  let cluster_ln_x = input.cluster_ln_x
  let cluster_rn_x = input.cluster_rn_x
  let cluster_bbox_heights = input.cluster_bbox_heights
  let rankdir = input.rankdir
  let ranks = input.ranks
  let rank_y = input.rank_y
  let rank_ht1 = input.rank_ht1
  let rank_ht2 = input.rank_ht2
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let result : Array[DotLayoutGraph] = []
  for subgraph in graph.subgraphs() {
    let node_set : Map[String, Bool] = Map::new()
    for node in subgraph.nodes() {
      if @clustering.graph_contains_node(subgraph, node) {
        node_set[node.name()] = true
      }
    }
    let edge_set : Map[String, Bool] = Map::new()
    for edge in subgraph.edges() {
      edge_set[@dot_shared.edge_key(edge)] = true
    }
    let sub_nodes : Array[DotLayoutNode] = []
    for node_layout in nodes_out {
      if node_set.get(node_layout.node.name()) is Some(_) {
        sub_nodes.push(node_layout)
      }
    }
    let sub_edges : Array[DotLayoutEdge] = []
    for edge_layout in edges_out {
      if edge_set.get(@dot_shared.edge_key(edge_layout.edge)) is Some(_) {
        let tail_name = edge_layout.edge.tail().name()
        let head_name = edge_layout.edge.head().name()
        if node_set.get(tail_name) is Some(_) &&
          node_set.get(head_name) is Some(_) {
          sub_edges.push(edge_layout)
        }
      }
    }
    let mut bbox = compute_bbox(sub_nodes, sub_edges)
    let mut label_pos : @geom.Point? = None
    let mut label_info : ClusterLabelPlacementInfo? = None
    let sub_subgraphs =
      layout_subgraphs(
        {
          graph: subgraph,
          nodes_out,
          edges_out,
          cluster_ln_x,
          cluster_rn_x,
          cluster_bbox_heights,
          rankdir,
          ranks,
          rank_y,
          rank_ht1,
          rank_ht2,
        },
      )
    if @dot_shared.is_cluster_graph(subgraph) {
      // Graphviz parity: empty clusters (no descendant nodes) are omitted.
      let cluster_nodes : Map[String, Bool] = Map::new()
      @dot_shared.collect_graph_nodes(subgraph, cluster_nodes)
      if cluster_nodes.length() == 0 {
        continue
      }
    }
    if sub_subgraphs.length() > 0 {
      bbox = expand_bbox_with_subgraphs(bbox, sub_subgraphs)
    }
    if @dot_shared.is_cluster_graph(subgraph) {
      let pad = @positioning.cluster_margin_pt(subgraph)
      let mut pad_left = pad
      let mut pad_right = pad
      let mut pad_y = pad
      let mut use_rank_bbox = false
      // Graphviz parity: cluster y bounds come from rank positions (dot_compute_bb).
      let mut min_rank : Int? = None
      let mut max_rank : Int? = None
      let cluster_nodes : Map[String, Bool] = Map::new()
      @dot_shared.collect_graph_nodes(subgraph, cluster_nodes)
      for name, _ in cluster_nodes {
        match ranks.get(name) {
          Some(rank) => {
            match min_rank {
              Some(value) => if rank < value { min_rank = Some(rank) }
              None => min_rank = Some(rank)
            }
            match max_rank {
              Some(value) => if rank > value { max_rank = Some(rank) }
              None => max_rank = Some(rank)
            }
          }
          None => ()
        }
      }
      match (min_rank, max_rank) {
        (Some(min_rank_value), Some(max_rank_value)) => {
          let max_rank_y = match rank_y.get(max_rank_value) {
            Some(value) => value
            None => bbox.lly
          }
          let min_rank_y = match rank_y.get(min_rank_value) {
            Some(value) => value
            None => bbox.ury
          }
          let mut ht1 = match rank_ht1.get(max_rank_value) {
            Some(value) => value
            None => 0.0
          }
          let mut ht2 = match rank_ht2.get(min_rank_value) {
            Some(value) => value
            None => 0.0
          }
          match subgraph.name() {
            Some(cluster_name) =>
              match cluster_bbox_heights.get(cluster_name) {
                Some(value) => {
                  ht1 = value.ht1
                  ht2 = value.ht2
                }
                None => ()
              }
            None => ()
          }
          bbox =
            { llx: bbox.llx, lly: max_rank_y - ht1, urx: bbox.urx, ury: min_rank_y + ht2 }
          pad_y = 0.0
          use_rank_bbox = true
        }
        _ => ()
      }
      // Graphviz parity: cluster x bounds come from ln/rn positions (dot_compute_bb).
      match subgraph.name() {
        Some(cluster_name) => {
          match cluster_ln_x.get(cluster_name) {
            Some(value) => {
              bbox = { llx: value, lly: bbox.lly, urx: bbox.urx, ury: bbox.ury }
              pad_left = 0.0
            }
            None => ()
          }
          match cluster_rn_x.get(cluster_name) {
            Some(value) => {
              bbox = { llx: bbox.llx, lly: bbox.lly, urx: value, ury: bbox.ury }
              pad_right = 0.0
            }
            None => ()
          }
        }
        None => ()
      }
      let llx = bbox.llx - pad_left
      let lly = bbox.lly - pad_y
      let urx = bbox.urx + pad_right
      let ury = bbox.ury + pad_y
      bbox = { llx, lly, urx, ury }
      match graph_label_metrics(subgraph) {
        Some(metrics) => {
          let loc = @dot_shared.graph_label_loc(subgraph)
          let just = @dot_shared.graph_label_just(subgraph)
          let pad = CLUSTER_LABEL_PAD_PT
          let padded_width = metrics.width_pt + pad * 2.0
          let padded_height = metrics.height_pt + pad
          if flip {
            let border_x = padded_height
            let border_y = padded_width
            let mut llx = bbox.llx
            let mut urx = bbox.urx
            let mut lly = bbox.lly
            let mut ury = bbox.ury
            if !use_rank_bbox {
              match loc {
                LabelLoc::Top => urx = urx + border_x
                LabelLoc::Bottom => llx = llx - border_x
              }
            }
            let span = ury - lly
            if border_y > span {
              let diff = (border_y - span) / 2.0
              lly = lly - diff
              ury = ury + diff
            }
            bbox = { llx, lly, urx, ury }
            label_info = Some({
              width_pt: border_x,
              height_pt: border_y,
              loc,
              just,
              flipped: true,
            })
          } else {
            if !use_rank_bbox {
              bbox =
                expand_bbox_for_label(
                  bbox,
                  metrics.width_pt,
                  metrics.height_pt,
                  loc,
                )
            }
            label_info = Some({
              width_pt: padded_width,
              height_pt: padded_height,
              loc,
              just,
              flipped: false,
            })
          }
        }
        None => ()
      }
      bbox = round_bbox(bbox)
    }
    match label_info {
      Some(value) =>
        label_pos =
          Some(
            if value.flipped {
              graph_label_pos_flip(
                bbox,
                value.width_pt,
                value.height_pt,
                value.loc,
                value.just,
              )
            } else {
              graph_label_pos(
                bbox,
                value.width_pt,
                value.height_pt,
                value.loc,
                value.just,
              )
            },
          )
      None => ()
    }
    result.push({
      graph: subgraph,
      bbox,
      label_pos,
      nodes: sub_nodes,
      edges: sub_edges,
      subgraphs: sub_subgraphs,
    })
  }
  result
}
///|
/// Layout bbox aggregation/expansion helpers plus rank-based dot bbox helpers.

priv struct BBoxAccumulator {
  set : Bool
  min_x : Double
  max_x : Double
  min_y : Double
  max_y : Double
}

fn bbox_is_zero_sentinel(bbox : @geom.Rect) -> Bool {
  bbox.llx == 0.0 && bbox.lly == 0.0 && bbox.urx == 0.0 && bbox.ury == 0.0
}

fn bbox_acc_empty() -> BBoxAccumulator {
  { set: false, min_x: 0.0, max_x: 0.0, min_y: 0.0, max_y: 0.0 }
}

fn bbox_acc_from_bbox(bbox : @geom.Rect) -> BBoxAccumulator {
  if bbox_is_zero_sentinel(bbox) {
    bbox_acc_empty()
  } else {
    {
      set: true,
      min_x: bbox.llx,
      max_x: bbox.urx,
      min_y: bbox.lly,
      max_y: bbox.ury,
    }
  }
}

fn bbox_acc_include_point(
  acc : BBoxAccumulator,
  p : @geom.Point,
) -> BBoxAccumulator {
  if !acc.set {
    {
      set: true,
      min_x: p.x,
      max_x: p.x,
      min_y: p.y,
      max_y: p.y,
    }
  } else {
    {
      set: true,
      min_x: if p.x < acc.min_x { p.x } else { acc.min_x },
      max_x: if p.x > acc.max_x { p.x } else { acc.max_x },
      min_y: if p.y < acc.min_y { p.y } else { acc.min_y },
      max_y: if p.y > acc.max_y { p.y } else { acc.max_y },
    }
  }
}

fn bbox_acc_to_rect(acc : BBoxAccumulator) -> @geom.Rect {
  if acc.set {
    { llx: acc.min_x, lly: acc.min_y, urx: acc.max_x, ury: acc.max_y }
  } else {
    { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
}

///|
/// Graphviz parity: bbox aggregation aligned to refs/graphviz/lib/common/utils.c (compute_bb),
/// with label/cluster expansion handled in f_postprocess helpers.
/// Do not change behavior without updating fixtures/tests.
fn compute_bbox(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut acc = bbox_acc_empty()
  for node in nodes {
    let half_w = node.width_in * 72.0 / 2.0
    let half_h = node.height_in * 72.0 / 2.0
    let left = node.pos.x - half_w
    let right = node.pos.x + half_w
    let bottom = node.pos.y - half_h
    let top = node.pos.y + half_h
    acc = bbox_acc_include_point(acc, { x: left, y: bottom })
    acc = bbox_acc_include_point(acc, { x: right, y: top })
  }
  for edge in edges {
    for spline in edge.splines {
      let update = (p : @geom.Point) => {
        acc = bbox_acc_include_point(acc, p)
      }
      match spline.start {
        Some(point) => update(point)
        None => ()
      }
      match spline.end {
        Some(point) => update(point)
        None => ()
      }
      match spline_bbox(spline.points) {
        Some(rect) => {
          update({ x: rect.llx, y: rect.lly })
          update({ x: rect.urx, y: rect.ury })
        }
        None => ()
      }
    }
  }
  bbox_acc_to_rect(acc)
}

///|
/// Graphviz parity: edge splines expand bbox like refs/graphviz/lib/dotgen/dotsplines.c
/// (update_bb_bz) after dot_compute_bb.
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_with_edges(
  bbox : @geom.Rect,
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut acc = bbox_acc_from_bbox(bbox)
  let update = (p : @geom.Point) => {
    acc = bbox_acc_include_point(acc, p)
  }
  for edge in edges {
    for spline in edge.splines {
      match spline.start {
        Some(point) => update(point)
        None => ()
      }
      match spline.end {
        Some(point) => update(point)
        None => ()
      }
      match spline_bbox(spline.points) {
        Some(rect) => {
          update({ x: rect.llx, y: rect.lly })
          update({ x: rect.urx, y: rect.ury })
        }
        None => ()
      }
    }
  }
  bbox_acc_to_rect(acc)
}

///|
fn merge_bbox(base : @geom.Rect, other : @geom.Rect) -> @geom.Rect {
  {
    llx: if base.llx < other.llx {
      base.llx
    } else {
      other.llx
    },
    lly: if base.lly < other.lly {
      base.lly
    } else {
      other.lly
    },
    urx: if base.urx > other.urx {
      base.urx
    } else {
      other.urx
    },
    ury: if base.ury > other.ury {
      base.ury
    } else {
      other.ury
    },
  }
}

///|
fn round_bbox(bbox : @geom.Rect) -> @geom.Rect {
  {
    llx: bbox.llx.round(),
    lly: bbox.lly,
    urx: bbox.urx.round(),
    ury: bbox.ury,
  }
}

///|
fn expand_bbox_with_subgraphs(
  bbox : @geom.Rect,
  subgraphs : Array[DotLayoutGraph],
) -> @geom.Rect {
  let mut result = bbox
  for subgraph in subgraphs {
    result = merge_bbox(result, subgraph.bbox)
    if subgraph.subgraphs.length() > 0 {
      result = expand_bbox_with_subgraphs(result, subgraph.subgraphs)
    }
  }
  result
}

///|
/// Graphviz parity: root bbox only expands to include cluster subgraphs
/// (dot_compute_bb uses GD_clust list, not generic subgraphs).
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_with_clusters(
  bbox : @geom.Rect,
  subgraphs : Array[DotLayoutGraph],
) -> @geom.Rect {
  let mut result = bbox
  for subgraph in subgraphs {
    if @dot_shared.is_cluster_graph(subgraph.graph) {
      // Graphviz parity: dot_compute_bb expands root bbox by CL_OFFSET for
      // cluster subgraphs in x direction.
      let padded : @geom.Rect = {
        llx: subgraph.bbox.llx - CLUSTER_MARGIN_PT,
        lly: subgraph.bbox.lly,
        urx: subgraph.bbox.urx + CLUSTER_MARGIN_PT,
        ury: subgraph.bbox.ury,
      }
      result = merge_bbox(result, padded)
    }
    if subgraph.subgraphs.length() > 0 {
      result = expand_bbox_with_clusters(result, subgraph.subgraphs)
    }
  }
  result
}

///|
/// Spline bounding-box helpers used by layout bbox aggregation.

///|
/// Graphviz parity: spline bbox uses update_bb_bz refinement aligned to
/// refs/graphviz/lib/common/emit.c (update_bb_bz).
/// Do not change behavior without updating fixtures/tests.
fn spline_bbox(points : Array[@geom.Point]) -> @geom.Rect? {
  if points.length() == 0 {
    return None
  }
  if points.length() % 3 != 1 {
    let mut min_x = points[0].x
    let mut max_x = points[0].x
    let mut min_y = points[0].y
    let mut max_y = points[0].y
    for p in points {
      if p.x < min_x { min_x = p.x }
      if p.x > max_x { max_x = p.x }
      if p.y < min_y { min_y = p.y }
      if p.y > max_y { max_y = p.y }
    }
    return Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
  }
  let mut bbox : @geom.Rect = {
    llx: points[0].x,
    lly: points[0].y,
    urx: points[0].x,
    ury: points[0].y,
  }
  let mut i = 0
  while i + 3 < points.length() {
    let p0 = points[i]
    let p1 = points[i + 1]
    let p2 = points[i + 2]
    let p3 = points[i + 3]
    bbox = update_bbox_with_bezier(bbox, p0, p1, p2, p3)
    i = i + 3
  }
  Some(bbox)
}

fn expand_bbox_with_point(bbox : @geom.Rect, p : @geom.Point) -> @geom.Rect {
  {
    llx: if p.x < bbox.llx { p.x } else { bbox.llx },
    lly: if p.y < bbox.lly { p.y } else { bbox.lly },
    urx: if p.x > bbox.urx { p.x } else { bbox.urx },
    ury: if p.y > bbox.ury { p.y } else { bbox.ury },
  }
}

fn pt_to_line2(a : @geom.Point, b : @geom.Point, p : @geom.Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let a2 = (p.y - a.y) * dx - (p.x - a.x) * dy
  let a2_sq = a2 * a2
  if a2_sq < 0.0000000001 {
    0.0
  } else {
    let denom = dx * dx + dy * dy
    if denom == 0.0 { 0.0 } else { a2_sq / denom }
  }
}

fn bezier_controls_near_line(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> Bool {
  let hw = 2.0
  let dis1 = pt_to_line2(p0, p3, p1)
  let dis2 = pt_to_line2(p0, p3, p2)
  dis1 < hw * hw && dis2 < hw * hw
}

priv struct CubicBezierSegment {
  p0 : @geom.Point
  p1 : @geom.Point
  p2 : @geom.Point
  p3 : @geom.Point
}

priv struct SplitBezierHalf {
  left : CubicBezierSegment
  right : CubicBezierSegment
}

fn split_bezier_half(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> SplitBezierHalf {
  let p01 = @edge_spline.point((p0.x + p1.x) / 2.0, (p0.y + p1.y) / 2.0)
  let p12 = @edge_spline.point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
  let p23 = @edge_spline.point((p2.x + p3.x) / 2.0, (p2.y + p3.y) / 2.0)
  let p012 = @edge_spline.point((p01.x + p12.x) / 2.0, (p01.y + p12.y) / 2.0)
  let p123 = @edge_spline.point((p12.x + p23.x) / 2.0, (p12.y + p23.y) / 2.0)
  let p0123 = @edge_spline.point((p012.x + p123.x) / 2.0, (p012.y + p123.y) / 2.0)
  {
    left: { p0, p1: p01, p2: p012, p3: p0123 },
    right: { p0: p0123, p1: p123, p2: p23, p3 },
  }
}

fn update_bbox_with_bezier(
  bbox : @geom.Rect,
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> @geom.Rect {
  let mut out = bbox
  if p0.x > out.urx || p0.x < out.llx || p0.y > out.ury || p0.y < out.lly ||
    p1.x > out.urx || p1.x < out.llx || p1.y > out.ury || p1.y < out.lly ||
    p2.x > out.urx || p2.x < out.llx || p2.y > out.ury || p2.y < out.lly ||
    p3.x > out.urx || p3.x < out.llx || p3.y > out.ury || p3.y < out.lly {
    if bezier_controls_near_line(p0, p1, p2, p3) {
      out = expand_bbox_with_point(out, p0)
      out = expand_bbox_with_point(out, p1)
      out = expand_bbox_with_point(out, p2)
      out = expand_bbox_with_point(out, p3)
    } else {
      let split = split_bezier_half(p0, p1, p2, p3)
      let left =
        update_bbox_with_bezier(
          out,
          split.left.p0,
          split.left.p1,
          split.left.p2,
          split.left.p3,
        )
      out =
        update_bbox_with_bezier(
          left,
          split.right.p0,
          split.right.p1,
          split.right.p2,
          split.right.p3,
        )
    }
  }
  out
}

///|
/// Rank-based bbox helper shared by routing precompute and final geometry.

///|
/// Graphviz parity: rank-based bbox input keeps node/rank geometry snapshots
/// grouped for deterministic dot_compute_bb bounds reconstruction.
priv struct DotBBoxInput {
  nodes_out : Array[DotLayoutNode]
  all_ranks : Array[Int]
  sizes : Map[String, NodeSize]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
/// Graphviz parity: rank-based bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_bbox(
  input : DotBBoxInput,
) -> @geom.Rect {
  if input.nodes_out.length() == 0 {
    return { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut first = true
  for node_layout in input.nodes_out {
    let name = node_layout.node.name()
    let left = @dot_shared.node_left_pt(name, input.sizes)
    let right = @dot_shared.node_right_pt(name, input.sizes)
    let llx = node_layout.pos.x - left
    let urx = node_layout.pos.x + right
    if first {
      min_x = llx
      max_x = urx
      first = false
    } else {
      if llx < min_x { min_x = llx }
      if urx > max_x { max_x = urx }
    }
  }
  let mut min_y = 0.0
  let mut max_y = 0.0
  if input.all_ranks.length() > 0 {
    let min_rank = input.all_ranks[0]
    let max_rank = input.all_ranks[input.all_ranks.length() - 1]
    let max_rank_y = match input.rank_y.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    let min_rank_y = match input.rank_y.get(min_rank) {
      Some(value) => value
      None => 0.0
    }
    let ht1 = match input.rank_ht1.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    let ht2 = match input.rank_ht2.get(min_rank) {
      Some(value) => value
      None => 0.0
    }
    min_y = max_rank_y - ht1
    max_y = min_rank_y + ht2
  }
  { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
}
///|
fn pow10_int(exp : Int) -> Int {
  if exp <= 0 {
    return 1
  }
  let mut result = 1
  for _ in 0..<exp {
    result = result * 10
  }
  result
}

///|
fn pow10_double(exp : Int) -> Double {
  @math.pow(10.0, exp.to_double())
}

///|
fn trim_trailing_zeros(text : String) -> String {
  if !text.contains(".") {
    return text
  }
  let mut result = text
  while result.length() > 0 && result.has_suffix("0") {
    let next_len = result.length() - 1
    result = result.unsafe_substring(start=0, end=next_len)
  }
  if result.has_suffix(".") {
    let next_len = result.length() - 1
    result = result.unsafe_substring(start=0, end=next_len)
  }
  result
}

///|
fn round_half_even(value : Double, decimals : Int) -> Double {
  if decimals <= 0 {
    let floored = value.floor()
    let frac = value - floored
    let eps = 0.000000000001
    if frac < 0.5 - eps {
      return floored
    }
    if frac > 0.5 + eps {
      return floored + 1.0
    }
    let int_floor = floored.to_int()
    if int_floor % 2 == 0 {
      return floored
    } else {
      return floored + 1.0
    }
  }
  let scale = pow10_double(decimals)
  let scaled = value * scale
  let floored = scaled.floor()
  let frac = scaled - floored
  let eps = 0.000000000001
  let rounded = if frac < 0.5 - eps {
    floored
  } else if frac > 0.5 + eps {
    floored + 1.0
  } else {
    let int_floor = floored.to_int()
    if int_floor % 2 == 0 {
      floored
    } else {
      floored + 1.0
    }
  }
  rounded / scale
}

///|
fn format_fixed(value : Double, decimals : Int) -> String {
  if decimals <= 0 {
    return "\{round_half_even(value, 0).to_int()}"
  }
  let scale = pow10_int(decimals)
  let scaled = round_half_even(value * scale.to_double(), 0).to_int()
  let int_part = scaled / scale
  let mut frac = scaled % scale
  if frac < 0 {
    frac = -frac
  }
  let mut frac_str = frac.to_string()
  while frac_str.length() < decimals {
    frac_str = "0\{frac_str}"
  }
  "\{int_part}.\{frac_str}"
}

///|
fn format_fixed_trim(value : Double, decimals : Int) -> String {
  trim_trailing_zeros(format_fixed(value, decimals))
}

///|
fn round_to(value : Double, decimals : Int) -> Double {
  round_half_even(value, decimals)
}

///|
fn format_scientific(abs : Double, exp : Int, precision : Int, sign : String) -> String {
  let mut exp_mut = exp
  let mantissa = abs / pow10_double(exp_mut)
  let decimals = precision - 1
  let mut rounded = round_to(mantissa, decimals)
  if rounded >= 10.0 {
    rounded = rounded / 10.0
    exp_mut = exp_mut + 1
  }
  let mantissa_str = format_fixed_trim(rounded, decimals)
  let exp_sign = if exp_mut < 0 {
    "-"
  } else {
    "+"
  }
  let exp_abs = if exp_mut < 0 {
    -exp_mut
  } else {
    exp_mut
  }
  let exp_str =
    if exp_abs < 10 {
    "0\{exp_abs}"
  } else {
    "\{exp_abs}"
  }
  "\{sign}\{mantissa_str}e\{exp_sign}\{exp_str}"
}

///|
fn format_float(value : Double) -> String {
  if value == 0.0 {
    return "0"
  }
  let sign = if value < 0.0 {
    "-"
  } else {
    ""
  }
  let abs = if value < 0.0 {
    -value
  } else {
    value
  }
  let precision = 5
  let exp = @math.log10(abs).floor().to_int()
  if exp < -4 || exp >= precision {
    return format_scientific(abs, exp, precision, sign)
  }
  let decimals = precision - exp - 1
  let rounded = round_to(abs, decimals)
  if rounded != 0.0 {
    let new_exp = @math.log10(rounded).floor().to_int()
    if new_exp >= precision {
      return format_scientific(rounded, new_exp, precision, sign)
    }
  }
  "\{sign}\{format_fixed_trim(rounded, decimals)}"
}

///|
fn format_dim(value : Double) -> String {
  format_float(value)
}

///|
fn format_point(point : @geom.Point) -> String {
  "\{format_float(point.x)},\{format_float(point.y)}"
}

///|
fn format_rect(rect : @geom.Rect) -> String {
  "\{format_float(rect.llx)},\{format_float(rect.lly)},\{format_float(rect.urx)},\{format_float(rect.ury)}"
}

///|
fn format_rects(rects : Array[@geom.Rect]) -> String {
  let parts : Array[String] = []
  for rect in rects {
    parts.push(format_rect(rect))
  }
  parts.join(" ")
}
