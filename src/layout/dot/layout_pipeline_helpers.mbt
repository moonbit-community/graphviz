///|
priv struct LayoutPrep {
  rankdir : RankDir
  nodesep_in : Double
  ranksep_in : Double
  splines : SplinesMode
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  has_dotted_edges : Bool
  has_port_edges : Bool
  has_edge_labels : Bool
  node_order : Map[String, Int]
  record_orientation : RecordOrientation
  output_sizes : Map[String, NodeSize]
  order_sizes : Map[String, NodeSize]
  sizes : Map[String, NodeSize]
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
priv struct RankData {
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  edge_in_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  all_ranks : Array[Int]
  self_edge_labels : Map[String, Double]
}

///|
priv struct RankHeights {
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  nodesep_pt : Double
  ranksep_pt : Double
}

///|
priv struct ClusterMetadata {
  has_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
priv struct OrderingResult {
  ordered_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  vnode_info : EdgeVnodeInfo
  vnode_count : Int
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  edge_order : Map[String, Int]
  edge_cluster_keys : Map[String, String]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
priv struct PositionResult {
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  flat_label_edge_vnodes : Map[String, String]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  cluster_bbox_heights : Map[String, (Double, Double)]
}

///|
/// Graphviz parity: layout attribute parsing aligned to refs/graphviz/lib/dotgen/dotinit.c + lib/common/input.c.
/// Do not change behavior without updating fixtures/tests.
///|
/// Graphviz parity: layout attribute parsing aligned to refs/graphviz/lib/dotgen/dotinit.c + lib/common/input.c.
/// Do not change behavior without updating fixtures/tests.
fn prepare_layout_inputs(
  graph : @cgraph.Graph,
  opts : DotLayoutOptions,
) -> LayoutPrep raise DotLayoutError {
  let rankdir = match opts.rankdir {
    Some(value) => value
    None =>
      match graph.get_attr("rankdir") {
        Some(value) =>
          match parse_rankdir(value) {
            Some(parsed) => parsed
            None => RankDir::TB
          }
        None => RankDir::TB
      }
  }
  let nodesep_raw = match opts.nodesep {
    Some(value) => value
    None =>
      match graph.get_attr("nodesep") {
        Some(value) => parse_first_double(value, default_nodesep_in())
        None => default_nodesep_in()
      }
  }
  if nodesep_raw < 0.0 {
    raise DotLayoutError::InvalidGraph(message="nodesep must be non-negative")
  }
  // Graphviz parity: late_double clamps nodesep to MIN_NODESEP.
  let nodesep_in =
    if nodesep_raw < MIN_NODESEP_IN { MIN_NODESEP_IN } else { nodesep_raw }
  let ranksep_raw = match opts.ranksep {
    Some(value) => value
    None =>
      match graph.get_attr("ranksep") {
        Some(value) => parse_first_double(value, default_ranksep_in())
        None => default_ranksep_in()
      }
  }
  if ranksep_raw < 0.0 {
    raise DotLayoutError::InvalidGraph(message="ranksep must be non-negative")
  }
  // Graphviz parity: ranksep clamps to MIN_RANKSEP.
  let ranksep_in =
    if ranksep_raw < MIN_RANKSEP_IN { MIN_RANKSEP_IN } else { ranksep_raw }
  let splines = match opts.splines {
    Some(value) => value
    None =>
      match graph.get_attr("splines") {
        Some(value) =>
          match parse_splines(value) {
            Some(parsed) => parsed
            None => SplinesMode::Spline
          }
        None => SplinesMode::Spline
      }
  }
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  dot_trace("layout_dot: start nodes=\{nodes.length()} edges=\{edges.length()}")
  let mut has_dotted_edges = false
  let mut has_port_edges = false
  for edge in edges {
    match edge.get_attr("style") {
      Some(value) =>
        if value.to_lower().contains("dotted") {
          has_dotted_edges = true
        }
      None => ()
    }
    if !has_port_edges {
      let tail_port = port_is_explicit(edge.tail_port())
      let head_port = port_is_explicit(edge.head_port())
      if tail_port || head_port {
        has_port_edges = true
      }
    }
  }
  let has_edge_labels = graph_has_edge_labels(edges)
  // Graphviz parity: GD_nlist iteration follows creation order (AGSEQ).
  let node_order : Map[String, Int] = Map::new()
  let nlist_nodes = nodes
  let mut order_idx = 0
  while order_idx < nlist_nodes.length() {
    node_order[nlist_nodes[order_idx].name()] = order_idx
    order_idx = order_idx + 1
  }
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_names : Array[String] = [
      "z_req",
      "z_req1",
      "handle_x",
      "handle_1",
      "mobvm_a_req",
      "mobvm_a_req1",
    ]
    for name in debug_names {
      match node_order.get(name) {
        Some(value) => println("raw_node_order \{name}=\{value}")
        None => ()
      }
    }
  }
  if rankdir == RankDir::RL {
    let total = nodes.length()
    for node in nodes {
      let name = node.name()
      let base = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = total - 1 - base
    }
  }
  let record_orientation = record_layout_orientation(rankdir)
  let output_sizes : Map[String, NodeSize] = Map::new()
  let order_sizes : Map[String, NodeSize] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let size = node_size(node, record_orientation)
    output_sizes[node.name()] = size
    order_sizes[node.name()] = size
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      swap_node_size(size)
    } else {
      size
    }
  }
  let port_order_positions : Map[String, Double] = Map::new()
  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  if (rankdir == RankDir::LR || rankdir == RankDir::RL) && has_port_edges {
    let record_port_order : Map[String, Map[String, Double]] = Map::new()
    for node in nodes {
      let label = label_text(node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html || is_record_shape(node) {
        let name = node.name()
        let size = match output_sizes.get(name) {
          Some(value) => value
          None => node_size(node, record_orientation)
        }
        let raw_ports =
          if has_html {
            html_ports(node, { x: 0.0, y: 0.0 }, size)
          } else {
            record_ports(node, { x: 0.0, y: 0.0 }, size, record_orientation)
          }
        let order_map : Map[String, Double] = Map::new()
        for port_name, port in raw_ports {
          let offset = layout_port_offset(port.center, rankdir)
          order_map[port_name] = offset.x
        }
        record_port_order[name] = order_map
      }
    }
    let order_sum : Map[String, (Double, Int)] = Map::new()
    let update_order = (target : String, anchor : String, port : @cgraph.Port?) => {
      match port {
        Some(value) =>
          match value.name {
            Some(port_name) =>
              match record_port_order.get(anchor) {
                Some(ports) =>
                  match ports.get(port_name) {
                    Some(order) => {
                      let (sum, count) = match order_sum.get(target) {
                        Some(value) => value
                        None => (0.0, 0)
                      }
                      order_sum[target] = (sum + order, count + 1)
                      match port_order_contrib.get(target) {
                        Some(list) => list.push((anchor, order))
                        None => port_order_contrib[target] = [(anchor, order)]
                      }
                    }
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
        None => ()
      }
    }
    for edge in edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
        update_order(head_name, tail_name, edge.tail_port())
      }
      if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
        update_order(tail_name, head_name, edge.head_port())
      }
    }
    for name, entry in order_sum {
      let (sum, count) = entry
      if count > 0 {
        port_order_positions[name] = sum / count.to_double()
      }
    }
  }
  {
    rankdir,
    nodesep_in,
    ranksep_in,
    splines,
    nodes,
    edges,
    has_dotted_edges,
    has_port_edges,
    has_edge_labels,
    node_order,
    record_orientation,
    output_sizes,
    order_sizes,
    sizes,
    port_order_positions,
    port_order_contrib,
  }
}

///|
/// Graphviz parity: rank direction + acyclic edge directions aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_data(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> RankData {
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  let edge_in_order : Map[String, Array[Int]] = Map::new()
  let (edge_tail, edge_head, edge_reversed) =
    if graph.kind() == @cgraph.GraphKind::Directed {
      let (tail, head, reversed, out_edges, in_edges) =
        acyclic_edge_directions_with_order(graph, nodes, edges)
      for i in 0..<nodes.length() {
        let name = nodes[i].name()
        edge_out_order[name] = out_edges[i].copy()
        edge_in_order[name] = in_edges[i].copy()
      }
      (tail, head, reversed)
    } else {
      let (tail, head, reversed) = edge_endpoints_from_edges(edges)
      for node in nodes {
        let name = node.name()
        edge_out_order[name] = []
        edge_in_order[name] = []
      }
      for i in 0..<tail.length() {
        let t = tail[i]
        let h = head[i]
        match edge_out_order.get(t) {
          Some(list) => list.push(i)
          None => edge_out_order[t] = [i]
        }
        match edge_in_order.get(h) {
          Some(list) => list.push(i)
          None => edge_in_order[h] = [i]
        }
      }
      (tail, head, reversed)
    }
  let ranks = if graph.kind() == @cgraph.GraphKind::Directed {
    compute_ranks_directed(
      graph,
      nodes,
      edges,
      has_edge_labels,
      edge_tail,
      edge_head,
      edge_reversed,
    )
  } else {
    let base : Map[String, Int] = Map::new()
    for node in nodes {
      base[node.name()] = 0
    }
    base
  }
  let groups = build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  let self_edge_labels = self_edge_label_half_heights(edges)
  {
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    edge_in_order,
    ranks,
    groups,
    rank_keys,
    all_ranks,
    self_edge_labels,
  }
}

///|
/// Graphviz parity: rank height/spacing aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_heights(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rankdir : RankDir,
  nodesep_in : Double,
  ranksep_in : Double,
  has_edge_labels : Bool,
) -> RankHeights {
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_half = 0.0
    for name in names {
      let half_height = node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
  if has_edge_labels {
    for edge in edges {
      if !edge_has_label(edge) {
        continue
      }
      let tail = edge.tail().name()
      let head = edge.head().name()
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => continue
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => continue
      }
      let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
      let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
      if max_rank - min_rank <= 1 {
        continue
      }
      let label_rank = (min_rank + max_rank) / 2
      let half_height = match edge_mid_label_metrics(edge) {
        Some((width, height)) =>
          if rankdir == RankDir::LR || rankdir == RankDir::RL {
            width / 2.0
          } else {
            height / 2.0
          }
        None => 0.0
      }
      let current = match rank_pht.get(label_rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[label_rank] = half_height
      }
    }
  }
  let vnode_half_height = VNODE_HEIGHT_PT / 2.0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      continue
    }
    for rank in (min_rank + 1)..<max_rank {
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if vnode_half_height > current {
        rank_pht[rank] = vnode_half_height
      }
    }
  }
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = match rank_pht.get(rank) {
      Some(value) => value
      None => 0.0
    }
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  let _ = apply_cluster_rank_heights(
    graph, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2, rankdir,
  )
  let nodesep_pt = round_int(nodesep_in * 72.0).to_double()
  let mut ranksep_pt_int = round_int(ranksep_in * 72.0)
  if has_edge_labels {
    ranksep_pt_int = (ranksep_pt_int + 1) / 2
  }
  let ranksep_pt = ranksep_pt_int.to_double()
  { rank_pht, rank_ht1, rank_ht2, nodesep_pt, ranksep_pt }
}

///|
/// Graphviz parity: cluster metadata/order aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/compound.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_cluster_metadata(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  edge_tail : Array[String],
  edge_head : Array[String],
  graphviz_flip : Bool,
) -> ClusterMetadata {
  let has_clusters = graph_has_cluster(graph)
  let cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    cluster_keys[node.name()] = node_cluster_key(node)
  }
  let creation_order : Map[String, Int] = Map::new()
  for i, node in nodes {
    creation_order[node.name()] = i
  }
  // Graphviz parity: cluster subgraphs walk GD_nlist backward to preserve input
  // order. For TB/BT, use creation order (input). For LR/RL, use reverse
  // creation order so the later rank flip restores input order.
  let total_nodes = nodes.length()
  for node in nodes {
    let name = node.name()
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let base_order = match creation_order.get(name) {
      Some(value) => value
      None => 0
    }
    let order_value =
      if graphviz_flip {
      total_nodes - 1 - base_order
    } else {
      base_order
    }
    node_order[name] = order_value
  }
  let cluster_skeleton : Map[String, Bool] = Map::new()
  let cluster_rank_seen : Map[String, Bool] = Map::new()
  for rank, names in groups {
    for name in names {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let key = "\{cluster}@\{rank}"
      if cluster_rank_seen.get(key) is None {
        cluster_rank_seen[key] = true
        cluster_skeleton[name] = true
      }
    }
  }
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let cluster_first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match cluster_min_rank.get(cluster) {
      Some(current) => if rank < current { cluster_min_rank[cluster] = rank }
      None => cluster_min_rank[cluster] = rank
    }
    match cluster_max_rank.get(cluster) {
      Some(current) => if rank > current { cluster_max_rank[cluster] = rank }
      None => cluster_max_rank[cluster] = rank
    }
    if cluster_first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      cluster_first_order[cluster] = order_value
    }
  }
  let cluster_order : Array[String] = []
  collect_cluster_names_graphviz_order(graph, cluster_order)
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) && cluster_order.length() > 0 {
    let joined = cluster_order.join(" ")
    println("cluster_order \{joined}")
  }
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  let cluster_order_list : Array[(String, Int, Int)] = []
  for cluster, rank in cluster_min_rank {
    let order = match cluster_first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    cluster_order_list.push((cluster, rank, order))
  }
  let cluster_order_base : Map[String, Int] = Map::new()
  if cluster_order_list.length() > 1 &&
    @sys.get_env_var("DOT_CLUSTER_ORDER_BASE") is Some(_) {
    cluster_order_list.sort_by((a, b) => {
      let (_name_a, rank_a, order_a) = a
      let (_name_b, rank_b, order_b) = b
      if rank_a < rank_b {
        -1
      } else if rank_a > rank_b {
        1
      } else if order_a < order_b {
        -1
      } else if order_a > order_b {
        1
      } else {
        0
      }
    })
    let step = nodes.length() + 1
    let mut base = 0
    for entry in cluster_order_list {
      let (cluster, _rank, _order) = entry
      cluster_order_base[cluster] = base
      base = base + step
    }
    for node in nodes {
      let name = node.name()
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let base_order = match cluster_order_base.get(cluster) {
        Some(value) => value
        None => 0
      }
      let inner = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = base_order + inner
    }
  }
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    intercluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let rank_same_groups : Map[String, Int] = Map::new()
  let rank_same_order : Map[String, Int] = Map::new()
  let _ = collect_rank_same_order(graph, rank_same_groups, rank_same_order, 0)
  let (flat_constraints, ordering_set) = build_ordering_flat_constraints(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    cluster_keys,
  )
  // Graphviz parity: flat edges (same-rank) act as ordering constraints.
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => 0
      }
      if tail_rank == head_rank {
        flat_constraints["\{tail}|\{head}"] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  {
    has_clusters,
    cluster_keys,
    cluster_skeleton,
    cluster_min_rank,
    cluster_max_rank,
    cluster_order,
    cluster_parents,
    intercluster_keys,
    rank_same_groups,
    rank_same_order,
    flat_constraints,
    ordering_set,
  }
}

///|
/// Graphviz parity: local cluster ordering uses minrank + first node order (cluster.c).
/// Do not change behavior without updating fixtures/tests.
fn build_local_cluster_order(
  nodes : Array[@cgraph.Node],
  local_cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> Map[String, Int] {
  let min_rank : Map[String, Int] = Map::new()
  let first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match local_cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match min_rank.get(cluster) {
      Some(current) => if rank < current { min_rank[cluster] = rank }
      None => min_rank[cluster] = rank
    }
    if first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      first_order[cluster] = order_value
    }
  }
  let entries : Array[(String, Int, Int)] = []
  for cluster, rank in min_rank {
    let order = match first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    entries.push((cluster, rank, order))
  }
  entries.sort_by((a, b) => {
    let (name_a, rank_a, order_a) = a
    let (name_b, rank_b, order_b) = b
    if rank_a < rank_b {
      -1
    } else if rank_a > rank_b {
      1
    } else if order_a < order_b {
      -1
    } else if order_a > order_b {
      1
    } else if name_a < name_b {
      -1
    } else if name_a > name_b {
      1
    } else {
      0
    }
  })
  let order_map : Map[String, Int] = Map::new()
  let mut idx = 0
  for entry in entries {
    let (cluster, _rank, _order) = entry
    if order_map.get(cluster) is None {
      order_map[cluster] = idx
      idx = idx + 1
    }
  }
  order_map
}

