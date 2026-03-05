///|
/// Ordering domain: root-mincross shared helpers used by root reorder and
/// component-wise root mincross preparation.

///|
/// Graphviz parity: membership checks for mincross subgraph are exact-name set
/// lookups over the filtered node list.
/// Do not change behavior without updating fixtures/tests.
pub fn build_node_membership_set(names : Array[String]) -> Map[String, Bool] {
  let membership : Map[String, Bool] = Map::new()
  for name in names {
    membership[name] = true
  }
  membership
}

///|
priv struct SyntheticPortValues {
  tail_port_x : Double
  head_port_x : Double
  tail_port_order : Double
  head_port_order : Double
}

///|
/// Graphviz parity: synthetic mincross endpoints keep default port values at
/// zero when Graphviz treats the endpoint pair as synthetic-only.
pub fn normalize_synthetic_ports(
  tail : String,
  head : String,
  tail_port_x_raw : Double,
  head_port_x_raw : Double,
  tail_port_order_raw : Double,
  head_port_order_raw : Double,
) -> (Double, Double, Double, Double) {
  // Graphviz parity: synthetic ordering nodes keep default mincross ports
  // unless a non-default port survives edge materialization.
  let tail_is_skeleton = tail.has_prefix(CLUSTER_SKELETON_PREFIX)
  let head_is_skeleton = head.has_prefix(CLUSTER_SKELETON_PREFIX)
  let synthetic_endpoint =
    is_edge_vnode_name(tail) || is_edge_vnode_name(head) ||
    tail_is_skeleton || head_is_skeleton
  let defaultish_x =
    (tail_port_x_raw == 0.0 || tail_port_x_raw == 0.5) &&
    (head_port_x_raw == 0.0 || head_port_x_raw == 0.5)
  let zero_synthetic_defaults =
    synthetic_endpoint &&
    (
      (tail_is_skeleton && head_is_skeleton) ||
      (defaultish_x && tail_port_order_raw == 0.0 && head_port_order_raw == 0.0)
    )
  let normalized : SyntheticPortValues =
    if !zero_synthetic_defaults {
      {
        tail_port_x: tail_port_x_raw,
        head_port_x: head_port_x_raw,
        tail_port_order: tail_port_order_raw,
        head_port_order: head_port_order_raw,
      }
    } else {
      {
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      }
    }
  (
    normalized.tail_port_x,
    normalized.head_port_x,
    normalized.tail_port_order,
    normalized.head_port_order,
  )
}

///|
pub(all) struct MincrossOrderEdgesOutput {
  order_edges_out_mincross : Array[@cgraph.Edge]
  order_edge_tail_out_mincross : Array[String]
  order_edge_head_out_mincross : Array[String]
  order_edge_tail_port_x_mincross : Array[Double]
  order_edge_head_port_x_mincross : Array[Double]
  order_edge_tail_port_order_mincross : Array[Double]
  order_edge_head_port_order_mincross : Array[Double]
}

///|
/// Graphviz parity: root mincross edge set keeps only edges whose endpoints are
/// both in the filtered node set, preserving edge and port-order sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_mincross_order_edges(
  mincross_nodes : Map[String, Bool],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> MincrossOrderEdgesOutput {
  let order_edges_out_mincross : Array[@cgraph.Edge] = []
  let order_edge_tail_out_mincross : Array[String] = []
  let order_edge_head_out_mincross : Array[String] = []
  let order_edge_tail_port_x_mincross : Array[Double] = []
  let order_edge_head_port_x_mincross : Array[Double] = []
  let order_edge_tail_port_order_mincross : Array[Double] = []
  let order_edge_head_port_order_mincross : Array[Double] = []
  let mut edge_idx = 0
  while edge_idx < order_edges_out.length() {
    let tail = order_edge_tail_out[edge_idx]
    let head = order_edge_head_out[edge_idx]
    if mincross_nodes.get(tail) is Some(_) && mincross_nodes.get(head) is Some(_) {
      let tail_port_x_raw = order_edge_tail_port_x[edge_idx]
      let head_port_x_raw = order_edge_head_port_x[edge_idx]
      let tail_port_order_raw = order_edge_tail_port_order[edge_idx]
      let head_port_order_raw = order_edge_head_port_order[edge_idx]
      let (tail_port_x, head_port_x, tail_port_order, head_port_order) =
        normalize_synthetic_ports(
          tail,
          head,
          tail_port_x_raw,
          head_port_x_raw,
          tail_port_order_raw,
          head_port_order_raw,
        )
      order_edges_out_mincross.push(order_edges_out[edge_idx])
      order_edge_tail_out_mincross.push(tail)
      order_edge_head_out_mincross.push(head)
      order_edge_tail_port_x_mincross.push(tail_port_x)
      order_edge_head_port_x_mincross.push(head_port_x)
      order_edge_tail_port_order_mincross.push(tail_port_order)
      order_edge_head_port_order_mincross.push(head_port_order)
    }
    edge_idx = edge_idx + 1
  }
  {
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
  }
}

///|
/// Graphviz parity: after root-only mincross, reordered root/skeleton nodes are
/// merged back into seeded rank lists by replacing only filtered positions.
/// Do not change behavior without updating fixtures/tests.
pub fn merge_root_mincross_groups(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = seeded_groups.get(rank).unwrap_or_default()
    let replacements = ordered_mincross.get(rank).unwrap_or_default()
    if replacements.length() == 0 {
      merged[rank] = names.copy()
      continue
    }
    let attached_by_skeleton =
      build_rank_attached_by_skeleton(
        names,
        order_cluster_keys,
        order_cluster_skeleton,
        mincross_nodes,
      )
    // Graphviz parity: when root mincross returns [root, skeleton] in a
    // single-root rank, keep the attached cluster node in front via positional
    // replacement (matches biological rank handoff in Graphviz).
    let should_use_positional_merge =
      should_merge_root_positions(
        replacements,
        order_cluster_skeleton,
        attached_by_skeleton,
      )
    if should_use_positional_merge {
      merged[rank] =
        merge_rank_with_positional_replacements(
          names,
          replacements,
          mincross_nodes,
        )
      continue
    }
    merged[rank] =
      merge_rank_with_attached_skeleton_replacements(
        names,
        replacements,
        attached_by_skeleton,
        order_cluster_skeleton,
      )
  }
  merged
}

