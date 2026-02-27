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
    let (component_groups, filtered_out, filtered_in) =
      prepare_rank_group_component_merge_inputs(
        rank_keys,
        groups,
        graphviz_out_neighbors,
        graphviz_in_neighbors,
        component,
      )
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
  dedup_rank_groups_graphviz_merged(rank_keys, merged)
}
