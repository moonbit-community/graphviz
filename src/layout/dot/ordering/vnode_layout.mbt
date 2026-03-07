
///|
pub(all) struct EdgeVnodeBuildDeps {
  edge_mid_label_metrics_for : (@cgraph.Edge) -> (Double, Double)?
}

///|
/// Graphviz parity: class2 virtual node creation order + sizing.
/// Do not change behavior without updating fixtures/tests.
pub fn build_edge_vnodes(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  nodesep_pt : Double,
  rankdir : @shared.RankDir,
  existing_names : Map[String, Bool],
  edge_cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  deps : EdgeVnodeBuildDeps,
) -> @routing.EdgeVnodeInfo {
  let vnode_ranks : Map[String, Int] = Map::new()
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  let vnode_clusters : Map[String, String] = Map::new()
  let tail_order : Array[String] = []
  for node in nodes {
    tail_order.push(node.name())
  }
  let edge_indices : Array[Int] = []
  let mut use_out_order = false
  for _key, _ in edge_out_order {
    use_out_order = true
    break
  }
  if use_out_order {
    for tail in tail_order {
      let list = match edge_out_order.get(tail) {
        Some(value) => value
        None => []
      }
      for idx in list {
        edge_indices.push(idx)
      }
    }
  } else {
    for idx in 0..<edges.length() {
      edge_indices.push(idx)
    }
  }
  let plain_width = 1.0 + nodesep_pt / 2.0
  for idx in edge_indices {
    let edge = edges[idx]
    let (tail, head) =
      edge_endpoints_at(
        edge,
        idx,
        edge_tail,
        edge_head,
      )
    let tail_cluster = @clustering.node_cluster_key(edge.tail())
    let head_cluster = @clustering.node_cluster_key(edge.head())
    // Graphviz parity: cluster-local parallel chains do not widen class2 vnodes.
    let use_cluster_plain =
      tail_cluster != "" && tail_cluster == head_cluster
    let delta = if use_cluster_plain { 0.0 } else { nodesep_pt / 2.0 }
    let key = @edge_identity.edge_vnode_key(edge)
    match edge_vnodes.get(key) {
      Some(list) => {
        for name in list {
          match vnode_sizes.get(name) {
            Some(size) => {
              let left = size.left_pt + delta
              let right = size.right_pt + delta
              vnode_sizes[name] =
                @node_primitives.vnode_size_from_widths_with_h(left, right, size.height_pt)
            }
            None => ()
          }
        }
        continue
      }
      None => ()
    }
    let label = match edge.get_attr("label") {
      Some(value) => value
      None => ""
    }
    if label == "" {
      // Graphviz parity: reverse-direction duplicate edges reuse the
      // existing virtual chain and only widen shared virtual nodes.
      let reverse_key =
        "\{edge.head().name()}|\{edge.tail().name()}|\{@edge_identity.port_key(edge.head_port())}|\{@edge_identity.port_key(edge.tail_port())}"
      match edge_vnodes.get(reverse_key) {
        Some(list) => {
          for name in list {
            match vnode_sizes.get(name) {
              Some(size) => {
                let left = size.left_pt + delta
                let right = size.right_pt + delta
                vnode_sizes[name] =
                  @node_primitives.vnode_size_from_widths_with_h(left, right, size.height_pt)
              }
              None => ()
            }
          }
          edge_vnodes[key] = list
          continue
        }
        None => ()
      }
    }
    // Graphviz parity: cluster-local vnodes use the virtual_node default width.
    let plain_width_for_edge = if use_cluster_plain { 1.0 } else { plain_width }
    let vnode_cluster =
      if tail_cluster != "" || head_cluster != "" {
        @clustering.cluster_lca(tail_cluster, head_cluster, cluster_parents)
      } else {
        match edge_cluster_keys.get(@edge_identity.edge_key(edge)) {
          Some(value) => value
          None => ""
        }
      }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => {
        continue
      }
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => {
        continue
      }
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      continue
    }
    let (label_width, label_height) =
      match (deps.edge_mid_label_metrics_for)(edge) {
      Some((width, height)) =>
        if rankdir == @shared.RankDir::LR || rankdir == @shared.RankDir::RL {
          (height, width)
        } else {
          (width, height)
        }
      None => (0.0, 0.0)
    }
    let label_rank = if label_width > 0.0 { (min_rank + max_rank) / 2 } else { -1 }
    let names : Array[String] = []
    let mut rank = min_rank + 1
    while rank < max_rank {
      let is_label_rank = rank == label_rank && label_width > 0.0
      let name = @edge_identity.unique_virtual_node_name(
        @edge_identity.EDGE_VNODE_PREFIX,
        idx,
        rank,
        existing_names,
      )
      vnode_ranks[name] = rank
      vnode_sizes[name] =
        if is_label_rank {
        @node_primitives.vnode_size_from_widths_with_h(
          nodesep_pt,
          label_width,
          label_height,
        )
      } else {
        @node_primitives.vnode_size_from_widths(plain_width_for_edge, plain_width_for_edge)
      }
      vnode_clusters[name] = vnode_cluster
      match vnodes_by_rank.get(rank) {
        Some(list) => list.push(name)
        None => vnodes_by_rank[rank] = [name]
      }
      names.push(name)
      rank = rank + 1
    }
    if names.length() > 0 {
      match edge_vnodes.get(key) {
        Some(list) =>
          for name in names {
            list.push(name)
          }
        None => edge_vnodes[key] = names
      }
    }
  }
  {
    vnode_ranks,
    vnode_sizes,
    vnodes_by_rank,
    edge_vnodes,
    vnode_clusters,
  }
}
