///|
fn build_bezier_layout_edge(
  base : EdgeRouteBase,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
  tail_swap : Bool,
  head_swap : Bool,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let bezier_layout_result =
    @routing.build_bezier_layout_spline_result(
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
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}

///|
/// Graphviz parity: self-edge routes reuse finalize/build_edge_layout path.
/// Do not change behavior without updating fixtures/tests.
fn build_self_edge_layout(
  base : EdgeRouteBase,
  route : SelfEdgeRoute,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let mut edge_layout =
    build_bezier_layout_edge(
      base,
      route.points,
      0.0,
      false,
      false,
      false,
      ranks,
      rank_y,
      vnode_info,
      vnode_positions,
      nodesep_pt,
      has_clusters,
      flat_label_edge_vnodes,
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
  base : EdgeRouteBase,
  bezier : Array[@geom.Point],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    base,
    bezier,
    0.0,
    false,
    base.swap_ends,
    base.swap_ends,
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}

priv struct RegularSplineLayoutResult {
  edge_layout : DotLayoutEdge
  spline_result : EdgeSplineResult
}

///|
/// Graphviz parity: regular-edge routing keeps build/finalize/recover_slack flow.
/// Do not change behavior without updating fixtures/tests.
fn build_regular_spline_layout(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  splines : SplinesMode,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
  path_adjacency : @routesplines.PathAdjacency,
  recover_edge_id_by_key : Map[String, Int],
  recovered_slack_keys : Map[String, Bool],
) -> RegularSplineLayoutResult {
  let spline_result = build_edge_spline(
    base,
    splines,
    ranks,
    sizes,
    positions,
    vnode_positions,
    vnode_info,
    rank_y,
    rank_ht1,
    rank_ht2,
    x_groups,
    nodesep_pt,
    path_left_bound,
    path_right_bound,
    ranksep_pt,
    label_edge_counts,
    head_port_metrics,
    routing_context,
    enable_complex_tuning,
  )
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let spline = @routing.finalize_edge_spline(base, layout_spline_result)
  @routing.recover_pathplan_slack(
    edge,
    base,
    spline_result,
    ranks,
    vnode_info.vnode_ranks,
    rank_y,
    vnode_positions,
    vnode_info.vnode_sizes,
    path_adjacency,
    recover_edge_id_by_key,
    recovered_slack_keys,
    recover_slack_vnodes,
  )
  let layout =
    build_edge_layout(
      base,
      spline,
      layout_spline_result,
      ranks,
      rank_y,
      vnode_info,
      vnode_positions,
      nodesep_pt,
      has_clusters,
      flat_label_edge_vnodes,
    )
  { edge_layout: layout, spline_result }
}

///|
/// Graphviz parity: regular-edge reuse path keeps clipping/label finalization.
fn build_regular_bezier_layout(
  base : EdgeRouteBase,
  shared_spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    base,
    shared_spline_result.raw_bezier,
    shared_spline_result.label_pad_boost,
    shared_spline_result.apply_dotted_adjustment,
    base.swap_ends,
    base.swap_ends,
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}

///|
/// Graphviz parity: self-edge route cache reuse + self-edge layout finalize path.
/// Do not change behavior without updating fixtures/tests.
fn maybe_build_self_edge_layout(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  build_base : (@cgraph.Edge) -> EdgeRouteBase,
  ranks : Map[String, Int],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Bool {
  let edge_id = edge.id()
  let route = @routing.self_edge_route_for_edge(
    edge,
    self_edge_groups,
    base_cache,
    nodesep_pt,
    rank_y,
    self_edge_routes,
    build_base,
    build_self_edge_routes,
  )
  match route {
    Some(route) => {
      let edge_layout =
        build_self_edge_layout(
          base,
          route,
          ranks,
          rank_y,
          vnode_info,
          vnode_positions,
          nodesep_pt,
          has_clusters,
          flat_label_edge_vnodes,
        )
      edges_out_by_id[edge_id] = edge_layout
      true
    }
    None => false
  }
}

///|
/// Graphviz parity: edge routing aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn route_edges(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  splines : SplinesMode,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  ranksep_pt : Double,
  has_clusters : Bool,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  flat_label_edge_vnodes : Map[String, String],
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> Array[DotLayoutEdge] {
  let path_adjacency = routing_context.path_adjacency
  let path_order_index = routing_context.path_order_index
  let self_edge_groups = @routing.collect_self_edge_groups(edges)
  let sameport_overrides = collect_sameport_overrides(
    edges,
    positions,
    sizes,
    record_orientation,
    layout_rankdir,
    ranksep_pt,
  )
  let build_base_for_edge =
    (edge : @cgraph.Edge) =>
      build_edge_route_base(
        graph.kind(),
        edge,
        ranks,
        sizes,
        positions,
        record_orientation,
        label_ports_map,
        label_ports_raw,
        routing_context,
        rankdir,
        layout_rankdir,
        enable_complex_tuning,
        vnode_info.edge_vnodes,
        sameport_overrides,
      )
  let base_cache =
    @routing.build_route_base_cache(
      edges,
      build_base_for_edge,
    )
  let prepass =
    @routing.build_route_prepass_state(
      edges,
      base_cache,
      splines == SplinesMode::Spline,
      ranks,
      routing_context.order_index,
      path_order_index,
      positions,
      vnode_positions,
      sizes,
      vnode_info.vnode_sizes,
      x_groups,
    )
  let flat_adjacent_simple_beziers = prepass.flat_adjacent_simple_beziers
  let path_left_bound = prepass.path_left_bound
  let path_right_bound = prepass.path_right_bound
  let ordered_edges = prepass.ordered_edges
  let recover_edge_id_for_routing = prepass.recover_edge_id_for_routing
  let regular_parallel_groups = prepass.regular_parallel_groups
  let self_edge_routes : Map[Int, SelfEdgeRoute] = Map::new()
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  let recovered_slack_keys : Map[String, Bool] = Map::new()
  for edge in ordered_edges {
    let edge_id = edge.id()
    if edges_out_by_id.get(edge_id) is Some(_) {
      continue
    }
    let base = match base_cache.get(edge_id) {
      Some(value) => value
      None => continue
    }
    match flat_adjacent_simple_beziers.get(edge_id) {
      Some(bezier) => {
        let edge_layout =
          build_flat_adjacent_layout(
            base,
            bezier,
            ranks,
            rank_y,
            vnode_info,
            vnode_positions,
            nodesep_pt,
            has_clusters,
            flat_label_edge_vnodes,
          )
        edges_out_by_id[edge_id] = edge_layout
        continue
      }
      None => ()
    }
    if maybe_build_self_edge_layout(
      edge,
      base,
      self_edge_groups,
      base_cache,
      build_base_for_edge,
      ranks,
      nodesep_pt,
      rank_y,
      vnode_info,
      vnode_positions,
      has_clusters,
      flat_label_edge_vnodes,
      self_edge_routes,
      edges_out_by_id,
    ) {
      continue
    }
    let regular_layout = build_regular_spline_layout(
      edge,
      base,
      splines,
      ranks,
      sizes,
      positions,
      vnode_positions,
      vnode_info,
      rank_y,
      rank_ht1,
      rank_ht2,
      x_groups,
      nodesep_pt,
      path_left_bound,
      path_right_bound,
      ranksep_pt,
      label_edge_counts,
      head_port_metrics,
      routing_context,
      enable_complex_tuning,
      has_clusters,
      flat_label_edge_vnodes,
      path_adjacency,
      recover_edge_id_for_routing,
      recovered_slack_keys,
    )
    edges_out_by_id[edge_id] = regular_layout.edge_layout
    let sibling_edges =
      @routing.collect_parallel_reuse_siblings(
        edge,
        regular_layout.spline_result.raw_bezier,
        regular_parallel_groups,
      )
    if sibling_edges.length() == 0 {
      continue
    }
    for group_edge in sibling_edges {
      let group_edge_id = group_edge.id()
      let group_base = match base_cache.get(group_edge_id) {
        Some(value) => value
        None => continue
      }
      let group_layout =
        build_regular_bezier_layout(
          group_base,
          regular_layout.spline_result,
          ranks,
          rank_y,
          vnode_info,
          vnode_positions,
          nodesep_pt,
          has_clusters,
          flat_label_edge_vnodes,
        )
      edges_out_by_id[group_edge_id] = group_layout
    }
  }
  remap_parallel_edge_layouts(edges, ranks, edges_out_by_id)
  let ordered_output_edge_ids =
    @routing.collect_input_order_edge_ids(
      edges,
      (edge_id) => edges_out_by_id.get(edge_id) is Some(_),
    )
  let edges_out : Array[DotLayoutEdge] = []
  for edge_id in ordered_output_edge_ids {
    match edges_out_by_id.get(edge_id) {
      Some(value) => edges_out.push(value)
      None => ()
    }
  }
  edges_out
}