///|
/// Graphviz parity: root ReMincross keeps only root + cluster-skeleton names
/// from seeded build_ranks groups; cluster-internal names stay cluster-local.
/// Do not change behavior without updating fixtures/tests.
pub fn filter_root_mincross_seeded_groups_for_clusters(
  seeded_groups : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let filtered : Map[Int, Array[String]] = Map::new()
  for rank, names in seeded_groups {
    let list : Array[String] = []
    for name in names {
      let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
      let cluster = order_cluster_keys.get(name).unwrap_or_default()
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

///|
pub(all) struct RootMincrossEdgeBundle {
  order_edges_out_mincross : Array[@cgraph.Edge]
  order_edge_tail_out_mincross : Array[String]
  order_edge_head_out_mincross : Array[String]
  order_edge_tail_port_x_mincross : Array[Double]
  order_edge_head_port_x_mincross : Array[Double]
  order_edge_tail_port_order_mincross : Array[Double]
  order_edge_head_port_order_mincross : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  edge_order : Map[String, Int]
}

///|
/// Graphviz parity: root ReMincross materializes filtered root/skeleton edges
/// before building parent/child + edge-order indices.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_mincross_edge_bundle(
  mincross_nodes : Map[String, Bool],
  order_nodes_for_mincross : Array[String],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_ranks : Map[String, Int],
) -> RootMincrossEdgeBundle {
  let mincross_edges_output =
    collect_mincross_order_edges(
      mincross_nodes,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
    )
  let edge_indices =
    build_edge_indices_and_order(
      order_nodes_for_mincross,
      mincross_edges_output.order_edge_tail_out_mincross,
      mincross_edges_output.order_edge_head_out_mincross,
      order_ranks,
      mincross_edges_output.order_edges_out_mincross,
    )
  {
    order_edges_out_mincross: mincross_edges_output.order_edges_out_mincross,
    order_edge_tail_out_mincross:
      mincross_edges_output.order_edge_tail_out_mincross,
    order_edge_head_out_mincross:
      mincross_edges_output.order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross:
      mincross_edges_output.order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross:
      mincross_edges_output.order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross:
      mincross_edges_output.order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross:
      mincross_edges_output.order_edge_head_port_order_mincross,
    parents: edge_indices.parents,
    children: edge_indices.children,
    edge_order: edge_indices.edge_order,
  }
}

///|
/// Graphviz parity: vnode preferred-position hints are forwarded only for edge
/// vnodes when vnode ordering is enabled in root ReMincross.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_vnode_preferred_positions(
  order_with_vnodes : Bool,
  vnode_order_keys_for_ordering : Map[String, Double],
) -> Map[String, Double] {
  if !order_with_vnodes {
    return Map::new()
  }
  let filtered : Map[String, Double] = Map::new()
  for name, value in vnode_order_keys_for_ordering {
    if is_edge_vnode_name(name) {
      filtered[name] = value
    }
  }
  filtered
}

///|
pub(all) struct RootRankReorderCallData {
  order_rank_keys_for_mincross : Array[Int]
  mincross_nodes : Map[String, Bool]
  mincross_edge_data : RootMincrossEdgeBundle
  root_rank_reorder_inputs : RootRankReorderInputs
}

///|
pub(all) struct RootReorderPassResult {
  ordered_mincross : Map[Int, Array[String]]
  reorder_call_data : RootRankReorderCallData
}

///|
pub(all) struct RootMincrossReorderResult {
  order_groups_for_mincross : Map[Int, Array[String]]
  ordered : Map[Int, Array[String]]
  reorder_call_data : RootRankReorderCallData
}

///|
pub(all) struct RootMincrossReorderInputs {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  seeded_groups : Map[Int, Array[String]]
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  vnode_order_keys_for_ordering : Map[String, Double]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: root ReMincross reorder input context keeps pre-root
/// materialized ordering snapshots unchanged before seeded group attachment.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootMincrossReorderBuildContext {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  vnode_order_keys_for_ordering : Map[String, Double]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: root ReMincross input-source bundle keeps seeded
/// build_ranks snapshots plus pre-root materialized ordering data unchanged
/// before root-only reorder input assembly.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootMincrossReorderInputsBuildSources {
  reorder_setup : OrderingReorderSetup
  reorder_context : OrderReorderContext
  materialized : OrderMaterializationData
  order_groups : Map[Int, Array[String]]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_sizes_out : Map[String, @shared.NodeSize]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: root ReMincross inputs are assembled from one pre-root
/// snapshot by first seeding build_ranks groups then attaching root reorder
/// context/state without changing Graphviz call order.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_mincross_reorder_inputs_from_sources(
  sources : RootMincrossReorderInputsBuildSources,
) -> RootMincrossReorderInputs {
  let seeded_context : SeededReorderBuildContext = {
    order_rank_keys: sources.reorder_context.order_rank_keys,
    order_groups: sources.order_groups,
    order_edge_tail_out: sources.materialized.order_edge_tail_out,
    order_edge_head_out: sources.materialized.order_edge_head_out,
    order_ranks: sources.reorder_context.order_ranks,
    order_node_order: sources.reorder_context.order_node_order,
    order_cluster_keys: sources.order_cluster_keys,
    order_cluster_skeleton: sources.order_cluster_skeleton,
    order_flat_constraints: sources.materialized.order_flat_constraints,
    graphviz_flip: sources.reorder_setup.graphviz_flip,
    graphviz_out_neighbors: sources.materialized.graphviz_out_neighbors,
    graphviz_in_neighbors: sources.materialized.graphviz_in_neighbors,
    order_edges_out: sources.materialized.order_edges_out,
    order_edge_tail_port_x: sources.materialized.order_edge_tail_port_x,
    order_edge_head_port_x: sources.materialized.order_edge_head_port_x,
    flat_rank_constraints: sources.reorder_setup.flat_rank_constraints,
  }
  let seeded_groups = build_seeded_reorder_groups(seeded_context)
  let root_reorder_context : RootMincrossReorderBuildContext = {
    order_with_clusters: sources.reorder_setup.order_with_clusters,
    order_with_vnodes: sources.reorder_setup.order_with_vnodes,
    order_rank_keys: sources.reorder_context.order_rank_keys,
    order_ranks: sources.reorder_context.order_ranks,
    order_edges_out: sources.materialized.order_edges_out,
    order_edge_tail_out: sources.materialized.order_edge_tail_out,
    order_edge_head_out: sources.materialized.order_edge_head_out,
    order_edge_tail_port_x: sources.materialized.order_edge_tail_port_x,
    order_edge_head_port_x: sources.materialized.order_edge_head_port_x,
    order_edge_tail_port_order: sources.materialized.order_edge_tail_port_order,
    order_edge_head_port_order: sources.materialized.order_edge_head_port_order,
    order_cluster_keys: sources.order_cluster_keys,
    order_cluster_skeleton: sources.order_cluster_skeleton,
    rank_same_groups: sources.rank_same_groups,
    rank_same_order: sources.rank_same_order,
    vnode_order_keys_for_ordering:
      sources.reorder_setup.vnode_order_keys_for_ordering,
    order_node_order: sources.reorder_context.order_node_order,
    order_sizes_out: sources.order_sizes_out,
    nodesep_pt: sources.nodesep_pt,
    has_edge_labels: sources.has_edge_labels,
    port_order_positions: sources.port_order_positions,
    port_order_contrib: sources.port_order_contrib,
    order_flat_constraints: sources.materialized.order_flat_constraints,
    graphviz_out_neighbors: sources.materialized.graphviz_out_neighbors,
    graphviz_in_neighbors: sources.materialized.graphviz_in_neighbors,
    graphviz_flip: sources.reorder_setup.graphviz_flip,
  }
  build_root_mincross_reorder_inputs(
    seeded_groups,
    root_reorder_context,
  )
}

///|
/// Graphviz parity: root ReMincross reorder input payload is assembled from the
/// same seeded groups + pre-root materialized snapshots before root pass call.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_mincross_reorder_inputs(
  seeded_groups : Map[Int, Array[String]],
  context : RootMincrossReorderBuildContext,
) -> RootMincrossReorderInputs {
  {
    order_with_clusters: context.order_with_clusters,
    order_with_vnodes: context.order_with_vnodes,
    seeded_groups,
    order_rank_keys: context.order_rank_keys,
    order_ranks: context.order_ranks,
    order_edges_out: context.order_edges_out,
    order_edge_tail_out: context.order_edge_tail_out,
    order_edge_head_out: context.order_edge_head_out,
    order_edge_tail_port_x: context.order_edge_tail_port_x,
    order_edge_head_port_x: context.order_edge_head_port_x,
    order_edge_tail_port_order: context.order_edge_tail_port_order,
    order_edge_head_port_order: context.order_edge_head_port_order,
    order_cluster_keys: context.order_cluster_keys,
    order_cluster_skeleton: context.order_cluster_skeleton,
    rank_same_groups: context.rank_same_groups,
    rank_same_order: context.rank_same_order,
    vnode_order_keys_for_ordering: context.vnode_order_keys_for_ordering,
    order_node_order: context.order_node_order,
    order_sizes_out: context.order_sizes_out,
    nodesep_pt: context.nodesep_pt,
    has_edge_labels: context.has_edge_labels,
    port_order_positions: context.port_order_positions,
    port_order_contrib: context.port_order_contrib,
    order_flat_constraints: context.order_flat_constraints,
    graphviz_out_neighbors: context.graphviz_out_neighbors,
    graphviz_in_neighbors: context.graphviz_in_neighbors,
    graphviz_flip: context.graphviz_flip,
  }
}

///|
/// Graphviz parity: root ReMincross stage data is assembled from one snapshot:
/// rank keys -> node membership -> filtered mincross edge bundle.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_rank_reorder_call_data(
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, @shared.NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions_source : Map[String, Double],
  order_with_vnodes : Bool,
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> RootRankReorderCallData {
  let order_rank_keys_for_mincross =
    collect_rank_keys(order_groups_for_mincross)
  let order_nodes_for_mincross =
    build_order_nodes_from_groups(
      order_groups_for_mincross,
      order_rank_keys_for_mincross,
    )
  let mincross_nodes =
    build_node_membership_set(order_nodes_for_mincross)
  let mincross_edge_data =
    build_root_mincross_edge_bundle(
      mincross_nodes,
      order_nodes_for_mincross,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      order_ranks,
    )
  let preferred_positions =
    build_root_vnode_preferred_positions(
      order_with_vnodes,
      preferred_positions_source,
    )
  let root_rank_reorder_inputs : RootRankReorderInputs =
    {
      order_rank_keys_for_mincross,
      order_groups_for_mincross,
      order_edges_out_mincross: mincross_edge_data.order_edges_out_mincross,
      order_edge_tail_out_mincross:
        mincross_edge_data.order_edge_tail_out_mincross,
      order_edge_head_out_mincross:
        mincross_edge_data.order_edge_head_out_mincross,
      order_edge_tail_port_x_mincross:
        mincross_edge_data.order_edge_tail_port_x_mincross,
      order_edge_head_port_x_mincross:
        mincross_edge_data.order_edge_head_port_x_mincross,
      order_edge_tail_port_order_mincross:
        mincross_edge_data.order_edge_tail_port_order_mincross,
      order_edge_head_port_order_mincross:
        mincross_edge_data.order_edge_head_port_order_mincross,
      parents: mincross_edge_data.parents,
      children: mincross_edge_data.children,
      order_cluster_keys,
      rank_same_groups,
      rank_same_order,
      edge_order: mincross_edge_data.edge_order,
      order_node_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      preferred_positions,
      order_cluster_skeleton,
      order_flat_constraints,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      graphviz_flip,
    }
  {
    order_rank_keys_for_mincross,
    mincross_nodes,
    mincross_edge_data,
    root_rank_reorder_inputs,
  }
}

