///|
/// Graphviz parity: recover_slack class keys collapse reverse-direction
/// unlabeled edges that share a class2 vnode chain.
pub fn recover_slack_key_for_edge(edge : @cgraph.Edge) -> String {
  let undirected = edge.tail().graph().kind() is @cgraph.GraphKind::Undirected
  if edge_has_label(edge) || !undirected {
    "vnode|\{@dot_shared.edge_vnode_key(edge)}"
  } else {
    "parallel|\{@edge_ops.edge_parallel_key(edge.tail().name(), edge.head().name(), edge.tail_port(), edge.head_port())}"
  }
}

///|
/// Graphviz parity: recover_slack for regular-edge classes uses the
/// center-most parallel member (tie: later edge id).
fn recover_regular_selection(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> Map[String, Int] {
  let selected_ids : Map[String, Int] = Map::new()
  let selected_scores : Map[String, Double] = Map::new()
  for edge in ordered_edges {
    if edge_is_self(edge) {
      continue
    }
    let base = match base_cache.get(edge.id()) {
      Some(value) => value
      None => continue
    }
    if base.is_flat_edge {
      continue
    }
    let key = recover_slack_key_for_edge(edge)
    let score = Double::abs(base.parallel_offset)
    match selected_ids.get(key) {
      Some(current_id) => {
        let current_score = match selected_scores.get(key) {
          Some(value) => value
          None => score
        }
        if score < current_score ||
          (score == current_score && edge.id() > current_id) {
          selected_ids[key] = edge.id()
          selected_scores[key] = score
        }
      }
      None => {
        selected_ids[key] = edge.id()
        selected_scores[key] = score
      }
    }
  }
  selected_ids
}

///|
fn collect_parallel_groups(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> Map[String, Array[@cgraph.Edge]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in ordered_edges {
    if edge_has_label(edge) {
      continue
    }
    if edge_is_self(edge) {
      continue
    }
    let base = match base_cache.get(edge.id()) {
      Some(value) => value
      None => continue
    }
    if base.is_flat_edge {
      continue
    }
    let key = @dot_shared.edge_vnode_key(edge)
    match groups.get(key) {
      Some(list) => list.push(edge)
      None => groups[key] = [edge]
    }
  }
  groups
}

///|
pub(all) struct RegularRecoverRoutingPlan {
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  recover_edge_id_for_routing : Map[String, Int]
}

///|
/// Graphviz parity: recover_slack candidate selection runs before edge routing
/// and keeps regular classes aligned to ordered-edge grouping.
pub fn build_regular_recover_routing_plan(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> RegularRecoverRoutingPlan {
  let recover_edge_id_by_key =
    recover_regular_selection(ordered_edges, base_cache)
  let regular_parallel_groups =
    collect_parallel_groups(ordered_edges, base_cache)
  let recover_edge_id_for_routing : Map[String, Int] = Map::new()
  for key, edge_id in recover_edge_id_by_key {
    recover_edge_id_for_routing[key] = edge_id
  }
  for _key, group_edges in regular_parallel_groups {
    if group_edges.length() > 1 {
      let recover_key = recover_slack_key_for_edge(group_edges[0])
      recover_edge_id_for_routing[recover_key] = group_edges[0].id()
    }
  }
  { regular_parallel_groups, recover_edge_id_for_routing }
}
