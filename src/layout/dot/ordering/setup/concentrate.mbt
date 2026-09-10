// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Graphviz maps `concentrate` through mapbool, where an empty or invalid
/// value is false and a non-zero numeric value is true.
fn graphviz_mapbool_default_false(value : String) -> Bool {
  let lower = value.trim().to_lower()
  if lower == "" || lower == "false" || lower == "no" {
    return false
  }
  if lower == "true" || lower == "yes" {
    return true
  }
  match lower.get_char(0) {
    Some(ch) =>
      if ch.is_ascii_digit() {
        let mut number = 0
        for digit in lower {
          if !digit.is_ascii_digit() {
            break
          }
          number = number * 10 + digit.to_int() - '0'.to_int()
        }
        number != 0
      } else {
        false
      }
    None => false
  }
}

///|
/// `dot_concentrate` only consumes the ordinary, unlabelled virtual chains
/// produced by class2.
fn edge_can_concentrate(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
) -> Bool {
  if edge.get_attr("label").unwrap_or_default() != "" {
    return false
  }
  let tail_rank = ranks.get(edge.tail().name()).unwrap_or_default()
  let head_rank = ranks.get(edge.head().name()).unwrap_or_default()
  if tail_rank == head_rank {
    return false
  }
  vnode_info.edge_vnodes.get(@edge_identity.edge_vnode_key(edge)) is Some(_)
}

///|
/// Class2 stores chains in ascending rank order; concentrate walks them in
/// edge direction when testing a shared tail and in reverse edge direction
/// when testing a shared head.
fn edge_vnodes_in_direction(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  from_tail : Bool,
) -> Array[String] {
  let vnodes = vnode_info.edge_vnodes
    .get(@edge_identity.edge_vnode_key(edge))
    .unwrap_or_default()
  let tail_rank = ranks.get(edge.tail().name()).unwrap_or_default()
  let head_rank = ranks.get(edge.head().name()).unwrap_or_default()
  let forward = (tail_rank < head_rank) == from_tail
  let ordered : Array[String] = []
  if forward {
    for vnode in vnodes {
      ordered.push(vnode)
    }
  } else {
    let mut index = vnodes.length()
    while index > 0 {
      index = index - 1
      ordered.push(vnodes[index])
    }
  }
  ordered
}

///|
/// Each concentrator candidate must have one incoming and one outgoing virtual
/// segment. Counting class2-chain ownership is the local equivalent: already
/// shared parallel chains are not candidates for a second merge.
fn build_vnode_chain_use_count(
  edges : Array[@cgraph.Edge],
  vnode_info : EdgeVnodeInfo,
) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for edge in edges {
    let vnodes = vnode_info.edge_vnodes
      .get(@edge_identity.edge_vnode_key(edge))
      .unwrap_or_default()
    for vnode in vnodes {
      counts[vnode] = counts.get(vnode).unwrap_or_default() + 1
    }
  }
  counts
}

///|
/// Resolve a previously merged virtual node to the leftmost retained member.
fn resolve_vnode_alias(aliases : Map[String, String], name : String) -> String {
  match aliases.get(name) {
    Some(next) => if next == name { name } else { resolve_vnode_alias(aliases, next) }
    None => name
  }
}

///|
/// `dot_concentrate` only merges consecutive virtual nodes in the rank list.
/// The ordering stage has already produced that list, so preserve its leftmost
/// node as the representative and leave separated runs alone.
fn merge_adjacent_vnode_run(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  from_tail : Bool,
  step : Int,
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  chain_use_count : Map[String, Int],
  aliases : Map[String, String],
) -> Unit {
  let order_index : Map[String, Int] = Map([])
  for _rank, names in ordered_groups_with_vnodes {
    let mut position = 0
    for name in names {
      if aliases.get(name) is None {
        order_index[name] = position
        position = position + 1
      }
    }
  }
  let candidates : Array[(String, Int)] = []
  for edge in edges {
    let chain = edge_vnodes_in_direction(edge, ranks, vnode_info, from_tail)
    if step >= chain.length() {
      continue
    }
    let vnode = resolve_vnode_alias(aliases, chain[step])
    if chain_use_count.get(vnode).unwrap_or_default() != 1 {
      continue
    }
    match order_index.get(vnode) {
      Some(position) => candidates.push((vnode, position))
      None => ()
    }
  }
  candidates.sort_by((a, b) => a.1 - b.1)
  let mut leader = ""
  let mut previous_position = -2
  for candidate in candidates {
    let (vnode, position) = candidate
    if vnode == leader {
      previous_position = position
      continue
    }
    if leader != "" && position == previous_position + 1 {
      aliases[vnode] = resolve_vnode_alias(aliases, leader)
    } else {
      leader = vnode
    }
    previous_position = position
  }
}

