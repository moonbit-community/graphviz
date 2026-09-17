// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
priv struct ChildSkeletonView {
  graph : @cgraph.Graph
  groups : Map[Int, Array[String]]
  members : Map[String, Array[String]]
  dispatch : ClusterLocalReorderDispatchContext
}

///|
fn collect_immediate_cluster_children(
  graph : @cgraph.Graph,
  children : Array[@cgraph.Graph],
) -> Unit {
  for child in graph.subgraphs() {
    if child.name().unwrap_or_default().has_prefix("cluster") {
      children.push(child)
    } else {
      collect_immediate_cluster_children(child, children)
    }
  }
}

///|
fn collect_descendant_cluster_keys(
  graph : @cgraph.Graph,
  keys : Map[String, Bool],
) -> Unit {
  if graph.name() is Some(name) {
    keys[name] = true
  }
  for child in graph.subgraphs() {
    collect_descendant_cluster_keys(child, keys)
  }
}

///|
fn local_cluster_skeleton_flags(nodes : Map[String, Bool]) -> Map[String, Bool] {
  let flags : Map[String, Bool] = Map([])
  for name, _ in nodes {
    if @cluster_identity.is_cluster_skeleton_name(name) {
      flags[name] = true
    }
  }
  flags
}

///|
/// class2(parent) retains each unexpanded child as one rankleader per rank.
/// Its internal edges are replaced by a high-penalty skeleton chain; only
/// edges crossing the child boundary are projected onto those rankleaders.
fn build_child_skeleton_view(
  cluster : String,
  graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  dispatch : ClusterLocalReorderDispatchContext,
) -> ChildSkeletonView? {
  let children : Array[@cgraph.Graph] = []
  collect_immediate_cluster_children(graph, children)
  guard children.length() > 0 else { return None }
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed)
  let active_graph = root.subgraph(name=cluster)
  let mapped : Map[String, String] = Map([])
  let child_keys : Map[String, String] = Map([])
  let ranks = dispatch.fixed_ranks.copy()
  let members : Map[String, Array[String]] = Map([])
  let skeleton_chains : Array[Array[String]] = []
  for child in children {
    let child_name = child.name().unwrap_or_default()
    let child_ranks : Array[Int] = []
    for node in child.nodes() {
      if ranks.get(node.name()) is Some(rank) {
        child_ranks.push(rank)
      }
    }
    guard child_ranks.length() > 0 else { continue }
    child_ranks.sort()
    let chain : Array[String] = []
    for rank in child_ranks[0]..<(child_ranks[child_ranks.length() - 1] + 1) {
      let name = @cluster_identity.cluster_skeleton_name(child_name, rank)
      ignore(active_graph.node(name))
      ranks[name] = rank
      members[name] = []
      chain.push(name)
    }
    skeleton_chains.push(chain)
    let descendants : Map[String, Bool] = Map([])
    collect_descendant_cluster_keys(child, descendants)
    for node in child.nodes() {
      child_keys[node.name()] = child_name
    }
    for name, owner in dispatch.vnode_clusters {
      if descendants.get(owner) is Some(_) {
        child_keys[name] = child_name
      }
    }
  }
  guard skeleton_chains.length() > 0 else { return None }
  for name, owner in child_keys {
    if ranks.get(name) is Some(rank) {
      mapped[name] = @cluster_identity.cluster_skeleton_name(owner, rank)
    }
  }
  for node in graph.nodes() {
    if mapped.get(node.name()) is None {
      ignore(active_graph.node(node.name()))
    }
  }
  let collapsed_groups : Map[Int, Array[String]] = Map([])
  for rank, names in groups {
    let collapsed : Array[String] = []
    let seen : Map[String, Bool] = Map([])
    for name in names {
      let replacement = mapped.get(name).unwrap_or(name)
      if members.get(replacement) is Some(list) {
        list.push(name)
      }
      if seen.get(replacement) is None {
        collapsed.push(replacement)
        seen[replacement] = true
      }
    }
    for chain in skeleton_chains {
      for name in chain {
        if ranks.get(name) == Some(rank) && seen.get(name) is None {
          collapsed.push(name)
        }
      }
    }
    collapsed_groups[rank] = collapsed
  }
  let edges : Array[@cgraph.Edge] = []
  let tails : Array[String] = []
  let heads : Array[String] = []
  let tail_x : Array[Double] = []
  let head_x : Array[Double] = []
  let tail_order : Array[Double] = []
  let head_order : Array[Double] = []
  let outgoing : Map[String, Array[String]] = Map([])
  let incoming : Map[String, Array[String]] = Map([])
  for chain in skeleton_chains {
    for index in 1..<chain.length() {
      let tail = chain[index - 1]
      let head = chain[index]
      let edge = active_graph.edge(
        active_graph.node(tail),
        active_graph.node(head),
      )
      edge.set_attr("xpenalty", "1000")
      edges.push(edge)
      tails.push(tail)
      heads.push(head)
      tail_x.push(0.0)
      head_x.push(0.0)
      tail_order.push(0.0)
      head_order.push(0.0)
      append_cluster_local_neighbor_edge(outgoing, incoming, tail, head)
    }
  }
  for index, edge in dispatch.order_edges {
    let original_tail = dispatch.order_edge_tail[index]
    let original_head = dispatch.order_edge_head[index]
    let tail_child = child_keys.get(original_tail)
    guard tail_child is None || tail_child != child_keys.get(original_head) else {
      continue
    }
    let tail = mapped.get(original_tail).unwrap_or(original_tail)
    let head = mapped.get(original_head).unwrap_or(original_head)
    guard tail != head else { continue }
    edges.push(edge)
    tails.push(tail)
    heads.push(head)
    tail_x.push(
      if tail == original_tail {
        dispatch.order_edge_tail_port_x[index]
      } else {
        0.0
      },
    )
    head_x.push(
      if head == original_head {
        dispatch.order_edge_head_port_x[index]
      } else {
        0.0
      },
    )
    tail_order.push(
      if tail == original_tail {
        dispatch.order_edge_tail_port_order[index]
      } else {
        0.0
      },
    )
    head_order.push(
      if head == original_head {
        dispatch.order_edge_head_port_order[index]
      } else {
        0.0
      },
    )
    append_cluster_local_neighbor_edge(outgoing, incoming, tail, head)
  }
  let neighbor_sources : ClusterLocalNeighborSources = {
    source_out_neighbors: outgoing,
    source_in_neighbors: incoming,
    raw_out_neighbors: outgoing,
    raw_in_neighbors: incoming,
  }
  Some({
    graph: active_graph,
    groups: collapsed_groups,
    members,
    dispatch: {
      ..dispatch,
      order_edges: edges,
      order_edge_tail: tails,
      order_edge_head: heads,
      order_edge_tail_port_x: tail_x,
      order_edge_head_port_x: head_x,
      order_edge_tail_port_order: tail_order,
      order_edge_head_port_order: head_order,
      fixed_ranks: ranks,
      neighbor_sources,
    },
  })
}
