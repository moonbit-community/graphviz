///|
/// Stage C Phase C1 split: class2/order-graph
/// construction helpers for ordering-graph assembly.

///|
fn order_edge_merge_key(
  tail : String,
  head : String,
  constraint : Bool,
  tail_port_order : Double,
  head_port_order : Double,
) -> String {
  "\{tail}|\{head}|\{constraint}|\{tail_port_order.to_string()}|\{head_port_order.to_string()}"
}

///|
/// Graphviz parity: class2 merge_chain coalesces mergeable segments per tail,
/// preserving first-seen sequence while summing xpenalty for duplicate keys.
/// Do not change behavior without updating fixtures/tests.
fn coalesce_order_edges_for_tail(
  entries : Array[(String, String, Int, Bool, Double, Double, Double, Double)],
) -> Array[(String, String, Int, Bool, Double, Double, Double, Double)] {
  let coalesced : Array[(String, String, Int, Bool, Double, Double, Double, Double)] = []
  let key_index : Map[String, Int] = Map::new()
  for entry in entries {
    let (tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
      entry
    let key =
      order_edge_merge_key(
        tail,
        head,
        constraint,
        tail_port_order,
        head_port_order,
      )
    match key_index.get(key) {
      Some(rep_index) => {
        if penalty > 0 {
          let (rep_tail, rep_head, rep_penalty, rep_constraint, rep_tail_port_x, rep_head_port_x, rep_tail_port_order, rep_head_port_order) =
            coalesced[rep_index]
          coalesced[rep_index] = (
            rep_tail,
            rep_head,
            rep_penalty + penalty,
            rep_constraint,
            rep_tail_port_x,
            rep_head_port_x,
            rep_tail_port_order,
            rep_head_port_order,
          )
        } else {
          coalesced.push(
            (tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order),
          )
        }
      }
      None => {
        coalesced.push(
          (tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order),
        )
        key_index[key] = coalesced.length() - 1
      }
    }
  }
  coalesced
}

///|
/// Graphviz parity: class2 merge_chain compacts adjacent mergeable ND_out
/// segments per tail after chain materialization.
/// Do not change behavior without updating fixtures/tests.
fn coalesce_order_edges_by_tail(
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  let coalesced : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  for tail_name, entries in order_edges_by_tail {
    coalesced[tail_name] = coalesce_order_edges_for_tail(entries)
  }
  coalesced
}

///|
/// Graphviz parity: oriented tail endpoint reads prefer edge_tail array and
/// fall back to edge object endpoint when arrays are shorter.
fn edge_tail_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_tail : Array[String],
) -> String {
  if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
    edge.tail().name()
  }
}

///|
/// Graphviz parity: oriented head endpoint reads prefer edge_head array and
/// fall back to edge object endpoint when arrays are shorter.
fn edge_head_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_head : Array[String],
) -> String {
  if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
    edge.head().name()
  }
}

///|
/// Graphviz parity: oriented edge endpoint reads prefer edge_tail/edge_head
/// arrays and fall back to edge object endpoints when arrays are shorter.
/// Do not change behavior without updating fixtures/tests.
fn edge_endpoints_at(
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
/// Graphviz parity: oriented endpoint port lookup follows remapped endpoint
/// names (including reversed directed edges), with optional fallback for
/// callers that require original endpoint defaults.
fn edge_tail_port_for_name(
  edge : @cgraph.Edge,
  tail_name : String,
  fallback_to_original? : Bool = true,
) -> @cgraph.Port? {
  let orig_tail = edge.tail().name()
  let orig_head = edge.head().name()
  if tail_name == orig_tail {
    edge.tail_port()
  } else if tail_name == orig_head {
    edge.head_port()
  } else if fallback_to_original {
    edge.tail_port()
  } else {
    None
  }
}

///|
/// Graphviz parity: oriented endpoint port lookup follows remapped endpoint
/// names (including reversed directed edges), with optional fallback for
/// callers that require original endpoint defaults.
fn edge_head_port_for_name(
  edge : @cgraph.Edge,
  head_name : String,
  fallback_to_original? : Bool = true,
) -> @cgraph.Port? {
  let orig_tail = edge.tail().name()
  let orig_head = edge.head().name()
  if head_name == orig_head {
    edge.head_port()
  } else if head_name == orig_tail {
    edge.tail_port()
  } else if fallback_to_original {
    edge.head_port()
  } else {
    None
  }
}

///|
/// Graphviz parity: nested class2 passes on intercluster multi-edges preserve
/// extra xpenalty on vnode-tail segments in clustered ReMincross rematerialize.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_bonus(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_keys : Map[String, String],
) -> Map[String, Int] {
  let count_by_key : Map[String, Int] = Map::new()
  for tail_name in creation_order {
    let indices = match edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
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
      let tail_cluster =
        if order_with_clusters {
          cluster_key_or_empty(cluster_keys, tail)
        } else {
          ""
        }
      let head_cluster =
        if order_with_clusters {
          cluster_key_or_empty(cluster_keys, head)
        } else {
          ""
        }
      let intercluster =
        order_with_clusters && tail_cluster != head_cluster &&
        (tail_cluster != "" || head_cluster != "")
      if !intercluster || !@dot_shared.edge_is_constraint(edge) || @dot_shared.edge_xpenalty(edge) <= 0 {
        continue
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
          match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
            Some(list) => list
            None => []
          }
        } else {
          []
        }
      let chain : Array[String] = []
      let (chain_tail, chain_head) =
        if tail_rank <= head_rank { (tail, head) } else { (head, tail) }
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
        if t != h && t.has_prefix(EDGE_VNODE_PREFIX) {
          let seg_tail_order =
            if t == tail && chain_tail == tail {
              tail_port_order
            } else if t == head && chain_head == head {
              head_port_order
            } else {
              0.0
            }
          let seg_head_order =
            if h == head && chain_head == head {
              head_port_order
            } else if h == tail && chain_tail == tail {
              tail_port_order
            } else {
              0.0
            }
          let key =
            order_edge_merge_key(
              t,
              h,
              true,
              seg_tail_order,
              seg_head_order,
            )
          let prev = match count_by_key.get(key) {
            Some(value) => value
            None => 0
          }
          count_by_key[key] = prev + 1
        }
        i = i + 1
      }
    }
  }
  let bonus_by_key : Map[String, Int] = Map::new()
  for key, count in count_by_key {
    if count > 1 {
      bonus_by_key[key] = count - 1
    }
  }
  bonus_by_key
}

