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
        @dot_shared.scale_point_rounded(node_layout.pos, sx, sy)
      } else {
        @dot_shared.scale_point(node_layout.pos, sx, sy)
      }
    nodes.push({
      node: node_layout.node,
      pos: scaled_pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: @dot_shared.scale_optional_point(node_layout.label_pos, sx, sy),
      xlabel_pos: @dot_shared.scale_optional_point(node_layout.xlabel_pos, sx, sy),
    })
  }
  let edges = @routing.scale_edge_layout_output(layout.edges, sx, sy)
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
    label_pos: @dot_shared.scale_optional_point(layout.label_pos, sx, sy),
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
        @dot_shared.graph_label_pos(
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
        @dot_shared.graph_label_pos(
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
