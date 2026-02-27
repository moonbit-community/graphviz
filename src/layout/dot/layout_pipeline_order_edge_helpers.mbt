///|
/// Extracted from layout_pipeline_helpers.mbt to keep order-edge,
/// cluster-skeleton seeding, and graphviz-neighbor helpers isolated.

///|
/// Graphviz parity: order-edge endpoint names may map to swapped virtual
/// directions, so corresponding tail/head ports must be remapped per endpoint.
/// Do not change behavior without updating fixtures/tests.
fn resolve_order_edge_names_and_ports(
  edge : @cgraph.Edge,
  idx : Int,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (String, String, @cgraph.Port?, @cgraph.Port?) {
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
  (tail_name, head_name, tail_port, head_port)
}

///|
/// Graphviz parity: order-edge endpoint remap is computed once per edge index
/// and reused by both port-offset and port-order passes.
/// Do not change behavior without updating fixtures/tests.
fn collect_order_edge_endpoint_ports(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (Array[String], Array[String], Array[@cgraph.Port?], Array[@cgraph.Port?]) {
  let tail_names : Array[String] = []
  let head_names : Array[String] = []
  let tail_ports : Array[@cgraph.Port?] = []
  let head_ports : Array[@cgraph.Port?] = []
  let mut idx = 0
  while idx < edges.length() {
    let edge = edges[idx]
    let (tail_name, head_name, tail_port, head_port) =
      resolve_order_edge_names_and_ports(
        edge,
        idx,
        edge_tail,
        edge_head,
      )
    tail_names.push(tail_name)
    head_names.push(head_name)
    tail_ports.push(tail_port)
    head_ports.push(head_port)
    idx = idx + 1
  }
  (tail_names, head_names, tail_ports, head_ports)
}

///|
/// Graphviz parity: per-edge tail/head x-offset samples are emitted in edge
/// sequence order after endpoint-name/port remap.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_port_offsets_from_endpoint_ports(
  edges : Array[@cgraph.Edge],
  tail_names : Array[String],
  head_names : Array[String],
  tail_ports : Array[@cgraph.Port?],
  head_ports : Array[@cgraph.Port?],
  port_offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> (Array[Double], Array[Double]) {
  let tail_offsets : Array[Double] = []
  let head_offsets : Array[Double] = []
  let mut idx = 0
  while idx < edges.length() {
    let tail_x =
      edge_port_offset(
        tail_names[idx],
        tail_ports[idx],
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      )
    let head_x =
      edge_port_offset(
        head_names[idx],
        head_ports[idx],
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      )
    tail_offsets.push(tail_x)
    head_offsets.push(head_x)
    idx = idx + 1
  }
  (tail_offsets, head_offsets)
}

///|
/// Graphviz parity: port-sampling inputs reuse one endpoint remap + per-node
/// port offset table so x-offset and order passes share identical edge context.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_port_sampling_inputs(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (
  Map[String, Map[String, RecordPort]],
  Array[String],
  Array[String],
  Array[@cgraph.Port?],
  Array[@cgraph.Port?],
) {
  let port_offsets = port_offsets_for_nodes(nodes, sizes)
  let (tail_names, head_names, tail_ports, head_ports) =
    collect_order_edge_endpoint_ports(
      edges,
      edge_tail,
      edge_head,
    )
  (port_offsets, tail_names, head_names, tail_ports, head_ports)
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
  let rankdir =
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
  let nodes_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    nodes_by_name[node.name()] = node
  }
  let (port_offsets, tail_names, head_names, tail_ports, head_ports) =
    build_edge_port_sampling_inputs(
      nodes,
      edges,
      edge_tail,
      edge_head,
      sizes,
    )
  build_edge_port_offsets_from_endpoint_ports(
    edges,
    tail_names,
    head_names,
    tail_ports,
    head_ports,
    port_offsets,
    sizes,
    rankdir,
    nodes_by_name,
  )
}

