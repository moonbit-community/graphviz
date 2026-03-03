///|
/// Graphviz parity: parallel offsets group by unordered endpoints/ports (set of
/// tail/head), and only for unlabeled edges (class2 merge_chain).
/// Do not change behavior without updating fixtures/tests.
pub fn edge_parallel_offsets(
  edges : Array[@cgraph.Edge],
  edge_has_label_by_id : Map[Int, Bool],
  ranks : Map[String, Int],
  _order_index : Map[String, Int],
  nodesep_pt : Double,
  edge_reversed_by_id : Map[Int, Bool],
  cluster_keys : Map[String, String],
) -> Map[Int, Double] {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_dir_attr : Map[String, String] = Map::new()
  let group_has_mixed_dir_attr : Map[String, Bool] = Map::new()
  let sameport_marked : Map[Int, Bool] = Map::new()
  let edge_by_id : Map[Int, @cgraph.Edge] = Map::new()
  let has_self_edge : Map[String, Bool] = Map::new()
  for edge in edges {
    edge_by_id[edge.id()] = edge
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      has_self_edge[tail] = true
    }
  }
  for edge in edges {
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
    let key =
      @edge_ops.edge_parallel_key(
        orig_tail,
        orig_head,
        edge.tail_port(),
        edge.head_port(),
      )
    let dir_attr = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
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
  let offsets : Map[Int, Double] = Map::new()
  for key, ids in groups {
    if ids.length() <= 1 {
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
            let intercluster =
              a_tail_cluster != a_head_cluster &&
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
      offsets[ids[i]] = offset
    }
  }
  offsets
}
