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
  let (port_pad_below, port_pad_above) =
    @routing.compute_port_padding(
      {
        has_clusters: input.cluster_meta.has_clusters,
        has_port_edges: prep.has_port_edges,
        edges: prep.edges,
        compute_padding_fn: (edges) => {
          let padding =
            record_port_padding_y(
              edges,
              input.positions_state.positions,
              input.label_ports_map,
            )
          (padding.below, padding.above)
        },
      },
    )
  let head_port_metrics =
    @routing.collect_head_port_metrics(
      {
        edges: prep.edges,
        enable_complex_tuning: input.enable_complex_tuning,
        key_for_edge_fn: (edge) => {
          let head_name = edge.head().name()
          let head_port = @dot_shared.port_key(edge.head_port())
          if head_port == "" {
            if is_record_shape(edge.head()) { head_name } else { "" }
          } else {
            "\{head_name}:\{head_port}"
          }
        },
        distance_for_edge_fn: (edge) => {
          let tail_name = edge.tail().name()
          let head_name = edge.head().name()
          let tail_pos =
            input.positions_state.positions.get(tail_name).unwrap_or({
              x: 0.0,
              y: 0.0,
            })
          let head_pos =
            input.positions_state.positions.get(head_name).unwrap_or({
              x: 0.0,
              y: 0.0,
            })
          let tail_size = input.sizes.get(tail_name).unwrap_or(node_size(edge.tail(), prep.record_orientation))
          let head_size = input.sizes.get(head_name).unwrap_or(node_size(edge.head(), prep.record_orientation))
          let tail_geometry =
            port_geometry(
              tail_name,
              edge.tail_port(),
              input.label_ports_map,
              tail_pos,
              tail_size,
            )
          let head_geometry =
            port_geometry(
              head_name,
              edge.head_port(),
              input.label_ports_map,
              head_pos,
              head_size,
            )
          let dx = head_geometry.center.x - tail_geometry.center.x
          let dy = head_geometry.center.y - tail_geometry.center.y
          Double::sqrt(dx * dx + dy * dy)
        },
      },
    )
  // Graphviz parity: routing path-context execution consumes routing-stage
  // fields while preserving path-group selection then context-assembly order.
  // Graphviz parity: path-groups selection prefers positioned x-groups,
  // then vnode-expanded order groups, then base order groups.
  // Graphviz parity: pathplan uses final x-order (after positioning) with vnodes.
  let path_groups =
    @routing.select_path_groups(
      input.positions_state.x_groups,
      input.ordering.ordered_groups_with_vnodes,
      input.ordering.ordered_groups,
    )
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
