///|
/// Ordering domain: class2 preprocessing helpers for order-graph assembly.

///|
pub(all) struct OrderingClass2Data {
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
pub(all) struct OrderingReorderSetup {
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
/// Graphviz parity: flat edge constraints include same-rank non-self edges
/// and use missing-rank fallback 0 exactly as class2 input pre-pass.
pub fn build_flat_rank_constraints(
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let flat_rank_constraints : Map[String, Bool] = Map::new()
  let mut flat_idx = 0
  while flat_idx < edge_tail.length() {
    let tail = edge_tail[flat_idx]
    let head = edge_head[flat_idx]
    if tail != head {
      let tail_rank = flat_constraint_rank_or_zero(ranks, tail)
      let head_rank = flat_constraint_rank_or_zero(ranks, head)
      if tail_rank == head_rank {
        flat_rank_constraints["\{tail}|\{head}"] = true
      }
    }
    flat_idx = flat_idx + 1
  }
  flat_rank_constraints
}

///|
/// Graphviz parity: GD_nlist follows decompose DFS order over fast graph
/// edges, with optional creation-order reverse debug/flip override.
/// Do not change behavior without updating fixtures/tests.
pub fn build_gdnlist_order(
  class2_data : OrderingClass2Data,
  graphviz_flip : Bool,
  cluster_order : Array[String],
) -> Array[String] {
  if @sys.get_env_var("DOT_DEBUG_GDNLIST_FROM_CREATION_REV") is Some(_) ||
    (graphviz_flip && cluster_order.length() > 1) {
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
}

///|
/// Graphviz parity: reorder setup derives class2 data, GD_nlist order, and
/// vnode ordering keys in Graphviz class2->decompose->vnode-key sequence.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct OrderingReorderSetupInput {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  port_edge_nodes : Map[String, Bool]
  vnode_count : Int
  graphviz_flip : Bool
  has_clusters : Bool
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_keys : Map[String, String]
  cluster_order : Array[String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  vnode_edge_vnodes : Map[String, Array[String]]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_ranks : Map[String, Int]
  cluster_parents : Map[String, String?]
  edge_port_data : OrderingEdgePortData
}

///|
/// Graphviz parity: reorder setup derives class2 data, GD_nlist order, and
/// vnode ordering keys in Graphviz class2->decompose->vnode-key sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_reorder_setup(
  input : OrderingReorderSetupInput,
) -> OrderingReorderSetup {
  let ordering_groups_base = apply_rank_same_order(
    input.groups,
    input.rank_same_groups,
    input.rank_same_order,
    input.node_order,
    input.port_edge_nodes,
  )
  let base_order_index = build_order_index(ordering_groups_base)
  let order_with_vnodes = input.vnode_count > 0
  let order_with_clusters = input.has_clusters && input.cluster_min_rank.length() > 0
  let flat_rank_constraints =
    build_flat_rank_constraints(input.edge_tail, input.edge_head, input.ranks)
  let class2_data =
    build_ordering_class2_data(
      input.nodes,
      input.edges,
      input.edge_tail,
      input.edge_head,
      input.edge_out_order,
      input.edge_port_data.edge_tail_port_x,
      input.edge_port_data.edge_head_port_x,
      input.edge_port_data.edge_tail_port_order,
      input.edge_port_data.edge_head_port_order,
      input.ranks,
      input.vnode_edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      input.cluster_keys,
      input.cluster_order,
      input.cluster_min_rank,
      input.cluster_max_rank,
      input.has_clusters,
      flat_rank_constraints,
      input.graphviz_flip,
    )
  let gdnlist_order =
    build_gdnlist_order(
      class2_data,
      input.graphviz_flip,
      input.cluster_order,
    )
  let nlist_order_index : Map[String, Int] = Map::new()
  let mut nlist_idx = 0
  for name in class2_data.nlist_order {
    nlist_order_index[name] = nlist_idx
    nlist_idx = nlist_idx + 1
  }
  let vnode_order_keys_for_ordering =
    if input.vnode_count <= 0 {
      Map::new()
    } else if input.has_clusters {
      build_vnode_order_keys(
        input.edges,
        input.edge_tail,
        input.edge_head,
        input.edge_reversed,
        input.ranks,
        base_order_index,
        input.cluster_keys,
        input.cluster_parents,
        input.vnode_edge_vnodes,
        input.vnode_ranks,
      )
    } else {
      build_vnode_keys_from_nlist(
        ordering_groups_base,
        input.vnodes_by_rank,
        base_order_index,
        nlist_order_index,
        Map::new(),
        false,
      )
    }
  {
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    graphviz_flip: input.graphviz_flip,
    flat_rank_constraints,
    class2_data,
    gdnlist_order,
    vnode_order_keys_for_ordering,
  }
}

///|
const CL_CROSS : Int = 1000

///|
fn skeleton_name_for_rank(cluster : String, rank : Int) -> String {
  @clustering.cluster_skeleton_name(cluster, rank)
}

///| 
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

///|
/// Graphviz parity: class2/decompose ordering prep follows creation order,
/// ND_out traversal, cluster skeleton insertion, then GD_nlist construction.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_class2_data(
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
  cluster_keys : Map[String, String],
  cluster_order : Array[String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  has_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> OrderingClass2Data {
  let creation_order : Array[String] = []
  for node in nodes {
    creation_order.push(node.name())
  }
  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  for node in nodes {
    let name = node.name()
    match edge_out_order.get(name) {
      Some(list) => edges_by_tail[name] = list.copy()
      None => edges_by_tail[name] = []
    }
  }
  let order_edges_by_tail_output =
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
      cluster_keys,
      order_with_clusters,
      false,
      true,
      edges_by_tail,
    )
  let order_edges_by_tail = order_edges_by_tail_output.order_edges_by_tail
  let vnode_creation_by_tail = order_edges_by_tail_output.vnode_creation_by_tail
  let order_edge_creation = order_edges_by_tail_output.edge_creation_order
  let (
    order_edges_by_tail_root,
    root_edge_creation,
  ) =
    if order_with_clusters {
      let root_edges_by_tail_output =
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
          cluster_keys,
          order_with_clusters,
          true,
          true,
          edges_by_tail,
        )
      let root_edges_by_tail = root_edges_by_tail_output.order_edges_by_tail
      let root_edge_creation = root_edges_by_tail_output.edge_creation_order
      (root_edges_by_tail, root_edge_creation)
    } else {
      (order_edges_by_tail, order_edge_creation)
    }
  let order_edges_by_tail_unmapped =
    if order_with_clusters {
      let unmapped_output =
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
          cluster_keys,
          order_with_clusters,
          false,
          false,
          edges_by_tail,
        )
      let unmapped_edges_by_tail = unmapped_output.order_edges_by_tail
      unmapped_edges_by_tail
    } else {
      order_edges_by_tail
    }
  let cluster_skeleton_creation : Array[String] = []
  if order_with_clusters {
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
              skeleton_name_for_rank(cluster, rank),
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
          skeleton_name_for_rank(cluster, rank),
        )
      }
    }
  }
  let skeleton_edge_creation =
    build_skeleton_edge_creation(
      order_with_clusters,
      cluster_order,
      cluster_min_rank,
      cluster_max_rank,
      order_edges_by_tail,
      order_edges_by_tail_root,
    )
  let edge_creation_order =
    merge_edge_creation_sequences(
      skeleton_edge_creation,
      order_edge_creation,
    )
  let (order_creation, vnode_creation_order) =
    {
      let order_creation : Array[String] = []
      let order_seen : Map[String, Bool] = Map::new()
      for name in cluster_skeleton_creation {
        append_creation_name(
          order_creation,
          order_seen,
          name,
        )
      }
      for tail_name in creation_order {
        append_creation_name(
          order_creation,
          order_seen,
          tail_name,
        )
        let vnodes = match vnode_creation_by_tail.get(tail_name) {
          Some(list) => list
          None => []
        }
        for vnode in vnodes {
          append_creation_name(
            order_creation,
            order_seen,
            vnode,
          )
        }
      }
      let vnode_creation_order : Array[String] = []
      for name in order_creation {
        if @edge_identity.is_edge_vnode_name(name) {
          vnode_creation_order.push(name)
        }
      }
      (order_creation, vnode_creation_order)
    }
  let nlist_tail_order =
    if has_clusters {
      creation_order
    } else {
      order_creation
    }
  let nlist_order_raw =
    @shared.build_graphviz_nlist_order_from_edges(
      nlist_tail_order,
      order_creation,
      edge_creation_order,
      flat_rank_constraints,
    )
  let nlist_order =
    adjust_nlist_order_for_flip(
      nlist_order_raw,
      graphviz_flip,
      has_clusters,
      cluster_keys,
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

///|
/// Ordering domain: edge-port sampling outputs used by class2 preprocessing.

///|
pub(all) struct OrderingEdgePortData {
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
/// Graphviz parity: ordering edge-port data input keeps precomputed full-edge
/// and dedup-order-edge samples grouped before class2 reorder setup.
pub(all) struct OrderingEdgePortDataInput {
  edges : Array[@cgraph.Edge]
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
/// Graphviz parity: order-edge data keeps original edge sequence and deduped
/// order-edge snapshots identical to precomputed Stage C sampling.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_edge_port_data(
  input : OrderingEdgePortDataInput,
) -> OrderingEdgePortData {
  let edge_order = collect_edge_order(input.edges)
  {
    edge_order,
    edge_tail_port_x: input.edge_tail_port_x,
    edge_head_port_x: input.edge_head_port_x,
    edge_tail_port_order: input.edge_tail_port_order,
    edge_head_port_order: input.edge_head_port_order,
    order_edges: input.order_edges,
    order_edge_tail: input.order_edge_tail,
    order_edge_head: input.order_edge_head,
    order_edge_tail_port_x: input.order_edge_tail_port_x,
    order_edge_head_port_x: input.order_edge_head_port_x,
    order_edge_tail_port_order: input.order_edge_tail_port_order,
    order_edge_head_port_order: input.order_edge_head_port_order,
  }
}
