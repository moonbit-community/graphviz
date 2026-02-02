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
  intercluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
priv struct OrderingResult {
  ordered_groups : Map[Int, Array[String]]
  vnode_info : EdgeVnodeInfo
  vnode_count : Int
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  edge_order : Map[String, Int]
  edge_cluster_keys : Map[String, String]
}

///|
priv struct PositionResult {
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  flat_label_edge_vnodes : Map[String, String]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

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
  let nodesep_in = match opts.nodesep {
    Some(value) => value
    None =>
      match graph.get_attr("nodesep") {
        Some(value) => parse_first_double(value, default_nodesep_in())
        None => default_nodesep_in()
      }
  }
  let ranksep_in = match opts.ranksep {
    Some(value) => value
    None =>
      match graph.get_attr("ranksep") {
        Some(value) => parse_first_double(value, default_ranksep_in())
        None => default_ranksep_in()
      }
  }
  if nodesep_in < 0.0 {
    raise DotLayoutError::InvalidGraph(message="nodesep must be non-negative")
  }
  if ranksep_in < 0.0 {
    raise DotLayoutError::InvalidGraph(message="ranksep must be non-negative")
  }
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
  let node_order : Map[String, Int] = Map::new()
  for i in 0..<nodes.length() {
    node_order[nodes[i].name()] = i
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
  let (edge_tail, edge_head, edge_reversed) =
    if graph.kind() == @cgraph.GraphKind::Directed {
      acyclic_edge_directions(nodes, edges)
    } else {
      edge_endpoints_from_edges(edges)
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
      let half_height = edge_label_height_pt(edge) / 2.0
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
    graph, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
  )
  let nodesep_pt = nodesep_in * 72.0
  let mut ranksep_pt = ranksep_in * 72.0
  if has_edge_labels {
    ranksep_pt = (ranksep_pt + 1.0) / 2.0
  }
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
) -> ClusterMetadata {
  let has_clusters = graph_has_cluster(graph)
  let cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    cluster_keys[node.name()] = node_cluster_key(node)
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
  {
    has_clusters,
    cluster_keys,
    cluster_skeleton,
    cluster_min_rank,
    cluster_max_rank,
    cluster_order,
    intercluster_keys,
    rank_same_groups,
    rank_same_order,
    flat_constraints,
    ordering_set,
  }
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
    edges,
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
  )
  let vnode_count = vnode_info.vnode_ranks.length()
  let edge_order = collect_edge_order(edges)
  let (order_edges, order_edge_tail, order_edge_head) =
    dedup_ordering_edges(edges, edge_tail, edge_head)
  let base_order_index = build_order_index(groups)
  let vnode_order_keys_for_ordering =
    if vnode_count > 0 {
      build_vnode_order_keys(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        base_order_index,
        vnode_info.edge_vnodes,
        vnode_info.vnode_ranks,
      )
    } else {
      Map::new()
    }
  let order_with_vnodes = vnode_count > 0
  let order_with_clusters =
    cluster_meta.has_clusters && cluster_meta.cluster_min_rank.length() > 0
  let ordered_groups_internal =
    if order_with_vnodes || order_with_clusters {
      let order_groups =
        if order_with_vnodes {
          build_x_groups_with_vnodes(
            groups,
            base_order_index,
            vnode_info.vnodes_by_rank,
            vnode_order_keys_for_ordering,
          )
        } else {
          let out : Map[Int, Array[String]] = Map::new()
          for rank, names in groups {
            out[rank] = names.copy()
          }
          out
        }
      let order_sizes_out : Map[String, NodeSize] = Map::new()
      for name, size in order_sizes {
        order_sizes_out[name] = size
      }
      if order_with_vnodes {
        for name, size in vnode_info.vnode_sizes {
          order_sizes_out[name] = size
        }
      }
      let order_cluster_keys : Map[String, String] = Map::new()
      for name, key in cluster_meta.cluster_keys {
        order_cluster_keys[name] = key
      }
      if order_with_vnodes {
        for name, key in vnode_info.vnode_clusters {
          order_cluster_keys[name] = key
        }
      }
      let order_cluster_skeleton : Map[String, Bool] = Map::new()
      let cluster_skeleton_creation : Array[String] = []
      if order_with_clusters {
        let skeleton_size = vnode_size_from_widths(0.0, 0.0)
        let cluster_seen : Map[String, Bool] = Map::new()
        for cluster in cluster_meta.cluster_order {
          match cluster_meta.cluster_min_rank.get(cluster) {
            Some(min_rank) => {
              let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
                Some(value) => value
                None => min_rank
              }
              for rank in min_rank..=max_rank {
                let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
                order_cluster_keys[name] = cluster
                order_cluster_skeleton[name] = true
                order_sizes_out[name] = skeleton_size
                cluster_skeleton_creation.push(name)
                match order_groups.get(rank) {
                  Some(list) => list.push(name)
                  None => order_groups[rank] = [name]
                }
              }
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
          for rank in min_rank..=max_rank {
            let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
            order_cluster_keys[name] = cluster
            order_cluster_skeleton[name] = true
            order_sizes_out[name] = skeleton_size
            cluster_skeleton_creation.push(name)
            match order_groups.get(rank) {
              Some(list) => list.push(name)
              None => order_groups[rank] = [name]
            }
          }
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
        @cgraph.Graph::new(@cgraph.GraphKind::Directed, name="order_graph", strict=false)
      let order_node_map : Map[String, @cgraph.Node] = Map::new()
      for name in order_nodes {
        order_node_map[name] = order_graph.node(name)
      }
      let tail_order : Array[String] = []
      for node in nodes {
        tail_order.push(node.name())
      }
      let edges_by_tail =
        if order_with_clusters {
          let filtered : Map[String, Array[Int]] = Map::new()
          for i in 0..<edges.length() {
            let tail =
              if i < edge_tail.length() { edge_tail[i] } else { edges[i].tail().name() }
            let head =
              if i < edge_head.length() { edge_head[i] } else { edges[i].head().name() }
            let tail_cluster = match cluster_meta.cluster_keys.get(tail) {
              Some(value) => value
              None => ""
            }
            let head_cluster = match cluster_meta.cluster_keys.get(head) {
              Some(value) => value
              None => ""
            }
            if tail_cluster != "" && tail_cluster == head_cluster {
              continue
            }
            match filtered.get(tail) {
              Some(list) => list.push(i)
              None => filtered[tail] = [i]
            }
          }
          filtered
        } else {
          collect_edge_indices_by_tail(edges, edge_tail)
        }
      let (order_edges_by_tail, vnode_creation_by_tail) =
        build_order_edges_by_tail_graphviz(
          tail_order,
          edges,
          edge_tail,
          edge_head,
          ranks,
          vnode_info.edge_vnodes,
          order_with_vnodes,
          cluster_meta.cluster_keys,
          order_with_clusters,
          edges_by_tail,
        )
      if order_with_clusters {
        let cluster_seen : Map[String, Bool] = Map::new()
        for cluster in cluster_meta.cluster_order {
          match cluster_meta.cluster_min_rank.get(cluster) {
            Some(min_rank) => {
              let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
                Some(value) => value
                None => min_rank
              }
              let mut rank = min_rank
              while rank < max_rank {
                let tail_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
                let head_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank + 1}"
                let entry = (tail_name, head_name, CL_CROSS, true)
                match order_edges_by_tail.get(tail_name) {
                  Some(list) => list.push(entry)
                  None => order_edges_by_tail[tail_name] = [entry]
                }
                rank = rank + 1
              }
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
          let mut rank = min_rank
          while rank < max_rank {
            let tail_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
            let head_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank + 1}"
            let entry = (tail_name, head_name, CL_CROSS, true)
            match order_edges_by_tail.get(tail_name) {
              Some(list) => list.push(entry)
              None => order_edges_by_tail[tail_name] = [entry]
            }
            rank = rank + 1
          }
        }
      }
      let nlist_order =
        build_graphviz_nlist_order(
          tail_order,
          cluster_meta.cluster_keys,
          cluster_skeleton_creation,
          vnode_creation_by_tail,
        )
      let order_node_order : Map[String, Int] = Map::new()
      let mut order_idx = 0
      for name in nlist_order {
        order_node_order[name] = order_idx
        order_idx = order_idx + 1
      }
      let order_index = build_order_index(order_groups)
      for name, idx in order_index {
        if order_node_order.get(name) is None {
          order_node_order[name] = idx
        }
      }
      let order_edges_out : Array[@cgraph.Edge] = []
      let order_edge_tail_out : Array[String] = []
      let order_edge_head_out : Array[String] = []
      for tail_name in nlist_order {
        let list = match order_edges_by_tail.get(tail_name) {
          Some(value) => value
          None => []
        }
        for entry in list {
          let (edge_tail_name, edge_head_name, penalty, constraint) = entry
          add_order_edge(
            order_graph,
            order_node_map,
            order_edges_out,
            order_edge_tail_out,
            order_edge_head_out,
            edge_tail_name,
            edge_head_name,
            penalty,
            constraint,
          )
        }
      }
      let (parents, children) = build_edge_index_for_order_names(
        order_nodes,
        order_edge_tail_out,
        order_edge_head_out,
        order_ranks,
      )
      let edge_order = collect_edge_order(order_edges_out)
      let ordered = reorder_rank_groups(
        order_rank_keys,
        order_groups,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
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
        Map::new(),
        order_cluster_skeleton,
        cluster_meta.flat_constraints,
      )
      let cluster_order_base : Map[String, Int] = Map::new()
      if order_with_clusters {
        let root_vnodes : Map[String, Bool] = Map::new()
        if order_with_vnodes {
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
            let tail_cluster = match cluster_meta.cluster_keys.get(tail) {
              Some(value) => value
              None => ""
            }
            let head_cluster = match cluster_meta.cluster_keys.get(head) {
              Some(value) => value
              None => ""
            }
            if tail_cluster != head_cluster {
              let vnodes = match vnode_info.edge_vnodes.get(edge_vnode_key(edge)) {
                Some(list) => list
                None => []
              }
              for vnode in vnodes {
                root_vnodes[vnode] = true
              }
            }
            edge_idx = edge_idx + 1
          }
        }
        let root_groups_base : Map[Int, Array[String]] = Map::new()
        for rank in order_rank_keys {
          let names = match order_groups.get(rank) {
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
        let root_order_index = build_order_index(root_groups_base)
        let root_vnodes_by_rank : Map[Int, Array[String]] = Map::new()
        let root_vnode_order_keys : Map[String, Double] = Map::new()
        if order_with_vnodes {
          for rank, names in vnode_info.vnodes_by_rank {
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
        let root_groups =
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
        let root_rank_keys = collect_rank_keys(root_groups)
        let root_ranks = build_node_ranks(root_groups)
        let root_nodes : Array[String] = []
        for rank in root_rank_keys {
          let names = match root_groups.get(rank) {
            Some(list) => list
            None => []
          }
          for name in names {
            root_nodes.push(name)
          }
        }
        let root_graph =
          @cgraph.Graph::new(@cgraph.GraphKind::Directed, name="order_root", strict=false)
        let root_node_map : Map[String, @cgraph.Node] = Map::new()
        for name in root_nodes {
          root_node_map[name] = root_graph.node(name)
        }
        let root_nlist_order : Array[String] = []
        let root_seen : Map[String, Bool] = Map::new()
        for name in nlist_order {
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
        let root_edges_out : Array[@cgraph.Edge] = []
        let root_edge_tail_out : Array[String] = []
        let root_edge_head_out : Array[String] = []
        for tail_name in root_nlist_order {
          let list = match order_edges_by_tail.get(tail_name) {
            Some(value) => value
            None => []
          }
          for entry in list {
            let (edge_tail_name, edge_head_name, penalty, constraint) = entry
            add_order_edge(
              root_graph,
              root_node_map,
              root_edges_out,
              root_edge_tail_out,
              root_edge_head_out,
              edge_tail_name,
              edge_head_name,
              penalty,
              constraint,
            )
          }
        }
        let (root_parents, root_children) = build_edge_index_for_order_names(
          root_nodes,
          root_edge_tail_out,
          root_edge_head_out,
          root_ranks,
        )
        let root_edge_order = collect_edge_order(root_edges_out)
        let ordered_root = reorder_rank_groups(
          root_rank_keys,
          root_groups,
          root_edges_out,
          root_edge_tail_out,
          root_edge_head_out,
          root_parents,
          root_children,
          order_cluster_keys,
          cluster_meta.rank_same_groups,
          cluster_meta.rank_same_order,
          root_edge_order,
          order_node_order,
          order_sizes_out,
          nodesep_pt,
          has_edge_labels,
          port_order_positions,
          port_order_contrib,
          Map::new(),
          order_cluster_skeleton,
          cluster_meta.flat_constraints,
        )
        let order_entries : Array[(String, Int, Int)] = []
        for rank in root_rank_keys {
          let names = match ordered_root.get(rank) {
            Some(list) => list
            None => []
          }
          let mut idx = 0
          for name in names {
            if order_cluster_skeleton.get(name) == Some(true) {
              let cluster = match order_cluster_keys.get(name) {
                Some(value) => value
                None => ""
              }
              if cluster != "" {
                order_entries.push((cluster, rank, idx))
              }
            }
            idx = idx + 1
          }
        }
        if order_entries.length() > 0 {
          order_entries.sort_by((a, b) => {
            let (_cluster_a, rank_a, idx_a) = a
            let (_cluster_b, rank_b, idx_b) = b
            if rank_a < rank_b {
              -1
            } else if rank_a > rank_b {
              1
            } else if idx_a < idx_b {
              -1
            } else if idx_a > idx_b {
              1
            } else {
              0
            }
          })
          let mut base = 0
          for entry in order_entries {
            let (cluster, _rank, _idx) = entry
            if cluster_order_base.get(cluster) is None {
              cluster_order_base[cluster] = base
              base = base + 1
            }
          }
        }
      }
      let cleaned_groups : Map[Int, Array[String]] = Map::new()
      for rank in order_rank_keys {
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
      if order_with_clusters {
        reorder_groups_by_cluster_order(
          cleaned_groups,
          cluster_meta.cluster_keys,
          cluster_order_base,
          node_order,
        )
      }
      cleaned_groups
    } else {
      let (parents, children) =
        build_edge_index_for_order(
          nodes,
          order_edges,
          order_edge_tail,
          order_edge_head,
          ranks,
        )
      reorder_rank_groups(
        rank_keys,
        groups,
        order_edges,
        order_edge_tail,
        order_edge_head,
        parents,
        children,
        cluster_meta.cluster_keys,
        cluster_meta.rank_same_groups,
        cluster_meta.rank_same_order,
        edge_order,
        node_order,
        order_sizes,
        nodesep_pt,
        has_edge_labels,
        port_order_positions,
        port_order_contrib,
        Map::new(),
        cluster_meta.cluster_skeleton,
        cluster_meta.flat_constraints,
      )
    }
  {
    ordered_groups: ordered_groups_internal,
    vnode_info,
    vnode_count,
    order_edges,
    order_edge_tail,
    order_edge_head,
    edge_order,
    edge_cluster_keys,
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
  let vnode_order_keys =
    if use_vnodes_for_xpos {
      build_vnode_order_keys(
        prep.edges,
        rank_data.edge_tail,
        rank_data.edge_head,
        rank_data.edge_reversed,
        rank_data.ranks,
        order_index,
        ordering.vnode_info.edge_vnodes,
        ordering.vnode_info.vnode_ranks,
      )
    } else {
      Map::new()
    }
  let mut has_vnode_order = false
  for _name, _ in vnode_order_keys {
    has_vnode_order = true
    break
  }
  let x_base_sizes = apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    prep.order_sizes,
    prep.rankdir,
    prep.record_orientation,
  )
  let x_order_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let mut x_groups =
    if use_vnodes_for_xpos {
      build_x_groups_with_vnodes(
        ordering.ordered_groups,
        order_index,
        ordering.vnode_info.vnodes_by_rank,
        vnode_order_keys,
      )
    } else {
      ordering.ordered_groups
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
    let skeleton_size = vnode_size_from_widths(0.0, 0.0)
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
          tail,
          head,
          penalty,
          constraint,
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
          add_order_edge(
            order_graph,
            order_node_map,
            order_edges_out,
            order_edge_tail_out,
            order_edge_head_out,
            chain[idx],
            chain[idx + 1],
            penalty,
            constraint,
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
          tail_name,
          head_name,
          CL_CROSS,
          true,
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
    let ordered_groups = reorder_rank_groups(
      order_rank_keys,
      order_groups,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
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
    )
    let cleaned_groups : Map[Int, Array[String]] = Map::new()
    for rank in order_rank_keys {
      let names = match ordered_groups.get(rank) {
        Some(list) => list
        None => []
      }
      let cleaned : Array[String] = []
      for name in names {
        if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
          cleaned.push(name)
        }
      }
      cleaned_groups[rank] = cleaned
    }
    x_groups = cleaned_groups
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
    let tmp_rank_keys = collect_rank_keys(x_groups)
    x_groups = reorder_rank_groups(
      tmp_rank_keys,
      x_groups,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
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
  let y_positions : Map[String, Double] = Map::new()
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
      build_vnode_extra_nodes(ordering.vnode_info.vnode_ranks)
    } else {
      []
    }
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
    x_ranks,
    x_rank_keys,
    x_groups,
    x_sizes,
    prep.output_sizes,
    x_cluster_keys,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    vnode_extra_nodes,
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
    flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
  }
}
