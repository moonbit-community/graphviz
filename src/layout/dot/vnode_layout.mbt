///|
priv struct EdgeVnodeInfo {
  vnode_ranks : Map[String, Int]
  vnode_sizes : Map[String, NodeSize]
  vnodes_by_rank : Map[Int, Array[String]]
  edge_vnodes : Map[String, Array[String]]
  vnode_clusters : Map[String, String]
}

///|
priv struct FlatLabelNodeInfo {
  tail : String
  head : String
  rank : Int
}

///|
/// Graphviz parity: class2 virtual node creation order + sizing.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_vnodes(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  existing_names : Map[String, Bool],
  edge_cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
) -> EdgeVnodeInfo {
  let vnode_ranks : Map[String, Int] = Map::new()
  let vnode_sizes : Map[String, NodeSize] = Map::new()
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
    let tail = if idx < edge_tail.length() { edge_tail[idx] } else {
      edge.tail().name()
    }
    let head = if idx < edge_head.length() { edge_head[idx] } else {
      edge.head().name()
    }
    let tail_cluster = node_cluster_key(edge.tail())
    let head_cluster = node_cluster_key(edge.head())
    // Graphviz parity: cluster-local parallel chains do not widen class2 vnodes.
    let use_cluster_plain =
      tail_cluster != "" && tail_cluster == head_cluster
    let delta = if use_cluster_plain { 0.0 } else { nodesep_pt / 2.0 }
    let key = @dot_shared.edge_vnode_key(edge)
    match edge_vnodes.get(key) {
      Some(list) => {
        for name in list {
          match vnode_sizes.get(name) {
            Some(size) => {
              let left = size.left_pt + delta
              let right = size.right_pt + delta
              vnode_sizes[name] =
                vnode_size_from_widths_with_h(left, right, size.height_pt)
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
        "\{edge.head().name()}|\{edge.tail().name()}|\{@dot_shared.port_key(edge.head_port())}|\{@dot_shared.port_key(edge.tail_port())}"
      match edge_vnodes.get(reverse_key) {
        Some(list) => {
          for name in list {
            match vnode_sizes.get(name) {
              Some(size) => {
                let left = size.left_pt + delta
                let right = size.right_pt + delta
                vnode_sizes[name] =
                  vnode_size_from_widths_with_h(left, right, size.height_pt)
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
        cluster_lca(tail_cluster, head_cluster, cluster_parents)
      } else {
        match edge_cluster_keys.get(@dot_shared.edge_key(edge)) {
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
    let label_metrics = edge_mid_label_metrics(edge)
    let (label_width, label_height) = match label_metrics {
      Some((width, height)) =>
        if rankdir == RankDir::LR || rankdir == RankDir::RL {
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
      let name = unique_virtual_node_name(
        EDGE_VNODE_PREFIX,
        idx,
        rank,
        existing_names,
      )
      vnode_ranks[name] = rank
      vnode_sizes[name] =
        if is_label_rank {
        vnode_size_from_widths_with_h(
          nodesep_pt,
          label_width,
          label_height,
        )
      } else {
        vnode_size_from_widths(plain_width_for_edge, plain_width_for_edge)
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
  vnode_info : EdgeVnodeInfo,
  x_groups : Map[Int, Array[String]],
) -> (
  Map[Int, Array[String]],
  Map[String, FlatLabelNodeInfo],
  Map[String, String],
  Array[ConstraintEdge],
) {
  let order_index = build_order_index(x_groups)
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
    let tail =
      if current_idx < edge_tail.length() { edge_tail[current_idx] } else {
        edge.tail().name()
      }
    let head =
      if current_idx < edge_head.length() { edge_head[current_idx] } else {
        edge.head().name()
      }
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
    let (metric_width, metric_height) = metrics
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
    let left_right = node_right_pt(left, sizes)
    let right_left = node_left_pt(right, sizes)
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
      let minlen = round_int(minlen_adjusted)
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
    let name = unique_virtual_node_name(
      EDGE_VNODE_PREFIX,
      current_idx,
      label_rank,
      existing_names,
    )
    let half_width = label_width / 2.0
    vnode_info.vnode_ranks[name] = label_rank
    vnode_info.vnode_sizes[name] =
      vnode_size_from_widths_with_h(half_width, half_width, label_height)
    let tail_cluster = node_cluster_key(edge.tail())
    let head_cluster = node_cluster_key(edge.head())
    let vnode_cluster =
      if tail_cluster != "" || head_cluster != "" {
        cluster_lca(tail_cluster, head_cluster, cluster_parents)
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
      match root_graph_for_node(edge.tail()).get_attr("ordering") {
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
    let minlen_left = round_int(m0 + left_right + half_width)
    let minlen_right = round_int(m0 + half_width + right_left)
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
  (x_groups, flat_label_nodes, flat_label_edges, extra_edges)
}

///|
fn build_node_singletons(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> Map[String, Bool] {
  let counts : Map[String, Int] = Map::new()
  for node in nodes {
    counts[node.name()] = 0
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let dir = edge_dir_for(edge, edge.tail().graph().kind())
    let inc = if dir is EdgeDir::Both { 2 } else { 1 }
    let tail_count = match counts.get(tail) {
      Some(value) => value
      None => 0
    }
    counts[tail] = tail_count + inc
    let head_count = match counts.get(head) {
      Some(value) => value
      None => 0
    }
    counts[head] = head_count + inc
  }
  let singletons : Map[String, Bool] = Map::new()
  for name, count in counts {
    if count <= 1 {
      singletons[name] = true
    }
  }
  singletons
}

///|
fn virtual_endpoint_class(
  name : String,
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
) -> Int {
  if vnode_ranks.get(name) is Some(_) {
    2
  } else if node_singletons.get(name) is Some(_) {
    1
  } else {
    0
  }
}

///|
fn virtual_weight_scale(
  tail : String,
  head : String,
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
) -> Int {
  let tail_class = virtual_endpoint_class(tail, vnode_ranks, node_singletons)
  let head_class = virtual_endpoint_class(head, vnode_ranks, node_singletons)
  if tail_class == 0 {
    1
  } else if tail_class == 1 {
    if head_class == 0 { 1 } else { 2 }
  } else {
    if head_class == 2 {
      4
    } else if head_class == 1 {
      2
    } else {
      1
    }
  }
}

///|
fn build_virtual_slack_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
  cluster_keys : Map[String, String],
) -> Array[ConstraintEdge] {
  let _ = cluster_keys
  let extra : Array[ConstraintEdge] = []
  let mut edge_idx = 0
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = if current_idx < edge_tail.length() { edge_tail[current_idx] } else {
      edge.tail().name()
    }
    let head = if current_idx < edge_head.length() { edge_head[current_idx] } else {
      edge.head().name()
    }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    let tail_port_name =
      if tail == orig_tail {
      edge_port_name(edge.tail_port())
    } else {
      edge_port_name(edge.head_port())
    }
    let head_port_name =
      if head == orig_head {
      edge_port_name(edge.head_port())
    } else {
      edge_port_name(edge.tail_port())
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let low = if tail_rank <= head_rank { tail } else { head }
    let high = if tail_rank <= head_rank { head } else { tail }
    let base_weight = @dot_shared.edge_weight(edge)
    let reversed = current_idx < edge_reversed.length() && edge_reversed[current_idx]
    let mut prev = low
    for vnode in vnodes {
      let scale = virtual_weight_scale(prev, vnode, vnode_ranks, node_singletons)
      let tail_port = endpoint_port_name(
        prev,
        tail,
        head,
        tail_port_name,
        head_port_name,
      )
      let head_port = endpoint_port_name(
        vnode,
        tail,
        head,
        tail_port_name,
        head_port_name,
      )
      let mut weight = base_weight * scale
      if vnode_ranks.get(prev) is None && vnode_ranks.get(vnode) is Some(_) {
        weight = weight * VNODE_ENDPOINT_WEIGHT
        if reversed {
          weight = weight * BACKWARD_PENALTY
        }
      }
      extra.push({
        tail: prev,
        head: vnode,
        minlen: 1,
        weight,
        tail_port,
        head_port,
      })
      prev = vnode
    }
    let scale = virtual_weight_scale(prev, high, vnode_ranks, node_singletons)
    let tail_port = endpoint_port_name(
      prev,
      tail,
      head,
      tail_port_name,
      head_port_name,
    )
    let head_port = endpoint_port_name(
      high,
      tail,
      head,
      tail_port_name,
      head_port_name,
    )
    let mut weight = base_weight * scale
    if vnode_ranks.get(prev) is Some(_) && vnode_ranks.get(high) is None {
      weight = weight * VNODE_ENDPOINT_WEIGHT
      if reversed {
        weight = weight * BACKWARD_PENALTY
      }
    }
    extra.push({
      tail: prev,
      head: high,
      minlen: 1,
      weight,
      tail_port,
      head_port,
    })
  }
  extra
}
