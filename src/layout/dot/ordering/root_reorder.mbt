///|
/// Ordering domain: root-cluster reorder input assembly helpers used by
/// clustered root-rank-order orchestration.

///|
/// Graphviz parity: root cluster reorder seeds tail order from current nlist,
/// replacing cluster members with rank-qualified skeleton names and deduping.
/// Do not change behavior without updating fixtures/tests.
fn build_root_tail_order_seed(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Array[String] {
  let tail_order_root : Array[String] = []
  let tail_root_seen : Map[String, Bool] = Map::new()
  for name in nlist_order {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster != "" {
      let rank = flat_constraint_rank_or_zero(ranks, name)
      let skel = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      append_creation_name(
        tail_order_root,
        tail_root_seen,
        skel,
      )
    } else {
      append_creation_name(
        tail_order_root,
        tail_root_seen,
        name,
      )
    }
  }
  tail_order_root
}

///|
/// Graphviz parity: root tail visit order places source tails (no incoming
/// edges) first while preserving original deduped tail sequence order.
/// Do not change behavior without updating fixtures/tests.
fn build_root_source_first_tail_order(
  tail_order_root : Array[String],
  root_nodes : Array[String],
  root_edge_creation_order : Array[(String, String)],
) -> Array[String] {
  let root_has_in : Map[String, Bool] = Map::new()
  for name in root_nodes {
    root_has_in[name] = false
  }
  for edge in root_edge_creation_order {
    let (_tail, head) = edge
    if root_has_in.get(head) is Some(_) {
      root_has_in[head] = true
    }
  }
  let root_tail_order : Array[String] = []
  let root_tail_seen : Map[String, Bool] = Map::new()
  for name in tail_order_root {
    if root_has_in.get(name) == Some(false) {
      append_creation_name(
        root_tail_order,
        root_tail_seen,
        name,
      )
    }
  }
  for name in tail_order_root {
    append_creation_name(
      root_tail_order,
      root_tail_seen,
      name,
    )
  }
  root_tail_order
}

///|
/// Graphviz parity: root GD_nlist output keeps only materialized root nodes,
/// then appends any missing root names in root_nodes order.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_nlist_order(
  root_nlist_full : Array[String],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
) -> Array[String] {
  let root_nlist_order : Array[String] = []
  let root_seen : Map[String, Bool] = Map::new()
  for name in root_nlist_full {
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
  root_nlist_order
}

///|
/// Graphviz parity: root cluster reorder GD_nlist keeps skeleton/root tail
/// sequence from input order, prioritizes source tails, then rebuilds nlist via
/// edge creation order while appending any missing root nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_root_nlist_order(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
) -> Array[String] {
  let tail_order_root =
    build_root_tail_order_seed(
      nlist_order,
      cluster_keys,
      ranks,
    )
  let root_edge_creation_order =
    merge_edge_creation_sequences(
      skeleton_edge_creation,
      root_edge_creation,
    )
  let root_tail_order =
    build_root_source_first_tail_order(
      tail_order_root,
      root_nodes,
      root_edge_creation_order,
    )
  let root_nlist_full =
    @shared.build_graphviz_nlist_order_from_edges(
      root_tail_order,
      root_nodes,
      root_edge_creation_order,
      flat_rank_constraints,
    )
  finalize_root_nlist_order(
    root_nlist_full,
    root_nodes,
    root_node_map,
  )
}

