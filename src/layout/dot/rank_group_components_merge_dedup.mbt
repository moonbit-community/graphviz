///|
/// Graphviz parity: merged per-rank order keeps first-seen occurrence globally
/// so cluster rankleaders appear once across all ranks/components.
/// Do not change behavior without updating fixtures/tests.
fn dedup_rank_groups_graphviz_merged(
  rank_keys : Array[Int],
  merged : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let seen : Map[String, Bool] = Map::new()
  for rank in rank_keys {
    let names = match merged.get(rank) {
      Some(list) => list
      None => []
    }
    let unique : Array[String] = []
    for name in names {
      if seen.get(name) is None {
        seen[name] = true
        unique.push(name)
      }
    }
    merged[rank] = unique
  }
  merged
}
