///|
/// Ordering mincross owner: clustered pre-root seed/reorder/materialization
/// stage stays with the clustered root/finalize pipeline that consumes it.

///|
type NodeSize = @node_primitives.NodeSize

///|
/// Graphviz parity: clustered pre-root seed payload keeps grouped nodes,
/// order-graph sizes, and cluster metadata maps bundled for root/cluster
/// ordering preparation.
priv struct OrderSeedGroupsOutput {
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
}

///|
/// Graphviz parity: order-stage seed input keeps vnode and cluster metadata
/// snapshots unchanged before grouped seed expansion.
priv struct OrderSeedGroupsInputs {
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
fn build_order_seed_groups(
  inputs : OrderSeedGroupsInputs,
) -> OrderSeedGroupsOutput {
  let order_groups = if inputs.order_with_vnodes {
    @shared.build_x_groups_with_vnodes(
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
  let order_sizes_out = @order_graph.build_sizes_for_order_graph(
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
  { order_groups, order_sizes_out, order_cluster_keys, order_cluster_skeleton }
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
  for rank in min_rank..<=max_rank {
    let name = @cluster_identity.cluster_skeleton_name(cluster, rank)
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
/// Graphviz parity: clustered pre-root reorder context keeps build_ranks seed
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
priv struct OrderReorderContextInputs {
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
/// Graphviz parity: unported rank=same groups keep subgraph order for ND_order.
/// Do not change behavior without updating fixtures/tests.
fn apply_rank_same_order_nodes(
  node_order : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> Unit {
  if rank_same_groups.length() == 0 {
    return ()
  }
  let group_nodes : Map[Int, Array[String]] = Map::new()
  let group_has_ported : Map[Int, Bool] = Map::new()
  for name, group in rank_same_groups {
    if node_order.get(name) is None {
      continue
    }
    match group_nodes.get(group) {
      Some(list) => list.push(name)
      None => group_nodes[group] = [name]
    }
    if port_edge_nodes.get(name) == Some(true) {
      group_has_ported[group] = true
    }
  }
  for group, names in group_nodes {
    if group_has_ported.get(group) == Some(true) {
      continue
    }
    if names.length() <= 1 {
      continue
    }
    let sorted_names = names.copy()
    sorted_names.sort_by((a, b) => {
      let a_idx = match rank_same_order.get(a) {
        Some(value) => value
        None => 0
      }
      let b_idx = match rank_same_order.get(b) {
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
    })
    let orders : Array[Int] = []
    for name in names {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      orders.push(order_value)
    }
    if orders.length() <= 1 {
      continue
    }
    orders.sort()
    let mut idx = 0
    while idx < sorted_names.length() && idx < orders.length() {
      node_order[sorted_names[idx]] = orders[idx]
      idx = idx + 1
    }
  }
}

///|
/// Graphviz parity: order-graph rebuild uses GD_nlist-derived creation order
/// and build_ranks seed order before mapped/unmapped edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_order_reorder_context(
  inputs : OrderReorderContextInputs,
) -> OrderReorderContext {
  let order_rank_keys = @shared.collect_rank_keys(inputs.order_groups)
  let order_ranks = @shared.build_node_ranks(inputs.order_groups)
  let order_nodes = @order_graph.build_order_nodes_from_groups(
    inputs.order_groups,
    order_rank_keys,
  )
  let order_graph_output = @order_graph.build_order_graph_and_nodes(
    "order_graph", order_nodes,
  )
  let order_graph = order_graph_output.order_graph
  let order_node_map = order_graph_output.order_node_map
  let order_graph_unmapped_output = @order_graph.build_order_graph_and_nodes(
    "order_graph_unmapped", order_nodes,
  )
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
    if inputs.real_nodes.get(name) is Some(_) &&
      order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let order_index = @shared.build_order_index(inputs.order_groups)
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
/// Graphviz parity: mapped/unmapped order-edge materialization output keeps
/// remapped arrays, Graphviz ND_out/ND_in neighbors, and flat constraints
/// snapshots unchanged for clustered root/finalize phases.
pub(all) struct OrderMaterializationData {
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_edges_out_unmapped : Array[@cgraph.Edge]
  order_edge_tail_out_unmapped : Array[String]
  order_edge_head_out_unmapped : Array[String]
  order_edge_tail_port_x_unmapped : Array[Double]
  order_edge_head_port_x_unmapped : Array[Double]
  order_edge_tail_port_order_unmapped : Array[Double]
  order_edge_head_port_order_unmapped : Array[Double]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  order_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: mapped/unmapped materialization input keeps nlist/AGSEQ
/// snapshots and flat constraints unchanged before edge-array build.
priv struct OrderMaterializationInputs {
  nlist_order : Array[String]
  order_edges_by_tail : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_edges_by_tail_unmapped : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  order_nodes : Array[String]
  edge_creation_order : Array[(String, String)]
  flat_constraints : Map[String, Bool]
}

///|
priv struct MaterializedGraphvizNeighborMaps {
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
}

///|
/// Graphviz parity: materialized ND_out/ND_in neighbors preserve per-tail
/// AGSEQ replay order before unconstrained seed overrides.
fn build_materialized_graphviz_neighbors(
  order_nodes : Array[String],
  order_edges_by_tail : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ],
  edge_creation_order : Array[(String, String)],
) -> MaterializedGraphvizNeighborMaps {
  // Graphviz parity: ND_out/ND_in neighbor order follows edge insertion (AGSEQ).
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    graphviz_out_neighbors[name] = []
    graphviz_in_neighbors[name] = []
  }
  for tail, entries in order_edges_by_tail {
    let heads : Array[String] = []
    for entry in entries {
      let (
        _t,
        h,
        _pen,
        _constraint,
        _tail_port_x,
        _head_port_x,
        _tail_port_order,
        _head_port_order,
      ) = entry
      heads.push(h)
    }
    graphviz_out_neighbors[tail] = heads
  }
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
  { out_neighbors: graphviz_out_neighbors, in_neighbors: graphviz_in_neighbors }
}

///|
/// Graphviz parity: mapped/unmapped order-edge materialization and ND_out/ND_in
/// maps must follow GD_nlist/AGSEQ traversal before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn build_order_materialization_data(
  inputs : OrderMaterializationInputs,
) -> OrderMaterializationData {
  // Graphviz parity: mapped/unmapped order-edge arrays are materialized from
  // GD_nlist tail order against remapped and non-remapped order graphs.
  let mapped_edges = @order_graph.collect_order_edges_for_tails(
    inputs.nlist_order,
    inputs.order_edges_by_tail,
    inputs.order_graph,
    inputs.order_node_map,
  )
  let unmapped_edges = @order_graph.collect_order_edges_for_tails(
    inputs.nlist_order,
    inputs.order_edges_by_tail_unmapped,
    inputs.order_graph_unmapped,
    inputs.order_node_map_unmapped,
  )
  let graphviz_neighbors = build_materialized_graphviz_neighbors(
    inputs.order_nodes,
    inputs.order_edges_by_tail,
    inputs.edge_creation_order,
  )
  let order_flat_constraints : Map[String, Bool] = Map::new()
  for key, value in inputs.flat_constraints {
    order_flat_constraints[key] = value
  }
  {
    order_edges_out: mapped_edges.order_edges_out,
    order_edge_tail_out: mapped_edges.order_edge_tail_out,
    order_edge_head_out: mapped_edges.order_edge_head_out,
    order_edge_tail_port_x: mapped_edges.order_edge_tail_port_x,
    order_edge_head_port_x: mapped_edges.order_edge_head_port_x,
    order_edge_tail_port_order: mapped_edges.order_edge_tail_port_order,
    order_edge_head_port_order: mapped_edges.order_edge_head_port_order,
    order_edges_out_unmapped: unmapped_edges.order_edges_out,
    order_edge_tail_out_unmapped: unmapped_edges.order_edge_tail_out,
    order_edge_head_out_unmapped: unmapped_edges.order_edge_head_out,
    order_edge_tail_port_x_unmapped: unmapped_edges.order_edge_tail_port_x,
    order_edge_head_port_x_unmapped: unmapped_edges.order_edge_head_port_x,
    order_edge_tail_port_order_unmapped: unmapped_edges.order_edge_tail_port_order,
    order_edge_head_port_order_unmapped: unmapped_edges.order_edge_head_port_order,
    graphviz_out_neighbors: graphviz_neighbors.out_neighbors,
    graphviz_in_neighbors: graphviz_neighbors.in_neighbors,
    order_flat_constraints,
  }
}

///|
/// Graphviz parity: unconstrained real nodes keep GD_nlist seed order, with
/// incoming-only local-cluster nodes reversed to match fast_node head-insert
/// behavior before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn apply_unconstrained_order_overrides(
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
  let gdnlist_order_index : Map[String, Int] = Map::new()
  let mut gdnlist_idx = 0
  for name in gdnlist_order {
    if real_nodes.get(name) is Some(_) {
      gdnlist_order_index[name] = gdnlist_idx
    }
    gdnlist_idx = gdnlist_idx + 1
  }
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
  for name, idx in gdnlist_order_index {
    if real_nodes.get(name) is Some(_) &&
      unconstrained_nodes.get(name) is Some(_) &&
      rank_same_groups.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: incoming-only unconstrained nodes inside local clusters
  // follow first incoming-edge order from unmapped class2 edge lists.
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
/// Graphviz parity: clustered pre-root materialized stage output keeps reorder
/// context and mapped/unmapped materialization snapshots paired.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredMaterializedStageOutput {
  reorder_context : OrderReorderContext
  materialized : OrderMaterializationData
}

///|
/// Graphviz parity: clustered pre-root stage source bundle keeps seed-stage
/// snapshots and materialization-stage snapshots grouped for one deterministic
/// pre-root run.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredPreRootStageSources {
  reorder_setup : @setup.OrderingReorderSetup
  cluster_keys : Map[String, String]
  cluster_order : Array[String]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  vnode_clusters : Map[String, String]
  vnodes_by_rank : Map[Int, Array[String]]
  order_sizes : Map[String, NodeSize]
  vnode_sizes : Map[String, NodeSize]
  skeleton_size : NodeSize
  node_order : Map[String, Int]
  real_nodes : Map[String, Bool]
  has_clusters : Bool
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  port_edge_nodes : Map[String, Bool]
  flat_constraints : Map[String, Bool]
  edge_tail : Array[String]
  edge_head : Array[String]
  nodes : Array[@cgraph.Node]
  intercluster_keys : Map[String, String]
}

///|
/// Graphviz parity: clustered pre-root stage output keeps grouped sizes,
/// cluster skeleton maps, reorder context, and materialized edges unchanged.
/// Do not change behavior without updating fixtures/tests.
pub struct ClusteredPreRootStageOutput {
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  reorder_context : OrderReorderContext
  materialized : OrderMaterializationData
}

///|
/// Graphviz parity: clustered pre-root seed stage derives grouped seed ranks
/// directly from the stage source payload before root/local materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_order_seed_stage(
  sources : ClusteredPreRootStageSources,
) -> OrderSeedGroupsOutput {
  build_order_seed_groups({
    ordering_groups_base: sources.reorder_setup.ordering_groups_base,
    base_order_index: sources.reorder_setup.base_order_index,
    order_with_vnodes: sources.reorder_setup.order_with_vnodes,
    order_with_clusters: sources.reorder_setup.order_with_clusters,
    cluster_keys: sources.cluster_keys,
    cluster_order: sources.cluster_order,
    cluster_min_rank: sources.cluster_min_rank,
    cluster_max_rank: sources.cluster_max_rank,
    vnode_clusters: sources.vnode_clusters,
    vnodes_by_rank: sources.vnodes_by_rank,
    vnode_order_keys_for_ordering: sources.reorder_setup.vnode_order_keys_for_ordering,
    order_sizes: sources.order_sizes,
    vnode_sizes: sources.vnode_sizes,
    skeleton_size: sources.skeleton_size,
  })
}

///|
/// Graphviz parity: clustered pre-root materialized stage derives reorder
/// context, mapped/unmapped edges, and unconstrained seed-order overrides
/// directly from the same pre-root stage source payload.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_materialized_stage(
  sources : ClusteredPreRootStageSources,
  order_groups : Map[Int, Array[String]],
) -> ClusteredMaterializedStageOutput {
  let reorder_context = build_order_reorder_context({
    order_groups,
    nlist_order: sources.reorder_setup.class2_data.nlist_order,
    gdnlist_order: sources.reorder_setup.gdnlist_order,
    node_order: sources.node_order,
    real_nodes: sources.real_nodes,
    has_clusters: sources.has_clusters,
    base_order_index: sources.reorder_setup.base_order_index,
    rank_same_groups: sources.rank_same_groups,
    rank_same_order: sources.rank_same_order,
    port_edge_nodes: sources.port_edge_nodes,
  })
  let materialized = build_order_materialization_data({
    nlist_order: sources.reorder_setup.class2_data.nlist_order,
    order_edges_by_tail: sources.reorder_setup.class2_data.order_edges_by_tail,
    order_graph: reorder_context.order_graph,
    order_node_map: reorder_context.order_node_map,
    order_edges_by_tail_unmapped: sources.reorder_setup.class2_data.order_edges_by_tail_unmapped,
    order_graph_unmapped: reorder_context.order_graph_unmapped,
    order_node_map_unmapped: reorder_context.order_node_map_unmapped,
    order_nodes: reorder_context.order_nodes,
    edge_creation_order: sources.reorder_setup.class2_data.edge_creation_order,
    flat_constraints: sources.flat_constraints,
  })
  // Graphviz parity: Graphviz neighbor maps and flat constraints are derived
  // before unconstrained-node seed-order overrides for build_ranks seeding.
  apply_unconstrained_order_overrides(
    sources.reorder_setup.gdnlist_order,
    sources.real_nodes,
    reorder_context.order_nodes,
    materialized.graphviz_out_neighbors,
    materialized.graphviz_in_neighbors,
    sources.rank_same_groups,
    sources.edge_tail,
    sources.edge_head,
    sources.nodes,
    sources.intercluster_keys,
    reorder_context.order_node_order,
  )
  { reorder_context, materialized }
}

///|
/// Graphviz parity: clustered pre-root stage keeps order-group seed expansion,
/// reorder-context assembly, and mapped/unmapped edge materialization in fixed
/// order before root/finalize phases.
/// Do not change behavior without updating fixtures/tests.
pub fn run_clustered_pre_root_stage_from_sources(
  sources : ClusteredPreRootStageSources,
) -> ClusteredPreRootStageOutput {
  let order_seed_stage = build_clustered_order_seed_stage(sources)
  let materialized_stage = build_clustered_materialized_stage(
    sources,
    order_seed_stage.order_groups,
  )
  {
    order_groups: order_seed_stage.order_groups,
    order_sizes_out: order_seed_stage.order_sizes_out,
    order_cluster_keys: order_seed_stage.order_cluster_keys,
    order_cluster_skeleton: order_seed_stage.order_cluster_skeleton,
    reorder_context: materialized_stage.reorder_context,
    materialized: materialized_stage.materialized,
  }
}

