///|
/// Graphviz parity: x-constraint edges carry minlen/weight plus optional
/// tail/head port tags used by ordering-sensitive edge-constraint assembly.
pub(all) struct ConstraintEdge {
  tail : String
  head : String
  minlen : Int
  weight : Int
  tail_port : String?
  head_port : String?
}

///|
/// Graphviz parity: duplicated constraint keys keep the max(minlen, weight)
/// just like constraint accumulation in xpos wiring.
fn upsert_constraint_with_max(
  constraints : Map[String, ConstraintEdge],
  key : String,
  tail : String,
  head : String,
  minlen : Int,
  weight : Int,
) -> Unit {
  match constraints.get(key) {
    Some(entry) =>
      constraints[key] = {
        tail: entry.tail,
        head: entry.head,
        minlen: if minlen > entry.minlen {
          minlen
        } else {
          entry.minlen
        },
        weight: if weight > entry.weight {
          weight
        } else {
          entry.weight
        },
        tail_port: None,
        head_port: None,
      }
    None =>
      constraints[key] = {
        tail,
        head,
        minlen,
        weight,
        tail_port: None,
        head_port: None,
      }
  }
}

///|
/// Graphviz parity: constraint edges are added only when both endpoints are
/// present in the current simplex index.
pub fn add_constraint_edge_if_present(
  graph : @network_simplex.NsGraph,
  index : Map[String, Int],
  edge : ConstraintEdge,
) -> Unit {
  match index.get(edge.tail) {
    Some(tail_idx) =>
      match index.get(edge.head) {
        Some(head_idx) => {
          let _ = @network_simplex.add_edge(
            graph,
            tail_idx,
            head_idx,
            edge.minlen,
            edge.weight,
          )
        }
        None => ()
      }
    None => ()
  }
}

///|
pub(all) struct ExtraConstraintNode {
  name : String
  rank : Int
}

///|
priv struct ConstraintNodeSeed {
  real_by_name : Map[String, @cgraph.Node]
  extra_rank : Map[String, Int]
  late_extra_nodes : Array[ExtraConstraintNode]
}

///|
fn build_constraint_node_seed(
  nodes : Array[@cgraph.Node],
  extra_nodes : Array[ExtraConstraintNode],
) -> ConstraintNodeSeed {
  let early_extra_nodes : Array[ExtraConstraintNode] = []
  let late_extra_nodes : Array[ExtraConstraintNode] = []
  for extra_node in extra_nodes {
    if @cluster_identity.is_cluster_boundary_name(extra_node.name) {
      late_extra_nodes.push(extra_node)
    } else {
      early_extra_nodes.push(extra_node)
    }
  }
  let real_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    real_by_name[node.name()] = node
  }
  let extra_rank : Map[String, Int] = Map::new()
  for extra_node in early_extra_nodes {
    extra_rank[extra_node.name] = extra_node.rank
  }
  { real_by_name, extra_rank, late_extra_nodes }
}

///|
fn build_constraint_ordered_names(
  nodes : Array[@cgraph.Node],
  nlist_order : Array[String],
  real_by_name : Map[String, @cgraph.Node],
  extra_rank : Map[String, Int],
) -> Array[String] {
  let ordered_names : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in nlist_order {
    if real_by_name.get(name) is Some(_) || extra_rank.get(name) is Some(_) {
      if seen.get(name) is None {
        ordered_names.push(name)
        seen[name] = true
      }
    }
  }
  for node in nodes {
    let name = node.name()
    if seen.get(name) is None {
      ordered_names.push(name)
      seen[name] = true
    }
  }
  for name, _rank in extra_rank {
    if seen.get(name) is None {
      ordered_names.push(name)
      seen[name] = true
    }
  }
  ordered_names
}

///|
pub fn constraint_node_kind(name : String) -> @network_simplex.NodeKind {
  if @edge_identity.is_edge_vnode_name(name) {
    @network_simplex.NodeKind::Virtual
  } else if @cluster_identity.is_cluster_boundary_name(name) {
    @network_simplex.NodeKind::Slack
  } else {
    @network_simplex.NodeKind::Normal
  }
}

