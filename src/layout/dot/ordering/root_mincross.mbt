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
/// Graphviz parity: root+cluster rank phase payload keeps root reorder inputs
/// and root override replay context unchanged before cluster-local pass.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct RootAndClusterRanksInputs {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  graphviz_flip : Bool
  cluster_keys : Map[String, String]
  root_groups_override : Map[Int, Array[String]]?
  root_mincross_reorder_inputs : RootMincrossReorderInputs
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
/// build_ranks application and vnode-inclusive output handoff for xpos.
/// Do not change behavior without updating fixtures/tests.
pub fn run_root_and_cluster_ranks(
  inputs : RootAndClusterRanksInputs,
  run_root_reorder : (RootMincrossReorderInputs, Map[Int, Array[String]]?) -> RootMincrossReorderResult,
  run_cluster_reorder : (Map[Int, Array[String]]) -> Unit,
) -> RootAndClusterRanksOutput {
  let root_reorder_result =
    run_root_reorder(
      inputs.root_mincross_reorder_inputs,
      inputs.root_groups_override,
    )
  let order_groups_for_mincross = root_reorder_result.order_groups_for_mincross
  let root_ordered_groups = root_reorder_result.ordered
  let ordered =
    resolve_root_phase_ordered_groups(
      root_ordered_groups,
      inputs.root_groups_override,
      inputs.cluster_keys,
      inputs.graphviz_flip,
    )
  if inputs.order_with_clusters {
    run_cluster_reorder(ordered)
  }
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