///|
/// Graphviz parity: root ReMincross rank-reorder pass keeps input preparation
/// and reorder_rank_groups execution in the same Graphviz call sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_reorder_for_groups(
  reorder_inputs : RootMincrossReorderInputs,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> RootReorderPassResult {
  let reorder_call_data =
    build_root_rank_reorder_call_data(
      order_groups_for_mincross,
      reorder_inputs.order_edges_out,
      reorder_inputs.order_edge_tail_out,
      reorder_inputs.order_edge_head_out,
      reorder_inputs.order_edge_tail_port_x,
      reorder_inputs.order_edge_head_port_x,
      reorder_inputs.order_edge_tail_port_order,
      reorder_inputs.order_edge_head_port_order,
      reorder_inputs.order_ranks,
      reorder_inputs.order_cluster_keys,
      reorder_inputs.rank_same_groups,
      reorder_inputs.rank_same_order,
      reorder_inputs.order_node_order,
      reorder_inputs.order_sizes_out,
      reorder_inputs.nodesep_pt,
      reorder_inputs.has_edge_labels,
      reorder_inputs.port_order_positions,
      reorder_inputs.port_order_contrib,
      reorder_inputs.vnode_order_keys_for_ordering,
      reorder_inputs.order_with_vnodes,
      reorder_inputs.order_cluster_skeleton,
      reorder_inputs.order_flat_constraints,
      reorder_inputs.graphviz_out_neighbors,
      reorder_inputs.graphviz_in_neighbors,
      reorder_inputs.graphviz_flip,
    )
  let ordered_mincross =
    run_root_rank_reorder(
      reorder_call_data.root_rank_reorder_inputs,
    )
  {
    ordered_mincross,
    reorder_call_data,
  }
}

///|
/// Graphviz parity: root ReMincross input groups are cluster-filtered when
/// cluster ordering is enabled, then optionally overridden for fixture replay.
/// Do not change behavior without updating fixtures/tests.
pub fn resolve_root_mincross_input_groups(
  order_with_clusters : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_groups_override : Map[Int, Array[String]]?,
) -> Map[Int, Array[String]] {
  let order_groups_for_mincross_base =
    if !order_with_clusters {
      seeded_groups
    } else {
      // Graphviz parity: root ReMincross keeps only root and cluster-skeleton
      // nodes; cluster-internal ordering stays in cluster-local build_ranks
      // passes.
      filter_root_mincross_seeded_groups_for_clusters(
        seeded_groups,
        order_cluster_keys,
        order_cluster_skeleton,
      )
    }
  match order_groups_override {
    Some(override_groups) => clone_rank_groups(override_groups)
    None => order_groups_for_mincross_base
  }
}

///|
/// Graphviz parity: root ReMincross output merges reordered root/skeleton names
/// back to seeded groups only in cluster-order mode.
/// Do not change behavior without updating fixtures/tests.
pub fn finalize_root_mincross_ordered_groups(
  order_with_clusters : Bool,
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  if !order_with_clusters {
    return ordered_mincross
  }
  merge_root_mincross_groups(
    order_rank_keys,
    seeded_groups,
    ordered_mincross,
    mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_mincross_reorder(
  inputs : RootMincrossReorderInputs,
  order_groups_override : Map[Int, Array[String]]?,
) -> RootMincrossReorderResult {
  let order_groups_for_mincross =
    resolve_root_mincross_input_groups(
      inputs.order_with_clusters,
      inputs.seeded_groups,
      inputs.order_cluster_keys,
      inputs.order_cluster_skeleton,
      order_groups_override,
    )
  let pass_result =
    run_root_reorder_for_groups(
      inputs,
      order_groups_for_mincross,
    )
  let ordered =
    finalize_root_mincross_ordered_groups(
      inputs.order_with_clusters,
      inputs.order_rank_keys,
      inputs.seeded_groups,
      pass_result.ordered_mincross,
      pass_result.reorder_call_data.mincross_nodes,
      inputs.order_cluster_keys,
      inputs.order_cluster_skeleton,
    )
  {
    order_groups_for_mincross,
    ordered,
    reorder_call_data: pass_result.reorder_call_data,
  }
}

///|
/// Graphviz parity: pass0 flat-seed capture wraps the root mincross call,
/// then records the same stage snapshot before resetting capture state.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_mincross_reorder_with_pass0_capture(
  inputs : RootMincrossReorderInputs,
  order_groups_override : Map[Int, Array[String]]?,
  capture_call : (RootMincrossReorderResult, RootMincrossReorderInputs) -> Unit,
) -> RootMincrossReorderResult {
  let result =
    run_with_pass0_flat_seed_capture(() =>
      run_root_mincross_reorder(
        inputs,
        order_groups_override,
      )
    )
  capture_call(result, inputs)
  result
}

///|
/// Graphviz parity: root+cluster rank phase payload keeps root reorder inputs
/// and root override replay context unchanged before cluster-local pass.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootAndClusterRanksInputs {
  order_with_vnodes : Bool
  graphviz_flip : Bool
  cluster_keys : Map[String, String]
  root_groups_override : Map[Int, Array[String]]?
}

///|
/// Graphviz parity: root+cluster call-input bundle keeps root ReMincross input
/// snapshots paired with root/cluster merge flags for one stage call.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootAndClusterRanksCallInputs {
  root_mincross_reorder_inputs : RootMincrossReorderInputs
  root_and_cluster_inputs : RootAndClusterRanksInputs
}

///|
/// Graphviz parity: root+cluster call-input source bundle keeps pre-root
/// materialized snapshots paired with root override replay inputs.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootAndClusterRanksCallInputSources {
  reorder_setup : OrderingReorderSetup
  reorder_context : OrderReorderContext
  materialized : OrderMaterializationData
  order_groups : Map[Int, Array[String]]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_sizes_out : Map[String, @shared.NodeSize]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_keys : Map[String, String]
  root_groups_override : Map[Int, Array[String]]?
}

///|
/// Graphviz parity: root+cluster stage call inputs are assembled from one
/// pre-root source snapshot without changing root reorder call order.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_and_cluster_ranks_call_inputs_from_sources(
  sources : RootAndClusterRanksCallInputSources,
) -> RootAndClusterRanksCallInputs {
  let root_mincross_reorder_inputs =
    build_root_mincross_reorder_inputs_from_sources(
      {
        reorder_setup: sources.reorder_setup,
        reorder_context: sources.reorder_context,
        materialized: sources.materialized,
        order_groups: sources.order_groups,
        order_cluster_keys: sources.order_cluster_keys,
        order_cluster_skeleton: sources.order_cluster_skeleton,
        order_sizes_out: sources.order_sizes_out,
        rank_same_groups: sources.rank_same_groups,
        rank_same_order: sources.rank_same_order,
        nodesep_pt: sources.nodesep_pt,
        has_edge_labels: sources.has_edge_labels,
        port_order_positions: sources.port_order_positions,
        port_order_contrib: sources.port_order_contrib,
      },
    )
  let root_and_cluster_inputs : RootAndClusterRanksInputs = {
    order_with_vnodes: sources.reorder_setup.order_with_vnodes,
    graphviz_flip: sources.reorder_setup.graphviz_flip,
    cluster_keys: sources.cluster_keys,
    root_groups_override: sources.root_groups_override,
  }
  {
    root_mincross_reorder_inputs,
    root_and_cluster_inputs,
  }
}

