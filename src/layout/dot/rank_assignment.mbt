///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/rank.c + common/ns.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_directed_base(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  _edge_reversed : Array[Bool],
) -> Map[String, Int] {
  let graph = new_graph()
  let node_by_name : Map[String, @cgraph.Node] = Map::new()
  let tail_order : Array[String] = []
  for node in nodes {
    let name = node.name()
    node_by_name[name] = node
    tail_order.push(name)
  }
  let node_index : Map[String, Int] = Map::new()
  for idx, name in tail_order {
    node_index[name] = idx
  }
  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  for edge_idx in 0..<edges.length() {
    let tail = edge_tail[edge_idx]
    match edges_by_tail.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edges_by_tail[tail] = [edge_idx]
    }
  }
  let edge_creation : Array[(String, String)] = []
  for tail in tail_order {
    let indices = match edges_by_tail.get(tail) {
      Some(list) => list
      None => []
    }
    // Graphviz parity: agfstout/agnxtout order edges by head node sequence (AGSEQ).
    if indices.length() > 1 {
      indices.sort_by((a, b) => {
        let ha = edge_head[a]
        let hb = edge_head[b]
        let ha_idx = match node_index.get(ha) {
          Some(value) => value
          None => 0
        }
        let hb_idx = match node_index.get(hb) {
          Some(value) => value
          None => 0
        }
        if ha_idx < hb_idx {
          -1
        } else if ha_idx > hb_idx {
          1
        } else if a < b {
          -1
        } else if a > b {
          1
        } else {
          0
        }
      })
    }
    for edge_idx in indices {
      edge_creation.push((tail, edge_head[edge_idx]))
    }
  }
  // Graphviz parity: decompose ordering uses DFS over flat/in/out neighbors
  // driven by agfstnode/agfstout ordering.
  let rank_node_names = build_graphviz_nlist_order_from_edges(
    tail_order,
    tail_order,
    edge_creation,
    Map::new(),
  )
  let rank_nodes : Array[@cgraph.Node] = []
  let seen : Map[String, Bool] = Map::new()
  for name in rank_node_names {
    match node_by_name.get(name) {
      Some(node) => {
        rank_nodes.push(node)
        seen[name] = true
      }
      None => ()
    }
  }
  if rank_nodes.length() < nodes.length() {
    for node in nodes {
      let name = node.name()
      if seen.get(name) is None {
        rank_nodes.push(node)
        seen[name] = true
      }
    }
  }
  let rank_same_reps = build_rank_same_reps(source, nodes)
  let rep_index : Map[String, Int] = Map::new()
  let index : Map[String, Int] = Map::new()
  for node in rank_nodes {
    let name = node.name()
    let rep = match rank_same_reps.get(name) {
      Some(value) => value
      None => name
    }
    let idx = match rep_index.get(rep) {
      Some(value) => value
      None => {
        let value = add_node(graph, rep)
        rep_index[rep] = value
        value
      }
    }
    index[name] = idx
  }
  let merged_edges : Map[String, (Int, Int, Int, Int)] = Map::new()
  for tail_name in rank_node_names {
    let indices = match edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for edge_idx in indices {
      let edge = edges[edge_idx]
      if !edge_is_constraint(edge) {
        continue
      }
      let tail = edge_tail[edge_idx]
      let head = edge_head[edge_idx]
      // Graphviz parity: ignore self edges in rank constraints (compile_edges Xt==Xh).
      if tail == head {
        continue
      }
      let tail_idx = match index.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_idx = match index.get(head) {
        Some(value) => value
        None => 0
      }
      if tail_idx == head_idx {
        continue
      }
      let minlen_value = edge_minlen(edge)
      let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
      let weight = edge_weight(edge)
      let key = "\{tail_idx}:\{head_idx}"
      match merged_edges.get(key) {
        Some(entry) => {
          let (_tail_idx, _head_idx, current_minlen, current_weight) = entry
          let next_minlen = if minlen > current_minlen { minlen } else { current_minlen }
          merged_edges[key] = (tail_idx, head_idx, next_minlen, current_weight + weight)
        }
        None => merged_edges[key] = (tail_idx, head_idx, minlen, weight)
      }
    }
  }
  for _key, entry in merged_edges {
    let (tail_idx, head_idx, minlen, weight) = entry
    let _ = add_edge(graph, tail_idx, head_idx, minlen, weight)
  }
  network_simplex(graph, 0x7fffffff, BalanceMode::TB)
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    let rank = node_rank(graph, idx)
    if !seen {
      min_rank = rank
      seen = true
    } else if rank < min_rank {
      min_rank = rank
    }
  }
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    let rank = node_rank(graph, idx) - min_rank
    ranks[name] = rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}

