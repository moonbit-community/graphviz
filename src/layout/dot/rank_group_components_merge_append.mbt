///|
fn append_rank_group_component_order_to_merged(
  rank_keys : Array[Int],
  merged : Map[Int, Array[String]],
  ordered_component : Map[Int, Array[String]],
) -> Unit {
  for rank in rank_keys {
    let names = match ordered_component.get(rank) {
      Some(list) => list
      None => []
    }
    if names.length() == 0 {
      continue
    }
    let merged_list = match merged.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      merged_list.push(name)
    }
    merged[rank] = merged_list
  }
}