///|
fn cluster_depth_for_order(
  cluster : String,
  parents : Map[String, String?],
  fallback_parents : Map[String, String?],
  memo : Map[String, Int],
) -> Int {
  match memo.get(cluster) {
    Some(value) => value
    None => {
      let parent_opt =
        match parents.get(cluster) {
          Some(value) => value
          None =>
            match fallback_parents.get(cluster) {
              Some(value) => value
              None => None
            }
        }
      let depth = match parent_opt {
        Some(parent) => cluster_depth_for_order(parent, parents, fallback_parents, memo) + 1
        None => 0
      }
      memo[cluster] = depth
      depth
    }
  }
}

///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
fn reorder_groups_by_cluster_build_ranks(
  graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  order_with_vnodes : Bool,
) -> Unit {
  if cluster_meta.cluster_order.length() == 0 {
    return ()
  }
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  if cluster_graphs.length() == 0 {
    return ()
  }
  let cluster_index : Map[String, Int] = Map::new()
  for idx, name in cluster_meta.cluster_order {
    cluster_index[name] = idx
  }
  let cluster_depth : Map[String, Int] = Map::new()
  let cluster_names : Array[String] = []
  for name, _ in cluster_graphs {
    cluster_names.push(name)
  }
  if cluster_names.length() > 1 {
    cluster_names.sort_by((a, b) => {
      let a_depth =
        cluster_depth_for_order(a, cluster_meta.cluster_parents, cluster_parents, cluster_depth)
      let b_depth =
        cluster_depth_for_order(b, cluster_meta.cluster_parents, cluster_parents, cluster_depth)
      if a_depth < b_depth {
        -1
      } else if a_depth > b_depth {
        1
      } else {
        let a_idx = match cluster_index.get(a) {
          Some(value) => value
          None => cluster_index.length() + 1
        }
        let b_idx = match cluster_index.get(b) {
          Some(value) => value
          None => cluster_index.length() + 1
        }
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      }
    })
  }
  let empty_cluster_skeleton : Map[String, Bool] = Map::new()
  // Graphviz parity: cluster-local ordering keeps global node order hints so
  // local passes can consult external positions when needed.
  let fixed_positions = order_positions_from_groups(groups)
  // Graphviz parity: cluster-local ordering must include vnode rank metadata.
  // Do not change behavior without updating fixtures/tests.
  let fixed_ranks : Map[String, Int] = Map::new()
  for name, rank in ranks {
    fixed_ranks[name] = rank
  }
  for name, rank in vnode_info.vnode_ranks {
    fixed_ranks[name] = rank
  }
  for cluster in cluster_names {
    let cluster_graph = match cluster_graphs.get(cluster) {
      Some(value) => value
      None => continue
    }
    let cluster_nodes_set : Map[String, Bool] = Map::new()
    for node in cluster_graph.nodes() {
      cluster_nodes_set[node.name()] = true
    }
    if order_with_vnodes {
      for vnode, vnode_cluster in vnode_info.vnode_clusters {
        if vnode_cluster == cluster {
          cluster_nodes_set[vnode] = true
        }
      }
    }
    let cluster_node_set : Map[String, Bool] = Map::new()
    for _rank, names in groups {
      for name in names {
        if cluster_nodes_set.get(name) is Some(_) {
          cluster_node_set[name] = true
        }
      }
    }
    if cluster_node_set.length() <= 1 {
      continue
    }
    let cluster_nodes : Array[String] = []
    for name, _ in cluster_node_set {
      cluster_nodes.push(name)
    }
    let cluster_node_order : Map[String, Int] = Map::new()
    let cluster_ordered_nodes = cluster_nodes.copy()
    if cluster_ordered_nodes.length() > 1 {
      cluster_ordered_nodes.sort_by((a, b) => {
        let a_idx = match node_order.get(a) {
          Some(value) => value
          None => 0
        }
        let b_idx = match node_order.get(b) {
          Some(value) => value
          None => 0
        }
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
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
    let mut order_idx = 0
    for name in cluster_ordered_nodes {
      cluster_node_order[name] = order_idx
      order_idx = order_idx + 1
    }
    let cluster_groups : Map[Int, Array[String]] = Map::new()
    for rank, names in groups {
      let list : Array[String] = []
      for name in names {
        if cluster_nodes_set.get(name) is Some(_) {
          list.push(name)
        }
      }
      if list.length() > 1 {
        list.sort_by((a, b) => {
          let a_idx = match cluster_node_order.get(a) {
            Some(value) => value
            None => 0
          }
          let b_idx = match cluster_node_order.get(b) {
            Some(value) => value
            None => 0
          }
          if a_idx < b_idx {
            -1
          } else if a_idx > b_idx {
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
      if list.length() > 0 {
        cluster_groups[rank] = list
      }
    }
    let cluster_rank_keys = collect_rank_keys(cluster_groups)
    if cluster_rank_keys.length() == 0 {
      continue
    }
    let cluster_edges : Array[@cgraph.Edge] = []
    let cluster_edge_tail : Array[String] = []
    let cluster_edge_head : Array[String] = []
    let cluster_edge_tail_port_x : Array[Double] = []
    let cluster_edge_head_port_x : Array[Double] = []
    let cluster_edge_tail_port_order : Array[Double] = []
    let cluster_edge_head_port_order : Array[Double] = []
    for i in 0..<order_edges.length() {
      let tail = order_edge_tail[i]
      let head = order_edge_head[i]
      let tail_in = cluster_node_set.get(tail) is Some(_)
      let head_in = cluster_node_set.get(head) is Some(_)
      // Graphviz parity: cluster-local mincross only sees edges whose endpoints
      // are inside the expanded cluster graph (expand_cluster/interclexp).
      if !(tail_in && head_in) {
        continue
      }
      cluster_edges.push(order_edges[i])
      cluster_edge_tail.push(tail)
      cluster_edge_head.push(head)
      cluster_edge_tail_port_x.push(order_edge_tail_port_x[i])
      cluster_edge_head_port_x.push(order_edge_head_port_x[i])
      cluster_edge_tail_port_order.push(order_edge_tail_port_order[i])
      cluster_edge_head_port_order.push(order_edge_head_port_order[i])
    }
    let (parents, children) = build_edge_index_for_order_names(
      cluster_nodes,
      cluster_edge_tail,
      cluster_edge_head,
      fixed_ranks,
    )
    let edge_order = collect_edge_order(cluster_edges)
    let cluster_sizes : Map[String, NodeSize] = Map::new()
    for name, _ in cluster_node_set {
      match order_sizes.get(name) {
        Some(size) => cluster_sizes[name] = size
        None =>
          match vnode_info.vnode_sizes.get(name) {
            Some(size) => cluster_sizes[name] = size
            None => ()
          }
      }
    }
    let cluster_keys : Map[String, String] = Map::new()
    for name, _ in cluster_node_set {
      let key = match cluster_meta.intercluster_keys.get(name) {
        Some(value) => value
        None =>
          match vnode_info.vnode_clusters.get(name) {
            Some(value) => value
            None => ""
          }
      }
      cluster_keys[name] = key
    }
    let cluster_flat_constraints : Map[String, Bool] = Map::new()
    for key, value in cluster_meta.flat_constraints {
      match key.find("|") {
        Some(pos) => {
          let len = key.length()
          let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
          let head =
            if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
              ""
            }
          if cluster_node_set.get(tail) is Some(_) &&
            cluster_node_set.get(head) is Some(_) {
            cluster_flat_constraints[key] = value
          }
        }
        None => ()
      }
    }
    // Graphviz parity: no internal edges/ordering constraints -> keep input order.
    if cluster_edges.length() == 0 && cluster_flat_constraints.length() == 0 {
      continue
    }
    let ordered_cluster = reorder_rank_groups(
      cluster_rank_keys,
      cluster_groups,
      cluster_edges,
      cluster_edge_tail,
      cluster_edge_head,
      cluster_edge_tail_port_x,
      cluster_edge_head_port_x,
      cluster_edge_tail_port_order,
      cluster_edge_head_port_order,
      parents,
      children,
      cluster_keys,
      cluster_meta.rank_same_groups,
      cluster_meta.rank_same_order,
      edge_order,
      cluster_node_order,
      cluster_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      Map::new(),
      empty_cluster_skeleton,
      cluster_flat_constraints,
      // Graphviz parity: subgraphs use effective rankdir=TB, so flip is false.
      fixed_positions=fixed_positions,
      fixed_ranks=fixed_ranks,
      graphviz_flip=false,
      startpass=2,
    )
    for rank in cluster_rank_keys {
      let desired = match ordered_cluster.get(rank) {
        Some(list) => list
        None => []
      }
      if desired.length() <= 1 {
        continue
      }
      let names = match groups.get(rank) {
        Some(list) => list
        None => continue
      }
      let mut idx = 0
      let mut pos = 0
      while pos < names.length() && idx < desired.length() {
        if cluster_node_set.get(names[pos]) is Some(_) {
          names[pos] = desired[idx]
          idx = idx + 1
        }
        pos = pos + 1
      }
    }
  }
}

///|
/// Graphviz parity: rank=same does not impose ordering constraints.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_same_constraints(
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  Map::new()
}

///|
/// Graphviz parity: port x offsets for mincross tie-breaks (mincross.c).
/// Do not change behavior without updating fixtures/tests.
fn compute_edge_port_positions(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  if edges.length() == 0 {
    return ([], [])
  }
  let port_offsets = port_offsets_for_nodes(nodes, sizes)
  let tail_ports : Array[Double] = []
  let head_ports : Array[Double] = []
  let mut idx = 0
  while idx < edges.length() {
    let edge = edges[idx]
    let tail_name =
      if idx < edge_tail.length() { edge_tail[idx] } else { edge.tail().name() }
    let head_name =
      if idx < edge_head.length() { edge_head[idx] } else { edge.head().name() }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    let tail_port =
      if tail_name == orig_tail {
        edge.tail_port()
      } else if tail_name == orig_head {
        edge.head_port()
      } else {
        edge.tail_port()
      }
    let head_port =
      if head_name == orig_head {
        edge.head_port()
      } else if head_name == orig_tail {
        edge.tail_port()
      } else {
        edge.head_port()
      }
    let tail_x = edge_port_offset(tail_name, tail_port, port_offsets, sizes)
    let head_x = edge_port_offset(head_name, head_port, port_offsets, sizes)
    tail_ports.push(tail_x)
    head_ports.push(head_x)
    idx = idx + 1
  }
  (tail_ports, head_ports)
}

///|
/// Graphviz parity: port order fractions for mincross medians
/// (shapes.c compassPort + mincross.c VAL/MC_SCALE).
/// Do not change behavior without updating fixtures/tests.
fn compute_edge_port_orders(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  if edges.length() == 0 {
    return ([], [])
  }
  let port_offsets = port_offsets_for_nodes(nodes, sizes)
  let rankdir =
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
  let tail_orders : Array[Double] = []
  let head_orders : Array[Double] = []
  let mut idx = 0
  while idx < edges.length() {
    let edge = edges[idx]
    let tail_name =
      if idx < edge_tail.length() { edge_tail[idx] } else { edge.tail().name() }
    let head_name =
      if idx < edge_head.length() { edge_head[idx] } else { edge.head().name() }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    let tail_port =
      if tail_name == orig_tail {
        edge.tail_port()
      } else if tail_name == orig_head {
        edge.head_port()
      } else {
        edge.tail_port()
      }
    let head_port =
      if head_name == orig_head {
        edge.head_port()
      } else if head_name == orig_tail {
        edge.tail_port()
      } else {
        edge.head_port()
      }
    let tail_order = edge_port_order(tail_name, tail_port, port_offsets, sizes, rankdir)
    let head_order = edge_port_order(head_name, head_port, port_offsets, sizes, rankdir)
    tail_orders.push(tail_order)
    head_orders.push(head_order)
    idx = idx + 1
  }
  (tail_orders, head_orders)
}

///|
/// Graphviz parity: ND_out/ND_in neighbor order follows edge insertion (AGSEQ).
/// Do not change behavior without updating fixtures/tests.
fn build_graphviz_neighbor_maps(
  order_nodes : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  edge_creation_order : Array[(String, String)],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    graphviz_out_neighbors[name] = []
    graphviz_in_neighbors[name] = []
  }
  for tail, entries in order_edges_by_tail {
    let heads : Array[String] = []
    for entry in entries {
      let (_t, h, _pen, _constraint, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) =
        entry
      heads.push(h)
    }
    graphviz_out_neighbors[tail] = heads
  }
  // Graphviz parity: ND_in order follows edge sequence (AGSEQ) within a
  // fixed head, so preserve edge_creation insertion order.
  let in_entries : Map[String, Array[String]] = Map::new()
  for edge in edge_creation_order {
    let (tail, head) = edge
    match in_entries.get(head) {
      Some(list) => list.push(tail)
      None => in_entries[head] = [tail]
    }
  }
  for head, entries in in_entries {
    graphviz_in_neighbors[head] = entries
  }
  (graphviz_out_neighbors, graphviz_in_neighbors)
}

///|
/// Graphviz parity: flat constraints are copied before local augmentation.
/// Do not change behavior without updating fixtures/tests.
fn clone_flat_constraints(
  flat_constraints : Map[String, Bool],
) -> Map[String, Bool] {
  let cloned : Map[String, Bool] = Map::new()
  for key, value in flat_constraints {
    cloned[key] = value
  }
  cloned
}

///|
/// Graphviz parity: prepended cluster skeleton edges must stay ahead of
/// previously collected tail edges during class2 ordering.
/// Do not change behavior without updating fixtures/tests.
fn prepend_order_edge_entry(
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  tail_name : String,
  entry : (String, String, Int, Bool, Double, Double, Double, Double),
) -> Unit {
  match order_edges_by_tail.get(tail_name) {
    Some(list) => {
      let updated : Array[(String, String, Int, Bool, Double, Double, Double, Double)] = [entry]
      for item in list {
        updated.push(item)
      }
      order_edges_by_tail[tail_name] = updated
    }
    None => order_edges_by_tail[tail_name] = [entry]
  }
}

///|
/// Graphviz parity: cluster skeleton creation follows cluster_order first,
/// then remaining cluster_min_rank iteration order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_skeleton_creation(
  order_with_clusters : Bool,
  cluster_order : Array[String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Array[String] {
  let cluster_skeleton_creation : Array[String] = []
  if !order_with_clusters {
    return cluster_skeleton_creation
  }
  let cluster_seen : Map[String, Bool] = Map::new()
  for cluster in cluster_order {
    match cluster_min_rank.get(cluster) {
      Some(min_rank) => {
        let max_rank = match cluster_max_rank.get(cluster) {
          Some(value) => value
          None => min_rank
        }
        for rank in min_rank..=max_rank {
          cluster_skeleton_creation.push(
            "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}",
          )
        }
        cluster_seen[cluster] = true
      }
      None => ()
    }
  }
  for cluster, min_rank in cluster_min_rank {
    if cluster_seen.get(cluster) is Some(_) {
      continue
    }
    let max_rank = match cluster_max_rank.get(cluster) {
      Some(value) => value
      None => min_rank
    }
    for rank in min_rank..=max_rank {
      cluster_skeleton_creation.push(
        "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}",
      )
    }
  }
  cluster_skeleton_creation
}

///|
/// Graphviz parity: cluster skeleton edges form a rank-by-rank CL_CROSS chain
/// and must be prepended to both local and root order-edge maps.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_edges(
  cluster : String,
  min_rank : Int,
  max_rank : Int,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
) -> Unit {
  let mut rank = min_rank
  while rank < max_rank {
    let tail_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
    let head_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank + 1}"
    let entry = (tail_name, head_name, CL_CROSS, true, 0.0, 0.0, 0.5, 0.5)
    skeleton_edge_creation.push((tail_name, head_name))
    prepend_order_edge_entry(
      order_edges_by_tail,
      tail_name,
      entry,
    )
    prepend_order_edge_entry(
      order_edges_by_tail_root,
      tail_name,
      entry,
    )
    rank = rank + 1
  }
}

///|
/// Graphviz parity: class2 order_creation starts with cluster skeletons, then
/// agfstnode real nodes interleaved with edge-vnodes per tail.
/// Do not change behavior without updating fixtures/tests.
fn build_order_creation_with_vnodes(
  cluster_skeleton_creation : Array[String],
  creation_order : Array[String],
  vnode_creation_by_tail : Map[String, Array[String]],
) -> (Array[String], Array[String]) {
  let order_creation : Array[String] = []
  let order_seen : Map[String, Bool] = Map::new()
  for name in cluster_skeleton_creation {
    if order_seen.get(name) is None {
      order_seen[name] = true
      order_creation.push(name)
    }
  }
  for tail_name in creation_order {
    if order_seen.get(tail_name) is None {
      order_seen[tail_name] = true
      order_creation.push(tail_name)
    }
    let vnodes = match vnode_creation_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for vnode in vnodes {
      if order_seen.get(vnode) is None {
        order_seen[vnode] = true
        order_creation.push(vnode)
      }
    }
  }
  let vnode_creation_order : Array[String] = []
  for name in order_creation {
    if name.has_prefix(EDGE_VNODE_PREFIX) {
      vnode_creation_order.push(name)
    }
  }
  (order_creation, vnode_creation_order)
}

///|
/// Graphviz parity: when GD_flip is true, decompose nlist reverses node order
/// inside each cluster while preserving cluster membership positions.
/// Do not change behavior without updating fixtures/tests.
fn adjust_nlist_order_for_cluster_flip(
  nlist_order_raw : Array[String],
  graphviz_flip : Bool,
  has_clusters : Bool,
  cluster_keys : Map[String, String],
) -> Array[String] {
  if !(graphviz_flip && has_clusters) {
    return nlist_order_raw
  }
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  for name in nlist_order_raw {
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    match cluster_nodes.get(cluster) {
      Some(list) => list.push(name)
      None => cluster_nodes[cluster] = [name]
    }
  }
  let cluster_reversed : Map[String, Array[String]] = Map::new()
  let cluster_index : Map[String, Int] = Map::new()
  for cluster, list in cluster_nodes {
    let reversed : Array[String] = []
    let mut idx = list.length()
    while idx > 0 {
      idx = idx - 1
      reversed.push(list[idx])
    }
    cluster_reversed[cluster] = reversed
    cluster_index[cluster] = 0
  }
  let adjusted : Array[String] = []
  for name in nlist_order_raw {
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      adjusted.push(name)
    } else {
      let idx = match cluster_index.get(cluster) {
        Some(value) => value
        None => 0
      }
      let list = match cluster_reversed.get(cluster) {
        Some(value) => value
        None => []
      }
      if idx < list.length() {
        adjusted.push(list[idx])
      } else {
        adjusted.push(name)
      }
      cluster_index[cluster] = idx + 1
    }
  }
  adjusted
}

///|
/// Graphviz parity: edge creation order feeds ND_in AGSEQ capture with cluster
/// skeleton links preceding regular order_edge_creation links.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_creation_order(
  skeleton_edge_creation : Array[(String, String)],
  order_edge_creation : Array[(String, String)],
) -> Array[(String, String)] {
  let edge_creation_order : Array[(String, String)] = []
  for edge in skeleton_edge_creation {
    edge_creation_order.push(edge)
  }
  for edge in order_edge_creation {
    edge_creation_order.push(edge)
  }
  edge_creation_order
}

///|
/// Graphviz parity: flat edge constraints include same-rank non-self edges
/// and use missing-rank fallback 0 exactly as class2 input pre-pass.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_rank_constraints(
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let flat_rank_constraints : Map[String, Bool] = Map::new()
  let mut flat_idx = 0
  while flat_idx < edge_tail.length() {
    let tail = edge_tail[flat_idx]
    let head = edge_head[flat_idx]
    if tail != head {
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => 0
      }
      if tail_rank == head_rank {
        flat_rank_constraints["\{tail}|\{head}"] = true
      }
    }
    flat_idx = flat_idx + 1
  }
  flat_rank_constraints
}