///|
/// Graphviz parity: root+cluster stage run keeps root mincross capture/replay
/// ordering unchanged, then applies root-override merge before local replay.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_and_cluster_ranks_from_call_inputs_with_pass0_capture(
  call_inputs : RootAndClusterRanksCallInputs,
  capture_call : (RootMincrossReorderResult, RootMincrossReorderInputs) -> Unit,
) -> RootAndClusterRanksOutput {
  let root_reorder_result =
    run_root_mincross_reorder_with_pass0_capture(
      call_inputs.root_mincross_reorder_inputs,
      call_inputs.root_and_cluster_inputs.root_groups_override,
      capture_call,
    )
  run_root_and_cluster_ranks(
    call_inputs.root_and_cluster_inputs,
    root_reorder_result,
  )
}

///|
/// Graphviz parity: root+cluster stage source bundle keeps root-mincross call
/// inputs and post-root local-replay snapshots grouped for one stage run.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootAndClusterRanksStageSources {
  call_input_sources : RootAndClusterRanksCallInputSources
  order_with_clusters : Bool
  graph : @cgraph.Graph
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
  flat_constraints : Map[String, Bool]
  node_order : Map[String, Int]
  ranks : Map[String, Int]
  vnode_ranks : Map[String, Int]
  vnode_clusters : Map[String, String]
  vnode_sizes : Map[String, @shared.NodeSize]
}

///|
/// Graphviz parity: root+cluster stage run preserves root mincross
/// capture/replay ordering, then applies local cluster replay using unmapped
/// order-graph snapshots from the same pre-root source payload.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_and_cluster_ranks_stage_from_sources(
  sources : RootAndClusterRanksStageSources,
  capture_call : (RootMincrossReorderResult, RootMincrossReorderInputs) -> Unit,
) -> RootAndClusterRanksOutput {
  let call_inputs =
    build_root_and_cluster_ranks_call_inputs_from_sources(
      sources.call_input_sources,
    )
  let root_cluster_stage =
    run_root_and_cluster_ranks_from_call_inputs_with_pass0_capture(
      call_inputs,
      capture_call,
    )
  run_cluster_local_rank_replay_after_root_from_sources(
    {
      order_with_clusters: sources.order_with_clusters,
      groups: root_cluster_stage.ordered,
      graph: sources.graph,
      cluster_order: sources.cluster_order,
      cluster_parents: sources.cluster_parents,
      rank_same_groups: sources.call_input_sources.rank_same_groups,
      rank_same_order: sources.call_input_sources.rank_same_order,
      intercluster_keys: sources.intercluster_keys,
      flat_constraints: sources.flat_constraints,
      node_order: sources.node_order,
      order_edges: sources.call_input_sources.materialized.order_edges_out_unmapped,
      order_edge_tail:
        sources.call_input_sources.materialized.order_edge_tail_out_unmapped,
      order_edge_head:
        sources.call_input_sources.materialized.order_edge_head_out_unmapped,
      order_edge_tail_port_x:
        sources.call_input_sources.materialized.order_edge_tail_port_x_unmapped,
      order_edge_head_port_x:
        sources.call_input_sources.materialized.order_edge_head_port_x_unmapped,
      order_edge_tail_port_order:
        sources.call_input_sources.materialized.order_edge_tail_port_order_unmapped,
      order_edge_head_port_order:
        sources.call_input_sources.materialized.order_edge_head_port_order_unmapped,
      graphviz_out_neighbors:
        sources.call_input_sources.materialized.graphviz_out_neighbors,
      graphviz_in_neighbors:
        sources.call_input_sources.materialized.graphviz_in_neighbors,
      ranks: sources.ranks,
      order_sizes: sources.call_input_sources.order_sizes_out,
      nodesep_pt: sources.call_input_sources.nodesep_pt,
      has_edge_labels: sources.call_input_sources.has_edge_labels,
      port_order_positions: sources.call_input_sources.port_order_positions,
      port_order_contrib: sources.call_input_sources.port_order_contrib,
      vnode_ranks: sources.vnode_ranks,
      vnode_clusters: sources.vnode_clusters,
      vnode_sizes: sources.vnode_sizes,
      order_with_vnodes: sources.call_input_sources.reorder_setup.order_with_vnodes,
    },
  )
  root_cluster_stage
}

///|
/// Graphviz parity: root-phase stage output keeps root+cluster rank groups,
/// tail-order replay override, and shared root-rank-order phase base grouped
/// for clustered finalize replay.
/// Do not change behavior without updating fixtures/tests.
pub struct ClusteredRootPhaseStageOutput {
  root_cluster_stage : RootAndClusterRanksOutput
  root_tail_order_override : Array[String]?
  root_rank_order_phase_base : RootRankOrderPhaseBase
}

///|
/// Graphviz parity: clustered root-phase stage source bundle keeps root
/// rank-order base sources, root-pass input groups, and root+cluster stage
/// sources grouped for one deterministic stage run.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredRootPhaseStageSources {
  root_rank_order_phase_base_sources : RootRankOrderPhaseBaseBuildSources
  order_groups_for_root_phase : Map[Int, Array[String]]
  root_and_cluster_stage_sources : RootAndClusterRanksStageSources
}

///|
/// Graphviz parity: clustered root-phase source bundle assembly keeps pre-root
/// snapshots and root-stage metadata grouped before deterministic stage run.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredRootPhaseStageBuildSources {
  reorder_setup : OrderingReorderSetup
  pre_root_stage : ClusteredPreRootStageOutput
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  cluster_keys : Map[String, String]
  edge_vnodes : Map[String, Array[String]]
  vnodes_by_rank : Map[Int, Array[String]]
  ranks : Map[String, Int]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graph : @cgraph.Graph
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
  flat_constraints : Map[String, Bool]
  vnode_ranks : Map[String, Int]
  vnode_clusters : Map[String, String]
  vnode_sizes : Map[String, @shared.NodeSize]
}

///|
/// Graphviz parity: clustered root-phase source assembly keeps root-rank-order
/// base sources and root+cluster stage sources paired from one pre-root
/// snapshot without positional argument drift.
/// Do not change behavior without updating fixtures/tests.
pub fn build_clustered_root_phase_stage_sources(
  sources : ClusteredRootPhaseStageBuildSources,
) -> ClusteredRootPhaseStageSources {
  {
    root_rank_order_phase_base_sources:
      {
        reorder_setup: sources.reorder_setup,
        class2_data: sources.reorder_setup.class2_data,
        order_rank_keys: sources.pre_root_stage.reorder_context.order_rank_keys,
        order_cluster_keys: sources.pre_root_stage.order_cluster_keys,
        order_cluster_skeleton: sources.pre_root_stage.order_cluster_skeleton,
        edges: sources.edges,
        edge_tail: sources.edge_tail,
        edge_head: sources.edge_head,
        cluster_keys: sources.cluster_keys,
        edge_vnodes: sources.edge_vnodes,
        vnodes_by_rank: sources.vnodes_by_rank,
        ranks: sources.ranks,
        rank_same_groups: sources.rank_same_groups,
        rank_same_order: sources.rank_same_order,
        order_sizes_out: sources.pre_root_stage.order_sizes_out,
        nodesep_pt: sources.nodesep_pt,
        has_edge_labels: sources.has_edge_labels,
        port_order_positions: sources.port_order_positions,
        port_order_contrib: sources.port_order_contrib,
        order_flat_constraints: sources.flat_constraints,
      },
    order_groups_for_root_phase: sources.pre_root_stage.order_groups,
    root_and_cluster_stage_sources:
      {
        call_input_sources:
          {
            reorder_setup: sources.reorder_setup,
            reorder_context: sources.pre_root_stage.reorder_context,
            materialized: sources.pre_root_stage.materialized,
            order_groups: sources.pre_root_stage.order_groups,
            order_cluster_keys: sources.pre_root_stage.order_cluster_keys,
            order_cluster_skeleton: sources.pre_root_stage.order_cluster_skeleton,
            order_sizes_out: sources.pre_root_stage.order_sizes_out,
            rank_same_groups: sources.rank_same_groups,
            rank_same_order: sources.rank_same_order,
            nodesep_pt: sources.nodesep_pt,
            has_edge_labels: sources.has_edge_labels,
            port_order_positions: sources.port_order_positions,
            port_order_contrib: sources.port_order_contrib,
            cluster_keys: sources.cluster_keys,
            root_groups_override: None,
          },
        order_with_clusters: sources.reorder_setup.order_with_clusters,
        graph: sources.graph,
        cluster_order: sources.cluster_order,
        cluster_parents: sources.cluster_parents,
        intercluster_keys: sources.intercluster_keys,
        flat_constraints: sources.flat_constraints,
        node_order: sources.pre_root_stage.reorder_context.order_node_order,
        ranks: sources.ranks,
        vnode_ranks: sources.vnode_ranks,
        vnode_clusters: sources.vnode_clusters,
        vnode_sizes: sources.vnode_sizes,
      },
  }
}

