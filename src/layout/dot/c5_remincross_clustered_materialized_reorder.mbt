///|
/// Stage C Phase C5 split: clustered materialized-edge
/// reorder/input orchestration helpers.

///|
/// Graphviz parity: clustered ReMincross final reorder runs with real-node
/// cleanup after vnode-inclusive rematerialized edge ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_final_reorder(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_remincross_reorder_and_collect_real_groups(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    rank_same_groups,
    rank_same_order,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    rem_flat_constraints,
    graphviz_flip,
    real_nodes,
  )
}

///|
/// Graphviz parity: clustered ReMincross derives rank map, order-node list,
/// and temporary order graph directly from vnode-augmented rem_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_graph_inputs(
  rem_groups : Map[Int, Array[String]],
  rem_rank_keys : Array[Int],
) -> (Map[String, Int], Array[String], @cgraph.Graph, Map[String, @cgraph.Node]) {
  let rem_ranks = build_node_ranks(rem_groups)
  let rem_nodes = build_order_nodes_from_groups(rem_groups, rem_rank_keys)
  let (rem_graph, rem_node_map) =
    build_order_graph_and_nodes("order_remincross", rem_nodes)
  (rem_ranks, rem_nodes, rem_graph, rem_node_map)
}

///|
/// Graphviz parity: clustered ReMincross order-edge rematerialization uses
/// Graphviz ND_out chain expansion with vnode creation + edge creation outputs.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_order_edges_by_tail(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index : Map[String, Int],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  let rem_edges_by_tail = edges_by_tail
  let (rem_order_edges_by_tail_raw, rem_vnode_creation, _rem_edge_creation_raw) =
    build_order_edges_by_tail_graphviz(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      false,
      false,
      rem_edges_by_tail,
      cluster_order_index=cluster_order_index,
    )
  let rem_order_edges_by_tail_coalesced =
    coalesce_order_edges_by_tail(rem_order_edges_by_tail_raw)
  let intercluster_bonus =
    collect_intercluster_vnode_tail_bonus(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      rem_edges_by_tail,
      cluster_keys,
    )
  let rem_order_edges_by_tail =
    apply_intercluster_vnode_tail_bonus(
      rem_order_edges_by_tail_coalesced,
      intercluster_bonus,
    )
  let rem_edge_creation =
    rebuild_edge_creation_from_tail_order(
      creation_order,
      rem_order_edges_by_tail,
    )
  (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation)
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge flow traces
/// ND_out-derived remapped edge chains immediately after Graphviz-style
/// edge rematerialization inputs are constructed.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_order_edges_by_tail_with_trace(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index : Map[String, Int],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  let (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation) =
    build_clustered_remincross_order_edges_by_tail(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      edges_by_tail,
      cluster_order_index,
    )
  trace_remincross_order_edges_by_tail(rem_order_edges_by_tail)
  (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation)
}

///|
/// Graphviz parity: clustered ReMincross materializes remapped order edges
/// from ND_out chains, then rebuilds GD_nlist-seeded edge arrays with traces.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation) =
    build_clustered_remincross_order_edges_by_tail_with_trace(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      edges_by_tail,
      cluster_order_index,
    )
  build_clustered_remincross_materialized_edges_output_phase(
    flat_rank_constraints,
    creation_order,
    rem_vnode_creation,
    rem_edge_creation,
    cluster_keys,
    cluster_order_index,
    rem_order_edges_by_tail,
    rem_graph,
    rem_node_map,
    rem_groups,
  )
}