///|
/// Graphviz parity: class2 traverses agfstnode creation order.
/// Do not change behavior without updating fixtures/tests.
fn collect_creation_order(
  nodes : Array[@cgraph.Node],
) -> Array[String] {
  let creation_order : Array[String] = []
  for node in nodes {
    creation_order.push(node.name())
  }
  creation_order
}

///|
/// Graphviz parity: order-graph tail buckets copy ND_out edge insertion order
/// for each agfstnode name, with empty lists for nodes without out edges.
/// Do not change behavior without updating fixtures/tests.
fn build_edges_by_tail_from_out_order(
  nodes : Array[@cgraph.Node],
  edge_out_order : Map[String, Array[Int]],
) -> Map[String, Array[Int]] {
  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  for node in nodes {
    let name = node.name()
    match edge_out_order.get(name) {
      Some(list) => edges_by_tail[name] = list.copy()
      None => edges_by_tail[name] = []
    }
  }
  edges_by_tail
}

///|
/// Graphviz parity: cluster-local build_ranks consumes edge chains before
/// root/cluster remapping, so unmapped tails/heads must remain available.
/// Do not change behavior without updating fixtures/tests.
fn build_unmapped_order_edges_by_tail(
  order_with_clusters : Bool,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
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
  edges_by_tail : Map[String, Array[Int]],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  if order_with_clusters {
    let (unmapped_edges_by_tail, _unmapped_vnode_creation, _unmapped_edge_creation) =
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
        edges_by_tail,
      )
    unmapped_edges_by_tail
  } else {
    order_edges_by_tail
  }
}

///|
/// Graphviz parity: root order-edge chains use remapped cluster endpoints,
/// while non-cluster graphs reuse the base order_edges_by_tail mapping.
/// Do not change behavior without updating fixtures/tests.
fn build_root_order_edges_by_tail(
  order_with_clusters : Bool,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
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
  edges_by_tail : Map[String, Array[Int]],
) -> (Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]], Array[(String, String)]) {
  if order_with_clusters {
    let (root_edges_by_tail, _root_vnode_creation_by_tail, root_edge_creation) =
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
        true,
        true,
        edges_by_tail,
      )
    (root_edges_by_tail, root_edge_creation)
  } else {
    (order_edges_by_tail, order_edge_creation)
  }
}

///|
/// Graphviz parity: nlist index map follows current GD_nlist/decompose order
/// for vnode key fallback and class2 ordering ties.
/// Do not change behavior without updating fixtures/tests.
fn build_nlist_order_index(
  nlist_order : Array[String],
) -> Map[String, Int] {
  let nlist_order_index : Map[String, Int] = Map::new()
  let mut nlist_idx = 0
  for name in nlist_order {
    nlist_order_index[name] = nlist_idx
    nlist_idx = nlist_idx + 1
  }
  nlist_order_index
}

///|
/// Graphviz parity: order graph starts from measured node sizes and augments
/// with vnode virtual sizes when vnode ordering is enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_order_sizes_for_order_graph(
  order_sizes : Map[String, NodeSize],
  order_with_vnodes : Bool,
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  let order_sizes_out : Map[String, NodeSize] = Map::new()
  for name, size in order_sizes {
    order_sizes_out[name] = size
  }
  if order_with_vnodes {
    for name, size in vnode_sizes {
      order_sizes_out[name] = size
    }
  }
  order_sizes_out
}

///|
/// Graphviz parity: class2 build_ranks reverses current nlist when creating
/// node visit seed order for edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_reverse_creation_order_from_nlist(
  nlist_order : Array[String],
) -> Array[String] {
  let creation_order : Array[String] = []
  let mut creation_idx = nlist_order.length()
  while creation_idx > 0 {
    creation_idx = creation_idx - 1
    creation_order.push(nlist_order[creation_idx])
  }
  creation_order
}

///|
/// Graphviz parity: order graph cluster-key map starts from real-node keys and
/// appends vnode cluster keys only when vnode ordering is enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_order_cluster_keys_for_order_graph(
  cluster_keys : Map[String, String],
  order_with_vnodes : Bool,
  vnode_clusters : Map[String, String],
) -> Map[String, String] {
  let order_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_keys {
    order_cluster_keys[name] = key
  }
  if order_with_vnodes {
    for name, key in vnode_clusters {
      order_cluster_keys[name] = key
    }
  }
  order_cluster_keys
}

///|
/// Graphviz parity: class2 cluster skeleton nodes use virtual_node() defaults
/// and are appended into every covered rank in cluster order.
/// Do not change behavior without updating fixtures/tests.
fn append_order_cluster_skeleton_range(
  cluster : String,
  min_rank : Int,
  max_rank : Int,
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  order_groups : Map[Int, Array[String]],
  skeleton_size : NodeSize,
) -> Unit {
  for rank in min_rank..=max_rank {
    let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
    order_cluster_keys[name] = cluster
    order_cluster_skeleton[name] = true
    order_sizes_out[name] = skeleton_size
    match order_groups.get(rank) {
      Some(list) => list.push(name)
      None => order_groups[rank] = [name]
    }
  }
}

///|
/// Graphviz parity: order-graph node creation follows collected rank key order
/// and per-rank node sequence (including appended virtual skeleton/vnodes).
/// Do not change behavior without updating fixtures/tests.
fn build_order_nodes_from_groups(
  order_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
) -> Array[String] {
  let order_nodes : Array[String] = []
  for rank in order_rank_keys {
    let names = match order_groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      order_nodes.push(name)
    }
  }
  order_nodes
}

///|
/// Graphviz parity: order graph node table is built by creating each name in
/// order_nodes sequence, matching agnode creation iteration order.
/// Do not change behavior without updating fixtures/tests.
fn build_order_graph_and_nodes(
  graph_name : String,
  order_nodes : Array[String],
) -> (@cgraph.Graph, Map[String, @cgraph.Node]) {
  let order_graph =
    @cgraph.Graph::new(
      @cgraph.GraphKind::Directed,
      name=graph_name,
      strict=false,
    )
  let order_node_map : Map[String, @cgraph.Node] = Map::new()
  for name in order_nodes {
    order_node_map[name] = order_graph.node(name)
  }
  (order_graph, order_node_map)
}

