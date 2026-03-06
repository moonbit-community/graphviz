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
          let pad = @clustering.CLUSTER_LABEL_PAD_PT
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
                @dot_shared.expand_bbox_for_label(
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
              @dot_shared.graph_label_pos_flip(
                bbox,
                value.width_pt,
                value.height_pt,
                value.loc,
                value.just,
              )
            } else {
              @dot_shared.graph_label_pos(
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
