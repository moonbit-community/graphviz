///|
/// Graphviz parity: xpos nlist order keeps clustered reverse-rank traversal,
/// vnode-first ordering, and LR/RL source-order fast path aligned with
/// position.c/create_aux_edges.
pub(all) struct XposNlistOrderInput {
  rankdir : @rankdir.RankDir
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  cluster_keys : Map[String, String]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
}

///|
/// Graphviz parity: class2/decompose creation order is consumed in reverse for
/// clustered xpos (except LR/RL), with virtual nodes visited before rank peers.
fn build_xpos_nlist_order(input : XposNlistOrderInput) -> Array[String] {
  let nlist_source = if input.gdnlist_order.length() > 0 {
    input.gdnlist_order
  } else {
    input.nlist_order
  }
  let nlist_reversed : Array[String] = []
  let mut nlist_idx = nlist_source.length()
  while nlist_idx > 0 {
    nlist_idx = nlist_idx - 1
    nlist_reversed.push(nlist_source[nlist_idx])
  }
  let xpos_nlist_order : Array[String] = []
  let cluster_order : Array[String] = []
  let cluster_seen : Map[String, Bool] = Map::new()
  let prefer_source_for_lr = input.rankdir == @rankdir.RankDir::LR ||
    input.rankdir == @rankdir.RankDir::RL
  for name in nlist_reversed {
    let cluster = input.cluster_keys.get(name).unwrap_or_default()
    if cluster != "" && cluster_seen.get(cluster) is None {
      cluster_seen[cluster] = true
      cluster_order.push(cluster)
    }
  }
  if prefer_source_for_lr || cluster_order.length() == 0 {
    for name in nlist_source {
      xpos_nlist_order.push(name)
    }
    return xpos_nlist_order
  }
  let xpos_seen : Map[String, Bool] = Map::new()
  for cluster in cluster_order {
    let mut rank_idx = input.rank_keys.length()
    while rank_idx > 0 {
      rank_idx = rank_idx - 1
      let rank = input.rank_keys[rank_idx]
      let names = input.groups.get(rank).unwrap_or_default()
      // Graphviz parity: decompose-created virtual nodes are visited before
      // their rank peers in clustered GD_nlist traversals.
      let mut name_idx = names.length()
      while name_idx > 0 {
        name_idx = name_idx - 1
        let name = names[name_idx]
        if !@edge_identity.is_edge_vnode_name(name) {
          continue
        }
        let name_cluster = input.cluster_keys.get(name).unwrap_or_default()
        if name_cluster == cluster && xpos_seen.get(name) is None {
          xpos_nlist_order.push(name)
          xpos_seen[name] = true
        }
      }
      name_idx = names.length()
      while name_idx > 0 {
        name_idx = name_idx - 1
        let name = names[name_idx]
        if @edge_identity.is_edge_vnode_name(name) {
          continue
        }
        let name_cluster = input.cluster_keys.get(name).unwrap_or_default()
        if name_cluster == cluster && xpos_seen.get(name) is None {
          xpos_nlist_order.push(name)
          xpos_seen[name] = true
        }
      }
    }
  }
  for name in nlist_reversed {
    if xpos_seen.get(name) is None {
      xpos_nlist_order.push(name)
      xpos_seen[name] = true
    }
  }
  xpos_nlist_order
}

///|
/// Graphviz parity: GD_nlist after create_aux_edges prepends slack nodes in
/// reverse creation order, then preserves GD_nlist order for existing nodes.
pub(all) struct ConstraintReorderInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  nlist_order : Array[String]
}

