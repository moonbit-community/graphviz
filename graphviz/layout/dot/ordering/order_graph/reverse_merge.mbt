// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn directed_edge_merge_key(tail_name : String, head_name : String) -> String {
  "\{tail_name}|\{head_name}"
}

///|
fn edge_is_reversed_by_endpoints(
  edge_idx : Int,
  edge : @cgraph.Edge,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Bool {
  let tail_name = if edge_idx < edge_tail.length() {
    edge_tail[edge_idx]
  } else {
    edge.tail().name()
  }
  let head_name = if edge_idx < edge_head.length() {
    edge_head[edge_idx]
  } else {
    edge.head().name()
  }
  edge_orientation_is_reversed(edge, tail_name, head_name)
}

///|
/// Graphviz parity: reverse-edge merge metadata tracks representative forward
/// edges and accumulates skip/weight-bonus overlays for reversed duplicates.
pub(all) struct ReverseMergeMetadata {
  merged_edge_weight_bonus : Map[Int, Int]
  merged_edge_skip : Map[Int, Bool]
}

///|
/// Graphviz parity: reverse-edge merge build consumes edge endpoint remap
/// arrays and an exclusion predicate aligned with label/self-edge rules.
pub(all) struct ReverseMergeMetadataInput {
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_excluded_from_reverse_merge : (@cgraph.Edge) -> Bool
  edge_ports_equal : (@cgraph.Edge, @cgraph.Edge) -> Bool
}

///|
/// Graphviz uses mapbool for concentrate: empty and invalid values are false,
/// while non-zero numeric values are true.
pub fn graphviz_concentrate_enabled(edges : Array[@cgraph.Edge]) -> Bool {
  guard edges.length() > 0 else { false }
  let graph = @membership.root_graph_for_node(edges[0].tail())
  let value = graph
    .get_attr("concentrate")
    .unwrap_or_default()
    .trim()
    .to_lower()
  if value == "true" || value == "yes" {
    true
  } else if value == "" || value == "false" || value == "no" {
    false
  } else if value.get_char(0) is Some(first) && first.is_ascii_digit() {
    let mut number = 0
    for digit in value {
      guard digit.is_ascii_digit() else { break }
      number = number * 10 + digit.to_int() - '0'.to_int()
    }
    number != 0
  } else {
    false
  }
}

///|
/// Graphviz parity: reversed edges merge into their forward representative
/// unless excluded (labels/self-edge), matching constraint-graph assembly.
pub fn build_reverse_merge_metadata(
  input : ReverseMergeMetadataInput,
  initial_metadata? : ReverseMergeMetadata = {
    merged_edge_weight_bonus: Map([]),
    merged_edge_skip: Map([]),
  },
) -> ReverseMergeMetadata {
  let forward_rep_by_key : Map[String, Array[Int]] = Map([])
  let concentrate = graphviz_concentrate_enabled(input.edges)
  let merged_edge_weight_bonus = initial_metadata.merged_edge_weight_bonus
  let merged_edge_skip = initial_metadata.merged_edge_skip
  for edge_idx in 0..<input.edges.length() {
    guard merged_edge_skip.get(edge_idx) is None else { continue }
    let edge = input.edges[edge_idx]
    if (input.edge_excluded_from_reverse_merge)(edge) {
      continue
    }
    let is_reversed = edge_is_reversed_by_endpoints(
      edge_idx,
      edge,
      input.edge_tail,
      input.edge_head,
    )
    if is_reversed {
      continue
    }
    let key = directed_edge_merge_key(edge.tail().name(), edge.head().name())
    if forward_rep_by_key.get(key) is Some(representatives) {
      representatives.push(edge_idx)
    } else {
      forward_rep_by_key[key] = [edge_idx]
    }
  }
  for edge_idx in 0..<input.edges.length() {
    guard merged_edge_skip.get(edge_idx) is None else { continue }
    let edge = input.edges[edge_idx]
    if (input.edge_excluded_from_reverse_merge)(edge) {
      continue
    }
    let is_reversed = edge_is_reversed_by_endpoints(
      edge_idx,
      edge,
      input.edge_tail,
      input.edge_head,
    )
    if !is_reversed {
      continue
    }
    let key = directed_edge_merge_key(edge.head().name(), edge.tail().name())
    guard forward_rep_by_key.get(key) is Some(representatives) else { continue }
    for rep_idx in representatives {
      guard rep_idx != edge_idx else { continue }
      guard (input.edge_ports_equal)(edge, input.edges[rep_idx]) else {
        continue
      }
      merged_edge_skip[edge_idx] = true
      // class2 marks an ordinary concentrated opposite IGNORED without
      // merge_chain: it must not contribute weight to the forward chain.
      if concentrate &&
        @membership.node_cluster_key(edge.tail()) ==
        @membership.node_cluster_key(edge.head()) {
        break
      }
      let prev_bonus = merged_edge_weight_bonus.get(rep_idx).unwrap_or_default()
      merged_edge_weight_bonus[rep_idx] = prev_bonus +
        @edge_semantics.edge_weight(edge) +
        merged_edge_weight_bonus.get(edge_idx).unwrap_or_default()
      break
    }
  }
  { merged_edge_weight_bonus, merged_edge_skip, }
}

///|
/// class2 compares consecutive parallel edges in each outgoing head group.
/// A successful merge keeps the previous representative. Cluster-crossing
/// chains accumulate weight even with concentrate; ordinary concentrated
/// duplicates are ignored instead. Flat edges have their own constraint pass.
pub fn build_parallel_merge_metadata(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  cluster_keys : Map[String, String],
  ports_equal : (@cgraph.Edge, @cgraph.Edge) -> Bool,
) -> ReverseMergeMetadata {
  let previous_by_endpoints : Map[String, Int] = Map([])
  let merged_edge_weight_bonus : Map[Int, Int] = Map([])
  let merged_edge_skip : Map[Int, Bool] = Map([])
  let concentrate = graphviz_concentrate_enabled(edges)
  let precreated = precreated_forward_edges(
    edges, ranks, cluster_keys, ports_equal,
  )
  for edge_idx, edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let key = directed_edge_merge_key(tail, head)
    let previous = previous_by_endpoints.get(key)
    previous_by_endpoints[key] = edge_idx
    guard precreated.get(edge_idx) is None else { continue }
    guard previous is Some(rep_idx) else { continue }
    let representative = edges[rep_idx]
    guard ranks.get(tail) != ranks.get(head) else { continue }
    guard edge.get_attr("label").unwrap_or_default() == "" &&
      representative.get_attr("label").unwrap_or_default() == "" else {
      continue
    }
    let crosses_cluster = cluster_keys.get(tail).unwrap_or_default() !=
      cluster_keys.get(head).unwrap_or_default()
    let same_ports = if crosses_cluster {
      ports_equal(representative, edge)
    } else {
      ports_equal(edge, representative)
    }
    guard same_ports else { continue }
    previous_by_endpoints[key] = rep_idx
    merged_edge_skip[edge_idx] = true
    if !concentrate || crosses_cluster {
      merged_edge_weight_bonus[rep_idx] = merged_edge_weight_bonus
        .get(rep_idx)
        .unwrap_or_default() +
        @edge_semantics.edge_weight(edge)
    }
  }
  { merged_edge_weight_bonus, merged_edge_skip, }
}

