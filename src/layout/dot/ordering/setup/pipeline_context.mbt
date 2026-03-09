///|
/// Ordering domain: Stage C cluster metadata and pipeline-context assembly.

///|
priv enum OrderingMode {
  Out
  In
}

///|
fn parse_ordering_mode(value : String) -> OrderingMode? {
  match value.to_lower() {
    "out" => Some(OrderingMode::Out)
    "in" => Some(OrderingMode::In)
    _ => None
  }
}

///|
pub(all) struct FlatConstraintsOutput {
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
fn build_flat_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
) -> FlatConstraintsOutput {
  let flat_constraints : Map[String, Bool] = Map::new()
  let out_edges : Map[String, Array[(Int, Int)]] = Map::new()
  let in_edges : Map[String, Array[(Int, Int)]] = Map::new()
  for node in nodes {
    let name = node.name()
    out_edges[name] = []
    in_edges[name] = []
  }
  for i in 0..<edges.length() {
    let (tail, head) = @order_graph.edge_endpoints_at(
      edges[i],
      i,
      edge_tail,
      edge_head,
    )
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster != head_cluster {
      continue
    }
    let edge_id = edges[i].id()
    match out_edges.get(tail) {
      Some(list) => list.push((edge_id, i))
      None => out_edges[tail] = [(edge_id, i)]
    }
    match in_edges.get(head) {
      Some(list) => list.push((edge_id, i))
      None => in_edges[head] = [(edge_id, i)]
    }
  }
  let apply_ordering = (name : String, mode : OrderingMode) => {
    let list = match mode {
      OrderingMode::Out =>
        match out_edges.get(name) {
          Some(items) => items
          None => []
        }
      OrderingMode::In =>
        match in_edges.get(name) {
          Some(items) => items
          None => []
        }
    }
    if list.length() <= 1 {
      return ()
    }
    let sorted = list.copy()
    sorted.sort_by((a, b) => {
      let (a_id, _a_idx) = a
      let (b_id, _b_idx) = b
      if a_id < b_id {
        -1
      } else if a_id > b_id {
        1
      } else {
        0
      }
    })
    let mut idx = 1
    while idx < sorted.length() {
      let (_prev_id, prev_idx) = sorted[idx - 1]
      let (_curr_id, curr_idx) = sorted[idx]
      let (prev_tail, prev_head) = @order_graph.edge_endpoints_at(
        edges[prev_idx],
        prev_idx,
        edge_tail,
        edge_head,
      )
      let (curr_tail, curr_head) = @order_graph.edge_endpoints_at(
        edges[curr_idx],
        curr_idx,
        edge_tail,
        edge_head,
      )
      let left = match mode {
        OrderingMode::Out => prev_head
        OrderingMode::In => prev_tail
      }
      let right = match mode {
        OrderingMode::Out => curr_head
        OrderingMode::In => curr_tail
      }
      if left != right {
        flat_constraints["\{left}|\{right}"] = true
      }
      idx = idx + 1
    }
  }
  let graph_ordering = match graph.get_attr("ordering") {
    Some(value) => parse_ordering_mode(value)
    None => None
  }
  let mut ordering_set = false
  match graph_ordering {
    Some(mode) => {
      ordering_set = true
      for node in nodes {
        apply_ordering(node.name(), mode)
      }
    }
    None =>
      for node in nodes {
        match node.get_attr("ordering") {
          Some(value) =>
            match parse_ordering_mode(value) {
              Some(mode) => {
                ordering_set = true
                apply_ordering(node.name(), mode)
              }
              None => ()
            }
          None => ()
        }
      }
  }
  { flat_constraints, ordering_set }
}

///|
/// Graphviz parity: same-rank constrained edges are promoted to flat ordering
/// constraints before clustered reorder dispatch.
/// Do not change behavior without updating fixtures/tests.
fn add_same_rank_constraint_edges_to_flat_constraints(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  flat_constraints : Map[String, Bool],
) -> Unit {
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    if edge_idx < edges.length() &&
      !@edge_semantics.edge_is_constraint(edges[edge_idx]) {
      edge_idx = edge_idx + 1
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      let tail_rank = @order_graph.flat_constraint_rank_or_zero(ranks, tail)
      let head_rank = @order_graph.flat_constraint_rank_or_zero(ranks, head)
      if tail_rank == head_rank {
        flat_constraints["\{tail}|\{head}"] = true
      }
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: flat ordering constraints include Graphviz ordering attrs
/// plus same-rank constrained edges before clustered reorder dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_flat_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  cluster_keys : Map[String, String],
) -> FlatConstraintsOutput {
  let flat_constraints_output = build_flat_constraints(
    graph, nodes, edges, edge_tail, edge_head, cluster_keys,
  )
  let flat_constraints = flat_constraints_output.flat_constraints
  add_same_rank_constraint_edges_to_flat_constraints(
    edges, edge_tail, edge_head, ranks, flat_constraints,
  )
  { flat_constraints, ordering_set: flat_constraints_output.ordering_set }
}

///|
fn collect_rank_same_order(
  graph : @cgraph.Graph,
  group_ids : Map[String, Int],
  order_ids : Map[String, Int],
  next_group : Int,
) -> Int {
  let mut current_group = next_group
  match graph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let group_id = current_group
        current_group = current_group + 1
        let mut idx = 0
        for node in graph.nodes() {
          if group_ids.get(node.name()) is None {
            group_ids[node.name()] = group_id
            order_ids[node.name()] = idx
          }
          idx = idx + 1
        }
      }
    None => ()
  }
  for child in graph.subgraphs() {
    current_group = collect_rank_same_order(
      child, group_ids, order_ids, current_group,
    )
  }
  current_group
}

