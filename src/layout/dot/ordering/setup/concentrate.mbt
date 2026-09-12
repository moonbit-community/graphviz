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
/// Resolve a previously merged virtual node to the leftmost retained member.
fn resolve_vnode_alias(aliases : Map[String, String], name : String) -> String {
  match aliases.get(name) {
    Some(next) =>
      if next == name {
        name
      } else {
        resolve_vnode_alias(aliases, next)
      }
    None => name
  }
}

///|
/// Concentrator candidacy is based on the current virtual graph rather than
/// original chain ownership. A retained representative can enter the opposite
/// pass only when it still has exactly one distinct predecessor and successor.
priv struct ConcentratedVNodeDegrees {
  incoming : Map[String, Map[String, Bool]]
  outgoing : Map[String, Map[String, Bool]]
}

///|
fn add_concentrated_vnode_segment(
  incoming : Map[String, Map[String, Bool]],
  outgoing : Map[String, Map[String, Bool]],
  tail : String,
  head : String,
) -> Unit {
  if tail == head {
    return
  }
  match outgoing.get(tail) {
    Some(neighbors) => neighbors[head] = true
    None => {
      let neighbors : Map[String, Bool] = Map([])
      neighbors[head] = true
      outgoing[tail] = neighbors
    }
  }
  match incoming.get(head) {
    Some(neighbors) => neighbors[tail] = true
    None => {
      let neighbors : Map[String, Bool] = Map([])
      neighbors[tail] = true
      incoming[head] = neighbors
    }
  }
}

///|
/// Reconstruct live virtual adjacency after aliases are applied. Parallel
/// paths share a neighbor entry, matching merge_oneway in conc.c.
fn build_concentrated_vnode_degrees(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  aliases : Map[String, String],
) -> ConcentratedVNodeDegrees {
  let incoming : Map[String, Map[String, Bool]] = Map([])
  let outgoing : Map[String, Map[String, Bool]] = Map([])
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let forward = ranks.get(tail).unwrap_or_default() <
      ranks.get(head).unwrap_or_default()
    // class2's fast edges point from low rank to high rank, even when the
    // original edge points backwards. Its vnode chains already use this order.
    let mut previous = if forward { tail } else { head }
    let chain = vnode_info.edge_vnodes
      .get(@edge_identity.edge_vnode_key(edge))
      .unwrap_or_default()
    for vnode in chain {
      let current = resolve_vnode_alias(aliases, vnode)
      add_concentrated_vnode_segment(incoming, outgoing, previous, current)
      previous = current
    }
    add_concentrated_vnode_segment(
      incoming,
      outgoing,
      previous,
      if forward {
        head
      } else {
        tail
      },
    )
  }
  { incoming, outgoing, }
}

///|
fn is_concentrate_candidate(
  vnode : String,
  degrees : ConcentratedVNodeDegrees,
) -> Bool {
  let incoming_count = degrees.incoming
    .get(vnode)
    .map_or(0, neighbors => neighbors.length())
  let outgoing_count = degrees.outgoing
    .get(vnode)
    .map_or(0, neighbors => neighbors.length())
  incoming_count == 1 && outgoing_count == 1
}

///|
/// Read the port from a retained chain, not an absorbed chain that now aliases
/// it. At a real endpoint the retained fast edge keeps this chain's port.
fn retained_endpoint_port(
  vnode : String,
  neighbor : String,
  edges : Array[@cgraph.Edge],
  vnode_info : EdgeVnodeInfo,
) -> (@cgraph.Node, @cgraph.Port?)? {
  guard !@edge_identity.is_edge_vnode_name(neighbor) else { None }
  for edge in edges {
    let chain = vnode_info.edge_vnodes
      .get(@edge_identity.edge_vnode_key(edge))
      .unwrap_or_default()
    guard chain.contains(vnode) else { continue }
    if edge.tail().name() == neighbor {
      return Some((edge.tail(), edge.tail_port()))
    }
    if edge.head().name() == neighbor {
      return Some((edge.head(), edge.head_port()))
    }
  }
  None
}

///|
fn same_retained_endpoint_ports(
  first : (@cgraph.Node, @cgraph.Port?)?,
  second : (@cgraph.Node, @cgraph.Port?)?,
  ports_equal : (@cgraph.Node, @cgraph.Port?, @cgraph.Port?) -> Bool,
) -> Bool {
  guard first is Some((node, first_port)) else { second is None }
  guard second is Some((_, second_port)) else { false }
  ports_equal(node, first_port, second_port)
}

