// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

// Live conc.c/fastgr.c edge state. Deleted edges remain addressable because
// later weight transfers may follow their representative links.

///|
pub(all) struct ConcentrateFastEdge {
  tail : String
  head : String
  mut weight : Int
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  mut to_virtual : Int?
  original : @cgraph.Edge?
}

///|
pub(all) struct ConcentrateFastGraph {
  edges : Array[ConcentrateFastEdge]
  copied_from : Map[Int, Int]
  incoming : Map[String, Array[Int]]
  outgoing : Map[String, Array[Int]]
}

///|
pub fn ConcentrateFastGraph::new() -> ConcentrateFastGraph {
  { edges: [], copied_from: {}, incoming: {}, outgoing: {}, }
}

///|
fn append_fast_adjacency(
  adjacency : Map[String, Array[Int]],
  node : String,
  edge : Int,
) -> Unit {
  if adjacency.get(node) is Some(indices) {
    indices.push(edge)
  } else {
    adjacency[node] = [edge]
  }
}

///|
fn ConcentrateFastGraph::add_edge(
  self : ConcentrateFastGraph,
  tail : String,
  head : String,
  weight : Int,
  tail_port? : @cgraph.Port? = None,
  head_port? : @cgraph.Port? = None,
  original? : @cgraph.Edge? = None,
) -> Int {
  let index = self.edges.length()
  self.edges.push({
    tail,
    head,
    weight,
    tail_port,
    head_port,
    to_virtual: None,
    original,
  })
  append_fast_adjacency(self.outgoing, tail, index)
  append_fast_adjacency(self.incoming, head, index)
  index
}

///|
/// zapinlist removes by swapping with the last entry, not stable erasure.
fn remove_fast_adjacency(indices : Array[Int], edge : Int) -> Unit {
  for index, candidate in indices {
    guard candidate == edge else { continue }
    guard indices.pop() is Some(last) else { return }
    if index < indices.length() {
      indices[index] = last
    }
    return
  }
}

///|
fn ConcentrateFastGraph::delete_edge(
  self : ConcentrateFastGraph,
  index : Int,
) -> Unit {
  let edge = self.edges[index]
  remove_fast_adjacency(self.outgoing[edge.tail], index)
  remove_fast_adjacency(self.incoming[edge.head], index)
}

///|
fn copied_fast_port(
  edge : ConcentrateFastEdge,
  endpoint : String,
) -> @cgraph.Port? {
  if endpoint == edge.tail {
    edge.tail_port
  } else if endpoint == edge.head {
    edge.head_port
  } else {
    None
  }
}

///|
/// new_virtual_edge inherits ports only at endpoints it shares with orig.
fn ConcentrateFastGraph::copy_edge(
  self : ConcentrateFastGraph,
  tail : String,
  head : String,
  original : Int,
) -> Int {
  let edge = self.edges[original]
  let index = self.add_edge(
    tail,
    head,
    edge.weight,
    tail_port=copied_fast_port(edge, tail),
    head_port=copied_fast_port(edge, head),
    original=edge.original,
  )
  self.copied_from[index] = original
  if edge.to_virtual is None {
    edge.to_virtual = Some(index)
  }
  index
}

///|
/// merge_oneway/basic_merge keeps deleted edges in the redirect chain so a
/// subsequent merge propagates weight through every downstream representative.
fn ConcentrateFastGraph::merge_weight(
  self : ConcentrateFastGraph,
  source : Int,
  target : Int,
) -> Unit {
  let edge = self.edges[source]
  guard edge.to_virtual != Some(target) &&
    self.edges[target].to_virtual != Some(source) else {
    return
  }
  guard edge.to_virtual is None else { abort("fast edge already redirected") }
  edge.to_virtual = Some(target)
  let mut current = Some(target)
  while current is Some(index) {
    self.edges[index].weight += edge.weight
    current = self.edges[index].to_virtual
  }
}

///|
priv enum ConcentrateSweep {
  Down
  Up
}

///|
fn ConcentrateFastGraph::merge_node(
  self : ConcentrateFastGraph,
  kept : String,
  removed : String,
  sweep : ConcentrateSweep,
) -> Unit {
  let (leaving, entering) = match sweep {
    Down => (self.outgoing, self.incoming)
    Up => (self.incoming, self.outgoing)
  }
  let removed_edges = leaving.get(removed).unwrap_or_default()
  while removed_edges.length() > 0 {
    let index = removed_edges[0]
    let edge = self.edges[index]
    let neighbor = match sweep {
      Down => edge.head
      Up => edge.tail
    }
    let mut existing : Int? = None
    for candidate in leaving.get(kept).unwrap_or_default() {
      let other = self.edges[candidate]
      let endpoint = match sweep {
        Down => other.head
        Up => other.tail
      }
      if endpoint == neighbor {
        existing = Some(candidate)
        break
      }
    }
    let representative = existing.unwrap_or_else(() => {
      match sweep {
        Down => self.copy_edge(kept, neighbor, index)
        Up => self.copy_edge(neighbor, kept, index)
      }
    })
    let crossing = entering.get(removed).unwrap_or_default()
    while crossing.length() > 0 {
      let absorbed = crossing[0]
      self.merge_weight(absorbed, representative)
      self.delete_edge(absorbed)
    }
    self.delete_edge(index)
  }
}
