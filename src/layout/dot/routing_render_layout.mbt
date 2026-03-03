///|
/// Graphviz parity: edge label placement aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_layout(
  base : EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let edge = base.edge
  let label_rank_info = edge_label_rank_info(edge, ranks)
  let label_rank_y = edge_label_rank_y(edge, ranks, rank_y)
  let label_rank_x = match label_rank_info {
    Some(info) =>
      if info.span > 1 {
        edge_label_rank_x(
          edge,
          info.label_rank,
          vnode_info.vnode_ranks,
          vnode_info.edge_vnodes,
          vnode_positions,
        )
      } else {
        None
      }
    None => None
  }
  let apply_label_pad = has_clusters
  let label_pos : @geom.Point? = match edge.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        match (label_rank_x, label_rank_y, edge_mid_label_metrics(edge)) {
          (Some(rank_x), Some(rank_y), Some(metrics)) => {
            Some(
              edge_label_pos_from_vnode(
                @edge_spline.point(rank_x, rank_y),
                metrics.width,
                metrics.height,
                base.rankdir,
              ),
            )
          }
          _ =>
            if base.is_flat_edge {
              match flat_label_edge_vnodes.get(@dot_shared.edge_key(edge)) {
                Some(vnode_name) =>
                  match vnode_positions.get(vnode_name) {
                    Some(pos) => Some(pos)
                    None =>
                      match edge_mid_label_metrics(edge) {
                        Some(metrics) =>
                          Some(
                            flat_edge_label_pos_simple(
                              base.out_tail_pos,
                              base.out_head_pos,
                              base.out_tail_size.right_pt,
                              base.out_head_size.left_pt,
                              metrics.height,
                            ),
                          )
                        None =>
                          edge_label_pos(
                            edge,
                            spline,
                            base.out_tail_clip,
                            base.out_head_clip,
                            base.layout_rankdir,
                            label_rank_y,
                            label_rank_x,
                            apply_label_pad,
                            nodesep_pt,
                            spline_result.label_pad_boost,
                          )
                      }
                  }
                None =>
                  match edge_mid_label_metrics(edge) {
                    Some(metrics) => {
                      Some(
                        flat_edge_label_pos_simple(
                          base.out_tail_pos,
                          base.out_head_pos,
                          base.out_tail_size.right_pt,
                          base.out_head_size.left_pt,
                          metrics.height,
                        ),
                      )
                    }
                    None =>
                      edge_label_pos(
                        edge,
                        spline,
                        base.out_tail_clip,
                        base.out_head_clip,
                        base.layout_rankdir,
                        label_rank_y,
                        label_rank_x,
                        apply_label_pad,
                        nodesep_pt,
                        spline_result.label_pad_boost,
                      )
                  }
              }
            } else {
              edge_label_pos(
                edge,
                spline,
                base.out_tail_clip,
                base.out_head_clip,
                base.layout_rankdir,
                label_rank_y,
                label_rank_x,
                apply_label_pad,
                nodesep_pt,
                spline_result.label_pad_boost,
              )
            }
        }
      }
    None => None
  }
  let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, true)
      }
    None => None
  }
  let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, false)
      }
    None => None
  }
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos: None,
  }
}
