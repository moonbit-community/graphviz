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
  let spline =
    @routing.build_bezier_points_spline(
      base,
      route.points,
      base.tail_clip_enabled,
      base.head_clip_enabled,
      false,
      false,
    )
  let spline_result =
    @routing.edge_spline_result_for_bezier(
      spline,
      route.points,
      0.0,
      false,
    )
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let final_spline = @routing.finalize_edge_spline(base, layout_spline_result)
  let mut edge_layout =
    build_edge_layout(
      base,
      final_spline,
      layout_spline_result,
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
  let spline =
    @routing.build_bezier_points_spline(
      base,
      bezier,
      base.tail_clip_enabled,
      base.head_clip_enabled,
      base.swap_ends,
      base.swap_ends,
    )
  let spline_result =
    @routing.edge_spline_result_for_bezier(
      spline,
      bezier,
      0.0,
      false,
    )
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let final_spline = @routing.finalize_edge_spline(base, layout_spline_result)
  build_edge_layout(
    base,
    final_spline,
    layout_spline_result,
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
/// Graphviz parity: self-edge groups share generated loop routes in the same pass.
/// Do not change behavior without updating fixtures/tests.
fn ensure_self_edge_routes(
  graph : @cgraph.Graph,
  edge : @cgraph.Edge,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  routing_context : RoutingContext,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  enable_complex_tuning : Bool,
  edge_vnodes : Map[String, Array[String]],
  sameport_overrides : SameportOverrides,
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  self_edge_routes : Map[Int, SelfEdgeRoute],
) -> Unit {
  let edge_id = edge.id()
  if self_edge_routes.get(edge_id) is Some(_) {
    return ()
  }
  let key = @routing.self_edge_group_key(edge)
  match self_edge_groups.get(key) {
    Some(group_edges) => {
      let group_bases : Array[EdgeRouteBase] = []
      for grouped in group_edges {
        let gid = grouped.id()
        let gbase = match base_cache.get(gid) {
          Some(value) => value
          None => {
            let value = build_edge_route_base(
              graph.kind(),
              grouped,
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
              edge_vnodes,
              sameport_overrides,
            )
            base_cache[gid] = value
            value
          }
        }
        group_bases.push(gbase)
      }
      let group_routes =
        build_self_edge_routes(
          group_edges,
          group_bases,
          nodesep_pt,
          rank_y,
        )
      for i in 0..<group_edges.length() {
        self_edge_routes[group_edges[i].id()] = group_routes[i]
      }
    }
    None => ()
  }
}

///|
/// Graphviz parity: routed edge output remains in original edge iteration order.
/// Do not change behavior without updating fixtures/tests.
fn collect_edges_in_input_order(
  edges : Array[@cgraph.Edge],
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Array[DotLayoutEdge] {
  let edges_out : Array[DotLayoutEdge] = []
  for edge in edges {
    match edges_out_by_id.get(edge.id()) {
      Some(value) => edges_out.push(value)
      None => ()
    }
  }
  edges_out
}

///|
fn remap_port_label_pos(
  edge : @cgraph.Edge,
  splines : Array[@geom.Spline],
  label_attr : String,
  is_head : Bool,
  fallback : @geom.Point?,
) -> @geom.Point? {
  if !edge_attr_non_empty(edge, label_attr) {
    return None
  }
  if splines.length() == 0 {
    return fallback
  }
  let spline =
    if is_head {
      splines[splines.length() - 1]
    } else {
      splines[0]
    }
  match edge_port_label_pos(edge, spline, is_head) {
    Some(pos) => Some(pos)
    None => fallback
  }
}

///|
fn remap_edge_layout_edge(
  edge : @cgraph.Edge,
  layout : DotLayoutEdge,
) -> DotLayoutEdge {
  let label_pos =
    if edge_attr_non_empty(edge, "label") {
      layout.label_pos
    } else {
      None
    }
  let head_label_pos = remap_port_label_pos(
    edge,
    layout.splines,
    "headlabel",
    true,
    layout.head_label_pos,
  )
  let tail_label_pos = remap_port_label_pos(
    edge,
    layout.splines,
    "taillabel",
    false,
    layout.tail_label_pos,
  )
  let xlabel_pos =
    if edge_attr_non_empty(edge, "xlabel") {
      layout.xlabel_pos
    } else {
      None
    }
  {
    edge,
    splines: layout.splines,
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}

///|
/// Graphviz parity: duplicate regular-edge spline slots are assigned in
/// pair order after routing, but only within one-direction parallel classes.
/// Do not change behavior without updating fixtures/tests.
fn remap_parallel_edge_layouts(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_direction : Map[String, String] = Map::new()
  let group_has_mixed_direction : Map[String, Bool] = Map::new()
  for edge in edges {
    if edge_has_label(edge) {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      continue
    }
    let tail_rank = ranks.get(tail).unwrap_or_default()
    let head_rank = ranks.get(head).unwrap_or_default()
    if tail_rank == head_rank {
      continue
    }
    let key = @edge_ops.edge_parallel_group_key(edge)
    let sameport_mark = @edge_ops.edge_has_sameport_mark(edge)
    let dir_key = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
    let sameport_tag = if sameport_mark { "sameport" } else { "plain" }
    let direction_key =
      "\{tail}|\{@dot_shared.port_key(edge.tail_port())}|\{head}|\{@dot_shared.port_key(edge.head_port())}|\{dir_key}|\{sameport_tag}"
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_direction.get(key) {
      Some(first_direction) =>
        if first_direction != direction_key {
          group_has_mixed_direction[key] = true
        }
      None => {
        group_first_direction[key] = direction_key
        group_has_mixed_direction[key] = false
      }
    }
  }
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    let mixed_direction = match group_has_mixed_direction.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_direction {
      continue
    }
    ids.sort()
    let layouts : Array[DotLayoutEdge] = []
    for edge_id in ids {
      match edges_out_by_id.get(edge_id) {
        Some(layout) => layouts.push(layout)
        None => ()
      }
    }
    if layouts.length() != ids.length() {
      continue
    }
    let mut out_idx = 0
    let mut src_idx = layouts.length()
    while out_idx < ids.length() {
      src_idx = src_idx - 1
      let edge_id = ids[out_idx]
      let edge = match edges_out_by_id.get(edge_id) {
        Some(layout) => layout.edge
        None => {
          out_idx = out_idx + 1
          continue
        }
      }
      edges_out_by_id[edge_id] =
        remap_edge_layout_edge(edge, layouts[src_idx])
      out_idx = out_idx + 1
    }
  }
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
  let spline =
    @routing.build_bezier_points_spline(
      base,
      shared_spline_result.raw_bezier,
      base.tail_clip_enabled,
      base.head_clip_enabled,
      base.swap_ends,
      base.swap_ends,
    )
  let sibling_spline_result =
    @routing.edge_spline_result_for_bezier(
      spline,
      shared_spline_result.raw_bezier,
      shared_spline_result.label_pad_boost,
      shared_spline_result.apply_dotted_adjustment,
    )
  let layout_spline_result =
    @routing.rebuild_spline_for_render(base, sibling_spline_result)
  let final_spline = @routing.finalize_edge_spline(base, layout_spline_result)
  build_edge_layout(
    base,
    final_spline,
    layout_spline_result,
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
  graph : @cgraph.Graph,
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  routing_context : RoutingContext,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  enable_complex_tuning : Bool,
  edge_vnodes : Map[String, Array[String]],
  sameport_overrides : SameportOverrides,
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Bool {
  if !edge_is_self(edge) {
    return false
  }
  let edge_id = edge.id()
  ensure_self_edge_routes(
    graph,
    edge,
    self_edge_groups,
    base_cache,
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
    edge_vnodes,
    sameport_overrides,
    nodesep_pt,
    rank_y,
    self_edge_routes,
  )
  match self_edge_routes.get(edge_id) {
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
  let order_index = routing_context.path_order_index
  let self_edge_groups = @routing.collect_self_edge_groups(edges)
  let sameport_overrides = collect_sameport_overrides(
    edges,
    positions,
    sizes,
    record_orientation,
    layout_rankdir,
    ranksep_pt,
  )
  let base_cache =
    @routing.build_route_base_cache(
      edges,
      (edge) =>
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
        ),
    )
  let flat_adjacent_simple_beziers =
    if splines == SplinesMode::Spline {
      @routing.collect_flat_adjacent_beziers(
        edges,
        base_cache,
        ranks,
        routing_context.order_index,
      )
    } else {
      Map::new()
    }
  let self_edge_routes : Map[Int, SelfEdgeRoute] = Map::new()
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  let recovered_slack_keys : Map[String, Bool] = Map::new()
  let path_bounds = @routesplines.pathplan_bounds(
    positions,
    vnode_positions,
    sizes,
    vnode_info.vnode_sizes,
    x_groups,
  )
  let path_left_bound = path_bounds.left
  let path_right_bound = path_bounds.right
  let ordered_edges =
    @routing.sorted_edges_for_routing(edges, base_cache, order_index)
  let regular_recover_plan =
    @routing.build_regular_recover_routing_plan(ordered_edges, base_cache)
  let recover_edge_id_for_routing =
    regular_recover_plan.recover_edge_id_for_routing
  let regular_parallel_groups =
    regular_recover_plan.regular_parallel_groups
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
      graph,
      edge,
      base,
      self_edge_groups,
      base_cache,
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
    let regular_key = @dot_shared.edge_vnode_key(edge)
    let group_edges = match regular_parallel_groups.get(regular_key) {
      Some(value) => value
      None => continue
    }
    if group_edges.length() <= 1 ||
      group_edges[0].id() != edge_id ||
      regular_layout.spline_result.raw_bezier.length() == 0 {
      continue
    }
    for group_edge in group_edges {
      let group_edge_id = group_edge.id()
      if group_edge_id == edge_id {
        continue
      }
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
  collect_edges_in_input_order(edges, edges_out_by_id)
}
