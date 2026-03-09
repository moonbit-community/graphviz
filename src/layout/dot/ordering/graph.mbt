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
  let coalesced : Array[
    (String, String, Int, Bool, Double, Double, Double, Double),
  ] = []
  let key_index : Map[String, Int] = Map::new()
  for entry in entries {
    let (
      tail,
      head,
      penalty,
      constraint,
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
    ) = entry
    let key = order_edge_merge_key(
      tail, head, constraint, tail_port_order, head_port_order,
    )
    match key_index.get(key) {
      Some(rep_index) =>
        if penalty > 0 {
          let (
            rep_tail,
            rep_head,
            rep_penalty,
            rep_constraint,
            rep_tail_port_x,
            rep_head_port_x,
            rep_tail_port_order,
            rep_head_port_order,
          ) = coalesced[rep_index]
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
            (
              tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order,
              head_port_order,
            ),
          )
        }
      None => {
        coalesced.push(
          (
            tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order,
            head_port_order,
          ),
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
  order_edges_by_tail : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ],
) -> Map[
  String,
  Array[(String, String, Int, Bool, Double, Double, Double, Double)],
] {
  let coalesced : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
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
  tail_name == edge.head().name() && head_name == edge.tail().name()
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
  let order_graph = @cgraph.Graph::new(
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
  edges_by_tail : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ],
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
      let (
        edge_tail_name,
        edge_head_name,
        penalty,
        constraint,
        tail_port_x,
        head_port_x,
        tail_port_order,
        head_port_order,
      ) = entry
      add_order_edge(
        order_graph, order_node_map, order_edges_out, order_edge_tail_out, order_edge_head_out,
        order_edge_tail_port_x, order_edge_head_port_x, order_edge_tail_port_order,
        order_edge_head_port_order, edge_tail_name, edge_head_name, penalty, constraint,
        tail_port_x, head_port_x, tail_port_order, head_port_order,
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
  let edge_index_data = build_edge_index_for_names(
    order_nodes, edge_tail_out, edge_head_out, order_ranks,
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
    let penalty = @edge_semantics.edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if penalty <= 0 || !@edge_semantics.edge_is_constraint(edge) {
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
