///|
priv struct EdgeLabelMetrics {
  width : Double
  height : Double
}

///|
type EdgeLabelRankForRoutingFn = (@cgraph.Edge, Map[String, Int], Double) -> (Int, Int)?

///|
type EdgeLabelRankYFn = (@cgraph.Edge, Map[String, Int], Map[Int, Double]) -> Double?

///|
type EdgeLabelRankXFn = (
  @cgraph.Edge,
  Int,
  EdgeVnodeInfo,
  Map[String, @geom.Point],
) -> Double?

///|
type EdgeLabelPosFromVnodeFn = (@geom.Point, Double, Double, @dot_shared.RankDir) -> @geom.Point

///|
type FlatEdgeLabelPosSimpleFn = (
  @geom.Point,
  @geom.Point,
  Double,
  Double,
  Double,
) -> @geom.Point

///|
type EdgeLabelPosFn = (
  @cgraph.Edge,
  @geom.Spline,
  @geom.Point,
  @geom.Point,
  @dot_shared.RankDir,
  Double?,
  Double?,
  Bool,
  Double,
  Double,
) -> @geom.Point?

///|
type EdgePortLabelPosFn = (@cgraph.Edge, @geom.Spline, Bool) -> @geom.Point?

///|
/// Graphviz parity: edge label placement aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn build_edge_layout(
  base : EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : EdgeSplineResult,
  input : EdgeLayoutInput,
  edge_label_rank_for_routing_fn : EdgeLabelRankForRoutingFn,
  edge_label_rank_y_fn : EdgeLabelRankYFn,
  edge_label_rank_x_fn : EdgeLabelRankXFn,
  edge_label_pos_from_vnode_fn : EdgeLabelPosFromVnodeFn,
  flat_edge_label_pos_simple_fn : FlatEdgeLabelPosSimpleFn,
  edge_label_pos_fn : EdgeLabelPosFn,
  edge_port_label_pos_fn : EdgePortLabelPosFn,
) -> DotLayoutEdge {
  let edge = base.edge
  let label_rank_info =
    edge_label_rank_for_routing_fn(edge, input.ranks, base.mid_label_width_pt)
  let label_rank_y =
    edge_label_rank_y_fn(edge, input.ranks, input.rank_y)
  let mid_label_metrics : EdgeLabelMetrics? =
    if base.mid_label_width_pt > 0.0 {
      Some({ width: base.mid_label_width_pt, height: base.mid_label_height_pt })
    } else {
      None
    }
  let label_rank_x =
    match label_rank_info {
      Some((label_rank, span)) =>
        if span > 1 {
          edge_label_rank_x_fn(
            edge,
            label_rank,
            input.vnode_info,
            input.vnode_positions,
          )
        } else {
          None
        }
      None => None
    }
  let apply_label_pad = input.has_clusters
  let default_label_pos =
    () =>
      edge_label_pos_fn(
        edge,
        spline,
        base.out_tail_clip,
        base.out_head_clip,
        base.layout_rankdir,
        label_rank_y,
        label_rank_x,
        apply_label_pad,
        input.nodesep_pt,
        spline_result.label_pad_boost,
      )
  let flat_simple_or_default =
    () =>
      match mid_label_metrics {
        Some(metrics) =>
          Some(
            flat_edge_label_pos_simple_fn(
              base.out_tail_pos,
              base.out_head_pos,
              base.out_tail_size.right_pt,
              base.out_head_size.left_pt,
              metrics.height,
            ),
          )
        None => default_label_pos()
      }
  let label_pos : @geom.Point? = match edge.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        match (label_rank_x, label_rank_y, mid_label_metrics) {
          (Some(rank_x), Some(rank_y), Some(metrics)) => {
            Some(
              edge_label_pos_from_vnode_fn(
                @edge_spline.point(rank_x, rank_y),
                metrics.width,
                metrics.height,
                base.rankdir,
              ),
            )
          }
          _ =>
            if base.is_flat_edge {
              match input.flat_label_edge_vnodes.get(@dot_shared.edge_key(edge)) {
                Some(vnode_name) =>
                  match input.vnode_positions.get(vnode_name) {
                    Some(pos) => Some(pos)
                    None => flat_simple_or_default()
                  }
                None => flat_simple_or_default()
              }
            } else {
              default_label_pos()
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
        edge_port_label_pos_fn(edge, spline, true)
      }
    None => None
  }
  let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos_fn(edge, spline, false)
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
