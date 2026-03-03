///|
priv struct BezierLayoutSplineResult {
  final_spline : @geom.Spline
  layout_spline_result : @routing.EdgeSplineResult
}

///|
/// Graphviz parity: bezier route rendering follows
/// build_bezier_points_spline -> edge_spline_result_for_bezier ->
/// rebuild_spline_for_render -> finalize_edge_spline.
/// Do not change behavior without updating fixtures/tests.
fn build_bezier_layout_spline_result(
  base : @routing.EdgeRouteBase,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
  tail_swap : Bool,
  head_swap : Bool,
) -> BezierLayoutSplineResult {
  let spline =
    @routing.build_bezier_points_spline(
      base,
      raw_bezier,
      base.tail_clip_enabled,
      base.head_clip_enabled,
      tail_swap,
      head_swap,
    )
  let spline_result =
    @routing.edge_spline_result_for_bezier(
      spline,
      raw_bezier,
      label_pad_boost,
      apply_dotted_adjustment,
    )
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let final_spline = @routing.finalize_edge_spline(base, layout_spline_result)
  { final_spline, layout_spline_result }
}

///|
fn build_bezier_layout_edge(
  base : @routing.EdgeRouteBase,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
  tail_swap : Bool,
  head_swap : Bool,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  let bezier_layout_result =
    build_bezier_layout_spline_result(
      base,
      raw_bezier,
      label_pad_boost,
      apply_dotted_adjustment,
      tail_swap,
      head_swap,
    )
  build_edge_layout(
    base,
    bezier_layout_result.final_spline,
    bezier_layout_result.layout_spline_result,
    context,
  )
}

///|
/// Graphviz parity: self-edge routes reuse finalize/build_edge_layout path.
/// Do not change behavior without updating fixtures/tests.
fn build_self_edge_layout(
  base : @routing.EdgeRouteBase,
  route : @routing.SelfEdgeRoute,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  let mut edge_layout =
    build_bezier_layout_edge(
      base,
      route.points,
      0.0,
      false,
      false,
      false,
      context,
    )
  match route.label_pos {
    Some(pos) =>
      edge_layout = {
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos: Some(pos),
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
        xlabel_pos: edge_layout.xlabel_pos,
      }
    None => ()
  }
  edge_layout
}

///|
/// Graphviz parity: adjacent same-rank no-port/no-label multiedges use the
/// makeSimpleFlat spindle path (dotsplines.c).
/// Do not change behavior without updating fixtures/tests.
fn build_flat_adjacent_layout(
  base : @routing.EdgeRouteBase,
  bezier : Array[@geom.Point],
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    base,
    bezier,
    0.0,
    false,
    base.swap_ends,
    base.swap_ends,
    context,
  )
}

///|
/// Graphviz parity: regular-edge reuse path keeps clipping/label finalization.
fn build_regular_bezier_layout(
  base : @routing.EdgeRouteBase,
  shared_spline_result : @routing.EdgeSplineResult,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    base,
    shared_spline_result.raw_bezier,
    shared_spline_result.label_pad_boost,
    shared_spline_result.apply_dotted_adjustment,
    base.swap_ends,
    base.swap_ends,
    context,
  )
}

///|
/// Graphviz parity: edge label placement aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_layout(
  base : @routing.EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : @routing.EdgeSplineResult,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  let input = context.input
  let edge = base.edge
  let label_rank_info = edge_label_rank_info(edge, input.ranks)
  let label_rank_y =
    edge_label_rank_y(edge, input.ranks, input.rank_y)
  let mid_label_metrics = edge_mid_label_metrics(edge)
  let label_rank_x = match label_rank_info {
    Some(info) =>
      if info.span > 1 {
        edge_label_rank_x(
          edge,
          info.label_rank,
          input.vnode_info.vnode_ranks,
          input.vnode_info.edge_vnodes,
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
      edge_label_pos(
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
            flat_edge_label_pos_simple(
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