///|
/// Build the common-tail or common-head classes used by the two passes in
/// `lib/dotgen/conc.c`.  Direction is part of the key, matching `samedir`.
fn build_concentrate_edge_groups(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  from_tail : Bool,
) -> Map[String, Array[@cgraph.Edge]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map([])
  for edge in edges {
    if !edge_can_concentrate(edge, ranks, vnode_info) {
      continue
    }
    let tail_rank = ranks.get(edge.tail().name()).unwrap_or_default()
    let head_rank = ranks.get(edge.head().name()).unwrap_or_default()
    let direction = if tail_rank < head_rank { "up" } else { "down" }
    let endpoint = if from_tail {
      edge.tail().name()
    } else {
      edge.head().name()
    }
    let port = if from_tail {
      @edge_identity.port_key(edge.tail_port())
    } else {
      @edge_identity.port_key(edge.head_port())
    }
    let key = "\{endpoint}|\{port}|\{direction}"
    match groups.get(key) {
      Some(group) => group.push(edge)
      None => groups[key] = [edge]
    }
  }
  groups
}

///|
/// Apply one directional concentrate pass.  In the upstream implementation
/// each rank is scanned in order; stepping through every virtual-chain depth
/// yields the same parent/child propagation for the local class2 model.
fn merge_concentrated_vnode_groups(
  groups : Map[String, Array[@cgraph.Edge]],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  from_tail : Bool,
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  chain_use_count : Map[String, Int],
  aliases : Map[String, String],
) -> Unit {
  for _key, edges in groups {
    if edges.length() < 2 {
      continue
    }
    let mut max_depth = 0
    for edge in edges {
      let depth = edge_vnodes_in_direction(edge, ranks, vnode_info, from_tail).length()
      if depth > max_depth {
        max_depth = depth
      }
    }
    for step in 0..<max_depth {
      merge_adjacent_vnode_run(
        edges,
        ranks,
        vnode_info,
        from_tail,
        step,
        ordered_groups_with_vnodes,
        chain_use_count,
        aliases,
      )
    }
  }
}

///|
/// Rebuild class2 metadata after virtual-node merges.  Keeping only live
/// nodes is important: stale virtual nodes would otherwise still become
/// simplex nodes and negate the concentrate pass.
fn rebuild_concentrated_vnode_info(
  vnode_info : EdgeVnodeInfo,
  aliases : Map[String, String],
) -> EdgeVnodeInfo {
  let edge_vnodes : Map[String, Array[String]] = Map([])
  let live : Map[String, Bool] = Map([])
  for key, chain in vnode_info.edge_vnodes {
    let updated : Array[String] = []
    for vnode in chain {
      let representative = resolve_vnode_alias(aliases, vnode)
      updated.push(representative)
      live[representative] = true
    }
    edge_vnodes[key] = updated
  }
  let vnode_ranks : Map[String, Int] = Map([])
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map([])
  let vnode_clusters : Map[String, String] = Map([])
  for vnode, _ in live {
    match vnode_info.vnode_ranks.get(vnode) {
      Some(rank) => vnode_ranks[vnode] = rank
      None => ()
    }
    match vnode_info.vnode_sizes.get(vnode) {
      Some(size) => vnode_sizes[vnode] = size
      None => ()
    }
    match vnode_info.vnode_clusters.get(vnode) {
      Some(cluster) => vnode_clusters[vnode] = cluster
      None => ()
    }
  }
  let vnodes_by_rank : Map[Int, Array[String]] = Map([])
  for rank, names in vnode_info.vnodes_by_rank {
    let updated : Array[String] = []
    let seen : Map[String, Bool] = Map([])
    for vnode in names {
      if aliases.get(vnode) is None &&
        live.get(vnode) is Some(_) &&
        seen.get(vnode) is None {
        updated.push(vnode)
        seen[vnode] = true
      }
    }
    if updated.length() > 0 {
      vnodes_by_rank[rank] = updated
    }
  }
  { vnode_ranks, vnode_sizes, vnodes_by_rank, edge_vnodes, vnode_clusters, }
}

///|
/// Remove absorbed virtual nodes from an already ordered rank list while
/// retaining ordinary nodes and cluster skeleton nodes unchanged.
fn filter_absorbed_vnodes_from_groups(
  groups : Map[Int, Array[String]],
  aliases : Map[String, String],
) -> Map[Int, Array[String]] {
  let filtered : Map[Int, Array[String]] = Map([])
  for rank, names in groups {
    let updated : Array[String] = []
    for name in names {
      if aliases.get(name) is None {
        updated.push(name)
      }
    }
    filtered[rank] = updated
  }
  filtered
}

