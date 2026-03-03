///|
/// Stage C Phase C1 split: ordering-edge materialization,
/// cluster-skeleton seeding, and neighbor-index helpers.

///|
priv struct EdgePortSamples {
  tail_values : Array[Double]
  head_values : Array[Double]
}

///|
/// Graphviz parity: shared edge-port sampling setup keeps endpoint remap and
/// per-edge iteration order identical for both x-offset and port-order passes.
fn compute_edge_port_samples(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
  sample_fn : (String, @cgraph.Port?, Map[String, Map[String, RecordPort]], Map[String, NodeSize], RankDir, Map[String, @cgraph.Node]) -> Double,
) -> EdgePortSamples {
  if edges.length() == 0 {
    return { tail_values: [], head_values: [] }
  }
  let rankdir =
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
  let nodes_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    nodes_by_name[node.name()] = node
  }
  let port_offsets = port_offsets_for_nodes(nodes, sizes)
  let tail_names : Array[String] = []
  let head_names : Array[String] = []
  let tail_ports : Array[@cgraph.Port?] = []
  let head_ports : Array[@cgraph.Port?] = []
  let mut endpoint_idx = 0
  while endpoint_idx < edges.length() {
    let edge = edges[endpoint_idx]
    let (tail_name, head_name) =
      @ordering.edge_endpoints_at(
        edge,
        endpoint_idx,
        edge_tail,
        edge_head,
      )
    let tail_port = @ordering.edge_tail_port_for_name(edge, tail_name)
    let head_port = @ordering.edge_head_port_for_name(edge, head_name)
    tail_names.push(tail_name)
    head_names.push(head_name)
    tail_ports.push(tail_port)
    head_ports.push(head_port)
    endpoint_idx = endpoint_idx + 1
  }
  let tail_samples : Array[Double] = []
  let head_samples : Array[Double] = []
  let mut idx = 0
  while idx < edges.length() {
    tail_samples.push(
      sample_fn(
        tail_names[idx],
        tail_ports[idx],
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      ),
    )
    head_samples.push(
      sample_fn(
        head_names[idx],
        head_ports[idx],
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      ),
    )
    idx = idx + 1
  }
  { tail_values: tail_samples, head_values: head_samples }
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
) -> EdgePortSamples {
  // Graphviz parity: per-edge tail/head x-offset samples are emitted in edge
  // sequence order after endpoint-name/port remap.
  compute_edge_port_samples(
    nodes,
    edges,
    edge_tail,
    edge_head,
    sizes,
    edge_port_offset,
  )
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
) -> EdgePortSamples {
  // Graphviz parity: per-edge tail/head port-order samples are emitted in edge
  // sequence order using the same endpoint remap as tie-break x-offsets.
  compute_edge_port_samples(
    nodes,
    edges,
    edge_tail,
    edge_head,
    sizes,
    edge_port_order,
  )
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
fn skeleton_name_for_rank(cluster : String, rank : Int) -> String {
  "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
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
    let tail_name = skeleton_name_for_rank(cluster, rank)
    let head_name = skeleton_name_for_rank(cluster, rank + 1)
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
/// Graphviz parity: cluster skeleton edge chains are emitted in Graphviz
/// cluster-order sequence first, then for any remaining cluster-min-rank keys.
/// Do not change behavior without updating fixtures/tests.
fn build_skeleton_edge_creation(
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