///|
/// Graphviz parity: order edges are materialized in nlist tail iteration order
/// with per-tail edge lists consumed exactly in stored sequence.
/// Do not change behavior without updating fixtures/tests.
fn append_order_edges_for_tail_sequence(
  tail_sequence : Array[String],
  edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> Unit {
  for tail_name in tail_sequence {
    let list = match edges_by_tail.get(tail_name) {
      Some(value) => value
      None => []
    }
    for entry in list {
      let (edge_tail_name, edge_head_name, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
        entry
      add_order_edge(
        order_graph,
        order_node_map,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_edge_tail_port_x,
        order_edge_head_port_x,
        order_edge_tail_port_order,
        order_edge_head_port_order,
        edge_tail_name,
        edge_head_name,
        penalty,
        constraint,
        tail_port_x,
        head_port_x,
        tail_port_order,
        head_port_order,
      )
    }
  }
}

///|
/// Graphviz parity: edge arrays are materialized from per-tail lists in exact
/// nlist tail iteration order (shared root/remincross order-graph builder).
/// Do not change behavior without updating fixtures/tests.
fn collect_order_edges_for_tail_sequence(
  tail_sequence : Array[String],
  edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  append_order_edges_for_tail_sequence(
    tail_sequence,
    edges_by_tail,
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
  (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}

///|
/// Graphviz parity: parent/child adjacency maps and edge-order indices are
/// derived from the exact materialized edge arrays in current order graph.
/// Do not change behavior without updating fixtures/tests.
fn build_order_edge_indices_and_order(
  order_nodes : Array[String],
  edge_tail_out : Array[String],
  edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  edges_out : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  let (parents, children) =
    build_edge_index_for_order_names(
      order_nodes,
      edge_tail_out,
      edge_head_out,
      order_ranks,
    )
  let edge_order = collect_edge_order(edges_out)
  (parents, children, edge_order)
}

///|
/// Graphviz parity: build_ranks node-order seed prioritizes GD_nlist then
/// fills with nlist/order_groups/base order while applying rank=same overrides.
/// Do not change behavior without updating fixtures/tests.
fn build_order_node_order_for_build_ranks(
  gdnlist_order : Array[String],
  nlist_order : Array[String],
  node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  order_groups : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> Map[String, Int] {
  let order_node_order : Map[String, Int] = Map::new()
  let mut order_idx = 0
  for name in gdnlist_order {
    order_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  for name in nlist_order {
    if order_node_order.get(name) is None {
      order_node_order[name] = order_idx
      order_idx = order_idx + 1
    }
  }
  // Graphviz parity: fall back to GD_nlist order for real nodes missing from nlist.
  for name, idx in node_order {
    if real_nodes.get(name) is Some(_) && order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let order_index = build_order_index(order_groups)
  for name, idx in order_index {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: seed missing real-node order from initial rank order;
  // GD_nlist order remains the primary source.
  for name, idx in base_order_index {
    if real_nodes.get(name) is Some(_) && order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  apply_rank_same_order_to_node_order(
    order_node_order,
    rank_same_groups,
    rank_same_order,
    port_edge_nodes,
  )
  order_node_order
}

///|
/// Graphviz parity: unconstrained-node seeding uses GD_nlist indices for real
/// nodes only, matching class2 fallback behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_gdnlist_order_index_for_real_nodes(
  gdnlist_order : Array[String],
  real_nodes : Map[String, Bool],
) -> Map[String, Int] {
  let gdnlist_order_index : Map[String, Int] = Map::new()
  let mut gdnlist_idx = 0
  for name in gdnlist_order {
    if real_nodes.get(name) is Some(_) {
      gdnlist_order_index[name] = gdnlist_idx
      gdnlist_idx = gdnlist_idx + 1
    }
  }
  gdnlist_order_index
}

///|
/// Graphviz parity: unconstrained nodes are exactly nodes with zero ND_out and
/// zero ND_in neighbors in the order graph.
/// Do not change behavior without updating fixtures/tests.
fn collect_unconstrained_order_nodes(
  order_nodes : Array[String],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
) -> Map[String, Bool] {
  let unconstrained_nodes : Map[String, Bool] = Map::new()
  for name in order_nodes {
    let out = match graphviz_out_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let inn = match graphviz_in_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    if out.length() == 0 && inn.length() == 0 {
      unconstrained_nodes[name] = true
    }
  }
  unconstrained_nodes
}

///|
/// Graphviz parity: incoming-only unconstrained handling uses non-self edges
/// to mark ND_out/ND_in presence, matching class2 neighbor detection.
/// Do not change behavior without updating fixtures/tests.
fn build_node_in_out_presence_maps(
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (Map[String, Bool], Map[String, Bool]) {
  let node_has_out : Map[String, Bool] = Map::new()
  let node_has_in : Map[String, Bool] = Map::new()
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      node_has_out[tail] = true
      node_has_in[head] = true
    }
    edge_idx = edge_idx + 1
  }
  (node_has_out, node_has_in)
}

///|
/// Graphviz parity: local cluster node creation order follows node scan order
/// per intercluster key, matching class2 fast-node insertion inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_local_cluster_creation_order(
  nodes : Array[@cgraph.Node],
  intercluster_keys : Map[String, String],
) -> Map[String, Array[String]] {
  let local_creation : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    let local_cluster = match intercluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if local_cluster == "" {
      continue
    }
    match local_creation.get(local_cluster) {
      Some(list) => list.push(name)
      None => local_creation[local_cluster] = [name]
    }
  }
  local_creation
}

///|
/// Graphviz parity: incoming-only unconstrained local nodes are reassigned in
/// reverse creation order while preserving their sorted order slots.
/// Do not change behavior without updating fixtures/tests.
fn reorder_incoming_only_unconstrained_local_nodes(
  local_creation : Map[String, Array[String]],
  unconstrained_nodes : Map[String, Bool],
  rank_same_groups : Map[String, Int],
  node_has_out : Map[String, Bool],
  node_has_in : Map[String, Bool],
  order_node_order : Map[String, Int],
) -> Unit {
  for _cluster, names in local_creation {
    let unconstrained_local : Array[String] = []
    for name in names {
      if unconstrained_nodes.get(name) is Some(_) &&
        rank_same_groups.get(name) is None &&
        node_has_out.get(name) is None &&
        node_has_in.get(name) is Some(_) {
        unconstrained_local.push(name)
      }
    }
    if unconstrained_local.length() <= 1 {
      continue
    }
    let desired : Array[String] = []
    let mut rev_idx = unconstrained_local.length()
    while rev_idx > 0 {
      rev_idx = rev_idx - 1
      desired.push(unconstrained_local[rev_idx])
    }
    let orders : Array[Int] = []
    let mut all_present = true
    for name in unconstrained_local {
      match order_node_order.get(name) {
        Some(value) => orders.push(value)
        None => {
          all_present = false
          break
        }
      }
    }
    if !all_present || orders.length() != desired.length() {
      continue
    }
    orders.sort()
    let mut idx = 0
    while idx < desired.length() && idx < orders.length() {
      order_node_order[desired[idx]] = orders[idx]
      idx = idx + 1
    }
  }
}

///|
/// Graphviz parity: transpose seed maps include all seeded nodes and only
/// positive-penalty constrained edges that cross ranks.
/// Do not change behavior without updating fixtures/tests.
fn build_transpose_seed_edge_maps(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
) -> (Array[Int], Map[String, Array[Int]], Map[String, Array[Int]]) {
  let edge_penalty : Array[Int] = []
  let edge_in : Map[String, Array[Int]] = Map::new()
  let edge_out : Map[String, Array[Int]] = Map::new()
  for rank in order_rank_keys {
    let names = match seeded_groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      edge_in[name] = []
      edge_out[name] = []
    }
  }
  for edge_idx in 0..<order_edges_out.length() {
    let edge = order_edges_out[edge_idx]
    let penalty = edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if penalty <= 0 || !edge_is_constraint(edge) {
      continue
    }
    let tail = order_edge_tail_out[edge_idx]
    let head = order_edge_head_out[edge_idx]
    let tail_rank = match order_ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match order_ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
    match edge_in.get(head) {
      Some(list) => list.push(edge_idx)
      None => edge_in[head] = [edge_idx]
    }
  }
  (edge_penalty, edge_in, edge_out)
}

///|
/// Graphviz parity: root ReMincross keeps only root and cluster-skeleton nodes;
/// cluster-internal ordering stays in cluster-local build_ranks passes.
/// Do not change behavior without updating fixtures/tests.
fn build_order_groups_for_root_mincross(
  order_with_clusters : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  if !order_with_clusters {
    return seeded_groups
  }
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

///|
/// Graphviz parity: membership checks for mincross subgraph are exact-name set
/// lookups over the filtered node list.
/// Do not change behavior without updating fixtures/tests.
fn build_node_membership_set(names : Array[String]) -> Map[String, Bool] {
  let membership : Map[String, Bool] = Map::new()
  for name in names {
    membership[name] = true
  }
  membership
}

///|
/// Graphviz parity: root mincross edge set keeps only edges whose endpoints are
/// both in the filtered node set, preserving edge and port-order sequence.
/// Do not change behavior without updating fixtures/tests.
fn collect_mincross_order_edges(
  mincross_nodes : Map[String, Bool],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let order_edges_out_mincross : Array[@cgraph.Edge] = []
  let order_edge_tail_out_mincross : Array[String] = []
  let order_edge_head_out_mincross : Array[String] = []
  let order_edge_tail_port_x_mincross : Array[Double] = []
  let order_edge_head_port_x_mincross : Array[Double] = []
  let order_edge_tail_port_order_mincross : Array[Double] = []
  let order_edge_head_port_order_mincross : Array[Double] = []
  let mut edge_idx = 0
  while edge_idx < order_edges_out.length() {
    let tail = order_edge_tail_out[edge_idx]
    let head = order_edge_head_out[edge_idx]
    if mincross_nodes.get(tail) is Some(_) && mincross_nodes.get(head) is Some(_) {
      order_edges_out_mincross.push(order_edges_out[edge_idx])
      order_edge_tail_out_mincross.push(tail)
      order_edge_head_out_mincross.push(head)
      order_edge_tail_port_x_mincross.push(order_edge_tail_port_x[edge_idx])
      order_edge_head_port_x_mincross.push(order_edge_head_port_x[edge_idx])
      order_edge_tail_port_order_mincross.push(order_edge_tail_port_order[edge_idx])
      order_edge_head_port_order_mincross.push(order_edge_head_port_order[edge_idx])
    }
    edge_idx = edge_idx + 1
  }
  (
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
  )
}

///|
/// Graphviz parity: after root-only mincross, reordered root/skeleton nodes are
/// merged back into seeded rank lists by replacing only filtered positions.
/// Do not change behavior without updating fixtures/tests.
fn merge_root_mincross_order_into_seeded_groups(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = match seeded_groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    let replacements = match ordered_mincross.get(rank) {
      Some(list) => list
      None => []
    }
    if replacements.length() == 0 {
      merged[rank] = names
      continue
    }
    let mut replace_idx = 0
    for i in 0..<names.length() {
      if mincross_nodes.get(names[i]) is Some(_) {
        if replace_idx < replacements.length() {
          names[i] = replacements[replace_idx]
          replace_idx = replace_idx + 1
        }
      }
    }
    merged[rank] = names
  }
  merged
}

///|
/// Graphviz parity: root-vnode set for cluster root reorder includes vnodes on
/// edges crossing cluster boundaries (same edge_vnode_key mapping as routing).
/// Do not change behavior without updating fixtures/tests.
fn collect_root_vnodes_for_cluster_reorder(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Bool] {
  let root_vnodes : Map[String, Bool] = Map::new()
  if !order_with_vnodes {
    return root_vnodes
  }
  let mut edge_idx = 0
  for edge in edges {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster != head_cluster {
      let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      for vnode in vnodes {
        root_vnodes[vnode] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  root_vnodes
}

///|
/// Graphviz parity: root cluster reorder base groups keep only root/skeleton
/// nodes, and include edge-vnodes only when flagged as root-vnodes.
/// Do not change behavior without updating fixtures/tests.
fn build_root_groups_base_for_cluster_reorder(
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  root_vnodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let root_groups_base : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = match order_groups_for_mincross.get(rank) {
      Some(list) => list
      None => []
    }
    let root_names : Array[String] = []
    for name in names {
      let cluster = match order_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
      if is_skeleton || cluster == "" {
        if !name.has_prefix(EDGE_VNODE_PREFIX) || root_vnodes.get(name) == Some(true) {
          root_names.push(name)
        }
      }
    }
    if root_names.length() > 0 {
      root_groups_base[rank] = root_names
    }
  }
  root_groups_base
}

///|
/// Graphviz parity: root cluster reorder GD_nlist keeps skeleton/root tail
/// sequence from input order, prioritizes source tails, then rebuilds nlist via
/// edge creation order while appending any missing root nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_root_nlist_order_for_cluster_reorder(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
) -> Array[String] {
  let tail_order_root : Array[String] = []
  let tail_root_seen : Map[String, Bool] = Map::new()
  for name in nlist_order {
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster != "" {
      let rank = match ranks.get(name) {
        Some(value) => value
        None => 0
      }
      let skel = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      if tail_root_seen.get(skel) is None {
        tail_root_seen[skel] = true
        tail_order_root.push(skel)
      }
    } else if tail_root_seen.get(name) is None {
      tail_root_seen[name] = true
      tail_order_root.push(name)
    }
  }
  let root_edge_creation_order : Array[(String, String)] = []
  for edge in skeleton_edge_creation {
    root_edge_creation_order.push(edge)
  }
  for edge in root_edge_creation {
    root_edge_creation_order.push(edge)
  }
  // Graphviz parity: build_ranks visits source nodes (no incoming edges)
  // first in GD_nlist order.
  // Do not change behavior without updating fixtures/tests.
  let root_has_in : Map[String, Bool] = Map::new()
  for name in root_nodes {
    root_has_in[name] = false
  }
  for edge in root_edge_creation_order {
    let (_tail, head) = edge
    if root_has_in.get(head) is Some(_) {
      root_has_in[head] = true
    }
  }
  let root_tail_order : Array[String] = []
  let root_tail_seen : Map[String, Bool] = Map::new()
  for name in tail_order_root {
    if root_has_in.get(name) == Some(false) {
      if root_tail_seen.get(name) is None {
        root_tail_seen[name] = true
        root_tail_order.push(name)
      }
    }
  }
  for name in tail_order_root {
    if root_tail_seen.get(name) is None {
      root_tail_seen[name] = true
      root_tail_order.push(name)
    }
  }
  let root_nlist_full =
    build_graphviz_nlist_order_from_edges(
      root_tail_order,
      root_nodes,
      root_edge_creation_order,
      flat_rank_constraints,
    )
  let root_nlist_order : Array[String] = []
  let root_seen : Map[String, Bool] = Map::new()
  for name in root_nlist_full {
    if root_node_map.get(name) is Some(_) {
      root_seen[name] = true
      root_nlist_order.push(name)
    }
  }
  if root_nlist_order.length() < root_nodes.length() {
    for name in root_nodes {
      if root_seen.get(name) is None {
        root_nlist_order.push(name)
      }
    }
  }
  root_nlist_order
}

///|
/// Graphviz parity: root mincross vnode inputs keep only root-vnodes from
/// vnode rank buckets and vnode order keys.
/// Do not change behavior without updating fixtures/tests.
fn collect_root_vnode_rank_groups_and_order_keys(
  order_with_vnodes : Bool,
  root_vnodes : Map[String, Bool],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> (Map[Int, Array[String]], Map[String, Double]) {
  let root_vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let root_vnode_order_keys : Map[String, Double] = Map::new()
  if order_with_vnodes {
    for rank, names in vnodes_by_rank {
      let filtered : Array[String] = []
      for name in names {
        if root_vnodes.get(name) == Some(true) {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        root_vnodes_by_rank[rank] = filtered
      }
    }
    for name, key in vnode_order_keys_for_ordering {
      if root_vnodes.get(name) == Some(true) {
        root_vnode_order_keys[name] = key
      }
    }
  }
  (root_vnodes_by_rank, root_vnode_order_keys)
}

///|
/// Graphviz parity: root cluster reorder groups keep root/skeleton base order
/// and optionally merge only root-vnodes into rank groups using filtered vnode
/// keys/rank buckets from root-mincross inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_root_groups_for_cluster_reorder(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> Map[Int, Array[String]] {
  let root_vnodes =
    collect_root_vnodes_for_cluster_reorder(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
    )
  let root_groups_base =
    build_root_groups_base_for_cluster_reorder(
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      root_vnodes,
    )
  let root_order_index = build_order_index(root_groups_base)
  let (root_vnodes_by_rank, root_vnode_order_keys) =
    collect_root_vnode_rank_groups_and_order_keys(
      order_with_vnodes,
      root_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
    )
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      root_groups_base,
      root_order_index,
      root_vnodes_by_rank,
      root_vnode_order_keys,
    )
  } else {
    root_groups_base
  }
}

///|
/// Graphviz parity: root mincross rank map records first-seen cluster skeleton
/// (or root real-node bucket) order per rank for cluster-phase reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_from_root_ordered(
  root_rank_keys : Array[Int],
  ordered_root : Map[Int, Array[String]],
  order_cluster_skeleton : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  for rank in root_rank_keys {
    let names = match ordered_root.get(rank) {
      Some(list) => list
      None => []
    }
    let order_map : Map[String, Int] = Map::new()
    let mut idx = 0
    for name in names {
      if order_cluster_skeleton.get(name) == Some(true) {
        let cluster = match order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster != "" && order_map.get(cluster) is None {
          order_map[cluster] = idx
          idx = idx + 1
        }
      } else if real_nodes.get(name) is Some(_) {
        let cluster = match order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster == "" && order_map.get("") is None {
          order_map[""] = idx
          idx = idx + 1
        }
      }
    }
    if order_map.length() > 0 {
      cluster_rank_order[rank] = order_map
    }
  }
  cluster_rank_order
}

///|
/// Graphviz parity: cluster-phase rank-order map is built from root-only
/// reorder pass (root/skeleton + root-vnodes) before local cluster bucket
/// reordering in final real-node groups.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_for_cluster_reorder(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  if !order_with_clusters {
    return cluster_rank_order
  }
  let root_groups =
    build_root_groups_for_cluster_reorder(
      order_with_vnodes,
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      edges,
      edge_tail,
      edge_head,
      cluster_meta.cluster_keys,
      vnode_info.edge_vnodes,
      vnode_info.vnodes_by_rank,
      vnode_order_keys_for_ordering,
    )
  let root_rank_keys = collect_rank_keys(root_groups)
  let root_ranks = build_node_ranks(root_groups)
  let root_nodes = build_order_nodes_from_groups(root_groups, root_rank_keys)
  let (root_graph, root_node_map) =
    build_order_graph_and_nodes("order_root", root_nodes)
  let root_nlist_order =
    build_root_nlist_order_for_cluster_reorder(
      nlist_order,
      cluster_meta.cluster_keys,
      ranks,
      root_nodes,
      root_node_map,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
    )
  let root_node_order =
    build_order_node_order_from_nlist_and_groups(
      root_nlist_order,
      root_node_map,
      root_groups,
    )
  let (
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
  ) =
    collect_order_edges_for_tail_sequence(
      root_nlist_order,
      order_edges_by_tail_root,
      root_graph,
      root_node_map,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let mut edge_idx = 0
    while edge_idx < root_edges_out.length() {
      let tail = root_edge_tail_out[edge_idx]
      let head = root_edge_head_out[edge_idx]
      let pen = edge_xpenalty(root_edges_out[edge_idx])
      println("root_edge \{edge_idx}: \{tail} -> \{head} pen=\{pen}")
      edge_idx = edge_idx + 1
    }
  }
  let (root_parents, root_children, root_edge_order) =
    build_order_edge_indices_and_order(
      root_nodes,
      root_edge_tail_out,
      root_edge_head_out,
      root_ranks,
      root_edges_out,
    )
  let ordered_root = reorder_rank_groups(
    root_rank_keys,
    root_groups,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    order_cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    root_edge_order,
    root_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    order_cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_flip=graphviz_flip,
  )
  dot_trace_groups("order_root", ordered_root)
  let root_cluster_rank_order =
    build_cluster_rank_order_from_root_ordered(
      root_rank_keys,
      ordered_root,
      order_cluster_skeleton,
      order_cluster_keys,
      real_nodes,
    )
  for rank, order_map in root_cluster_rank_order {
    cluster_rank_order[rank] = order_map
  }
  cluster_rank_order
}

///|
/// Graphviz parity: final rank groups drop non-real nodes after root ordering,
/// preserving rank iteration order and per-rank sequence.
/// Do not change behavior without updating fixtures/tests.
fn collect_real_only_rank_groups(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let cleaned_groups : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    let cleaned : Array[String] = []
    for name in names {
      if real_nodes.get(name) is Some(_) {
        cleaned.push(name)
      }
    }
    if cleaned.length() > 0 {
      cleaned_groups[rank] = cleaned
    }
  }
  cleaned_groups
}

