///|
/// Stage C Phase C2 split: root mincross/replay helpers
/// for primary crossing-reduction ordering passes.

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
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in order_nodes {
    fallback_order[name] = i
  }
  let start_nodes = order_nodes.copy()
  if start_nodes.length() > 1 {
    start_nodes.sort_by((a, b) => {
      let a_idx = match order_node_order.get(a) {
        Some(value) => value
        None =>
          match fallback_order.get(a) {
            Some(value) => value
            None => 0
          }
      }
      let b_idx = match order_node_order.get(b) {
        Some(value) => value
        None =>
          match fallback_order.get(b) {
            Some(value) => value
            None => 0
          }
      }
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

  let out_neighbors : Map[String, Array[String]] = Map::new()
  let in_neighbors : Map[String, Array[String]] = Map::new()
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    let out_list = match graphviz_out_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let out_keep : Array[String] = []
    for other in out_list {
      if node_set.get(other) is Some(_) {
        out_keep.push(other)
      }
    }
    out_neighbors[name] = out_keep

    let in_list = match graphviz_in_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let in_keep : Array[String] = []
    for other in in_list {
      if node_set.get(other) is Some(_) {
        in_keep.push(other)
      }
    }
    in_neighbors[name] = in_keep
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
        let fin = match flat_in.get(current) {
          Some(list) => list
          None => []
        }
        let fout = match flat_out.get(current) {
          Some(list) => list
          None => []
        }
        let inn = match in_neighbors.get(current) {
          Some(list) => list
          None => []
        }
        let out = match out_neighbors.get(current) {
          Some(list) => list
          None => []
        }
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
  for start in traversal_starts {
    visit_start(start)
  }
  for start in start_nodes {
    visit_start(start)
  }
  components
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
/// Graphviz parity: root ReMincross runs mincross per connected component
/// (dot_mincross init_mccomp loop), then concatenates rank output by component.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_reorder(
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out_mincross : Array[@cgraph.Edge],
  order_edge_tail_out_mincross : Array[String],
  order_edge_head_out_mincross : Array[String],
  order_edge_tail_port_x_mincross : Array[Double],
  order_edge_head_port_x_mincross : Array[Double],
  order_edge_tail_port_order_mincross : Array[Double],
  order_edge_head_port_order_mincross : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let mut has_cluster_keys = false
  for _name, cluster in order_cluster_keys {
    if cluster != "" {
      has_cluster_keys = true
      break
    }
  }
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
  let coalesce_parallel =
    @sys.get_env_var("DOT_NO_COALESCE_PARALLEL") is None
  let root_graphviz_flip =
    if has_cluster_keys {
      // Graphviz parity: cluster-aware root mincross runs in internal TB
      // coordinates (like mincross_clust subgraph passes), so flip is off.
      false
    } else {
      graphviz_flip
    }
  if components.length() <= 1 {
    return reorder_rank_groups(
      order_rank_keys_for_mincross,
      order_groups_for_mincross,
      order_edges_out_mincross,
      order_edge_tail_out_mincross,
      order_edge_head_out_mincross,
      order_edge_tail_port_x_mincross,
      order_edge_head_port_x_mincross,
      order_edge_tail_port_order_mincross,
      order_edge_head_port_order_mincross,
      parents,
      children,
      order_cluster_keys,
      cluster_meta.rank_same_groups,
      cluster_meta.rank_same_order,
      edge_order,
      order_node_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      preferred_positions,
      order_cluster_skeleton,
      order_flat_constraints,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
      graphviz_flip=root_graphviz_flip,
      // Graphviz parity: root mincross (startpass=0) uses original edge
      // multiplicity; parallel-edge coalescing is a ReMincross concern.
      coalesce_parallel_edges=coalesce_parallel,
    )
  }

  let merged : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys_for_mincross {
    merged[rank] = []
  }
  for component_nodes in components {
    let component_set = build_node_membership_set(component_nodes)
    // Graphviz parity: component reorder keeps each rank's relative extraction
    // order from the full group list before running mincross on that component.
    let component_groups : Map[Int, Array[String]] = Map::new()
    for rank in order_rank_keys_for_mincross {
      let names = match order_groups_for_mincross.get(rank) {
        Some(list) => list
        None => []
      }
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
    let component_edges_output =
      collect_mincross_order_edges(
        component_set,
        order_edges_out_mincross,
        order_edge_tail_out_mincross,
        order_edge_head_out_mincross,
        order_edge_tail_port_x_mincross,
        order_edge_head_port_x_mincross,
        order_edge_tail_port_order_mincross,
        order_edge_head_port_order_mincross,
      )
    let component_edges = component_edges_output.order_edges_out_mincross
    let component_edge_tail = component_edges_output.order_edge_tail_out_mincross
    let component_edge_head = component_edges_output.order_edge_head_out_mincross
    let component_edge_tail_port_x =
      component_edges_output.order_edge_tail_port_x_mincross
    let component_edge_head_port_x =
      component_edges_output.order_edge_head_port_x_mincross
    let component_edge_tail_port_order =
      component_edges_output.order_edge_tail_port_order_mincross
    let component_edge_head_port_order =
      component_edges_output.order_edge_head_port_order_mincross
    let component_parents =
      filter_component_neighbor_map(
        component_nodes,
        component_set,
        parents,
      )
    let component_children =
      filter_component_neighbor_map(
        component_nodes,
        component_set,
        children,
      )
    let component_graphviz_out_neighbors =
      filter_component_neighbor_map(
        component_nodes,
        component_set,
        graphviz_out_neighbors,
      )
    let component_graphviz_in_neighbors =
      filter_component_neighbor_map(
        component_nodes,
        component_set,
        graphviz_in_neighbors,
      )
    // Graphviz parity: component-local node-position hints are passed to
    // mincross only for nodes belonging to the active connected component.
    let component_port_order_positions =
      filter_component_positions(component_set, port_order_positions)
    let component_preferred_positions =
      filter_component_positions(component_set, preferred_positions)
    // Graphviz parity: component-local port-order contributor lists drop
    // endpoints outside the active connected component before mincross.
    let component_port_order_contrib =
      filter_component_port_order_contrib(component_set, port_order_contrib)
    // Graphviz parity: component-local flat constraints are forwarded to
    // mincross only when both endpoints belong to the active component.
    let component_flat_constraints =
      filter_component_flat_constraints(component_set, order_flat_constraints)
    let ordered_component =
      reorder_rank_groups(
        order_rank_keys_for_mincross,
        component_groups,
        component_edges,
        component_edge_tail,
        component_edge_head,
        component_edge_tail_port_x,
        component_edge_head_port_x,
        component_edge_tail_port_order,
        component_edge_head_port_order,
        component_parents,
        component_children,
        order_cluster_keys,
        cluster_meta.rank_same_groups,
        cluster_meta.rank_same_order,
        edge_order,
        order_node_order,
        order_sizes_out,
        nodesep_pt,
        has_edge_labels,
        component_port_order_positions,
        component_port_order_contrib,
        component_preferred_positions,
        order_cluster_skeleton,
        component_flat_constraints,
        graphviz_out_neighbors=component_graphviz_out_neighbors,
        graphviz_in_neighbors=component_graphviz_in_neighbors,
        graphviz_flip=root_graphviz_flip,
        // Graphviz parity: component root mincross preserves original edge
        // multiplicity during startpass=0 ordering.
        coalesce_parallel_edges=coalesce_parallel,
      )
    for rank in order_rank_keys_for_mincross {
      let names = match ordered_component.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() == 0 {
        continue
      }
      let merged_names = match merged.get(rank) {
        Some(list) => list
        None => []
      }
      for name in names {
        merged_names.push(name)
      }
      merged[rank] = merged_names
    }
  }
  merged
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
/// Graphviz parity: root ReMincross materializes filtered root/skeleton edges
/// before building parent/child + edge-order indices.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_edge_data(
  mincross_nodes : Map[String, Bool],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_nodes_for_mincross : Array[String],
  order_ranks : Map[String, Int],
) -> RootMincrossEdgeData {
  let mincross_edges_output =
    collect_mincross_order_edges(
      mincross_nodes,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
    )
  let order_edges_out_mincross =
    mincross_edges_output.order_edges_out_mincross
  let order_edge_tail_out_mincross =
    mincross_edges_output.order_edge_tail_out_mincross
  let order_edge_head_out_mincross =
    mincross_edges_output.order_edge_head_out_mincross
  let edge_indices =
    build_edge_indices_and_order(
      order_nodes_for_mincross,
      order_edge_tail_out_mincross,
      order_edge_head_out_mincross,
      order_ranks,
      order_edges_out_mincross,
    )
  {
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
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
/// Graphviz parity: root ReMincross output keeps seeded root-mincross input
/// groups and merged ordered groups bundled for downstream clustered phases.
priv struct RootMincrossReorderOutput {
  order_groups_for_mincross : Map[Int, Array[String]]
  ordered : Map[Int, Array[String]]
}

///|
/// Graphviz parity: root ReMincross rank-reorder pass keeps input preparation
/// and reorder_rank_groups execution in the same Graphviz call sequence.
/// Do not change behavior without updating fixtures/tests.
fn run_root_reorder_pass(
  order_with_vnodes : Bool,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> RootReorderPassOutput {
  let order_rank_keys_for_mincross = collect_rank_keys(order_groups_for_mincross)
  let order_nodes_for_mincross =
    build_order_nodes_from_groups(
      order_groups_for_mincross,
      order_rank_keys_for_mincross,
    )
  let mincross_nodes = build_node_membership_set(order_nodes_for_mincross)
  let mincross_edge_data =
    build_root_mincross_edge_data(
      mincross_nodes,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      order_nodes_for_mincross,
      order_ranks,
    )
  let order_edges_out_mincross = mincross_edge_data.order_edges_out_mincross
  let order_edge_tail_out_mincross = mincross_edge_data.order_edge_tail_out_mincross
  let order_edge_head_out_mincross = mincross_edge_data.order_edge_head_out_mincross
  let order_edge_tail_port_x_mincross =
    mincross_edge_data.order_edge_tail_port_x_mincross
  let order_edge_head_port_x_mincross =
    mincross_edge_data.order_edge_head_port_x_mincross
  let order_edge_tail_port_order_mincross =
    mincross_edge_data.order_edge_tail_port_order_mincross
  let order_edge_head_port_order_mincross =
    mincross_edge_data.order_edge_head_port_order_mincross
  let preferred_positions : Map[String, Double] =
    if order_with_vnodes {
      let filtered : Map[String, Double] = Map::new()
      for name, value in vnode_order_keys_for_ordering {
        if name.has_prefix(EDGE_VNODE_PREFIX) {
          filtered[name] = value
        }
      }
      filtered
    } else {
      Map::new()
    }
  capture_pass0_flat_seed_groups_value.val = None
  capture_pass0_flat_seed_groups_enabled.val = true
  let ordered_mincross =
    run_root_rank_reorder(
      order_rank_keys_for_mincross,
      order_groups_for_mincross,
      order_edges_out_mincross,
      order_edge_tail_out_mincross,
      order_edge_head_out_mincross,
      order_edge_tail_port_x_mincross,
      order_edge_head_port_x_mincross,
      order_edge_tail_port_order_mincross,
      order_edge_head_port_order_mincross,
      mincross_edge_data.parents,
      mincross_edge_data.children,
      order_cluster_keys,
      cluster_meta,
      mincross_edge_data.edge_order,
      order_node_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      preferred_positions,
      order_cluster_skeleton,
      order_flat_constraints,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      graphviz_flip,
    )
  capture_pass0_flat_seed_groups_enabled.val = false
  let root_input_groups = order_groups_for_mincross
  capture_root_snapshot(
    order_rank_keys_for_mincross,
    root_input_groups,
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
  )
  capture_pass0_flat_seed_groups_value.val = None
  { ordered_mincross, mincross_nodes }
}

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
  order_ranks : Map[String, Int],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> RootMincrossReorderOutput {
  // Graphviz parity: root ReMincross only reorders root/skeleton nodes;
  // cluster-internal nodes are handled by cluster-local build_ranks passes.
  let order_groups_for_mincross_base =
    if !order_with_clusters {
      seeded_groups
    } else {
      // Graphviz parity: root ReMincross keeps only root and cluster-skeleton
      // nodes; cluster-internal ordering stays in cluster-local build_ranks
      // passes.
      let filtered : Map[Int, Array[String]] = Map::new()
      for rank, names in seeded_groups {
        let list : Array[String] = []
        for name in names {
          let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
          let cluster = match order_cluster_keys.get(name) {
            Some(value) => value
            None => ""
          }
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
  let order_groups_for_mincross =
    match root_mincross_groups_override.val {
      Some(override_groups) => clone_rank_groups(override_groups)
      None => order_groups_for_mincross_base
    }
  let root_reorder_output =
    run_root_reorder_pass(
      order_with_vnodes,
      vnode_order_keys_for_ordering,
      order_groups_for_mincross,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      order_ranks,
      order_cluster_keys,
      cluster_meta,
      order_node_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      order_cluster_skeleton,
      order_flat_constraints,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      graphviz_flip,
    )
  let ordered =
    if order_with_clusters {
      merge_root_mincross_groups(
        order_rank_keys,
        seeded_groups,
        root_reorder_output.ordered_mincross,
        root_reorder_output.mincross_nodes,
        order_cluster_keys,
        order_cluster_skeleton,
      )
    } else {
      root_reorder_output.ordered_mincross
    }
  { order_groups_for_mincross, ordered }
}