///|
fn add_ordered_constraint_nodes(
  graph : @network_simplex.NsGraph,
  index : Map[String, Int],
  ordered_names : Array[String],
  real_by_name : Map[String, @cgraph.Node],
  extra_rank : Map[String, Int],
  base_positions : Map[String, Double],
) -> Unit {
  for name in ordered_names {
    match real_by_name.get(name) {
      Some(node) => {
        let idx = @network_simplex.add_node(graph, node.name())
        index[name] = idx
        let pos = base_positions.get(name).unwrap_or_default()
        @network_simplex.set_node_rank(graph, idx, @numeric.trunc_int(pos))
      }
      None =>
        match extra_rank.get(name) {
          Some(rank) => {
            let idx = @network_simplex.add_node(
              graph,
              name,
              kind=constraint_node_kind(name),
            )
            index[name] = idx
            let pos = base_positions.get(name).unwrap_or(rank.to_double())
            @network_simplex.set_node_rank(graph, idx, @numeric.trunc_int(pos))
          }
          None => ()
        }
    }
  }
}

///|
/// Graphviz parity: constraint-node setup preserves GD_nlist-preferred node
/// insertion order, then appends missing real nodes and early aux nodes.
pub(all) struct ConstraintNodesSetupInput {
  graph : @network_simplex.NsGraph
  nodes : Array[@cgraph.Node]
  extra_nodes : Array[ExtraConstraintNode]
  nlist_order : Array[String]
  base_positions : Map[String, Double]
}

///|
/// Graphviz parity: cluster boundary helpers remain late-boundary nodes while
/// all other aux nodes are materialized in the initial constraint index.
pub(all) struct ConstraintNodesSetupOutput {
  index : Map[String, Int]
  real_by_name : Map[String, @cgraph.Node]
  late_extra_nodes : Array[ExtraConstraintNode]
}

///|
fn build_constraint_nodes_setup(
  input : ConstraintNodesSetupInput,
) -> ConstraintNodesSetupOutput {
  let seed = build_constraint_node_seed(input.nodes, input.extra_nodes)
  let ordered_names = build_constraint_ordered_names(
    input.nodes,
    input.nlist_order,
    seed.real_by_name,
    seed.extra_rank,
  )
  let index : Map[String, Int] = Map::new()
  add_ordered_constraint_nodes(
    input.graph,
    index,
    ordered_names,
    seed.real_by_name,
    seed.extra_rank,
    input.base_positions,
  )
  {
    index,
    real_by_name: seed.real_by_name,
    late_extra_nodes: seed.late_extra_nodes,
  }
}

///|
pub(all) struct LateConstraintNodesInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  late_extra_nodes : Array[ExtraConstraintNode]
}

///|
/// Graphviz parity: cluster boundary helpers enter the aux graph at rank 0
/// and are later positioned by constraints, not by seed x ranks.
fn append_late_constraint_nodes(input : LateConstraintNodesInput) -> Unit {
  for extra_node in input.late_extra_nodes {
    let idx = @network_simplex.add_node(
      input.graph,
      extra_node.name,
      kind=constraint_node_kind(extra_node.name),
    )
    input.index[extra_node.name] = idx
    @network_simplex.set_node_rank(input.graph, idx, 0)
  }
}

