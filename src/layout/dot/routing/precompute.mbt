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
  @dot_shared.env_flag_enabled(@sys.get_env_var("DOT_COMPLEX_TUNING"), false)
}

///|
/// Graphviz parity: clustered/port-edge gate for routing Y padding mirrors
/// dotsplines branch before record-port padding sampling.
pub fn resolve_routing_port_padding(
  has_clusters : Bool,
  has_port_edges : Bool,
  compute_padding : () -> (Double, Double),
) -> (Double, Double) {
  if has_clusters || !has_port_edges {
    (0.0, 0.0)
  } else {
    compute_padding()
  }
}

///|
/// Graphviz parity: head-port metric aggregation mirrors dotsplines
/// count/min/max accumulation for complex tuning.
pub fn build_head_port_metrics(
  edges : Array[@cgraph.Edge],
  enable_complex_tuning : Bool,
  edge_metric_sample : (@cgraph.Edge) -> (String, Double)?,
) -> HeadPortMetrics {
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if enable_complex_tuning {
    for edge in edges {
      match edge_metric_sample(edge) {
        Some((key, dist)) => {
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
        None => ()
      }
    }
  }
  { head_port_counts, head_port_min_dist, head_port_max_dist }
}

///|
/// Graphviz parity: routing precompute pipeline input keeps padding/metric
/// snapshots grouped before Stage E edge solve.
pub(all) struct RoutingPrecomputePipelineInput {
  edges : Array[@cgraph.Edge]
  x_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  ordered_groups : Map[Int, Array[String]]
  port_pad_below : Double
  port_pad_above : Double
  head_port_metrics : HeadPortMetrics
  edge_tail : Array[String]
  edge_head : Array[String]
  ranks : Map[String, Int]
  nodesep_pt : Double
  edge_vnodes : Map[String, Array[String]]
  pathplan_sizes : Map[String, @dot_shared.NodeSize]
  path_cluster_keys : Map[String, String]
  vnode_sizes : Map[String, @dot_shared.NodeSize]
  vnode_positions : Map[String, @geom.Point]
  cluster_bboxes : Map[String, @geom.Rect]
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
  let path_groups =
    select_path_groups(
      input.x_groups,
      input.ordered_groups_with_vnodes,
      input.ordered_groups,
    )
  let routing_context =
    prepare_routing_context(
      {
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        ranks: input.ranks,
        ordered_groups: input.ordered_groups,
        x_groups: path_groups,
        nodesep_pt: input.nodesep_pt,
        edge_vnodes: input.edge_vnodes,
        pathplan_sizes: input.pathplan_sizes,
        path_cluster_keys: input.path_cluster_keys,
        vnode_sizes: input.vnode_sizes,
        vnode_positions: input.vnode_positions,
        cluster_bboxes: input.cluster_bboxes,
      },
    )
  {
    port_pad_below: input.port_pad_below,
    port_pad_above: input.port_pad_above,
    head_port_metrics: input.head_port_metrics,
    path_groups,
    routing_context,
  }
}
