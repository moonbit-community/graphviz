///|
/// Graphviz parity: path-group selection mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// and keeps routing order preference stable for pathplan.
/// Do not change behavior without updating fixtures/tests.
pub fn select_path_groups(
  x_groups : Map[Int, Array[String]],
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  ordered_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if x_groups.length() > 0 {
    x_groups
  } else if ordered_groups_with_vnodes.length() > 0 {
    ordered_groups_with_vnodes
  } else {
    ordered_groups
  }
}

///|
/// Graphviz parity: label edge counts aligned to refs/graphviz/lib/dotgen/dotsplines.c (label spacing).
/// Do not change behavior without updating fixtures/tests.
pub fn build_label_edge_counts(
  edges : Array[@cgraph.Edge],
  has_mid_label : (@cgraph.Edge) -> Bool,
) -> Map[String, Int] {
  let label_edge_counts : Map[String, Int] = Map::new()
  for edge in edges {
    if !has_mid_label(edge) {
      continue
    }
    let tail = edge.tail().name()
    let current = match label_edge_counts.get(tail) {
      Some(value) => value
      None => 0
    }
    label_edge_counts[tail] = current + 1
  }
  label_edge_counts
}

///|
/// Graphviz parity: complex tuning toggle mirrors fixture gating for dotsplines heuristics.
/// Do not change behavior without updating fixtures/tests.
pub fn complex_tuning_enabled() -> Bool {
  match @sys.get_env_var("DOT_COMPLEX_TUNING") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}

///|
/// Graphviz parity: routing port-padding gate input keeps cluster/port flags
/// plus edge sequence and callback wiring grouped for Stage E precompute.
pub(all) struct RoutingPortPaddingInput {
  has_clusters : Bool
  has_port_edges : Bool
  edges : Array[@cgraph.Edge]
  compute_padding_fn : (Array[@cgraph.Edge]) -> (Double, Double)
}

///|
/// Graphviz parity: routing port padding keeps Graphviz branch gating for
/// clustered/port-edge mode before invoking record-port padding callbacks.
pub fn compute_port_padding(
  input : RoutingPortPaddingInput,
) -> (Double, Double) {
  if input.has_clusters || !input.has_port_edges {
    (0.0, 0.0)
  } else {
    (input.compute_padding_fn)(input.edges)
  }
}

///|
/// Graphviz parity: head-port metric collector input keeps edge traversal and
/// key/distance callback wiring grouped for deterministic metric aggregation.
pub(all) struct CollectHeadPortMetricsInput {
  edges : Array[@cgraph.Edge]
  enable_complex_tuning : Bool
  key_for_edge_fn : (@cgraph.Edge) -> String
  distance_for_edge_fn : (@cgraph.Edge) -> Double
}

///|
/// Graphviz parity: head-port metric aggregation mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// (curve offsets), preserving stable count/min/max updates per head-port key.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_head_port_metrics(
  input : CollectHeadPortMetricsInput,
) -> HeadPortMetrics {
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if input.enable_complex_tuning {
    for edge in input.edges {
      let key = (input.key_for_edge_fn)(edge)
      if key == "" {
        continue
      }
      let dist = (input.distance_for_edge_fn)(edge)
      let current = head_port_counts.get(key).unwrap_or_default()
      head_port_counts[key] = current + 1
      let mut min_dist = head_port_min_dist.get(key).unwrap_or(dist)
      let mut max_dist = head_port_max_dist.get(key).unwrap_or(dist)
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

///|
/// Graphviz parity: routing precompute pipeline input keeps padding/metric
/// callbacks plus path-context snapshots grouped before Stage E edge solve.
pub(all) struct RoutingPrecomputePipelineInput {
  has_clusters : Bool
  has_port_edges : Bool
  edges : Array[@cgraph.Edge]
  enable_complex_tuning : Bool
  x_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  ordered_groups : Map[Int, Array[String]]
  nodes : Array[@cgraph.Node]
  edge_tail : Array[String]
  edge_head : Array[String]
  sizes : Map[String, @dot_shared.NodeSize]
  ranks : Map[String, Int]
  nodesep_pt : Double
  edge_vnodes : Map[String, Array[String]]
  vnode_sizes : Map[String, @dot_shared.NodeSize]
  vnode_positions : Map[String, @geom.Point]
  cluster_bboxes : Map[String, @geom.Rect]
  build_order_index_fn : (Map[Int, Array[String]]) -> Map[String, Int]
  apply_self_edge_right_space_fn : (
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Map[String, @dot_shared.NodeSize],
  ) -> Map[String, @dot_shared.NodeSize]
  node_local_cluster_key_fn : (@cgraph.Node) -> String
  compute_padding_fn : (Array[@cgraph.Edge]) -> (Double, Double)
  head_metric_key_fn : (@cgraph.Edge) -> String
  head_metric_distance_fn : (@cgraph.Edge) -> Double
}

///|
/// Graphviz parity: routing precompute pipeline output keeps padding metrics,
/// selected path groups, and assembled routing context for Stage E solve.
pub struct RoutingPrecomputePipelineOutput {
  port_pad_below : Double
  port_pad_above : Double
  head_port_metrics : HeadPortMetrics
  path_groups : Map[Int, Array[String]]
  routing_context : RoutingContext
}

///|
/// Graphviz parity: routing precompute keeps metric and path-context
/// derivation in fixed order before Stage E edge routing.
/// Do not change behavior without updating fixtures/tests.
pub fn build_routing_precompute_pipeline(
  input : RoutingPrecomputePipelineInput,
) -> RoutingPrecomputePipelineOutput {
  let (port_pad_below, port_pad_above) =
    compute_port_padding(
      {
        has_clusters: input.has_clusters,
        has_port_edges: input.has_port_edges,
        edges: input.edges,
        compute_padding_fn: input.compute_padding_fn,
      },
    )
  let head_port_metrics =
    collect_head_port_metrics(
      {
        edges: input.edges,
        enable_complex_tuning: input.enable_complex_tuning,
        key_for_edge_fn: input.head_metric_key_fn,
        distance_for_edge_fn: input.head_metric_distance_fn,
      },
    )
  let path_groups =
    select_path_groups(
      input.x_groups,
      input.ordered_groups_with_vnodes,
      input.ordered_groups,
    )
  let routing_context =
    prepare_routing_context(
      {
        nodes: input.nodes,
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        sizes: input.sizes,
        ranks: input.ranks,
        ordered_groups: input.ordered_groups,
        x_groups: path_groups,
        nodesep_pt: input.nodesep_pt,
        edge_vnodes: input.edge_vnodes,
        vnode_sizes: input.vnode_sizes,
        vnode_positions: input.vnode_positions,
        cluster_bboxes: input.cluster_bboxes,
        build_order_index_fn: input.build_order_index_fn,
        apply_self_edge_right_space_fn: input.apply_self_edge_right_space_fn,
        node_local_cluster_key_fn: input.node_local_cluster_key_fn,
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