///|
/// Graphviz parity: order mirrors position.c's auxiliary-graph sweep and keeps
/// slack helper nodes ahead of non-slack constraints.
fn build_constraint_reorder(input : ConstraintReorderInput) -> Array[Int] {
  let total = input.graph.nodes.length()
  let order : Array[Int] = []
  if total == 0 {
    return order
  }
  let seen : Array[Bool] = []
  for _ in 0..<total {
    seen.push(false)
  }
  let slack_indices : Array[Int] = []
  for i in 0..<total {
    if input.graph.nodes[i].kind == @network_simplex.NodeKind::Slack {
      slack_indices.push(i)
    }
  }
  let mut slack_idx = slack_indices.length()
  while slack_idx > 0 {
    slack_idx = slack_idx - 1
    let node_idx = slack_indices[slack_idx]
    order.push(node_idx)
    seen[node_idx] = true
  }
  let mut nlist_idx = input.nlist_order.length()
  while nlist_idx > 0 {
    nlist_idx = nlist_idx - 1
    let name = input.nlist_order[nlist_idx]
    match input.index.get(name) {
      Some(node_idx) =>
        if !seen[node_idx] {
          order.push(node_idx)
          seen[node_idx] = true
        }
      None => ()
    }
  }
  for i in 0..<total {
    if !seen[i] {
      order.push(i)
      seen[i] = true
    }
  }
  order
}

///|
pub(all) struct ReorderConstraintGraphInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  order : Array[Int]
}

///|
pub(all) struct ReorderConstraintGraphOutput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
}

///|
/// Graphviz parity: preserves node rank values while rewriting node ids to the
/// computed order vector consumed by network simplex.
fn reorder_constraint_graph(
  input : ReorderConstraintGraphInput,
) -> ReorderConstraintGraphOutput {
  let total = input.graph.nodes.length()
  if total == 0 || input.order.length() != total {
    return { graph: input.graph, index: input.index }
  }
  let new_graph = @network_simplex.new_graph()
  let old_to_new : Array[Int] = []
  for _ in 0..<total {
    old_to_new.push(-1)
  }
  for old_idx in input.order {
    let node = input.graph.nodes[old_idx]
    let new_idx = @network_simplex.add_node(new_graph, "", kind=node.kind)
    @network_simplex.set_node_rank(new_graph, new_idx, node.rank)
    old_to_new[old_idx] = new_idx
  }
  for edge in input.graph.edges {
    let tail = old_to_new[edge.tail]
    let head = old_to_new[edge.head]
    let _ = @network_simplex.add_edge(
      new_graph,
      tail,
      head,
      edge.minlen,
      edge.weight,
    )
  }
  let new_index : Map[String, Int] = Map::new()
  for name, old_idx in input.index {
    let new_idx = old_to_new[old_idx]
    new_index[name] = new_idx
  }
  { graph: new_graph, index: new_index }
}

///|
type SnapshotNodeSize = @node_primitives.NodeSize

///|
pub(all) struct XposConstraintNodeSnapshot {
  name : String?
  kind : @network_simplex.NodeKind
  rank : Int
  order : Int
  left_pt : Double
  right_pt : Double
  height_pt : Double
}

