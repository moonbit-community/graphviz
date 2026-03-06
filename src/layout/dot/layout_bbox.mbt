///|
/// Root-only bbox recursion helpers that still depend on DotLayoutGraph trees;
/// pure bbox kernels live in the bbox subpackage.

const CLUSTER_MARGIN_PT : Double = 8.0

///|
fn expand_bbox_with_subgraphs(
  bbox : @geom.Rect,
  subgraphs : Array[DotLayoutGraph],
) -> @geom.Rect {
  let mut result = bbox
  for subgraph in subgraphs {
    result = @bbox.merge_bbox(result, subgraph.bbox)
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
      result = @bbox.merge_bbox(result, padded)
    }
    if subgraph.subgraphs.length() > 0 {
      result = expand_bbox_with_clusters(result, subgraph.subgraphs)
    }
  }
  result
}
