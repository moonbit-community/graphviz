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
  sizes : Map[String, @shared.NodeSize]
  skip_intercluster : Bool
  rank_adj_constraints : Map[String, ConstraintEdge]
  edge_has_mid_label : (@cgraph.Edge) -> Bool
  edge_degree_increment : (@cgraph.Edge) -> Int
  trunc_int : (Double) -> Int
}

///|
pub(all) struct ConstraintSegmentPassOutput {
  segments_by_tail : Map[String, Array[SlackSegment]]
  flat_minlen_constraints : Map[String, ConstraintEdge]
}

///|
fn is_edge_vnode_name(name : String) -> Bool {
  name.has_prefix(@shared.EDGE_VNODE_PREFIX)
}

///|
fn is_self_edge(edge : @cgraph.Edge) -> Bool {
  edge.tail().name() == edge.head().name()
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
  sizes : Map[String, @shared.NodeSize],
  use_left : Bool,
) -> Double {
  match sizes.get(name) {
    Some(value) => if use_left { value.left_pt } else { value.right_pt }
    None => @shared.default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn same_rank_constraint_minlen(
  edge : @cgraph.Edge,
  left : String,
  right : String,
  nodesep_pt : Double,
  sizes : Map[String, @shared.NodeSize],
  has_ordering : Bool,
  trunc_int : (Double) -> Int,
) -> Int {
  let width = node_side_pt(left, sizes, false) + node_side_pt(right, sizes, true)
  let mut minlen_value =
    Double::from_int(@shared.edge_minlen(edge)) * nodesep_pt + width
  let is_invis = match edge.get_attr("style") {
    Some(style) => style.to_lower().contains("invis")
    None => false
  }
  if is_invis && has_ordering {
    minlen_value = minlen_value + nodesep_pt
  }
  trunc_int(minlen_value)
}

///|
/// Graphviz parity: build make_edge_pairs-style segment constraints in
/// ND_out/ND_nlist order, including reverse-merge handling and same-rank flats.
pub fn build_constraint_segment_pass(
  input : ConstraintSegmentPassInput,
) -> ConstraintSegmentPassOutput {
  let node_degrees =
    build_node_degrees(input.edges, input.edge_degree_increment)
  let reverse_merge_metadata =
    build_reverse_merge_metadata(
      {
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        edge_excluded_from_reverse_merge:
          edge => (input.edge_has_mid_label)(edge) || is_self_edge(edge),
      },
    )
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
      let (tail_name, head_name) =
        @ordering.edge_endpoints_at(
          edge,
          edge_idx,
          input.edge_tail,
          input.edge_head,
        )
      let tail_cluster = input.cluster_keys.get(tail_name).unwrap_or_default()
      let head_cluster = input.cluster_keys.get(head_name).unwrap_or_default()
      if input.skip_intercluster && tail_cluster != head_cluster &&
        (tail_cluster != "" || head_cluster != "") {
        return ()
      }
      match (input.ranks.get(tail_name), input.ranks.get(head_name)) {
        (Some(tail_rank), Some(head_rank)) =>
          if tail_name == head_name {
            // Graphviz parity: make_edge_pairs skips self-edges (handled via ND_other).
            ()
          } else {
            let weight_bonus = merged_edge_weight_bonus.get(edge_idx).unwrap_or_default()
            let has_ordering = edge_tail_ordering_is_out_or_in(edge)
            let has_mid_label = (input.edge_has_mid_label)(edge)
            if tail_rank == head_rank &&
              @shared.edge_is_constraint(edge) &&
              !has_mid_label {
              let (left, right) =
                choose_flat_constraint_endpoints(
                  tail_name,
                  head_name,
                  input.order_in_rank,
                )
              let minlen =
                same_rank_constraint_minlen(
                  edge,
                  left,
                  right,
                  input.nodesep_pt,
                  input.sizes,
                  has_ordering,
                  input.trunc_int,
                )
              let weight = @shared.edge_weight(edge)
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
                  flat_minlen_constraints,
                  flat_key,
                  left,
                  right,
                  minlen,
                  weight,
                )
              }
            } else {
              let vnodes =
                input.edge_vnodes.get(@shared.edge_vnode_key(edge)).unwrap_or_default()
              let ordered_vnodes = ordered_vnodes_for_ranks(vnodes, tail_rank, head_rank)
              let chain : Array[String] = []
              chain.push(tail_name)
              for vnode in ordered_vnodes {
                chain.push(vnode)
              }
              if tail_name != head_name || ordered_vnodes.length() == 0 {
                chain.push(head_name)
              }
              let base_weight = @shared.edge_weight(edge)
              let orig_tail = edge.tail().name()
              let mut chain_idx = 0
              while chain_idx + 1 < chain.length() {
                let seg_tail = chain[chain_idx]
                let seg_head = chain[chain_idx + 1]
                chain_idx = chain_idx + 1
                let seg_base_weight =
                  if is_edge_vnode_name(seg_tail) || is_edge_vnode_name(seg_head) {
                    scaled_segment_edge_weight(
                      base_weight,
                      seg_tail,
                      seg_head,
                      node_degrees,
                    )
                  } else {
                    base_weight
                  }
                let weight = seg_base_weight + weight_bonus
                let mut tail_port =
                  @ordering.edge_tail_port_for_name(
                    edge,
                    seg_tail,
                    fallback_to_original=false,
                  )
                let mut head_port =
                  @ordering.edge_head_port_for_name(
                    edge,
                    seg_head,
                    fallback_to_original=false,
                  )
                if tail_rank == head_rank &&
                  has_mid_label &&
                  !@shared.port_is_explicit(edge.tail_port()) &&
                  !@shared.port_is_explicit(edge.head_port()) &&
                  has_ordering &&
                  seg_tail == orig_tail &&
                  is_edge_vnode_name(seg_head) {
                  let forward =
                    match (
                      input.order_in_rank.get(seg_tail),
                      input.order_in_rank.get(seg_head),
                    ) {
                      (Some(tail_order), Some(head_order)) => tail_order <= head_order
                      _ => seg_tail <= seg_head
                    }
                  if forward {
                    tail_port = Some({ name: None, compass: Some(@cgraph.Compass::E) })
                    head_port = Some({ name: None, compass: Some(@cgraph.Compass::W) })
                  } else {
                    tail_port = Some({ name: None, compass: Some(@cgraph.Compass::W) })
                    head_port = Some({ name: None, compass: Some(@cgraph.Compass::E) })
                  }
                }
                push_slack_segment(
                  segments_by_tail,
                  seg_tail,
                  seg_head,
                  weight,
                  tail_port,
                  head_port,
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