///|
/// Graphviz parity: clustered ReMincross edge index inputs are derived from
/// rematerialized edge arrays before the final startpass=2 reorder call.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_edge_indices_for_reorder(
  rem_nodes : Array[String],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  build_order_edge_indices_and_order(
    rem_nodes,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_ranks,
    rem_edges_out,
  )
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge flow rebuilds
/// remapped order graph arrays, then traces edge endpoints before tuple output.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_graph_with_trace(
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let _ = flat_rank_constraints
  let (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    build_remincross_materialized_order_graph(
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_cluster_keys,
      cluster_order_index,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  trace_remincross_materialized_edges(
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
  )
  (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge output preserves
/// node-order and remapped edge/port arrays in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges_output(
  rem_node_order : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}


///|
/// Graphviz parity: clustered ReMincross materialized-edge output phase keeps
/// graph-materialization tuple ordering before returning remapped edge arrays.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges_output_phase(
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    build_clustered_remincross_materialized_graph_with_trace(
      flat_rank_constraints,
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_cluster_keys,
      cluster_order_index,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  build_clustered_remincross_materialized_edges_output(
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}


///|
/// Graphviz parity: ReMincross order-graph materialization filters local flat
/// constraints by fast-graph membership, rebuilds GD_nlist, seeds node order,
/// then materializes edge arrays in nlist tail order.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_materialized_order_graph(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let rem_ranks = build_node_ranks(rem_groups)
  let rem_nlist_order =
    build_remincross_nlist_order(
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_ranks,
      rem_cluster_keys,
      cluster_order_index,
    )
  let rem_node_order = build_order_index(rem_groups)
  let (
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    collect_order_edges_for_tail_sequence(
      rem_nlist_order,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
    )
  build_clustered_remincross_materialized_edges_output(
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: ReMincross GD_nlist order keeps cluster-local blocks in
/// first-seen cluster sequence and replays each cluster block by rank-desc
/// reverse-order before root-cluster nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_nlist_order(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
) -> Array[String] {
  let rem_order_creation =
    build_rem_order_creation_sequence(creation_order, rem_vnode_creation)
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let debug_names : Array[String] = [
      "i-gd-gd",
      "o-gd-vrml",
      "i-core-ps",
      "i-core-svg",
      "i-svg",
    ]
    for name in debug_names {
      let cluster = match rem_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      let rank = match rem_ranks.get(name) {
        Some(value) => value
        None => -1
      }
      println("remincross cluster_key \{name}=\{cluster} rank=\{rank}")
    }
  }
  let rem_nlist_order =
    if cluster_order_index.length() <= 2 {
      // Graphviz parity: single-cluster/root-only remincross materialization
      // replays tails in reverse rem_order_creation sequence.
      let reversed : Array[String] = []
      let mut idx = rem_order_creation.length()
      while idx > 0 {
        idx = idx - 1
        reversed.push(rem_order_creation[idx])
      }
      reversed
    } else {
      build_remincross_cluster_tail_order(
        rem_order_creation,
        rem_ranks,
        rem_cluster_keys,
        rem_edge_creation,
        cluster_order_index,
      )
    }
  if rem_nlist_order.length() < rem_order_creation.length() {
    let seen : Map[String, Bool] = Map::new()
    for name in rem_nlist_order {
      seen[name] = true
    }
    for name in rem_order_creation {
      if seen.get(name) is None {
        rem_nlist_order.push(name)
        seen[name] = true
      }
    }
  }
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let rem_creation_joined = rem_order_creation.join(" ")
    let rem_nlist_joined = rem_nlist_order.join(" ")
    println("remincross rem_order_creation \{rem_creation_joined}")
    println("remincross rem_nlist_order \{rem_nlist_joined}")
  }
  rem_nlist_order
}

///|
/// Debug trace: dump selected ReMincross per-tail edge lists when
/// DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_order_edges_by_tail(
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  match rem_order_edges_by_tail.get("arbiter_vadam") {
    Some(list) => {
      let mut idx = 0
      while idx < list.length() {
        let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
        println("remincross arbiter edge \{idx}: \{t} -> \{h}")
        idx = idx + 1
      }
    }
    None => ()
  }
  let debug_tails : Array[String] = ["front_end_jz", "others"]
  for name in debug_tails {
    match rem_order_edges_by_tail.get(name) {
      Some(list) => {
        let mut idx = 0
        while idx < list.length() {
          let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
          println("remincross out \{name} \{idx}: \{t} -> \{h}")
          idx = idx + 1
        }
      }
      None => ()
    }
  }
}

///|
/// Debug trace: dump materialized ReMincross edges (high-pen and selected
/// endpoints) when DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_materialized_edges(
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let mut idx = 0
  while idx < rem_edges_out.length() {
    let edge = rem_edges_out[idx]
    let pen = @dot_shared.edge_xpenalty(edge)
    if pen >= CL_CROSS {
      let tail = rem_edge_tail_out[idx]
      let head = rem_edge_head_out[idx]
      println("remincross high-pen edge \{tail} -> \{head} pen=\{pen}")
    }
    idx = idx + 1
  }
  let mut edge_idx = 0
  while edge_idx < rem_edge_tail_out.length() {
    let tail = rem_edge_tail_out[edge_idx]
    let head = rem_edge_head_out[edge_idx]
    if tail == "z_req" || tail == "z_req1" || head == "z_req" ||
      head == "z_req1" {
      println("remincross edge \{edge_idx}: \{tail} -> \{head}")
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Stage C Phase C5 split: remincross cluster tail order
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: ReMincross GD_nlist order is rebuilt from creation order
/// + vnode expansion + fast-graph edge insertion order (decompose parity).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_tail_order(
  rem_order_creation : Array[String],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  rem_edge_creation : Array[(String, String)],
  cluster_order_index : Map[String, Int],
) -> Array[String] {
  let (cluster_order_seen, names_by_cluster, cluster_first_seen) =
    build_remincross_cluster_order_seen_and_names(
      rem_order_creation,
      rem_cluster_keys,
    )
  let (cluster_order, cluster_order_pos) =
    build_remincross_cluster_order_and_positions(
      cluster_order_seen,
      cluster_first_seen,
      cluster_order_index,
    )
  let heads_by_tail = build_remincross_heads_by_tail(rem_edge_creation)
  let rem_nlist_order : Array[String] = []
  for cluster in cluster_order {
    let names = match names_by_cluster.get(cluster) {
      Some(list) => list
      None => []
    }
    if cluster == "" {
      let root_names = match remincross_root_tail_order_override_snapshot.val {
        Some(override_names) =>
          reorder_rank_names_by_override(
            names,
            override_names,
          )
        None => names
      }
      for name in root_names {
        rem_nlist_order.push(name)
      }
      continue
    }
    let nonroot_rank_ordered =
      build_remincross_cluster_tail_order_nonroot_names(
        cluster,
        names,
        rem_ranks,
        heads_by_tail,
        cluster_order_pos,
        cluster_order,
        rem_cluster_keys,
      )
    for name in nonroot_rank_ordered {
      rem_nlist_order.push(name)
    }
  }
  rem_nlist_order
}

///|
/// Graphviz parity: clustered tail-order cluster lookup uses explicit
/// rem_cluster_keys with skeleton-name fallback parsing.
/// Do not change behavior without updating fixtures/tests.
fn cluster_key_for_remincross_tail_order_name(
  rem_cluster_keys : Map[String, String],
  name : String,
) -> String {
  let direct = match rem_cluster_keys.get(name) {
    Some(value) => value
    None => ""
  }
  if direct != "" {
    return direct
  }
  if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
    return ""
  }
  let prefix_len = CLUSTER_SKELETON_PREFIX.length()
  let len = name.length()
  if prefix_len >= len {
    return ""
  }
  let suffix = name.unsafe_substring(start=prefix_len, end=len)
  match suffix.find("@") {
    Some(pos) =>
      if pos > 0 { suffix.unsafe_substring(start=0, end=pos) } else { "" }
    None => ""
  }
}

///|
/// Graphviz parity: clustered tail-order setup preserves first-seen cluster
/// sequence while grouping rem_order_creation names by cluster key.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_order_seen_and_names(
  rem_order_creation : Array[String],
  rem_cluster_keys : Map[String, String],
) -> (Array[String], Map[String, Array[String]], Map[String, Int]) {
  let cluster_order_seen : Array[String] = []
  let cluster_seen : Map[String, Bool] = Map::new()
  let names_by_cluster : Map[String, Array[String]] = Map::new()
  for name in rem_order_creation {
    let cluster =
      cluster_key_for_remincross_tail_order_name(
        rem_cluster_keys,
        name,
      )
    if cluster_seen.get(cluster) is None {
      cluster_seen[cluster] = true
      cluster_order_seen.push(cluster)
    }
    match names_by_cluster.get(cluster) {
      Some(list) => list.push(name)
      None => names_by_cluster[cluster] = [name]
    }
  }
  let cluster_first_seen : Map[String, Int] = Map::new()
  for idx, cluster in cluster_order_seen {
    cluster_first_seen[cluster] = idx
  }
  (cluster_order_seen, names_by_cluster, cluster_first_seen)
}