///|
/// Graphviz parity: root-vnode set for root cluster reorder includes only
/// edge-vnodes on edges crossing cluster boundaries.
fn collect_root_vnodes(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Bool] {
  let root_vnodes : Map[String, Bool] = Map::new()
  if !order_with_vnodes {
    return root_vnodes
  }
  let mut edge_idx = 0
  for edge in edges {
    let (tail, head) =
      edge_endpoints_at(
        edge,
        edge_idx,
        edge_tail,
        edge_head,
      )
    let tail_cluster = cluster_key_or_empty(cluster_keys, tail)
    let head_cluster = cluster_key_or_empty(cluster_keys, head)
    if tail_cluster != head_cluster {
      let vnodes = edge_vnodes.get(@shared.edge_vnode_key(edge)).unwrap_or_default()
      for vnode in vnodes {
        root_vnodes[vnode] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  root_vnodes
}

///|
/// Graphviz parity: root mincross vnode inputs keep only root-vnodes from
/// vnode rank buckets and vnode-order key map.
fn build_root_vnode_inputs(
  order_with_vnodes : Bool,
  root_vnodes : Map[String, Bool],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> (Map[Int, Array[String]], Map[String, Double]) {
  let root_vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let root_vnode_order_keys : Map[String, Double] = Map::new()
  if !order_with_vnodes {
    return (root_vnodes_by_rank, root_vnode_order_keys)
  }
  for rank, names in vnodes_by_rank {
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
  (root_vnodes_by_rank, root_vnode_order_keys)
}

///|
/// Graphviz parity: root reorder rank filtering keeps root-cluster skeletons
/// plus root real nodes, and keeps edge-vnodes only when marked root-vnode.
/// Do not change behavior without updating fixtures/tests.
fn should_keep_root_reorder_name(
  name : String,
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  root_vnodes : Map[String, Bool],
) -> Bool {
  let cluster = cluster_key_or_empty(order_cluster_keys, name)
  let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
  if !is_skeleton && cluster != "" {
    return false
  }
  if name.has_prefix(EDGE_VNODE_PREFIX) && root_vnodes.get(name) != Some(true) {
    return false
  }
  true
}

///|
/// Graphviz parity: root cluster reorder groups keep root/skeleton base order
/// and optionally merge only root-vnodes into rank groups using filtered vnode
/// keys/rank buckets from root-mincross inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_groups(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> Map[Int, Array[String]] {
  let root_vnodes =
    collect_root_vnodes(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
    )
  // Graphviz parity: root cluster reorder base groups keep only root/skeleton
  // nodes, and include edge-vnodes only when flagged as root-vnodes.
  let root_groups_base : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = order_groups_for_mincross.get(rank).unwrap_or_default()
    let root_names : Array[String] = []
    for name in names {
      if should_keep_root_reorder_name(
        name,
        order_cluster_keys,
        order_cluster_skeleton,
        root_vnodes,
      ) {
        root_names.push(name)
      }
    }
    if root_names.length() > 0 {
      root_groups_base[rank] = root_names
    }
  }
  let root_order_index = build_order_index(root_groups_base)
  let (root_vnodes_by_rank, root_vnode_order_keys) =
    build_root_vnode_inputs(
      order_with_vnodes,
      root_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
    )
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
}

///|
/// Graphviz parity: root cluster-rank-order prep payload keeps root
/// groups/edges/node-order values unchanged.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootClusterReorderInputs {
  root_groups : Map[Int, Array[String]]
  root_rank_keys : Array[Int]
  root_edges_out : Array[@cgraph.Edge]
  root_edge_tail_out : Array[String]
  root_edge_head_out : Array[String]
  root_edge_tail_port_x : Array[Double]
  root_edge_head_port_x : Array[Double]
  root_edge_tail_port_order : Array[Double]
  root_edge_head_port_order : Array[Double]
  root_parents : Map[String, Array[String]]
  root_children : Map[String, Array[String]]
  root_edge_order : Map[String, Int]
  root_node_order : Map[String, Int]
}

///|
/// Graphviz parity: root cluster-reorder source bundle keeps the exact
/// root/mincross input snapshots passed through context + edge stages.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootReorderBuildSources {
  order_with_vnodes : Bool
  order_rank_keys : Array[Int]
  order_groups_for_mincross : Map[Int, Array[String]]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  cluster_keys : Map[String, String]
  edge_vnodes : Map[String, Array[String]]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_order_keys_for_ordering : Map[String, Double]
  nlist_order : Array[String]
  ranks : Map[String, Int]
  skeleton_edge_creation : Array[(String, String)]
  root_edge_creation : Array[(String, String)]
  flat_rank_constraints : Map[String, Bool]
}


///|
/// Graphviz parity: root reorder context keeps root groups, ranks, graph
/// handles, GD_nlist walk order, and seeded node-order map before root-only
/// edge materialization.
priv struct RootClusterReorderContext {
  root_groups : Map[Int, Array[String]]
  root_rank_keys : Array[Int]
  root_ranks : Map[String, Int]
  root_nodes : Array[String]
  root_graph : @cgraph.Graph
  root_node_map : Map[String, @cgraph.Node]
  root_nlist_order : Array[String]
  root_node_order : Map[String, Int]
}

///|
/// Graphviz parity: root/ReMincross node-order seeding follows GD_nlist order
/// first, then fills missing names from current rank-group order index.
fn build_root_reorder_node_order(
  root_nlist_order : Array[String],
  root_node_map : Map[String, @cgraph.Node],
  root_groups : Map[Int, Array[String]],
) -> Map[String, Int] {
  let root_node_order : Map[String, Int] = Map::new()
  let mut root_node_idx = 0
  for name in root_nlist_order {
    if root_node_map.get(name) is Some(_) {
      root_node_order[name] = root_node_idx
      root_node_idx = root_node_idx + 1
    }
  }
  let root_order_index = build_order_index(root_groups)
  for name, idx in root_order_index {
    if root_node_order.get(name) is None {
      root_node_order[name] = idx
    }
  }
  root_node_order
}

///|
/// Graphviz parity: root edge-port arrays are normalized with synthetic-endpoint
/// defaults before root mincross edge-index construction.
priv struct NormalizedRootEdgePorts {
  edge_tail_port_x_norm : Array[Double]
  edge_head_port_x_norm : Array[Double]
  edge_tail_port_order_norm : Array[Double]
  edge_head_port_order_norm : Array[Double]
}

///|
/// Graphviz parity: root reorder edge bundle keeps tail-sequence materialized
/// edges, synthetic port normalization, and edge index/order maps together.
/// Do not change behavior without updating fixtures/tests.
priv struct RootReorderEdgeData {
  root_edges_out : Array[@cgraph.Edge]
  root_edge_tail_out : Array[String]
  root_edge_head_out : Array[String]
  root_edge_tail_port_x : Array[Double]
  root_edge_head_port_x : Array[Double]
  root_edge_tail_port_order : Array[Double]
  root_edge_head_port_order : Array[Double]
  root_parents : Map[String, Array[String]]
  root_children : Map[String, Array[String]]
  root_edge_order : Map[String, Int]
}

///|
/// Graphviz parity: root edge-port arrays are normalized with synthetic-endpoint
/// defaults before root mincross edge-index construction.
fn normalize_root_edge_ports(
  edge_tail_out : Array[String],
  edge_head_out : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
) -> NormalizedRootEdgePorts {
  let edge_tail_port_x_norm : Array[Double] = []
  let edge_head_port_x_norm : Array[Double] = []
  let edge_tail_port_order_norm : Array[Double] = []
  let edge_head_port_order_norm : Array[Double] = []
  let mut edge_idx = 0
  while edge_idx < edge_tail_out.length() {
    let tail = edge_tail_out[edge_idx]
    let head = edge_head_out[edge_idx]
    let tail_port_x_raw = edge_tail_port_x[edge_idx]
    let head_port_x_raw = edge_head_port_x[edge_idx]
    let tail_port_order_raw = edge_tail_port_order[edge_idx]
    let head_port_order_raw = edge_head_port_order[edge_idx]
    let (tail_port_x, head_port_x, tail_port_order, head_port_order) =
      normalize_synthetic_ports(
        tail,
        head,
        tail_port_x_raw,
        head_port_x_raw,
        tail_port_order_raw,
        head_port_order_raw,
      )
    edge_tail_port_x_norm.push(tail_port_x)
    edge_head_port_x_norm.push(head_port_x)
    edge_tail_port_order_norm.push(tail_port_order)
    edge_head_port_order_norm.push(head_port_order)
    edge_idx = edge_idx + 1
  }
  {
    edge_tail_port_x_norm,
    edge_head_port_x_norm,
    edge_tail_port_order_norm,
    edge_head_port_order_norm,
  }
}

///|
/// Graphviz parity: root reorder edge bundle keeps tail-sequence materialized
/// edges, synthetic port normalization, and edge index/order maps in one stage.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_edge_data(
  root_context : RootClusterReorderContext,
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> RootReorderEdgeData {
  let root_materialized =
    collect_order_edges_for_tails(
      root_context.root_nlist_order,
      order_edges_by_tail_root,
      root_context.root_graph,
      root_context.root_node_map,
    )
  let normalized_root_ports =
    normalize_root_edge_ports(
      root_materialized.order_edge_tail_out,
      root_materialized.order_edge_head_out,
      root_materialized.order_edge_tail_port_x,
      root_materialized.order_edge_head_port_x,
      root_materialized.order_edge_tail_port_order,
      root_materialized.order_edge_head_port_order,
    )
  let root_edge_indices =
    build_edge_indices_and_order(
      root_context.root_nodes,
      root_materialized.order_edge_tail_out,
      root_materialized.order_edge_head_out,
      root_context.root_ranks,
      root_materialized.order_edges_out,
    )
  {
    root_edges_out: root_materialized.order_edges_out,
    root_edge_tail_out: root_materialized.order_edge_tail_out,
    root_edge_head_out: root_materialized.order_edge_head_out,
    root_edge_tail_port_x: normalized_root_ports.edge_tail_port_x_norm,
    root_edge_head_port_x: normalized_root_ports.edge_head_port_x_norm,
    root_edge_tail_port_order: normalized_root_ports.edge_tail_port_order_norm,
    root_edge_head_port_order: normalized_root_ports.edge_head_port_order_norm,
    root_parents: root_edge_indices.parents,
    root_children: root_edge_indices.children,
    root_edge_order: root_edge_indices.edge_order,
  }
}

///|
/// Graphviz parity: root reorder context is built from root-only filtered rank
/// groups and shared GD_nlist walk order before root mincross edge bundle.
fn build_root_reorder_context(
  sources : RootReorderBuildSources,
) -> RootClusterReorderContext {
  let root_groups =
    build_root_reorder_groups(
      sources.order_with_vnodes,
      sources.order_rank_keys,
      sources.order_groups_for_mincross,
      sources.order_cluster_keys,
      sources.order_cluster_skeleton,
      sources.edges,
      sources.edge_tail,
      sources.edge_head,
      sources.cluster_keys,
      sources.edge_vnodes,
      sources.vnodes_by_rank,
      sources.vnode_order_keys_for_ordering,
    )
  let root_rank_keys = collect_rank_keys(root_groups)
  let root_ranks = build_node_ranks(root_groups)
  let root_nodes = build_order_nodes_from_groups(root_groups, root_rank_keys)
  let root_graph_output =
    build_order_graph_and_nodes("order_root", root_nodes)
  let root_graph = root_graph_output.order_graph
  let root_node_map = root_graph_output.order_node_map
  // Graphviz parity: root cluster-reorder derives root GD_nlist walk order and
  // root-node order map from the same root graph/group membership snapshot.
  let root_nlist_order =
    build_root_nlist_order(
      sources.nlist_order,
      sources.cluster_keys,
      sources.ranks,
      root_nodes,
      root_node_map,
      sources.skeleton_edge_creation,
      sources.root_edge_creation,
      sources.flat_rank_constraints,
    )
  let root_node_order =
    build_root_reorder_node_order(
      root_nlist_order,
      root_node_map,
      root_groups,
    )
  {
    root_groups,
    root_rank_keys,
    root_ranks,
    root_nodes,
    root_graph,
    root_node_map,
    root_nlist_order,
    root_node_order,
  }
}

///|
/// Graphviz parity: root reorder context + root edge bundle are materialized
/// before root-only mincross in cluster-order phase.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_reorder_inputs(
  sources : RootReorderBuildSources,
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> RootClusterReorderInputs {
  let root_context =
    build_root_reorder_context(sources)
  let root_edge_data =
    build_root_reorder_edge_data(
      root_context,
      order_edges_by_tail_root,
    )
  {
    root_groups: root_context.root_groups,
    root_rank_keys: root_context.root_rank_keys,
    root_edges_out: root_edge_data.root_edges_out,
    root_edge_tail_out: root_edge_data.root_edge_tail_out,
    root_edge_head_out: root_edge_data.root_edge_head_out,
    root_edge_tail_port_x: root_edge_data.root_edge_tail_port_x,
    root_edge_head_port_x: root_edge_data.root_edge_head_port_x,
    root_edge_tail_port_order: root_edge_data.root_edge_tail_port_order,
    root_edge_head_port_order: root_edge_data.root_edge_head_port_order,
    root_parents: root_edge_data.root_parents,
    root_children: root_edge_data.root_children,
    root_edge_order: root_edge_data.root_edge_order,
    root_node_order: root_context.root_node_order,
  }
}

///|
/// Graphviz parity: root cluster-rank-order phase output keeps root-rank keys
/// and ordered-root groups bundled for rank-transfer dispatch.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootRankOrderPhaseOutput {
  root_rank_keys : Array[Int]
  ordered_root : Map[Int, Array[String]]
}