///|
pub(all) struct XposConstraintEdgeSnapshot {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
pub(all) struct XposConstraintSnapshot {
  nodes : Array[XposConstraintNodeSnapshot]
  edges : Array[XposConstraintEdgeSnapshot]
}

///|
fn touch_constraint_snapshot(snapshot : XposConstraintSnapshot) -> Unit {
  let _ = snapshot.nodes
  let _ = snapshot.edges
  for node in snapshot.nodes {
    let _ = node.name
    let _ = node.kind
    let _ = node.rank
    let _ = node.order
    let _ = node.left_pt
    let _ = node.right_pt
    let _ = node.height_pt
  }
  for edge in snapshot.edges {
    let _ = edge.tail
    let _ = edge.head
    let _ = edge.minlen
    let _ = edge.weight
  }
}

///|
pub let xpos_constraint_snapshot : Ref[XposConstraintSnapshot?] = Ref::new(None)

///|
pub fn should_capture_xpos_snapshot(graph : @cgraph.Graph) -> Bool {
  match @sys.get_env_var("DOT_CAPTURE_XPOS_CONSTRAINTS") {
    None => false
    Some(value) => {
      if value == "" || value == "1" {
        return true
      }
      match graph.name() {
        Some(name) => name == value
        None => false
      }
    }
  }
}

///|
fn build_constraint_snapshot(
  graph : @network_simplex.NsGraph,
  index : Map[String, Int],
  sizes : Map[String, SnapshotNodeSize],
  order_index : Map[String, Int],
) -> XposConstraintSnapshot {
  let names : Array[String?] = []
  for _ in 0..<graph.nodes.length() {
    names.push(None)
  }
  for name, idx in index {
    names[idx] = Some(name)
  }
  let nodes : Array[XposConstraintNodeSnapshot] = []
  for i in 0..<graph.nodes.length() {
    let node = graph.nodes[i]
    let name = names[i]
    let mut left_pt = 1.0
    let mut right_pt = 1.0
    let mut height_pt = 1.0
    let mut order = 0
    match name {
      Some(value) =>
        match sizes.get(value) {
          Some(size) => {
            left_pt = size.left_pt
            right_pt = size.right_pt
            height_pt = size.height_pt
          }
          None => ()
        }
      None => ()
    }
    match name {
      Some(value) =>
        match order_index.get(value) {
          Some(value) => order = value
          None => ()
        }
      None => ()
    }
    nodes.push({
      name,
      kind: node.kind,
      rank: node.rank,
      order,
      left_pt,
      right_pt,
      height_pt,
    })
  }
  let edges : Array[XposConstraintEdgeSnapshot] = []
  for edge in graph.edges {
    edges.push({
      tail: edge.tail,
      head: edge.head,
      minlen: edge.minlen,
      weight: edge.weight,
    })
  }
  let snapshot = { nodes, edges }
  touch_constraint_snapshot(snapshot)
  snapshot
}

///|
/// Positioning domain: x-position constraint input preparation helpers.

///|
pub(all) struct PreparedXposConstraintInputs {
  extra_nodes : Array[ExtraConstraintNode]
  extra_edges : Array[ConstraintEdge]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
  compress_width_minlen : Int?
}

///|
fn prepare_xpos_constraint_inputs(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, @node_primitives.NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  edge_vnodes : Map[String, Array[String]],
  base_extra_nodes : Array[ExtraConstraintNode],
  flat_label_edges : Array[ConstraintEdge],
) -> PreparedXposConstraintInputs {
  let cluster_constraints = build_cluster_constraints(
    graph, nodes, edges, ranks, rank_keys, groups, sizes, cluster_keys, nodesep_pt,
    has_edge_labels, edge_vnodes,
  )
  let all_extra_nodes = base_extra_nodes.copy()
  for pair in cluster_constraints.extra_nodes {
    all_extra_nodes.push(pair)
  }
  let all_extra_edges = cluster_constraints.extra_edges.copy()
  for edge in flat_label_edges {
    all_extra_edges.push(edge)
  }
  let rankdir = @rankdir.graph_rankdir(graph)
  let compress_width_minlen = compress_width_minlen_pt(graph, rankdir)
  let all_root_ln_targets = cluster_constraints.root_ln_targets.copy()
  let all_root_rn_targets = cluster_constraints.root_rn_targets.copy()
  match compress_width_minlen {
    Some(_) =>
      // Graphviz parity: contain_nodes constrains per-rank leftmost/rightmost
      // nodes against root ln/rn before adding the compress edge.
      append_missing_rank_boundary_targets(
        rank_keys, groups, all_root_ln_targets, all_root_rn_targets,
      )
    None => ()
  }
  {
    extra_nodes: all_extra_nodes,
    extra_edges: all_extra_edges,
    root_ln_targets: all_root_ln_targets,
    root_rn_targets: all_root_rn_targets,
    compress_width_minlen,
  }
}

///|
/// Graphviz parity: x-position solve input keeps reordered rank metadata,
/// vnode extra-node toggles, and size overlays grouped for one xpos call.
pub struct XposComputationInput {
  x_sizes : Map[String, @node_primitives.NodeSize]
  x_rank_keys : Array[Int]
  x_ranks : Map[String, Int]
  x_extra_nodes : Array[ExtraConstraintNode]
  x_edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: xpos source bundle keeps x-stage payload and vnode replay
/// metadata grouped so Stage D call-sites avoid positional drift.
priv struct XposComputationInputSources {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, @node_primitives.NodeSize]
  x_groups : Map[Int, Array[String]]
  vnode_sizes : Map[String, @node_primitives.NodeSize]
  vnode_creation_order : Array[String]
  vnode_ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: preserve vnode insertion order when seeding extra nodes
/// for xpos constraints (nlist-driven ordering), with map-order fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_extra_nodes(
  vnode_order : Array[String],
  vnode_ranks : Map[String, Int],
) -> Array[ExtraConstraintNode] {
  let extra : Array[ExtraConstraintNode] = []
  let seen : Map[String, Bool] = Map::new()
  if vnode_order.length() > 0 {
    for name in vnode_order {
      match vnode_ranks.get(name) {
        Some(rank) => {
          extra.push({ name, rank })
          seen[name] = true
        }
        None => ()
      }
    }
  }
  if extra.length() < vnode_ranks.length() {
    for name, rank in vnode_ranks {
      if seen.get(name) is None {
        extra.push({ name, rank })
      }
    }
  }
  extra
}

///|
/// Graphviz parity: xpos solver inputs preserve vnode-size merge,
/// rank-map/key derivation, and vnode-edge/slack toggles.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_computation_input_from_sources(
  sources : XposComputationInputSources,
) -> XposComputationInput {
  let x_sizes = if sources.use_vnodes_for_xpos {
    @shared.merge_sizes_with_vnodes(sources.x_base_sizes, sources.vnode_sizes)
  } else {
    sources.x_base_sizes
  }
  let x_rank_keys = @shared.collect_rank_keys(sources.x_groups)
  let x_ranks = @shared.build_node_ranks(sources.x_groups)
  let vnode_extra_nodes = if sources.use_vnodes_for_xpos {
    build_vnode_extra_nodes(sources.vnode_creation_order, sources.vnode_ranks)
  } else {
    []
  }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes = if sources.use_vnodes_for_xpos {
    sources.edge_vnodes
  } else {
    Map::new()
  }
  { x_sizes, x_rank_keys, x_ranks, x_extra_nodes, x_edge_vnodes }
}

