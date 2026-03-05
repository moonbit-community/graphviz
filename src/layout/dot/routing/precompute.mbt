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