///|
fn round_int_for_seed(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
fn nodesep_minlen_for_seed(
  tail_name : String,
  head_name : String,
  sizes : Map[String, @node_primitives.NodeSize],
  nodesep_pt : Double,
) -> Int {
  let tail_size = sizes.get(tail_name)
  let head_size = sizes.get(head_name)
  let tail_right = match tail_size {
    Some(value) => value.right_pt
    None => @node_primitives.default_node_width_in() * 72.0 / 2.0
  }
  let head_left = match head_size {
    Some(value) => value.left_pt
    None => @node_primitives.default_node_width_in() * 72.0 / 2.0
  }
  let minlen = tail_right + head_left + nodesep_pt
  if minlen <= 0.0 {
    0
  } else {
    round_int_for_seed(minlen)
  }
}

///|
/// Graphviz parity: rank-adjacent seed constraints are emitted in rank/group
/// order before edge-chain segments are added.
pub(all) struct RankConstraintSeed {
  rank_adj_constraints : Map[String, ConstraintEdge]
  rank_adj_order : Array[String]
  order_in_rank : Map[String, Int]
}

///|
/// Graphviz parity: rank-adjacent constraints use rank_nodesep and node widths
/// exactly once per adjacent pair in each rank group.
fn build_rank_constraint_seed(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, @node_primitives.NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> RankConstraintSeed {
  let rank_adj_constraints : Map[String, ConstraintEdge] = Map::new()
  let rank_adj_order : Array[String] = []
  let order_in_rank : Map[String, Int] = Map::new()
  for rank in rank_keys {
    let names = groups.get(rank).unwrap_or_default()
    for i in 0..<names.length() {
      order_in_rank[names[i]] = i
    }
    let rank_nodesep = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    let mut i = 0
    while i + 1 < names.length() {
      let tail = names[i]
      let head = names[i + 1]
      let minlen = nodesep_minlen_for_seed(tail, head, sizes, rank_nodesep)
      let key = "\{tail}|\{head}"
      rank_adj_constraints[key] = {
        tail,
        head,
        minlen,
        weight: 0,
        tail_port: None,
        head_port: None,
      }
      rank_adj_order.push(key)
      i = i + 1
    }
  }
  { rank_adj_constraints, rank_adj_order, order_in_rank }
}

///|
/// Graphviz parity: edge iteration follows ND_out tail order first and then
/// falls back to unseen edge indices in input sequence.
fn for_each_edge_index_in_tail_order(
  edges : Array[@cgraph.Edge],
  edge_out_order : Map[String, Array[Int]],
  nlist_order : Array[String],
  visit : (Int) -> Unit,
) -> Unit {
  let seen_edges : Map[Int, Bool] = Map::new()
  for tail_name in nlist_order {
    let indices = edge_out_order.get(tail_name).unwrap_or_default()
    for edge_idx in indices {
      if edge_idx < 0 || edge_idx >= edges.length() {
        continue
      }
      seen_edges[edge_idx] = true
      visit(edge_idx)
    }
  }
  if seen_edges.length() < edges.length() {
    for edge_idx in 0..<edges.length() {
      if seen_edges.get(edge_idx) is None {
        visit(edge_idx)
      }
    }
  }
}

///|
priv enum EndpointClass {
  Ordinary
  Singleton
  Virtual
}

///|
fn endpoint_class(
  name : String,
  node_degrees : Map[String, Int],
) -> EndpointClass {
  if @edge_identity.is_edge_vnode_name(name) {
    EndpointClass::Virtual
  } else {
    let degree = node_degrees.get(name).unwrap_or_default()
    if degree <= 1 {
      EndpointClass::Singleton
    } else {
      EndpointClass::Ordinary
    }
  }
}

///|
fn constraint_weight_scale(
  tail_class : EndpointClass,
  head_class : EndpointClass,
) -> Int {
  match (tail_class, head_class) {
    (EndpointClass::Virtual, EndpointClass::Virtual) => 4
    (EndpointClass::Singleton, EndpointClass::Singleton)
    | (EndpointClass::Singleton, EndpointClass::Virtual)
    | (EndpointClass::Virtual, EndpointClass::Singleton) => 2
    _ => 1
  }
}

///|
/// Graphviz parity: edge segment weights are amplified for virtual/singleton
/// endpoints so auxiliary chains remain tight in sparse local neighborhoods.
fn scaled_segment_edge_weight(
  base_weight : Int,
  tail_name : String,
  head_name : String,
  node_degrees : Map[String, Int],
) -> Int {
  if base_weight == 0 {
    0
  } else {
    let tail_class = endpoint_class(tail_name, node_degrees)
    let head_class = endpoint_class(head_name, node_degrees)
    base_weight * constraint_weight_scale(tail_class, head_class)
  }
}

///|
fn edge_tail_ordering_is_out_or_in(edge : @cgraph.Edge) -> Bool {
  match @clustering.root_graph_for_node(edge.tail()).get_attr("ordering") {
    Some(value) => {
      let lower = value.to_lower()
      lower == "out" || lower == "in"
    }
    None => false
  }
}

///|
pub(all) struct SlackSegment {
  tail : String
  head : String
  weight : Int
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
}

///|
fn push_slack_segment(
  segments_by_tail : Map[String, Array[SlackSegment]],
  seg_tail : String,
  seg_head : String,
  weight : Int,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
) -> Unit {
  let entry = { tail: seg_tail, head: seg_head, weight, tail_port, head_port }
  match segments_by_tail.get(seg_tail) {
    Some(list) => list.push(entry)
    None => segments_by_tail[seg_tail] = [entry]
  }
}

///|
priv struct SegmentsInTailOrderInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  segments_by_tail : Map[String, Array[SlackSegment]]
  nlist_order : Array[String]
  segment_minlen : (SlackSegment) -> (Int, Int)
}

///|
/// Graphviz parity: virtual edge segment minlen asymmetry follows
/// make_edge_pairs delta split (positive=>tail arc, negative=>head arc).
pub fn segment_slack_minlen(
  segment : SlackSegment,
  edge_port_offset : (String, @cgraph.Port?) -> Double,
) -> (Int, Int) {
  let tail_offset = edge_port_offset(segment.tail, segment.tail_port)
  let head_offset = edge_port_offset(segment.head, segment.head_port)
  let delta = head_offset - tail_offset
  let m0 = if delta > 0.0 { @numeric.trunc_int(delta) } else { 0 }
  let m1 = if delta < 0.0 { @numeric.trunc_int(-delta) } else { 0 }
  (m0, m1)
}

///|
fn add_segment_slack_edges(
  graph : @network_simplex.NsGraph,
  index : Map[String, Int],
  segments : Array[SlackSegment],
  segment_minlen : (SlackSegment) -> (Int, Int),
) -> Unit {
  for seg in segments {
    let tail_idx = match index.get(seg.tail) {
      Some(value) => value
      None => continue
    }
    let head_idx = match index.get(seg.head) {
      Some(value) => value
      None => continue
    }
    let (m0, m1) = segment_minlen(seg)
    // Graphviz parity: make_edge_pairs applies to each virtual edge segment.
    let slack_idx = @network_simplex.add_node(
      graph,
      "",
      kind=@network_simplex.NodeKind::Slack,
    )
    let tail_rank = @network_simplex.node_rank(graph, tail_idx)
    let head_rank = @network_simplex.node_rank(graph, head_idx)
    let base_tail = tail_rank - m0 - 1
    let base_head = head_rank - m1 - 1
    @network_simplex.set_node_rank(
      graph,
      slack_idx,
      if base_tail < base_head {
        base_tail
      } else {
        base_head
      },
    )
    let _ = @network_simplex.add_edge(
      graph,
      slack_idx,
      tail_idx,
      m0 + 1,
      seg.weight,
    )
    let _ = @network_simplex.add_edge(
      graph,
      slack_idx,
      head_idx,
      m1 + 1,
      seg.weight,
    )
  }
}

///|
/// Graphviz parity: virtual-edge segment constraints are emitted in ND_nlist
/// tail order before unseen tails, preserving stable simplex insertion.
fn add_segments_in_tail_order(input : SegmentsInTailOrderInput) -> Unit {
  let tail_seen : Map[String, Bool] = Map::new()
  for tail_name in input.nlist_order {
    let segments = input.segments_by_tail.get(tail_name).unwrap_or_default()
    add_segment_slack_edges(
      input.graph,
      input.index,
      segments,
      input.segment_minlen,
    )
    tail_seen[tail_name] = true
  }
  for tail_name, segments in input.segments_by_tail {
    if tail_seen.get(tail_name) is None {
      add_segment_slack_edges(
        input.graph,
        input.index,
        segments,
        input.segment_minlen,
      )
    }
  }
}

///|
pub(all) struct ConstraintSegmentPassInput {
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  ranks : Map[String, Int]
  cluster_keys : Map[String, String]
  edge_vnodes : Map[String, Array[String]]
  order_in_rank : Map[String, Int]
  nodesep_pt : Double
  sizes : Map[String, @node_primitives.NodeSize]
  skip_intercluster : Bool
  rank_adj_constraints : Map[String, ConstraintEdge]
  edge_has_mid_label : (@cgraph.Edge) -> Bool
  edge_degree_increment : (@cgraph.Edge) -> Int
}

///|
pub(all) struct ConstraintSegmentPassOutput {
  segments_by_tail : Map[String, Array[SlackSegment]]
  flat_minlen_constraints : Map[String, ConstraintEdge]
}

///|
fn choose_flat_constraint_endpoints(
  tail_name : String,
  head_name : String,
  order_in_rank : Map[String, Int],
) -> (String, String) {
  match (order_in_rank.get(tail_name), order_in_rank.get(head_name)) {
    (Some(tail_order), Some(head_order)) =>
      if tail_order <= head_order {
        (tail_name, head_name)
      } else {
        (head_name, tail_name)
      }
    _ =>
      if tail_name <= head_name {
        (tail_name, head_name)
      } else {
        (head_name, tail_name)
      }
  }
}

///|
fn ordered_vnodes_for_ranks(
  vnodes : Array[String],
  tail_rank : Int,
  head_rank : Int,
) -> Array[String] {
  if tail_rank <= head_rank {
    return vnodes
  }
  let reversed : Array[String] = []
  let mut idx = vnodes.length()
  while idx > 0 {
    idx = idx - 1
    reversed.push(vnodes[idx])
  }
  reversed
}

///|
fn build_node_degrees(
  edges : Array[@cgraph.Edge],
  edge_degree_increment : (@cgraph.Edge) -> Int,
) -> Map[String, Int] {
  let node_degrees : Map[String, Int] = Map::new()
  for edge in edges {
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let inc = edge_degree_increment(edge)
    let tail_degree = node_degrees.get(tail_name).unwrap_or_default()
    node_degrees[tail_name] = tail_degree + inc
    let head_degree = node_degrees.get(head_name).unwrap_or_default()
    node_degrees[head_name] = head_degree + inc
  }
  node_degrees
}

///|
fn node_side_pt(
  name : String,
  sizes : Map[String, @node_primitives.NodeSize],
  use_left : Bool,
) -> Double {
  match sizes.get(name) {
    Some(value) => if use_left { value.left_pt } else { value.right_pt }
    None => @node_primitives.default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn same_rank_constraint_minlen(
  edge : @cgraph.Edge,
  left : String,
  right : String,
  nodesep_pt : Double,
  sizes : Map[String, @node_primitives.NodeSize],
  has_ordering : Bool,
) -> Int {
  let width = node_side_pt(left, sizes, false) +
    node_side_pt(right, sizes, true)
  let mut minlen_value = Double::from_int(@edge_semantics.edge_minlen(edge)) *
    nodesep_pt +
    width
  let is_invis = match edge.get_attr("style") {
    Some(style) => style.to_lower().contains("invis")
    None => false
  }
  if is_invis && has_ordering {
    minlen_value = minlen_value + nodesep_pt
  }
  @numeric.trunc_int(minlen_value)
}

///|
/// Graphviz parity: build make_edge_pairs-style segment constraints in
/// ND_out/ND_nlist order, including reverse-merge handling and same-rank flats.
fn build_constraint_segment_pass(
  input : ConstraintSegmentPassInput,
) -> ConstraintSegmentPassOutput {
  let node_degrees = build_node_degrees(
    input.edges,
    input.edge_degree_increment,
  )
  let reverse_merge_metadata = build_reverse_merge_metadata({
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_excluded_from_reverse_merge: edge => {
      (input.edge_has_mid_label)(edge) || @edge_semantics.edge_is_self(edge)
    },
  })
  let merged_edge_weight_bonus = reverse_merge_metadata.merged_edge_weight_bonus
  let merged_edge_skip = reverse_merge_metadata.merged_edge_skip
  let segments_by_tail : Map[String, Array[SlackSegment]] = Map::new()
  let flat_minlen_constraints : Map[String, ConstraintEdge] = Map::new()
  for_each_edge_index_in_tail_order(
    input.edges,
    input.edge_out_order,
    input.nlist_order,
    edge_idx => {
      if merged_edge_skip.get(edge_idx) is Some(_) {
        return ()
      }
      let edge = input.edges[edge_idx]
      let (tail_name, head_name) = @order_graph.edge_endpoints_at(
        edge,
        edge_idx,
        input.edge_tail,
        input.edge_head,
      )
      let tail_cluster = input.cluster_keys.get(tail_name).unwrap_or_default()
      let head_cluster = input.cluster_keys.get(head_name).unwrap_or_default()
      if input.skip_intercluster &&
        tail_cluster != head_cluster &&
        (tail_cluster != "" || head_cluster != "") {
        return ()
      }
      match (input.ranks.get(tail_name), input.ranks.get(head_name)) {
        (Some(tail_rank), Some(head_rank)) =>
          if tail_name == head_name {
            // Graphviz parity: make_edge_pairs skips self-edges (handled via ND_other).
            ()
          } else {
            let weight_bonus = merged_edge_weight_bonus
              .get(edge_idx)
              .unwrap_or_default()
            let has_ordering = edge_tail_ordering_is_out_or_in(edge)
            let has_mid_label = (input.edge_has_mid_label)(edge)
            if tail_rank == head_rank &&
              @edge_semantics.edge_is_constraint(edge) &&
              !has_mid_label {
              let (left, right) = choose_flat_constraint_endpoints(
                tail_name,
                head_name,
                input.order_in_rank,
              )
              let minlen = same_rank_constraint_minlen(
                edge,
                left,
                right,
                input.nodesep_pt,
                input.sizes,
                has_ordering,
              )
              let weight = @edge_semantics.edge_weight(edge)
              let flat_key = "\{left}|\{right}"
              if input.rank_adj_constraints.get(flat_key) is Some(_) {
                upsert_constraint_with_max(
                  input.rank_adj_constraints,
                  flat_key,
                  left,
                  right,
                  minlen,
                  weight,
                )
              } else {
                upsert_constraint_with_max(
                  flat_minlen_constraints, flat_key, left, right, minlen, weight,
                )
              }
            } else {
              let vnodes = input.edge_vnodes
                .get(@edge_identity.edge_vnode_key(edge))
                .unwrap_or_default()
              let ordered_vnodes = ordered_vnodes_for_ranks(
                vnodes, tail_rank, head_rank,
              )
              let chain : Array[String] = []
              chain.push(tail_name)
              for vnode in ordered_vnodes {
                chain.push(vnode)
              }
              if tail_name != head_name || ordered_vnodes.length() == 0 {
                chain.push(head_name)
              }
              let base_weight = @edge_semantics.edge_weight(edge)
              let orig_tail = edge.tail().name()
              let mut chain_idx = 0
              while chain_idx + 1 < chain.length() {
                let seg_tail = chain[chain_idx]
                let seg_head = chain[chain_idx + 1]
                chain_idx = chain_idx + 1
                let seg_base_weight = if @edge_identity.is_edge_vnode_name(
                    seg_tail,
                  ) ||
                  @edge_identity.is_edge_vnode_name(seg_head) {
                  scaled_segment_edge_weight(
                    base_weight, seg_tail, seg_head, node_degrees,
                  )
                } else {
                  base_weight
                }
                let weight = seg_base_weight + weight_bonus
                let mut tail_port = @order_graph.edge_tail_port_for_name(
                  edge,
                  seg_tail,
                  fallback_to_original=false,
                )
                let mut head_port = @order_graph.edge_head_port_for_name(
                  edge,
                  seg_head,
                  fallback_to_original=false,
                )
                if tail_rank == head_rank &&
                  has_mid_label &&
                  !@edge_identity.port_is_explicit(edge.tail_port()) &&
                  !@edge_identity.port_is_explicit(edge.head_port()) &&
                  has_ordering &&
                  seg_tail == orig_tail &&
                  @edge_identity.is_edge_vnode_name(seg_head) {
                  let forward = match
                    (
                      input.order_in_rank.get(seg_tail),
                      input.order_in_rank.get(seg_head),
                    ) {
                    (Some(tail_order), Some(head_order)) =>
                      tail_order <= head_order
                    _ => seg_tail <= seg_head
                  }
                  if forward {
                    tail_port = Some({
                      name: None,
                      compass: Some(@cgraph.Compass::E),
                    })
                    head_port = Some({
                      name: None,
                      compass: Some(@cgraph.Compass::W),
                    })
                  } else {
                    tail_port = Some({
                      name: None,
                      compass: Some(@cgraph.Compass::W),
                    })
                    head_port = Some({
                      name: None,
                      compass: Some(@cgraph.Compass::E),
                    })
                  }
                }
                push_slack_segment(
                  segments_by_tail, seg_tail, seg_head, weight, tail_port, head_port,
                )
              }
            }
          }
        _ => ()
      }
    },
  )
  { segments_by_tail, flat_minlen_constraints }
}

///|
/// Graphviz parity: when root boundary slack nodes are enabled (compress mode),
/// each non-empty rank contributes its leftmost/rightmost node once.
fn append_missing_rank_boundary_targets(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  root_ln_targets : Array[String],
  root_rn_targets : Array[String],
) -> Unit {
  let ln_seen : Map[String, Bool] = Map::new()
  let rn_seen : Map[String, Bool] = Map::new()
  for name in root_ln_targets {
    ln_seen[name] = true
  }
  for name in root_rn_targets {
    rn_seen[name] = true
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(value) => value
      None => []
    }
    if names.length() == 0 {
      continue
    }
    let left_name = names[0]
    let right_name = names[names.length() - 1]
    if ln_seen.get(left_name) is None {
      root_ln_targets.push(left_name)
      ln_seen[left_name] = true
    }
    if rn_seen.get(right_name) is None {
      root_rn_targets.push(right_name)
      rn_seen[right_name] = true
    }
  }
}

///|
priv struct RootBoundaryTargetEdgesInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  target_names : Array[String]
  root_idx : Int
  sizes : Map[String, @node_primitives.NodeSize]
  root_margin : Double
  compress_mode : Bool
  is_left_boundary : Bool
}

///|
fn add_root_boundary_target_edges(input : RootBoundaryTargetEdgesInput) -> Unit {
  let base_minlen = @numeric.round_int(input.root_margin)
  for name in input.target_names {
    match input.index.get(name) {
      Some(idx) => {
        let minlen = if input.compress_mode {
          if input.is_left_boundary {
            @numeric.round_int(
              @node_primitives.node_left_pt(name, input.sizes) +
              input.root_margin,
            )
          } else {
            @numeric.round_int(
              @node_primitives.node_right_pt(name, input.sizes) +
              input.root_margin,
            )
          }
        } else {
          base_minlen
        }
        if input.is_left_boundary {
          let _ = @network_simplex.add_edge(
            input.graph,
            input.root_idx,
            idx,
            minlen,
            0,
          )
        } else {
          let _ = @network_simplex.add_edge(
            input.graph,
            idx,
            input.root_idx,
            minlen,
            0,
          )
        }
      }
      None => ()
    }
  }
}

///|
/// Graphviz parity: root boundary constraints add synthetic ln/rn slack nodes
/// and optional compress-width edge before simplex solve.
priv struct RootBoundaryConstraintsInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
  sizes : Map[String, @node_primitives.NodeSize]
  root_margin : Double
  compress_width_minlen : Int?
  root_compress_weight : Int
}