///|
/// Graphviz parity: xpos solver callback input keeps one compute_x_positions
/// invocation payload grouped so stage wiring avoids positional drift.
pub(all) struct XPositionSolveInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  sizes : Map[String, @node_primitives.NodeSize]
  output_sizes : Map[String, @node_primitives.NodeSize]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  extra_nodes : Array[ExtraConstraintNode]
  flat_label_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: x-position pipeline input keeps x-seed + vnode replay
/// snapshots and one compute_x_positions callback payload at one boundary.
pub(all) struct XPositionPipelineInput {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, @node_primitives.NodeSize]
  x_groups : Map[Int, Array[String]]
  vnode_sizes : Map[String, @node_primitives.NodeSize]
  vnode_creation_order : Array[String]
  vnode_ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  output_sizes : Map[String, @node_primitives.NodeSize]
  flat_label_edges : Array[ConstraintEdge]
}

///|
/// Graphviz parity: x-position stage keeps vnode merge and rank-derivation
/// order unchanged while producing one stable solve payload.
/// Do not change behavior without updating fixtures/tests.
pub fn build_x_position_solve_input(
  input : XPositionPipelineInput,
) -> XPositionSolveInput {
  let xpos_input = build_xpos_computation_input_from_sources({
    use_vnodes_for_xpos: input.use_vnodes_for_xpos,
    x_base_sizes: input.x_base_sizes,
    x_groups: input.x_groups,
    vnode_sizes: input.vnode_sizes,
    vnode_creation_order: input.vnode_creation_order,
    vnode_ranks: input.vnode_ranks,
    edge_vnodes: input.edge_vnodes,
  })
  {
    graph: input.graph,
    nodes: input.nodes,
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_out_order: input.edge_out_order,
    nlist_order: input.nlist_order,
    gdnlist_order: input.gdnlist_order,
    ranks: xpos_input.x_ranks,
    rank_keys: xpos_input.x_rank_keys,
    groups: input.x_groups,
    sizes: xpos_input.x_sizes,
    output_sizes: input.output_sizes,
    cluster_keys: input.cluster_keys,
    nodesep_pt: input.nodesep_pt,
    has_edge_labels: input.has_edge_labels,
    extra_nodes: xpos_input.x_extra_nodes,
    flat_label_edges: input.flat_label_edges,
    edge_vnodes: xpos_input.x_edge_vnodes,
  }
}