///|
fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> Map[String, Int] {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(source, None, cluster_graphs, cluster_parents)
  let root_cluster_name =
    if is_cluster_graph(source) {
    match source.name() {
      Some(value) => value
      None => ""
    }
  } else {
    ""
  }
  let top_clusters : Array[String] = []
  for name, parent in cluster_parents {
    match parent {
      None =>
        if name != root_cluster_name {
          top_clusters.push(name)
        }
      Some(_) => ()
    }
  }
  if top_clusters.length() == 0 {
    let (base_tail, base_head, base_reversed) =
      acyclic_edge_directions(nodes, edges)
    return compute_ranks_directed_base(
      source,
      nodes,
      edges,
      has_edge_labels,
      base_tail,
      base_head,
      base_reversed,
    )
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  let node_cluster : Map[String, String] = Map::new()
  for cluster_name in top_clusters {
    match cluster_members.get(cluster_name) {
      Some(members) =>
        for name, _ in members {
          node_cluster[name] = cluster_name
        }
      None => ()
    }
  }
  let local_ranks : Map[String, Int] = Map::new()
  let cluster_leaders : Map[String, String] = Map::new()
  for cluster_name in top_clusters {
    let members = match cluster_members.get(cluster_name) {
      Some(value) => value
      None => continue
    }
    let cluster_nodes : Array[@cgraph.Node] = []
    for node in nodes {
      if members.get(node.name()) is Some(_) {
        cluster_nodes.push(node)
      }
    }
    if cluster_nodes.length() == 0 {
      continue
    }
    let cluster_edges : Array[@cgraph.Edge] = []
    for edge in edges {
      let tail = edge.tail().name()
      let head = edge.head().name()
      if members.get(tail) is Some(_) && members.get(head) is Some(_) {
        cluster_edges.push(edge)
      }
    }
    let (cluster_tail, cluster_head, cluster_reversed) =
      acyclic_edge_directions(cluster_nodes, cluster_edges)
    let cluster_graph = match cluster_graphs.get(cluster_name) {
      Some(value) => value
      None => source
    }
    let cluster_ranks = compute_ranks_directed(
      cluster_graph,
      cluster_nodes,
      cluster_edges,
      has_edge_labels,
      cluster_tail,
      cluster_head,
      cluster_reversed,
    )
    for name, rank in cluster_ranks {
      local_ranks[name] = rank
    }
    let mut leader_name : String? = None
    for node in cluster_nodes {
      let name = node.name()
      match cluster_ranks.get(name) {
        Some(rank) =>
          if rank == 0 && leader_name is None {
            leader_name = Some(name)
          }
        None => ()
      }
    }
    let leader =
      match leader_name {
        Some(name) => name
        None => cluster_nodes[0].name()
      }
    cluster_leaders[cluster_name] = leader
  }
  let rank_graph = new_graph()
  let rank_index : Map[String, Int] = Map::new()
  let rank_names : Array[String] = []
  for node in nodes {
    let name = node.name()
    let cluster = match node_cluster.get(name) {
      Some(value) => value
      None => ""
    }
    let key =
      if cluster == "" {
        name
      } else {
        match cluster_leaders.get(cluster) {
          Some(value) => value
          None => name
        }
      }
    if rank_index.get(key) is None {
      rank_index[key] = add_node(rank_graph, key)
      rank_names.push(key)
    }
  }
  let direct_tail : Array[String] = []
  let direct_head : Array[String] = []
  let direct_minlen : Array[Int] = []
  let direct_weight : Array[Int] = []
  let direct_active : Array[Bool] = []
  let mut slack_id = 0
  for edge in edges {
    if !edge_is_constraint(edge) {
      continue
    }
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let tail_cluster = match node_cluster.get(tail_name) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match node_cluster.get(head_name) {
      Some(value) => value
      None => ""
    }
    let minlen_value = edge_minlen(edge)
    let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
    let weight = edge_weight(edge)
    if tail_cluster == head_cluster {
      if tail_cluster == "" && tail_name != head_name {
        direct_tail.push(tail_name)
        direct_head.push(head_name)
        direct_minlen.push(minlen)
        direct_weight.push(weight)
        direct_active.push(true)
      }
      continue
    }
    let tail_leader =
      if tail_cluster == "" {
        tail_name
      } else {
        match cluster_leaders.get(tail_cluster) {
          Some(value) => value
          None => tail_name
        }
      }
    let head_leader =
      if head_cluster == "" {
        head_name
      } else {
        match cluster_leaders.get(head_cluster) {
          Some(value) => value
          None => head_name
        }
      }
    let tail_local = match local_ranks.get(tail_name) {
      Some(value) => value
      None => 0
    }
    let head_local = match local_ranks.get(head_name) {
      Some(value) => value
      None => 0
    }
    let offset = minlen + tail_local - head_local
    let (t_len, h_len) =
      if offset > 0 { (0, offset) } else { (-offset, 0) }
    let slack_name = "_mbt_rank_slack_\{slack_id}"
    slack_id = slack_id + 1
    let slack_idx = add_node(rank_graph, slack_name, kind=NodeKind::Slack)
    let tail_idx = match rank_index.get(tail_leader) {
      Some(value) => value
      None => continue
    }
    let head_idx = match rank_index.get(head_leader) {
      Some(value) => value
      None => continue
    }
    let _ = add_edge(rank_graph, slack_idx, tail_idx, t_len, weight * CL_BACK)
    let _ = add_edge(rank_graph, slack_idx, head_idx, h_len, weight)
  }
  let (direct_tail_final, direct_head_final, _direct_rev) =
    acyclic_edge_directions_for_names(
      rank_names,
      direct_tail,
      direct_head,
      direct_active,
    )
  let merged_edges : Map[String, (Int, Int, Int, Int)] = Map::new()
  for i in 0..<direct_tail_final.length() {
    let tail_name = direct_tail_final[i]
    let head_name = direct_head_final[i]
    if tail_name == head_name {
      continue
    }
    let tail_idx = match rank_index.get(tail_name) {
      Some(value) => value
      None => continue
    }
    let head_idx = match rank_index.get(head_name) {
      Some(value) => value
      None => continue
    }
    let minlen = direct_minlen[i]
    let weight = direct_weight[i]
    let key = "\{tail_idx}:\{head_idx}"
    match merged_edges.get(key) {
      Some(entry) => {
        let (_tail_idx, _head_idx, current_minlen, current_weight) = entry
        let next_minlen =
          if minlen > current_minlen { minlen } else { current_minlen }
        merged_edges[key] =
          (tail_idx, head_idx, next_minlen, current_weight + weight)
      }
      None => merged_edges[key] = (tail_idx, head_idx, minlen, weight)
    }
  }
  for _key, entry in merged_edges {
    let (tail_idx, head_idx, minlen, weight) = entry
    let _ = add_edge(rank_graph, tail_idx, head_idx, minlen, weight)
  }
  let _ = network_simplex_pre_balance(rank_graph, 0x7fffffff)
  let leader_ranks : Map[String, Int] = Map::new()
  for name, idx in rank_index {
    leader_ranks[name] = node_rank(rank_graph, idx)
  }
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let cluster = match node_cluster.get(name) {
      Some(value) => value
      None => ""
    }
    let base_rank =
      if cluster == "" {
        match leader_ranks.get(name) {
          Some(value) => value
          None => 0
        }
      } else {
        let leader = match cluster_leaders.get(cluster) {
          Some(value) => value
          None => name
        }
        let leader_rank = match leader_ranks.get(leader) {
          Some(value) => value
          None => 0
        }
        let local_rank = match local_ranks.get(name) {
          Some(value) => value
          None => 0
        }
        leader_rank + local_rank
      }
    if !seen {
      min_rank = base_rank
      seen = true
    } else if base_rank < min_rank {
      min_rank = base_rank
    }
    ranks[name] = base_rank
  }
  for name, rank in ranks {
    ranks[name] = rank - min_rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}

///|
fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
) -> Map[String, Int] {
  if graph_has_cluster(source) {
    return compute_ranks_directed_with_clusters(
      source,
      nodes,
      edges,
      has_edge_labels,
    )
  }
  compute_ranks_directed_base(
    source,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
    edge_reversed,
  )
}
