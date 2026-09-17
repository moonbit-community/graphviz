// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// cl_bound uses the immediate ED_to_orig of the first outgoing fast edge,
/// which may itself be virtual after concentration, not the ultimate owner.
fn live_vnode_origin_clusters(
  graph : @setup.ConcentrateFastGraph,
  cluster_keys : Map[String, String],
) -> Map[String, (String, String)] {
  let node_clusters = cluster_keys.copy()
  for edge in graph.edges {
    guard edge.original is Some(owner) else { continue }
    let tail_cluster = cluster_keys.get(owner.tail().name()).unwrap_or_default()
    let head_cluster = cluster_keys.get(owner.head().name()).unwrap_or_default()
    let cluster = if tail_cluster == head_cluster { tail_cluster } else { "" }
    for name in [edge.tail, edge.head] {
      if node_clusters.get(name) is None {
        node_clusters[name] = cluster
      }
    }
  }
  let origins : Map[String, (String, String)] = Map([])
  for name, indices in graph.outgoing {
    guard @edge_identity.is_edge_vnode_name(name) && indices.length() > 0 else {
      continue
    }
    let index = indices[0]
    let edge = graph.edges[index]
    let (tail, head) = if graph.copied_from.get(index) is Some(source) {
      (graph.edges[source].tail, graph.edges[source].head)
    } else {
      guard edge.original is Some(owner) else { continue }
      (owner.tail().name(), owner.head().name())
    }
    origins[name] = (
      node_clusters.get(tail).unwrap_or_default(),
      node_clusters.get(head).unwrap_or_default(),
    )
  }
  origins
}

///|
// Without concentration, ED_to_orig points directly at the original edge.
// Retain both endpoint clusters: rejecting the first in cl_bound must still
// allow the second to interfere, especially for nested clusters.
fn original_vnode_origin_clusters(
  edges : Array[@cgraph.Edge],
  edge_vnodes : Map[String, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[String, (String, String)] {
  let origins : Map[String, (String, String)] = Map([])
  for edge in edges {
    let clusters = (
      cluster_keys.get(edge.tail().name()).unwrap_or_default(),
      cluster_keys.get(edge.head().name()).unwrap_or_default(),
    )
    let vnodes = edge_vnodes
      .get(@edge_identity.edge_vnode_key(edge))
      .unwrap_or_default()
    for vnode in vnodes {
      if origins.get(vnode) is None {
        origins[vnode] = clusters
      }
    }
  }
  origins
}

///|
/// Routing uses the same post-concentrate ND_in/ND_out lists as positioning.
/// Original chains include deleted edges and cannot reconstruct these lists.
fn build_live_path_adjacency(
  graph : @setup.ConcentrateFastGraph,
) -> @routesplines.PathAdjacency {
  let out_edges : Map[String, Array[String]] = Map([])
  let in_edges : Map[String, Array[String]] = Map([])
  for name, indices in graph.outgoing {
    out_edges[name] = indices.map(index => graph.edges[index].head)
  }
  for name, indices in graph.incoming {
    in_edges[name] = indices.map(index => graph.edges[index].tail)
  }
  { out_edges, in_edges, }
}