///|
priv struct XposSimplexSolveInput {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  sizes : Map[String, @node_primitives.NodeSize]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  extra_nodes : Array[ExtraConstraintNode]
  extra_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
  compress_width_minlen : Int?
  segment_minlen_fn : (SlackSegment, Map[String, @cgraph.Node]) -> (Int, Int)
  edge_has_mid_label_fn : (@cgraph.Edge) -> Bool
  edge_degree_increment_fn : (@cgraph.Edge) -> Int
  root_margin : Double
  root_compress_weight : Int
  on_reordered_graph : (@network_simplex.NsGraph, Map[String, Int]) -> Unit
}

///|
/// Graphviz parity: xpos simplex solve consumes the already prepared GD_nlist
/// order, builds/reorders the auxiliary constraint graph, and then runs
/// network_simplex exactly once before reading node ranks.
/// Do not change behavior without updating fixtures/tests.
fn solve_xpos_with_simplex(
  input : XposSimplexSolveInput,
) -> Map[String, Double] {
  let constraint_graph = build_constraint_graph({
    nodes: input.nodes,
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_out_order: input.edge_out_order,
    nlist_order: input.nlist_order,
    ranks: input.ranks,
    rank_keys: input.rank_keys,
    groups: input.groups,
    sizes: input.sizes,
    cluster_keys: input.cluster_keys,
    nodesep_pt: input.nodesep_pt,
    has_edge_labels: input.has_edge_labels,
    extra_nodes: input.extra_nodes,
    extra_edges: input.extra_edges,
    edge_vnodes: input.edge_vnodes,
    root_ln_targets: input.root_ln_targets,
    root_rn_targets: input.root_rn_targets,
    compress_width_minlen: input.compress_width_minlen,
    segment_minlen: input.segment_minlen_fn,
    edge_has_mid_label: input.edge_has_mid_label_fn,
    edge_degree_increment: input.edge_degree_increment_fn,
    root_margin: input.root_margin,
    root_compress_weight: input.root_compress_weight,
  })
  // Graphviz parity: constraint graph reorder follows GD_nlist sequence.
  let order = build_constraint_reorder({
    graph: constraint_graph.graph,
    index: constraint_graph.index,
    nlist_order: input.nlist_order,
  })
  let reordered = reorder_constraint_graph({
    graph: constraint_graph.graph,
    index: constraint_graph.index,
    order,
  })
  (input.on_reordered_graph)(reordered.graph, reordered.index)
  @network_simplex.network_simplex(
    reordered.graph,
    0x7fffffff,
    @network_simplex.BalanceMode::LR,
  )
  let positions : Map[String, Double] = Map::new()
  for node in input.nodes {
    let name = node.name()
    let idx = reordered.index.get(name).unwrap_or_default()
    positions[name] = @network_simplex.node_rank(reordered.graph, idx).to_double()
  }
  for extra_node in input.extra_nodes {
    let idx = reordered.index.get(extra_node.name).unwrap_or_default()
    positions[extra_node.name] = @network_simplex.node_rank(
      reordered.graph,
      idx,
    ).to_double()
  }
  positions
}

///|
/// Positioning domain: x-position simplex solve pipeline bridge.
priv struct XSimplexInput {
  graph_root : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  sizes : Map[String, @node_primitives.NodeSize]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  extra_nodes : Array[ExtraConstraintNode]
  extra_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
  compress_width_minlen : Int?
  root_margin : Double
  root_compress_weight : Int
  segment_minlen_fn : (SlackSegment, Map[String, @cgraph.Node]) -> (Int, Int)
  edge_has_mid_label_fn : (@cgraph.Edge) -> Bool
  edge_degree_increment_fn : (@cgraph.Edge) -> Int
  capture_snapshot : Bool
  order_index : Map[String, Int]
}

