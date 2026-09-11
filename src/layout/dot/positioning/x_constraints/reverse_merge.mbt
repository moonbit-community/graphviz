// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn directed_edge_merge_key(
  tail_name : String,
  head_name : String,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
) -> String {
  "\{tail_name}|\{head_name}|\{@edge_identity.port_key(tail_port)}|\{@edge_identity.port_key(head_port)}"
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
  @order_graph.edge_orientation_is_reversed(edge, tail_name, head_name)
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
priv struct ReverseMergeMetadataInput {
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_excluded_from_reverse_merge : (@cgraph.Edge) -> Bool
}

///|
/// Graphviz uses mapbool for concentrate: empty and invalid values are false,
/// while non-zero numeric values are true.
fn graphviz_concentrate_enabled(edges : Array[@cgraph.Edge]) -> Bool {
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
fn build_reverse_merge_metadata(
  input : ReverseMergeMetadataInput,
) -> ReverseMergeMetadata {
  let forward_rep_by_key : Map[String, Int] = Map([])
  let merged_edge_weight_bonus : Map[Int, Int] = Map([])
  let merged_edge_skip : Map[Int, Bool] = Map([])
  for edge_idx in 0..<input.edges.length() {
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
    let key = directed_edge_merge_key(
      edge.tail().name(),
      edge.head().name(),
      edge.tail_port(),
      edge.head_port(),
    )
    if forward_rep_by_key.get(key) is None {
      forward_rep_by_key[key] = edge_idx
    }
  }
  for edge_idx in 0..<input.edges.length() {
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
    let key = directed_edge_merge_key(
      edge.head().name(),
      edge.tail().name(),
      edge.tail_port(),
      edge.head_port(),
    )
    match forward_rep_by_key.get(key) {
      Some(rep_idx) => {
        if rep_idx == edge_idx {
          continue
        }
        merged_edge_skip[edge_idx] = true
        let prev_bonus = merged_edge_weight_bonus
          .get(rep_idx)
          .unwrap_or_default()
        merged_edge_weight_bonus[rep_idx] = prev_bonus +
          @edge_semantics.edge_weight(edge)
      }
      None => ()
    }
  }
  { merged_edge_weight_bonus, merged_edge_skip, }
}
