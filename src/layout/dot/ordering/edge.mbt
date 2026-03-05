///|
priv enum OrderingMode {
  Out
  In
}

///|
fn parse_ordering_mode(value : String) -> OrderingMode? {
  match value.to_lower() {
    "out" => Some(OrderingMode::Out)
    "in" => Some(OrderingMode::In)
    _ => None
  }
}

///|
pub fn edge_tail_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_tail : Array[String],
) -> String {
  if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
    edge.tail().name()
  }
}

///|
pub fn edge_head_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_head : Array[String],
) -> String {
  if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
    edge.head().name()
  }
}

///|
pub fn edge_endpoints_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (String, String) {
  let tail = edge_tail_at(edge, edge_idx, edge_tail)
  let head = edge_head_at(edge, edge_idx, edge_head)
  (tail, head)
}

///|
pub(all) struct DedupOrderingEdgesOutput {
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
}

///|
pub fn dedup_ordering_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> DedupOrderingEdgesOutput {
  let seen : Map[String, Bool] = Map::new()
  let out_edges : Array[@cgraph.Edge] = []
  let out_tail : Array[String] = []
  let out_head : Array[String] = []
  for i in 0..<edges.length() {
    let (tail, head) =
      edge_endpoints_at(
        edges[i],
        i,
        edge_tail,
        edge_head,
      )
    let key = "\{tail}|\{head}"
    if seen.get(key) is Some(_) {
      continue
    }
    seen[key] = true
    out_edges.push(edges[i])
    out_tail.push(tail)
    out_head.push(head)
  }
  { order_edges: out_edges, order_edge_tail: out_tail, order_edge_head: out_head }
}

///|
pub(all) struct FlatConstraintsOutput {
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
pub fn build_flat_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
) -> FlatConstraintsOutput {
  let flat_constraints : Map[String, Bool] = Map::new()
  let out_edges : Map[String, Array[(Int, Int)]] = Map::new()
  let in_edges : Map[String, Array[(Int, Int)]] = Map::new()
  for node in nodes {
    let name = node.name()
    out_edges[name] = []
    in_edges[name] = []
  }
  for i in 0..<edges.length() {
    let (tail, head) =
      edge_endpoints_at(
        edges[i],
        i,
        edge_tail,
        edge_head,
      )
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster != head_cluster {
      continue
    }
    let edge_id = edges[i].id()
    match out_edges.get(tail) {
      Some(list) => list.push((edge_id, i))
      None => out_edges[tail] = [(edge_id, i)]
    }
    match in_edges.get(head) {
      Some(list) => list.push((edge_id, i))
      None => in_edges[head] = [(edge_id, i)]
    }
  }
  let apply_ordering = (name : String, mode : OrderingMode) => {
    let list = match mode {
      OrderingMode::Out => {
        match out_edges.get(name) {
          Some(items) => items
          None => []
        }
      }
      OrderingMode::In => {
        match in_edges.get(name) {
          Some(items) => items
          None => []
        }
      }
    }
    if list.length() <= 1 {
      return ()
    }
    let sorted = list.copy()
    sorted.sort_by((a, b) => {
      let (a_id, _a_idx) = a
      let (b_id, _b_idx) = b
      if a_id < b_id {
        -1
      } else if a_id > b_id {
        1
      } else {
        0
      }
    })
    let mut idx = 1
    while idx < sorted.length() {
      let (_prev_id, prev_idx) = sorted[idx - 1]
      let (_curr_id, curr_idx) = sorted[idx]
      let (prev_tail, prev_head) =
        edge_endpoints_at(
          edges[prev_idx],
          prev_idx,
          edge_tail,
          edge_head,
        )
      let (curr_tail, curr_head) =
        edge_endpoints_at(
          edges[curr_idx],
          curr_idx,
          edge_tail,
          edge_head,
        )
      let left = match mode {
        OrderingMode::Out => prev_head
        OrderingMode::In => prev_tail
      }
      let right = match mode {
        OrderingMode::Out => curr_head
        OrderingMode::In => curr_tail
      }
      if left != right {
        flat_constraints["\{left}|\{right}"] = true
      }
      idx = idx + 1
    }
  }
  let graph_ordering = match graph.get_attr("ordering") {
    Some(value) => parse_ordering_mode(value)
    None => None
  }
  let mut ordering_set = false
  match graph_ordering {
    Some(mode) => {
      ordering_set = true
      for node in nodes {
        apply_ordering(node.name(), mode)
      }
    }
    None => {
      for node in nodes {
        match node.get_attr("ordering") {
          Some(value) =>
            match parse_ordering_mode(value) {
              Some(mode) => {
                ordering_set = true
                apply_ordering(node.name(), mode)
              }
              None => ()
            }
          None => ()
        }
      }
    }
  }
  { flat_constraints, ordering_set }
}