///|
fn x_positions_from_simplex(input : XSimplexInput) -> Map[String, Double] {
  let xpos_nlist_order = build_xpos_nlist_order({
    rankdir: @rankdir.graph_rankdir(input.graph_root),
    nlist_order: input.nlist_order,
    gdnlist_order: input.gdnlist_order,
    cluster_keys: input.cluster_keys,
    rank_keys: input.rank_keys,
    groups: input.groups,
  })
  solve_xpos_with_simplex({
    nodes: input.nodes,
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_out_order: input.edge_out_order,
    nlist_order: xpos_nlist_order,
    ranks: input.ranks,
    rank_keys: input.rank_keys,
    groups: input.groups,
    sizes: input.sizes,
    cluster_keys: input.cluster_keys,
    nodesep_pt: input.nodesep_pt,
    has_edge_labels: input.has_edge_labels,
    extra_nodes: input.extra_nodes,
    extra_edges: input.extra_edges,
    edge_vnodes: input.edge_vnodes,
    root_ln_targets: input.root_ln_targets,
    root_rn_targets: input.root_rn_targets,
    compress_width_minlen: input.compress_width_minlen,
    segment_minlen_fn: input.segment_minlen_fn,
    edge_has_mid_label_fn: input.edge_has_mid_label_fn,
    edge_degree_increment_fn: input.edge_degree_increment_fn,
    root_margin: input.root_margin,
    root_compress_weight: input.root_compress_weight,
    on_reordered_graph: (graph, index) => {
      if input.capture_snapshot {
        xpos_constraint_snapshot.val = Some(
          build_constraint_snapshot(
            graph,
            index,
            input.sizes,
            input.order_index,
          ),
        )
      }
    },
  })
}

///|
/// Graphviz parity: x-position solve bridge keeps constraint preparation,
/// simplex-input assembly, and snapshot/order wiring in one boundary helper.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_x_positions_with_prepared_constraints(
  solve_input : XPositionSolveInput,
  root_margin : Double,
  root_compress_weight : Int,
  segment_minlen_fn : (SlackSegment, Map[String, @cgraph.Node]) -> (Int, Int),
  edge_has_mid_label_fn : (@cgraph.Edge) -> Bool,
  edge_degree_increment_fn : (@cgraph.Edge) -> Int,
  capture_snapshot : Bool,
) -> Map[String, Double] {
  let prepared = prepare_xpos_constraint_inputs(
    solve_input.graph,
    solve_input.nodes,
    solve_input.edges,
    solve_input.ranks,
    solve_input.rank_keys,
    solve_input.groups,
    solve_input.sizes,
    solve_input.cluster_keys,
    solve_input.nodesep_pt,
    solve_input.has_edge_labels,
    solve_input.edge_vnodes,
    solve_input.extra_nodes,
    solve_input.flat_label_edges,
  )
  let order_index = @shared.build_order_index(solve_input.groups)
  x_positions_from_simplex({
    graph_root: solve_input.graph,
    nodes: solve_input.nodes,
    edges: solve_input.edges,
    edge_tail: solve_input.edge_tail,
    edge_head: solve_input.edge_head,
    edge_out_order: solve_input.edge_out_order,
    nlist_order: solve_input.nlist_order,
    gdnlist_order: solve_input.gdnlist_order,
    ranks: solve_input.ranks,
    rank_keys: solve_input.rank_keys,
    groups: solve_input.groups,
    sizes: solve_input.sizes,
    cluster_keys: solve_input.cluster_keys,
    nodesep_pt: solve_input.nodesep_pt,
    has_edge_labels: solve_input.has_edge_labels,
    extra_nodes: prepared.extra_nodes,
    extra_edges: prepared.extra_edges,
    edge_vnodes: solve_input.edge_vnodes,
    root_ln_targets: prepared.root_ln_targets,
    root_rn_targets: prepared.root_rn_targets,
    compress_width_minlen: prepared.compress_width_minlen,
    root_margin,
    root_compress_weight,
    segment_minlen_fn,
    edge_has_mid_label_fn,
    edge_degree_increment_fn,
    capture_snapshot,
    order_index,
  })
}