///|
/// Graphviz parity: root boundary links mirror contain_nodes/create_aux_edges
/// order and include the optional compress edge when size=... is active.
fn add_root_boundary_constraints(input : RootBoundaryConstraintsInput) -> Unit {
  if input.root_ln_targets.length() == 0 && input.root_rn_targets.length() == 0 {
    return ()
  }
  let root_ln = @network_simplex.add_node(
    input.graph,
    "",
    kind=@network_simplex.NodeKind::Slack,
  )
  let root_rn = @network_simplex.add_node(
    input.graph,
    "",
    kind=@network_simplex.NodeKind::Slack,
  )
  @network_simplex.set_node_rank(input.graph, root_ln, 0)
  @network_simplex.set_node_rank(input.graph, root_rn, 0)
  let compress_mode = input.compress_width_minlen is Some(_)
  add_root_boundary_target_edges({
    graph: input.graph,
    index: input.index,
    target_names: input.root_ln_targets,
    root_idx: root_ln,
    sizes: input.sizes,
    root_margin: input.root_margin,
    compress_mode,
    is_left_boundary: true,
  })
  add_root_boundary_target_edges({
    graph: input.graph,
    index: input.index,
    target_names: input.root_rn_targets,
    root_idx: root_rn,
    sizes: input.sizes,
    root_margin: input.root_margin,
    compress_mode,
    is_left_boundary: false,
  })
  match input.compress_width_minlen {
    Some(width_minlen) => {
      let _ = @network_simplex.add_edge(
        input.graph,
        root_ln,
        root_rn,
        width_minlen,
        input.root_compress_weight,
      )
    }
    None => ()
  }
}

