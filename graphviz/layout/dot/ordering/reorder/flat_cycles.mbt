// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
// mincross.c flat_search: a back edge always contributes the reversed matrix
// entry, but only an ordinary edge is reinserted into the flat graph.
fn break_flat_cycles(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  constraints : Map[String, Bool],
  edge_tail : Array[String],
  edge_head : Array[String],
  edges? : Array[@cgraph.Edge] = [],
) -> (Map[String, Bool], Map[String, Bool]) {
  let topology : Map[String, Bool] = Map([])
  let matrix : Map[String, Bool] = Map([])
  let ordinary : Map[String, Bool] = Map([])
  let outgoing : Map[String, Array[String]] = Map([])
  let installed : Map[String, Bool] = Map([])
  let install = (tail : String, head : String) => {
    let key = "\{tail}|\{head}"
    guard constraints.get(key) == Some(true) &&
      ranks.get(tail) == ranks.get(head) &&
      installed.get(key) != Some(true) else {
      return
    }
    installed[key] = true
    topology[key] = true
    guard outgoing.get(tail) is Some(heads) else {
      outgoing[tail] = [head]
      return
    }
    heads.push(head)
  }
  // class2 installs ordinary flat edges before ordered_edges appends FLATORDER.
  let scan_order = []
  for index in 0..<edge_tail.length() {
    scan_order.push(index)
  }
  // class2 scans agfstnode/agfstout: outgoing edges are ordered by the
  // original head node id, not by edge statement order. Keep parallel ties
  // in edge-id order before flat_search mutates the live adjacency lists.
  if edges.length() == scan_order.length() {
    scan_order.sort_by((a, b) => {
      let tail_order = edges[a].tail().id.compare(edges[b].tail().id)
      guard tail_order == 0 else { return tail_order }
      let head_order = edges[a].head().id.compare(edges[b].head().id)
      guard head_order == 0 else { return head_order }
      edges[a].id().compare(edges[b].id())
    })
  }
  for index in scan_order {
    let tail = edge_tail[index]
    let head = edge_head[index]
    ordinary["\{tail}|\{head}"] = true
    install(tail, head)
  }
  for key, enabled in constraints {
    guard enabled else { continue }
    guard @rank_constraints.parse_flat_constraint_key(key) is Some((tail, head)) else {
      continue
    }
    install(tail, head)
  }
  let marked : Map[String, Bool] = Map([])
  let on_stack : Map[String, Bool] = Map([])
  for rank in rank_keys {
    for start in groups.get(rank).unwrap_or([]) {
      guard marked.get(start) != Some(true) else { continue }
      let stack : Array[(String, Int)] = [(start, 0)]
      marked[start] = true
      on_stack[start] = true
      while stack.length() > 0 {
        let top = stack.length() - 1
        let (tail, index) = stack[top]
        let heads = outgoing.get(tail).unwrap_or([])
        guard index < heads.length() else {
          on_stack[tail] = false
          let _ = stack.pop()
          continue
        }
        let head = heads[index]
        if on_stack.get(head) == Some(true) {
          matrix["\{head}|\{tail}"] = true
          topology["\{tail}|\{head}"] = false
          let last = heads[heads.length() - 1]
          let _ = heads.pop()
          if index < heads.length() {
            heads[index] = last
          }
          if ordinary.get("\{tail}|\{head}") == Some(true) &&
            topology.get("\{head}|\{tail}") != Some(true) {
            topology["\{head}|\{tail}"] = true
            outgoing
            .get(head)
            .unwrap_or_else(() => {
              let heads = []
              outgoing[head] = heads
              heads
            })
            .push(tail)
          }
        } else {
          matrix["\{tail}|\{head}"] = true
          stack[top] = (tail, index + 1)
          if marked.get(head) != Some(true) {
            marked[head] = true
            on_stack[head] = true
            stack.push((head, 0))
          }
        }
      }
    }
  }
  // zapinlist moves the last edge into a deleted slot. Preserve that live
  // adjacency order for flat_reorder, rather than the original map order.
  let reordered_topology : Map[String, Bool] = Map([])
  for key, enabled in topology {
    guard !enabled else { continue }
    reordered_topology[key] = false
  }
  for tail, heads in outgoing {
    for head in heads {
      reordered_topology["\{tail}|\{head}"] = true
    }
  }
  (reordered_topology, matrix)
}