///|
/// Graphviz parity: clustered tail-order cluster ordering sorts non-root
/// clusters by descending cluster_order_index, then by first-seen sequence.
/// Root cluster always remains last when present.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_order_and_positions(
  cluster_order_seen : Array[String],
  cluster_first_seen : Map[String, Int],
  cluster_order_index : Map[String, Int],
) -> (Array[String], Map[String, Int]) {
  let cluster_order_non_root : Array[String] = []
  let mut has_root_cluster = false
  for cluster in cluster_order_seen {
    if cluster == "" {
      has_root_cluster = true
    } else {
      cluster_order_non_root.push(cluster)
    }
  }
  cluster_order_non_root.sort_by((a, b) => {
    let a_idx = match cluster_order_index.get(a) {
      Some(value) => value
      None => -1
    }
    let b_idx = match cluster_order_index.get(b) {
      Some(value) => value
      None => -1
    }
    if a_idx > b_idx {
      return -1
    }
    if a_idx < b_idx {
      return 1
    }
    let a_seen = match cluster_first_seen.get(a) {
      Some(value) => value
      None => 0
    }
    let b_seen = match cluster_first_seen.get(b) {
      Some(value) => value
      None => 0
    }
    if a_seen < b_seen {
      -1
    } else if a_seen > b_seen {
      1
    } else {
      0
    }
  })
  let cluster_order = cluster_order_non_root
  if has_root_cluster {
    cluster_order.push("")
  }
  let cluster_order_pos : Map[String, Int] = Map::new()
  for idx, cluster in cluster_order {
    cluster_order_pos[cluster] = idx
  }
  (cluster_order, cluster_order_pos)
}

