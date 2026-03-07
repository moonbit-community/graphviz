///|
/// Ordering domain: runtime-core context used by Stage C ordering setup.

///|
/// Graphviz parity: runtime-core payload keeps real-node/name sets, edge
/// cluster keys, and order/port maps grouped before vnode expansion.
pub(all) struct OrderingRuntimeCore {
  real_nodes : Map[String, Bool]
  existing_names : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
}

///|
/// Graphviz parity: Stage C runtime context keeps runtime-core expansion,
/// vnode injection, and parity probes in one setup boundary.
pub(all) struct OrderingRuntimeContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : @routing.EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: runtime-core input keeps node/edge/rank snapshots and the
/// edge-cluster collection context grouped in one setup boundary.
pub(all) struct BuildOrderingRuntimeCoreInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  intercluster_keys : Map[String, String]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
}

///|
/// Graphviz parity: runtime-context source bundle keeps stage-side graph/rank
/// snapshots plus cluster metadata grouped so ordering owner code owns the
/// cluster-key/parent unpacking.
pub(all) struct BuildOrderingRuntimeContextSources {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  nodesep_pt : Double
  rankdir : @rankdir.RankDir
  cluster_meta : DotClusterMetadata
}

///|
/// Graphviz parity: runtime-context dep bundle keeps label-metric vnode wiring
/// explicit while ordering owner code assembles the remaining runtime input.
pub(all) struct BuildOrderingRuntimeContextDeps {
  edge_mid_label_metrics_for : (@cgraph.Edge) -> (Double, Double)?
}

///|
/// Graphviz parity: ordering runtime prep keeps vnode build and cluster-key
/// wiring derived from grouped sources before Stage C dispatch.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_runtime_context_from_sources(
  sources : BuildOrderingRuntimeContextSources,
  deps : BuildOrderingRuntimeContextDeps,
) -> OrderingRuntimeContext {
  build_ordering_runtime_context(
    {
      graph: sources.graph,
      nodes: sources.nodes,
      edges: sources.edges,
      edge_tail: sources.edge_tail,
      edge_head: sources.edge_head,
      edge_out_order: sources.edge_out_order,
      ranks: sources.ranks,
      node_order: sources.node_order,
      nodesep_pt: sources.nodesep_pt,
      rankdir: sources.rankdir,
      intercluster_keys: sources.cluster_meta.intercluster_keys,
      cluster_parents: sources.cluster_meta.cluster_parents,
      edge_mid_label_metrics_for: deps.edge_mid_label_metrics_for,
    },
  )
}

///|
/// Graphviz parity: runtime-context input keeps runtime-core, vnode build, and
/// tail-constraint probe dependencies grouped before Stage C dispatch.
pub(all) struct BuildOrderingRuntimeContextInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  nodesep_pt : Double
  rankdir : @rankdir.RankDir
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  edge_mid_label_metrics_for : (@cgraph.Edge) -> (Double, Double)?
}

///|
/// Graphviz parity: ordering runtime-core setup keeps name-set build,
/// edge-cluster collection, and order/port map derivation in fixed sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_runtime_core(
  input : BuildOrderingRuntimeCoreInput,
) -> OrderingRuntimeCore {
  let node_name_sets = build_ordering_node_name_sets(input.nodes)
  let real_nodes = node_name_sets.real_nodes
  let existing_names = node_name_sets.existing_names
  let edge_cluster_keys : Map[String, String] = Map::new()
  @clustering.collect_edge_cluster_keys(input.graph, edge_cluster_keys)
  let port_edge_nodes =
    build_port_edge_nodes_for_ordering(
      input.edges,
      input.edge_tail,
      input.edge_head,
    )
  let local_cluster_order =
    build_local_cluster_order(
      input.nodes,
      input.intercluster_keys,
      input.ranks,
      input.node_order,
    )
  {
    real_nodes,
    existing_names,
    edge_cluster_keys,
    port_edge_nodes,
    local_cluster_order,
  }
}

