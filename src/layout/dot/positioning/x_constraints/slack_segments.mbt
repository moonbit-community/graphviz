///|
pub(all) struct SlackSegment {
  tail : String
  head : String
  weight : Int
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
}

///|
pub fn push_slack_segment(
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
pub(all) struct SegmentsInTailOrderInput {
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
  let m0 = if delta > 0.0 { @shared.trunc_int(delta) } else { 0 }
  let m1 = if delta < 0.0 { @shared.trunc_int(-delta) } else { 0 }
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
    let slack_idx = @network_simplex.add_node(graph, "", kind=@network_simplex.NodeKind::Slack)
    let tail_rank = @network_simplex.node_rank(graph, tail_idx)
    let head_rank = @network_simplex.node_rank(graph, head_idx)
    let base_tail = tail_rank - m0 - 1
    let base_head = head_rank - m1 - 1
    @network_simplex.set_node_rank(
      graph,
      slack_idx,
      if base_tail < base_head { base_tail } else { base_head },
    )
    let _ = @network_simplex.add_edge(graph, slack_idx, tail_idx, m0 + 1, seg.weight)
    let _ = @network_simplex.add_edge(graph, slack_idx, head_idx, m1 + 1, seg.weight)
  }
}

///|
/// Graphviz parity: virtual-edge segment constraints are emitted in ND_nlist
/// tail order before unseen tails, preserving stable simplex insertion.
pub fn add_segments_in_tail_order(input : SegmentsInTailOrderInput) -> Unit {
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
