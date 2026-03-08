///|
/// Cluster route-bbox extraction helpers built on top of recursive cluster
/// layout so routing can reuse final cluster bounds without duplicating tree
/// traversal.

///|
fn collect_cluster_route_bboxes(
  subgraphs : Array[LayoutTree],
  out : Map[String, @geom.Rect],
) -> Unit {
  for layout in subgraphs {
    if @cluster_graph.is_cluster_graph(layout.graph) {
      match layout.graph.name() {
        Some(name) => out[name] = layout.bbox
        None => ()
      }
    }
    if layout.subgraphs.length() > 0 {
      collect_cluster_route_bboxes(layout.subgraphs, out)
    }
  }
}

///|
/// Graphviz parity: cluster routing bboxes aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_cluster_route_bboxes(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair],
  rankdir : RankDir,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Map[String, @geom.Rect] {
  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  if @cluster_graph.graph_has_cluster(graph) {
    let cluster_layouts =
      layout_subgraphs(
        {
          graph,
          nodes_out,
          edges_out: [],
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
    collect_cluster_route_bboxes(cluster_layouts, cluster_bboxes)
  }
  cluster_bboxes
}