///|
/// Graphviz parity: per-edge tail/head port-order samples are emitted in edge
/// sequence order using the same endpoint remap as tie-break x-offsets.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_port_orders_from_endpoint_ports(
  edges : Array[@cgraph.Edge],
  tail_names : Array[String],
  head_names : Array[String],
  tail_ports : Array[@cgraph.Port?],
  head_ports : Array[@cgraph.Port?],
  port_offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> (Array[Double], Array[Double]) {
  let tail_orders : Array[Double] = []
  let head_orders : Array[Double] = []
  let mut idx = 0
  while idx < edges.length() {
    let tail_order =
      edge_port_order(
        tail_names[idx],
        tail_ports[idx],
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      )
    let head_order =
      edge_port_order(
        head_names[idx],
        head_ports[idx],
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      )
    tail_orders.push(tail_order)
    head_orders.push(head_order)
    idx = idx + 1
  }
  (tail_orders, head_orders)
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
  let rankdir =
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
  let nodes_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    nodes_by_name[node.name()] = node
  }
  let (port_offsets, tail_names, head_names, tail_ports, head_ports) =
    build_edge_port_sampling_inputs(
      nodes,
      edges,
      edge_tail,
      edge_head,
      sizes,
    )
  build_edge_port_orders_from_endpoint_ports(
    edges,
    tail_names,
    head_names,
    tail_ports,
    head_ports,
    port_offsets,
    sizes,
    rankdir,
    nodes_by_name,
  )
}

///|
/// Graphviz parity: ND_in order follows edge sequence (AGSEQ) within each
/// fixed head, preserving edge creation insertion order.
/// Do not change behavior without updating fixtures/tests.
fn build_graphviz_in_entries_from_edge_sequence(
  edge_creation_order : Array[(String, String)],
) -> Map[String, Array[String]] {
  let in_entries : Map[String, Array[String]] = Map::new()
  for edge in edge_creation_order {
    let (tail, head) = edge
    match in_entries.get(head) {
      Some(list) => list.push(tail)
      None => in_entries[head] = [tail]
    }
  }
  in_entries
}

///|
/// Graphviz parity: ND_out keeps tail-local edge insertion order for heads,
/// mirroring Graphviz AGSEQ traversal on each tail adjacency list.
/// Do not change behavior without updating fixtures/tests.
fn collect_graphviz_out_heads(
  entries : Array[(String, String, Int, Bool, Double, Double, Double, Double)],
) -> Array[String] {
  let heads : Array[String] = []
  for entry in entries {
    let (_t, h, _pen, _constraint, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) =
      entry
    heads.push(h)
  }
  heads
}

///|
/// Graphviz parity: ND_out/ND_in neighbor maps are pre-seeded for every order
/// node before edge insertion replay to match Graphviz empty-adjacency behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_empty_graphviz_neighbor_maps(
  order_nodes : Array[String],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    graphviz_out_neighbors[name] = []
    graphviz_in_neighbors[name] = []
  }
  (graphviz_out_neighbors, graphviz_in_neighbors)
}

///|
/// Graphviz parity: ND_in map assignment replays AGSEQ-derived head buckets
/// directly onto pre-seeded neighbor maps.
/// Do not change behavior without updating fixtures/tests.
fn assign_graphviz_in_neighbors_from_edge_sequence(
  graphviz_in_neighbors : Map[String, Array[String]],
  edge_creation_order : Array[(String, String)],
) -> Unit {
  let in_entries = build_graphviz_in_entries_from_edge_sequence(
    edge_creation_order,
  )
  for head, entries in in_entries {
    graphviz_in_neighbors[head] = entries
  }
}