///|
/// Graphviz parity: order graph starts from measured node sizes and augments
/// with vnode virtual sizes when vnode ordering is enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_sizes_for_order_graph(
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
/// Graphviz parity: class2 cluster skeleton nodes use virtual_node() defaults
/// and are appended into every covered rank in cluster order.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_range(
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
priv struct OrderGraphAndNodes {
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
}

///|
/// Graphviz parity: order graph node table is built by creating each name in
/// order_nodes sequence, matching agnode creation iteration order.
/// Do not change behavior without updating fixtures/tests.
fn build_order_graph_and_nodes(
  graph_name : String,
  order_nodes : Array[String],
) -> OrderGraphAndNodes {
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
  { order_graph, order_node_map }
}

///|
/// Graphviz parity: edge arrays are materialized from per-tail lists in exact
/// nlist tail iteration order (shared root/remincross order-graph builder).
/// Do not change behavior without updating fixtures/tests.
priv struct OrderEdgeArrays {
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
/// Graphviz parity: edge arrays are materialized from per-tail lists in exact
/// nlist tail iteration order (shared root/remincross order-graph builder).
/// Do not change behavior without updating fixtures/tests.
fn collect_order_edges_for_tails(
  tail_sequence : Array[String],
  edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
) -> OrderEdgeArrays {
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
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
  {
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}

///|
/// Graphviz parity: parent/child adjacency maps and edge-order indices are
/// derived from the exact materialized edge arrays in current order graph.
/// Do not change behavior without updating fixtures/tests.
priv struct EdgeIndicesAndOrder {
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  edge_order : Map[String, Int]
}

///|
/// Graphviz parity: parent/child adjacency maps and edge-order indices are
/// derived from the exact materialized edge arrays in current order graph.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_indices_and_order(
  order_nodes : Array[String],
  edge_tail_out : Array[String],
  edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  edges_out : Array[@cgraph.Edge],
) -> EdgeIndicesAndOrder {
  let edge_index_data =
    build_edge_index_for_names(
      order_nodes,
      edge_tail_out,
      edge_head_out,
      order_ranks,
    )
  let parents = edge_index_data.parents
  let children = edge_index_data.children
  let edge_order = collect_edge_order(edges_out)
  { parents, children, edge_order }
}

///|
/// Graphviz parity: transpose seed maps include all seeded nodes and only
/// positive-penalty constrained edges that cross ranks.
/// Do not change behavior without updating fixtures/tests.
priv struct TransposeSeedMapsOutput {
  edge_penalty : Array[Int]
  edge_in : Map[String, Array[Int]]
  edge_out : Map[String, Array[Int]]
}

///|
/// Graphviz parity: transpose seed maps include all seeded nodes and only
/// positive-penalty constrained edges that cross ranks.
/// Do not change behavior without updating fixtures/tests.
fn build_transpose_seed_maps(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
) -> TransposeSeedMapsOutput {
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
    let penalty = @dot_shared.edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if penalty <= 0 || !@dot_shared.edge_is_constraint(edge) {
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
  { edge_penalty, edge_in, edge_out }
}
