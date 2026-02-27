///|
/// Stage C Phase C1 split: class2/order-graph
/// construction helpers for ordering-graph assembly.

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
/// Graphviz parity: nested class2 passes on intercluster multi-edges preserve
/// extra xpenalty on vnode-tail segments in clustered ReMincross rematerialize.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_vnode_tail_bonus(
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
      let tail =
        if idx < edge_tail.length() { edge_tail[idx] } else { edge.tail().name() }
      let head =
        if idx < edge_head.length() { edge_head[idx] } else { edge.head().name() }
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
          match edge_vnodes.get(edge_vnode_key(edge)) {
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
/// Graphviz parity: apply nested intercluster merge-chain bonus to the first
/// representative vnode-tail segment for each merge key.
/// Do not change behavior without updating fixtures/tests.
fn apply_intercluster_vnode_tail_bonus(
  order_edges_by_tail_coalesced : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  bonus_by_key : Map[String, Int],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  if bonus_by_key.length() == 0 {
    return order_edges_by_tail_coalesced
  }
  let remaining_bonus : Map[String, Int] = Map::new()
  for key, value in bonus_by_key {
    remaining_bonus[key] = value
  }
  let adjusted : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  for tail_name, entries in order_edges_by_tail_coalesced {
    let adjusted_entries : Array[(String, String, Int, Bool, Double, Double, Double, Double)] = []
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
      let mut adjusted_penalty = penalty
      match remaining_bonus.get(key) {
        Some(extra) =>
          if extra > 0 {
            adjusted_penalty = adjusted_penalty + extra
            remaining_bonus[key] = 0
          }
        None => ()
      }
      adjusted_entries.push(
        (tail, head, adjusted_penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order),
      )
    }
    adjusted[tail_name] = adjusted_entries
  }
  adjusted
}

///|
/// Graphviz parity: edge creation replay follows per-tail ND_out order after
/// class2 merge-chain coalescing in rematerialized clustered passes.
/// Do not change behavior without updating fixtures/tests.
fn rebuild_edge_creation_from_tail_order(
  tail_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Array[(String, String)] {
  let edge_creation : Array[(String, String)] = []
  for tail_name in tail_order {
    let entries = match order_edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for entry in entries {
      let (tail, head, _, _, _, _, _, _) = entry
      edge_creation.push((tail, head))
    }
  }
  edge_creation
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
/// fills with nlist/order_groups/base order; rank=same ND_order normalization
/// is applied only on clustered reorder paths.
/// Do not change behavior without updating fixtures/tests.
fn build_order_node_order_for_build_ranks(
  gdnlist_order : Array[String],
  nlist_order : Array[String],
  node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  has_clusters : Bool,
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
  if has_clusters {
    // Graphviz parity: non-cluster root reorder keeps GD_nlist-derived order
    // (world.gv) and does not re-normalize ND_order by rank=same declaration.
    apply_rank_same_order_to_node_order(
      order_node_order,
      rank_same_groups,
      rank_same_order,
      port_edge_nodes,
    )
  }
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
    }
    gdnlist_idx = gdnlist_idx + 1
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
/// Graphviz parity: incoming-only unconstrained handling uses non-self edge
/// presence and first incoming edge order from the unmapped order graph.
/// Do not change behavior without updating fixtures/tests.
fn build_node_in_out_presence_and_first_in_order(
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (Map[String, Bool], Map[String, Bool], Map[String, Int]) {
  let node_has_out : Map[String, Bool] = Map::new()
  let node_has_in : Map[String, Bool] = Map::new()
  let first_in_order : Map[String, Int] = Map::new()
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      node_has_out[tail] = true
      node_has_in[head] = true
      if first_in_order.get(head) is None {
        first_in_order[head] = edge_idx
      }
    }
    edge_idx = edge_idx + 1
  }
  (node_has_out, node_has_in, first_in_order)
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
/// Graphviz parity: incoming-only unconstrained local nodes are reassigned by
/// first incoming edge order while preserving their sorted order slots.
/// Do not change behavior without updating fixtures/tests.
fn reorder_incoming_only_unconstrained_local_nodes(
  local_creation : Map[String, Array[String]],
  unconstrained_nodes : Map[String, Bool],
  rank_same_groups : Map[String, Int],
  node_has_out : Map[String, Bool],
  node_has_in : Map[String, Bool],
  first_in_order : Map[String, Int],
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
    let desired = unconstrained_local.copy()
    if desired.length() > 1 {
      let local_index : Map[String, Int] = Map::new()
      for idx, name in unconstrained_local {
        local_index[name] = idx
      }
      desired.sort_by((a, b) => {
        let a_in = match first_in_order.get(a) {
          Some(value) => value
          None => 0x7fffffff
        }
        let b_in = match first_in_order.get(b) {
          Some(value) => value
          None => 0x7fffffff
        }
        if a_in < b_in {
          -1
        } else if a_in > b_in {
          1
        } else {
          let a_idx = match local_index.get(a) {
            Some(value) => value
            None => 0
          }
          let b_idx = match local_index.get(b) {
            Some(value) => value
            None => 0
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
