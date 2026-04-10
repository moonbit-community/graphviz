// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Routing spatial owner package keeps node/port projection and ratio-adjust
/// kernels together so Stage E integration can depend on one focused owner.
type LayoutPrep = @layout_prep.LayoutPrep

///|
type RankDir = @rankdir.RankDir

///|
type RecordOrientation = @layout_prep.RecordOrientation

///|
type NodeSize = @node_primitives.NodeSize

///|
type RecordPort = @record_geometry.RecordPort

///|
type DotLayoutNode = @layout_tree.DotLayoutNode

///|
type RankData = @rank_data.RankData

///|
type PositionResult = @positioning.PositionResult

///|
pub struct RoutingSpatialData {
  nodes_out : Array[DotLayoutNode]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
priv struct RoutingPortLayoutMaps {
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
/// Graphviz parity: routing spatial payload keeps stage context grouped so
/// node/port and cluster-bbox precompute wiring stays explicit and stable.
pub(all) struct RoutingSpatialInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  ranks : Map[String, Int]
  positions_state : PositionResult
}

///|
/// Graphviz parity: node layout assembly aligned to refs/graphviz/lib/dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_routing_layout_nodes(
  nodes : Array[@cgraph.Node],
  positions : Map[String, @geom.Point],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Array[DotLayoutNode] {
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = @node_geometry.resolve_node_output_size(
      output_sizes, node, record_orientation,
    )
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    })
  }
  nodes_out
}

///|
/// Graphviz parity: port layout maps aligned to refs/graphviz/lib/common/shapes.c (record/html ports).
/// Do not change behavior without updating fixtures/tests.
fn build_routing_port_layout_maps(
  nodes_out : Array[DotLayoutNode],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  rankdir : RankDir,
  has_port_edges : Bool,
) -> RoutingPortLayoutMaps {
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  let label_ports_raw : Map[String, Map[String, RecordPort]] = Map::new()
  if has_port_edges {
    for node_layout in nodes_out {
      let final_size = @node_geometry.resolve_node_output_size(
        output_sizes,
        node_layout.node,
        record_orientation,
      )
      let name = node_layout.node.name()
      let raw_ports = @label_layout.raw_label_ports_for_node(
        node_layout.node,
        { x: 0.0, y: 0.0 },
        final_size,
        record_orientation,
      )
      if raw_ports.length() > 0 {
        label_ports_raw[name] = raw_ports
        let ports = @port_geometry.layout_ports_from_final(
          raw_ports,
          node_layout.pos,
          rankdir,
        )
        label_ports_map[name] = ports
      }
    }
  }
  { label_ports_map, label_ports_raw }
}

///|
/// Graphviz parity: routing spatial precompute consumes typed routing-stage
/// inputs and keeps node/port + cluster-bbox computation order unchanged.
/// Do not change behavior without updating fixtures/tests.
pub fn build_routing_spatial_data(
  input : RoutingSpatialInput,
) -> RoutingSpatialData {
  let prep = input.prep
  let positions_state = input.positions_state
  let nodes_out = build_routing_layout_nodes(
    prep.nodes,
    positions_state.positions,
    prep.output_sizes,
    prep.record_orientation,
  )
  let port_layout_maps = build_routing_port_layout_maps(
    nodes_out,
    prep.output_sizes,
    prep.record_orientation,
    prep.rankdir,
    prep.has_port_edges,
  )
  let cluster_bboxes = @subgraph_layout.compute_cluster_route_bboxes(
    input.graph,
    nodes_out,
    positions_state.cluster_ln_x,
    positions_state.cluster_rn_x,
    positions_state.cluster_bbox_heights,
    prep.rankdir,
    input.ranks,
    positions_state.rank_y,
    positions_state.rank_ht1,
    positions_state.rank_ht2,
  )
  {
    nodes_out,
    label_ports_map: port_layout_maps.label_ports_map,
    label_ports_raw: port_layout_maps.label_ports_raw,
    cluster_bboxes,
  }
}

///|
/// Graphviz parity: ratio-adjust payload keeps ratio inputs grouped so the
/// pre-routing scaling boundary remains explicit and stable.
pub(all) struct RoutingRatioAdjustInput {
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
pub struct RoutingRatioAdjustedData {
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
pub fn build_routing_ratio_adjusted_data(
  input : RoutingRatioAdjustInput,
) -> RoutingRatioAdjustedData {
  let graph = input.graph
  let prep = input.prep
  let rank_data = input.rank_data
  let nodes_out = input.nodes_out
  let positions_state = input.positions_state
  let routing_bbox = @bbox.compute_dot_bbox({
    nodes_out,
    all_ranks: rank_data.all_ranks,
    sizes: prep.sizes,
    rank_y: positions_state.rank_y,
    rank_ht1: positions_state.rank_ht1,
    rank_ht2: positions_state.rank_ht2,
  })
  let (ratio_sx, ratio_sy) = match
    @scale_geometry.ratio_fill_scale_factors(graph, routing_bbox, prep.rankdir) {
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
    rank_y: @scale_geometry.scale_double_map_rounded(
      positions_state.rank_y,
      ratio_sy,
    ),
    positions: @scale_geometry.scale_point_map_rounded(
      positions_state.positions,
      ratio_sx,
      ratio_sy,
    ),
    vnode_positions: @scale_geometry.scale_point_map_rounded(
      positions_state.vnode_positions,
      ratio_sx,
      ratio_sy,
    ),
    cluster_ln_x: @scale_geometry.scale_named_double_map(
      positions_state.cluster_ln_x,
      ratio_sx,
    ),
    cluster_rn_x: @scale_geometry.scale_named_double_map(
      positions_state.cluster_rn_x,
      ratio_sx,
    ),
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
    cluster_bboxes: @scale_geometry.scale_rect_map(
      input.cluster_bboxes,
      ratio_sx,
      ratio_sy,
    ),
    label_ports_map: @scale_geometry.scale_record_port_maps(
      input.label_ports_map,
      ratio_sx,
      ratio_sy,
    ),
    label_ports_raw: @scale_geometry.scale_record_port_maps(
      input.label_ports_raw,
      ratio_sx,
      ratio_sy,
    ),
  }
}