///|
/// Graphviz parity: clustered root-phase stage root-groups override is applied
/// only to root+cluster stage call-input sources, keeping all other snapshots
/// unchanged.
fn with_root_groups_override_in_call_input_sources(
  call_input_sources : RootAndClusterRanksCallInputSources,
  root_groups_override : Map[Int, Array[String]]?,
) -> RootAndClusterRanksCallInputSources {
  {
    reorder_setup: call_input_sources.reorder_setup,
    reorder_context: call_input_sources.reorder_context,
    materialized: call_input_sources.materialized,
    order_groups: call_input_sources.order_groups,
    order_cluster_keys: call_input_sources.order_cluster_keys,
    order_cluster_skeleton: call_input_sources.order_cluster_skeleton,
    order_sizes_out: call_input_sources.order_sizes_out,
    rank_same_groups: call_input_sources.rank_same_groups,
    rank_same_order: call_input_sources.rank_same_order,
    nodesep_pt: call_input_sources.nodesep_pt,
    has_edge_labels: call_input_sources.has_edge_labels,
    port_order_positions: call_input_sources.port_order_positions,
    port_order_contrib: call_input_sources.port_order_contrib,
    cluster_keys: call_input_sources.cluster_keys,
    root_groups_override,
  }
}

///|
/// Graphviz parity: clustered root phase keeps root-rank-order base assembly,
/// root-only reorder pass/override derivation, and root+cluster stage replay in
/// fixed order.
/// Do not change behavior without updating fixtures/tests.
pub fn run_clustered_root_phase_stage_from_sources(
  sources : ClusteredRootPhaseStageSources,
  capture_call : (RootMincrossReorderResult, RootMincrossReorderInputs) -> Unit,
) -> ClusteredRootPhaseStageOutput {
  let root_rank_order_phase_base =
    build_root_rank_order_phase_base_from_sources(
      sources.root_rank_order_phase_base_sources,
    )
  let (root_reorder_output, root_rank_order_phase_output) =
    run_root_reorder_and_rank_order_from_base(
      root_rank_order_phase_base,
      sources.order_groups_for_root_phase,
    )
  let root_phase_overrides =
    build_clustered_root_phase_overrides(
      sources.root_and_cluster_stage_sources.order_with_clusters,
      root_reorder_output,
      root_rank_order_phase_output,
    )
  let root_cluster_stage =
    run_root_and_cluster_ranks_stage_from_sources(
      {
        call_input_sources:
          with_root_groups_override_in_call_input_sources(
            sources.root_and_cluster_stage_sources.call_input_sources,
            root_phase_overrides.root_groups_override_for_root_pass,
          ),
        order_with_clusters:
          sources.root_and_cluster_stage_sources.order_with_clusters,
        graph: sources.root_and_cluster_stage_sources.graph,
        cluster_order: sources.root_and_cluster_stage_sources.cluster_order,
        cluster_parents: sources.root_and_cluster_stage_sources.cluster_parents,
        intercluster_keys:
          sources.root_and_cluster_stage_sources.intercluster_keys,
        flat_constraints: sources.root_and_cluster_stage_sources.flat_constraints,
        node_order: sources.root_and_cluster_stage_sources.node_order,
        ranks: sources.root_and_cluster_stage_sources.ranks,
        vnode_ranks: sources.root_and_cluster_stage_sources.vnode_ranks,
        vnode_clusters: sources.root_and_cluster_stage_sources.vnode_clusters,
        vnode_sizes: sources.root_and_cluster_stage_sources.vnode_sizes,
      },
      capture_call,
    )
  {
    root_cluster_stage,
    root_tail_order_override: root_phase_overrides.root_tail_order_override,
    root_rank_order_phase_base,
  }
}

///|
/// Graphviz parity: root+cluster rank phase output keeps root-mincross input
/// groups, final ordered groups, and vnode-inclusive groups for xpos.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootAndClusterRanksOutput {
  order_groups_for_mincross : Map[Int, Array[String]]
  ordered : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
/// Graphviz parity: graphviz_flip root output merge can replay rank overrides
/// captured from root phase before cluster-local build_ranks ordering.
fn resolve_root_phase_ordered_groups(
  root_ordered_groups : Map[Int, Array[String]],
  root_groups_override : Map[Int, Array[String]]?,
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  if !graphviz_flip {
    return root_ordered_groups
  }
  match root_groups_override {
    Some(override_groups) =>
      apply_root_groups_override(
        root_ordered_groups,
        override_groups,
        cluster_keys,
        graphviz_flip,
      )
    None => root_ordered_groups
  }
}

///|
/// Graphviz parity: root mincross reordering is followed by clustered
/// build_ranks handoff payload generation for clustered/local replay.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_and_cluster_ranks(
  inputs : RootAndClusterRanksInputs,
  root_reorder_result : RootMincrossReorderResult,
) -> RootAndClusterRanksOutput {
  let order_groups_for_mincross = root_reorder_result.order_groups_for_mincross
  let root_ordered_groups = root_reorder_result.ordered
  let ordered =
    resolve_root_phase_ordered_groups(
      root_ordered_groups,
      inputs.root_groups_override,
      inputs.cluster_keys,
      inputs.graphviz_flip,
    )
  let ordered_with_vnodes =
    if !inputs.order_with_vnodes {
      Map::new()
    } else {
      ordered
    }
  {
    order_groups_for_mincross,
    ordered,
    ordered_with_vnodes,
  }
}

///|
/// Graphviz parity: keep cluster-internal nodes attached to the rankleader
/// skeleton position when root mincross reorders cluster skeleton chains.
fn build_rank_attached_by_skeleton(
  names : Array[String],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  mincross_nodes : Map[String, Bool],
) -> Map[String, Array[String]] {
  let skeleton_for_cluster =
    build_skeleton_for_clusters(
      names,
      (name) =>
        if order_cluster_skeleton.get(name) == Some(true) {
          cluster_key_or_empty(order_cluster_keys, name)
        } else {
          ""
        },
    )
  build_attached_by_skeleton(
    names,
    order_cluster_keys,
    skeleton_for_cluster,
    (name) => mincross_nodes.get(name) is Some(_),
  )
}

///|
/// Graphviz parity: positional merge replaces only root-mincross membership
/// slots while preserving non-member positions in seeded rank order.
fn merge_rank_with_positional_replacements(
  names : Array[String],
  replacements : Array[String],
  mincross_nodes : Map[String, Bool],
) -> Array[String] {
  let merged_names = names.copy()
  let mut replace_idx = 0
  for i in 0..<merged_names.length() {
    if mincross_nodes.get(merged_names[i]) is Some(_) {
      if replace_idx < replacements.length() {
        merged_names[i] = replacements[replace_idx]
        replace_idx = replace_idx + 1
      }
    }
  }
  merged_names
}

///|
/// Graphviz parity: attachment merge appends skeleton-attached members after
/// replacement skeletons before replaying remaining seeded names.
fn merge_rank_with_attached_skeleton_replacements(
  names : Array[String],
  replacements : Array[String],
  attached_by_skeleton : Map[String, Array[String]],
  order_cluster_skeleton : Map[String, Bool],
) -> Array[String] {
  let next_names : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for replacement in replacements {
    next_names.push(replacement)
    seen[replacement] = true
    if order_cluster_skeleton.get(replacement) == Some(true) {
      append_attached_by_skeleton(
        next_names,
        seen,
        attached_by_skeleton,
        replacement,
      )
    }
  }
  for name in names {
    if seen.get(name) is None {
      next_names.push(name)
      seen[name] = true
    }
  }
  next_names
}

///|
/// Graphviz parity: cluster->skeleton map keeps last-seen skeleton per cluster
/// from input order and ignores names without a cluster skeleton key.
pub fn build_skeleton_for_clusters(
  names : Array[String],
  cluster_for_name : (String) -> String,
) -> Map[String, String] {
  let skeleton_for_cluster : Map[String, String] = Map::new()
  for name in names {
    let cluster = cluster_for_name(name)
    if cluster != "" {
      skeleton_for_cluster[cluster] = name
    }
  }
  skeleton_for_cluster
}

///|
/// Graphviz parity: attached-by-skeleton buckets map non-skipped cluster
/// members to their rankleader skeleton in input order.
pub fn build_attached_by_skeleton(
  names : Array[String],
  cluster_keys : Map[String, String],
  skeleton_for_cluster : Map[String, String],
  should_skip : (String) -> Bool,
) -> Map[String, Array[String]] {
  let attached_by_skeleton : Map[String, Array[String]] = Map::new()
  for name in names {
    if should_skip(name) {
      continue
    }
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    match skeleton_for_cluster.get(cluster) {
      Some(skeleton_name) =>
        match attached_by_skeleton.get(skeleton_name) {
          Some(list) => list.push(name)
          None => attached_by_skeleton[skeleton_name] = [name]
        }
      None => ()
    }
  }
  attached_by_skeleton
}