///|
fn merge_adjacent_vnode_run(
  edges : Array[@cgraph.Edge],
  all_edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  from_tail : Bool,
  step : Int,
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  aliases : Map[String, String],
  live_graph? : ConcentrateFastGraph? = None,
  node_ports_equal? : (@cgraph.Node, @cgraph.Port?, @cgraph.Port?) -> Bool = (
    _,
    a,
    b,
  ) => @edge_identity.port_key(a) == @edge_identity.port_key(b),
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
  let degrees = build_concentrated_vnode_degrees(
    all_edges, ranks, vnode_info, aliases,
  )
  let candidates : Array[(String, Int, String, (@cgraph.Node, @cgraph.Port?)?)] = []
  for edge in edges {
    let chain = edge_vnodes_in_direction(edge, ranks, vnode_info, from_tail)
    if step >= chain.length() {
      continue
    }
    let vnode = resolve_vnode_alias(aliases, chain[step])
    if !is_concentrate_candidate(vnode, degrees) {
      continue
    }
    guard order_index.get(vnode) is Some(position) else { continue }
    let forward = ranks.get(edge.tail().name()).unwrap_or_default() <
      ranks.get(edge.head().name()).unwrap_or_default()
    let neighbors = if from_tail == forward {
      degrees.incoming
    } else {
      degrees.outgoing
    }
    guard neighbors.get(vnode) is Some(adjacent) else { continue }
    for neighbor, _ in adjacent {
      candidates.push(
        (
          vnode,
          position,
          neighbor,
          retained_endpoint_port(vnode, neighbor, all_edges, vnode_info),
        ),
      )
    }
  }
  candidates.sort_by((a, b) => a.1 - b.1)
  let mut leader = ""
  let mut leader_neighbor = ""
  let mut leader_port : (@cgraph.Node, @cgraph.Port?)? = None
  let mut previous_position = -2
  for candidate in candidates {
    let (vnode, position, neighbor, live_port) = candidate
    if vnode == leader {
      previous_position = position
      continue
    }
    // bothdowncandidates/bothupcandidates compare the live adjacent node,
    // not just the original endpoint. A separated earlier rank must stop
    // propagation of a merge into the following rank.
    if leader != "" &&
      position == previous_position + 1 &&
      neighbor == leader_neighbor &&
      same_retained_endpoint_ports(leader_port, live_port, node_ports_equal) {
      aliases[vnode] = resolve_vnode_alias(aliases, leader)
      if live_graph is Some(fast) {
        let forward = ranks.get(edges[0].tail().name()).unwrap_or_default() <
          ranks.get(edges[0].head().name()).unwrap_or_default()
        fast.merge_node(
          leader,
          vnode,
          if from_tail == forward {
            Down
          } else {
            Up
          },
        )
      }
    } else {
      leader = vnode
      leader_neighbor = neighbor
      leader_port = live_port
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
  from_low_rank : Bool,
  excluded_edges? : Map[String, Bool] = Map([]),
) -> Map[String, Array[@cgraph.Edge]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map([])
  for edge in edges {
    guard excluded_edges.get(@edge_identity.edge_vnode_key(edge)) is None else {
      continue
    }
    if !edge_can_concentrate(edge, ranks, vnode_info) {
      continue
    }
    let tail_rank = ranks.get(edge.tail().name()).unwrap_or_default()
    let head_rank = ranks.get(edge.head().name()).unwrap_or_default()
    let from_tail = from_low_rank == (tail_rank < head_rank)
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
/// class2 ignores a backward edge matching a forward edge's initial ports
/// and marks the forward representative conc_opp_flag. Neither chain can
/// participate in conc.c's samedir candidate test.
fn concentrate_opposite_edges(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  ports_equal : (@cgraph.Edge, @cgraph.Edge) -> Bool,
) -> Map[String, Bool] {
  let excluded : Map[String, Bool] = Map([])
  for backward in edges {
    let tail = backward.tail().name()
    let head = backward.head().name()
    guard ranks.get(tail).unwrap_or_default() >
      ranks.get(head).unwrap_or_default() else {
      continue
    }
    guard backward.get_attr("label").unwrap_or_default() == "" else { continue }
    for forward in edges {
      guard forward.tail().name() == head && forward.head().name() == tail else {
        continue
      }
      guard forward.get_attr("label").unwrap_or_default() == "" else {
        continue
      }
      guard ports_equal(backward, forward) else { continue }
      excluded[@edge_identity.edge_vnode_key(backward)] = true
      excluded[@edge_identity.edge_vnode_key(forward)] = true
      break
    }
  }
  excluded
}

///|
/// Find the chain position at the rank being scanned. Edges sharing an
/// endpoint can have different lengths, so a short chain cannot end the scan.
fn concentrate_step_at_rank(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  from_tail : Bool,
  rank : Int,
) -> Int? {
  for edge in edges {
    let chain = edge_vnodes_in_direction(edge, ranks, vnode_info, from_tail)
    for step, vnode in chain {
      if vnode_info.vnode_ranks.get(vnode) == Some(rank) {
        return Some(step)
      }
    }
  }
  None
}

///|
/// conc.c scans all groups at each rank, downwards first and upwards second.
/// Rank direction is independent of an original edge's tail/head direction.
fn merge_concentrated_vnode_groups(
  groups : Map[String, Array[@cgraph.Edge]],
  all_edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  from_low_rank : Bool,
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  aliases : Map[String, String],
  node_ports_equal : (@cgraph.Node, @cgraph.Port?, @cgraph.Port?) -> Bool,
  live_graph : ConcentrateFastGraph?,
) -> Unit {
  let rank_order : Array[Int] = []
  for rank, _ in ordered_groups_with_vnodes {
    rank_order.push(rank)
  }
  rank_order.sort_by((a, b) => if from_low_rank { a - b } else { b - a })
  for rank in rank_order {
    for _key, edges in groups {
      guard edges.length() >= 2 else { continue }
      let first = edges[0]
      let forward = ranks.get(first.tail().name()).unwrap_or_default() <
        ranks.get(first.head().name()).unwrap_or_default()
      let from_tail = from_low_rank == forward
      guard concentrate_step_at_rank(edges, ranks, vnode_info, from_tail, rank)
        is Some(step) else {
        continue
      }
      merge_adjacent_vnode_run(
        edges,
        all_edges,
        ranks,
        vnode_info,
        from_tail,
        step,
        ordered_groups_with_vnodes,
        aliases,
        node_ports_equal~,
        live_graph~,
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
    let vnodes = vnode_info.edge_vnodes
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
      if absorbed {
        "true"
      } else {
        "false"
      },
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
  live_graph? : ConcentrateFastGraph? = None,
  edge_ports_equal? : (@cgraph.Edge, @cgraph.Edge) -> Bool = (_, _) => false,
  node_ports_equal? : (@cgraph.Node, @cgraph.Port?, @cgraph.Port?) -> Bool = (
    _,
    a,
    b,
  ) => @edge_identity.port_key(a) == @edge_identity.port_key(b),
) -> ConcentratedVNodeData {
  let enabled = match graph.get_attr("concentrate") {
    Some(value) => graphviz_mapbool_default_false(value)
    None => false
  }
  if !enabled || ordered_groups_with_vnodes.length() == 0 {
    return { vnode_info, ordered_groups_with_vnodes, aliases: Map([]), }
  }
  let aliases : Map[String, String] = Map([])
  let excluded_edges = concentrate_opposite_edges(
    edges, ranks, edge_ports_equal,
  )
  if live_graph is Some(fast) {
    concentrate_live_candidates(
      fast, ordered_groups_with_vnodes, ranks, edges, vnode_info, excluded_edges,
      aliases, node_ports_equal,
    )
  } else {
    merge_concentrated_vnode_groups(
      build_concentrate_edge_groups(
        edges,
        ranks,
        vnode_info,
        true,
        excluded_edges~,
      ),
      edges,
      ranks,
      vnode_info,
      true,
      ordered_groups_with_vnodes,
      aliases,
      node_ports_equal,
      live_graph,
    )
    merge_concentrated_vnode_groups(
      build_concentrate_edge_groups(
        edges,
        ranks,
        vnode_info,
        false,
        excluded_edges~,
      ),
      edges,
      ranks,
      vnode_info,
      false,
      ordered_groups_with_vnodes,
      aliases,
      node_ports_equal,
      live_graph,
    )
  }
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
  edge_ports_equal? : (@cgraph.Edge, @cgraph.Edge) -> Bool = (_, _) => false,
  node_ports_equal? : (@cgraph.Node, @cgraph.Port?, @cgraph.Port?) -> Bool = (
    _,
    a,
    b,
  ) => @edge_identity.port_key(a) == @edge_identity.port_key(b),
) -> OrderingResult {
  let live_graph = if graphviz_mapbool_default_false(
      graph.get_attr("concentrate").unwrap_or_default(),
    ) {
    Some(
      build_concentrate_fast_graph(
        edges,
        ranks,
        ordering.vnode_info,
        edge_ports_equal,
      ),
    )
  } else {
    None
  }
  let concentrated = concentrate_vnode_data(
    graph,
    edges,
    ranks,
    ordering.vnode_info,
    ordering.ordered_groups_with_vnodes,
    live_graph~,
    edge_ports_equal~,
    node_ports_equal~,
  )
  {
    live_graph,
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
