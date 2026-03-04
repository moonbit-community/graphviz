///|
/// Ordering domain: order-graph construction and materialization helpers.

///|
/// Graphviz parity: cluster membership lookup treats missing keys as
/// non-cluster entries across class2 preprocessing passes.
/// Do not change behavior without updating fixtures/tests.
pub fn cluster_key_or_empty(
  cluster_keys : Map[String, String],
  name : String,
) -> String {
  match cluster_keys.get(name) {
    Some(value) => value
    None => ""
  }
}

///|
/// Graphviz parity: class2 order_creation keeps first-seen insertion order,
/// suppressing duplicates across skeleton, real-node, and vnode phases.
/// Do not change behavior without updating fixtures/tests.
pub fn append_creation_name(
  order_creation : Array[String],
  order_seen : Map[String, Bool],
  name : String,
) -> Unit {
  if order_seen.get(name) is None {
    order_seen[name] = true
    order_creation.push(name)
  }
}

///|
/// Graphviz parity: when GD_flip is true, decompose nlist reverses node order
/// inside each cluster while preserving cluster membership positions.
/// Do not change behavior without updating fixtures/tests.
pub fn adjust_nlist_order_for_flip(
  nlist_order_raw : Array[String],
  graphviz_flip : Bool,
  has_clusters : Bool,
  cluster_keys : Map[String, String],
) -> Array[String] {
  if !(graphviz_flip && has_clusters) {
    return nlist_order_raw
  }
  // Graphviz parity: cluster flip preprocessing first buckets nlist nodes by
  // cluster key while skipping non-cluster entries.
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  for name in nlist_order_raw {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    match cluster_nodes.get(cluster) {
      Some(list) => list.push(name)
      None => cluster_nodes[cluster] = [name]
    }
  }
  // Graphviz parity: cluster flip precomputes reversed per-cluster node lists
  // and zeroed consumption indices before reconstructing adjusted nlist order.
  let cluster_reversed : Map[String, Array[String]] = Map::new()
  let cluster_index : Map[String, Int] = Map::new()
  for cluster, list in cluster_nodes {
    // Graphviz parity: cluster flip uses explicit reverse traversal to
    // construct per-cluster replacement lists in reverse local order.
    let reversed : Array[String] = []
    let mut idx = list.length()
    while idx > 0 {
      idx = idx - 1
      reversed.push(list[idx])
    }
    cluster_reversed[cluster] = reversed
    cluster_index[cluster] = 0
  }
  // Graphviz parity: reconstruction preserves non-cluster names and replaces
  // cluster names by sequential consumption from reversed buckets.
  let adjusted : Array[String] = []
  for name in nlist_order_raw {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      adjusted.push(name)
    } else {
      // Graphviz parity: consume one reversed member per cluster occurrence,
      // falling back to original name on index overflow.
      let idx = match cluster_index.get(cluster) {
        Some(value) => value
        None => 0
      }
      let list = match cluster_reversed.get(cluster) {
        Some(value) => value
        None => []
      }
      let resolved = if idx < list.length() { list[idx] } else { name }
      cluster_index[cluster] = idx + 1
      adjusted.push(
        resolved,
      )
    }
  }
  adjusted
}

///|
/// Graphviz parity: edge creation sequence concatenates skeleton links before
/// regular order-edge links to preserve AGSEQ head-neighbor replay.
/// Do not change behavior without updating fixtures/tests.
pub fn merge_edge_creation_sequences(
  leading : Array[(String, String)],
  trailing : Array[(String, String)],
) -> Array[(String, String)] {
  let merged : Array[(String, String)] = []
  for edge in leading {
    merged.push(edge)
  }
  for edge in trailing {
    merged.push(edge)
  }
  merged
}

///|
/// Graphviz parity: class2 flat-rank preprocessing treats unknown node ranks
/// as 0 when evaluating same-rank non-self edge constraints.
/// Do not change behavior without updating fixtures/tests.
pub fn flat_constraint_rank_or_zero(
  ranks : Map[String, Int],
  name : String,
) -> Int {
  match ranks.get(name) {
    Some(value) => value
    None => 0
  }
}

