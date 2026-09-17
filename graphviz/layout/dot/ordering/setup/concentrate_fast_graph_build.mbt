// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn build_concentrate_fast_graph(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  edge_ports_equal : (@cgraph.Edge, @cgraph.Edge) -> Bool,
) -> ConcentrateFastGraph {
  let graph = ConcentrateFastGraph::new()
  let degree : Map[String, Int] = Map([])
  let cluster_keys : Map[String, String] = Map([])
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  for edge in edges {
    for node in [edge.tail(), edge.head()] {
      cluster_keys[node.name()] = @membership.node_cluster_key(node)
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let forward = ranks.get(tail).unwrap_or_default() <=
      ranks.get(head).unwrap_or_default()
    edge_tail.push(if forward { tail } else { head })
    edge_head.push(if forward { head } else { tail })
    for name in [edge.tail().name(), edge.head().name()] {
      degree[name] = degree.get(name).unwrap_or_default() + 1
    }
  }
  let metadata = @order_graph.build_reverse_merge_metadata(
    {
      edges,
      edge_tail,
      edge_head,
      edge_excluded_from_reverse_merge: edge => {
        edge.get_attr("label").unwrap_or_default() != "" ||
        edge.tail().name() == edge.head().name()
      },
      edge_ports_equal,
    },
    initial_metadata=@order_graph.build_parallel_merge_metadata(
      edges, ranks, cluster_keys, edge_ports_equal,
    ),
  )
  let creation_indices : Array[Int] = []
  let node_order : Map[String, Int] = Map([])
  if edges.length() > 0 {
    let root = @membership.root_graph_for_node(edges[0].tail())
    for index, node in root.nodes() {
      node_order[node.name()] = index
    }
  }
  for index in 0..<edges.length() {
    creation_indices.push(index)
  }
  creation_indices.sort_by((a, b) => {
    let tail_order = node_order[edges[a].tail().name()].compare(
      node_order[edges[b].tail().name()],
    )
    guard tail_order == 0 else { tail_order }
    let head_order = node_order[edges[a].head().name()].compare(
      node_order[edges[b].head().name()],
    )
    if head_order == 0 {
      a.compare(b)
    } else {
      head_order
    }
  })
  for index in creation_indices {
    let edge = edges[index]
    guard metadata.merged_edge_skip.get(index) is None else { continue }
    let tail = edge.tail().name()
    let head = edge.head().name()
    guard tail != head else { continue }
    // Flat edges belong to ND_flat_out, not the live rank-to-rank graph.
    guard ranks.get(tail) != ranks.get(head) else { continue }
    let forward = ranks.get(tail).unwrap_or_default() <=
      ranks.get(head).unwrap_or_default()
    let low = if forward { tail } else { head }
    let high = if forward { head } else { tail }
    let vnodes = vnode_info.edge_vnodes
      .get(@edge_identity.edge_vnode_key(edge))
      .unwrap_or_default()
    let chain = [low, ..vnodes, high]
    for i in 0..<(chain.length() - 1) {
      let from = chain[i]
      let to = chain[i + 1]
      let from_virtual = @edge_identity.is_edge_vnode_name(from)
      let to_virtual = @edge_identity.is_edge_vnode_name(to)
      let scale = if from_virtual && to_virtual {
        4
      } else if (from_virtual || to_virtual) &&
        (degree.get(from).unwrap_or(2) == 1 || degree.get(to).unwrap_or(2) == 1) {
        2
      } else {
        1
      }
      let _ = graph.add_edge(
        from,
        to,
        @edge_semantics.edge_weight(edge) * scale +
        metadata.merged_edge_weight_bonus.get(index).unwrap_or_default(),
        tail_port=@order_graph.edge_tail_port_for_name(
          edge,
          from,
          fallback_to_original=false,
        ),
        head_port=@order_graph.edge_head_port_for_name(
          edge,
          to,
          fallback_to_original=false,
        ),
        original=Some(edge),
      )
    }
  }
  graph
}