///|
/// Graphviz parity: cluster-phase reorder keeps intra-cluster node order, then
/// reorders cluster buckets by root mincross rank map with stable tie-breaks.
/// Do not change behavior without updating fixtures/tests.
fn reorder_rank_groups_by_cluster_rank_order(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let ordered_by_cluster : Map[Int, Array[String]] = Map::new()
  for rank, names in final_groups {
    let order_map = match cluster_rank_order.get(rank) {
      Some(value) => value
      None => {
        ordered_by_cluster[rank] = names
        continue
      }
    }
    let cluster_nodes : Map[String, Array[String]] = Map::new()
    let cluster_seq : Array[String] = []
    for name in names {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      match cluster_nodes.get(cluster) {
        Some(list) => list.push(name)
        None => {
          cluster_nodes[cluster] = [name]
          cluster_seq.push(cluster)
        }
      }
    }
    let cluster_ordered : Array[(Int, Int, String)] = []
    for idx, cluster in cluster_seq {
      let base =
        match order_map.get(cluster) {
          Some(value) => value
          None => order_map.length() + idx
        }
      cluster_ordered.push((base, idx, cluster))
    }
    if cluster_ordered.length() > 1 {
      cluster_ordered.sort_by((a, b) => {
        let (a_order, a_idx, _a_name) = a
        let (b_order, b_idx, _b_name) = b
        if a_order < b_order {
          -1
        } else if a_order > b_order {
          1
        } else if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      })
    }
    let ordered_names : Array[String] = []
    for entry in cluster_ordered {
      let (_order, _idx, cluster) = entry
      let nodes_in_cluster = match cluster_nodes.get(cluster) {
        Some(list) => list
        None => []
      }
      for name in nodes_in_cluster {
        ordered_names.push(name)
      }
    }
    ordered_by_cluster[rank] = ordered_names
  }
  ordered_by_cluster
}

///|
/// Graphviz parity: ReMincross trailing vnode set marks intercluster edge
/// vnodes whose endpoint cluster rank ranges do not overlap.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_trailing_vnodes(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Bool] {
  let intercluster_vnodes : Map[String, Bool] = Map::new()
  if !order_with_vnodes {
    return intercluster_vnodes
  }
  let mut edge_idx = 0
  for edge in edges {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    let internal =
      tail_cluster != "" && head_cluster != "" &&
      edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
    if !internal && tail_cluster != head_cluster {
      let mut should_trail = false
      if tail_cluster != "" && head_cluster != "" {
        let tail_min = match cluster_min_rank.get(tail_cluster) {
          Some(value) => value
          None => 0
        }
        let tail_max = match cluster_max_rank.get(tail_cluster) {
          Some(value) => value
          None => tail_min
        }
        let head_min = match cluster_min_rank.get(head_cluster) {
          Some(value) => value
          None => 0
        }
        let head_max = match cluster_max_rank.get(head_cluster) {
          Some(value) => value
          None => head_min
        }
        let overlap = tail_min <= head_max && head_min <= tail_max
        should_trail = !overlap
      }
      if should_trail {
        let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
          Some(list) => list
          None => []
        }
        for vnode in vnodes {
          intercluster_vnodes[vnode] = true
        }
      }
    }
    edge_idx = edge_idx + 1
  }
  intercluster_vnodes
}

///|
/// Graphviz parity: trailing intercluster vnodes get a minimum order key just
/// after the max real-node order on their rank (stable tiny seq offset).
/// Do not change behavior without updating fixtures/tests.
fn apply_intercluster_vnode_order_key_floor(
  keys : Map[String, Double],
  intercluster_vnodes : Map[String, Bool],
  rem_base_order_index : Map[String, Int],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> Unit {
  if intercluster_vnodes.length() == 0 {
    return
  }
  let max_order_by_rank : Map[Int, Int] = Map::new()
  for name, order in rem_base_order_index {
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    match max_order_by_rank.get(rank) {
      Some(current) =>
        if order > current {
          max_order_by_rank[rank] = order
        }
      None => max_order_by_rank[rank] = order
    }
  }
  let mut seq = 0
  for vnode, _ in intercluster_vnodes {
    let rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let max_order = match max_order_by_rank.get(rank) {
      Some(value) => value
      None => -1
    }
    let base = Double::from_int(max_order + 1)
    let offset = Double::from_int(seq) * 0.000001
    let min_key = base + offset
    match keys.get(vnode) {
      Some(current) =>
        if current < min_key {
          keys[vnode] = min_key
        }
      None => keys[vnode] = min_key
    }
    seq = seq + 1
  }
}

///|
/// Graphviz parity: ReMincross local flat constraints keep only endpoints that
/// exist in the current fast graph node map.
/// Do not change behavior without updating fixtures/tests.
fn filter_flat_constraints_for_node_map(
  flat_rank_constraints : Map[String, Bool],
  node_map : Map[String, @cgraph.Node],
) -> Map[String, Bool] {
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  for key, _ in flat_rank_constraints {
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else {
          ""
        }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
        if node_map.get(tail) is Some(_) && node_map.get(head) is Some(_) {
          rem_flat_constraints[key] = true
        }
      }
      None => ()
    }
  }
  rem_flat_constraints
}

///|
/// Graphviz parity: ReMincross creation order starts from tail creation order
/// then appends each tail vnode sequence once (stable dedupe).
/// Do not change behavior without updating fixtures/tests.
fn build_rem_order_creation_sequence(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
) -> Array[String] {
  let rem_order_creation : Array[String] = []
  let rem_seen : Map[String, Bool] = Map::new()
  for tail_name in creation_order {
    if rem_seen.get(tail_name) is None {
      rem_seen[tail_name] = true
      rem_order_creation.push(tail_name)
    }
    let vnodes = match rem_vnode_creation.get(tail_name) {
      Some(list) => list
      None => []
    }
    for vnode in vnodes {
      if rem_seen.get(vnode) is None {
        rem_seen[vnode] = true
        rem_order_creation.push(vnode)
      }
    }
  }
  rem_order_creation
}

///|
/// Graphviz parity: ReMincross vnode order keys follow vnodes_by_rank keys
/// with trailing intercluster vnode floor adjustment before rank merge.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_vnode_order_keys(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  rem_base_order_index : Map[String, Int],
  cluster_keys : Map[String, String],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  if !order_with_vnodes {
    return Map::new()
  }
  let intercluster_vnodes =
    collect_intercluster_trailing_vnodes(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
      edge_vnodes,
    )
  let keys = build_vnode_order_keys(
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    rem_base_order_index,
    intercluster_keys,
    cluster_parents,
    edge_vnodes,
    vnode_ranks,
  )
  apply_intercluster_vnode_order_key_floor(
    keys,
    intercluster_vnodes,
    rem_base_order_index,
    ranks,
    vnode_ranks,
  )
  keys
}

///|
/// Graphviz parity: ReMincross rank groups start from real-node groups and
/// optionally inject edge-vnodes using vnode order keys from cluster-aware
/// trailing-vnode adjustments.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_groups_with_optional_vnodes(
  final_groups : Map[Int, Array[String]],
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  cluster_keys : Map[String, String],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let rem_base_groups = clone_rank_groups(final_groups)
  let rem_base_order_index = build_order_index(rem_base_groups)
  let rem_vnode_order_keys =
    build_remincross_vnode_order_keys(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      rem_base_order_index,
      cluster_keys,
      intercluster_keys,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
      edge_vnodes,
      vnode_ranks,
    )
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      rem_base_groups,
      rem_base_order_index,
      vnodes_by_rank,
      rem_vnode_order_keys,
    )
  } else {
    rem_base_groups
  }
}

///|
/// Graphviz parity: ReMincross GD_nlist order is rebuilt from creation order
/// + vnode expansion + fast-graph edge insertion order (decompose parity).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_nlist_order(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_flat_constraints : Map[String, Bool],
) -> Array[String] {
  let rem_edge_creation_order : Array[(String, String)] = []
  for edge in rem_edge_creation {
    rem_edge_creation_order.push(edge)
  }
  let rem_order_creation =
    build_rem_order_creation_sequence(creation_order, rem_vnode_creation)
  // Graphviz parity: GD_nlist seeding uses agfstnode order for the
  // fast graph (reverse creation insertion).
  let rem_order_creation_rev : Array[String] = []
  let mut rem_rev_idx = rem_order_creation.length()
  while rem_rev_idx > 0 {
    rem_rev_idx = rem_rev_idx - 1
    rem_order_creation_rev.push(rem_order_creation[rem_rev_idx])
  }
  build_graphviz_nlist_order_from_edges(
    rem_order_creation_rev,
    rem_order_creation,
    rem_edge_creation_order,
    rem_flat_constraints,
  )
}

///|
/// Graphviz parity: ReMincross order-graph materialization filters local flat
/// constraints by fast-graph membership, rebuilds GD_nlist, seeds node order,
/// then materializes edge arrays in nlist tail order.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_materialized_order_graph(
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
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
  let rem_flat_constraints =
    filter_flat_constraints_for_node_map(
      flat_rank_constraints,
      rem_node_map,
    )
  let rem_nlist_order =
    build_remincross_nlist_order(
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_flat_constraints,
    )
  let rem_node_order =
    build_order_node_order_from_nlist_and_groups(
      rem_nlist_order,
      rem_node_map,
      rem_groups,
    )
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
/// Graphviz parity: ReMincross cluster keys start from intercluster keys,
/// map empty keys to the root graph key, and assign edge vnodes to the LCA
/// cluster (mark_lowclusters) for cluster-boundary swap guards.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, String] {
  let rem_cluster_keys : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    rem_cluster_keys[name] = key
  }
  // Graphviz parity: ND_clust is the root graph for nodes outside
  // any cluster (mark_lowclusters). Use a non-empty root key so
  // ReMincross can block swaps across cluster boundaries.
  let root_cluster = match graph.name() {
    Some(value) => value
    None => "__root__"
  }
  for name, key in rem_cluster_keys {
    if key == "" {
      rem_cluster_keys[name] = root_cluster
    }
  }
  if !order_with_vnodes {
    return rem_cluster_keys
  }
  let mut edge_idx = 0
  for edge in edges {
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      edge_idx = edge_idx + 1
      continue
    }
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = match intercluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match intercluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    // Graphviz parity: mark_lowclusters assigns virtual nodes to the
    // lowest common ancestor cluster for intercluster edges.
    let vnode_cluster =
      cluster_lowest_common_ancestor(
        tail_cluster,
        head_cluster,
        cluster_parents,
      )
    let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
    for vnode in vnodes {
      rem_cluster_keys[vnode] = rem_cluster
    }
    edge_idx = edge_idx + 1
  }
  rem_cluster_keys
}

///|
/// Graphviz parity: intercluster node guard marks real endpoints of
/// intercluster edges with rank span <= 1 for local-order relaxation.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_nodes_with_short_span(
  order_with_clusters : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let intercluster_nodes : Map[String, Bool] = Map::new()
  if !order_with_clusters {
    return intercluster_nodes
  }
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_cluster = match intercluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match intercluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster != head_cluster {
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => 0
      }
      let span = if tail_rank <= head_rank {
        head_rank - tail_rank
      } else {
        tail_rank - head_rank
      }
      if span <= 1 {
        intercluster_nodes[tail] = true
        intercluster_nodes[head] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  intercluster_nodes
}

///|
/// Graphviz parity: root/ReMincross node-order seeding follows GD_nlist order
/// and fills missing nodes from current rank-group index.
/// Do not change behavior without updating fixtures/tests.
fn build_order_node_order_from_nlist_and_groups(
  nlist_order : Array[String],
  node_map : Map[String, @cgraph.Node],
  groups : Map[Int, Array[String]],
) -> Map[String, Int] {
  let node_order_out : Map[String, Int] = Map::new()
  let mut node_idx = 0
  for name in nlist_order {
    if node_map.get(name) is Some(_) {
      node_order_out[name] = node_idx
      node_idx = node_idx + 1
    }
  }
  let order_index = build_order_index(groups)
  for name, idx in order_index {
    if node_order_out.get(name) is None {
      node_order_out[name] = idx
    }
  }
  node_order_out
}

///|
/// Graphviz parity: ReMincross flat constraints combine existing same-rank
/// constraints with local intra-cluster adjacency locks for non-intercluster
/// real-node pairs (flat.c cluster-local reorder guard).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_flat_constraints(
  flat_constraints : Map[String, Bool],
  rank_same_constraints : Map[String, Bool],
  order_with_clusters : Bool,
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_cluster_keys : Map[String, String],
  intercluster_nodes : Map[String, Bool],
) -> Map[String, Bool] {
  let rem_flat_constraints = clone_flat_constraints(flat_constraints)
  for key, _ in rank_same_constraints {
    rem_flat_constraints[key] = true
  }
  if !order_with_clusters {
    return rem_flat_constraints
  }
  // Graphviz parity: keep relative order of real nodes that are
  // internal to a cluster; allow nodes with intercluster edges to reorder.
  for _rank, names in rem_groups {
    let mut prev_real : String? = None
    let mut prev_cluster = ""
    let mut prev_inter = false
    for name in names {
      if real_nodes.get(name) is None {
        continue
      }
      let cluster = match rem_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      let inter = intercluster_nodes.get(name) is Some(_)
      match prev_real {
        Some(prev) =>
          if cluster != "" && cluster == prev_cluster && !prev_inter && !inter {
            rem_flat_constraints["\{prev}|\{name}"] = true
          }
        None => ()
      }
      prev_real = Some(name)
      prev_cluster = cluster
      prev_inter = inter
    }
  }
  rem_flat_constraints
}

///|
/// Graphviz parity: ReMincross final reorder runs with startpass=2 using
/// materialized fast-graph edges, then drops non-real nodes for final groups
/// while preserving rank iteration and per-rank order.
/// Do not change behavior without updating fixtures/tests.
fn run_remincross_reorder_and_collect_real_groups(
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
  let rem_ordered = reorder_rank_groups(
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
    Map::new(),
    Map::new(),
    rem_flat_constraints,
    graphviz_flip=graphviz_flip,
    startpass=2,
  )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    dot_trace_groups("remincross_ordered", rem_ordered)
  }
  let rem_cleaned =
    collect_real_only_rank_groups(rem_rank_keys, rem_ordered, real_nodes)
  (rem_ordered, rem_cleaned)
}

///|
/// Graphviz parity: ReMincross reorder inputs derive cluster keys (including
/// vnode LCA assignments), local intercluster-node guards, size map extension,
/// and flat-constraint augmentation before final reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_reorder_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> (Map[String, String], Map[String, NodeSize], Map[String, Bool]) {
  let rem_cluster_keys =
    build_remincross_cluster_keys(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      vnode_info.edge_vnodes,
    )
  let intercluster_nodes =
    collect_intercluster_nodes_with_short_span(
      order_with_clusters,
      edge_tail,
      edge_head,
      cluster_meta.intercluster_keys,
      ranks,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_vnodes : Array[String] = [
      "_mbt_edge_vn_0_3",
      "_mbt_edge_vn_1_3",
    ]
    for name in debug_vnodes {
      let cluster = match rem_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      println("remincross vnode \{name} cluster=\{cluster}")
    }
  }
  let rem_sizes =
    build_order_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
    )
  let rem_flat_constraints =
    build_remincross_flat_constraints(
      cluster_meta.flat_constraints,
      rank_same_constraints,
      order_with_clusters,
      rem_groups,
      real_nodes,
      rem_cluster_keys,
      intercluster_nodes,
    )
  (rem_cluster_keys, rem_sizes, rem_flat_constraints)
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
    let pen = edge_xpenalty(edge)
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
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_pass(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  base_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  // Graphviz parity: ReMincross runs on real nodes + edge vnodes (no cluster skeletons).
  let rem_groups =
    build_remincross_groups_with_optional_vnodes(
      base_groups,
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      cluster_meta.cluster_keys,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
      vnode_info.vnodes_by_rank,
    )
  dot_trace_groups("remincross_groups", rem_groups)
  let rem_rank_keys = collect_rank_keys(rem_groups)
  let mut next_ordered_with_vnodes = ordered_with_vnodes
  let mut next_final_groups = base_groups
  if rem_rank_keys.length() > 1 {
    let rem_ranks = build_node_ranks(rem_groups)
    let rem_nodes = build_order_nodes_from_groups(rem_groups, rem_rank_keys)
    let (rem_graph, rem_node_map) =
      build_order_graph_and_nodes("order_remincross", rem_nodes)
    let rem_edges_by_tail = edges_by_tail
    // Graphviz parity: ReMincross uses real intercluster edges
    // (no cluster skeleton mapping).
    let (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation) =
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
        vnode_info.edge_vnodes,
        order_with_vnodes,
        cluster_meta.cluster_keys,
        order_with_clusters,
        false,
        false,
        rem_edges_by_tail,
      )
    trace_remincross_order_edges_by_tail(rem_order_edges_by_tail)
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
        flat_rank_constraints,
        creation_order,
        rem_vnode_creation,
        rem_edge_creation,
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
    let (rem_parents, rem_children, rem_edge_order) =
      build_order_edge_indices_and_order(
        rem_nodes,
        rem_edge_tail_out,
        rem_edge_head_out,
        rem_ranks,
        rem_edges_out,
      )
    let (rem_cluster_keys, rem_sizes, rem_flat_constraints) =
      build_remincross_reorder_inputs(
        graph,
        edges,
        edge_tail,
        edge_head,
        order_with_vnodes,
        order_with_clusters,
        ranks,
        cluster_meta,
        vnode_info,
        order_sizes,
        rank_same_constraints,
        rem_groups,
        real_nodes,
      )
    let (rem_ordered, rem_cleaned) =
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
        cluster_meta.rank_same_groups,
        cluster_meta.rank_same_order,
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
    next_ordered_with_vnodes = rem_ordered
    next_final_groups = rem_cleaned
  }
  (next_ordered_with_vnodes, next_final_groups)
}

