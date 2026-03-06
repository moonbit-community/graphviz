///|
/// Flat-label vnode injection helpers for positioning/x-order constraints,
/// aligned with Graphviz flat-edge label behavior.

///|
priv struct FlatLabelNodeInfo {
  tail : String
  head : String
  rank : Int
}

///|
fn flat_label_adjacent(
  rank : Int,
  tail : String,
  head : String,
  ordered_groups : Map[Int, Array[String]],
) -> Bool {
  let names = match ordered_groups.get(rank) {
    Some(list) => list
    None => []
  }
  if names.length() == 0 {
    return false
  }
  let mut tail_idx = -1
  let mut head_idx = -1
  for i in 0..<names.length() {
    if names[i] == tail {
      tail_idx = i
    }
    if names[i] == head {
      head_idx = i
    }
  }
  if tail_idx < 0 || head_idx < 0 {
    return false
  }
  let diff = if tail_idx > head_idx {
    tail_idx - head_idx
  } else {
    head_idx - tail_idx
  }
  diff <= 1
}

///|
fn collect_vnode_out_heads(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out_heads : Map[String, Array[String]] = Map::new()
  let mut edge_idx = 0
  for edge in edges {
    let (tail, head) =
      @ordering.edge_endpoints_at(
        edge,
        edge_idx,
        edge_tail,
        edge_head,
      )
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let path : Array[String] = []
    path.push(tail)
    if tail_rank <= head_rank {
      for vnode in vnodes {
        path.push(vnode)
      }
    } else {
      let mut idx = vnodes.length()
      while idx > 0 {
        idx = idx - 1
        path.push(vnodes[idx])
      }
    }
    path.push(head)
    let mut i = 0
    while i + 1 < path.length() {
      let from = path[i]
      let to = path[i + 1]
      if @dot_shared.is_edge_vnode_name(from) {
        match out_heads.get(from) {
          Some(list) => list.push(to)
          None => out_heads[from] = [to]
        }
      }
      i = i + 1
    }
  }
  out_heads
}

///|
fn flat_limits(
  rank_nodes : Array[String],
  order_index : Map[String, Int],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  vnode_out_heads : Map[String, Array[String]],
  tail : String,
  head : String,
) -> Int {
  let tail_pos = match order_index.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_pos = match order_index.get(head) {
    Some(value) => value
    None => 0
  }
  let lpos = if tail_pos <= head_pos { tail_pos } else { head_pos }
  let rpos = if tail_pos <= head_pos { head_pos } else { tail_pos }
  let n = rank_nodes.length()
  if n == 0 {
    return 0
  }
  let mut lnode = 0
  let mut rnode = n - 1
  let bounds : Array[Int] = [lnode - 1, rnode + 1, lnode - 1, rnode + 1]
  let setbounds = (name : String) => {
    let is_flat = flat_label_nodes.get(name) is Some(_)
    if !is_flat && !@dot_shared.is_edge_vnode_name(name) {
      return ()
    }
    let ord = match order_index.get(name) {
      Some(value) => value
      None => return ()
    }
    match flat_label_nodes.get(name) {
      Some(info) => {
        let tail_ord = match order_index.get(info.tail) {
          Some(value) => value
          None => return ()
        }
        let head_ord = match order_index.get(info.head) {
          Some(value) => value
          None => return ()
        }
        let left = if tail_ord <= head_ord { tail_ord } else { head_ord }
        let right = if tail_ord <= head_ord { head_ord } else { tail_ord }
        if right <= lpos {
          bounds[2] = ord
          bounds[0] = ord
        } else if left >= rpos {
          bounds[3] = ord
          bounds[1] = ord
        } else if left < lpos && right > rpos {
          ()
        } else {
          if left < lpos || (left == lpos && right < rpos) {
            bounds[2] = ord
          }
          if right > rpos || (right == rpos && left > lpos) {
            bounds[3] = ord
          }
        }
      }
      None => {
        let heads = match vnode_out_heads.get(name) {
          Some(list) => list
          None => []
        }
        let mut onleft = false
        let mut onright = false
        for head_name in heads {
          let head_ord = match order_index.get(head_name) {
            Some(value) => value
            None => continue
          }
          if head_ord <= lpos {
            onleft = true
          }
          if head_ord >= rpos {
            onright = true
          }
        }
        if onleft && !onright {
          bounds[0] = ord + 1
        }
        if onright && !onleft {
          bounds[1] = ord - 1
        }
      }
    }
  }
  while lnode <= rnode {
    setbounds(rank_nodes[lnode])
    if lnode != rnode {
      setbounds(rank_nodes[rnode])
    }
    lnode = lnode + 1
    rnode = rnode - 1
    if bounds[1] - bounds[0] <= 1 {
      break
    }
  }
  if bounds[0] <= bounds[1] {
    (bounds[0] + bounds[1] + 1) / 2
  } else {
    (bounds[2] + bounds[3] + 1) / 2
  }
}

