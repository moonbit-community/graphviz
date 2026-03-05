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
