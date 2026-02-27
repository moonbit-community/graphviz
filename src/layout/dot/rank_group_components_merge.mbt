///|
/// Graphviz parity: per-component rank-group ordering preserves component-local
/// neighbor filtering and merge order before final deduplication.
/// Do not change behavior without updating fixtures/tests.
fn merge_rank_groups_graphviz_components(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  pass : Int,
  flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  components : Array[Array[String]],
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    merged[rank] = []
  }
  for component in components {
    let component_set : Map[String, Bool] = Map::new()
    for name in component {
      component_set[name] = true
    }
    let component_groups : Map[Int, Array[String]] = Map::new()
    for rank in rank_keys {
      let names = match groups.get(rank) {
        Some(list) => list
        None => []
      }
      let filtered : Array[String] = []
      for name in names {
        if component_set.get(name) is Some(_) {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        component_groups[rank] = filtered
      }
    }
    let filtered_out : Map[String, Array[String]] = Map::new()
    let filtered_in : Map[String, Array[String]] = Map::new()
    for name in component {
      let out = match graphviz_out_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      let filtered_out_list : Array[String] = []
      for other in out {
        if component_set.get(other) is Some(_) {
          filtered_out_list.push(other)
        }
      }
      filtered_out[name] = filtered_out_list
      let inn = match graphviz_in_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      let filtered_in_list : Array[String] = []
      for other in inn {
        if component_set.get(other) is Some(_) {
          filtered_in_list.push(other)
        }
      }
      filtered_in[name] = filtered_in_list
    }
    let ordered_component = build_rank_groups_graphviz(
      rank_keys,
      component_groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      pass,
      flip=flip,
      graphviz_out_neighbors=filtered_out,
      graphviz_in_neighbors=filtered_in,
    )
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
  // Graphviz parity: cluster rankleaders should appear once per cluster.
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