///|
fn add_flat_label_vnodes(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  ordered_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  rankdir : RankDir,
  sizes : Map[String, NodeSize],
  edge_cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  existing_names : Map[String, Bool],
  vnode_info : @routing.EdgeVnodeInfo,
  x_groups : Map[Int, Array[String]],
) -> FlatLabelVnodeResult {
  let order_index = @ordering.build_order_index(x_groups)
  let vnode_out_heads =
    collect_vnode_out_heads(edges, edge_tail, edge_head, ranks, vnode_info.edge_vnodes)
  let flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let flat_label_edges : Map[String, String] = Map::new()
  let extra_edges : Array[ConstraintEdge] = []
  let mut edge_idx = 0
  let insert_at = (names : Array[String], pos : Int, value : String) => {
    let result : Array[String] = []
    let mut idx = 0
    let insert_pos =
      if pos < 0 {
      0
    } else if pos > names.length() {
      names.length()
    } else {
      pos
    }
    while idx < insert_pos {
      result.push(names[idx])
      idx = idx + 1
    }
    result.push(value)
    while idx < names.length() {
      result.push(names[idx])
      idx = idx + 1
    }
    result
  }
  let rebuild_order = (names : Array[String]) => {
    for i in 0..<names.length() {
      order_index[names[i]] = i
    }
  }
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let (tail, head) =
      @ordering.edge_endpoints_at(
        edge,
        current_idx,
        edge_tail,
        edge_head,
      )
    if tail == head {
      // Graphviz parity: self-edge labels are handled via node spacing, not flat labels.
      continue
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    if tail_rank != head_rank {
      continue
    }
    let metrics = match edge_mid_label_metrics(edge) {
      Some(value) => value
      None => continue
    }
    let metric_width = metrics.width
    let metric_height = metrics.height
    let (label_width, label_height) =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      (metric_height, metric_width)
    } else {
      (metric_width, metric_height)
    }
    if label_width <= 0.0 {
      continue
    }
    let is_adjacent = flat_label_adjacent(tail_rank, tail, head, ordered_groups)
    let left =
      match (order_index.get(tail), order_index.get(head)) {
        (Some(tail_pos), Some(head_pos)) =>
          if tail_pos <= head_pos { tail } else { head }
        _ => tail
      }
    let right = if left == tail { head } else { tail }
    let left_right = @dot_shared.node_right_pt(left, sizes)
    let right_left = @dot_shared.node_left_pt(right, sizes)
    let width = left_right + right_left
    let base_minlen =
      Double::from_int(@dot_shared.edge_minlen(edge)) * nodesep_pt + width
    if is_adjacent {
      let label_minlen = width + nodesep_pt + label_width
      // Graphviz parity: LR/RL flat-label adjacency uses integer rounding that
      // yields a +1pt spacing in reference outputs.
      let minlen_base =
        if base_minlen > label_minlen { base_minlen } else { label_minlen }
      let minlen_adjusted =
        if rankdir == RankDir::LR || rankdir == RankDir::RL {
        minlen_base + 1.0
      } else {
        minlen_base
      }
      let minlen = @dot_shared.round_int(minlen_adjusted)
      extra_edges.push({
        tail: left,
        head: right,
        minlen,
        weight: @dot_shared.edge_weight(edge),
        tail_port: None,
        head_port: None,
      })
      continue
    }
    let label_rank = tail_rank - 1
    let names = match x_groups.get(label_rank) {
      Some(list) => list.copy()
      None => []
    }
    let place =
      flat_limits(names, order_index, flat_label_nodes, vnode_out_heads, tail, head)
    let name = @dot_shared.unique_virtual_node_name(
      @dot_shared.EDGE_VNODE_PREFIX,
      current_idx,
      label_rank,
      existing_names,
    )
    let half_width = label_width / 2.0
    vnode_info.vnode_ranks[name] = label_rank
    vnode_info.vnode_sizes[name] =
      @dot_shared.vnode_size_from_widths_with_h(half_width, half_width, label_height)
    let tail_cluster = @clustering.node_cluster_key(edge.tail())
    let head_cluster = @clustering.node_cluster_key(edge.head())
    let vnode_cluster =
      if tail_cluster != "" || head_cluster != "" {
        @clustering.cluster_lca(tail_cluster, head_cluster, cluster_parents)
      } else {
        match edge_cluster_keys.get(@dot_shared.edge_key(edge)) {
          Some(value) => value
          None => ""
        }
      }
    vnode_info.vnode_clusters[name] = vnode_cluster
    match vnode_info.vnodes_by_rank.get(label_rank) {
      Some(list) => list.push(name)
      None => vnode_info.vnodes_by_rank[label_rank] = [name]
    }
    let updated_rank = insert_at(names, place, name)
    x_groups[label_rank] = updated_rank
    rebuild_order(updated_rank)
    flat_label_nodes[name] = {
      tail,
      head,
      rank: label_rank,
    }
    flat_label_edges[@dot_shared.edge_key(edge)] = name
    let vnode_edge_key = @dot_shared.edge_vnode_key(edge)
    match vnode_info.edge_vnodes.get(vnode_edge_key) {
      Some(list) => list.push(name)
      None => vnode_info.edge_vnodes[vnode_edge_key] = [name]
    }
    let graph_ordering =
      match @clustering.root_graph_for_node(edge.tail()).get_attr("ordering") {
      Some(value) => value.to_lower()
      None => ""
    }
    let m0_scale =
      if graph_ordering == "out" || graph_ordering == "in" {
      1.0
    } else {
      0.5
    }
    let m0 = Double::from_int(@dot_shared.edge_minlen(edge)) * nodesep_pt * m0_scale
    let minlen_left = @dot_shared.round_int(m0 + left_right + half_width)
    let minlen_right = @dot_shared.round_int(m0 + half_width + right_left)
    extra_edges.push({
      tail: left,
      head: name,
      minlen: minlen_left,
      weight: @dot_shared.edge_weight(edge),
      tail_port: None,
      head_port: None,
    })
    extra_edges.push({
      tail: name,
      head: right,
      minlen: minlen_right,
      weight: @dot_shared.edge_weight(edge),
      tail_port: None,
      head_port: None,
    })
  }
  {
    x_groups,
    flat_label_nodes,
    flat_label_edge_vnodes: flat_label_edges,
    flat_label_edges: extra_edges,
  }
}

///|
priv struct FlatLabelVnodeResult {
  x_groups : Map[Int, Array[String]]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
}

///|
fn build_flat_label_vnodes_for_positioning(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  ordered_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  rankdir : RankDir,
  x_base_sizes : Map[String, NodeSize],
  edge_cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  existing_names : Map[String, Bool],
  vnode_info : @routing.EdgeVnodeInfo,
  x_groups : Map[Int, Array[String]],
) -> @positioning.FlatLabelVnodeBuildOutput {
  let flat_label_vnodes = add_flat_label_vnodes(
    edges,
    edge_tail,
    edge_head,
    ranks,
    ordered_groups,
    nodesep_pt,
    rankdir,
    x_base_sizes,
    edge_cluster_keys,
    cluster_parents,
    existing_names,
    vnode_info,
    x_groups,
  )
  let flat_label_ranks : Map[String, Int] = Map::new()
  for name, info in flat_label_vnodes.flat_label_nodes {
    flat_label_ranks[name] = info.rank
  }
  {
    x_groups: flat_label_vnodes.x_groups,
    flat_label_edges: flat_label_vnodes.flat_label_edges,
    flat_label_ranks,
    flat_label_edge_vnodes: flat_label_vnodes.flat_label_edge_vnodes,
  }
}
