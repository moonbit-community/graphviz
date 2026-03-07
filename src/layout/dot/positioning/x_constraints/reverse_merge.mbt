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
  let tail_name =
    if edge_idx < edge_tail.length() {
      edge_tail[edge_idx]
    } else {
      edge.tail().name()
    }
  let head_name =
    if edge_idx < edge_head.length() {
      edge_head[edge_idx]
    } else {
      edge.head().name()
    }
  @ordering.edge_orientation_is_reversed(edge, tail_name, head_name)
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
}

///|
/// Graphviz parity: reversed edges merge into their forward representative
/// unless excluded (labels/self-edge), matching constraint-graph assembly.
pub fn build_reverse_merge_metadata(
  input : ReverseMergeMetadataInput,
) -> ReverseMergeMetadata {
  let forward_rep_by_key : Map[String, Int] = Map::new()
  let merged_edge_weight_bonus : Map[Int, Int] = Map::new()
  let merged_edge_skip : Map[Int, Bool] = Map::new()
  for edge_idx in 0..<input.edges.length() {
    let edge = input.edges[edge_idx]
    if (input.edge_excluded_from_reverse_merge)(edge) {
      continue
    }
    let is_reversed =
      edge_is_reversed_by_endpoints(
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
    let is_reversed =
      edge_is_reversed_by_endpoints(
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
        let prev_bonus = merged_edge_weight_bonus.get(rep_idx).unwrap_or_default()
        merged_edge_weight_bonus[rep_idx] = prev_bonus + @edge_semantics.edge_weight(edge)
      }
      None => ()
    }
  }
  { merged_edge_weight_bonus, merged_edge_skip }
}