///|
/// Graphviz parity: ordering runtime prep keeps vnode tail-constraint probe in
/// the same setup position as Graphviz ordering pipeline.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_runtime_context(
  input : BuildOrderingRuntimeContextInput,
) -> OrderingRuntimeContext {
  let runtime_core =
    build_ordering_runtime_core(
      {
        graph: input.graph,
        nodes: input.nodes,
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        intercluster_keys: input.intercluster_keys,
        ranks: input.ranks,
        node_order: input.node_order,
      },
    )
  let vnode_info =
    build_edge_vnodes(
      input.nodes,
      input.edges,
      input.edge_tail,
      input.edge_head,
      input.edge_out_order,
      input.ranks,
      input.nodesep_pt,
      input.rankdir,
      runtime_core.existing_names,
      runtime_core.edge_cluster_keys,
      input.cluster_parents,
      {
        edge_mid_label_metrics_for: input.edge_mid_label_metrics_for,
      },
    )
  // Graphviz parity: rank=same does not inject extra flat constraints at this stage.
  let rank_same_constraints : Map[String, Bool] = Map::new()
  let runtime_context : OrderingRuntimeContext =
    {
      real_nodes: runtime_core.real_nodes,
      edge_cluster_keys: runtime_core.edge_cluster_keys,
      vnode_info,
      port_edge_nodes: runtime_core.port_edge_nodes,
      local_cluster_order: runtime_core.local_cluster_order,
      rank_same_constraints,
    }
  // Graphviz parity: setup probes vnode tail constraints in setup order even
  // when the probe output is only used for parity diagnostics.
  let _ =
    if runtime_context.vnode_info.vnode_ranks.length() > 0 {
      build_vnode_tail_constraints(
        runtime_context.vnode_info.vnodes_by_rank,
        input.edge_tail,
      )
    } else {
      Map::new()
    }
  runtime_context
}

///|
/// Graphviz parity: vnode name index parser reads the leading edge index from
/// virtual-node names generated by class2 vnode expansion.
fn edge_vnode_edge_index(name : String) -> Int? {
  if !@edge_identity.is_edge_vnode_name(name) {
    return None
  }
  let rest =
    name.unsafe_substring(start=@edge_identity.EDGE_VNODE_PREFIX.length(), end=name.length())
  let mut acc = 0
  let mut seen = false
  for c in rest {
    if c.is_ascii_digit() {
      seen = true
      acc = acc * 10 + (c.to_int() - '0'.to_int())
    } else {
      break
    }
  }
  if seen {
    Some(acc)
  } else {
    None
  }
}

///|
/// Graphviz parity: vnode tail-order constraints keep vnode chains stable for
/// edges sharing the same tail in each rank.
/// Do not change behavior without updating fixtures/tests.
pub fn build_vnode_tail_constraints(
  vnodes_by_rank : Map[Int, Array[String]],
  edge_tail : Array[String],
) -> Map[String, Bool] {
  let constraints : Map[String, Bool] = Map::new()
  for _rank, names in vnodes_by_rank {
    if names.length() <= 1 {
      continue
    }
    let by_tail : Map[String, Array[(Int, String)]] = Map::new()
    for name in names {
      if !@edge_identity.is_edge_vnode_name(name) {
        continue
      }
      match edge_vnode_edge_index(name) {
        Some(edge_idx) =>
          if edge_idx >= 0 && edge_idx < edge_tail.length() {
            let tail = edge_tail[edge_idx]
            match by_tail.get(tail) {
              Some(list) => list.push((edge_idx, name))
              None => by_tail[tail] = [(edge_idx, name)]
            }
          }
        None => ()
      }
    }
    for _tail, entries in by_tail {
      if entries.length() <= 1 {
        continue
      }
      let sorted = entries.copy()
      sorted.sort_by((a, b) => {
        let (idx_a, _name_a) = a
        let (idx_b, _name_b) = b
        if idx_a < idx_b {
          -1
        } else if idx_a > idx_b {
          1
        } else {
          0
        }
      })
      let mut i = 1
      while i < sorted.length() {
        let (_idx_prev, prev_name) = sorted[i - 1]
        let (_idx_curr, curr_name) = sorted[i]
        if prev_name != curr_name {
          constraints["\{prev_name}|\{curr_name}"] = true
        }
        i = i + 1
      }
    }
  }
  constraints
}