///|
/// Graphviz parity: clustered tail-order setup preserves rem_edge_creation
/// tail insertion order in heads_by_tail adjacency buckets.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_heads_by_tail(
  rem_edge_creation : Array[(String, String)],
) -> Map[String, Array[String]] {
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  for edge in rem_edge_creation {
    let (tail, head) = edge
    match heads_by_tail.get(tail) {
      Some(list) => list.push(head)
      None => heads_by_tail[tail] = [head]
    }
  }
  heads_by_tail
}

///|
/// Graphviz parity: clustered tail-order non-root phase preserves rank-key
/// collection, descending rank replay, and input-like category rebucketing.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_tail_order_nonroot_names(
  cluster : String,
  names : Array[String],
  rem_ranks : Map[String, Int],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let rank_keys : Array[Int] = []
  let rank_seen : Map[Int, Bool] = Map::new()
  for name in names {
    let rank = match rem_ranks.get(name) {
      Some(value) => value
      None => -1
    }
    if rank_seen.get(rank) is None {
      rank_seen[rank] = true
      rank_keys.push(rank)
    }
  }
  rank_keys.sort()
  let min_rank = {
    let mut candidate = -1
    for value in rank_keys {
      if value >= 0 {
        candidate = value
        break
      }
    }
    candidate
  }
  let cluster_rank_ordered : Array[String] = []
  let mut rank_idx = rank_keys.length()
  while rank_idx > 0 {
    rank_idx = rank_idx - 1
    let rank = rank_keys[rank_idx]
    let rank_names : Array[String] = []
    for name in names {
      let name_rank = match rem_ranks.get(name) {
        Some(value) => value
        None => -1
      }
      if name_rank == rank {
        rank_names.push(name)
      }
    }
    let rank_ordered =
      build_remincross_cluster_rank_ordered_names(
        cluster,
        rank_names,
        heads_by_tail,
      )
    let mut all_input_like = true
    for name in rank_ordered {
      if !name.has_prefix("i-") {
        all_input_like = false
        break
      }
    }
    if rank == min_rank && rank_ordered.length() > 1 && all_input_like {
      let reordered_rank =
        rebucket_remincross_input_like_rank_order(
          cluster,
          rank_ordered,
          heads_by_tail,
          cluster_order_pos,
          cluster_order,
          rem_cluster_keys,
        )
      let mut idx = 0
      while idx < reordered_rank.length() {
        rank_ordered[idx] = reordered_rank[idx]
        idx = idx + 1
      }
    }
    for name in rank_ordered {
      cluster_rank_ordered.push(name)
    }
  }
  cluster_rank_ordered
}

