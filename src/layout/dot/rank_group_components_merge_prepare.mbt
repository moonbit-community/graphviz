///|
/// Graphviz parity: component-local merge inputs preserve rank-group filtering
/// and in/out neighbor projection constrained to the component node set.
/// Do not change behavior without updating fixtures/tests.
fn prepare_rank_group_component_merge_inputs(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  component : Array[String],
) -> (
  Map[Int, Array[String]],
  Map[String, Array[String]],
  Map[String, Array[String]],
) {
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
  (component_groups, filtered_out, filtered_in)
}
