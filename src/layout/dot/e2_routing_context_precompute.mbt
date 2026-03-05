///|
/// Stage E routing-context precompute and edge metric helpers.

///|
/// Graphviz parity: routing precompute payload keeps context snapshots grouped
/// so port metrics and path-context wiring stay explicit and stable.
priv struct RoutingPrecomputeInput {
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
}

///|
priv struct RoutingPrecomputeData {
  port_pad_below : Double
  port_pad_above : Double
  head_port_metrics : @routing.HeadPortMetrics
  path_groups : Map[Int, Array[String]]
  routing_context : @routing.RoutingContext
}

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_precompute_data(
  input : RoutingPrecomputeInput,
) -> RoutingPrecomputeData {
  let prep = input.prep
  // Graphviz parity: port padding and head-port metrics consume
  // routing-stage inputs while preserving compute order before spline routing.
  let port_padding =
    compute_port_padding(
      {
        has_clusters: input.cluster_meta.has_clusters,
        has_port_edges: prep.has_port_edges,
        edges: prep.edges,
        positions: input.positions_state.positions,
        label_ports_map: input.label_ports_map,
      },
    )
  let port_pad_below = port_padding.port_pad_below
  let port_pad_above = port_padding.port_pad_above
  let head_port_metrics =
    collect_head_port_metrics(
      {
        edges: prep.edges,
        positions: input.positions_state.positions,
        sizes: input.sizes,
        label_ports_map: input.label_ports_map,
        record_orientation: prep.record_orientation,
        enable_complex_tuning: input.enable_complex_tuning,
      },
    )
  // Graphviz parity: routing path-context execution consumes routing-stage
  // fields while preserving path-group selection then context-assembly order.
  // Graphviz parity: path-groups selection prefers positioned x-groups,
  // then vnode-expanded order groups, then base order groups.
  // Graphviz parity: pathplan uses final x-order (after positioning) with vnodes.
  let path_groups =
    if input.positions_state.x_groups.length() > 0 {
      input.positions_state.x_groups
    } else if input.ordering.ordered_groups_with_vnodes.length() > 0 {
      input.ordering.ordered_groups_with_vnodes
    } else {
      input.ordering.ordered_groups
    }
  // Graphviz parity: routing context is assembled from routing-stage
  // inputs, final ordering, vnode/rank, and cluster bboxes.
  let routing_context =
    @routing.prepare_routing_context(
      {
        nodes: prep.nodes,
        edges: prep.edges,
        edge_tail: input.rank_data.edge_tail,
        edge_head: input.rank_data.edge_head,
        sizes: input.sizes,
        ranks: input.rank_data.ranks,
        ordered_groups: input.ordering.ordered_groups,
        x_groups: path_groups,
        nodesep_pt: input.rank_heights.nodesep_pt,
        edge_vnodes: input.ordering.vnode_info.edge_vnodes,
        vnode_sizes: input.ordering.vnode_info.vnode_sizes,
        vnode_positions: input.positions_state.vnode_positions,
        cluster_bboxes: input.cluster_bboxes,
        build_order_index_fn: @ordering.build_order_index,
        apply_self_edge_right_space_fn: (nodes, edges, sizes) =>
          apply_self_edge_right_space(
            nodes,
            edges,
            sizes,
            prep.rankdir,
            prep.record_orientation,
          ),
        node_local_cluster_key_fn: node_local_cluster_key,
      },
    )
  {
    port_pad_below,
    port_pad_above,
    head_port_metrics,
    path_groups,
    routing_context,
  }
}

///|
/// Graphviz parity: label edge counts aligned to refs/graphviz/lib/dotgen/dotsplines.c (label spacing).
/// Do not change behavior without updating fixtures/tests.
fn build_label_edge_counts(
  edges : Array[@cgraph.Edge],
) -> Map[String, Int] {
  let label_edge_counts : Map[String, Int] = Map::new()
  for edge in edges {
    if edge_mid_label_text(edge) is Some(_) {
      let tail = edge.tail().name()
      let current = match label_edge_counts.get(tail) {
        Some(value) => value
        None => 0
      }
      label_edge_counts[tail] = current + 1
    }
  }
  label_edge_counts
}

