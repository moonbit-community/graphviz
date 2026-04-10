// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn build_edge_vnodes_for_test(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  nodesep_pt : Double,
  rankdir : @rankdir.RankDir,
) -> EdgeVnodeInfo {
  let nodes = graph.nodes()
  let edges = graph.edges()
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  @membership.collect_edge_cluster_keys(graph, edge_cluster_keys)
  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(graph)
  build_edge_vnodes(
    nodes,
    edges,
    [],
    [],
    Map::new(),
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
    cluster_maps.cluster_parents,
  )
}

///|
fn edge_vnode_chain_for_test(
  vnode_info : EdgeVnodeInfo,
  edge : @cgraph.Edge,
) -> Array[String] raise {
  match vnode_info.edge_vnodes.get(@edge_identity.edge_vnode_key(edge)) {
    Some(value) => value
    None => fail("missing vnode chain for edge")
  }
}

///|
fn vnode_size_for_test(
  vnode_info : EdgeVnodeInfo,
  name : String,
) -> @node_primitives.NodeSize raise {
  match vnode_info.vnode_sizes.get(name) {
    Some(value) => value
    None => fail("missing vnode size for \{name}")
  }
}