///|
/// Graphviz parity: attached cluster members are replayed after their
/// skeleton only once, preserving original attached list order.
pub fn append_attached_by_skeleton(
  target : Array[String],
  seen : Map[String, Bool],
  attached_by_skeleton : Map[String, Array[String]],
  skeleton_name : String,
) -> Unit {
  let attached = attached_by_skeleton.get(skeleton_name).unwrap_or_default()
  for attached_name in attached {
    if seen.get(attached_name) is None {
      target.push(attached_name)
      seen[attached_name] = true
    }
  }
}

///|
/// Graphviz parity: positional root merge triggers only for [root, skeleton]
/// replacement pairs with exactly one attached member on that skeleton.
fn should_merge_root_positions(
  replacements : Array[String],
  order_cluster_skeleton : Map[String, Bool],
  attached_by_skeleton : Map[String, Array[String]],
) -> Bool {
  if replacements.length() != 2 {
    return false
  }
  if order_cluster_skeleton.get(replacements[1]) != Some(true) ||
    order_cluster_skeleton.get(replacements[0]) == Some(true) {
    return false
  }
  let attached_count =
    attached_by_skeleton.get(replacements[1]).unwrap_or_default().length()
  attached_count == 1
}

///|
/// Ordering domain: root-rank override replay helpers used by clustered
/// Stage C root passes when replaying root-mincross override groups.

///|
/// Graphviz parity: rank-level override reorders only names present in the
/// current rank while preserving the relative order of unmatched names.
/// Do not change behavior without updating fixtures/tests.
pub fn reorder_names_by_override(
  names : Array[String],
  override_names : Array[String],
) -> Array[String] {
  let present : Map[String, Bool] = Map::new()
  for name in names {
    present[name] = true
  }
  let reordered : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in override_names {
    if present.get(name) is Some(_) && seen.get(name) is None {
      reordered.push(name)
      seen[name] = true
    }
  }
  for name in names {
    if seen.get(name) is None {
      reordered.push(name)
      seen[name] = true
    }
  }
  reordered
}

///|
/// Graphviz parity: root-override graphviz_flip replay keeps skeleton names in
/// rank order, reattaches same-cluster names after skeletons, and preserves any
/// unmatched names as final fallback in original rank order.
fn rebuild_root_override_names(
  rank_names : Array[String],
  cluster_keys : Map[String, String],
) -> Array[String] {
  // Graphviz parity: root-override skeleton checks treat non-skeleton names as
  // empty cluster keys when rebuilding attached-cluster bundles.
  let skeleton_cluster_or_empty = (name : String) =>
    @clustering.cluster_key_from_skeleton(name).unwrap_or_default()
  // Graphviz parity: any parsed skeleton cluster key is a skeleton marker.
  let is_root_override_skeleton_name = (name : String) =>
    skeleton_cluster_or_empty(name) != ""
  let skeleton_for_cluster =
    build_skeleton_for_clusters(
      rank_names,
      skeleton_cluster_or_empty,
    )
  let attached_by_skeleton =
    build_attached_by_skeleton(
      rank_names,
      cluster_keys,
      skeleton_for_cluster,
      is_root_override_skeleton_name,
    )
  let next_names : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in rank_names {
    if seen.get(name) is Some(_) {
      continue
    }
    let is_skeleton = is_root_override_skeleton_name(name)
    if is_skeleton {
      next_names.push(name)
      seen[name] = true
      append_attached_by_skeleton(
        next_names,
        seen,
        attached_by_skeleton,
        name,
      )
      continue
    }
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster != "" && skeleton_for_cluster.get(cluster) is Some(_) {
      continue
    }
    next_names.push(name)
    seen[name] = true
  }
  for name in rank_names {
    if seen.get(name) is None {
      next_names.push(name)
      seen[name] = true
    }
  }
  next_names
}

///|
/// Graphviz parity: rank-level root override first applies explicit override
/// order, then replays cluster-attached skeleton ordering only in flip mode.
/// Do not change behavior without updating fixtures/tests.
fn build_root_override_rank_names(
  names : Array[String],
  override_names : Array[String],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
) -> Array[String] {
  let rank_names =
    reorder_names_by_override(
      names,
      override_names,
    )
  if !graphviz_flip {
    return rank_names
  }
  rebuild_root_override_names(rank_names, cluster_keys)
}

///|
/// Graphviz parity: root phase can apply a rank-order override from root
/// mincross output before local cluster passes.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_root_groups_override(
  groups : Map[Int, Array[String]],
  override_groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let reordered = clone_rank_groups(groups)
  for rank, override_names in override_groups {
    match reordered.get(rank) {
      Some(names) =>
        reordered[rank] =
          build_root_override_rank_names(
            names,
            override_names,
            cluster_keys,
            graphviz_flip,
          )
      None => ()
    }
  }
  reordered
}

///|
/// Ordering domain: connected-component traversal and projection helpers for
/// root mincross reorder inputs.

///|
/// Graphviz parity: non-cluster mincross traverses connected components in
/// GD_nlist order (real nodes first), then runs mincross on each component.
/// Do not change behavior without updating fixtures/tests.
fn resolve_root_component_order_index(
  name : String,
  order_node_order : Map[String, Int],
  fallback_order : Map[String, Int],
) -> Int {
  match order_node_order.get(name) {
    Some(value) => value
    None =>
      match fallback_order.get(name) {
        Some(value) => value
        None => 0
      }
  }
}

///|
/// Graphviz parity: flat-constraint adjacency contributes undirected traversal
/// links for non-cluster connected-component discovery.
/// Do not change behavior without updating fixtures/tests.
priv struct FlatConstraintAdjacency {
  flat_out : Map[String, Array[String]]
  flat_in : Map[String, Array[String]]
}

///|
/// Graphviz parity: component traversal starts keep sorted root order and
/// preferred non-vnode starts for the first DFS pass.
/// Do not change behavior without updating fixtures/tests.
priv struct ComponentTraversalStarts {
  start_nodes : Array[String]
  traversal_starts : Array[String]
}

///|
/// Graphviz parity: component traversal adjacency combines graphviz in/out
/// neighbors with flat-constraint links for one node-set projection.
/// Do not change behavior without updating fixtures/tests.
priv struct ComponentTraversalAdjacency {
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
  flat_out : Map[String, Array[String]]
  flat_in : Map[String, Array[String]]
}

///|
/// Graphviz parity: enabled flat constraints add traversal links only when
/// both endpoints exist in the current root node membership projection.
fn build_flat_constraint_adjacency(
  order_nodes : Array[String],
  node_set : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> FlatConstraintAdjacency {
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    flat_out[name] = []
    flat_in[name] = []
  }
  for key, enabled in flat_constraints {
    if !enabled {
      continue
    }
    match @shared.parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        if tail == "" || head == "" {
          continue
        }
        if node_set.get(tail) is None || node_set.get(head) is None {
          continue
        }
        match flat_out.get(tail) {
          Some(list) => list.push(head)
          None => flat_out[tail] = [head]
        }
        match flat_in.get(head) {
          Some(list) => list.push(tail)
          None => flat_in[head] = [tail]
        }
      }
      None => ()
    }
  }
  { flat_out, flat_in }
}