///|
pub(all) struct EdgeIndexData {
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
}

///|
pub fn build_edge_index_for_order(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> EdgeIndexData {
  let node_names : Array[String] = []
  for node in nodes {
    node_names.push(node.name())
  }
  build_edge_index_impl(
    node_names,
    edge_tail,
    edge_head,
    ranks,
    edges.length(),
  )
}

///|
fn build_edge_index_impl(
  node_names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_count : Int,
) -> EdgeIndexData {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for name in node_names {
    parents[name] = []
    children[name] = []
  }
  for edge_idx in 0..<edge_count {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    match parents.get(head) {
      Some(list) => list.push(tail)
      None => parents[head] = [tail]
    }
    match children.get(tail) {
      Some(list) => list.push(head)
      None => children[tail] = [head]
    }
  }
  { parents, children }
}

///|
pub fn build_edge_index_for_names(
  node_names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> EdgeIndexData {
  build_edge_index_impl(
    node_names,
    edge_tail,
    edge_head,
    ranks,
    edge_tail.length(),
  )
}

///|
pub fn add_order_edge(
  graph : @cgraph.Graph,
  node_map : Map[String, @cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  tail_name : String,
  head_name : String,
  xpenalty : Int,
  constraint : Bool,
  tail_port_x : Double,
  head_port_x : Double,
  tail_port_order : Double,
  head_port_order : Double,
) -> Unit {
  if tail_name == head_name {
    return ()
  }
  match node_map.get(tail_name) {
    Some(tail_node) =>
      match node_map.get(head_name) {
        Some(head_node) => {
          let edge = graph.edge(tail_node, head_node)
          edge.set_attr("xpenalty", "\{xpenalty}")
          if !constraint {
            edge.set_attr("constraint", "false")
          }
          edges.push(edge)
          edge_tail.push(tail_name)
          edge_head.push(head_name)
          edge_tail_port_x.push(tail_port_x)
          edge_head_port_x.push(head_port_x)
          edge_tail_port_order.push(tail_port_order)
          edge_head_port_order.push(head_port_order)
        }
        None => ()
      }
    None => ()
  }
}

/// Graphviz parity: build order-graph edges in class2 tail/edge iteration order.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct OrderEdgesByTailOutput {
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  vnode_creation_by_tail : Map[String, Array[String]]
  edge_creation_order : Array[(String, String)]
}

///|
/// Graphviz parity: build order-graph edges in class2 tail/edge iteration order.
/// Do not change behavior without updating fixtures/tests.
pub fn build_order_edges_by_tail(
  tail_order : Array[String],
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
  map_clusters : Bool,
  map_intercluster : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index? : Map[String, Int] = Map::new(),
) -> OrderEdgesByTailOutput {
  let out : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  let vnode_seen : Map[String, Bool] = Map::new()
  let vnode_creation_by_tail : Map[String, Array[String]] = Map::new()
  let edge_creation : Array[(String, String)] = []
  let use_mapping = order_with_clusters && map_clusters
  let cluster_order_index_local : Map[String, Int] = Map::new()
  if order_with_clusters && cluster_order_index.length() > 0 {
    for cluster, idx in cluster_order_index {
      cluster_order_index_local[cluster] = idx
    }
  }
  for tail_name in tail_order {
    let created_for_tail : Array[String] = []
    let indices_raw = match edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    let indices =
      if !order_with_clusters || cluster_order_index_local.length() == 0 ||
        indices_raw.length() <= 1 {
        indices_raw
      } else {
        let tail_cluster_name = match cluster_keys.get(tail_name) {
          Some(value) => value
          None => ""
        }
        let tail_cluster_rank = match cluster_order_index_local.get(tail_cluster_name) {
          Some(value) => value
          None => -1
        }
        let head_cluster_default = cluster_order_index_local.length() + 1
        let keyed : Array[(Int, Int, Int, Int, String)] = []
        let mut original_pos = 0
        for idx in indices_raw {
          let edge = edges[idx]
          let (tail, head) =
            edge_endpoints_at(
              edge,
              idx,
              edge_tail,
              edge_head,
            )
          let tail_cluster = match cluster_keys.get(tail) {
            Some(value) => value
            None => ""
          }
          let head_cluster = match cluster_keys.get(head) {
            Some(value) => value
            None => ""
          }
          let same_cluster =
            tail_cluster != "" && head_cluster != "" && tail_cluster == head_cluster
          let cluster_rank = match cluster_order_index_local.get(head_cluster) {
            Some(value) => value
            None => head_cluster_default
          }
          keyed.push(
            (
              idx,
              if same_cluster { 0 } else { 1 },
              cluster_rank,
              original_pos,
              head_cluster,
            ),
          )
          original_pos = original_pos + 1
        }
        if keyed.length() > 1 {
          keyed.sort_by((a, b) => {
            let (_idx_a, same_a, rank_a, pos_a, _cluster_a) = a
            let (_idx_b, same_b, rank_b, pos_b, _cluster_b) = b
            if same_a < same_b {
              -1
            } else if same_a > same_b {
              1
            } else if rank_a < rank_b {
              -1
            } else if rank_a > rank_b {
              1
            } else if pos_a < pos_b {
              -1
            } else if pos_a > pos_b {
              1
            } else {
              0
            }
          })
        }
        // Graphviz parity: when a tail points into later clusters, agfstout
        // starts each cluster bucket from its rankleader edge, then walks the
        // remaining edges in original order.
        let keyed_rotated : Array[(Int, Int, Int, Int, String)] = []
        if tail_cluster_name != "" && tail_cluster_rank >= 0 && keyed.length() > 1 {
          let leader_entries : Array[(Int, Int, Int, Int, String)] = []
          let body_entries : Array[(Int, Int, Int, Int, String)] = []
          let mut insert_pos = -1
          let mut i = 0
          while i < keyed.length() {
            let (_idx_i, same_i, rank_i, _pos_i, cluster_i) = keyed[i]
            let mut j = i + 1
            while j < keyed.length() {
              let (_idx_j, same_j, rank_j, _pos_j, cluster_j) = keyed[j]
              if same_j != same_i || rank_j != rank_i || cluster_j != cluster_i {
                break
              }
              j = j + 1
            }
            let segment_len = j - i
            let use_right_cluster_leader =
              same_i == 1 && cluster_i != "" && rank_i > tail_cluster_rank &&
              segment_len > 1
            if use_right_cluster_leader {
              if insert_pos < 0 {
                insert_pos = body_entries.length()
              }
              let mut k = i
              while k + 1 < j {
                body_entries.push(keyed[k])
                k = k + 1
              }
              leader_entries.push(keyed[j - 1])
            } else {
              let mut k = i
              while k < j {
                body_entries.push(keyed[k])
                k = k + 1
              }
            }
            i = j
          }
          if leader_entries.length() > 0 {
            let split =
              if insert_pos >= 0 { insert_pos } else { body_entries.length() }
            let mut i = 0
            while i < split {
              keyed_rotated.push(body_entries[i])
              i = i + 1
            }
            for entry in leader_entries {
              keyed_rotated.push(entry)
            }
            i = split
            while i < body_entries.length() {
              keyed_rotated.push(body_entries[i])
              i = i + 1
            }
          } else {
            for entry in keyed {
              keyed_rotated.push(entry)
            }
          }
        } else {
          for entry in keyed {
            keyed_rotated.push(entry)
          }
        }
        let sorted_indices : Array[Int] = []
        for entry in keyed_rotated {
          let (idx, _same, _rank, _pos, _cluster) = entry
          sorted_indices.push(idx)
        }
        sorted_indices
      }
    for idx in indices {
      let edge = edges[idx]
      let (tail, head) =
        edge_endpoints_at(
          edge,
          idx,
          edge_tail,
          edge_head,
        )
      let tail_cluster =
        if order_with_clusters {
        match cluster_keys.get(tail) {
          Some(value) => value
          None => ""
        }
      } else {
        ""
      }
      let head_cluster =
        if order_with_clusters {
        match cluster_keys.get(head) {
          Some(value) => value
          None => ""
        }
      } else {
        ""
      }
      if use_mapping && tail_cluster != "" && tail_cluster == head_cluster {
        continue
      }
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => 0
      }
      if tail_rank == head_rank {
        continue
      }
      // Graphviz parity: intercluster edges map to cluster rankleaders
      // in ordering (class2/interclrep).
      let intercluster =
        order_with_clusters && tail_cluster != head_cluster &&
        (tail_cluster != "" || head_cluster != "")
      let map_edge = use_mapping || (map_intercluster && intercluster)
      let mapped_tail =
        if map_edge && tail_cluster != "" {
        @clustering.cluster_skeleton_name(tail_cluster, tail_rank)
      } else {
        tail
      }
      let mapped_head =
        if map_edge && head_cluster != "" {
        @clustering.cluster_skeleton_name(head_cluster, head_rank)
      } else {
        head
      }
      let penalty = @shared.edge_xpenalty(edge)
      let constraint = @shared.edge_is_constraint(edge)
      let tail_port_x =
        if idx < edge_tail_port_x.length() { edge_tail_port_x[idx] } else {
          0.0
        }
      let head_port_x =
        if idx < edge_head_port_x.length() { edge_head_port_x[idx] } else {
          0.0
        }
      let tail_port_order =
        if idx < edge_tail_port_order.length() { edge_tail_port_order[idx] } else {
          0.5
        }
      let head_port_order =
        if idx < edge_head_port_order.length() { edge_head_port_order[idx] } else {
          0.5
        }
      let vnodes =
        if order_with_vnodes {
        match edge_vnodes.get(@shared.edge_vnode_key(edge)) {
          Some(list) => list
          None => []
        }
      } else {
        []
      }
      if order_with_vnodes && vnodes.length() > 0 {
        for vnode in vnodes {
          if vnode_seen.get(vnode) is None {
            vnode_seen[vnode] = true
            created_for_tail.push(vnode)
          }
        }
      }
      let chain : Array[String] = []
      let (chain_tail, chain_head) =
        if tail_rank <= head_rank { (mapped_tail, mapped_head) } else {
          (mapped_head, mapped_tail)
        }
      chain.push(chain_tail)
      if order_with_vnodes && vnodes.length() > 0 {
        for vnode in vnodes {
          chain.push(vnode)
        }
      }
      chain.push(chain_head)
      let mut i = 0
      while i + 1 < chain.length() {
        let t = chain[i]
        let h = chain[i + 1]
        if t != h {
          let seg_tail_port =
            if t == tail && mapped_tail == tail {
              tail_port_x
            } else if t == head && mapped_head == head {
              head_port_x
            } else {
              0.5
            }
          let seg_head_port =
            if h == head && mapped_head == head {
              head_port_x
            } else if h == tail && mapped_tail == tail {
              tail_port_x
            } else {
              0.5
            }
          let seg_tail_order =
            if t == tail && mapped_tail == tail {
              tail_port_order
            } else if t == head && mapped_head == head {
              head_port_order
            } else {
              0.0
            }
          let seg_head_order =
            if h == head && mapped_head == head {
              head_port_order
            } else if h == tail && mapped_tail == tail {
              tail_port_order
            } else {
              0.0
            }
          match out.get(t) {
            Some(list) =>
              list.push(
                (t, h, penalty, constraint, seg_tail_port, seg_head_port, seg_tail_order, seg_head_order),
              )
            None =>
              out[t] = [
                (t, h, penalty, constraint, seg_tail_port, seg_head_port, seg_tail_order, seg_head_order),
              ]
          }
          edge_creation.push((t, h))
        }
        i = i + 1
      }
    }
    if created_for_tail.length() > 0 {
      vnode_creation_by_tail[tail_name] = created_for_tail
    }
  }
  {
    order_edges_by_tail: out,
    vnode_creation_by_tail,
    edge_creation_order: edge_creation,
  }
}

///|
pub fn build_edge_index_with_vnodes(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> EdgeIndexData {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    parents[name] = []
    children[name] = []
  }
  for vnode, _ in vnode_ranks {
    parents[vnode] = []
    children[vnode] = []
  }
  for edge_idx in 0..<edges.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    let (low, high) = if tail_rank <= head_rank { (tail, head) } else { (head, tail) }
    let vnodes = match edge_vnodes.get(@shared.edge_vnode_key(edges[edge_idx])) {
      Some(list) => list
      None => []
    }
    let mut prev = low
    for vnode in vnodes {
      match parents.get(vnode) {
        Some(list) => list.push(prev)
        None => parents[vnode] = [prev]
      }
      match children.get(prev) {
        Some(list) => list.push(vnode)
        None => children[prev] = [vnode]
      }
      prev = vnode
    }
    match parents.get(high) {
      Some(list) => list.push(prev)
      None => parents[high] = [prev]
    }
    match children.get(prev) {
      Some(list) => list.push(high)
      None => children[prev] = [high]
    }
  }
  { parents, children }
}