///|
/// Preserve the original node-list order while removing absorbed virtual
/// nodes from the later X-constraint construction.
fn filter_absorbed_vnode_names(
  names : Array[String],
  aliases : Map[String, String],
) -> Array[String] {
  names.filter(name => aliases.get(name) is None)
}

///|
/// Keep the original-edge ownership bit that `merge_oneway` carries in
/// Graphviz. Routing consumes this internal marker to omit only paths that
/// actually lost a virtual segment during concentrate.
fn mark_edges_with_absorbed_vnodes(
  edges : Array[@cgraph.Edge],
  vnode_info : EdgeVnodeInfo,
  aliases : Map[String, String],
) -> Unit {
  for edge in edges {
    let vnodes = vnode_info
      .edge_vnodes
      .get(@edge_identity.edge_vnode_key(edge))
      .unwrap_or_default()
    let mut absorbed = false
    for vnode in vnodes {
      if aliases.get(vnode) is Some(_) {
        absorbed = true
        break
      }
    }
    edge.set_attr(
      "_concentrated_absorbed",
      if absorbed { "true" } else { "false" },
    )
  }
}

///|
/// Result of the post-mincross virtual-node concentrate step.
priv struct ConcentratedVNodeData {
  vnode_info : EdgeVnodeInfo
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  aliases : Map[String, String]
}

///|
/// Align the local class2 representation with `dot_concentrate`: after
/// mincross, merge adjacent unlabelled virtual chains with a common endpoint
/// and matching endpoint port.  This must run before X simplex construction.
fn concentrate_vnode_data(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  ordered_groups_with_vnodes : Map[Int, Array[String]],
) -> ConcentratedVNodeData {
  let enabled = match graph.get_attr("concentrate") {
    Some(value) => graphviz_mapbool_default_false(value)
    None => false
  }
  if !enabled || ordered_groups_with_vnodes.length() == 0 {
    return { vnode_info, ordered_groups_with_vnodes, aliases: Map([]), }
  }
  let chain_use_count = build_vnode_chain_use_count(edges, vnode_info)
  let aliases : Map[String, String] = Map([])
  merge_concentrated_vnode_groups(
    build_concentrate_edge_groups(edges, ranks, vnode_info, true),
    ranks,
    vnode_info,
    true,
    ordered_groups_with_vnodes,
    chain_use_count,
    aliases,
  )
  merge_concentrated_vnode_groups(
    build_concentrate_edge_groups(edges, ranks, vnode_info, false),
    ranks,
    vnode_info,
    false,
    ordered_groups_with_vnodes,
    chain_use_count,
    aliases,
  )
  mark_edges_with_absorbed_vnodes(edges, vnode_info, aliases)
  if aliases.length() == 0 {
    return { vnode_info, ordered_groups_with_vnodes, aliases, }
  }
  {
    vnode_info: rebuild_concentrated_vnode_info(vnode_info, aliases),
    ordered_groups_with_vnodes: filter_absorbed_vnodes_from_groups(
      ordered_groups_with_vnodes, aliases,
    ),
    aliases,
  }
}

///|
/// Apply the post-mincross concentrate transformation to the complete
/// ordering result.  The function is kept in setup so its internal snapshots
/// remain package-private to the ordering pipeline.
pub fn concentrate_ordering_result(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  ordering : OrderingResult,
) -> OrderingResult {
  let concentrated = concentrate_vnode_data(
    graph,
    edges,
    ranks,
    ordering.vnode_info,
    ordering.ordered_groups_with_vnodes,
  )
  {
    ordered_groups: ordering.ordered_groups,
    ordered_groups_with_vnodes: concentrated.ordered_groups_with_vnodes,
    vnode_info: concentrated.vnode_info,
    vnode_count: concentrated.vnode_info.vnode_ranks.length(),
    order_edges: ordering.order_edges,
    order_edge_tail: ordering.order_edge_tail,
    order_edge_head: ordering.order_edge_head,
    edge_order: ordering.edge_order,
    edge_cluster_keys: ordering.edge_cluster_keys,
    nlist_order: filter_absorbed_vnode_names(
      ordering.nlist_order,
      concentrated.aliases,
    ),
    gdnlist_order: filter_absorbed_vnode_names(
      ordering.gdnlist_order,
      concentrated.aliases,
    ),
    vnode_creation_order: filter_absorbed_vnode_names(
      ordering.vnode_creation_order,
      concentrated.aliases,
    ),
  }
}
