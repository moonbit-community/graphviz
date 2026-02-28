///|
/// Stage C Phase C1 split: ordering-edge materialization,
/// cluster-skeleton seeding, and neighbor-index helpers.

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
  let tail_names : Array[String] = []
  let head_names : Array[String] = []
  let tail_ports : Array[@cgraph.Port?] = []
  let head_ports : Array[@cgraph.Port?] = []
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
    tail_names.push(tail_name)
    head_names.push(head_name)
    tail_ports.push(tail_port)
    head_ports.push(head_port)
    idx = idx + 1
  }
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
  // Graphviz parity: per-edge tail/head x-offset samples are emitted in edge
  // sequence order after endpoint-name/port remap.
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
  // Graphviz parity: per-edge tail/head port-order samples are emitted in edge
  // sequence order using the same endpoint remap as tie-break x-offsets.
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
            cluster_skeleton_name_for_rank(cluster, rank),
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
        cluster_skeleton_name_for_rank(cluster, rank),
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
    let tail_name = cluster_skeleton_name_for_rank(cluster, rank)
    let head_name = cluster_skeleton_name_for_rank(cluster, rank + 1)
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
    // Graphviz parity: each real-node tail emits itself first, followed by its
    // per-tail vnode sequence, while preserving first-seen dedup semantics.
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
  let vnode_creation_order : Array[String] = []
  for name in order_creation {
    if name.has_prefix(EDGE_VNODE_PREFIX) {
      vnode_creation_order.push(name)
    }
  }
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
  // Graphviz parity: append skeleton chains by cluster_order first,
  // then remaining cluster_min_rank keys.
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
  skeleton_edge_creation
}