///|
/// Graphviz parity: ND_out assignment replays AGSEQ-ordered tail adjacency
/// lists directly onto pre-seeded neighbor maps.
/// Do not change behavior without updating fixtures/tests.
fn assign_graphviz_out_neighbors_from_tail_entries(
  graphviz_out_neighbors : Map[String, Array[String]],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Unit {
  for tail, entries in order_edges_by_tail {
    graphviz_out_neighbors[tail] = collect_graphviz_out_heads(entries)
  }
}

///|
/// Graphviz parity: ND_out/ND_in neighbor order follows edge insertion (AGSEQ).
/// Do not change behavior without updating fixtures/tests.
fn build_graphviz_neighbor_maps(
  order_nodes : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  edge_creation_order : Array[(String, String)],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let (graphviz_out_neighbors, graphviz_in_neighbors) =
    build_empty_graphviz_neighbor_maps(order_nodes)
  assign_graphviz_out_neighbors_from_tail_entries(
    graphviz_out_neighbors,
    order_edges_by_tail,
  )
  assign_graphviz_in_neighbors_from_edge_sequence(
    graphviz_in_neighbors,
    edge_creation_order,
  )
  (graphviz_out_neighbors, graphviz_in_neighbors)
}

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
/// Graphviz parity: cluster skeleton node naming uses
/// CLUSTER_SKELETON_PREFIX + cluster + @rank across all class2 passes.
/// Do not change behavior without updating fixtures/tests.
fn cluster_skeleton_name_for_rank(cluster : String, rank : Int) -> String {
  "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
}

///|
/// Graphviz parity: cluster skeleton names expand to one deterministic token
/// per rank between min/max bounds using CLUSTER_SKELETON_PREFIX naming.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_rank_span(
  cluster_skeleton_creation : Array[String],
  cluster : String,
  min_rank : Int,
  max_rank : Int,
) -> Unit {
  for rank in min_rank..=max_rank {
    cluster_skeleton_creation.push(
      cluster_skeleton_name_for_rank(cluster, rank),
    )
  }
}

///|
/// Graphviz parity: cluster skeleton max rank falls back to min rank when
/// cluster_max_rank has no entry for the cluster.
/// Do not change behavior without updating fixtures/tests.
fn cluster_skeleton_max_rank_or_min(
  cluster_max_rank : Map[String, Int],
  cluster : String,
  min_rank : Int,
) -> Int {
  match cluster_max_rank.get(cluster) {
    Some(value) => value
    None => min_rank
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
        let max_rank =
          cluster_skeleton_max_rank_or_min(cluster_max_rank, cluster, min_rank)
        append_cluster_skeleton_rank_span(
          cluster_skeleton_creation,
          cluster,
          min_rank,
          max_rank,
        )
        cluster_seen[cluster] = true
      }
      None => ()
    }
  }
  for cluster, min_rank in cluster_min_rank {
    if cluster_seen.get(cluster) is Some(_) {
      continue
    }
    let max_rank =
      cluster_skeleton_max_rank_or_min(cluster_max_rank, cluster, min_rank)
    append_cluster_skeleton_rank_span(
      cluster_skeleton_creation,
      cluster,
      min_rank,
      max_rank,
    )
  }
  cluster_skeleton_creation
}

///|
/// Graphviz parity: cluster skeleton CL_CROSS edges are inserted at the front
/// of both local and root tail maps to preserve class2 traversal priority.
/// Do not change behavior without updating fixtures/tests.
fn prepend_cluster_skeleton_edge_to_local_and_root(
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  tail_name : String,
  entry : (String, String, Int, Bool, Double, Double, Double, Double),
) -> Unit {
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
    let tail_name = cluster_skeleton_name_for_rank(cluster, rank)
    let head_name = cluster_skeleton_name_for_rank(cluster, rank + 1)
    let entry = (tail_name, head_name, CL_CROSS, true, 0.0, 0.0, 0.5, 0.5)
    skeleton_edge_creation.push((tail_name, head_name))
    prepend_cluster_skeleton_edge_to_local_and_root(
      order_edges_by_tail,
      order_edges_by_tail_root,
      tail_name,
      entry,
    )
    rank = rank + 1
  }
}