///|
priv struct RankSameMetadata {
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
}

///|
/// Graphviz parity: rank=same group/order metadata is collected from graph
/// attributes before ordering setup and flat-constraint wiring.
/// Do not change behavior without updating fixtures/tests.
fn collect_rank_same_metadata(graph : @cgraph.Graph) -> RankSameMetadata {
  let rank_same_groups : Map[String, Int] = Map::new()
  let rank_same_order : Map[String, Int] = Map::new()
  let _ = collect_rank_same_order(graph, rank_same_groups, rank_same_order, 0)
  { rank_same_groups, rank_same_order }
}

///|
/// Graphviz parity: ordering metadata payload keeps rank=same and flat
/// constraint snapshots grouped for clustered reorder dispatch wiring.
priv struct ClusterOrderingMetadata {
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
/// Graphviz parity: ordering metadata assembly collects rank=same groups/order
/// and flat constraints before clustered reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_ordering_metadata(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  cluster_keys : Map[String, String],
) -> ClusterOrderingMetadata {
  let rank_same_metadata = collect_rank_same_metadata(graph)
  let flat_constraint_metadata = build_cluster_flat_constraints(
    graph, nodes, edges, edge_tail, edge_head, ranks, cluster_keys,
  )
  {
    rank_same_groups: rank_same_metadata.rank_same_groups,
    rank_same_order: rank_same_metadata.rank_same_order,
    flat_constraints: flat_constraint_metadata.flat_constraints,
    ordering_set: flat_constraint_metadata.ordering_set,
  }
}

///|
/// Graphviz parity: dot cluster-metadata source bundle keeps stage-side rank
/// snapshots and rankdir grouped so ordering owner code computes graphviz_flip
/// and metadata assembly together.
pub(all) struct DotClusterMetadataSources {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  groups : Map[Int, Array[String]]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  edge_tail : Array[String]
  edge_head : Array[String]
  rankdir : @rankdir.RankDir
}

///|
/// Graphviz parity: dot cluster metadata assembly merges clustering core and
/// ordering metadata after deriving graphviz_flip from the grouped rankdir
/// source.
/// Do not change behavior without updating fixtures/tests.
pub fn build_dot_cluster_metadata_from_sources(
  sources : DotClusterMetadataSources,
) -> DotClusterMetadata {
  let graphviz_flip = sources.rankdir == @rankdir.RankDir::LR ||
    sources.rankdir == @rankdir.RankDir::RL
  build_dot_cluster_metadata(sources, graphviz_flip)
}

///|
/// Graphviz parity: dot cluster metadata payload keeps cluster core + ordering
/// snapshots grouped for stage-B/stage-C/stage-D wiring.
pub(all) struct DotClusterMetadata {
  has_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
/// Graphviz parity: dot cluster metadata assembly merges clustering core
/// metadata and ordering metadata before clustered dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_dot_cluster_metadata(
  sources : DotClusterMetadataSources,
  graphviz_flip : Bool,
) -> DotClusterMetadata {
  let cluster_core = @clustering.build_cluster_core_metadata_for_ordering(
    sources.graph,
    sources.nodes,
    sources.groups,
    sources.ranks,
    sources.node_order,
    graphviz_flip,
    @sys.get_env_var("DOT_CLUSTER_ORDER_BASE") is Some(_),
  )
  let ordering_metadata = build_cluster_ordering_metadata(
    sources.graph,
    sources.nodes,
    sources.edges,
    sources.edge_tail,
    sources.edge_head,
    sources.ranks,
    cluster_core.cluster_keys,
  )
  {
    has_clusters: cluster_core.has_clusters,
    cluster_keys: cluster_core.cluster_keys,
    cluster_skeleton: cluster_core.cluster_skeleton,
    cluster_min_rank: cluster_core.cluster_min_rank,
    cluster_max_rank: cluster_core.cluster_max_rank,
    cluster_order: cluster_core.cluster_order,
    cluster_parents: cluster_core.cluster_parents,
    intercluster_keys: cluster_core.intercluster_keys,
    rank_same_groups: ordering_metadata.rank_same_groups,
    rank_same_order: ordering_metadata.rank_same_order,
    flat_constraints: ordering_metadata.flat_constraints,
    ordering_set: ordering_metadata.ordering_set,
  }
}

