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
  let subgraphs : Array[DotLayoutGraph] = []
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
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(refresh_cluster_labels(subgraph))
  }
  let label_pos =
    if @dot_shared.is_cluster_graph(layout.graph) {
      match @label_metrics.graph_label_metrics(layout.graph) {
        Some(metrics) => {
          let pad = @clustering.CLUSTER_LABEL_PAD_PT
          Some(
            @dot_shared.graph_label_pos(
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
fn shift_layout_graph(
  layout : DotLayoutGraph,
  dx : Double,
  dy : Double,
) -> DotLayoutGraph {
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
  let subgraphs : Array[DotLayoutGraph] = []
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