///|
/// Graphviz parity: class2 order_creation keeps first-seen insertion order,
/// suppressing duplicates across skeleton, real-node, and vnode phases.
/// Do not change behavior without updating fixtures/tests.
fn append_order_creation_name_if_absent(
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
/// Graphviz parity: vnode creation order is the stable subsequence of
/// order_creation names prefixed with EDGE_VNODE_PREFIX.
/// Do not change behavior without updating fixtures/tests.
fn collect_vnode_creation_order_from_order_creation(
  order_creation : Array[String],
) -> Array[String] {
  let vnode_creation_order : Array[String] = []
  for name in order_creation {
    if name.has_prefix(EDGE_VNODE_PREFIX) {
      vnode_creation_order.push(name)
    }
  }
  vnode_creation_order
}

///|
/// Graphviz parity: each real-node tail emits itself first, followed by its
/// per-tail vnode sequence, while preserving first-seen dedup semantics.
/// Do not change behavior without updating fixtures/tests.
fn append_order_creation_tail_and_vnodes(
  order_creation : Array[String],
  order_seen : Map[String, Bool],
  tail_name : String,
  vnode_creation_by_tail : Map[String, Array[String]],
) -> Unit {
  append_order_creation_name_if_absent(
    order_creation,
    order_seen,
    tail_name,
  )
  let vnodes = match vnode_creation_by_tail.get(tail_name) {
    Some(list) => list
    None => []
  }
  for vnode in vnodes {
    append_order_creation_name_if_absent(
      order_creation,
      order_seen,
      vnode,
    )
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
    append_order_creation_name_if_absent(
      order_creation,
      order_seen,
      name,
    )
  }
  for tail_name in creation_order {
    append_order_creation_tail_and_vnodes(
      order_creation,
      order_seen,
      tail_name,
      vnode_creation_by_tail,
    )
  }
  let vnode_creation_order =
    collect_vnode_creation_order_from_order_creation(order_creation)
  (order_creation, vnode_creation_order)
}

///|
/// Graphviz parity: cluster membership lookup treats missing keys as
/// non-cluster entries across class2 preprocessing passes.
/// Do not change behavior without updating fixtures/tests.
fn cluster_key_or_empty(
  cluster_keys : Map[String, String],
  name : String,
) -> String {
  match cluster_keys.get(name) {
    Some(value) => value
    None => ""
  }
}

///|
/// Graphviz parity: cluster flip preprocessing first buckets nlist nodes by
/// cluster key while skipping non-cluster entries.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_nodes_for_flip(
  nlist_order_raw : Array[String],
  cluster_keys : Map[String, String],
) -> Map[String, Array[String]] {
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
  cluster_nodes
}


///|
/// Graphviz parity: cluster flip uses explicit reverse traversal to construct
/// per-cluster replacement lists in reverse local order.
/// Do not change behavior without updating fixtures/tests.
fn reverse_cluster_nodes_for_flip(list : Array[String]) -> Array[String] {
  let reversed : Array[String] = []
  let mut idx = list.length()
  while idx > 0 {
    idx = idx - 1
    reversed.push(list[idx])
  }
  reversed
}

///|
/// Graphviz parity: cluster flip precomputes reversed per-cluster node lists
/// and zeroed consumption indices before reconstructing adjusted nlist order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_reversed_nodes_and_index_for_flip(
  cluster_nodes : Map[String, Array[String]],
) -> (Map[String, Array[String]], Map[String, Int]) {
  let cluster_reversed : Map[String, Array[String]] = Map::new()
  let cluster_index : Map[String, Int] = Map::new()
  for cluster, list in cluster_nodes {
    cluster_reversed[cluster] = reverse_cluster_nodes_for_flip(list)
    cluster_index[cluster] = 0
  }
  (cluster_reversed, cluster_index)
}


///|
/// Graphviz parity: flipped nlist reconstruction consumes one reversed member
/// per cluster occurrence, falling back to original name on index overflow.
/// Do not change behavior without updating fixtures/tests.
fn consume_cluster_flip_name(
  cluster : String,
  name : String,
  cluster_reversed : Map[String, Array[String]],
  cluster_index : Map[String, Int],
) -> String {
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
  resolved
}