///|
/// Graphviz parity: root cluster-rank-order phase context keeps clustered
/// dispatch snapshots unchanged before attaching root reorder outputs.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootRankOrderPhaseContext {
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  order_sizes_out : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: root cluster-rank-order phase input bundle keeps root
/// reorder outputs and clustered dispatch context values unchanged.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootRankOrderPhaseInputs {
  root_reorder_output : RootClusterReorderInputs
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  order_sizes_out : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: root cluster-rank-order phase inputs attach root reorder
/// outputs to the unchanged clustered context snapshot.
/// Do not change behavior without updating fixtures/tests.
fn build_root_rank_order_phase_inputs(
  root_reorder_output : RootClusterReorderInputs,
  context : RootRankOrderPhaseContext,
) -> RootRankOrderPhaseInputs {
  {
    root_reorder_output,
    order_cluster_keys: context.order_cluster_keys,
    order_cluster_skeleton: context.order_cluster_skeleton,
    rank_same_groups: context.rank_same_groups,
    rank_same_order: context.rank_same_order,
    order_sizes_out: context.order_sizes_out,
    nodesep_pt: context.nodesep_pt,
    has_edge_labels: context.has_edge_labels,
    port_order_positions: context.port_order_positions,
    port_order_contrib: context.port_order_contrib,
    order_flat_constraints: context.order_flat_constraints,
    graphviz_flip: context.graphviz_flip,
  }
}