///|
/// Graphviz parity: ordering pipeline context keeps runtime expansion, edge-port
/// extraction, and reorder-setup snapshots grouped so owner-side dispatch can
/// reuse the same Stage C setup artifacts.
pub(all) struct OrderingPipelineContext {
  runtime_context : OrderingRuntimeContext
  edge_port_data : OrderingEdgePortData
  reorder_setup : OrderingReorderSetup
}

///|
/// Graphviz parity: ordering pipeline source bundle keeps stage-side graph/rank
/// snapshots grouped so owner code assembles runtime, class2, and reorder setup
/// in one boundary.
pub(all) struct BuildOrderingPipelineContextSources {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  nodesep_pt : Double
  rankdir : @rankdir.RankDir
  cluster_meta : DotClusterMetadata
}

///|
/// Graphviz parity: ordering stage result keeps reordered rank groups, vnode
/// metadata, and derived edge-order snapshots grouped for downstream stages.
pub(all) struct OrderingResult {
  ordered_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  vnode_info : EdgeVnodeInfo
  vnode_count : Int
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  edge_order : Map[String, Int]
  edge_cluster_keys : Map[String, String]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
/// Graphviz parity: ordering pipeline context assembles runtime expansion,
/// edge-port snapshots, and reorder setup in the same sequence as Graphviz.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_pipeline_context_from_sources(
  sources : BuildOrderingPipelineContextSources,
  build_port_sample_bundle : (Array[@cgraph.Edge], Array[String], Array[String]) -> EdgePortSampleBundle,
) -> OrderingPipelineContext {
  let runtime_context = build_ordering_runtime_context_from_sources({
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
    cluster_meta: sources.cluster_meta,
  })
  let edge_port_data = build_ordering_edge_port_data_from_sources(
    {
      edges: sources.edges,
      edge_tail: sources.edge_tail,
      edge_head: sources.edge_head,
    },
    build_port_sample_bundle,
  )
  let reorder_setup = build_ordering_reorder_setup_from_sources({
    nodes: sources.nodes,
    edges: sources.edges,
    edge_tail: sources.edge_tail,
    edge_head: sources.edge_head,
    edge_reversed: sources.edge_reversed,
    edge_out_order: sources.edge_out_order,
    ranks: sources.ranks,
    groups: sources.groups,
    node_order: sources.node_order,
    port_edge_nodes: runtime_context.port_edge_nodes,
    vnode_info: runtime_context.vnode_info,
    cluster_has_clusters: sources.cluster_meta.has_clusters,
    cluster_keys: sources.cluster_meta.cluster_keys,
    cluster_order: sources.cluster_meta.cluster_order,
    cluster_min_rank: sources.cluster_meta.cluster_min_rank,
    cluster_max_rank: sources.cluster_meta.cluster_max_rank,
    cluster_parents: sources.cluster_meta.cluster_parents,
    rank_same_groups: sources.cluster_meta.rank_same_groups,
    rank_same_order: sources.cluster_meta.rank_same_order,
    rankdir: sources.rankdir,
    edge_port_data,
  })
  { runtime_context, edge_port_data, reorder_setup }
}

///|
/// Graphviz parity: ordering result assembly forwards dispatch and pipeline
/// snapshots in Graphviz-aligned field composition order.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_result_from_pipeline_context(
  pipeline_context : OrderingPipelineContext,
  ordered_groups : Map[Int, Array[String]],
  ordered_groups_with_vnodes : Map[Int, Array[String]],
) -> OrderingResult {
  {
    ordered_groups,
    ordered_groups_with_vnodes,
    vnode_info: pipeline_context.runtime_context.vnode_info,
    vnode_count: pipeline_context.runtime_context.vnode_info.vnode_ranks.length(),
    order_edges: pipeline_context.edge_port_data.order_edges,
    order_edge_tail: pipeline_context.edge_port_data.order_edge_tail,
    order_edge_head: pipeline_context.edge_port_data.order_edge_head,
    edge_order: pipeline_context.edge_port_data.edge_order,
    edge_cluster_keys: pipeline_context.runtime_context.edge_cluster_keys,
    nlist_order: pipeline_context.reorder_setup.class2_data.nlist_order,
    gdnlist_order: pipeline_context.reorder_setup.gdnlist_order,
    vnode_creation_order: pipeline_context.reorder_setup.class2_data.vnode_creation_order,
  }
}