///|
pub fn order_edge_merge_key(
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
pub fn coalesce_order_edges_by_tail(
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
/// Graphviz parity: oriented endpoint names represent a reversed edge when
/// they swap the original tail/head names.
pub fn edge_orientation_is_reversed(
  edge : @cgraph.Edge,
  tail_name : String,
  head_name : String,
) -> Bool {
  tail_name == edge.head().name() &&
  head_name == edge.tail().name()
}

///|
/// Graphviz parity: oriented endpoint port lookup follows remapped endpoint
/// names (including reversed directed edges), with optional fallback for
/// callers that require original endpoint defaults.
pub fn edge_tail_port_for_name(
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
pub fn edge_head_port_for_name(
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
pub fn collect_intercluster_bonus(
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
      if !intercluster || !@shared.edge_is_constraint(edge) || @shared.edge_xpenalty(edge) <= 0 {
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
          match edge_vnodes.get(@shared.edge_vnode_key(edge)) {
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
pub fn build_sizes_for_order_graph(
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
/// Graphviz parity: clustered pre-root seed payload keeps grouped nodes,
/// order-graph sizes, and cluster metadata maps bundled for root/cluster
/// ordering preparation.
pub(all) struct OrderSeedGroupsOutput {
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
}

///|
/// Graphviz parity: order-stage seed input keeps vnode and cluster metadata
/// snapshots unchanged before grouped seed expansion.
pub(all) struct OrderSeedGroupsInputs {
  ordering_groups_base : Map[Int, Array[String]]
  base_order_index : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_order : Array[String]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  vnode_clusters : Map[String, String]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_order_keys_for_ordering : Map[String, Double]
  order_sizes : Map[String, NodeSize]
  vnode_sizes : Map[String, NodeSize]
  skeleton_size : NodeSize
}

///|
/// Graphviz parity: order-stage groups clone rank groups, optionally merge edge
/// vnodes, and install cluster skeleton nodes with virtual-node defaults.
/// Do not change behavior without updating fixtures/tests.
pub fn build_order_seed_groups(
  inputs : OrderSeedGroupsInputs,
) -> OrderSeedGroupsOutput {
  let order_groups =
    if inputs.order_with_vnodes {
      build_x_groups_with_vnodes(
        inputs.ordering_groups_base,
        inputs.base_order_index,
        inputs.vnodes_by_rank,
        inputs.vnode_order_keys_for_ordering,
      )
    } else {
      let out : Map[Int, Array[String]] = Map::new()
      for rank, names in inputs.ordering_groups_base {
        out[rank] = names.copy()
      }
      out
    }
  let order_sizes_out =
    build_sizes_for_order_graph(
      inputs.order_sizes,
      inputs.order_with_vnodes,
      inputs.vnode_sizes,
    )
  // Graphviz parity: order graph cluster-key map starts from real-node keys and
  // appends vnode cluster keys only when vnode ordering is enabled.
  let order_cluster_keys : Map[String, String] = Map::new()
  for name, key in inputs.cluster_keys {
    order_cluster_keys[name] = key
  }
  if inputs.order_with_vnodes {
    for name, key in inputs.vnode_clusters {
      order_cluster_keys[name] = key
    }
  }
  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  if inputs.order_with_clusters {
    let cluster_seen : Map[String, Bool] = Map::new()
    for cluster in inputs.cluster_order {
      match inputs.cluster_min_rank.get(cluster) {
        Some(min_rank) => {
          let max_rank = match inputs.cluster_max_rank.get(cluster) {
            Some(value) => value
            None => min_rank
          }
          append_cluster_skeleton_range(
            cluster,
            min_rank,
            max_rank,
            order_cluster_keys,
            order_cluster_skeleton,
            order_sizes_out,
            order_groups,
            inputs.skeleton_size,
          )
          cluster_seen[cluster] = true
        }
        None => ()
      }
    }
    for cluster, min_rank in inputs.cluster_min_rank {
      if cluster_seen.get(cluster) is Some(_) {
        continue
      }
      let max_rank = match inputs.cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      append_cluster_skeleton_range(
        cluster,
        min_rank,
        max_rank,
        order_cluster_keys,
        order_cluster_skeleton,
        order_sizes_out,
        order_groups,
        inputs.skeleton_size,
      )
    }
  }
  {
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
  }
}

///|
/// Graphviz parity: class2 cluster skeleton nodes use virtual_node() defaults
/// and are appended into every covered rank in cluster order.
/// Do not change behavior without updating fixtures/tests.
pub fn append_cluster_skeleton_range(
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
pub fn build_order_nodes_from_groups(
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

///| Graphviz parity: clustered pre-root reorder context keeps build_ranks seed
/// ranks, order-graph snapshots, and node-order seed maps unchanged.
pub(all) struct OrderReorderContext {
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_nodes : Array[String]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  creation_order : Array[String]
  order_node_order : Map[String, Int]
}

///|
/// Graphviz parity: reorder-context seed input keeps GD_nlist/nlist snapshots,
/// rank=same metadata, and base order maps unchanged before order-graph build.
pub(all) struct OrderReorderContextInputs {
  order_groups : Map[Int, Array[String]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  node_order : Map[String, Int]
  real_nodes : Map[String, Bool]
  has_clusters : Bool
  base_order_index : Map[String, Int]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  port_edge_nodes : Map[String, Bool]
}

///|
/// Graphviz parity: order-graph rebuild uses GD_nlist-derived creation order
/// and build_ranks seed order before mapped/unmapped edge materialization.
/// Do not change behavior without updating fixtures/tests.
pub fn build_order_reorder_context(
  inputs : OrderReorderContextInputs,
) -> OrderReorderContext {
  let order_rank_keys = collect_rank_keys(inputs.order_groups)
  let order_ranks = build_node_ranks(inputs.order_groups)
  let order_nodes =
    build_order_nodes_from_groups(inputs.order_groups, order_rank_keys)
  let order_graph_output =
    build_order_graph_and_nodes("order_graph", order_nodes)
  let order_graph = order_graph_output.order_graph
  let order_node_map = order_graph_output.order_node_map
  let order_graph_unmapped_output =
    build_order_graph_and_nodes("order_graph_unmapped", order_nodes)
  let order_graph_unmapped = order_graph_unmapped_output.order_graph
  let order_node_map_unmapped = order_graph_unmapped_output.order_node_map
  let creation_order : Array[String] = []
  let mut creation_idx = inputs.nlist_order.length()
  while creation_idx > 0 {
    creation_idx = creation_idx - 1
    creation_order.push(inputs.nlist_order[creation_idx])
  }
  // Graphviz parity: build_ranks node-order seed prioritizes GD_nlist then
  // fills with nlist/order_groups/base order; rank=same ND_order normalization
  // is applied only on clustered reorder paths.
  let order_node_order : Map[String, Int] = Map::new()
  let mut order_idx = 0
  for name in inputs.gdnlist_order {
    order_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  for name in inputs.nlist_order {
    if order_node_order.get(name) is None {
      order_node_order[name] = order_idx
      order_idx = order_idx + 1
    }
  }
  // Graphviz parity: fall back to GD_nlist order for real nodes missing from nlist.
  for name, idx in inputs.node_order {
    if inputs.real_nodes.get(name) is Some(_) && order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let order_index = build_order_index(inputs.order_groups)
  for name, idx in order_index {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: seed missing real-node order from initial rank order;
  // GD_nlist order remains the primary source.
  for name, idx in inputs.base_order_index {
    if inputs.real_nodes.get(name) is Some(_) &&
      order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  if inputs.has_clusters {
    // Graphviz parity: non-cluster root reorder keeps GD_nlist-derived order
    // (world.gv) and does not re-normalize ND_order by rank=same declaration.
    apply_rank_same_order_nodes(
      order_node_order,
      inputs.rank_same_groups,
      inputs.rank_same_order,
      inputs.port_edge_nodes,
    )
  }
  {
    order_rank_keys,
    order_ranks,
    order_nodes,
    order_graph,
    order_node_map,
    order_graph_unmapped,
    order_node_map_unmapped,
    creation_order,
    order_node_order,
  }
}

///|
/// Graphviz parity: order graph node table is built by creating each name in
/// order_nodes sequence, matching agnode creation iteration order.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct OrderGraphAndNodes {
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
}

///|
/// Graphviz parity: order graph node table is built by creating each name in
/// order_nodes sequence, matching agnode creation iteration order.
/// Do not change behavior without updating fixtures/tests.
pub fn build_order_graph_and_nodes(
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
pub(all) struct OrderEdgeArrays {
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
pub fn collect_order_edges_for_tails(
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
pub(all) struct EdgeIndicesAndOrder {
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  edge_order : Map[String, Int]
}

///|
/// Graphviz parity: parent/child adjacency maps and edge-order indices are
/// derived from the exact materialized edge arrays in current order graph.
/// Do not change behavior without updating fixtures/tests.
pub fn build_edge_indices_and_order(
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
pub(all) struct TransposeSeedMapsOutput {
  edge_penalty : Array[Int]
  edge_in : Map[String, Array[Int]]
  edge_out : Map[String, Array[Int]]
}

///|
/// Graphviz parity: transpose seed maps include all seeded nodes and only
/// positive-penalty constrained edges that cross ranks.
/// Do not change behavior without updating fixtures/tests.
pub fn build_transpose_seed_maps(
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
    let penalty = @shared.edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if penalty <= 0 || !@shared.edge_is_constraint(edge) {
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