///|
/// Graphviz parity: complex tuning toggle mirrors fixture gating for dotsplines heuristics.
/// Do not change behavior without updating fixtures/tests.
fn complex_tuning_enabled() -> Bool {
  match @sys.get_env_var("DOT_COMPLEX_TUNING") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}

///|
/// Graphviz parity: port padding aligned to refs/graphviz/lib/dotgen/position.c (sameport/compound spacing).
/// Do not change behavior without updating fixtures/tests.
priv struct PortPadding {
  port_pad_below : Double
  port_pad_above : Double
}

///|
/// Graphviz parity: port-padding payload keeps routing edge/port context
/// grouped so Stage E padding wiring remains explicit and stable.
priv struct PortPaddingInput {
  has_clusters : Bool
  has_port_edges : Bool
  edges : Array[@cgraph.Edge]
  positions : Map[String, @geom.Point]
  label_ports_map : Map[String, Map[String, RecordPort]]
}

///|
/// Graphviz parity: port padding aligned to refs/graphviz/lib/dotgen/position.c (sameport/compound spacing).
/// Do not change behavior without updating fixtures/tests.
fn compute_port_padding(
  input : PortPaddingInput,
) -> PortPadding {
  if input.has_clusters || !input.has_port_edges {
    { port_pad_below: 0.0, port_pad_above: 0.0 }
  } else {
    let port_padding =
      record_port_padding_y(input.edges, input.positions, input.label_ports_map)
    { port_pad_below: port_padding.below, port_pad_above: port_padding.above }
  }
}

///|
/// Graphviz parity: head-port payload keeps route geometry context grouped so
/// tuning/metric wiring remains explicit and stable.
priv struct HeadPortMetricsInput {
  edges : Array[@cgraph.Edge]
  positions : Map[String, @geom.Point]
  sizes : Map[String, NodeSize]
  label_ports_map : Map[String, Map[String, RecordPort]]
  record_orientation : RecordOrientation
  enable_complex_tuning : Bool
}

///|
/// Graphviz parity: head port metrics aligned to refs/graphviz/lib/dotgen/dotsplines.c (curve offsets).
/// Do not change behavior without updating fixtures/tests.
fn collect_head_port_metrics(
  input : HeadPortMetricsInput,
) -> @routing.HeadPortMetrics {
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if input.enable_complex_tuning {
    for edge in input.edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      let head_port = @dot_shared.port_key(edge.head_port())
      let key =
        if head_port == "" {
        if is_record_shape(edge.head()) { head_name } else { "" }
      } else {
        "\{head_name}:\{head_port}"
      }
      if key == "" {
        continue
      }
      let tail_pos = match input.positions.get(tail_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let head_pos = match input.positions.get(head_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let tail_size = match input.sizes.get(tail_name) {
        Some(value) => value
        None => node_size(edge.tail(), input.record_orientation)
      }
      let head_size = match input.sizes.get(head_name) {
        Some(value) => value
        None => node_size(edge.head(), input.record_orientation)
      }
      let tail_geometry = port_geometry(
        tail_name,
        edge.tail_port(),
        input.label_ports_map,
        tail_pos,
        tail_size,
      )
      let head_geometry = port_geometry(
        head_name,
        edge.head_port(),
        input.label_ports_map,
        head_pos,
        head_size,
      )
      let dx = head_geometry.center.x - tail_geometry.center.x
      let dy = head_geometry.center.y - tail_geometry.center.y
      let dist = Double::sqrt(dx * dx + dy * dy)
      let current = match head_port_counts.get(key) {
        Some(value) => value
        None => 0
      }
      head_port_counts[key] = current + 1
      let mut min_dist = match head_port_min_dist.get(key) {
        Some(value) => value
        None => dist
      }
      let mut max_dist = match head_port_max_dist.get(key) {
        Some(value) => value
        None => dist
      }
      if dist < min_dist {
        min_dist = dist
      }
      if dist > max_dist {
        max_dist = dist
      }
      head_port_min_dist[key] = min_dist
      head_port_max_dist[key] = max_dist
    }
  }
  { head_port_counts, head_port_min_dist, head_port_max_dist }
}
