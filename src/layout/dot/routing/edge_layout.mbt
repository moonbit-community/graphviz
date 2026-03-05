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
pub(all) struct EdgeLabelPosInput {
  edge : @cgraph.Edge
  spline : @geom.Spline
  tail_clip : @geom.Point
  head_clip : @geom.Point
  rankdir : @dot_shared.RankDir
  label_rank_y : Double?
  label_rank_x : Double?
  apply_label_pad : Bool
  nodesep_pt : Double
  label_pad_boost : Double
}

///|
type EdgeLabelPosFn = (EdgeLabelPosInput) -> @geom.Point?

///|
pub(all) struct EdgeLayoutDeps {
  edge_label_rank_for_routing_fn : EdgeLabelRankForRoutingFn
  edge_label_rank_y_fn : EdgeLabelRankYFn
  edge_label_rank_x_fn : EdgeLabelRankXFn
  edge_label_pos_from_vnode_fn : EdgeLabelPosFromVnodeFn
  flat_edge_label_pos_simple_fn : FlatEdgeLabelPosSimpleFn
  edge_label_pos_fn : EdgeLabelPosFn
  edge_port_label_pos_fn : EdgePortLabelPosFn
}

priv struct EdgePortLabelPosForAttrInput {
  edge : @cgraph.Edge
  spline : @geom.Spline
  attr_name : String
  is_head : Bool
  edge_port_label_pos_fn : EdgePortLabelPosFn
}

///|
fn edge_port_label_pos_for_attr(
  input : EdgePortLabelPosForAttrInput,
) -> @geom.Point? {
  let edge = input.edge
  if edge_attr_non_empty(edge, input.attr_name) {
    (input.edge_port_label_pos_fn)(
      {
        edge,
        spline: input.spline,
        is_head: input.is_head,
      },
    )
  } else {
    None
  }
}

///|
/// Graphviz parity: edge label placement aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub(all) struct EdgeLayoutBuildInput {
  base : EdgeRouteBase
  spline : @geom.Spline
  spline_result : EdgeSplineResult
  edge_layout_input : EdgeLayoutInput
  deps : EdgeLayoutDeps
}

///|
pub fn build_edge_layout(
  input : EdgeLayoutBuildInput,
) -> DotLayoutEdge {
  let base = input.base
  let spline = input.spline
  let spline_result = input.spline_result
  let edge_layout_input = input.edge_layout_input
  let deps = input.deps
  let edge = base.edge
  let label_rank_info =
    (deps.edge_label_rank_for_routing_fn)(
      edge,
      edge_layout_input.ranks,
      base.mid_label_width_pt,
    )
  let label_rank_y =
    (deps.edge_label_rank_y_fn)(
      edge,
      edge_layout_input.ranks,
      edge_layout_input.rank_y,
    )
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
          (deps.edge_label_rank_x_fn)(
            edge,
            label_rank,
            edge_layout_input.vnode_info,
            edge_layout_input.vnode_positions,
          )
        } else {
          None
        }
      None => None
    }
  let apply_label_pad = edge_layout_input.has_clusters
  let default_label_pos =
    () =>
      (deps.edge_label_pos_fn)(
        {
          edge,
          spline,
          tail_clip: base.out_tail_clip,
          head_clip: base.out_head_clip,
          rankdir: base.layout_rankdir,
          label_rank_y,
          label_rank_x,
          apply_label_pad,
          nodesep_pt: edge_layout_input.nodesep_pt,
          label_pad_boost: spline_result.label_pad_boost,
        },
      )
  let flat_simple_or_default =
    () =>
      match mid_label_metrics {
        Some(metrics) =>
          Some(
            (deps.flat_edge_label_pos_simple_fn)(
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
              (deps.edge_label_pos_from_vnode_fn)(
                @edge_spline.point(rank_x, rank_y),
                metrics.width,
                metrics.height,
                base.rankdir,
              ),
            )
          }
          _ =>
            if base.is_flat_edge {
              match edge_layout_input.flat_label_edge_vnodes.get(@dot_shared.edge_key(edge)) {
                Some(vnode_name) =>
                  match edge_layout_input.vnode_positions.get(vnode_name) {
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
  let head_label_pos =
    edge_port_label_pos_for_attr(
      {
        edge,
        spline,
        attr_name: "headlabel",
        is_head: true,
        edge_port_label_pos_fn: deps.edge_port_label_pos_fn,
      },
    )
  let tail_label_pos =
    edge_port_label_pos_for_attr(
      {
        edge,
        spline,
        attr_name: "taillabel",
        is_head: false,
        edge_port_label_pos_fn: deps.edge_port_label_pos_fn,
      },
    )
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos: None,
  }
}