///|
/// Graphviz parity: root cluster-rank-order call payload preserves the exact
/// argument order expected by reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootRankOrderCallInputs {
  root_rank_keys : Array[Int]
  root_groups : Map[Int, Array[String]]
  root_edges_out : Array[@cgraph.Edge]
  root_edge_tail_out : Array[String]
  root_edge_head_out : Array[String]
  root_edge_tail_port_x : Array[Double]
  root_edge_head_port_x : Array[Double]
  root_edge_tail_port_order : Array[Double]
  root_edge_head_port_order : Array[Double]
  root_parents : Map[String, Array[String]]
  root_children : Map[String, Array[String]]
  order_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  root_edge_order : Map[String, Int]
  root_node_order : Map[String, Int]
  order_sizes_out : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
}

fn has_multiple_non_empty_cluster_keys(
  order_cluster_keys : Map[String, String],
) -> Bool {
  let seen_cluster_keys : Map[String, Bool] = Map::new()
  for _name, key in order_cluster_keys {
    if key == "" || seen_cluster_keys.get(key) is Some(_) {
      continue
    }
    seen_cluster_keys[key] = true
    if seen_cluster_keys.length() > 1 {
      return true
    }
  }
  false
}

///|
/// Graphviz parity: root-only graphviz_flip gating enables root flip only when
/// capture-fixture mode is active or when at least two non-empty cluster keys
/// exist in the current ordering key map.
fn should_enable_root_flip(
  graphviz_flip : Bool,
  order_cluster_keys : Map[String, String],
) -> Bool {
  if !graphviz_flip {
    return false
  }
  if @sys.get_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE") is Some(_) {
    return true
  }
  has_multiple_non_empty_cluster_keys(order_cluster_keys)
}

