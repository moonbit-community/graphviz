// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Graphviz parity: recover_slack class keys collapse reverse-direction
/// unlabeled edges that share a class2 vnode chain.
fn recover_slack_key_for_edge(edge : @cgraph.Edge) -> String {
  let undirected = edge.tail().graph().kind() is @cgraph.GraphKind::Undirected
  if @edge_semantics.edge_has_label(edge) || !undirected {
    "vnode|\{@edge_identity.edge_vnode_key(edge)}"
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
  let selected_ids : Map[String, Int] = Map([])
  let selected_scores : Map[String, Double] = Map([])
  for edge in ordered_edges {
    if @edge_semantics.edge_is_self(edge) {
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
priv enum RegularParallelClass {
  Direct(String)
  Chain(String, Array[String])
} derive(Eq, Hash)

///|
fn collect_parallel_groups(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> Map[String, Array[@cgraph.Edge]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map([])
  let classes : Map[RegularParallelClass, Array[@cgraph.Edge]] = Map([])
  let concentrate = @order_graph.graphviz_concentrate_enabled(ordered_edges)
  for edge in ordered_edges {
    guard !concentrate ||
      @membership.node_cluster_key(edge.tail()) !=
      @membership.node_cluster_key(edge.head()) else {
      continue
    }
    guard !@edge_semantics.edge_has_label(edge) &&
      !@edge_semantics.edge_is_self(edge) else {
      continue
    }
    guard base_cache.get(edge.id()) is Some(base) else { continue }
    guard !base.is_flat_edge else { continue }
    let key = @edge_identity.edge_vnode_key(edge)
    let class_key = if base.vnodes.is_empty() {
      RegularParallelClass::Direct(key)
    } else {
      // class2 can merge opposite directions into one fast-edge chain.
      // Require the entire chain, not a concentrated shared prefix.
      let chain = if base.vnodes[0] > base.vnodes[base.vnodes.length() - 1] {
        base.vnodes.rev()
      } else {
        base.vnodes.copy()
      }
      RegularParallelClass::Chain(
        @edge_ops.edge_parallel_key(
          edge.tail().name(),
          edge.head().name(),
          edge.tail_port(),
          edge.head_port(),
        ),
        chain,
      )
    }
    let group = classes.get_or_init(class_key, () => [])
    group.push(edge)
    groups[key] = group
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
fn build_regular_recover_routing_plan(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> RegularRecoverRoutingPlan {
  let recover_edge_id_by_key = recover_regular_selection(
    ordered_edges, base_cache,
  )
  let regular_parallel_groups = collect_parallel_groups(
    ordered_edges, base_cache,
  )
  let recover_edge_id_for_routing : Map[String, Int] = Map([])
  for key, edge_id in recover_edge_id_by_key {
    recover_edge_id_for_routing[key] = edge_id
  }
  for _key, group_edges in regular_parallel_groups {
    if group_edges.length() > 1 {
      for group_edge in group_edges {
        let recover_key = recover_slack_key_for_edge(group_edge)
        recover_edge_id_for_routing[recover_key] = group_edges[0].id()
      }
    }
  }
  { regular_parallel_groups, recover_edge_id_for_routing, }
}
