// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn concentrate_live_candidates(
  fast : ConcentrateFastGraph,
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  vnode_info : EdgeVnodeInfo,
  excluded : Map[String, Bool],
  aliases : Map[String, String],
  node_ports_equal : (@cgraph.Node, @cgraph.Port?, @cgraph.Port?) -> Bool,
) -> Unit {
  let labeled : Map[String, Bool] = Map([])
  let nodes : Map[String, @cgraph.Node] = Map([])
  for edge in edges {
    nodes[edge.tail().name()] = edge.tail()
    nodes[edge.head().name()] = edge.head()
    guard edge.get_attr("label").unwrap_or_default() != "" else { continue }
    let label_rank = (
        ranks.get(edge.tail().name()).unwrap_or_default() +
        ranks.get(edge.head().name()).unwrap_or_default()
      ) /
      2
    for
      vnode in vnode_info.edge_vnodes
      .get(@edge_identity.edge_vnode_key(edge))
      .unwrap_or_default() {
      if vnode_info.vnode_ranks.get(vnode) == Some(label_rank) {
        labeled[vnode] = true
      }
    }
  }
  let rank_keys : Array[Int] = []
  for rank, _ in groups {
    rank_keys.push(rank)
  }
  rank_keys.sort()
  for sweep in [Down, Up] {
    for offset in 0..<rank_keys.length() {
      let index = match sweep {
        Down => offset
        Up => rank_keys.length() - 1 - offset
      }
      let rank = rank_keys[index]
      guard rank > 0 else { continue }
      let names = groups[rank].filter(name => aliases.get(name) is None)
      let mut left = 0
      while left < names.length() {
        let kept = names[left]
        guard fast.concentrate_candidate(kept, labeled) else {
          left += 1
          continue
        }
        let mut right = left + 1
        while right < names.length() &&
              fast.concentrate_candidate(names[right], labeled) &&
              fast.same_concentrate_endpoint(
                kept,
                names[right],
                sweep,
                ranks,
                excluded,
                nodes,
                node_ports_equal,
              ) {
          right += 1
        }
        for index in (left + 1)..<right {
          fast.merge_node(kept, names[index], sweep)
          aliases[names[index]] = kept
        }
        left = right
      }
    }
  }
}

///|
fn ConcentrateFastGraph::concentrate_candidate(
  self : ConcentrateFastGraph,
  name : String,
  labeled : Map[String, Bool],
) -> Bool {
  @edge_identity.is_edge_vnode_name(name) &&
  labeled.get(name) is None &&
  self.incoming.get(name).unwrap_or_default().length() == 1 &&
  self.outgoing.get(name).unwrap_or_default().length() == 1
}

///|
fn ConcentrateFastGraph::same_concentrate_endpoint(
  self : ConcentrateFastGraph,
  kept : String,
  candidate : String,
  sweep : ConcentrateSweep,
  ranks : Map[String, Int],
  excluded : Map[String, Bool],
  nodes : Map[String, @cgraph.Node],
  node_ports_equal : (@cgraph.Node, @cgraph.Port?, @cgraph.Port?) -> Bool,
) -> Bool {
  let adjacency = match sweep {
    Down => self.incoming
    Up => self.outgoing
  }
  let first = self.edges[adjacency[kept][0]]
  let second = self.edges[adjacency[candidate][0]]
  guard first.original is Some(a) else { false }
  guard second.original is Some(b) else { false }
  guard excluded.get(@edge_identity.edge_vnode_key(a)) is None &&
    excluded.get(@edge_identity.edge_vnode_key(b)) is None else {
    false
  }
  let a_forward = ranks.get(a.tail().name()).unwrap_or_default() <
    ranks.get(a.head().name()).unwrap_or_default()
  let b_forward = ranks.get(b.tail().name()).unwrap_or_default() <
    ranks.get(b.head().name()).unwrap_or_default()
  guard a_forward == b_forward else { false }
  let (neighbor, other, first_port, second_port) = match sweep {
    Down => (first.tail, second.tail, first.tail_port, second.tail_port)
    Up => (first.head, second.head, first.head_port, second.head_port)
  }
  guard neighbor == other else { false }
  if nodes.get(neighbor) is Some(node) {
    node_ports_equal(node, first_port, second_port)
  } else {
    @edge_identity.port_key(first_port) == @edge_identity.port_key(second_port)
  }
}
