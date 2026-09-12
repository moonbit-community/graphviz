// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Graphviz parity: parallel-offset ordering keeps edge-orientation flags from
/// staged edge_tail/edge_head arrays.
/// Do not change behavior without updating fixtures/tests.
fn edge_endpoints_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (String, String) {
  let tail = if edge_idx < edge_tail.length() {
    edge_tail[edge_idx]
  } else {
    edge.tail().name()
  }
  let head = if edge_idx < edge_head.length() {
    edge_head[edge_idx]
  } else {
    edge.head().name()
  }
  (tail, head)
}

///|
fn edge_orientation_is_reversed(
  edge : @cgraph.Edge,
  tail_name : String,
  head_name : String,
) -> Bool {
  tail_name == edge.head().name() && head_name == edge.tail().name()
}

///|
/// Graphviz parity: parallel-offset ordering keeps edge-orientation flags from
/// staged edge_tail/edge_head arrays.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_parallel_offset_edge_flags(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (Map[Int, Bool], Map[Int, Bool]) {
  let edge_reversed_by_id : Map[Int, Bool] = Map([])
  let edge_has_label_by_id : Map[Int, Bool] = Map([])
  for i in 0..<edges.length() {
    let edge = edges[i]
    let (oriented_tail, oriented_head) = edge_endpoints_at(
      edge, i, edge_tail, edge_head,
    )
    let reversed = edge_orientation_is_reversed(
      edge, oriented_tail, oriented_head,
    )
    edge_reversed_by_id[edge.id()] = reversed
    edge_has_label_by_id[edge.id()] = @edge_semantics.edge_has_label(edge)
  }
  (edge_reversed_by_id, edge_has_label_by_id)
}

///|
/// Graphviz parity: parallel offsets group by unordered endpoints/ports (set of
/// tail/head), and only for unlabeled edges (class2 merge_chain).
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ParallelOffsetsBuildInput {
  edges : Array[@cgraph.Edge]
  edge_has_label_by_id : Map[Int, Bool]
  ranks : Map[String, Int]
  nodesep_pt : Double
  edge_reversed_by_id : Map[Int, Bool]
  cluster_keys : Map[String, String]
  concentrated_ignored_edge_ids : Map[Int, Bool]
}

///|
/// class2 keeps a forward chain when opposite concentrated edges meet,
/// regardless of which direction appeared first in the input.
pub fn collect_concentrated_edge_ids(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  concentrate : Bool,
) -> Map[Int, Bool] {
  let ignored_edge_ids : Map[Int, Bool] = Map([])
  if !concentrate {
    return ignored_edge_ids
  }
  let cluster_keys : Map[String, String] = Map([])
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    cluster_keys[tail] = @membership.node_cluster_key(edge.tail())
    cluster_keys[head] = @membership.node_cluster_key(edge.head())
    let forward = ranks.get(tail).unwrap_or_default() <=
      ranks.get(head).unwrap_or_default()
    edge_tail.push(if forward { tail } else { head })
    edge_head.push(if forward { head } else { tail })
  }
  let ports_equal = (a : @cgraph.Edge, b : @cgraph.Edge) => {
    @edge_ops.edge_parallel_key(
      a.tail().name(),
      a.head().name(),
      a.tail_port(),
      a.head_port(),
    ) ==
    @edge_ops.edge_parallel_key(
      b.tail().name(),
      b.head().name(),
      b.tail_port(),
      b.head_port(),
    )
  }
  let metadata = @order_graph.build_reverse_merge_metadata(
    {
      edges,
      edge_tail,
      edge_head,
      edge_excluded_from_reverse_merge: edge => {
        @edge_semantics.edge_has_label(edge) ||
        ranks.get(edge.tail().name()) == ranks.get(edge.head().name())
      },
      edge_ports_equal: ports_equal,
    },
    initial_metadata=@order_graph.build_parallel_merge_metadata(
      edges, ranks, cluster_keys, ports_equal,
    ),
  )
  for index, _ in metadata.merged_edge_skip {
    let edge = edges[index]
    guard cluster_keys.get(edge.tail().name()) ==
      cluster_keys.get(edge.head().name()) else {
      continue
    }
    ignored_edge_ids[edge.id()] = true
  }
  ignored_edge_ids
}

