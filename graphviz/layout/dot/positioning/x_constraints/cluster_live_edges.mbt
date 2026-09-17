// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// position.c/vnode_not_related_to follows the first saved outgoing edge to
/// its original edge. Other original paths through a concentrated vnode do
/// not exempt that vnode from cluster keepout constraints.
fn live_cluster_related_nodes(
  graph : @setup.ConcentrateFastGraph,
  members : Map[String, Bool],
) -> Map[String, Bool] {
  let related : Map[String, Bool] = Map([])
  for name, _ in members {
    if !@edge_identity.is_edge_vnode_name(name) {
      related[name] = true
    }
  }
  for name, indices in graph.outgoing {
    guard @edge_identity.is_edge_vnode_name(name) && indices.length() > 0 else {
      continue
    }
    guard graph.edges[indices[0]].original is Some(original) else { continue }
    if members.get(original.tail().name()) is Some(_) ||
      members.get(original.head().name()) is Some(_) {
      related[name] = true
    }
  }
  related
}

///|
/// conc.c/rebuild_vlists extends the right boundary only when the first
/// incoming edge originates wholly inside the cluster.
fn live_cluster_right_boundary_member(
  graph : @setup.ConcentrateFastGraph,
  name : String,
  members : Map[String, Bool],
) -> Bool {
  guard @edge_identity.is_edge_vnode_name(name) else {
    members.get(name) is Some(_)
  }
  let incoming = graph.incoming.get(name).unwrap_or_default()
  guard incoming.length() > 0 else { false }
  guard graph.edges[incoming[0]].original is Some(original) else { false }
  members.get(original.tail().name()) is Some(_) &&
  members.get(original.head().name()) is Some(_)
}

///|
/// conc.c/rebuild_vlists infuses normal members, then follows each internal
/// original edge through its final redirect and first outgoing live edges.
/// Backward originals do not infuse their upward virtual chains.
fn live_cluster_left_boundary_members(
  graph : @setup.ConcentrateFastGraph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  members : Map[String, Bool],
) -> Map[String, Bool] {
  let infused : Map[String, Bool] = Map([])
  for name, _ in members {
    if !@edge_identity.is_edge_vnode_name(name) {
      infused[name] = true
    }
  }
  let first_edges : Map[String, Int] = Map([])
  for index, edge in graph.edges {
    guard edge.original is Some(original) else { continue }
    let key = @edge_identity.edge_key(original)
    if first_edges.get(key) is None {
      first_edges[key] = index
    }
  }
  for original in edges {
    guard members.get(original.tail().name()) is Some(_) &&
      members.get(original.head().name()) is Some(_) else {
      continue
    }
    guard first_edges.get(@edge_identity.edge_key(original)) is Some(first) else {
      continue
    }
    let mut index = first
    while graph.edges[index].to_virtual is Some(next) {
      index = next
    }
    let head_rank = ranks.get(original.head().name()).unwrap_or_default()
    while ranks.get(graph.edges[index].head).unwrap_or_default() < head_rank {
      let head = graph.edges[index].head
      infused[head] = true
      let outgoing = graph.outgoing.get(head).unwrap_or_default()
      guard outgoing.length() > 0 else { break }
      index = outgoing[0]
    }
  }
  infused
}