///|
/// Graphviz parity: non-cluster traversal starts are sorted by root node order,
/// then biased to real nodes before edge-vnode starts.
/// Do not change behavior without updating fixtures/tests.
fn build_component_traversal_starts(
  order_nodes : Array[String],
  order_node_order : Map[String, Int],
) -> ComponentTraversalStarts {
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in order_nodes {
    fallback_order[name] = i
  }
  let start_nodes = order_nodes.copy()
  if start_nodes.length() > 1 {
    start_nodes.sort_by((a, b) => {
      let a_idx =
        resolve_root_component_order_index(
          a,
          order_node_order,
          fallback_order,
        )
      let b_idx =
        resolve_root_component_order_index(
          b,
          order_node_order,
          fallback_order,
        )
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
  }
  let preferred_start_nodes : Array[String] = []
  for name in start_nodes {
    if !name.has_prefix(EDGE_VNODE_PREFIX) {
      preferred_start_nodes.push(name)
    }
  }
  let traversal_starts =
    if preferred_start_nodes.length() > 0 { preferred_start_nodes } else { start_nodes }
  { start_nodes, traversal_starts }
}

///|
/// Graphviz parity: non-cluster component traversal uses graphviz in/out
/// neighbors plus flat-constraint adjacency over the active node-set.
/// Do not change behavior without updating fixtures/tests.
fn build_component_traversal_adjacency(
  order_nodes : Array[String],
  node_set : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  flat_constraints : Map[String, Bool],
) -> ComponentTraversalAdjacency {
  let out_neighbors =
    filter_component_neighbor_map(
      order_nodes,
      node_set,
      graphviz_out_neighbors,
    )
  let in_neighbors =
    filter_component_neighbor_map(
      order_nodes,
      node_set,
      graphviz_in_neighbors,
    )
  let flat_adjacency =
    build_flat_constraint_adjacency(
      order_nodes,
      node_set,
      flat_constraints,
    )
  {
    out_neighbors,
    in_neighbors,
    flat_out: flat_adjacency.flat_out,
    flat_in: flat_adjacency.flat_in,
  }
}

///|
/// Graphviz parity: component DFS replays preferred starts first, then full
/// starts, preserving visit-order within each connected component.
/// Do not change behavior without updating fixtures/tests.
fn collect_components_from_traversal(
  order_nodes : Array[String],
  node_set : Map[String, Bool],
  traversal_starts : ComponentTraversalStarts,
  adjacency : ComponentTraversalAdjacency,
) -> Array[Array[String]] {
  let visited : Map[String, Bool] = Map::new()
  for name in order_nodes {
    visited[name] = false
  }
  let components : Array[Array[String]] = []
  let stack : Array[String] = []
  let push_neighbors = (list : Array[String]) => {
    let mut idx = list.length()
    while idx > 0 {
      idx = idx - 1
      let other = list[idx]
      if node_set.get(other) is None {
        continue
      }
      if visited.get(other) != Some(true) {
        stack.push(other)
      }
    }
  }
  let visit_start = (start : String) => {
    if visited.get(start) == Some(true) {
      ()
    } else {
      let component : Array[String] = []
      stack.push(start)
      while stack.length() > 0 {
        let current = stack[stack.length() - 1]
        let _ = stack.pop()
        if visited.get(current) == Some(true) {
          continue
        }
        visited[current] = true
        component.push(current)
        let fin = adjacency.flat_in.get(current).unwrap_or_default()
        let fout = adjacency.flat_out.get(current).unwrap_or_default()
        let inn = adjacency.in_neighbors.get(current).unwrap_or_default()
        let out = adjacency.out_neighbors.get(current).unwrap_or_default()
        push_neighbors(fin)
        push_neighbors(fout)
        push_neighbors(inn)
        push_neighbors(out)
      }
      if component.length() > 0 {
        components.push(component)
      }
    }
  }
  for start in traversal_starts.traversal_starts {
    visit_start(start)
  }
  for start in traversal_starts.start_nodes {
    visit_start(start)
  }
  components
}

///|
/// Graphviz parity: non-cluster mincross traverses connected components in
/// GD_nlist order (real nodes first), then runs mincross on each component.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_noncluster_components(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  order_node_order : Map[String, Int],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  flat_constraints : Map[String, Bool],
) -> Array[Array[String]] {
  let order_nodes = build_order_nodes_from_groups(groups, rank_keys)
  if order_nodes.length() == 0 {
    return []
  }
  let node_set = build_node_membership_set(order_nodes)
  let traversal_starts =
    build_component_traversal_starts(
      order_nodes,
      order_node_order,
    )
  let adjacency =
    build_component_traversal_adjacency(
      order_nodes,
      node_set,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      flat_constraints,
    )
  collect_components_from_traversal(
    order_nodes,
    node_set,
    traversal_starts,
    adjacency,
  )
}

///|
pub fn filter_component_neighbor_map(
  component_nodes : Array[String],
  component_set : Map[String, Bool],
  neighbors : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let filtered : Map[String, Array[String]] = Map::new()
  for name in component_nodes {
    let values = match neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let keep : Array[String] = []
    for other in values {
      if component_set.get(other) is Some(_) {
        keep.push(other)
      }
    }
    filtered[name] = keep
  }
  filtered
}

///|
pub fn filter_component_positions(
  component_set : Map[String, Bool],
  positions : Map[String, Double],
) -> Map[String, Double] {
  let filtered : Map[String, Double] = Map::new()
  for name, value in positions {
    if component_set.get(name) is Some(_) {
      filtered[name] = value
    }
  }
  filtered
}

///|
pub fn filter_component_port_order_contrib(
  component_set : Map[String, Bool],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[String, Array[(String, Double)]] {
  let component_port_order_contrib : Map[String, Array[(String, Double)]] =
    Map::new()
  for name, entries in port_order_contrib {
    if component_set.get(name) is None {
      continue
    }
    let keep : Array[(String, Double)] = []
    for entry in entries {
      let (other, weight) = entry
      if component_set.get(other) is Some(_) {
        keep.push((other, weight))
      }
    }
    component_port_order_contrib[name] = keep
  }
  component_port_order_contrib
}

///|
pub fn filter_component_flat_constraints(
  component_set : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
) -> Map[String, Bool] {
  let component_flat_constraints : Map[String, Bool] = Map::new()
  for key, enabled in order_flat_constraints {
    if !enabled {
      continue
    }
    match @shared.parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        if tail == "" || head == "" {
          continue
        }
        if component_set.get(tail) is Some(_) && component_set.get(head) is Some(_) {
          component_flat_constraints[key] = true
        }
      }
      None => ()
    }
  }
  component_flat_constraints
}

///|
pub(all) struct RootComponentProjection {
  order_groups_for_mincross : Map[Int, Array[String]]
  order_edges_out_mincross : Array[@cgraph.Edge]
  order_edge_tail_out_mincross : Array[String]
  order_edge_head_out_mincross : Array[String]
  order_edge_tail_port_x_mincross : Array[Double]
  order_edge_head_port_x_mincross : Array[Double]
  order_edge_tail_port_order_mincross : Array[Double]
  order_edge_head_port_order_mincross : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  port_order_positions : Map[String, Double]
  preferred_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_flat_constraints : Map[String, Bool]
}

///|
pub(all) struct RootRankReorderInputs {
  order_rank_keys_for_mincross : Array[Int]
  order_groups_for_mincross : Map[Int, Array[String]]
  order_edges_out_mincross : Array[@cgraph.Edge]
  order_edge_tail_out_mincross : Array[String]
  order_edge_head_out_mincross : Array[String]
  order_edge_tail_port_x_mincross : Array[Double]
  order_edge_head_port_x_mincross : Array[Double]
  order_edge_tail_port_order_mincross : Array[Double]
  order_edge_head_port_order_mincross : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  order_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_order : Map[String, Int]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  preferred_positions : Map[String, Double]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: component-local reorder inputs are filtered from root data
/// so each mincross call only sees one connected component projection.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_component_projection(
  component_nodes : Array[String],
  component_set : Map[String, Bool],
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out_mincross : Array[@cgraph.Edge],
  order_edge_tail_out_mincross : Array[String],
  order_edge_head_out_mincross : Array[String],
  order_edge_tail_port_x_mincross : Array[Double],
  order_edge_head_port_x_mincross : Array[Double],
  order_edge_tail_port_order_mincross : Array[Double],
  order_edge_head_port_order_mincross : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  port_order_positions : Map[String, Double],
  preferred_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_flat_constraints : Map[String, Bool],
) -> RootComponentProjection {
  let component_groups =
    filter_component_rank_groups(
      order_rank_keys_for_mincross,
      order_groups_for_mincross,
      component_set,
    )
  let component_edges_output =
    collect_mincross_order_edges(
      component_set,
      order_edges_out_mincross,
      order_edge_tail_out_mincross,
      order_edge_head_out_mincross,
      order_edge_tail_port_x_mincross,
      order_edge_head_port_x_mincross,
      order_edge_tail_port_order_mincross,
      order_edge_head_port_order_mincross,
    )
  // Graphviz parity: component-local parent/child + Graphviz traversal maps
  // are all filtered through one component-set projection.
  let component_parents =
    filter_component_neighbor_map(
      component_nodes,
      component_set,
      parents,
    )
  let component_children =
    filter_component_neighbor_map(
      component_nodes,
      component_set,
      children,
    )
  let component_graphviz_out_neighbors =
    filter_component_neighbor_map(
      component_nodes,
      component_set,
      graphviz_out_neighbors,
    )
  let component_graphviz_in_neighbors =
    filter_component_neighbor_map(
      component_nodes,
      component_set,
      graphviz_in_neighbors,
    )
  // Graphviz parity: component-local node-position hints are passed to
  // mincross only for nodes belonging to the active connected component.
  let component_port_order_positions =
    filter_component_positions(component_set, port_order_positions)
  let component_preferred_positions =
    filter_component_positions(component_set, preferred_positions)
  // Graphviz parity: component-local port-order contributor lists drop
  // endpoints outside the active connected component before mincross.
  let component_port_order_contrib =
    filter_component_port_order_contrib(
      component_set,
      port_order_contrib,
    )
  // Graphviz parity: component-local flat constraints are forwarded to
  // mincross only when both endpoints belong to the active component.
  let component_flat_constraints =
    filter_component_flat_constraints(
      component_set,
      order_flat_constraints,
    )
  {
    order_groups_for_mincross: component_groups,
    order_edges_out_mincross: component_edges_output.order_edges_out_mincross,
    order_edge_tail_out_mincross:
      component_edges_output.order_edge_tail_out_mincross,
    order_edge_head_out_mincross:
      component_edges_output.order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross:
      component_edges_output.order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross:
      component_edges_output.order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross:
      component_edges_output.order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross:
      component_edges_output.order_edge_head_port_order_mincross,
    parents: component_parents,
    children: component_children,
    graphviz_out_neighbors: component_graphviz_out_neighbors,
    graphviz_in_neighbors: component_graphviz_in_neighbors,
    port_order_positions: component_port_order_positions,
    preferred_positions: component_preferred_positions,
    port_order_contrib: component_port_order_contrib,
    order_flat_constraints: component_flat_constraints,
  }
}

