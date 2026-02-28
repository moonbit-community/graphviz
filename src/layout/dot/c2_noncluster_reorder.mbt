///|
/// Stage C Phase C2 split: non-cluster rank-reorder
/// helpers isolated from clustered ordering branches.

///|
/// Graphviz parity: non-cluster neighbor maps preserve ND_out tail order from
/// edge_out_order and ND_in head order from node-ordered ND_out scans.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_neighbor_maps(
  nodes : Array[@cgraph.Node],
  edge_out_order : Map[String, Array[Int]],
  edge_head : Array[String],
  edges : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  let node_names : Array[String] = []
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    node_names.push(name)
    graphviz_out_neighbors[name] = []
    graphviz_in_neighbors[name] = []
  }
  for name, list in edge_out_order {
    let heads : Array[String] = []
    for edge_idx in list {
      let head =
        if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
          edges[edge_idx].head().name()
        }
      heads.push(head)
    }
    graphviz_out_neighbors[name] = heads
  }
  // Graphviz parity: non-cluster ND_in neighbor order follows ND_out traversal
  // in graph node iteration order (agfstnode/agnxtnode), matching add_fast_edges.
  let in_entries : Map[String, Array[String]] = Map::new()
  for tail in node_names {
    let heads = match graphviz_out_neighbors.get(tail) {
      Some(list) => list
      None => []
    }
    for head in heads {
      match in_entries.get(head) {
        Some(list) => list.push(tail)
        None => in_entries[head] = [tail]
      }
    }
  }
  for head, entries in in_entries {
    graphviz_in_neighbors[head] = entries
  }
  (graphviz_out_neighbors, graphviz_in_neighbors)
}

///|
/// Graphviz parity: non-cluster mincross traverses connected components in
/// GD_nlist order (real nodes first), then runs mincross on each component.
/// Do not change behavior without updating fixtures/tests.
fn collect_noncluster_reorder_components(
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
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
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
/// Graphviz parity: non-cluster reorder path seeds node order from GD_nlist,
/// builds Graphviz-style ND_out/ND_in neighbor order, and runs rank reorder
/// without cluster remapping.
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_reorder_pass(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  nlist_order : Array[String],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  // Graphviz parity: non-cluster reorder seeds build_ranks node order from
  // GD_nlist, then falls back to existing node order for missing nodes.
  let order_node_order : Map[String, Int] = Map::new()
  let mut order_idx = 0
  for name in nlist_order {
    order_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  for name, idx in node_order {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let (parents, children) =
    build_edge_index_for_order(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
    )
  let (graphviz_out_neighbors, graphviz_in_neighbors) =
    build_noncluster_neighbor_maps(
      nodes,
      edge_out_order,
      edge_head,
      edges,
    )
  reorder_rank_groups(
    rank_keys,
    groups,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    parents,
    children,
    cluster_meta.cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    edge_order,
    order_node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    cluster_meta.cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
    graphviz_flip=graphviz_flip,
  )
}