///|
pub(all) struct ConstraintGraphBuildInput {
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
  segment_minlen : (SlackSegment, Map[String, @cgraph.Node]) -> (Int, Int)
  edge_has_mid_label : (@cgraph.Edge) -> Bool
  edge_degree_increment : (@cgraph.Edge) -> Int
  root_margin : Double
  root_compress_weight : Int
}

///|
pub(all) struct ConstraintGraphBuildOutput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
}

///|
/// Graphviz parity: constraint graph uses GD_nlist order for existing
/// nodes and appends aux slack/cluster nodes per create_aux_edges.
/// Do not change behavior without updating fixtures/tests.
fn build_constraint_graph(
  input : ConstraintGraphBuildInput,
) -> ConstraintGraphBuildOutput {
  let graph = @network_simplex.new_graph()
  let skip_intercluster = @sys.get_env_var("DOT_SKIP_INTERCLUSTER_XPOS")
    is Some(_)
  let base_positions = compute_rank_positions(
    input.rank_keys,
    input.groups,
    input.sizes,
    input.nodesep_pt,
    input.has_edge_labels,
  )
  let node_setup = build_constraint_nodes_setup({
    graph,
    nodes: input.nodes,
    extra_nodes: input.extra_nodes,
    nlist_order: input.nlist_order,
    base_positions,
  })
  let index = node_setup.index
  let rank_constraint_seed = build_rank_constraint_seed(
    input.rank_keys,
    input.groups,
    input.sizes,
    input.nodesep_pt,
    input.has_edge_labels,
  )
  let rank_adj_constraints = rank_constraint_seed.rank_adj_constraints
  let rank_adj_order = rank_constraint_seed.rank_adj_order
  let segment_pass = build_constraint_segment_pass({
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_out_order: input.edge_out_order,
    nlist_order: input.nlist_order,
    ranks: input.ranks,
    cluster_keys: input.cluster_keys,
    edge_vnodes: input.edge_vnodes,
    order_in_rank: rank_constraint_seed.order_in_rank,
    nodesep_pt: input.nodesep_pt,
    sizes: input.sizes,
    skip_intercluster,
    rank_adj_constraints,
    edge_has_mid_label: input.edge_has_mid_label,
    edge_degree_increment: input.edge_degree_increment,
  })
  for key in rank_adj_order {
    match rank_adj_constraints.get(key) {
      Some(entry) => add_constraint_edge_if_present(graph, index, entry)
      None => ()
    }
  }
  for _flat_key, entry in segment_pass.flat_minlen_constraints {
    add_constraint_edge_if_present(graph, index, entry)
  }
  add_segments_in_tail_order({
    graph,
    index,
    segments_by_tail: segment_pass.segments_by_tail,
    nlist_order: input.nlist_order,
    segment_minlen: segment => {
      (input.segment_minlen)(segment, node_setup.real_by_name)
    },
  })
  append_late_constraint_nodes({
    graph,
    index,
    late_extra_nodes: node_setup.late_extra_nodes,
  })
  add_root_boundary_constraints({
    graph,
    index,
    root_ln_targets: input.root_ln_targets,
    root_rn_targets: input.root_rn_targets,
    sizes: input.sizes,
    root_margin: input.root_margin,
    compress_width_minlen: input.compress_width_minlen,
    root_compress_weight: input.root_compress_weight,
  })
  for edge in input.extra_edges {
    let _ = edge.tail_port
    let _ = edge.head_port
    add_constraint_edge_if_present(graph, index, edge)
  }
  { graph, index }
}