///|
/// Graphviz parity: non-cluster reorder path seeds node order from GD_nlist,
/// builds Graphviz-style ND_out/ND_in neighbor order, and runs rank reorder
/// without cluster remapping.
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_reorder_pass(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
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
  // Graphviz parity: build_ranks seeds from GD_nlist (decompose) order.
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
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
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
  // Graphviz parity: ND_in order follows edge sequence (AGSEQ) within a
  // fixed head, so preserve edge index order.
  let in_entries : Map[String, Array[String]] = Map::new()
  let mut edge_idx = 0
  while edge_idx < edges.length() {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edges[edge_idx].tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edges[edge_idx].head().name()
      }
    match in_entries.get(head) {
      Some(list) => list.push(tail)
      None => in_entries[head] = [tail]
    }
    edge_idx = edge_idx + 1
  }
  for head, entries in in_entries {
    graphviz_in_neighbors[head] = entries
  }
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

///|
/// Debug trace: dump GD_nlist sequence and skeleton-node subset when
/// DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_nlist_order_debug(
  nlist_order : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let order_joined = nlist_order.join(" ")
  if order_joined.length() > 0 {
    println("nlist_order \{order_joined}")
  }
  let skeleton_names =
    nlist_order.filter(name => name.has_prefix(CLUSTER_SKELETON_PREFIX))
  let joined = skeleton_names.join(" ")
  if joined.length() > 0 {
    println("nlist_skeleton \{joined}")
  }
}

///|
/// Debug trace: dump selected order-node positions when DOT_TRACE_GROUPS is
/// enabled (diagnostic only).
fn trace_order_node_order_debug(
  order_node_order : Map[String, Int],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let debug_names : Array[String] = [
    "z_req",
    "z_req1",
    "handle_x",
    "handle_1",
    "mobvm_a_req",
    "mobvm_a_req1",
    "front_end_jz",
    "other_xprot",
    "z_shapeshifter",
  ]
  for name in debug_names {
    match order_node_order.get(name) {
      Some(value) => println("order_node_order \{name}=\{value}")
      None => ()
    }
  }
}

///|
/// Debug trace: dump materialized order edges with rank/real-node flags when
/// DOT_TRACE_ORDER_EDGES is enabled (diagnostic only).
fn trace_order_edges_with_ranks(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  real_nodes : Map[String, Bool],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_ORDER_EDGES") is None {
    return
  }
  let mut edge_idx = 0
  for _edge in order_edges_out {
    let tail = order_edge_tail_out[edge_idx]
    let head = order_edge_head_out[edge_idx]
    let tail_rank = match order_ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match order_ranks.get(head) {
      Some(value) => value
      None => 0
    }
    let tail_real = real_nodes.get(tail) is Some(_)
    let head_real = real_nodes.get(head) is Some(_)
    println(
      "order_edge \{edge_idx}: \{tail}(\{tail_rank},\{tail_real}) -> \{head}(\{head_rank},\{head_real})",
    )
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: order-graph edge arrays are materialized from GD_nlist
/// tail order for both mapped (cluster-remapped) and unmapped variants.
/// Do not change behavior without updating fixtures/tests.
fn materialize_mapped_and_unmapped_order_edges(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  let order_edges_out_unmapped : Array[@cgraph.Edge] = []
  let order_edge_tail_out_unmapped : Array[String] = []
  let order_edge_head_out_unmapped : Array[String] = []
  let order_edge_tail_port_x_unmapped : Array[Double] = []
  let order_edge_head_port_x_unmapped : Array[Double] = []
  let order_edge_tail_port_order_unmapped : Array[Double] = []
  let order_edge_head_port_order_unmapped : Array[Double] = []
  append_order_edges_for_tail_sequence(
    nlist_order,
    order_edges_by_tail,
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
  append_order_edges_for_tail_sequence(
    nlist_order,
    order_edges_by_tail_unmapped,
    order_graph_unmapped,
    order_node_map_unmapped,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
  (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
}

///|
/// Graphviz parity: order-stage groups clone rank groups, optionally merge edge
/// vnodes, and install cluster skeleton nodes with virtual-node defaults.
/// Do not change behavior without updating fixtures/tests.
fn build_order_groups_sizes_and_cluster_skeleton(
  ordering_groups_base : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_sizes : Map[String, NodeSize],
) -> (
  Map[Int, Array[String]],
  Map[String, NodeSize],
  Map[String, String],
  Map[String, Bool],
) {
  let order_groups =
    if order_with_vnodes {
      build_x_groups_with_vnodes(
        ordering_groups_base,
        base_order_index,
        vnode_info.vnodes_by_rank,
        vnode_order_keys_for_ordering,
      )
    } else {
      let out : Map[Int, Array[String]] = Map::new()
      for rank, names in ordering_groups_base {
        out[rank] = names.copy()
      }
      out
    }
  let order_sizes_out =
    build_order_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
    )
  let order_cluster_keys =
    build_order_cluster_keys_for_order_graph(
      cluster_meta.cluster_keys,
      order_with_vnodes,
      vnode_info.vnode_clusters,
    )
  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  if order_with_clusters {
    // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
    let skeleton_size = vnode_size_from_widths(1.0, 1.0)
    let cluster_seen : Map[String, Bool] = Map::new()
    for cluster in cluster_meta.cluster_order {
      match cluster_meta.cluster_min_rank.get(cluster) {
        Some(min_rank) => {
          let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
            Some(value) => value
            None => min_rank
          }
          append_order_cluster_skeleton_range(
            cluster,
            min_rank,
            max_rank,
            order_cluster_keys,
            order_cluster_skeleton,
            order_sizes_out,
            order_groups,
            skeleton_size,
          )
          cluster_seen[cluster] = true
        }
        None => ()
      }
    }
    for cluster, min_rank in cluster_meta.cluster_min_rank {
      if cluster_seen.get(cluster) is Some(_) {
        continue
      }
      let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      append_order_cluster_skeleton_range(
        cluster,
        min_rank,
        max_rank,
        order_cluster_keys,
        order_cluster_skeleton,
        order_sizes_out,
        order_groups,
        skeleton_size,
      )
    }
  }
  (
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: unconstrained real nodes keep GD_nlist seed order, with
/// incoming-only local-cluster nodes reversed to match fast_node head-insert
/// behavior before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn apply_unconstrained_order_node_overrides(
  gdnlist_order : Array[String],
  real_nodes : Map[String, Bool],
  order_nodes : Array[String],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  rank_same_groups : Map[String, Int],
  edge_tail : Array[String],
  edge_head : Array[String],
  nodes : Array[@cgraph.Node],
  intercluster_keys : Map[String, String],
  order_node_order : Map[String, Int],
) -> Unit {
  // Graphviz parity: unconstrained nodes retain GD_nlist order for seeding.
  let gdnlist_order_index =
    build_gdnlist_order_index_for_real_nodes(gdnlist_order, real_nodes)
  let unconstrained_nodes =
    collect_unconstrained_order_nodes(
      order_nodes,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
    )
  for name, idx in gdnlist_order_index {
    if real_nodes.get(name) is Some(_) &&
      unconstrained_nodes.get(name) is Some(_) &&
      rank_same_groups.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: incoming-only unconstrained nodes inside local
  // clusters follow reverse input order (fast_node inserts at head).
  let (node_has_out, node_has_in) =
    build_node_in_out_presence_maps(edge_tail, edge_head)
  let local_creation =
    build_local_cluster_creation_order(nodes, intercluster_keys)
  reorder_incoming_only_unconstrained_local_nodes(
    local_creation,
    unconstrained_nodes,
    rank_same_groups,
    node_has_out,
    node_has_in,
    order_node_order,
  )
}

///|
/// Graphviz parity: build_ranks seeding runs component-scoped ordering first,
/// then applies transpose when crossings remain (port-offset aware tie-breaks).
/// Do not change behavior without updating fixtures/tests.
fn build_seeded_groups_for_order_reorder(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  order_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  // Graphviz parity: seed build_ranks from component-scoped walk,
  // matching decompose/install traversal used by remincross with
  // cluster-expanded flat constraints.
  let seeded_groups = build_rank_groups_graphviz_components(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    0,
    order_flat_constraints,
    flip=graphviz_flip,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
  )
  // Graphviz parity: build_ranks applies transpose if crossings remain;
  // crossing count uses endpoint port x offsets for tie-correct ordering.
  let seed_cross = count_crossings_graphviz(
    seeded_groups,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    edge_tail_port_x=order_edge_tail_port_x,
    edge_head_port_x=order_edge_head_port_x,
  )
  if seed_cross > 0 {
    let (edge_penalty, edge_in, edge_out) =
      build_transpose_seed_edge_maps(
        order_rank_keys,
        seeded_groups,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_ranks,
      )
    let _ = transpose_rank_groups_graphviz(
      order_rank_keys,
      seeded_groups,
      order_ranks,
      edge_in,
      edge_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      edge_penalty,
      order_cluster_keys,
      order_cluster_skeleton,
      flat_rank_constraints,
      false,
      0,
    )
  }
  dot_trace_groups("seeded_groups", seeded_groups)
  seeded_groups
}

///|
/// Graphviz parity: clustered order pass runs cluster-local build_ranks on the
/// unmapped order graph, then stores vnode-inclusive rank groups for later xpos.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_build_ranks_and_track_vnodes(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if order_with_clusters {
    reorder_groups_by_cluster_build_ranks(
      graph,
      ordered,
      cluster_meta,
      order_node_order,
      order_edges_out_unmapped,
      order_edge_tail_out_unmapped,
      order_edge_head_out_unmapped,
      order_edge_tail_port_x_unmapped,
      order_edge_head_port_x_unmapped,
      order_edge_tail_port_order_unmapped,
      order_edge_head_port_order_unmapped,
      ranks,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      vnode_info,
      graphviz_flip,
      order_with_vnodes,
    )
  }
  let mut next_ordered_with_vnodes = ordered_with_vnodes
  if order_with_vnodes {
    next_ordered_with_vnodes = ordered
  }
  next_ordered_with_vnodes
}

///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
fn finalize_order_groups_with_cluster_remincross(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let cleaned_groups =
    collect_real_only_rank_groups(order_rank_keys, ordered, real_nodes)
  dot_trace_groups("cleaned_groups_pre", cleaned_groups)
  let mut final_groups = cleaned_groups
  let mut next_ordered_with_vnodes = ordered_with_vnodes
  if order_with_clusters {
    final_groups =
      reorder_rank_groups_by_cluster_rank_order(
        final_groups,
        cluster_rank_order,
        cluster_meta.cluster_keys,
      )
    // Graphviz parity: order local subclusters within outer clusters by minrank/first order.
    reorder_groups_by_local_cluster_order(
      final_groups,
      cluster_meta.cluster_keys,
      cluster_meta.intercluster_keys,
      local_cluster_order,
    )
    dot_trace_groups("cleaned_groups_post", final_groups)
    let (rem_ordered_with_vnodes, rem_final_groups) =
      run_clustered_remincross_pass(
        graph,
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        edge_tail_port_x,
        edge_head_port_x,
        edge_tail_port_order,
        edge_head_port_order,
        ranks,
        order_with_vnodes,
        order_with_clusters,
        flat_rank_constraints,
        creation_order,
        edges_by_tail,
        cluster_meta,
        vnode_info,
        order_sizes,
        rank_same_constraints,
        final_groups,
        next_ordered_with_vnodes,
        real_nodes,
        graphviz_flip,
        nodesep_pt,
        has_edge_labels,
        port_order_positions,
        port_order_contrib,
      )
    next_ordered_with_vnodes = rem_ordered_with_vnodes
    final_groups = rem_final_groups
  }
  (next_ordered_with_vnodes, final_groups)
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
  let order_groups_for_mincross =
    build_order_groups_for_root_mincross(
      order_with_clusters,
      seeded_groups,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_nodes : Array[String] = ["front_end_jz", "z_req1", "z_req"]
    for name in debug_nodes {
      let inn = match graphviz_in_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      let out = match graphviz_out_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      println("order_neighbors \{name} in=\{inn} out=\{out}")
    }
  }
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
  let preferred_positions =
    if order_with_vnodes {
      vnode_order_keys_for_ordering
    } else {
      Map::new()
    }
  let ordered_mincross = reorder_rank_groups(
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
    graphviz_flip=graphviz_flip,
  )
  let ordered =
    if order_with_clusters {
      merge_root_mincross_order_into_seeded_groups(
        order_rank_keys,
        seeded_groups,
        ordered_mincross,
        mincross_nodes,
      )
    } else {
      ordered_mincross
    }
  (order_groups_for_mincross, ordered)
}

///|
/// Graphviz parity: ordering + vnode expansion aligned to refs/graphviz/lib/dotgen/mincross.c + dotgen/flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_ordering_and_vnodes(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> OrderingResult {
  let real_nodes : Map[String, Bool] = Map::new()
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    let name = node.name()
    real_nodes[name] = true
    existing_names[name] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
    cluster_meta.cluster_parents,
  )
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = port_is_explicit(edge.tail_port()) ||
      port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  let local_cluster_order = build_local_cluster_order(
    nodes,
    cluster_meta.intercluster_keys,
    ranks,
    node_order,
  )
  let rank_same_constraints = build_rank_same_constraints(
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    node_order,
    port_edge_nodes,
    ranks,
  )
  let vnode_count = vnode_info.vnode_ranks.length()
  let vnode_tail_constraints =
    if vnode_count > 0 {
      build_vnode_tail_constraints(vnode_info.vnodes_by_rank, edge_tail)
    } else {
      Map::new()
    }
  let edge_order = collect_edge_order(edges)
  let (edge_tail_port_x, edge_head_port_x) =
    compute_edge_port_positions(nodes, edges, edge_tail, edge_head, order_sizes)
  let (edge_tail_port_order, edge_head_port_order) =
    compute_edge_port_orders(nodes, edges, edge_tail, edge_head, order_sizes)
  let (order_edges, order_edge_tail, order_edge_head) =
    dedup_ordering_edges(edges, edge_tail, edge_head)
  let (order_edge_tail_port_x, order_edge_head_port_x) =
    compute_edge_port_positions(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_sizes,
    )
  let (order_edge_tail_port_order, order_edge_head_port_order) =
    compute_edge_port_orders(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_sizes,
    )
  let ordering_groups_base = apply_rank_same_order_with_port_override(
    groups,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    node_order,
    port_edge_nodes,
  )
  let base_order_index = build_order_index(ordering_groups_base)
  let order_with_vnodes = vnode_count > 0
  let order_with_clusters =
    cluster_meta.has_clusters && cluster_meta.cluster_min_rank.length() > 0
  // Graphviz parity: GD_flip is true for horizontal rankdir (LR/RL).
  let graphviz_flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let flat_rank_constraints =
    build_flat_rank_constraints(
      edge_tail,
      edge_head,
      ranks,
    )
  // Graphviz parity: class2 iterates agfstnode order (creation order) for edge traversal.
  let creation_order = collect_creation_order(nodes)
  // Graphviz parity: order-graph edges follow ND_out ordering after acyclic.
  let edges_by_tail =
    build_edges_by_tail_from_out_order(nodes, edge_out_order)
  let (order_edges_by_tail, vnode_creation_by_tail, order_edge_creation) =
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
      vnode_info.edge_vnodes,
      order_with_vnodes,
      cluster_meta.cluster_keys,
      order_with_clusters,
      false,
      true,
      edges_by_tail,
    )
  let (order_edges_by_tail_root, root_edge_creation) =
    build_root_order_edges_by_tail(
      order_with_clusters,
      order_edges_by_tail,
      order_edge_creation,
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      vnode_info.edge_vnodes,
      order_with_vnodes,
      cluster_meta.cluster_keys,
      edges_by_tail,
    )
  // Graphviz parity: cluster-local build_ranks uses edge chains before
  // root/cluster remapping so local passes see original cluster endpoints.
  let order_edges_by_tail_unmapped =
    build_unmapped_order_edges_by_tail(
      order_with_clusters,
      order_edges_by_tail,
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      vnode_info.edge_vnodes,
      order_with_vnodes,
      cluster_meta.cluster_keys,
      edges_by_tail,
    )
  let cluster_skeleton_creation =
    build_cluster_skeleton_creation(
      order_with_clusters,
      cluster_meta.cluster_order,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
    )
  let skeleton_edge_creation : Array[(String, String)] = []
  if order_with_clusters {
    let cluster_seen : Map[String, Bool] = Map::new()
    for cluster in cluster_meta.cluster_order {
      match cluster_meta.cluster_min_rank.get(cluster) {
        Some(min_rank) => {
          let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
            Some(value) => value
            None => min_rank
          }
          append_cluster_skeleton_edges(
            cluster,
            min_rank,
            max_rank,
            order_edges_by_tail,
            order_edges_by_tail_root,
            skeleton_edge_creation,
          )
          cluster_seen[cluster] = true
        }
        None => ()
      }
    }
    for cluster, min_rank in cluster_meta.cluster_min_rank {
      if cluster_seen.get(cluster) is Some(_) {
        continue
      }
      let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      append_cluster_skeleton_edges(
        cluster,
        min_rank,
        max_rank,
        order_edges_by_tail,
        order_edges_by_tail_root,
        skeleton_edge_creation,
      )
    }
  }
  let edge_creation_order =
    build_edge_creation_order(
      skeleton_edge_creation,
      order_edge_creation,
    )
  // Graphviz parity: class2 creates cluster skeletons first, then interleaves
  // real nodes with their edge vnodes in agfstnode order.
  let (order_creation, vnode_creation_order) =
    build_order_creation_with_vnodes(
      cluster_skeleton_creation,
      creation_order,
      vnode_creation_by_tail,
    )
  // Graphviz parity: decompose DFS starts from agfstnode (creation) order
  // regardless of rankdir flip.
  // Do not change behavior without updating fixtures/tests.
  let nlist_tail_order : Array[String] = creation_order
  let nlist_order_raw =
    build_graphviz_nlist_order_from_edges(
      nlist_tail_order,
      order_creation,
      edge_creation_order,
      flat_rank_constraints,
    )
  let nlist_order =
    adjust_nlist_order_for_cluster_flip(
      nlist_order_raw,
      graphviz_flip,
      cluster_meta.has_clusters,
      cluster_meta.cluster_keys,
    )
  // Graphviz parity: GD_nlist follows decompose DFS order over fast graph edges.
  // Do not change behavior without updating fixtures/tests.
  let gdnlist_order = nlist_order
  trace_nlist_order_debug(nlist_order)
  let nlist_order_index = build_nlist_order_index(nlist_order)
  let vnode_order_keys_for_ordering =
    if vnode_count > 0 {
      if cluster_meta.has_clusters {
        build_vnode_order_keys(
          edges,
          edge_tail,
          edge_head,
          edge_reversed,
          ranks,
          base_order_index,
          cluster_meta.cluster_keys,
          cluster_meta.cluster_parents,
          vnode_info.edge_vnodes,
          vnode_info.vnode_ranks,
        )
      } else {
        build_vnode_order_keys_from_nlist(
          ordering_groups_base,
          vnode_info.vnodes_by_rank,
          base_order_index,
          nlist_order_index,
          Map::new(),
          false,
        )
      }
    } else {
      Map::new()
    }
  let mut ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  let ordered_groups_internal =
    if order_with_vnodes || order_with_clusters {
      let (
        order_groups,
        order_sizes_out,
        order_cluster_keys,
        order_cluster_skeleton,
      ) =
        build_order_groups_sizes_and_cluster_skeleton(
          ordering_groups_base,
          base_order_index,
          order_with_vnodes,
          order_with_clusters,
          cluster_meta,
          vnode_info,
          vnode_order_keys_for_ordering,
          order_sizes,
        )
      dot_trace_groups("order_groups_pre", order_groups)
      let order_rank_keys = collect_rank_keys(order_groups)
      let order_ranks = build_node_ranks(order_groups)
      let order_nodes =
        build_order_nodes_from_groups(order_groups, order_rank_keys)
      let (order_graph, order_node_map) =
        build_order_graph_and_nodes("order_graph", order_nodes)
      let (order_graph_unmapped, order_node_map_unmapped) =
        build_order_graph_and_nodes("order_graph_unmapped", order_nodes)
      let creation_order =
        build_reverse_creation_order_from_nlist(nlist_order)
      let order_node_order =
        build_order_node_order_for_build_ranks(
          gdnlist_order,
          nlist_order,
          node_order,
          real_nodes,
          order_groups,
          base_order_index,
          cluster_meta.rank_same_groups,
          cluster_meta.rank_same_order,
          port_edge_nodes,
        )
      trace_order_node_order_debug(order_node_order)
      let (
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_edge_tail_port_x,
        order_edge_head_port_x,
        order_edge_tail_port_order,
        order_edge_head_port_order,
        order_edges_out_unmapped,
        order_edge_tail_out_unmapped,
        order_edge_head_out_unmapped,
        order_edge_tail_port_x_unmapped,
        order_edge_head_port_x_unmapped,
        order_edge_tail_port_order_unmapped,
        order_edge_head_port_order_unmapped,
      ) =
        materialize_mapped_and_unmapped_order_edges(
          nlist_order,
          order_edges_by_tail,
          order_graph,
          order_node_map,
          order_edges_by_tail_unmapped,
          order_graph_unmapped,
          order_node_map_unmapped,
        )
      trace_order_edges_with_ranks(
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_ranks,
        real_nodes,
      )
      let (graphviz_out_neighbors, graphviz_in_neighbors) =
        build_graphviz_neighbor_maps(
          order_nodes,
          order_edges_by_tail,
          edge_creation_order,
        )
      let order_flat_constraints =
        clone_flat_constraints(cluster_meta.flat_constraints)
      apply_unconstrained_order_node_overrides(
        gdnlist_order,
        real_nodes,
        order_nodes,
        graphviz_out_neighbors,
        graphviz_in_neighbors,
        cluster_meta.rank_same_groups,
        edge_tail,
        edge_head,
        nodes,
        cluster_meta.intercluster_keys,
        order_node_order,
      )
      let seeded_groups =
        build_seeded_groups_for_order_reorder(
          order_rank_keys,
          order_groups,
          order_edge_tail_out,
          order_edge_head_out,
          order_ranks,
          order_node_order,
          order_cluster_keys,
          order_cluster_skeleton,
          order_flat_constraints,
          graphviz_flip,
          graphviz_out_neighbors,
          graphviz_in_neighbors,
          order_edges_out,
          order_edge_tail_port_x,
          order_edge_head_port_x,
          flat_rank_constraints,
        )
      let (order_groups_for_mincross, ordered) =
        run_root_mincross_reorder(
          order_with_clusters,
          order_with_vnodes,
          seeded_groups,
          order_rank_keys,
          order_ranks,
          order_edges_out,
          order_edge_tail_out,
          order_edge_head_out,
          order_edge_tail_port_x,
          order_edge_head_port_x,
          order_edge_tail_port_order,
          order_edge_head_port_order,
          order_cluster_keys,
          order_cluster_skeleton,
          cluster_meta,
          vnode_order_keys_for_ordering,
          order_node_order,
          order_sizes_out,
          nodesep_pt,
          has_edge_labels,
          port_order_positions,
          port_order_contrib,
          order_flat_constraints,
          graphviz_out_neighbors,
          graphviz_in_neighbors,
          graphviz_flip,
        )
      ordered_with_vnodes =
        apply_cluster_build_ranks_and_track_vnodes(
          order_with_clusters,
          order_with_vnodes,
          graph,
          ordered,
          cluster_meta,
          order_node_order,
          order_edges_out_unmapped,
          order_edge_tail_out_unmapped,
          order_edge_head_out_unmapped,
          order_edge_tail_port_x_unmapped,
          order_edge_head_port_x_unmapped,
          order_edge_tail_port_order_unmapped,
          order_edge_head_port_order_unmapped,
          ranks,
          order_sizes_out,
          nodesep_pt,
          has_edge_labels,
          port_order_positions,
          port_order_contrib,
          vnode_info,
          graphviz_flip,
          ordered_with_vnodes,
        )
      let cluster_rank_order =
        build_cluster_rank_order_for_cluster_reorder(
          order_with_clusters,
          order_with_vnodes,
          graphviz_flip,
          edges,
          edge_tail,
          edge_head,
          nlist_order,
          ranks,
          order_rank_keys,
          order_groups_for_mincross,
          order_cluster_keys,
          order_cluster_skeleton,
          order_edges_by_tail_root,
          skeleton_edge_creation,
          root_edge_creation,
          flat_rank_constraints,
          cluster_meta,
          vnode_info,
          vnode_order_keys_for_ordering,
          real_nodes,
          order_sizes_out,
          nodesep_pt,
          has_edge_labels,
          port_order_positions,
          port_order_contrib,
        )
      let (next_ordered_with_vnodes, final_groups) =
        finalize_order_groups_with_cluster_remincross(
          order_with_clusters,
          order_with_vnodes,
          cluster_rank_order,
          cluster_meta,
          local_cluster_order,
          order_rank_keys,
          ordered,
          real_nodes,
          ordered_with_vnodes,
          graph,
          edges,
          edge_tail,
          edge_head,
          edge_reversed,
          edge_tail_port_x,
          edge_head_port_x,
          edge_tail_port_order,
          edge_head_port_order,
          ranks,
          flat_rank_constraints,
          creation_order,
          edges_by_tail,
          vnode_info,
          order_sizes,
          rank_same_constraints,
          graphviz_flip,
          nodesep_pt,
          has_edge_labels,
          port_order_positions,
          port_order_contrib,
        )
      ordered_with_vnodes = next_ordered_with_vnodes
      final_groups
    } else {
      run_noncluster_reorder_pass(
        nodes,
        edges,
        edge_tail,
        edge_head,
        edge_out_order,
        ranks,
        rank_keys,
        groups,
        nlist_order,
        node_order,
        order_edges,
        order_edge_tail,
        order_edge_head,
        order_edge_tail_port_x,
        order_edge_head_port_x,
        order_edge_tail_port_order,
        order_edge_head_port_order,
        cluster_meta,
        edge_order,
        order_sizes,
        nodesep_pt,
        has_edge_labels,
        port_order_positions,
        port_order_contrib,
        graphviz_flip,
      )
    }
  {
    ordered_groups: ordered_groups_internal,
    ordered_groups_with_vnodes: ordered_with_vnodes,
    vnode_info,
    vnode_count,
    order_edges,
    order_edge_tail,
    order_edge_head,
    edge_order,
    edge_cluster_keys,
    nlist_order,
    gdnlist_order,
    vnode_creation_order,
  }
}