///|
/// Graphviz parity: clustered tail-order rank names remain forward when all
/// names have no outgoing edges in non-root cluster blocks; otherwise replayed
/// in reverse insertion order.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_rank_ordered_names(
  cluster : String,
  rank_names : Array[String],
  heads_by_tail : Map[String, Array[String]],
) -> Array[String] {
  let rank_ordered : Array[String] = []
  let mut all_without_outgoing = true
  for name in rank_names {
    if heads_by_tail.get(name) is Some(_) {
      all_without_outgoing = false
      break
    }
  }
  if cluster != "" && all_without_outgoing {
    for name in rank_names {
      rank_ordered.push(name)
    }
    return rank_ordered
  }
  let mut name_idx = rank_names.length()
  while name_idx > 0 {
    name_idx = name_idx - 1
    rank_ordered.push(rank_names[name_idx])
  }
  rank_ordered
}

///|
/// Graphviz parity: minimum-rank all-input-like clustered rank blocks are
/// rebucketed by outgoing cross-cluster direction and out-degree priority.
/// Do not change behavior without updating fixtures/tests.
fn rebucket_remincross_input_like_rank_order(
  cluster : String,
  rank_ordered : Array[String],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let current_cluster_pos = match cluster_order_pos.get(cluster) {
    Some(value) => value
    None => 0
  }
  let category0 : Array[String] = []
  let category1 : Array[String] = []
  let category2 : Array[String] = []
  let category3 : Array[String] = []
  for name in rank_ordered {
    let heads = match heads_by_tail.get(name) {
      Some(list) => list
      None => []
    }
    let mut has_later = false
    let mut has_earlier = false
    for head in heads {
      let head_cluster =
        cluster_key_for_remincross_tail_order_name(rem_cluster_keys, head)
      if head_cluster == cluster {
        continue
      }
      let head_pos = match cluster_order_pos.get(head_cluster) {
        Some(value) => value
        None => cluster_order.length()
      }
      if head_pos > current_cluster_pos {
        has_later = true
      } else if head_pos < current_cluster_pos {
        has_earlier = true
      }
    }
    let out_degree = heads.length()
    if !has_later && !has_earlier && out_degree > 1 {
      category0.push(name)
    } else if has_later {
      category1.push(name)
    } else if has_earlier {
      category2.push(name)
    } else {
      category3.push(name)
    }
  }
  let reordered_rank : Array[String] = []
  for name in category0 {
    reordered_rank.push(name)
  }
  for name in category1 {
    reordered_rank.push(name)
  }
  for name in category2 {
    reordered_rank.push(name)
  }
  for name in category3 {
    reordered_rank.push(name)
  }
  reordered_rank
}