///|
/// A backward edge processed before its opposite tail calls make_chain on
/// each opposite candidate before testing ports. Those forward edges later
/// take class2's ED_to_virt early exit, not the parallel-merging branch.
fn precreated_forward_edges(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  cluster_keys : Map[String, String],
  ports_equal : (@cgraph.Edge, @cgraph.Edge) -> Bool,
) -> Map[Int, Bool] {
  let precreated : Map[Int, Bool] = Map([])
  guard edges.length() > 0 else { precreated }
  let root = @membership.root_graph_for_node(edges[0].tail())
  let node_order : Map[String, Int] = Map([])
  for index, node in root.nodes() {
    node_order[node.name()] = index
  }
  for backward in edges {
    let tail = backward.tail().name()
    let head = backward.head().name()
    guard ranks.get(tail).unwrap_or_default() >
      ranks.get(head).unwrap_or_default() else {
      continue
    }
    guard node_order.get(tail).unwrap_or_default() <
      node_order.get(head).unwrap_or_default() else {
      continue
    }
    guard cluster_keys.get(tail).unwrap_or_default() ==
      cluster_keys.get(head).unwrap_or_default() else {
      continue
    }
    for index, forward in edges {
      guard forward.tail().name() == head && forward.head().name() == tail else {
        continue
      }
      precreated[index] = true
      if backward.get_attr("label").unwrap_or_default() == "" &&
        forward.get_attr("label").unwrap_or_default() == "" &&
        ports_equal(backward, forward) {
        break
      }
    }
  }
  precreated
}