fn build_root_rank_order_call_inputs(
  inputs : RootRankOrderPhaseInputs,
) -> RootRankOrderCallInputs {
  let root_reorder_output = inputs.root_reorder_output
  {
    root_rank_keys: root_reorder_output.root_rank_keys,
    root_groups: root_reorder_output.root_groups,
    root_edges_out: root_reorder_output.root_edges_out,
    root_edge_tail_out: root_reorder_output.root_edge_tail_out,
    root_edge_head_out: root_reorder_output.root_edge_head_out,
    root_edge_tail_port_x: root_reorder_output.root_edge_tail_port_x,
    root_edge_head_port_x: root_reorder_output.root_edge_head_port_x,
    root_edge_tail_port_order: root_reorder_output.root_edge_tail_port_order,
    root_edge_head_port_order: root_reorder_output.root_edge_head_port_order,
    root_parents: root_reorder_output.root_parents,
    root_children: root_reorder_output.root_children,
    order_cluster_keys: inputs.order_cluster_keys,
    rank_same_groups: inputs.rank_same_groups,
    rank_same_order: inputs.rank_same_order,
    root_edge_order: root_reorder_output.root_edge_order,
    root_node_order: root_reorder_output.root_node_order,
    order_sizes_out: inputs.order_sizes_out,
    nodesep_pt: inputs.nodesep_pt,
    has_edge_labels: inputs.has_edge_labels,
    port_order_positions: inputs.port_order_positions,
    port_order_contrib: inputs.port_order_contrib,
    order_cluster_skeleton: inputs.order_cluster_skeleton,
    order_flat_constraints: inputs.order_flat_constraints,
  }
}

