///|
/// Extracted from layout_pipeline_stage_c_remincross_cluster_tail_order_helpers.mbt
/// to isolate Stage C clustered tail-order non-root rank phases.

///|
/// Graphviz parity: clustered tail-order non-root phase preserves rank-key
/// collection, descending rank replay, and input-like category rebucketing.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_tail_order_nonroot_names(
  cluster : String,
  names : Array[String],
  rem_ranks : Map[String, Int],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let rank_keys : Array[Int] = []
  let rank_seen : Map[Int, Bool] = Map::new()
  for name in names {
    let rank = match rem_ranks.get(name) {
      Some(value) => value
      None => -1
    }
    if rank_seen.get(rank) is None {
      rank_seen[rank] = true
      rank_keys.push(rank)
    }
  }
  rank_keys.sort()
  let min_rank = {
    let mut candidate = -1
    for value in rank_keys {
      if value >= 0 {
        candidate = value
        break
      }
    }
    candidate
  }
  let cluster_rank_ordered : Array[String] = []
  let mut rank_idx = rank_keys.length()
  while rank_idx > 0 {
    rank_idx = rank_idx - 1
    let rank = rank_keys[rank_idx]
    let rank_names : Array[String] = []
    for name in names {
      let name_rank = match rem_ranks.get(name) {
        Some(value) => value
        None => -1
      }
      if name_rank == rank {
        rank_names.push(name)
      }
    }
    let rank_ordered : Array[String] = []
    let mut all_without_outgoing = true
    for name in rank_names {
      if heads_by_tail.get(name) is Some(_) {
        all_without_outgoing = false
        break
      }
    }
    if cluster != "" && all_without_outgoing {
      for name in rank_names {
        rank_ordered.push(name)
      }
    } else {
      let mut name_idx = rank_names.length()
      while name_idx > 0 {
        name_idx = name_idx - 1
        rank_ordered.push(rank_names[name_idx])
      }
    }
    let mut all_input_like = true
    for name in rank_ordered {
      if !name.has_prefix("i-") {
        all_input_like = false
        break
      }
    }
    if rank == min_rank && rank_ordered.length() > 1 && all_input_like {
      let current_cluster_pos = match cluster_order_pos.get(cluster) {
        Some(value) => value
        None => 0
      }
      let category0 : Array[String] = []
      let category1 : Array[String] = []
      let category2 : Array[String] = []
      let category3 : Array[String] = []
      for name in rank_ordered {
        let heads = match heads_by_tail.get(name) {
          Some(list) => list
          None => []
        }
        let mut has_later = false
        let mut has_earlier = false
        for head in heads {
          let head_cluster =
            cluster_key_for_remincross_tail_order_name(rem_cluster_keys, head)
          if head_cluster == cluster {
            continue
          }
          let head_pos = match cluster_order_pos.get(head_cluster) {
            Some(value) => value
            None => cluster_order.length()
          }
          if head_pos > current_cluster_pos {
            has_later = true
          } else if head_pos < current_cluster_pos {
            has_earlier = true
          }
        }
        let out_degree = heads.length()
        if !has_later && !has_earlier && out_degree > 1 {
          category0.push(name)
        } else if has_later {
          category1.push(name)
        } else if has_earlier {
          category2.push(name)
        } else {
          category3.push(name)
        }
      }
      let reordered_rank : Array[String] = []
      for name in category0 {
        reordered_rank.push(name)
      }
      for name in category1 {
        reordered_rank.push(name)
      }
      for name in category2 {
        reordered_rank.push(name)
      }
      for name in category3 {
        reordered_rank.push(name)
      }
      let mut idx = 0
      while idx < reordered_rank.length() {
        rank_ordered[idx] = reordered_rank[idx]
        idx = idx + 1
      }
    }
    for name in rank_ordered {
      cluster_rank_ordered.push(name)
    }
  }
  cluster_rank_ordered
}