///|
/// After `dot_concentrate` absorbs part of an original class2 chain, Graphviz
/// keeps the original edge in DOT but gives it no spline. Exact parallel
/// edges are handled above; this records only edges marked by the post-
/// mincross concentrate pass, rather than guessing from endpoint equality.
pub fn mark_absorbed_concentrated_edge_ids(
  edges : Array[@cgraph.Edge],
  concentrate : Bool,
  ignored_edge_ids : Map[Int, Bool],
) -> Unit {
  if !concentrate {
    return
  }
  for edge in edges {
    if edge.get_attr("_concentrated_absorbed") == Some("true") {
      ignored_edge_ids[edge.id()] = true
    }
  }
}

///|
fn matching_reverse_concentrated_edge(
  edge : @cgraph.Edge,
  candidate : @cgraph.Edge,
) -> Bool {
  edge.tail().name() == candidate.head().name() &&
  edge.head().name() == candidate.tail().name() &&
  @edge_identity.port_key(edge.tail_port()) ==
  @edge_identity.port_key(candidate.head_port()) &&
  @edge_identity.port_key(edge.head_port()) ==
  @edge_identity.port_key(candidate.tail_port())
}

///|
/// A concentrated reverse edge contributes the second arrowhead to its routed
/// representative. Keep that relationship internal so the original `dir`
/// attribute remains unchanged in DOT output.
pub fn mark_concentrated_reverse_representatives(
  edges : Array[@cgraph.Edge],
  ignored_edge_ids : Map[Int, Bool],
) -> Unit {
  for edge in edges {
    if ignored_edge_ids.get(edge.id()) is Some(_) {
      continue
    }
    for candidate in edges {
      if ignored_edge_ids.get(candidate.id()) is Some(_) &&
        matching_reverse_concentrated_edge(edge, candidate) {
        edge.set_attr("_concentrated_reverse", "true")
        break
      }
    }
  }
}