///|
/// Graphviz parity: flipped nlist reconstruction preserves non-cluster names
/// and replaces cluster names by sequential consumption from reversed buckets.
/// Do not change behavior without updating fixtures/tests.
fn build_adjusted_nlist_order_for_cluster_flip(
  nlist_order_raw : Array[String],
  cluster_keys : Map[String, String],
  cluster_reversed : Map[String, Array[String]],
  cluster_index : Map[String, Int],
) -> Array[String] {
  let adjusted : Array[String] = []
  for name in nlist_order_raw {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      adjusted.push(name)
    } else {
      adjusted.push(
        consume_cluster_flip_name(
          cluster,
          name,
          cluster_reversed,
          cluster_index,
        ),
      )
    }
  }
  adjusted
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
  let cluster_nodes = collect_cluster_nodes_for_flip(
    nlist_order_raw,
    cluster_keys,
  )
  let (cluster_reversed, cluster_index) =
    build_cluster_reversed_nodes_and_index_for_flip(cluster_nodes)
  build_adjusted_nlist_order_for_cluster_flip(
    nlist_order_raw,
    cluster_keys,
    cluster_reversed,
    cluster_index,
  )
}

///|
/// Graphviz parity: edge creation sequence concatenates skeleton links before
/// regular order-edge links to preserve AGSEQ head-neighbor replay.
/// Do not change behavior without updating fixtures/tests.
fn merge_edge_creation_sequences(
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
/// Graphviz parity: edge creation order feeds ND_in AGSEQ capture with cluster
/// skeleton links preceding regular order_edge_creation links.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_creation_order(
  skeleton_edge_creation : Array[(String, String)],
  order_edge_creation : Array[(String, String)],
) -> Array[(String, String)] {
  merge_edge_creation_sequences(
    skeleton_edge_creation,
    order_edge_creation,
  )
}

///|
/// Graphviz parity: class2 flat-rank preprocessing treats unknown node ranks
/// as 0 when evaluating same-rank non-self edge constraints.
/// Do not change behavior without updating fixtures/tests.
fn rank_or_zero_for_flat_constraints(
  ranks : Map[String, Int],
  name : String,
) -> Int {
  match ranks.get(name) {
    Some(value) => value
    None => 0
  }
}

///|
/// Graphviz parity: flat-constraint insertion only records non-self edges whose
/// endpoints resolve to the same rank under missing-rank fallback.
/// Do not change behavior without updating fixtures/tests.
fn append_flat_rank_constraint_if_same_rank(
  flat_rank_constraints : Map[String, Bool],
  tail : String,
  head : String,
  ranks : Map[String, Int],
) -> Unit {
  if tail == head {
    return
  }
  let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
  let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
  if tail_rank == head_rank {
    flat_rank_constraints["\{tail}|\{head}"] = true
  }
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
    append_flat_rank_constraint_if_same_rank(
      flat_rank_constraints,
      tail,
      head,
      ranks,
    )
    flat_idx = flat_idx + 1
  }
  flat_rank_constraints
}

///|
/// Graphviz parity: cluster skeleton edge chains are appended by cluster_order
/// first, then remaining cluster_min_rank keys, matching Graphviz ordering.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_edges_for_order_graph(
  cluster_order : Array[String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
) -> Unit {
  let cluster_seen : Map[String, Bool] = Map::new()
  for cluster in cluster_order {
    match cluster_min_rank.get(cluster) {
      Some(min_rank) => {
        let max_rank = match cluster_max_rank.get(cluster) {
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
  for cluster, min_rank in cluster_min_rank {
    if cluster_seen.get(cluster) is Some(_) {
      continue
    }
    let max_rank = match cluster_max_rank.get(cluster) {
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


///|
/// Graphviz parity: cluster skeleton edge chains are emitted in Graphviz
/// cluster-order sequence first, then for any remaining cluster-min-rank keys.
/// Do not change behavior without updating fixtures/tests.
fn build_skeleton_edge_creation_for_order_graph(
  order_with_clusters : Bool,
  cluster_order : Array[String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Array[(String, String)] {
  let skeleton_edge_creation : Array[(String, String)] = []
  if !order_with_clusters {
    return skeleton_edge_creation
  }
  append_cluster_skeleton_edges_for_order_graph(
    cluster_order,
    cluster_min_rank,
    cluster_max_rank,
    order_edges_by_tail,
    order_edges_by_tail_root,
    skeleton_edge_creation,
  )
  skeleton_edge_creation
}

