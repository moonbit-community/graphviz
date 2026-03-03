///|
/// Ordering domain: connected-component traversal and projection helpers for
/// root mincross reorder inputs.

///|
/// Graphviz parity: non-cluster mincross traverses connected components in
/// GD_nlist order (real nodes first), then runs mincross on each component.
/// Do not change behavior without updating fixtures/tests.
fn resolve_root_component_order_index(
  name : String,
  order_node_order : Map[String, Int],
  fallback_order : Map[String, Int],
) -> Int {
  match order_node_order.get(name) {
    Some(value) => value
    None =>
      match fallback_order.get(name) {
        Some(value) => value
        None => 0
      }
  }
}

///|
/// Graphviz parity: flat-constraint adjacency contributes undirected traversal
/// links for non-cluster connected-component discovery.
/// Do not change behavior without updating fixtures/tests.
priv struct FlatConstraintAdjacency {
  flat_out : Map[String, Array[String]]
  flat_in : Map[String, Array[String]]
}

///|
/// Graphviz parity: component traversal starts keep sorted root order and
/// preferred non-vnode starts for the first DFS pass.
/// Do not change behavior without updating fixtures/tests.
priv struct ComponentTraversalStarts {
  start_nodes : Array[String]
  traversal_starts : Array[String]
}

///|
/// Graphviz parity: component traversal adjacency combines graphviz in/out
/// neighbors with flat-constraint links for one node-set projection.
/// Do not change behavior without updating fixtures/tests.
priv struct ComponentTraversalAdjacency {
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
  flat_out : Map[String, Array[String]]
  flat_in : Map[String, Array[String]]
}

///|
/// Graphviz parity: enabled flat constraints add traversal links only when
/// both endpoints exist in the current root node membership projection.
fn build_flat_constraint_adjacency(
  order_nodes : Array[String],
  node_set : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> FlatConstraintAdjacency {
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    flat_out[name] = []
    flat_in[name] = []
  }
  for key, enabled in flat_constraints {
    if !enabled {
      continue
    }
    match @shared.parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        if tail == "" || head == "" {
          continue
        }
        if node_set.get(tail) is None || node_set.get(head) is None {
          continue
        }
        match flat_out.get(tail) {
          Some(list) => list.push(head)
          None => flat_out[tail] = [head]
        }
        match flat_in.get(head) {
          Some(list) => list.push(tail)
          None => flat_in[head] = [tail]
        }
      }
      None => ()
    }
  }
  { flat_out, flat_in }
}

