///|
/// Stage C Phase C2 split: root mincross/replay helpers
/// for primary crossing-reduction ordering passes.

///|
/// Graphviz parity: root ReMincross runs mincross per connected component
/// (dot_mincross init_mccomp loop), then concatenates rank output by component.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_rank_reorder(
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
      collect_noncluster_reorder_components(
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
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    println(
      "root_mincross_flip has_cluster=\{has_cluster_keys} in=\{graphviz_flip} out=\{root_graphviz_flip}",
    )
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
    let component_groups =
      build_noncluster_reorder_component_groups(
        order_rank_keys_for_mincross,
        order_groups_for_mincross,
        component_set,
      )
    let (
      component_edges,
      component_edge_tail,
      component_edge_head,
      component_edge_tail_port_x,
      component_edge_head_port_x,
      component_edge_tail_port_order,
      component_edge_head_port_order,
    ) =
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
    let component_parents =
      filter_noncluster_neighbor_map_for_component(
        component_nodes,
        component_set,
        parents,
      )
    let component_children =
      filter_noncluster_neighbor_map_for_component(
        component_nodes,
        component_set,
        children,
      )
    let component_graphviz_out_neighbors =
      filter_noncluster_neighbor_map_for_component(
        component_nodes,
        component_set,
        graphviz_out_neighbors,
      )
    let component_graphviz_in_neighbors =
      filter_noncluster_neighbor_map_for_component(
        component_nodes,
        component_set,
        graphviz_in_neighbors,
      )
    // Graphviz parity: component-local node-position hints are passed to
    // mincross only for nodes belonging to the active connected component.
    let component_port_order_positions : Map[String, Double] = Map::new()
    for name, value in port_order_positions {
      if component_set.get(name) is Some(_) {
        component_port_order_positions[name] = value
      }
    }
    let component_preferred_positions : Map[String, Double] = Map::new()
    for name, value in preferred_positions {
      if component_set.get(name) is Some(_) {
        component_preferred_positions[name] = value
      }
    }
    // Graphviz parity: component-local port-order contributor lists drop
    // endpoints outside the active connected component before mincross.
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
    let component_flat_constraints =
      filter_noncluster_flat_constraints_for_component(
        order_flat_constraints,
        component_set,
      )
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
fn run_root_mincross_rank_reorder_pass(
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
) -> (Map[Int, Array[String]], Map[String, Bool]) {
  let order_rank_keys_for_mincross = collect_rank_keys(order_groups_for_mincross)
  let order_nodes_for_mincross =
    build_order_nodes_from_groups(
      order_groups_for_mincross,
      order_rank_keys_for_mincross,
    )
  let mincross_nodes = build_node_membership_set(order_nodes_for_mincross)
  let (
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    edge_order,
  ) =
    {
      // Graphviz parity: root ReMincross materializes filtered root/skeleton
      // edges before building parent/child + edge-order indices.
      let (
        order_edges_out_mincross,
        order_edge_tail_out_mincross,
        order_edge_head_out_mincross,
        order_edge_tail_port_x_mincross,
        order_edge_head_port_x_mincross,
        order_edge_tail_port_order_mincross,
        order_edge_head_port_order_mincross,
      ) =
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
      let (parents, children, edge_order) =
        build_order_edge_indices_and_order(
          order_nodes_for_mincross,
          order_edge_tail_out_mincross,
          order_edge_head_out_mincross,
          order_ranks,
          order_edges_out_mincross,
        )
      (
        order_edges_out_mincross,
        order_edge_tail_out_mincross,
        order_edge_head_out_mincross,
        order_edge_tail_port_x_mincross,
        order_edge_head_port_x_mincross,
        order_edge_tail_port_order_mincross,
        order_edge_head_port_order_mincross,
        parents,
        children,
        edge_order,
      )
    }
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
  if @sys.get_env_var("DOT_TRACE_ROOT_INPUT") is Some(_) {
    let mut edge_idx = 0
    while edge_idx < order_edges_out_mincross.length() {
      let tail = order_edge_tail_out_mincross[edge_idx]
      let head = order_edge_head_out_mincross[edge_idx]
      let pen = @dot_shared.edge_xpenalty(order_edges_out_mincross[edge_idx])
      let tail_port_order =
        if edge_idx < order_edge_tail_port_order_mincross.length() {
          order_edge_tail_port_order_mincross[edge_idx]
        } else {
          -1.0
        }
      let head_port_order =
        if edge_idx < order_edge_head_port_order_mincross.length() {
          order_edge_head_port_order_mincross[edge_idx]
        } else {
          -1.0
        }
      println(
        "root_input_edge \{edge_idx}: \{tail} -> \{head} pen=\{pen} tpo=\{tail_port_order} hpo=\{head_port_order}",
      )
      edge_idx = edge_idx + 1
    }
  }
  let ordered_mincross =
    run_root_mincross_rank_reorder(
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
      cluster_meta,
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
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      graphviz_flip,
    )
  capture_pass0_flat_seed_groups_enabled.val = false
  let root_input_groups = order_groups_for_mincross
  capture_root_mincross_input_snapshot(
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
  (ordered_mincross, mincross_nodes)
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
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  // Graphviz parity: root ReMincross only reorders root/skeleton nodes;
  // cluster-internal nodes are handled by cluster-local build_ranks passes.
  let order_groups_for_mincross_base =
    build_order_groups_for_root_mincross(
      order_with_clusters,
      seeded_groups,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  if @sys.get_env_var("DOT_TRACE_ROOT_INPUT") is Some(_) {
    for rank, names in order_groups_for_mincross_base {
      let rank_joined = names.join(" ")
      println("root_input_rank \{rank}: \{rank_joined}")
      for name in names {
        let cluster = match order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        let skel = order_cluster_skeleton.get(name) == Some(true)
        println("root_input_node \{name} cluster=\{cluster} skel=\{skel}")
      }
    }
  }
  let order_groups_for_mincross =
    match root_mincross_groups_override.val {
      Some(override_groups) => clone_rank_groups(override_groups)
      None => order_groups_for_mincross_base
    }
  let (ordered_mincross, mincross_nodes) =
    run_root_mincross_rank_reorder_pass(
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
      merge_root_mincross_order_into_seeded_groups(
        order_rank_keys,
        seeded_groups,
        ordered_mincross,
        mincross_nodes,
        order_cluster_keys,
        order_cluster_skeleton,
      )
    } else {
      ordered_mincross
    }
  (order_groups_for_mincross, ordered)
}