///|
pub fn build_edge_parallel_offsets(
  input : ParallelOffsetsBuildInput,
) -> Map[Int, Double] {
  let edges = input.edges
  let edge_has_label_by_id = input.edge_has_label_by_id
  let ranks = input.ranks
  let nodesep_pt = input.nodesep_pt
  let edge_reversed_by_id = input.edge_reversed_by_id
  let cluster_keys = input.cluster_keys
  let concentrated_ignored_edge_ids = input.concentrated_ignored_edge_ids
  let concentrate = @order_graph.graphviz_concentrate_enabled(edges)
  let groups : Map[String, Array[Int]] = Map([])
  let group_first_dir_attr : Map[String, String] = Map([])
  let group_has_mixed_dir_attr : Map[String, Bool] = Map([])
  let sameport_marked : Map[Int, Bool] = Map([])
  let edge_by_id : Map[Int, @cgraph.Edge] = Map([])
  let has_self_edge : Map[String, Bool] = Map([])
  for edge in edges {
    edge_by_id[edge.id()] = edge
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      has_self_edge[tail] = true
    }
  }
  for edge in edges {
    if concentrated_ignored_edge_ids.get(edge.id()) is Some(_) {
      continue
    }
    let has_label = match edge_has_label_by_id.get(edge.id()) {
      Some(value) => value
      None => false
    }
    if has_label {
      continue
    }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    if orig_tail == orig_head {
      continue
    }
    let tail_rank = match ranks.get(orig_tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(orig_head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    let key = @edge_ops.edge_parallel_key(
      orig_tail,
      orig_head,
      edge.tail_port(),
      edge.head_port(),
    )
    let dir_attr = @edge_ops.edge_dir_attr_key(edge)
    let mark = @edge_ops.edge_has_sameport_mark(edge)
    sameport_marked[edge.id()] = mark
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_dir_attr.get(key) {
      Some(first_dir) =>
        if first_dir != dir_attr {
          group_has_mixed_dir_attr[key] = true
        }
      None => {
        group_first_dir_attr[key] = dir_attr
        group_has_mixed_dir_attr[key] = false
      }
    }
  }
  let offsets : Map[Int, Double] = Map([])
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    let first = edge_by_id[ids[0]]
    // Ordinary concentrated edges that survived class2 own independent fast
    // chains. They are separate MAINGRAPH routes, not offset multi-edge copies.
    if concentrate &&
      cluster_keys.get(first.tail().name()).unwrap_or_default() ==
      cluster_keys.get(first.head().name()).unwrap_or_default() {
      continue
    }
    ids.sort_by((a, b) => {
      let a_mark = match sameport_marked.get(a) {
        Some(value) => if value { 1 } else { 0 }
        None => 0
      }
      let b_mark = match sameport_marked.get(b) {
        Some(value) => if value { 1 } else { 0 }
        None => 0
      }
      if a_mark != b_mark {
        b_mark - a_mark
      } else {
        a - b
      }
    })
    let mixed_dir = match group_has_mixed_dir_attr.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_dir {
      let mut left = 0
      let mut right = ids.length()
      while left + 1 < right {
        right = right - 1
        let tmp = ids[left]
        ids[left] = ids[right]
        ids[right] = tmp
        left = left + 1
      }
    }
    // Graphviz parity: for reverse-edge pairs, prefer the tail without a
    // self-loop first. This matches class2/dotsplines slot assignment on NaN.gv.
    if ids.length() == 2 {
      let edge0 = edge_by_id.get(ids[0])
      let edge1 = edge_by_id.get(ids[1])
      match (edge0, edge1) {
        (Some(a), Some(b)) => {
          let a_tail = a.tail().name()
          let a_head = a.head().name()
          let b_tail = b.tail().name()
          let b_head = b.head().name()
          if a_tail == b_head && a_head == b_tail {
            let a_tail_cluster = match cluster_keys.get(a_tail) {
              Some(value) => value
              None => ""
            }
            let a_head_cluster = match cluster_keys.get(a_head) {
              Some(value) => value
              None => ""
            }
            let intercluster = a_tail_cluster != a_head_cluster &&
              (a_tail_cluster != "" || a_head_cluster != "")
            let a_tail_has_self = match has_self_edge.get(a_tail) {
              Some(value) => value
              None => false
            }
            let b_tail_has_self = match has_self_edge.get(b_tail) {
              Some(value) => value
              None => false
            }
            // Graphviz parity: reverse-pair slot ordering applies to regular
            // intra-cluster pairs (rowe), but cluster-crossing pairs (clust2)
            // keep cluster-constrained ordering.
            if !intercluster && a_tail_has_self == b_tail_has_self {
              let a_reversed = match edge_reversed_by_id.get(ids[0]) {
                Some(value) => value
                None => false
              }
              let b_reversed = match edge_reversed_by_id.get(ids[1]) {
                Some(value) => value
                None => false
              }
              if !a_reversed && b_reversed {
                let tmp = ids[0]
                ids[0] = ids[1]
                ids[1] = tmp
              }
            }
            if a_tail_has_self && !b_tail_has_self {
              let tmp = ids[0]
              ids[0] = ids[1]
              ids[1] = tmp
            }
          }
        }
        _ => ()
      }
    }
    let count = ids.length()
    let dx = nodesep_pt * Double::from_int(count - 1) / 2.0
    for i in 0..<count {
      let offset = dx - Double::from_int(i) * nodesep_pt
      // Concentrated cluster duplicates are ND_other copies of a live main
      // edge: dotsplines installs the main at -dx, then advances by Multisep.
      offsets[ids[i]] = if concentrate { -offset } else { offset }
    }
  }
  offsets
}