///|
/// Graphviz parity: graphviz_flip root output merge replays ordered root
/// membership from root mincross back into seeded root rank groups.
fn build_graphviz_flip_merged_root_groups(
  root_rank_keys : Array[Int],
  root_groups : Map[Int, Array[String]],
  ordered_root : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let ordered_root_nodes =
    build_order_nodes_from_groups(ordered_root, root_rank_keys)
  let ordered_root_mincross_nodes =
    build_node_membership_set(ordered_root_nodes)
  merge_root_mincross_groups(
    root_rank_keys,
    root_groups,
    ordered_root,
    ordered_root_mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: root rank-order output merge keeps non-flip output as-is,
/// and only replays root mincross membership back into seeded groups when
/// graphviz_flip was requested for this pass.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_rank_order_phase_output(
  root_rank_keys : Array[Int],
  root_groups : Map[Int, Array[String]],
  ordered_root : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
) -> RootRankOrderPhaseOutput {
  if !graphviz_flip {
    return {
      root_rank_keys,
      ordered_root,
    }
  }
  let merged_ordered_root =
    build_graphviz_flip_merged_root_groups(
      root_rank_keys,
      root_groups,
      ordered_root,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  {
    root_rank_keys,
    ordered_root: merged_ordered_root,
  }
}

///|
/// Graphviz parity: root cluster-rank-order phase consumes root reorder tuple
/// and dispatch context without reordering Graphviz call arguments.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_rank_order_phase(
  inputs : RootRankOrderPhaseInputs,
  run_call : (RootRankOrderCallInputs, Bool) -> Map[Int, Array[String]],
) -> RootRankOrderPhaseOutput {
  // Graphviz parity: root-only reorder pass uses the same reorder_rank_groups
  // path as cluster-phase root bucket ordering, with root-flip guarding.
  let root_graphviz_flip =
    should_enable_root_flip(
      inputs.graphviz_flip,
      inputs.order_cluster_keys,
    )
  let call_inputs = build_root_rank_order_call_inputs(inputs)
  let ordered_root = run_call(call_inputs, root_graphviz_flip)
  finalize_root_rank_order_phase_output(
    call_inputs.root_rank_keys,
    call_inputs.root_groups,
    ordered_root,
    inputs.order_cluster_keys,
    inputs.order_cluster_skeleton,
    inputs.graphviz_flip,
  )
}

///|
/// Graphviz parity: clustered root phase runs root-only edge rematerialization
/// and root rank-order reorder in one deterministic call sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_reorder_and_rank_order_phase(
  root_reorder_sources : RootReorderBuildSources,
  root_rank_order_context : RootRankOrderPhaseContext,
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  run_call : (RootRankOrderCallInputs, Bool) -> Map[Int, Array[String]],
) -> (RootClusterReorderInputs, RootRankOrderPhaseOutput) {
  let root_reorder_output =
    build_root_reorder_inputs(root_reorder_sources, order_edges_by_tail_root)
  let root_rank_order_inputs =
    build_root_rank_order_phase_inputs(
      root_reorder_output,
      root_rank_order_context,
    )
  let root_rank_order_phase_output =
    run_root_rank_order_phase(root_rank_order_inputs, run_call)
  (root_reorder_output, root_rank_order_phase_output)
}