///|
/// Graphviz parity: x-positioning aligned to refs/graphviz/lib/dotgen/position.c + dotgen/cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> PositionResult {
  let use_vnodes_for_xpos =
    prep.has_edge_labels || prep.has_port_edges || ordering.vnode_count <= MAX_XPOS_VNODES
  let allow_xpos_reorder =
    !use_vnodes_for_xpos || ordering.vnode_count <= MAX_XPOS_REORDER_VNODES
  let graphviz_flip = prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL
  // Graphviz parity: xpos constraints must preserve mincross ordering; do not reorder here.
  let xpos_reorder_enabled = false
  dot_trace("layout_dot: vnodes built count=\{ordering.vnode_count}")
  let virtual_slack_edges =
    if use_vnodes_for_xpos {
      let node_singletons = build_node_singletons(prep.nodes, prep.edges)
      let edges_out = build_virtual_slack_edges(
        prep.edges,
        rank_data.edge_tail,
        rank_data.edge_head,
        rank_data.edge_reversed,
        rank_data.ranks,
        ordering.vnode_info.edge_vnodes,
        ordering.vnode_info.vnode_ranks,
        node_singletons,
        cluster_meta.cluster_keys,
      )
      dot_trace("layout_dot: virtual slack edges=\{edges_out.length()}")
      edges_out
    } else {
      dot_trace("layout_dot: virtual slack edges=0 (skipped)")
      []
    }
  let order_index = build_order_index(ordering.ordered_groups)
  let mut vnode_order_keys : Map[String, Double] = Map::new()
  let mut has_vnode_order = false
  if use_vnodes_for_xpos && ordering.ordered_groups_with_vnodes.length() == 0 {
    vnode_order_keys = build_vnode_order_keys(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.edge_reversed,
      rank_data.ranks,
      order_index,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      ordering.vnode_info.edge_vnodes,
      ordering.vnode_info.vnode_ranks,
    )
    for _name, _ in vnode_order_keys {
      has_vnode_order = true
      break
    }
  }
  if use_vnodes_for_xpos && ordering.ordered_groups_with_vnodes.length() > 0 {
    has_vnode_order = true
  }
  // Graphviz parity: x-positioning uses layout-coordinate node sizes,
  // so rankdir flip is handled via prep.sizes (not ordering-space widths).
  let x_base_sizes = apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    prep.sizes,
    prep.rankdir,
    prep.record_orientation,
  )
  let x_order_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let (x_edge_tail_port_x, x_edge_head_port_x) =
    compute_edge_port_positions(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let (x_edge_tail_port_order, x_edge_head_port_order) =
    compute_edge_port_orders(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let mut x_groups =
    if use_vnodes_for_xpos {
      if ordering.ordered_groups_with_vnodes.length() > 0 {
        clone_rank_groups(ordering.ordered_groups_with_vnodes)
      } else {
        build_x_groups_with_vnodes(
          ordering.ordered_groups,
          order_index,
          ordering.vnode_info.vnodes_by_rank,
          vnode_order_keys,
        )
      }
    } else {
      ordering.ordered_groups
    }
  if cluster_meta.has_clusters {
    let cleaned : Map[Int, Array[String]] = Map::new()
    for rank, names in x_groups {
      let filtered : Array[String] = []
      for name in names {
        if cluster_key_from_skeleton_name(name) is None {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        cleaned[rank] = filtered
      }
    }
    x_groups = cleaned
  }
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_meta.cluster_keys {
    x_cluster_keys[name] = key
  }
  if use_vnodes_for_xpos {
    for name, key in ordering.vnode_info.vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  if xpos_reorder_enabled && use_vnodes_for_xpos && allow_xpos_reorder &&
    !cluster_meta.ordering_set {
    let order_groups : Map[Int, Array[String]] = Map::new()
    for rank, names in x_groups {
      order_groups[rank] = names.copy()
    }
    let order_sizes : Map[String, NodeSize] = Map::new()
    for name, size in x_order_sizes {
      order_sizes[name] = size
    }
    let order_cluster_keys : Map[String, String] = Map::new()
    for name, key in x_cluster_keys {
      order_cluster_keys[name] = key
    }
    let order_cluster_skeleton : Map[String, Bool] = Map::new()
    // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
    let skeleton_size = vnode_size_from_widths(1.0, 1.0)
    for cluster, min_rank in cluster_meta.cluster_min_rank {
      let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      for rank in min_rank..=max_rank {
        let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
        order_cluster_keys[name] = cluster
        order_cluster_skeleton[name] = true
        order_sizes[name] = skeleton_size
        match order_groups.get(rank) {
          Some(list) => list.push(name)
          None => order_groups[rank] = [name]
        }
      }
    }
    let order_node_order : Map[String, Int] = Map::new()
    for name, value in prep.node_order {
      order_node_order[name] = value
    }
    let order_index = build_order_index(order_groups)
    for name, idx in order_index {
      if order_node_order.get(name) is None {
        order_node_order[name] = idx
      }
    }
    let order_rank_keys = collect_rank_keys(order_groups)
    let order_ranks = build_node_ranks(order_groups)
    let order_nodes : Array[String] = []
    for rank in order_rank_keys {
      let names = match order_groups.get(rank) {
        Some(list) => list
        None => []
      }
      for name in names {
        order_nodes.push(name)
      }
    }
    let order_graph =
      @cgraph.Graph::new(@cgraph.GraphKind::Directed, name="xpos_order", strict=false)
    let order_node_map : Map[String, @cgraph.Node] = Map::new()
    for name in order_nodes {
      order_node_map[name] = order_graph.node(name)
    }
    let order_edges_out : Array[@cgraph.Edge] = []
    let order_edge_tail_out : Array[String] = []
    let order_edge_head_out : Array[String] = []
    let order_edge_tail_port_x : Array[Double] = []
    let order_edge_head_port_x : Array[Double] = []
    let order_edge_tail_port_order : Array[Double] = []
    let order_edge_head_port_order : Array[Double] = []
    let mut edge_idx = 0
    for edge in prep.edges {
      let tail =
        if edge_idx < rank_data.edge_tail.length() { rank_data.edge_tail[edge_idx] } else {
          edge.tail().name()
        }
      let head =
        if edge_idx < rank_data.edge_head.length() { rank_data.edge_head[edge_idx] } else {
          edge.head().name()
        }
      let penalty = edge_xpenalty(edge)
      let constraint = edge_is_constraint(edge)
      let tail_port_x =
        if edge_idx < x_edge_tail_port_x.length() { x_edge_tail_port_x[edge_idx] } else {
          0.0
        }
      let head_port_x =
        if edge_idx < x_edge_head_port_x.length() { x_edge_head_port_x[edge_idx] } else {
          0.0
        }
      let tail_port_order =
        if edge_idx < x_edge_tail_port_order.length() { x_edge_tail_port_order[edge_idx] } else {
          0.5
        }
      let head_port_order =
        if edge_idx < x_edge_head_port_order.length() { x_edge_head_port_order[edge_idx] } else {
          0.5
        }
      let vnodes = match ordering.vnode_info.edge_vnodes.get(edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      if vnodes.length() == 0 {
        add_order_edge(
          order_graph,
          order_node_map,
          order_edges_out,
          order_edge_tail_out,
          order_edge_head_out,
          order_edge_tail_port_x,
          order_edge_head_port_x,
          order_edge_tail_port_order,
          order_edge_head_port_order,
          tail,
          head,
          penalty,
          constraint,
          tail_port_x,
          head_port_x,
          tail_port_order,
          head_port_order,
        )
      } else {
        let tail_rank = match rank_data.ranks.get(tail) {
          Some(value) => value
          None => 0
        }
        let head_rank = match rank_data.ranks.get(head) {
          Some(value) => value
          None => 0
        }
        let chain : Array[String] = []
        chain.push(tail)
        if tail_rank <= head_rank {
          for vnode in vnodes {
            chain.push(vnode)
          }
        } else {
          let mut i = vnodes.length()
          while i > 0 {
            i = i - 1
            chain.push(vnodes[i])
          }
        }
        chain.push(head)
        let mut idx = 0
        while idx + 1 < chain.length() {
          let seg_tail_port =
            if chain[idx] == tail { tail_port_x } else { 0.0 }
          let seg_head_port =
            if chain[idx + 1] == head { head_port_x } else { 0.0 }
          // Graphviz parity: split edge segments keep neutral midpoint
          // port-order (0.5) unless endpoint matches real tail/head.
          let seg_tail_order =
            if chain[idx] == tail { tail_port_order } else { 0.5 }
          let seg_head_order =
            if chain[idx + 1] == head { head_port_order } else { 0.5 }
          add_order_edge(
            order_graph,
            order_node_map,
            order_edges_out,
            order_edge_tail_out,
            order_edge_head_out,
            order_edge_tail_port_x,
            order_edge_head_port_x,
            order_edge_tail_port_order,
            order_edge_head_port_order,
            chain[idx],
            chain[idx + 1],
            penalty,
            constraint,
            seg_tail_port,
            seg_head_port,
            seg_tail_order,
            seg_head_order,
          )
          idx = idx + 1
        }
      }
      edge_idx = edge_idx + 1
    }
    for cluster, min_rank in cluster_meta.cluster_min_rank {
      let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      let mut rank = min_rank
      while rank < max_rank {
        let tail_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
        let head_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank + 1}"
        add_order_edge(
          order_graph,
          order_node_map,
          order_edges_out,
          order_edge_tail_out,
          order_edge_head_out,
          order_edge_tail_port_x,
          order_edge_head_port_x,
          order_edge_tail_port_order,
          order_edge_head_port_order,
          tail_name,
          head_name,
          CL_CROSS,
          true,
          0.0,
          0.0,
          0.5,
          0.5,
        )
        rank = rank + 1
      }
    }
    let (parents, children) = build_edge_index_for_order_names(
      order_nodes,
      order_edge_tail_out,
      order_edge_head_out,
      order_ranks,
    )
    let edge_order = collect_edge_order(order_edges_out)
    // Graphviz parity: xpos reorder uses the same edge-segment port-order hints
    // computed for the order graph (mincross median tie-breaking path).
    let ordered_groups = reorder_rank_groups(
      order_rank_keys,
      order_groups,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      parents,
      children,
      order_cluster_keys,
      cluster_meta.rank_same_groups,
      cluster_meta.rank_same_order,
      edge_order,
      order_node_order,
      order_sizes,
      rank_heights.nodesep_pt,
      prep.has_edge_labels,
      Map::new(),
      Map::new(),
      Map::new(),
      order_cluster_skeleton,
      cluster_meta.flat_constraints,
      graphviz_flip=graphviz_flip,
    )
    x_groups = ordered_groups
  } else if xpos_reorder_enabled &&
    allow_xpos_reorder && !cluster_meta.ordering_set && !has_vnode_order &&
    !cluster_meta.has_clusters {
    let (parents, children) = build_edge_index_for_order_with_vnodes(
      prep.nodes,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      rank_data.ranks,
      ordering.vnode_info.edge_vnodes,
      ordering.vnode_info.vnode_ranks,
    )
    let (order_edge_tail_port_x, order_edge_head_port_x) =
      compute_edge_port_positions(
        prep.nodes,
        ordering.order_edges,
        ordering.order_edge_tail,
        ordering.order_edge_head,
        x_order_sizes,
      )
    // Graphviz parity: even non-cluster xpos reorder uses compass/record
    // port-order fractions when mincross scoring ties are evaluated.
    let (order_edge_tail_port_order, order_edge_head_port_order) =
      compute_edge_port_orders(
        prep.nodes,
        ordering.order_edges,
        ordering.order_edge_tail,
        ordering.order_edge_head,
        x_order_sizes,
      )
    let tmp_rank_keys = collect_rank_keys(x_groups)
    x_groups = reorder_rank_groups(
      tmp_rank_keys,
      x_groups,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      parents,
      children,
      x_cluster_keys,
      cluster_meta.rank_same_groups,
      cluster_meta.rank_same_order,
      ordering.edge_order,
      prep.node_order,
      x_order_sizes,
      rank_heights.nodesep_pt,
      prep.has_edge_labels,
      prep.port_order_positions,
      prep.port_order_contrib,
      Map::new(),
      cluster_meta.cluster_skeleton,
      cluster_meta.flat_constraints,
      graphviz_flip=graphviz_flip,
    )
  }
  dot_trace_groups("x-groups", x_groups)
  if xpos_reorder_enabled && use_vnodes_for_xpos && allow_xpos_reorder &&
    !cluster_meta.ordering_set {
    let (parents, children) = build_edge_index_for_order_with_vnodes(
      prep.nodes,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      rank_data.ranks,
      ordering.vnode_info.edge_vnodes,
      ordering.vnode_info.vnode_ranks,
    )
    let tmp_rank_keys = collect_rank_keys(x_groups)
    let tmp_ranks = build_node_ranks(x_groups)
    let _ = transpose_rank_groups_limited(
      tmp_rank_keys,
      x_groups,
      parents,
      children,
      tmp_ranks,
      false,
      4,
    )
    let _ = transpose_rank_groups_limited(
      tmp_rank_keys,
      x_groups,
      parents,
      children,
      tmp_ranks,
      true,
      4,
    )
  }
  let mut flat_label_edges : Array[ConstraintEdge] = []
  let mut flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let mut flat_label_edge_vnodes : Map[String, String] = Map::new()
  let existing_names : Map[String, Bool] = Map::new()
  for node in prep.nodes {
    existing_names[node.name()] = true
  }
  for vnode, _ in ordering.vnode_info.vnode_ranks {
    existing_names[vnode] = true
  }
  if use_vnodes_for_xpos {
    let (
      updated_groups,
      label_nodes,
      label_edge_vnodes,
      extra_edges,
    ) = add_flat_label_vnodes(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.ranks,
      ordering.ordered_groups,
      rank_heights.nodesep_pt,
      prep.rankdir,
      x_base_sizes,
      ordering.edge_cluster_keys,
      cluster_meta.cluster_parents,
      existing_names,
      ordering.vnode_info,
      x_groups,
    )
    x_groups = updated_groups
    flat_label_edges = extra_edges
    flat_label_nodes = label_nodes
    flat_label_edge_vnodes = label_edge_vnodes
    for name, key in ordering.vnode_info.vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  let rank_pht = rank_heights.rank_pht
  let rank_ht1 = rank_heights.rank_ht1
  let rank_ht2 = rank_heights.rank_ht2
  let cluster_bbox_heights =
    if cluster_meta.has_clusters {
      compute_cluster_bbox_heights(
        graph,
        rank_data.ranks,
        prep.sizes,
        rank_data.self_edge_labels,
        prep.rankdir,
      )
    } else {
      Map::new()
    }
  if flat_label_nodes.length() > 0 {
    for name, info in flat_label_nodes {
      let size = match ordering.vnode_info.vnode_sizes.get(name) {
        Some(value) => value
        None => continue
      }
      let half_height = size.height_pt / 2.0
      let rank = info.rank
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[rank] = half_height
      }
      let current_ht1 = match rank_ht1.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current_ht1 {
        rank_ht1[rank] = half_height
      }
      let current_ht2 = match rank_ht2.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current_ht2 {
        rank_ht2[rank] = half_height
      }
    }
  }
  let y_all_ranks : Array[Int] = []
  if rank_data.rank_keys.length() > 0 {
    let mut min_rank = rank_data.rank_keys[0]
    let mut max_rank = rank_data.rank_keys[rank_data.rank_keys.length() - 1]
    if flat_label_nodes.length() > 0 {
      for _name, info in flat_label_nodes {
        if info.rank < min_rank {
          min_rank = info.rank
        }
        if info.rank > max_rank {
          max_rank = info.rank
        }
      }
    }
    for rank in min_rank..=max_rank {
      y_all_ranks.push(rank)
    }
  }
  let mut y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  fill_rank_positions(
    rank_data.rank_keys,
    rank_data.groups,
    y_all_ranks,
    rank_pht,
    rank_ht1,
    rank_ht2,
    rank_heights.ranksep_pt,
    y_positions,
    rank_y,
  )
  if (prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL) &&
    graph_has_cluster(graph) {
    let min_root_rank = if y_all_ranks.length() > 0 { y_all_ranks[0] } else { 0 }
    let adjusted =
      adjust_flip_cluster_rank_heights(
      graph,
      rank_data.ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      cluster_bbox_heights,
      min_root_rank,
      0.0,
    )
    if adjusted {
      y_positions = Map::new()
      for rank in rank_data.rank_keys {
        let pos_y = match rank_y.get(rank) {
          Some(value) => value
          None => 0.0
        }
        let names = match rank_data.groups.get(rank) {
          Some(list) => list
          None => []
        }
        for name in names {
          y_positions[name] = pos_y
        }
      }
    }
  }
  let x_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let x_rank_keys = collect_rank_keys(x_groups)
  let x_ranks = build_node_ranks(x_groups)
  let vnode_extra_nodes =
    if use_vnodes_for_xpos {
      build_vnode_extra_nodes(
        ordering.vnode_creation_order,
        ordering.vnode_info.vnode_ranks,
      )
    } else {
      []
    }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes =
    if use_vnodes_for_xpos {
      ordering.vnode_info.edge_vnodes
    } else {
      Map::new()
    }
  let x_slack_edges =
    if use_vnodes_for_xpos {
      virtual_slack_edges
    } else {
      []
    }
  let x_positions = compute_x_positions(
    graph,
    prep.nodes,
    prep.edges,
    rank_data.edge_tail,
    rank_data.edge_head,
    rank_data.edge_out_order,
    ordering.nlist_order,
    ordering.gdnlist_order,
    x_ranks,
    x_rank_keys,
    x_groups,
    x_sizes,
    prep.output_sizes,
    x_cluster_keys,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    x_extra_nodes,
    flat_label_edges,
    x_edge_vnodes,
    x_slack_edges,
  )
  dot_trace("layout_dot: x positions computed")
  dot_trace_positions("xpos", x_positions)
  let intercluster_align_enabled = match @sys.get_env_var("DOT_INTERCLUSTER_ALIGN") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
  if cluster_meta.has_clusters && prep.has_dotted_edges && intercluster_align_enabled {
    adjust_intercluster_alignment(
      prep.nodes,
      prep.edges,
      rank_data.ranks,
      x_positions,
      cluster_meta.cluster_keys,
      cluster_meta.intercluster_keys,
      rank_heights.nodesep_pt,
      prep.has_edge_labels,
    )
  }
  // Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
  let cluster_ln_x : Map[String, Double] = Map::new()
  let cluster_rn_x : Map[String, Double] = Map::new()
  if cluster_meta.has_clusters {
    let cluster_names : Map[String, Bool] = Map::new()
    collect_cluster_names(graph, cluster_names)
    if cluster_names.length() > 0 {
      for name, pos_x in x_positions {
        if name.has_prefix(CLUSTER_LN_PREFIX) ||
          name.has_prefix(CLUSTER_RN_PREFIX) {
          match cluster_key_from_boundary_name(name, cluster_names) {
            Some(cluster_key) =>
              if name.has_prefix(CLUSTER_LN_PREFIX) {
                cluster_ln_x[cluster_key] = pos_x
              } else {
                cluster_rn_x[cluster_key] = pos_x
              }
            None => ()
          }
        }
      }
    }
  }
  // Let the final bounding-box translation handle normalization, matching Graphviz.
  let vnode_positions =
    if use_vnodes_for_xpos {
      let positions : Map[String, @geom.Point] = Map::new()
      for name, rank in ordering.vnode_info.vnode_ranks {
        let pos_x = match x_positions.get(name) {
          Some(value) => value
          None => 0.0
        }
        let pos_y = match rank_y.get(rank) {
          Some(value) => value
          None => 0.0
        }
        positions[name] = { x: pos_x, y: pos_y }
      }
      positions
    } else {
      vnode_positions_from_endpoints(
        prep.edges,
        rank_data.ranks,
        ordering.vnode_info.vnode_ranks,
        ordering.vnode_info.edge_vnodes,
        x_positions,
        rank_y,
      )
    }
  let positions : Map[String, @geom.Point] = Map::new()
  for node in prep.nodes {
    let name = node.name()
    let pos_x = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = match y_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    positions[name] = { x: pos_x, y: pos_y }
  }
  if cluster_meta.has_clusters && cluster_rounding_enabled() {
    let _ = adjust_cluster_positions_for_rounding(
      graph,
      positions,
      vnode_positions,
      ordering.vnode_info.vnode_clusters,
      prep.sizes,
    )
  }
  {
    x_groups,
    rank_y,
    positions,
    vnode_positions,
    cluster_ln_x,
    cluster_rn_x,
    flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
    cluster_bbox_heights,
  }
}
