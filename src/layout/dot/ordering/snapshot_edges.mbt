///|
/// Ordering domain: edge snapshot projections for ordering fixture capture.

///|
/// Graphviz parity: ordering edge snapshot input keeps edge arrays plus
/// optional port metadata aligned by edge index before projection/coalescing.
pub(all) struct OrderingEdgeSnapshotBuildInput {
  edges_out : Array[@cgraph.Edge]
  edge_tail_out : Array[String]
  edge_head_out : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  edge_xpenalty_for : (@cgraph.Edge) -> Int
}

///|
/// Graphviz parity: ordering edge snapshot entry keeps coalescing keys and
/// edge-port metrics grouped for fixture-stable projection order.
pub(all) struct OrderingEdgeSnapshotEntry {
  tail : String
  head : String
  xpenalty : Int
  tail_port_x : Double
  head_port_x : Double
  tail_port_order : Double
  head_port_order : Double
}

///|
/// Graphviz parity: snapshot edge projection keeps raw edge arrays and optional
/// port metadata aligned by index before coalescing/materialization.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_edge_snapshot_entries(
  input : OrderingEdgeSnapshotBuildInput,
) -> Array[OrderingEdgeSnapshotEntry] {
  let entries : Array[OrderingEdgeSnapshotEntry] = []
  let mut idx = 0
  while idx < input.edges_out.length() {
    let tail = input.edge_tail_out[idx]
    let head = input.edge_head_out[idx]
    let tail_port_x =
      if idx < input.edge_tail_port_x.length() { input.edge_tail_port_x[idx] } else { 0.0 }
    let head_port_x =
      if idx < input.edge_head_port_x.length() { input.edge_head_port_x[idx] } else { 0.0 }
    let tail_port_order =
      if idx < input.edge_tail_port_order.length() {
        input.edge_tail_port_order[idx]
      } else {
        0.0
      }
    let head_port_order =
      if idx < input.edge_head_port_order.length() {
        input.edge_head_port_order[idx]
      } else {
        0.0
      }
    entries.push({
      tail,
      head,
      xpenalty: (input.edge_xpenalty_for)(input.edges_out[idx]),
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
    })
    idx = idx + 1
  }
  entries
}

///|
/// Graphviz parity: ordering edge snapshot coalescing preserves first-tail
/// traversal order while applying Graphviz-aligned duplicate-edge coalescing.
/// Do not change behavior without updating fixtures/tests.
pub fn coalesce_ordering_edge_snapshot_entries(
  entries : Array[OrderingEdgeSnapshotEntry],
) -> Array[OrderingEdgeSnapshotEntry] {
  let entries_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  let tail_order : Array[String] = []
  for entry in entries {
    let tail = entry.tail
    if entries_by_tail.get(tail) is None {
      entries_by_tail[tail] = []
      tail_order.push(tail)
    }
    match entries_by_tail.get(tail) {
      Some(list) =>
        list.push(
          (
            entry.tail,
            entry.head,
            entry.xpenalty,
            true,
            entry.tail_port_x,
            entry.head_port_x,
            entry.tail_port_order,
            entry.head_port_order,
          ),
        )
      None => ()
    }
  }
  let coalesced_by_tail = coalesce_order_edges_by_tail(entries_by_tail)
  let coalesced : Array[OrderingEdgeSnapshotEntry] = []
  for tail in tail_order {
    let tail_entries = coalesced_by_tail.get(tail).unwrap_or_default()
    for item in tail_entries {
      let (tail_name, head_name, xpenalty, _constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
        item
      coalesced.push({
        tail: tail_name,
        head: head_name,
        xpenalty,
        tail_port_x,
        head_port_x,
        tail_port_order,
        head_port_order,
      })
    }
  }
  coalesced
}
