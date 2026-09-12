// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Routing integration owner package keeps Stage E orchestration plus dot-specific
/// bridge assembly, precompute, and final edge-execution wiring.
type LayoutPrep = @layout_prep.LayoutPrep

///|
type RankDir = @rankdir.RankDir

///|
type SplinesMode = @layout_prep.SplinesMode

///|
type NodeSize = @node_primitives.NodeSize

///|
type RecordPort = @record_geometry.RecordPort

///|
type DotLayoutNode = @layout_tree.DotLayoutNode

///|
type DotLayoutEdge = @routing.DotLayoutEdge

///|
type RankData = @rank_data.RankData

///|
type RankHeights = @rank_heights.RankHeights

///|
type ClusterMetadata = @setup.DotClusterMetadata

///|
fn graphviz_mapbool_default_false(value : String) -> Bool {
  let lower = value.trim().to_lower()
  if lower == "" || lower == "false" || lower == "no" {
    return false
  }
  if lower == "true" || lower == "yes" {
    return true
  }
  match lower.get_char(0) {
    Some(ch) =>
      if ch.is_ascii_digit() {
        let mut number = 0
        for digit in lower {
          if !digit.is_ascii_digit() {
            break
          }
          number = number * 10 + digit.to_int() - '0'.to_int()
        }
        number != 0
      } else {
        false
      }
    None => false
  }
}

///|
fn graph_concentrate_enabled(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("concentrate") {
    Some(value) => graphviz_mapbool_default_false(value)
    None => false
  }
}

///|
type OrderingResult = @setup.OrderingResult

///|
type PositionResult = @positioning.PositionResult

///|
/// Graphviz parity: routing precompute payload keeps owner-side routing metric
/// inputs grouped so Stage E stays explicit without a wrapper-heavy deps layer.
pub(all) struct RoutingPrecomputeInput {
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  positions_state : PositionResult
  label_ports_map : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
  sizes : Map[String, NodeSize]
  enable_complex_tuning : Bool
  concentrate : Bool
}

///|
pub type RoutingPrecomputeData = @precompute.RoutingPrecomputePipelineOutput

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/geometry inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
pub fn build_routing_precompute_data(
  input : RoutingPrecomputeInput,
) -> RoutingPrecomputeData {
  let prep = input.prep
  let head_port_metrics = @precompute.build_dot_head_port_metrics(
    prep.edges,
    input.enable_complex_tuning,
    input.positions_state.positions,
    input.sizes,
    prep.record_orientation,
    input.label_ports_map,
  )
  let pathplan_sizes = @ports.apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    input.sizes,
    prep.rankdir,
    prep.record_orientation,
  )
  let initial_port_points : Map[Int, (@geom.Point?, @geom.Point?)] = Map([])
  if input.ordering.live_graph is Some(_) {
    let sample = @ports.build_initial_port_sampler(prep.nodes, input.sizes)
    for edge in prep.edges {
      initial_port_points[edge.id()] = (
        sample(edge.tail(), edge.tail_port()),
        sample(edge.head(), edge.head_port()),
      )
    }
  }
  @precompute.build_routing_precompute_pipeline(
    {
      edges: prep.edges,
      positions: input.positions_state.positions,
      x_groups: input.positions_state.x_groups,
      ordered_groups_with_vnodes: input.ordering.ordered_groups_with_vnodes,
      ordered_groups: input.ordering.ordered_groups,
      head_port_metrics,
      edge_tail: input.rank_data.edge_tail,
      edge_head: input.rank_data.edge_head,
      ranks: input.rank_data.ranks,
      nodesep_pt: input.rank_heights.nodesep_pt,
      sizes: input.sizes,
      edge_vnodes: input.ordering.vnode_info.edge_vnodes,
      pathplan_sizes,
      path_cluster_keys: input.cluster_meta.intercluster_keys,
      vnode_sizes: input.ordering.vnode_info.vnode_sizes,
      vnode_positions: input.positions_state.vnode_positions,
      cluster_bboxes: input.cluster_bboxes,
      concentrate: input.concentrate,
      initial_port_points,
    },
    live_graph=input.ordering.live_graph,
  )
}

///|
/// Stage E route-edge bridge helpers that adapt stage payload into routing
/// subpackage pipeline dependencies.
pub(all) struct RouteEdgesForDotInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  routing_positions_state : PositionResult
  routing_label_ports_map : Map[String, Map[String, RecordPort]]
  routing_label_ports_raw : Map[String, Map[String, RecordPort]]
  routing_sizes : Map[String, NodeSize]
  path_groups : Map[Int, Array[String]]
  routing_context : @precompute.RoutingContext
  has_graph_edge_labels : Bool
  label_edge_counts : Map[String, Int]
  head_port_metrics : @precompute.HeadPortMetrics
  enable_complex_tuning : Bool
}

