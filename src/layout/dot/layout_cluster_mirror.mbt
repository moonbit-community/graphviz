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
              graph_label_loc(layout.graph),
              graph_label_just(layout.graph),
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
/// Graphviz parity: clustered LR/RL layouts are mirrored back after rankdir
/// rotation (dotgen cluster decompose + postproc map_point ordering).
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_lr_mirror_after_rotation(
  graph : @cgraph.Graph,
  rankdir : RankDir,
  rotated : DotLayoutGraph,
  pre_rotation_bbox : @geom.Rect,
  rank_bbox : @geom.Rect,
  subgraph_base_bbox : @geom.Rect,
) -> DotLayoutGraph {
  let use_cluster_point_mirror =
    subgraph_base_bbox.urx > rank_bbox.urx &&
    (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(graph)
  let use_lr_multi_cluster_creation_order_mode =
    (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    count_cluster_subgraphs(graph) > 1
  if (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(graph) &&
    !use_lr_multi_cluster_creation_order_mode {
    if use_cluster_point_mirror {
      let cluster_mirror_bbox =
        transform_bbox_with_root(rank_bbox, pre_rotation_bbox, rankdir)
      refresh_cluster_labels(
        mirror_layout_points(
          rotated,
          cluster_mirror_bbox,
          rotated.bbox,
        ),
      )
    } else {
      rotate_layout_graph(rotated, rotated.bbox, RankDir::BT)
    }
  } else {
    rotated
  }
}
