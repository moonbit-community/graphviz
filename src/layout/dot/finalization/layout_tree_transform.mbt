///|
/// Cluster-oriented mirror/label refresh helpers on internal layout trees used
/// by final postprocess.


///|
fn count_cluster_subgraphs(graph : @cgraph.Graph) -> Int {
  let mut count = 0
  for subgraph in graph.subgraphs() {
    if @shared.is_cluster_graph(subgraph) {
      count = count + 1
    }
    count = count + count_cluster_subgraphs(subgraph)
  }
  count
}

///|
fn mirror_layout_points(
  layout : LayoutTree,
  point_bbox : @geom.Rect,
  bbox_bbox : @geom.Rect,
) -> LayoutTree {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    nodes.push({
      node: node_layout.node,
      pos: @coordinate_transform.transform_point(node_layout.pos, point_bbox, RankDir::BT),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: @coordinate_transform.transform_optional_point(
        node_layout.label_pos,
        point_bbox,
        RankDir::BT,
      ),
      xlabel_pos: @coordinate_transform.transform_optional_point(
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
      splines.push(@coordinate_transform.transform_spline(spline, point_bbox, RankDir::BT))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: @coordinate_transform.transform_optional_point(
        edge_layout.label_pos,
        point_bbox,
        RankDir::BT,
      ),
      head_label_pos: @coordinate_transform.transform_optional_point(
        edge_layout.head_label_pos,
        point_bbox,
        RankDir::BT,
      ),
      tail_label_pos: @coordinate_transform.transform_optional_point(
        edge_layout.tail_label_pos,
        point_bbox,
        RankDir::BT,
      ),
      xlabel_pos: @coordinate_transform.transform_optional_point(
        edge_layout.xlabel_pos,
        point_bbox,
        RankDir::BT,
      ),
    })
  }
  let subgraphs : Array[LayoutTree] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(
      mirror_layout_points(subgraph, point_bbox, bbox_bbox),
    )
  }
  let mirrored_bbox =
    @coordinate_transform.transform_bbox_with_root(layout.bbox, bbox_bbox, RankDir::BT)
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
  layout : LayoutTree,
) -> LayoutTree {
  let subgraphs : Array[LayoutTree] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(refresh_cluster_labels(subgraph))
  }
  let label_pos =
    if @shared.is_cluster_graph(layout.graph) {
      match @label_metrics.graph_label_metrics(layout.graph) {
        Some(metrics) => {
          let pad = @clustering.CLUSTER_LABEL_PAD_PT
          Some(
            @shared.graph_label_pos(
              layout.bbox,
              metrics.width_pt + pad * 2.0,
              metrics.height_pt + pad,
              @shared.graph_label_loc(layout.graph),
              @shared.graph_label_just(layout.graph),
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
pub(all) struct ClusterLRMirrorInput {
  graph : @cgraph.Graph
  rankdir : RankDir
  rotated : LayoutTree
  pre_rotation_bbox : @geom.Rect
  rank_bbox : @geom.Rect
  subgraph_base_bbox : @geom.Rect
}

///|
/// Graphviz parity: clustered LR/RL layouts are mirrored back after rankdir
/// rotation (dotgen cluster decompose + postproc map_point ordering).
/// Do not change behavior without updating fixtures/tests.
pub fn apply_cluster_lr_mirror_after_rotation(
  input : ClusterLRMirrorInput,
) -> LayoutTree {
  let use_cluster_point_mirror =
    input.subgraph_base_bbox.urx > input.rank_bbox.urx &&
    (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
    @shared.graph_has_cluster(input.graph)
  let use_lr_multi_cluster_creation_order_mode =
    (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
    count_cluster_subgraphs(input.graph) > 1
  if (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
    @shared.graph_has_cluster(input.graph) &&
    !use_lr_multi_cluster_creation_order_mode {
    if use_cluster_point_mirror {
      let cluster_mirror_bbox =
        @coordinate_transform.transform_bbox_with_root(input.rank_bbox, input.pre_rotation_bbox, input.rankdir)
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
/// Graphviz parity: layout translation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
pub fn shift_layout_graph(
  layout : LayoutTree,
  dx : Double,
  dy : Double,
) -> LayoutTree {
  let shifted_nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    shifted_nodes.push({
      node: node_layout.node,
      pos: @coordinate_transform.shift_point(node_layout.pos, dx, dy),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: @coordinate_transform.shift_optional_point(node_layout.label_pos, dx, dy),
      xlabel_pos: @coordinate_transform.shift_optional_point(node_layout.xlabel_pos, dx, dy),
    })
  }
  let shifted_edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(@coordinate_transform.shift_spline(spline, dx, dy))
    }
    shifted_edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: @coordinate_transform.shift_optional_point(edge_layout.label_pos, dx, dy),
      head_label_pos: @coordinate_transform.shift_optional_point(edge_layout.head_label_pos, dx, dy),
      tail_label_pos: @coordinate_transform.shift_optional_point(edge_layout.tail_label_pos, dx, dy),
      xlabel_pos: @coordinate_transform.shift_optional_point(edge_layout.xlabel_pos, dx, dy),
    })
  }
  let shifted_subgraphs : Array[LayoutTree] = []
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
    label_pos: @coordinate_transform.shift_optional_point(layout.label_pos, dx, dy),
    nodes: shifted_nodes,
    edges: shifted_edges,
    subgraphs: shifted_subgraphs,
  }
}

///|
/// Graphviz parity: rankdir rotation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/map_point).
/// Do not change behavior without updating fixtures/tests.
pub fn rotate_layout_graph(
  layout : LayoutTree,
  root_bbox : @geom.Rect,
  rankdir : RankDir,
) -> LayoutTree {
  if rankdir == RankDir::TB {
    return layout
  }
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    nodes.push({
      node: node_layout.node,
      pos: @coordinate_transform.transform_point(node_layout.pos, root_bbox, rankdir),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: @coordinate_transform.transform_optional_point(
        node_layout.label_pos,
        root_bbox,
        rankdir,
      ),
      xlabel_pos: @coordinate_transform.transform_optional_point(
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
      splines.push(@coordinate_transform.transform_spline(spline, root_bbox, rankdir))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: @coordinate_transform.transform_optional_point(
        edge_layout.label_pos,
        root_bbox,
        rankdir,
      ),
      head_label_pos: @coordinate_transform.transform_optional_point(
        edge_layout.head_label_pos,
        root_bbox,
        rankdir,
      ),
      tail_label_pos: @coordinate_transform.transform_optional_point(
        edge_layout.tail_label_pos,
        root_bbox,
        rankdir,
      ),
      xlabel_pos: @coordinate_transform.transform_optional_point(
        edge_layout.xlabel_pos,
        root_bbox,
        rankdir,
      ),
    })
  }
  let subgraphs : Array[LayoutTree] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(rotate_layout_graph(subgraph, root_bbox, rankdir))
  }
  {
    graph: layout.graph,
    bbox: @coordinate_transform.transform_bbox_with_root(layout.bbox, root_bbox, rankdir),
    label_pos: @coordinate_transform.transform_optional_point(layout.label_pos, root_bbox, rankdir),
    nodes,
    edges,
    subgraphs,
  }
}

///|
/// Final-layout ratio=fill scaling and root-coordinate frame helpers used by
/// postprocess.

///|
fn scale_layout_tree(
  layout : LayoutTree,
  sx : Double,
  sy : Double,
  round_node_pos : Bool,
) -> LayoutTree {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let scaled_pos =
      if round_node_pos {
        @shared.scale_point_rounded(node_layout.pos, sx, sy)
      } else {
        @shared.scale_point(node_layout.pos, sx, sy)
      }
    nodes.push({
      node: node_layout.node,
      pos: scaled_pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: @shared.scale_optional_point(node_layout.label_pos, sx, sy),
      xlabel_pos: @shared.scale_optional_point(node_layout.xlabel_pos, sx, sy),
    })
  }
  let subgraphs : Array[LayoutTree] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(scale_layout_tree(subgraph, sx, sy, round_node_pos))
  }
  {
    graph: layout.graph,
    bbox: {
      llx: layout.bbox.llx * sx,
      lly: layout.bbox.lly * sy,
      urx: layout.bbox.urx * sx,
      ury: layout.bbox.ury * sy,
    },
    label_pos: @shared.scale_optional_point(layout.label_pos, sx, sy),
    nodes,
    edges: @routing.scale_edge_layout_output(layout.edges, sx, sy),
    subgraphs,
  }
}

///|
/// Graphviz parity: root-cluster padding input keeps the pre-padding layout and
/// top/bottom pad deltas grouped for one shift + bbox rebuild boundary.
pub(all) struct RootClusterPaddingApplyInput {
  layout : LayoutTree
  root_cluster_pad_top : Double
  root_cluster_pad_bottom : Double
}

///|
/// Graphviz parity: translate to origin aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn shift_layout_to_origin(layout : LayoutTree) -> LayoutTree {
  if layout.graph.is_root() {
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
fn refresh_root_label_position(
  layout : LayoutTree,
) -> LayoutTree {
  if layout.graph.is_root() {
    let label_pos =
      match @root_geometry.root_label_pos_for_bbox(layout.graph, layout.bbox) {
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
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
pub fn apply_root_cluster_padding(
  input : RootClusterPaddingApplyInput,
) -> LayoutTree {
  let layout = input.layout
  if layout.graph.is_root() &&
    (input.root_cluster_pad_top > 0.0 || input.root_cluster_pad_bottom > 0.0) {
    let padded =
      shift_layout_graph(layout, 0.0, input.root_cluster_pad_bottom)
    let padded_bbox : @geom.Rect = {
      llx: layout.bbox.llx,
      lly: layout.bbox.lly,
      urx: layout.bbox.urx,
      ury:
        layout.bbox.ury + input.root_cluster_pad_bottom +
        input.root_cluster_pad_top,
    }
    let label_pos =
      match @root_geometry.root_label_pos_for_bbox(layout.graph, padded_bbox) {
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
    layout
  }
}

///|
/// Graphviz parity: root ratio=fill scaling aligned to refs/graphviz/lib/dotgen/position.c
/// (set_aspect R_FILL branch + ND_coord rounding).
pub fn apply_ratio_fill_scale(
  layout : LayoutTree,
  rankdir : RankDir,
  ratio_bbox : @geom.Rect,
) -> LayoutTree {
  if !layout.graph.is_root() {
    return layout
  }
  match @shared.ratio_fill_scale_factors(layout.graph, ratio_bbox, rankdir) {
    Some(scale_factors) => {
      if scale_factors.sx == 1.0 && scale_factors.sy == 1.0 {
        layout
      } else {
        // Graphviz parity: set_aspect rounds ND_coord after scaling.
        scale_layout_tree(layout, scale_factors.sx, scale_factors.sy, true)
      }
    }
    None => layout
  }
}

///|
/// Graphviz parity: final root-coordinate frame applies margin, then origin
/// translation, then root label refresh.
/// Do not change behavior without updating fixtures/tests.
pub fn finalize_root_coordinates(layout : LayoutTree) -> LayoutTree {
  let with_margin : LayoutTree = {
    graph: layout.graph,
    bbox: @root_geometry.apply_root_margin_x(layout.graph, layout.bbox),
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs: layout.subgraphs,
  }
  refresh_root_label_position(
    shift_layout_to_origin(with_margin),
  )
}