///|
/// Graphviz parity: component-local reorder inputs are filtered from root data
/// so each mincross call only sees one connected component projection.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_component_reorder_inputs(
  component_nodes : Array[String],
  component_set : Map[String, Bool],
  root_inputs : RootRankReorderInputs,
) -> RootRankReorderInputs {
  let projection =
    build_root_component_projection(
      component_nodes,
      component_set,
      root_inputs.order_rank_keys_for_mincross,
      root_inputs.order_groups_for_mincross,
      root_inputs.order_edges_out_mincross,
      root_inputs.order_edge_tail_out_mincross,
      root_inputs.order_edge_head_out_mincross,
      root_inputs.order_edge_tail_port_x_mincross,
      root_inputs.order_edge_head_port_x_mincross,
      root_inputs.order_edge_tail_port_order_mincross,
      root_inputs.order_edge_head_port_order_mincross,
      root_inputs.parents,
      root_inputs.children,
      root_inputs.graphviz_out_neighbors,
      root_inputs.graphviz_in_neighbors,
      root_inputs.port_order_positions,
      root_inputs.preferred_positions,
      root_inputs.port_order_contrib,
      root_inputs.order_flat_constraints,
    )
  {
    order_rank_keys_for_mincross: root_inputs.order_rank_keys_for_mincross,
    order_groups_for_mincross: projection.order_groups_for_mincross,
    order_edges_out_mincross: projection.order_edges_out_mincross,
    order_edge_tail_out_mincross: projection.order_edge_tail_out_mincross,
    order_edge_head_out_mincross: projection.order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross: projection.order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross: projection.order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross:
      projection.order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross:
      projection.order_edge_head_port_order_mincross,
    parents: projection.parents,
    children: projection.children,
    order_cluster_keys: root_inputs.order_cluster_keys,
    rank_same_groups: root_inputs.rank_same_groups,
    rank_same_order: root_inputs.rank_same_order,
    edge_order: root_inputs.edge_order,
    order_node_order: root_inputs.order_node_order,
    order_sizes_out: root_inputs.order_sizes_out,
    nodesep_pt: root_inputs.nodesep_pt,
    has_edge_labels: root_inputs.has_edge_labels,
    port_order_positions: projection.port_order_positions,
    port_order_contrib: projection.port_order_contrib,
    preferred_positions: projection.preferred_positions,
    order_cluster_skeleton: root_inputs.order_cluster_skeleton,
    order_flat_constraints: projection.order_flat_constraints,
    graphviz_out_neighbors: projection.graphviz_out_neighbors,
    graphviz_in_neighbors: projection.graphviz_in_neighbors,
    graphviz_flip: root_inputs.graphviz_flip,
  }
}

pub fn has_non_empty_cluster_keys(order_cluster_keys : Map[String, String]) -> Bool {
  for _name, cluster in order_cluster_keys {
    if cluster != "" {
      return true
    }
  }
  false
}

///|
/// Graphviz parity: component reorder keeps each rank's relative extraction
/// order from the full group list before running mincross on that component.
pub fn filter_component_rank_groups(
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  component_set : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let component_groups : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys_for_mincross {
    let names = order_groups_for_mincross.get(rank).unwrap_or_default()
    let keep : Array[String] = []
    for name in names {
      if component_set.get(name) is Some(_) {
        keep.push(name)
      }
    }
    if keep.length() > 0 {
      component_groups[rank] = keep
    }
  }
  component_groups
}

///|
pub fn append_component_rank_groups(
  order_rank_keys_for_mincross : Array[Int],
  merged : Map[Int, Array[String]],
  ordered_component : Map[Int, Array[String]],
) -> Unit {
  for rank in order_rank_keys_for_mincross {
    let names = ordered_component.get(rank).unwrap_or_default()
    if names.length() == 0 {
      continue
    }
    let merged_names = merged.get(rank).unwrap_or_default()
    for name in names {
      merged_names.push(name)
    }
    merged[rank] = merged_names
  }
}

///|
/// Graphviz parity: multi-component root reorder runs one component projection
/// per mincross call, then concatenates per-rank outputs in component order.
/// Do not change behavior without updating fixtures/tests.
fn run_componentwise_root_rank_reorder(
  components : Array[Array[String]],
  order_rank_keys_for_mincross : Array[Int],
  inputs : RootRankReorderInputs,
  root_graphviz_flip : Bool,
  coalesce_parallel : Bool,
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys_for_mincross {
    merged[rank] = []
  }
  for component_nodes in components {
    let component_set = build_node_membership_set(component_nodes)
    let reorder_call_inputs =
      build_root_component_reorder_inputs(
        component_nodes,
        component_set,
        inputs,
      )
    let ordered_component =
      run_root_rank_reorder_call(
        reorder_call_inputs,
        root_graphviz_flip,
        coalesce_parallel,
      )
    append_component_rank_groups(
      order_rank_keys_for_mincross,
      merged,
      ordered_component,
    )
  }
  merged
}

///|
/// Graphviz parity: root ReMincross runs mincross per connected component
/// (dot_mincross init_mccomp loop), then concatenates rank output by component.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_rank_reorder(
  inputs : RootRankReorderInputs,
) -> Map[Int, Array[String]] {
  let (components, root_graphviz_flip) =
    build_root_component_runtime_plan(
      inputs.order_cluster_keys,
      inputs.graphviz_flip,
      inputs.order_rank_keys_for_mincross,
      inputs.order_groups_for_mincross,
      inputs.order_node_order,
      inputs.graphviz_out_neighbors,
      inputs.graphviz_in_neighbors,
      inputs.order_flat_constraints,
    )
  let coalesce_parallel =
    @sys.get_env_var("DOT_NO_COALESCE_PARALLEL") is None
  if components.length() <= 1 {
    return run_root_rank_reorder_call(
      inputs,
      root_graphviz_flip,
      coalesce_parallel,
    )
  }
  run_componentwise_root_rank_reorder(
    components,
    inputs.order_rank_keys_for_mincross,
    inputs,
    root_graphviz_flip,
    coalesce_parallel,
  )
}

///|
/// Graphviz parity: root rank-reorder runtime setup keeps cluster-key gating,
/// component traversal plan, and graphviz_flip mode aligned with Graphviz.
/// Do not change behavior without updating fixtures/tests.
pub fn build_root_component_runtime_plan(
  order_cluster_keys : Map[String, String],
  graphviz_flip : Bool,
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_node_order : Map[String, Int],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_flat_constraints : Map[String, Bool],
) -> (Array[Array[String]], Bool) {
  let has_cluster_keys = has_non_empty_cluster_keys(order_cluster_keys)
  // Graphviz parity: cluster-aware root mincross runs in internal TB
  // coordinates (like mincross_clust subgraph passes), so flip is off.
  let components =
    if has_cluster_keys {
      []
    } else {
      collect_noncluster_components(
        order_rank_keys_for_mincross,
        order_groups_for_mincross,
        order_node_order,
        graphviz_out_neighbors,
        graphviz_in_neighbors,
        order_flat_constraints,
      )
    }
  let root_graphviz_flip =
    if has_cluster_keys {
      false
    } else {
      graphviz_flip
    }
  (components, root_graphviz_flip)
}