///|
pub fn route_edges_for_dot(
  input : RouteEdgesForDotInput,
) -> Array[DotLayoutEdge] {
  let edge_layout_input : @routing.EdgeLayoutInput = {
    ranks: input.rank_data.ranks,
    rank_y: input.routing_positions_state.rank_y,
    vnode_info: input.ordering.vnode_info,
    vnode_positions: input.routing_positions_state.vnode_positions,
    has_clusters: input.cluster_meta.has_clusters,
    nodesep_pt: input.rank_heights.nodesep_pt,
    flat_label_edge_vnodes: input.routing_positions_state.flat_label_edge_vnodes,
  }
  let pipeline_deps : @routing.RouteEdgesPipelineDeps = {
    route_base_deps: build_dot_route_base_deps(
      input.prep.rankdir,
      input.prep.record_orientation,
      input.routing_label_ports_map,
      input.routing_label_ports_raw,
    ),
    callbacks: build_dot_routing_callbacks(edge_layout_input),
  }
  let pipeline_input : @routing.RouteEdgesPipelineInput = {
    graph_kind: input.graph.kind(),
    rankdir: input.prep.rankdir,
    layout_rankdir: RankDir::TB,
    edges: input.prep.edges,
    ranks: input.rank_data.ranks,
    sizes: input.routing_sizes,
    positions: input.routing_positions_state.positions,
    vnode_positions: input.routing_positions_state.vnode_positions,
    vnode_info: input.ordering.vnode_info,
    rank_y: input.routing_positions_state.rank_y,
    rank_ht1: input.routing_positions_state.rank_ht1,
    rank_ht2: input.routing_positions_state.rank_ht2,
    x_groups: input.path_groups,
    nodesep_pt: input.rank_heights.nodesep_pt,
    ranksep_pt: input.rank_heights.ranksep_pt,
    has_graph_edge_labels: input.has_graph_edge_labels,
    label_edge_counts: input.label_edge_counts,
    head_port_metrics: input.head_port_metrics,
    flat_label_edge_vnodes: input.routing_positions_state.flat_label_edge_vnodes,
    routing_context: input.routing_context,
    enable_complex_tuning: input.enable_complex_tuning,
    use_spline_prepass: input.prep.splines == SplinesMode::Spline,
    spline_mode: match input.prep.splines {
      SplinesMode::None | SplinesMode::Polyline => 0
      SplinesMode::Ortho => 1
      _ => 2
    },
  }
  @execution.route_edges_pipeline(pipeline_input, pipeline_deps)
}

///|
/// Graphviz parity: routing stage payload keeps stage outputs and context maps
/// grouped so Stage E wiring remains explicit and stable.
pub(all) struct DotRoutingStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  positions_state : PositionResult
}

///|
pub(all) struct DotRoutingStageOutput {
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  bbox_sizes : Map[String, NodeSize]
}

///|
/// Graphviz parity: dot routing stage mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures), with typed stage payload.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_dot_routing_stage(
  input : DotRoutingStageInput,
) -> DotRoutingStageOutput {
  let graph = input.graph
  let prep = input.prep
  let rank_data = input.rank_data
  let rank_heights = input.rank_heights
  let cluster_meta = input.cluster_meta
  let ordering = input.ordering
  let positions_state = input.positions_state
  let spatial_data = @spatial.build_routing_spatial_data({
    graph,
    prep,
    ranks: rank_data.ranks,
    positions_state,
  })
  let nodes_out = spatial_data.nodes_out
  let ratio_adjusted_data = @spatial.build_routing_ratio_adjusted_data({
    graph,
    prep,
    rank_data,
    nodes_out,
    positions_state,
    cluster_bboxes: spatial_data.cluster_bboxes,
    label_ports_map: spatial_data.label_ports_map,
    label_ports_raw: spatial_data.label_ports_raw,
  })
  let ratio_scaled = ratio_adjusted_data.ratio_scaled
  let ratio_sx = ratio_adjusted_data.ratio_sx
  let ratio_sy = ratio_adjusted_data.ratio_sy
  let routing_cluster_bboxes = ratio_adjusted_data.cluster_bboxes
  let routing_positions_state = ratio_adjusted_data.positions_state
  let label_edge_counts = @precompute.build_label_edge_counts(prep.edges, edge => {
    @edge_label_metrics.edge_mid_label_text(edge) is Some(_)
  })
  let has_graph_edge_labels = @edge_label_metrics.graph_has_edge_labels(
    prep.edges,
  )
  let enable_complex_tuning = @precompute.complex_tuning_enabled()
  let precompute_data = build_routing_precompute_data({
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    positions_state: routing_positions_state,
    label_ports_map: ratio_adjusted_data.label_ports_map,
    cluster_bboxes: routing_cluster_bboxes,
    sizes: prep.sizes,
    enable_complex_tuning,
    concentrate: graph_concentrate_enabled(graph),
  })
  let head_port_metrics = precompute_data.head_port_metrics
  let path_groups = precompute_data.path_groups
  let bbox_sizes = precompute_data.pathplan_sizes
  let routing_context = precompute_data.routing_context
  let edges_routed = route_edges_for_dot({
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    routing_positions_state: ratio_adjusted_data.positions_state,
    routing_label_ports_map: ratio_adjusted_data.label_ports_map,
    routing_label_ports_raw: ratio_adjusted_data.label_ports_raw,
    routing_sizes: prep.sizes,
    path_groups,
    routing_context,
    has_graph_edge_labels,
    label_edge_counts,
    head_port_metrics,
    enable_complex_tuning,
  })
  let edges_out = if ratio_scaled {
    @scale_geometry.scale_edge_layout_output(
      edges_routed,
      1.0 / ratio_sx,
      1.0 / ratio_sy,
    )
  } else {
    edges_routed
  }
  { nodes_out, edges_out, bbox_sizes, }
}
