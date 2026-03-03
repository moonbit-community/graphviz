///|
fn parallel_remap_edge_has_label(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("label") {
    Some(value) => value != ""
    None => false
  }
}

///|
/// Graphviz parity: duplicate regular-edge remap groups follow one-direction
/// parallel classes only.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_parallel_remap_edge_ids(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
) -> Array[Array[Int]] {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_direction : Map[String, String] = Map::new()
  let group_has_mixed_direction : Map[String, Bool] = Map::new()
  for edge in edges {
    if parallel_remap_edge_has_label(edge) {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      continue
    }
    let tail_rank = ranks.get(tail).unwrap_or_default()
    let head_rank = ranks.get(head).unwrap_or_default()
    if tail_rank == head_rank {
      continue
    }
    let key = @edge_ops.edge_parallel_group_key(edge)
    let sameport_mark = @edge_ops.edge_has_sameport_mark(edge)
    let dir_key = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
    let sameport_tag = if sameport_mark { "sameport" } else { "plain" }
    let direction_key =
      "\{tail}|\{@dot_shared.port_key(edge.tail_port())}|\{head}|\{@dot_shared.port_key(edge.head_port())}|\{dir_key}|\{sameport_tag}"
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_direction.get(key) {
      Some(first_direction) =>
        if first_direction != direction_key {
          group_has_mixed_direction[key] = true
        }
      None => {
        group_first_direction[key] = direction_key
        group_has_mixed_direction[key] = false
      }
    }
  }
  let remap_groups : Array[Array[Int]] = []
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    let mixed_direction = match group_has_mixed_direction.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_direction {
      continue
    }
    ids.sort()
    remap_groups.push(ids)
  }
  remap_groups
}
