///|
/// Stage C Phase C2 split: root mincross/replay helpers
/// for primary crossing-reduction ordering passes.

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
    match @dot_shared.parse_flat_constraint_key(key) {
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
fn collect_noncluster_components(
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
fn filter_component_neighbor_map(
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
fn filter_component_positions(
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
fn filter_component_port_order_contrib(
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
fn filter_component_flat_constraints(
  component_set : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
) -> Map[String, Bool] {
  let component_flat_constraints : Map[String, Bool] = Map::new()
  for key, enabled in order_flat_constraints {
    if !enabled {
      continue
    }
    match @dot_shared.parse_flat_constraint_key(key) {
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

///|
fn filter_component_rank_groups(
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  component_set : Map[String, Bool],
) -> Map[Int, Array[String]] {
  // Graphviz parity: component reorder keeps each rank's relative extraction
  // order from the full group list before running mincross on that component.
  let component_groups : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys_for_mincross {
    let names = order_groups_for_mincross.get(rank).unwrap_or_default()
    let keep : Array[String] = []
    for name in names {
      if component_set.get(name) is Some(_) {
        keep.push(name)
      }
    }
    if keep.length() > 0 {
      component_groups[rank] = keep
    }
  }
  component_groups
}

///|
fn append_component_rank_groups(
  order_rank_keys_for_mincross : Array[Int],
  merged : Map[Int, Array[String]],
  ordered_component : Map[Int, Array[String]],
) -> Unit {
  for rank in order_rank_keys_for_mincross {
    let names = ordered_component.get(rank).unwrap_or_default()
    if names.length() == 0 {
      continue
    }
    let merged_names = merged.get(rank).unwrap_or_default()
    for name in names {
      merged_names.push(name)
    }
    merged[rank] = merged_names
  }
}

///|
priv struct RootComponentReorderInputs {
  component_groups : Map[Int, Array[String]]
  component_edges : Array[@cgraph.Edge]
  component_edge_tail : Array[String]
  component_edge_head : Array[String]
  component_edge_tail_port_x : Array[Double]
  component_edge_head_port_x : Array[Double]
  component_edge_tail_port_order : Array[Double]
  component_edge_head_port_order : Array[Double]
  component_parents : Map[String, Array[String]]
  component_children : Map[String, Array[String]]
  component_graphviz_out_neighbors : Map[String, Array[String]]
  component_graphviz_in_neighbors : Map[String, Array[String]]
  component_port_order_positions : Map[String, Double]
  component_preferred_positions : Map[String, Double]
  component_port_order_contrib : Map[String, Array[(String, Double)]]
  component_flat_constraints : Map[String, Bool]
}

///|
priv struct RootComponentReorderConfig {
  order_rank_keys_for_mincross : Array[Int]
  order_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_order : Map[String, Int]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  order_cluster_skeleton : Map[String, Bool]
  root_graphviz_flip : Bool
  coalesce_parallel : Bool
}

///|
/// Graphviz parity: component root mincross preserves original edge
/// multiplicity during startpass=0 ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_component_rank_reorder(
  component_inputs : RootComponentReorderInputs,
  config : RootComponentReorderConfig,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    config.order_rank_keys_for_mincross,
    component_inputs.component_groups,
    component_inputs.component_edges,
    component_inputs.component_edge_tail,
    component_inputs.component_edge_head,
    component_inputs.component_edge_tail_port_x,
    component_inputs.component_edge_head_port_x,
    component_inputs.component_edge_tail_port_order,
    component_inputs.component_edge_head_port_order,
    component_inputs.component_parents,
    component_inputs.component_children,
    config.order_cluster_keys,
    config.rank_same_groups,
    config.rank_same_order,
    config.edge_order,
    config.order_node_order,
    config.order_sizes_out,
    config.nodesep_pt,
    config.has_edge_labels,
    component_inputs.component_port_order_positions,
    component_inputs.component_port_order_contrib,
    component_inputs.component_preferred_positions,
    config.order_cluster_skeleton,
    component_inputs.component_flat_constraints,
    graphviz_out_neighbors=component_inputs.component_graphviz_out_neighbors,
    graphviz_in_neighbors=component_inputs.component_graphviz_in_neighbors,
    graphviz_flip=config.root_graphviz_flip,
    coalesce_parallel_edges=config.coalesce_parallel,
  )
}

///|
fn has_non_empty_cluster_keys(order_cluster_keys : Map[String, String]) -> Bool {
  for _name, cluster in order_cluster_keys {
    if cluster != "" {
      return true
    }
  }
  false
}

///|
priv struct RootRankReorderInputs {
  order_rank_keys_for_mincross : Array[Int]
  order_groups_for_mincross : Map[Int, Array[String]]
  order_edges_out_mincross : Array[@cgraph.Edge]
  order_edge_tail_out_mincross : Array[String]
  order_edge_head_out_mincross : Array[String]
  order_edge_tail_port_x_mincross : Array[Double]
  order_edge_head_port_x_mincross : Array[Double]
  order_edge_tail_port_order_mincross : Array[Double]
  order_edge_head_port_order_mincross : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  order_cluster_keys : Map[String, String]
  cluster_meta : ClusterMetadata
  edge_order : Map[String, Int]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  preferred_positions : Map[String, Double]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
priv struct RootComponentTraversalPlan {
  components : Array[Array[String]]
  root_graphviz_flip : Bool
}

///|
/// Graphviz parity: component projection source bundle keeps root mincross
/// input snapshots unchanged before per-component filtering.
/// Do not change behavior without updating fixtures/tests.
priv struct RootComponentProjectionSources {
  order_rank_keys_for_mincross : Array[Int]
  order_groups_for_mincross : Map[Int, Array[String]]
  order_edges_out_mincross : Array[@cgraph.Edge]
  order_edge_tail_out_mincross : Array[String]
  order_edge_head_out_mincross : Array[String]
  order_edge_tail_port_x_mincross : Array[Double]
  order_edge_head_port_x_mincross : Array[Double]
  order_edge_tail_port_order_mincross : Array[Double]
  order_edge_head_port_order_mincross : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  port_order_positions : Map[String, Double]
  preferred_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: component-local neighbor projections are filtered from the
/// same component membership snapshot before root mincross.
/// Do not change behavior without updating fixtures/tests.
priv struct RootComponentNeighborMaps {
  component_parents : Map[String, Array[String]]
  component_children : Map[String, Array[String]]
  component_graphviz_out_neighbors : Map[String, Array[String]]
  component_graphviz_in_neighbors : Map[String, Array[String]]
}

///|
/// Graphviz parity: cluster-aware root mincross runs in internal TB
/// coordinates (like mincross_clust subgraph passes), so flip is off.
/// Do not change behavior without updating fixtures/tests.
fn build_root_component_traversal_plan(
  has_cluster_keys : Bool,
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_node_order : Map[String, Int],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> RootComponentTraversalPlan {
  let components =
    if has_cluster_keys {
      []
    } else {
      collect_noncluster_components(
        order_rank_keys_for_mincross,
        order_groups_for_mincross,
        order_node_order,
        graphviz_out_neighbors,
        graphviz_in_neighbors,
        order_flat_constraints,
      )
    }
  let root_graphviz_flip =
    if has_cluster_keys {
      false
    } else {
      graphviz_flip
    }
  { components, root_graphviz_flip }
}

///|
/// Graphviz parity: component-local parent/child + Graphviz traversal maps are
/// all filtered through one component-set projection.
/// Do not change behavior without updating fixtures/tests.
fn build_root_component_neighbor_maps(
  component_nodes : Array[String],
  component_set : Map[String, Bool],
  sources : RootComponentProjectionSources,
) -> RootComponentNeighborMaps {
  {
    component_parents:
      filter_component_neighbor_map(
        component_nodes,
        component_set,
        sources.parents,
      ),
    component_children:
      filter_component_neighbor_map(
        component_nodes,
        component_set,
        sources.children,
      ),
    component_graphviz_out_neighbors:
      filter_component_neighbor_map(
        component_nodes,
        component_set,
        sources.graphviz_out_neighbors,
      ),
    component_graphviz_in_neighbors:
      filter_component_neighbor_map(
        component_nodes,
        component_set,
        sources.graphviz_in_neighbors,
      ),
  }
}

///|
/// Graphviz parity: component-local reorder inputs are filtered from root data
/// so each mincross call only sees one connected component projection.
/// Do not change behavior without updating fixtures/tests.
fn build_root_component_reorder_inputs(
  component_nodes : Array[String],
  component_set : Map[String, Bool],
  sources : RootComponentProjectionSources,
) -> RootComponentReorderInputs {
  let component_groups =
    filter_component_rank_groups(
      sources.order_rank_keys_for_mincross,
      sources.order_groups_for_mincross,
      component_set,
    )
  let component_edges_output =
    collect_mincross_order_edges(
      component_set,
      sources.order_edges_out_mincross,
      sources.order_edge_tail_out_mincross,
      sources.order_edge_head_out_mincross,
      sources.order_edge_tail_port_x_mincross,
      sources.order_edge_head_port_x_mincross,
      sources.order_edge_tail_port_order_mincross,
      sources.order_edge_head_port_order_mincross,
    )
  let component_neighbor_maps =
    build_root_component_neighbor_maps(
      component_nodes,
      component_set,
      sources,
    )
  // Graphviz parity: component-local node-position hints are passed to
  // mincross only for nodes belonging to the active connected component.
  let component_port_order_positions =
    filter_component_positions(component_set, sources.port_order_positions)
  let component_preferred_positions =
    filter_component_positions(component_set, sources.preferred_positions)
  // Graphviz parity: component-local port-order contributor lists drop
  // endpoints outside the active connected component before mincross.
  let component_port_order_contrib =
    filter_component_port_order_contrib(
      component_set,
      sources.port_order_contrib,
    )
  // Graphviz parity: component-local flat constraints are forwarded to
  // mincross only when both endpoints belong to the active component.
  let component_flat_constraints =
    filter_component_flat_constraints(
      component_set,
      sources.order_flat_constraints,
    )
  {
    component_groups,
    component_edges: component_edges_output.order_edges_out_mincross,
    component_edge_tail: component_edges_output.order_edge_tail_out_mincross,
    component_edge_head: component_edges_output.order_edge_head_out_mincross,
    component_edge_tail_port_x:
      component_edges_output.order_edge_tail_port_x_mincross,
    component_edge_head_port_x:
      component_edges_output.order_edge_head_port_x_mincross,
    component_edge_tail_port_order:
      component_edges_output.order_edge_tail_port_order_mincross,
    component_edge_head_port_order:
      component_edges_output.order_edge_head_port_order_mincross,
    component_parents: component_neighbor_maps.component_parents,
    component_children: component_neighbor_maps.component_children,
    component_graphviz_out_neighbors:
      component_neighbor_maps.component_graphviz_out_neighbors,
    component_graphviz_in_neighbors:
      component_neighbor_maps.component_graphviz_in_neighbors,
    component_port_order_positions,
    component_preferred_positions,
    component_port_order_contrib,
    component_flat_constraints,
  }
}

///|
/// Graphviz parity: multi-component root reorder runs one component projection
/// per mincross call, then concatenates per-rank outputs in component order.
/// Do not change behavior without updating fixtures/tests.
fn run_componentwise_root_rank_reorder(
  components : Array[Array[String]],
  component_projection_sources : RootComponentProjectionSources,
  component_reorder_config : RootComponentReorderConfig,
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in component_reorder_config.order_rank_keys_for_mincross {
    merged[rank] = []
  }
  for component_nodes in components {
    let component_set = build_node_membership_set(component_nodes)
    let component_inputs =
      build_root_component_reorder_inputs(
        component_nodes,
        component_set,
        component_projection_sources,
      )
    let ordered_component =
      run_root_component_rank_reorder(
        component_inputs,
        component_reorder_config,
      )
    append_component_rank_groups(
      component_reorder_config.order_rank_keys_for_mincross,
      merged,
      ordered_component,
    )
  }
  merged
}

///|
/// Graphviz parity: single-component root reorder dispatch preserves the same
/// reorder_rank_groups inputs and edge coalescing behavior as the root path.
/// Do not change behavior without updating fixtures/tests.
fn run_single_component_root_rank_reorder(
  inputs : RootRankReorderInputs,
  root_graphviz_flip : Bool,
  coalesce_parallel : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    inputs.order_rank_keys_for_mincross,
    inputs.order_groups_for_mincross,
    inputs.order_edges_out_mincross,
    inputs.order_edge_tail_out_mincross,
    inputs.order_edge_head_out_mincross,
    inputs.order_edge_tail_port_x_mincross,
    inputs.order_edge_head_port_x_mincross,
    inputs.order_edge_tail_port_order_mincross,
    inputs.order_edge_head_port_order_mincross,
    inputs.parents,
    inputs.children,
    inputs.order_cluster_keys,
    inputs.cluster_meta.rank_same_groups,
    inputs.cluster_meta.rank_same_order,
    inputs.edge_order,
    inputs.order_node_order,
    inputs.order_sizes_out,
    inputs.nodesep_pt,
    inputs.has_edge_labels,
    inputs.port_order_positions,
    inputs.port_order_contrib,
    inputs.preferred_positions,
    inputs.order_cluster_skeleton,
    inputs.order_flat_constraints,
    graphviz_out_neighbors=inputs.graphviz_out_neighbors,
    graphviz_in_neighbors=inputs.graphviz_in_neighbors,
    graphviz_flip=root_graphviz_flip,
    // Graphviz parity: root mincross (startpass=0) uses original edge
    // multiplicity; parallel-edge coalescing is a ReMincross concern.
    coalesce_parallel_edges=coalesce_parallel,
  )
}

///|
/// Graphviz parity: component projection sources for multi-component root
/// reorder keep one-to-one snapshots of root mincross edges and neighbors.
/// Do not change behavior without updating fixtures/tests.
fn build_root_component_projection_sources(
  inputs : RootRankReorderInputs,
) -> RootComponentProjectionSources {
  {
    order_rank_keys_for_mincross: inputs.order_rank_keys_for_mincross,
    order_groups_for_mincross: inputs.order_groups_for_mincross,
    order_edges_out_mincross: inputs.order_edges_out_mincross,
    order_edge_tail_out_mincross: inputs.order_edge_tail_out_mincross,
    order_edge_head_out_mincross: inputs.order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross: inputs.order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross: inputs.order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross:
      inputs.order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross:
      inputs.order_edge_head_port_order_mincross,
    parents: inputs.parents,
    children: inputs.children,
    graphviz_out_neighbors: inputs.graphviz_out_neighbors,
    graphviz_in_neighbors: inputs.graphviz_in_neighbors,
    port_order_positions: inputs.port_order_positions,
    preferred_positions: inputs.preferred_positions,
    port_order_contrib: inputs.port_order_contrib,
    order_flat_constraints: inputs.order_flat_constraints,
  }
}

///|
/// Graphviz parity: component reorder config keeps rank/cluster ordering
/// metadata identical to the single-component root reorder dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_root_component_reorder_config(
  inputs : RootRankReorderInputs,
  root_graphviz_flip : Bool,
  coalesce_parallel : Bool,
) -> RootComponentReorderConfig {
  {
    order_rank_keys_for_mincross: inputs.order_rank_keys_for_mincross,
    order_cluster_keys: inputs.order_cluster_keys,
    rank_same_groups: inputs.cluster_meta.rank_same_groups,
    rank_same_order: inputs.cluster_meta.rank_same_order,
    edge_order: inputs.edge_order,
    order_node_order: inputs.order_node_order,
    order_sizes_out: inputs.order_sizes_out,
    nodesep_pt: inputs.nodesep_pt,
    has_edge_labels: inputs.has_edge_labels,
    order_cluster_skeleton: inputs.order_cluster_skeleton,
    root_graphviz_flip,
    coalesce_parallel,
  }
}

///|
/// Graphviz parity: root ReMincross runs mincross per connected component
/// (dot_mincross init_mccomp loop), then concatenates rank output by component.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_reorder(
  inputs : RootRankReorderInputs,
) -> Map[Int, Array[String]] {
  let has_cluster_keys =
    has_non_empty_cluster_keys(inputs.order_cluster_keys)
  let traversal_plan =
    build_root_component_traversal_plan(
      has_cluster_keys,
      inputs.order_rank_keys_for_mincross,
      inputs.order_groups_for_mincross,
      inputs.order_node_order,
      inputs.graphviz_out_neighbors,
      inputs.graphviz_in_neighbors,
      inputs.order_flat_constraints,
      inputs.graphviz_flip,
    )
  let components = traversal_plan.components
  let coalesce_parallel =
    @sys.get_env_var("DOT_NO_COALESCE_PARALLEL") is None
  let root_graphviz_flip = traversal_plan.root_graphviz_flip
  if components.length() <= 1 {
    return run_single_component_root_rank_reorder(
      inputs,
      root_graphviz_flip,
      coalesce_parallel,
    )
  }

  let component_projection_sources =
    build_root_component_projection_sources(inputs)
  let component_reorder_config =
    build_root_component_reorder_config(
      inputs,
      root_graphviz_flip,
      coalesce_parallel,
    )
  run_componentwise_root_rank_reorder(
    components,
    component_projection_sources,
    component_reorder_config,
  )
}

///|
/// Graphviz parity: root ReMincross rank-reorder pass keeps input preparation
/// and reorder_rank_groups execution in the same Graphviz call sequence.
/// Do not change behavior without updating fixtures/tests.
priv struct RootMincrossEdgeData {
  order_edges_out_mincross : Array[@cgraph.Edge]
  order_edge_tail_out_mincross : Array[String]
  order_edge_head_out_mincross : Array[String]
  order_edge_tail_port_x_mincross : Array[Double]
  order_edge_head_port_x_mincross : Array[Double]
  order_edge_tail_port_order_mincross : Array[Double]
  order_edge_head_port_order_mincross : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  edge_order : Map[String, Int]
}

///|
/// Graphviz parity: root ReMincross edge-data sources keep root edge snapshots,
/// filtered node set, and rank map unchanged for mincross edge projection.
/// Do not change behavior without updating fixtures/tests.
priv struct RootMincrossEdgeBuildInputs {
  mincross_nodes : Map[String, Bool]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_nodes_for_mincross : Array[String]
  order_ranks : Map[String, Int]
}

///|
/// Graphviz parity: root ReMincross materializes filtered root/skeleton edges
/// before building parent/child + edge-order indices.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_edge_data(
  inputs : RootMincrossEdgeBuildInputs,
) -> RootMincrossEdgeData {
  let mincross_edges_output =
    collect_mincross_order_edges(
      inputs.mincross_nodes,
      inputs.order_edges_out,
      inputs.order_edge_tail_out,
      inputs.order_edge_head_out,
      inputs.order_edge_tail_port_x,
      inputs.order_edge_head_port_x,
      inputs.order_edge_tail_port_order,
      inputs.order_edge_head_port_order,
    )
  let edge_indices =
    build_edge_indices_and_order(
      inputs.order_nodes_for_mincross,
      mincross_edges_output.order_edge_tail_out_mincross,
      mincross_edges_output.order_edge_head_out_mincross,
      inputs.order_ranks,
      mincross_edges_output.order_edges_out_mincross,
    )
  {
    order_edges_out_mincross: mincross_edges_output.order_edges_out_mincross,
    order_edge_tail_out_mincross:
      mincross_edges_output.order_edge_tail_out_mincross,
    order_edge_head_out_mincross:
      mincross_edges_output.order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross:
      mincross_edges_output.order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross:
      mincross_edges_output.order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross:
      mincross_edges_output.order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross:
      mincross_edges_output.order_edge_head_port_order_mincross,
    parents: edge_indices.parents,
    children: edge_indices.children,
    edge_order: edge_indices.edge_order,
  }
}

///|
/// Graphviz parity: root ReMincross rank-reorder pass keeps input preparation
/// and reorder_rank_groups execution in the same Graphviz call sequence.
/// Do not change behavior without updating fixtures/tests.
priv struct RootReorderPassOutput {
  ordered_mincross : Map[Int, Array[String]]
  mincross_nodes : Map[String, Bool]
}

///|
/// Graphviz parity: root ReMincross rank-reorder pass input bundle keeps edge,
/// rank, constraint, and ordering snapshots unchanged across pass assembly.
/// Do not change behavior without updating fixtures/tests.
priv struct RootReorderPassInputs {
  order_with_vnodes : Bool
  vnode_order_keys_for_ordering : Map[String, Double]
  order_groups_for_mincross : Map[Int, Array[String]]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_ranks : Map[String, Int]
  order_cluster_keys : Map[String, String]
  cluster_meta : ClusterMetadata
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: root ReMincross output keeps seeded root-mincross input
/// groups and merged ordered groups bundled for downstream clustered phases.
priv struct RootMincrossReorderOutput {
  order_groups_for_mincross : Map[Int, Array[String]]
  ordered : Map[Int, Array[String]]
}

///|
/// Graphviz parity: root ReMincross input bundle keeps seeded groups, edge
/// snapshots, cluster metadata, and rank-order settings unchanged for replay.
/// Do not change behavior without updating fixtures/tests.
priv struct RootMincrossReorderInputs {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  seeded_groups : Map[Int, Array[String]]
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  cluster_meta : ClusterMetadata
  vnode_order_keys_for_ordering : Map[String, Double]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: root ReMincross pass stage data keeps rank keys, node
/// membership, and filtered edge bundle from one root-mincross projection.
/// Do not change behavior without updating fixtures/tests.
priv struct RootReorderPassStageData {
  order_rank_keys_for_mincross : Array[Int]
  mincross_nodes : Map[String, Bool]
  mincross_edge_data : RootMincrossEdgeData
}

///|
/// Graphviz parity: root ReMincross stage data is assembled from one snapshot:
/// rank keys -> node membership -> filtered mincross edge bundle.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_pass_stage_data(
  inputs : RootReorderPassInputs,
) -> RootReorderPassStageData {
  let order_rank_keys_for_mincross =
    collect_rank_keys(inputs.order_groups_for_mincross)
  let order_nodes_for_mincross =
    build_order_nodes_from_groups(
      inputs.order_groups_for_mincross,
      order_rank_keys_for_mincross,
    )
  let mincross_nodes = build_node_membership_set(order_nodes_for_mincross)
  let mincross_edge_data =
    build_root_mincross_edge_data(
      {
        mincross_nodes,
        order_edges_out: inputs.order_edges_out,
        order_edge_tail_out: inputs.order_edge_tail_out,
        order_edge_head_out: inputs.order_edge_head_out,
        order_edge_tail_port_x: inputs.order_edge_tail_port_x,
        order_edge_head_port_x: inputs.order_edge_head_port_x,
        order_edge_tail_port_order: inputs.order_edge_tail_port_order,
        order_edge_head_port_order: inputs.order_edge_head_port_order,
        order_nodes_for_mincross,
        order_ranks: inputs.order_ranks,
      },
    )
  { order_rank_keys_for_mincross, mincross_nodes, mincross_edge_data }
}

///|
/// Graphviz parity: vnode preferred-position hints are forwarded only for edge
/// vnodes when vnode ordering is enabled in root ReMincross.
/// Do not change behavior without updating fixtures/tests.
fn build_root_vnode_preferred_positions(
  order_with_vnodes : Bool,
  vnode_order_keys_for_ordering : Map[String, Double],
) -> Map[String, Double] {
  if !order_with_vnodes {
    return Map::new()
  }
  let filtered : Map[String, Double] = Map::new()
  for name, value in vnode_order_keys_for_ordering {
    if name.has_prefix(EDGE_VNODE_PREFIX) {
      filtered[name] = value
    }
  }
  filtered
}

///|
/// Graphviz parity: root ReMincross rank-reorder input preserves the stage
/// edge snapshot and root-order metadata when dispatching reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_root_rank_reorder_inputs_for_pass(
  stage_data : RootReorderPassStageData,
  inputs : RootReorderPassInputs,
  preferred_positions : Map[String, Double],
) -> RootRankReorderInputs {
  let mincross_edge_data = stage_data.mincross_edge_data
  {
    order_rank_keys_for_mincross: stage_data.order_rank_keys_for_mincross,
    order_groups_for_mincross: inputs.order_groups_for_mincross,
    order_edges_out_mincross: mincross_edge_data.order_edges_out_mincross,
    order_edge_tail_out_mincross: mincross_edge_data.order_edge_tail_out_mincross,
    order_edge_head_out_mincross: mincross_edge_data.order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross:
      mincross_edge_data.order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross:
      mincross_edge_data.order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross:
      mincross_edge_data.order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross:
      mincross_edge_data.order_edge_head_port_order_mincross,
    parents: mincross_edge_data.parents,
    children: mincross_edge_data.children,
    order_cluster_keys: inputs.order_cluster_keys,
    cluster_meta: inputs.cluster_meta,
    edge_order: mincross_edge_data.edge_order,
    order_node_order: inputs.order_node_order,
    order_sizes_out: inputs.order_sizes_out,
    nodesep_pt: inputs.nodesep_pt,
    has_edge_labels: inputs.has_edge_labels,
    port_order_positions: inputs.port_order_positions,
    port_order_contrib: inputs.port_order_contrib,
    preferred_positions,
    order_cluster_skeleton: inputs.order_cluster_skeleton,
    order_flat_constraints: inputs.order_flat_constraints,
    graphviz_out_neighbors: inputs.graphviz_out_neighbors,
    graphviz_in_neighbors: inputs.graphviz_in_neighbors,
    graphviz_flip: inputs.graphviz_flip,
  }
}

///|
/// Graphviz parity: root reorder pass snapshot records the same mincross edge
/// projection and selected rank groups that were passed to reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn capture_root_reorder_pass_snapshot(
  stage_data : RootReorderPassStageData,
  inputs : RootReorderPassInputs,
) -> Unit {
  let mincross_edge_data = stage_data.mincross_edge_data
  capture_root_snapshot(
    stage_data.order_rank_keys_for_mincross,
    inputs.order_groups_for_mincross,
    mincross_edge_data.order_edges_out_mincross,
    mincross_edge_data.order_edge_tail_out_mincross,
    mincross_edge_data.order_edge_head_out_mincross,
    mincross_edge_data.order_edge_tail_port_x_mincross,
    mincross_edge_data.order_edge_head_port_x_mincross,
    mincross_edge_data.order_edge_tail_port_order_mincross,
    mincross_edge_data.order_edge_head_port_order_mincross,
    inputs.order_cluster_keys,
    inputs.order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: pass0 flat-seed capture wraps the root rank-reorder call,
/// then records the same stage snapshot before resetting capture state.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_reorder_with_pass0_capture(
  stage_data : RootReorderPassStageData,
  inputs : RootReorderPassInputs,
  root_rank_reorder_inputs : RootRankReorderInputs,
) -> Map[Int, Array[String]] {
  capture_pass0_flat_seed_groups_value.val = None
  capture_pass0_flat_seed_groups_enabled.val = true
  let ordered_mincross =
    run_root_rank_reorder(root_rank_reorder_inputs)
  capture_pass0_flat_seed_groups_enabled.val = false
  capture_root_reorder_pass_snapshot(stage_data, inputs)
  capture_pass0_flat_seed_groups_value.val = None
  ordered_mincross
}

///|
/// Graphviz parity: root ReMincross rank-reorder pass keeps input preparation
/// and reorder_rank_groups execution in the same Graphviz call sequence.
/// Do not change behavior without updating fixtures/tests.
fn run_root_reorder_pass(
  inputs : RootReorderPassInputs,
) -> RootReorderPassOutput {
  let stage_data =
    build_root_reorder_pass_stage_data(inputs)
  let preferred_positions =
    build_root_vnode_preferred_positions(
      inputs.order_with_vnodes,
      inputs.vnode_order_keys_for_ordering,
    )
  let root_rank_reorder_inputs : RootRankReorderInputs = {
    ..build_root_rank_reorder_inputs_for_pass(
      stage_data,
      inputs,
      preferred_positions,
    )
  }
  let ordered_mincross =
    run_root_rank_reorder_with_pass0_capture(
      stage_data,
      inputs,
      root_rank_reorder_inputs,
    )
  { ordered_mincross, mincross_nodes: stage_data.mincross_nodes }
}

///|
/// Graphviz parity: root ReMincross keeps only root + cluster-skeleton names
/// from seeded build_ranks groups; cluster-internal names stay cluster-local.
/// Do not change behavior without updating fixtures/tests.
fn filter_root_mincross_seeded_groups_for_clusters(
  seeded_groups : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let filtered : Map[Int, Array[String]] = Map::new()
  for rank, names in seeded_groups {
    let list : Array[String] = []
    for name in names {
      let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
      let cluster = order_cluster_keys.get(name).unwrap_or_default()
      if is_skeleton || cluster == "" {
        list.push(name)
      }
    }
    if list.length() > 0 {
      filtered[rank] = list
    }
  }
  filtered
}

///|
/// Graphviz parity: root ReMincross input groups are cluster-filtered when
/// cluster ordering is enabled, then optionally overridden for fixture replay.
/// Do not change behavior without updating fixtures/tests.
fn resolve_root_mincross_input_groups(
  inputs : RootMincrossReorderInputs,
) -> Map[Int, Array[String]] {
  let order_groups_for_mincross_base =
    if !inputs.order_with_clusters {
      inputs.seeded_groups
    } else {
      // Graphviz parity: root ReMincross keeps only root and cluster-skeleton
      // nodes; cluster-internal ordering stays in cluster-local build_ranks
      // passes.
      filter_root_mincross_seeded_groups_for_clusters(
        inputs.seeded_groups,
        inputs.order_cluster_keys,
        inputs.order_cluster_skeleton,
      )
    }
  match root_mincross_groups_override.val {
    Some(override_groups) => clone_rank_groups(override_groups)
    None => order_groups_for_mincross_base
  }
}

///|
/// Graphviz parity: root ReMincross pass input is derived directly from one
/// root mincross input snapshot plus selected root/skeleton groups.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_pass_inputs(
  inputs : RootMincrossReorderInputs,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> RootReorderPassInputs {
  {
    order_with_vnodes: inputs.order_with_vnodes,
    vnode_order_keys_for_ordering:
      inputs.vnode_order_keys_for_ordering,
    order_groups_for_mincross,
    order_edges_out: inputs.order_edges_out,
    order_edge_tail_out: inputs.order_edge_tail_out,
    order_edge_head_out: inputs.order_edge_head_out,
    order_edge_tail_port_x: inputs.order_edge_tail_port_x,
    order_edge_head_port_x: inputs.order_edge_head_port_x,
    order_edge_tail_port_order: inputs.order_edge_tail_port_order,
    order_edge_head_port_order: inputs.order_edge_head_port_order,
    order_ranks: inputs.order_ranks,
    order_cluster_keys: inputs.order_cluster_keys,
    cluster_meta: inputs.cluster_meta,
    order_node_order: inputs.order_node_order,
    order_sizes_out: inputs.order_sizes_out,
    nodesep_pt: inputs.nodesep_pt,
    has_edge_labels: inputs.has_edge_labels,
    port_order_positions: inputs.port_order_positions,
    port_order_contrib: inputs.port_order_contrib,
    order_cluster_skeleton: inputs.order_cluster_skeleton,
    order_flat_constraints: inputs.order_flat_constraints,
    graphviz_out_neighbors: inputs.graphviz_out_neighbors,
    graphviz_in_neighbors: inputs.graphviz_in_neighbors,
    graphviz_flip: inputs.graphviz_flip,
  }
}

///|
/// Graphviz parity: root ReMincross output merges reordered root/skeleton names
/// back to seeded groups only in cluster-order mode.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_mincross_ordered_groups(
  inputs : RootMincrossReorderInputs,
  root_reorder_output : RootReorderPassOutput,
) -> Map[Int, Array[String]] {
  if !inputs.order_with_clusters {
    return root_reorder_output.ordered_mincross
  }
  merge_root_mincross_groups(
    inputs.order_rank_keys,
    inputs.seeded_groups,
    root_reorder_output.ordered_mincross,
    root_reorder_output.mincross_nodes,
    inputs.order_cluster_keys,
    inputs.order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder(
  inputs : RootMincrossReorderInputs,
) -> RootMincrossReorderOutput {
  let order_groups_for_mincross =
    resolve_root_mincross_input_groups(inputs)
  let root_reorder_inputs =
    build_root_reorder_pass_inputs(
      inputs,
      order_groups_for_mincross,
    )
  let root_reorder_output =
    run_root_reorder_pass(root_reorder_inputs)
  let ordered =
    finalize_root_mincross_ordered_groups(
      inputs,
      root_reorder_output,
    )
  { order_groups_for_mincross, ordered }
}