///|
/// Graphviz parity: non-cluster traversal starts are sorted by root node order,
/// then biased to real nodes before edge-vnode starts.
/// Do not change behavior without updating fixtures/tests.
fn build_component_traversal_starts(
  order_nodes : Array[String],
  order_node_order : Map[String, Int],
) -> ComponentTraversalStarts {
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in order_nodes {
    fallback_order[name] = i
  }
  let start_nodes = order_nodes.copy()
  if start_nodes.length() > 1 {
    start_nodes.sort_by((a, b) => {
      let a_idx =
        resolve_root_component_order_index(
          a,
          order_node_order,
          fallback_order,
        )
      let b_idx =
        resolve_root_component_order_index(
          b,
          order_node_order,
          fallback_order,
        )
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
  }
  let preferred_start_nodes : Array[String] = []
  for name in start_nodes {
    if !name.has_prefix(EDGE_VNODE_PREFIX) {
      preferred_start_nodes.push(name)
    }
  }
  let traversal_starts =
    if preferred_start_nodes.length() > 0 { preferred_start_nodes } else { start_nodes }
  { start_nodes, traversal_starts }
}

///|
/// Graphviz parity: non-cluster component traversal uses graphviz in/out
/// neighbors plus flat-constraint adjacency over the active node-set.
/// Do not change behavior without updating fixtures/tests.
fn build_component_traversal_adjacency(
  order_nodes : Array[String],
  node_set : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  flat_constraints : Map[String, Bool],
) -> ComponentTraversalAdjacency {
  let out_neighbors =
    filter_component_neighbor_map(
      order_nodes,
      node_set,
      graphviz_out_neighbors,
    )
  let in_neighbors =
    filter_component_neighbor_map(
      order_nodes,
      node_set,
      graphviz_in_neighbors,
    )
  let flat_adjacency =
    build_flat_constraint_adjacency(
      order_nodes,
      node_set,
      flat_constraints,
    )
  {
    out_neighbors,
    in_neighbors,
    flat_out: flat_adjacency.flat_out,
    flat_in: flat_adjacency.flat_in,
  }
}

///|
/// Graphviz parity: component DFS replays preferred starts first, then full
/// starts, preserving visit-order within each connected component.
/// Do not change behavior without updating fixtures/tests.
fn collect_components_from_traversal(
  order_nodes : Array[String],
  node_set : Map[String, Bool],
  traversal_starts : ComponentTraversalStarts,
  adjacency : ComponentTraversalAdjacency,
) -> Array[Array[String]] {
  let visited : Map[String, Bool] = Map::new()
  for name in order_nodes {
    visited[name] = false
  }
  let components : Array[Array[String]] = []
  let stack : Array[String] = []
  let push_neighbors = (list : Array[String]) => {
    let mut idx = list.length()
    while idx > 0 {
      idx = idx - 1
      let other = list[idx]
      if node_set.get(other) is None {
        continue
      }
      if visited.get(other) != Some(true) {
        stack.push(other)
      }
    }
  }
  let visit_start = (start : String) => {
    if visited.get(start) == Some(true) {
      ()
    } else {
      let component : Array[String] = []
      stack.push(start)
      while stack.length() > 0 {
        let current = stack[stack.length() - 1]
        let _ = stack.pop()
        if visited.get(current) == Some(true) {
          continue
        }
        visited[current] = true
        component.push(current)
        let fin = adjacency.flat_in.get(current).unwrap_or_default()
        let fout = adjacency.flat_out.get(current).unwrap_or_default()
        let inn = adjacency.in_neighbors.get(current).unwrap_or_default()
        let out = adjacency.out_neighbors.get(current).unwrap_or_default()
        push_neighbors(fin)
        push_neighbors(fout)
        push_neighbors(inn)
        push_neighbors(out)
      }
      if component.length() > 0 {
        components.push(component)
      }
    }
  }
  for start in traversal_starts.traversal_starts {
    visit_start(start)
  }
  for start in traversal_starts.start_nodes {
    visit_start(start)
  }
  components
}

///|
/// Graphviz parity: non-cluster mincross traverses connected components in
/// GD_nlist order (real nodes first), then runs mincross on each component.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_noncluster_components(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  order_node_order : Map[String, Int],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  flat_constraints : Map[String, Bool],
) -> Array[Array[String]] {
  let order_nodes = build_order_nodes_from_groups(groups, rank_keys)
  if order_nodes.length() == 0 {
    return []
  }
  let node_set = build_node_membership_set(order_nodes)
  let traversal_starts =
    build_component_traversal_starts(
      order_nodes,
      order_node_order,
    )
  let adjacency =
    build_component_traversal_adjacency(
      order_nodes,
      node_set,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      flat_constraints,
    )
  collect_components_from_traversal(
    order_nodes,
    node_set,
    traversal_starts,
    adjacency,
  )
}

///|
pub fn filter_component_neighbor_map(
  component_nodes : Array[String],
  component_set : Map[String, Bool],
  neighbors : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let filtered : Map[String, Array[String]] = Map::new()
  for name in component_nodes {
    let values = match neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let keep : Array[String] = []
    for other in values {
      if component_set.get(other) is Some(_) {
        keep.push(other)
      }
    }
    filtered[name] = keep
  }
  filtered
}

///|
pub fn filter_component_positions(
  component_set : Map[String, Bool],
  positions : Map[String, Double],
) -> Map[String, Double] {
  let filtered : Map[String, Double] = Map::new()
  for name, value in positions {
    if component_set.get(name) is Some(_) {
      filtered[name] = value
    }
  }
  filtered
}

///|
pub fn filter_component_port_order_contrib(
  component_set : Map[String, Bool],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[String, Array[(String, Double)]] {
  let component_port_order_contrib : Map[String, Array[(String, Double)]] =
    Map::new()
  for name, entries in port_order_contrib {
    if component_set.get(name) is None {
      continue
    }
    let keep : Array[(String, Double)] = []
    for entry in entries {
      let (other, weight) = entry
      if component_set.get(other) is Some(_) {
        keep.push((other, weight))
      }
    }
    component_port_order_contrib[name] = keep
  }
  component_port_order_contrib
}

///|
pub fn filter_component_flat_constraints(
  component_set : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
) -> Map[String, Bool] {
  let component_flat_constraints : Map[String, Bool] = Map::new()
  for key, enabled in order_flat_constraints {
    if !enabled {
      continue
    }
    match @shared.parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        if tail == "" || head == "" {
          continue
        }
        if component_set.get(tail) is Some(_) && component_set.get(head) is Some(_) {
          component_flat_constraints[key] = true
        }
      }
      None => ()
    }
  }
  component_flat_constraints
}

pub fn has_non_empty_cluster_keys(order_cluster_keys : Map[String, String]) -> Bool {
  for _name, cluster in order_cluster_keys {
    if cluster != "" {
      return true
    }
  }
  false
}
