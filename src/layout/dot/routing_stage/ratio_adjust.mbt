///|
/// Graphviz parity: ratio-adjust payload keeps ratio inputs grouped so the
/// pre-routing scaling boundary remains explicit and stable.
priv struct RoutingRatioAdjustInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  nodes_out : Array[DotLayoutNode]
  positions_state : PositionResult
  cluster_bboxes : Map[String, @geom.Rect]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
priv struct RoutingRatioAdjustedData {
  ratio_scaled : Bool
  ratio_sx : Double
  ratio_sy : Double
  positions_state : PositionResult
  cluster_bboxes : Map[String, @geom.Rect]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
/// Graphviz parity: ratio=fill scaling is resolved once before routing
/// precompute/edge solve and keeps position/cluster/port maps in sync.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_ratio_adjusted_data(
  input : RoutingRatioAdjustInput,
) -> RoutingRatioAdjustedData {
  let graph = input.graph
  let prep = input.prep
  let rank_data = input.rank_data
  let nodes_out = input.nodes_out
  let positions_state = input.positions_state
  let routing_bbox =
    @bbox.compute_dot_bbox({
      nodes_out,
      all_ranks: rank_data.all_ranks,
      sizes: prep.sizes,
      rank_y: positions_state.rank_y,
      rank_ht1: positions_state.rank_ht1,
      rank_ht2: positions_state.rank_ht2,
    })
  let (ratio_sx, ratio_sy) =
    match @shared.ratio_fill_scale_factors(graph, routing_bbox, prep.rankdir) {
      Some(scale_factors) =>
        if scale_factors.sx != 1.0 || scale_factors.sy != 1.0 {
          (scale_factors.sx, scale_factors.sy)
        } else {
          (1.0, 1.0)
        }
      None => (1.0, 1.0)
    }
  let ratio_scaled = ratio_sx != 1.0 || ratio_sy != 1.0
  if !ratio_scaled {
    return {
      ratio_scaled,
      ratio_sx,
      ratio_sy,
      positions_state,
      cluster_bboxes: input.cluster_bboxes,
      label_ports_map: input.label_ports_map,
      label_ports_raw: input.label_ports_raw,
    }
  }
  let adjusted_positions_state : PositionResult = {
    x_groups: positions_state.x_groups,
    rank_y: @routing.scale_double_map_rounded(positions_state.rank_y, ratio_sy),
    positions:
      @routing.scale_point_map_rounded(
        positions_state.positions,
        ratio_sx,
        ratio_sy,
      ),
    vnode_positions:
      @routing.scale_point_map_rounded(
        positions_state.vnode_positions,
        ratio_sx,
        ratio_sy,
      ),
    cluster_ln_x:
      @routing.scale_named_double_map(positions_state.cluster_ln_x, ratio_sx),
    cluster_rn_x:
      @routing.scale_named_double_map(positions_state.cluster_rn_x, ratio_sx),
    flat_label_edge_vnodes: positions_state.flat_label_edge_vnodes,
    rank_ht1: positions_state.rank_ht1,
    rank_ht2: positions_state.rank_ht2,
    cluster_bbox_heights: positions_state.cluster_bbox_heights,
  }
  {
    ratio_scaled,
    ratio_sx,
    ratio_sy,
    positions_state: adjusted_positions_state,
    cluster_bboxes:
      @routing.scale_rect_map(
        input.cluster_bboxes,
        ratio_sx,
        ratio_sy,
      ),
    label_ports_map:
      @routing.scale_record_port_maps(
        input.label_ports_map,
        ratio_sx,
        ratio_sy,
      ),
    label_ports_raw:
      @routing.scale_record_port_maps(
        input.label_ports_raw,
        ratio_sx,
        ratio_sy,
      ),
  }
}
