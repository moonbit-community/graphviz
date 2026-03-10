///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_close(actual.x, expected.x, eps~)
  assert_close(actual.y, expected.y, eps~)
}

///|
fn build_route_base(
  edge : @cgraph.Edge,
  is_flat_edge? : Bool = false,
  parallel_offset? : Double = 0.0,
  tail_rank? : Int = 0,
  head_rank? : Int = 1,
  tail_pos? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_pos? : @geom.Point = @edge_spline.point(30.0, 0.0),
  tail_anchor? : @geom.Point = @edge_spline.point(5.0, 0.0),
  head_anchor? : @geom.Point = @edge_spline.point(25.0, 0.0),
  tail_port? : @cgraph.Port? = None,
  head_port? : @cgraph.Port? = None,
  orig_tail_name? : String = edge.tail().name(),
  orig_head_name? : String = edge.head().name(),
  tail_clip_enabled? : Bool = false,
  head_clip_enabled? : Bool = false,
  has_vnodes? : Bool = false,
  vnodes? : Array[String] = [],
  has_side_anchor? : Bool = false,
) -> EdgeRouteBase {
  let zero = @edge_spline.point(0.0, 0.0)
  let size = @node_primitives.node_size_from_points(10.0, 10.0)
  {
    edge,
    parallel_offset,
    swap_ends: false,
    orig_tail_name,
    orig_head_name,
    tail_name: edge.tail().name(),
    head_name: edge.head().name(),
    tail_port,
    head_port,
    tail_node: edge.tail(),
    head_node: edge.head(),
    tail_pos,
    head_pos,
    tail_size: size,
    head_size: size,
    mid_label_width_pt: 0.0,
    mid_label_height_pt: 0.0,
    tail_record_path_box: None,
    head_record_path_box: None,
    tail_anchor,
    head_anchor,
    head_port_rect: None,
    tail_port_side: 0,
    head_port_side: 0,
    tail_sameport_group_size: 0,
    head_sameport_group_size: 0,
    tail_clip_center: tail_pos,
    tail_clip_size: size,
    head_clip_center: head_pos,
    head_clip_size: size,
    tail_clip_enabled,
    head_clip_enabled,
    tail_clip: tail_anchor,
    head_clip: head_anchor,
    tail_slope: zero,
    head_slope: zero,
    force_segmented: false,
    tail_cluster_bbox: None,
    head_cluster_bbox: None,
    tail_rank,
    head_rank,
    is_flat_edge,
    is_flat_adjacent: false,
    vnodes,
    has_vnodes,
    use_pathplan: false,
    route_include_tail: false,
    route_include_head: false,
    arrow_len_override: None,
    is_dotted: false,
    same_outer_cluster: true,
    diff_local_cluster: false,
    same_local_cluster: true,
    out_tail_anchor: tail_anchor,
    out_head_anchor: head_anchor,
    out_tail_clip: tail_anchor,
    out_head_clip: head_anchor,
    out_tail_pos: tail_pos,
    out_head_pos: head_pos,
    out_tail_size: size,
    out_head_size: size,
    rankdir: @rankdir.RankDir::TB,
    layout_rankdir: @rankdir.RankDir::TB,
    has_side_anchor,
  }
}

///|
fn normalize_id_groups(groups : Array[Array[Int]]) -> Array[Array[Int]] {
  let normalized = groups.copy()
  for ids in normalized {
    ids.sort()
  }
  normalized.sort_by((a, b) => {
    let a0 = a.get(0).unwrap_or_default()
    let b0 = b.get(0).unwrap_or_default()
    cmp_int(a0, b0)
  })
  normalized
}

///|
fn spline_with_start_x(start_x : Double) -> @geom.Spline {
  {
    start: None,
    end: None,
    points: [
      @edge_spline.point(start_x, 0.0),
      @edge_spline.point(start_x + 1.0, 0.0),
      @edge_spline.point(start_x + 2.0, 0.0),
      @edge_spline.point(start_x + 3.0, 0.0),
    ],
  }
}

///|
fn build_layout_edge(
  edge : @cgraph.Edge,
  spline_start_x : Double,
  label_pos? : @geom.Point? = None,
  head_label_pos? : @geom.Point? = None,
  tail_label_pos? : @geom.Point? = None,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutEdge {
  {
    edge,
    splines: [spline_with_start_x(spline_start_x)],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}

///|
fn straight_bezier_points() -> Array[@geom.Point] {
  [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(10.0, 0.0),
    @edge_spline.point(20.0, 0.0),
    @edge_spline.point(30.0, 0.0),
  ]
}

///|
fn sample_regular_pass_input(
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  vnode_positions : Map[String, @geom.Point],
  vnode_sizes : Map[String, @node_primitives.NodeSize],
  rank_y : Map[Int, Double],
) -> RegularPassInput {
  {
    spline_mode: 0,
    ranks,
    sizes: Map::new(),
    positions: Map::new(),
    vnode_positions,
    vnode_info: {
      vnode_ranks,
      vnode_sizes,
      vnodes_by_rank: Map::new(),
      edge_vnodes: Map::new(),
      vnode_clusters: Map::new(),
    },
    rank_y,
    rank_ht1: Map::new(),
    rank_ht2: Map::new(),
    x_groups: Map::new(),
    nodesep_pt: 0.0,
    ranksep_pt: 0.0,
    label_edge_counts: Map::new(),
    head_port_metrics: {
      head_port_counts: Map::new(),
      head_port_min_dist: Map::new(),
      head_port_max_dist: Map::new(),
    },
    routing_context: {
      order_index: Map::new(),
      path_order_index: Map::new(),
      path_adjacency: @routesplines.build_path_adjacency([], Map::new(), [], []),
      pathplan_sizes: Map::new(),
      pathplan_vnode_mval_sizes: Map::new(),
      path_cluster_keys: Map::new(),
      path_vnode_clusters: Map::new(),
      parallel_offsets: Map::new(),
      cluster_bboxes: Map::new(),
    },
    enable_complex_tuning: false,
  }
}
