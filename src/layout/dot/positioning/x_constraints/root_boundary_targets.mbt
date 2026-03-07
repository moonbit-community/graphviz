///|
/// Graphviz parity: when root boundary slack nodes are enabled (compress mode),
/// each non-empty rank contributes its leftmost/rightmost node once.
fn append_missing_rank_boundary_targets(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  root_ln_targets : Array[String],
  root_rn_targets : Array[String],
) -> Unit {
  let ln_seen : Map[String, Bool] = Map::new()
  let rn_seen : Map[String, Bool] = Map::new()
  for name in root_ln_targets {
    ln_seen[name] = true
  }
  for name in root_rn_targets {
    rn_seen[name] = true
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(value) => value
      None => []
    }
    if names.length() == 0 {
      continue
    }
    let left_name = names[0]
    let right_name = names[names.length() - 1]
    if ln_seen.get(left_name) is None {
      root_ln_targets.push(left_name)
      ln_seen[left_name] = true
    }
    if rn_seen.get(right_name) is None {
      root_rn_targets.push(right_name)
      rn_seen[right_name] = true
    }
  }
}
