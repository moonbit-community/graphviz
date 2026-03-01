///|
/// Stage C Phase C0 split: ordering setup-stage
/// type definitions for reorder/materialize preparation.

///|
/// Stage C Phase C0 split: ordering runtime
/// context type for pre-class2 setup derivation.

///|
priv struct OrderingRuntimeContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
  vnode_count : Int
}

///|
priv struct OrderingReorderSetup {
  ordering_groups_base : Map[Int, Array[String]]
  base_order_index : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  graphviz_flip : Bool
  flat_rank_constraints : Map[String, Bool]
  class2_data : OrderingClass2Data
  gdnlist_order : Array[String]
  vnode_order_keys_for_ordering : Map[String, Double]
}

///|
priv struct OrderingDispatchSetup {
  edge_port_data : OrderingEdgePortData
  reorder_setup : OrderingReorderSetup
  nlist_order : Array[String]
  vnode_creation_order : Array[String]
  gdnlist_order : Array[String]
}


///|
/// Stage C Phase C0 split: ordering setup context
/// and dispatch preparation helpers.

///|
/// Graphviz parity: ordering runtime prep keeps vnode tail-constraint derivation
/// in the same position as Graphviz ordering setup, even when only used for
/// parity diagnostics.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingRuntimeContext {
  // Graphviz parity: ordering pre-pass collects real-node maps, edge cluster
  // ownership, vnode chains, and local cluster/port constraints before class2.
  let real_nodes : Map[String, Bool] = Map::new()
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    let name = node.name()
    real_nodes[name] = true
    existing_names[name] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
    cluster_meta.cluster_parents,
  )
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = @dot_shared.port_is_explicit(edge.tail_port()) ||
      @dot_shared.port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  let local_cluster_order = build_local_cluster_order(
    nodes,
    cluster_meta.intercluster_keys,
    ranks,
    node_order,
  )
  // Graphviz parity: rank=same does not inject extra flat constraints at this stage.
  let rank_same_constraints : Map[String, Bool] = Map::new()
  let runtime_context =
    {
      real_nodes,
      edge_cluster_keys,
      vnode_info,
      port_edge_nodes,
      local_cluster_order,
      rank_same_constraints,
      vnode_count: vnode_info.vnode_ranks.length(),
    }
  // Graphviz parity: probe vnode tail constraints in setup order even though
  // the result is diagnostic-only.
  let _ =
    if runtime_context.vnode_count > 0 {
      build_vnode_tail_constraints(runtime_context.vnode_info.vnodes_by_rank, edge_tail)
    } else {
      Map::new()
    }
  runtime_context
}

///|
/// Graphviz parity: dispatch setup keeps edge-port extraction and reorder setup
/// sequence identical to Graphviz class2/mincross preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_setup(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  port_edge_nodes : Map[String, Bool],
  vnode_count : Int,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> OrderingDispatchSetup {
  let edge_port_data =
    build_ordering_edge_port_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  // Graphviz parity: reorder setup preserves class2/GD_nlist prep order before
  // clustered/nonclustered mincross paths diverge.
  let ordering_groups_base = apply_rank_same_order_with_ports(
    groups,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    node_order,
    port_edge_nodes,
  )
  let base_order_index = build_order_index(ordering_groups_base)
  let order_with_vnodes = vnode_count > 0
  let order_with_clusters =
    cluster_meta.has_clusters && cluster_meta.cluster_min_rank.length() > 0
  let graphviz_flip = rankdir == RankDir::RL || rankdir == RankDir::LR
  // Graphviz parity: flat edge constraints include same-rank non-self edges
  // and use missing-rank fallback 0 exactly as class2 input pre-pass.
  let flat_rank_constraints : Map[String, Bool] = Map::new()
  let mut flat_idx = 0
  while flat_idx < edge_tail.length() {
    let tail = edge_tail[flat_idx]
    let head = edge_head[flat_idx]
    if tail != head {
      let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
      let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
      if tail_rank == head_rank {
        flat_rank_constraints["\{tail}|\{head}"] = true
      }
    }
    flat_idx = flat_idx + 1
  }
  // Graphviz parity: reorder setup derives class2 data, GD_nlist order, and
  // vnode ordering keys in Graphviz class2->decompose->vnode-key sequence.
  let class2_data =
    build_ordering_class2_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      edge_port_data.edge_tail_port_x,
      edge_port_data.edge_head_port_x,
      edge_port_data.edge_tail_port_order,
      edge_port_data.edge_head_port_order,
      ranks,
      vnode_info.edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      cluster_meta,
      flat_rank_constraints,
      graphviz_flip,
    )
  // Graphviz parity: GD_nlist follows decompose DFS order over fast graph edges.
  // Do not change behavior without updating fixtures/tests.
  let gdnlist_order =
    if @sys.get_env_var("DOT_DEBUG_GDNLIST_FROM_CREATION_REV") is Some(_) ||
      (graphviz_flip && cluster_meta.cluster_order.length() > 1) {
      let reversed_creation_order : Array[String] = []
      let mut creation_idx = class2_data.creation_order.length()
      while creation_idx > 0 {
        creation_idx = creation_idx - 1
        reversed_creation_order.push(class2_data.creation_order[creation_idx])
      }
      reversed_creation_order
    } else {
      class2_data.nlist_order
    }
  let nlist_order_index : Map[String, Int] = Map::new()
  let mut nlist_idx = 0
  for name in class2_data.nlist_order {
    nlist_order_index[name] = nlist_idx
    nlist_idx = nlist_idx + 1
  }
  // Graphviz parity: vnode ordering keys come from cluster-aware class2 walks,
  // or from GD_nlist fallback ordering when clusters are absent.
  let vnode_order_keys_for_ordering =
    if vnode_count > 0 {
      if cluster_meta.has_clusters {
        build_vnode_order_keys(
          edges,
          edge_tail,
          edge_head,
          edge_reversed,
          ranks,
          base_order_index,
          cluster_meta.cluster_keys,
          cluster_meta.cluster_parents,
          vnode_info.edge_vnodes,
          vnode_info.vnode_ranks,
        )
      } else {
        build_vnode_order_keys_from_nlist(
          ordering_groups_base,
          vnode_info.vnodes_by_rank,
          base_order_index,
          nlist_order_index,
          Map::new(),
          false,
        )
      }
    } else {
      Map::new()
    }
  let reorder_setup =
    {
      ordering_groups_base,
      base_order_index,
      order_with_vnodes,
      order_with_clusters,
      graphviz_flip,
      flat_rank_constraints,
      class2_data,
      gdnlist_order,
      vnode_order_keys_for_ordering,
    }
  {
    edge_port_data,
    reorder_setup,
    nlist_order: class2_data.nlist_order,
    vnode_creation_order: class2_data.vnode_creation_order,
    gdnlist_order,
  }
}
