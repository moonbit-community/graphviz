///|
/// Stage C Phase C1 split: ordering class2
/// preprocessing helpers for order-graph construction.

///|
/// Stage C Phase C1 split: ordering edge-port/class2
/// runtime data types produced by class2 preprocessing.

///|
priv struct OrderingEdgePortData {
  edge_order : Map[String, Int]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
priv struct OrderingClass2Data {
  edges_by_tail : Map[String, Array[Int]]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  root_edge_creation : Array[(String, String)]
  skeleton_edge_creation : Array[(String, String)]
  edge_creation_order : Array[(String, String)]
  creation_order : Array[String]
  nlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
/// Graphviz parity: order-graph edge arrays preserve original edge sequence,
/// then reuse deduplicated order edges for mincross-specific port sampling.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> OrderingEdgePortData {
  // Graphviz parity: edge-port original phase keeps original edge order map and
  // per-edge port position/order arrays before any ordering-edge deduplication.
  let edge_order = collect_edge_order(edges)
  let (edge_tail_port_x, edge_head_port_x) =
    compute_edge_port_positions(nodes, edges, edge_tail, edge_head, order_sizes)
  let (edge_tail_port_order, edge_head_port_order) =
    compute_edge_port_orders(nodes, edges, edge_tail, edge_head, order_sizes)
  // Graphviz parity: edge-port dedup phase derives ordering-edge arrays and
  // recomputes port position/order samples on deduplicated ordering edges.
  let (order_edges, order_edge_tail, order_edge_head) =
    dedup_ordering_edges(edges, edge_tail, edge_head)
  let (
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  ) =
    {
      let (tail_port_x, head_port_x) =
        compute_edge_port_positions(
          nodes,
          order_edges,
          order_edge_tail,
          order_edge_head,
          order_sizes,
        )
      let (tail_port_order, head_port_order) =
        compute_edge_port_orders(
          nodes,
          order_edges,
          order_edge_tail,
          order_edge_head,
          order_sizes,
        )
      (
        tail_port_x,
        head_port_x,
        tail_port_order,
        head_port_order,
      )
    }
  {
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}

///|
/// Graphviz parity: class2/decompose ordering prep follows creation order,
/// ND_out traversal, cluster skeleton insertion, then GD_nlist construction.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> OrderingClass2Data {
  // Graphviz parity: class2 iterates agfstnode order (creation order) for edge traversal.
  let creation_order : Array[String] = []
  for node in nodes {
    creation_order.push(node.name())
  }
  // Graphviz parity: order-graph edges follow ND_out ordering after acyclic.
  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  for node in nodes {
    let name = node.name()
    match edge_out_order.get(name) {
      Some(list) => edges_by_tail[name] = list.copy()
      None => edges_by_tail[name] = []
    }
  }
  let (order_edges_by_tail, vnode_creation_by_tail, order_edge_creation) =
    build_order_edges_by_tail(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_meta.cluster_keys,
      order_with_clusters,
      false,
      true,
      edges_by_tail,
    )
  let (
    order_edges_by_tail_root,
    root_edge_creation,
  ) =
    // Graphviz parity: root order-edge chains use remapped cluster endpoints,
    // while non-cluster graphs reuse the base order_edges_by_tail mapping.
    if order_with_clusters {
      let (root_edges_by_tail, _root_vnode_creation_by_tail, root_edge_creation) =
        build_order_edges_by_tail(
          creation_order,
          edges,
          edge_tail,
          edge_head,
          edge_tail_port_x,
          edge_head_port_x,
          edge_tail_port_order,
          edge_head_port_order,
          ranks,
          edge_vnodes,
          order_with_vnodes,
          cluster_meta.cluster_keys,
          order_with_clusters,
          true,
          true,
          edges_by_tail,
        )
      (root_edges_by_tail, root_edge_creation)
    } else {
      (order_edges_by_tail, order_edge_creation)
    }
  // Graphviz parity: cluster-local build_ranks uses edge chains before
  // root/cluster remapping so local passes see original cluster endpoints.
  let order_edges_by_tail_unmapped =
    if order_with_clusters {
      let (unmapped_edges_by_tail, _unmapped_vnode_creation, _unmapped_edge_creation) =
        build_order_edges_by_tail(
          creation_order,
          edges,
          edge_tail,
          edge_head,
          edge_tail_port_x,
          edge_head_port_x,
          edge_tail_port_order,
          edge_head_port_order,
          ranks,
          edge_vnodes,
          order_with_vnodes,
          cluster_meta.cluster_keys,
          order_with_clusters,
          false,
          false,
          edges_by_tail,
        )
      unmapped_edges_by_tail
    } else {
      order_edges_by_tail
    }
  // Graphviz parity: class2 creation sequences build cluster skeleton edges,
  // then edge creation order and GD_nlist ordering in Graphviz pass order.
  // Graphviz parity: cluster skeleton creation follows cluster_order first,
  // then remaining cluster_min_rank iteration order.
  let cluster_skeleton_creation : Array[String] = []
  if order_with_clusters {
    let cluster_seen : Map[String, Bool] = Map::new()
    for cluster in cluster_meta.cluster_order {
      match cluster_meta.cluster_min_rank.get(cluster) {
        Some(min_rank) => {
          let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
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
    for cluster, min_rank in cluster_meta.cluster_min_rank {
      if cluster_seen.get(cluster) is Some(_) {
        continue
      }
      let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
        Some(value) => value
        None => min_rank
      }
      for rank in min_rank..=max_rank {
        cluster_skeleton_creation.push(
          cluster_skeleton_name_for_rank(cluster, rank),
        )
      }
    }
  }
  let skeleton_edge_creation =
    build_skeleton_edge_creation_for_order_graph(
      order_with_clusters,
      cluster_meta.cluster_order,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
      order_edges_by_tail,
      order_edges_by_tail_root,
    )
  let edge_creation_order =
    merge_edge_creation_sequences(
      skeleton_edge_creation,
      order_edge_creation,
    )
  // Graphviz parity: class2 order_creation starts with cluster skeletons, then
  // agfstnode real nodes interleaved with edge-vnodes per tail.
  let (order_creation, vnode_creation_order) =
    {
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
        // Graphviz parity: each real-node tail emits itself first, followed by
        // its per-tail vnode sequence, while preserving first-seen dedup semantics.
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
  // Graphviz parity: decompose DFS starts from agfstnode (creation) order
  // regardless of rankdir flip.
  let nlist_tail_order =
    if cluster_meta.has_clusters {
      creation_order
    } else {
      order_creation
    }
  let nlist_order_raw =
    @dot_shared.build_graphviz_nlist_order_from_edges(
      nlist_tail_order,
      order_creation,
      edge_creation_order,
      flat_rank_constraints,
    )
  let nlist_order =
    adjust_nlist_order_for_cluster_flip(
      nlist_order_raw,
      graphviz_flip,
      cluster_meta.has_clusters,
      cluster_meta.cluster_keys,
    )
  {
    edges_by_tail,
    order_edges_by_tail,
    order_edges_by_tail_root,
    order_edges_by_tail_unmapped,
    root_edge_creation,
    skeleton_edge_creation,
    edge_creation_order,
    creation_order,
    nlist_order,
    vnode_creation_order,
  }
}
