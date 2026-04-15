// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
priv struct PortLabelPosRemapInput {
  edge : @cgraph.Edge
  splines : Array[@geom.Spline]
  label_attr : String
  is_head : Bool
  fallback : @geom.Point?
  edge_port_label_pos_fn : EdgePortLabelPosFn
}

///|
fn remap_port_label_pos(input : PortLabelPosRemapInput) -> @geom.Point? {
  let edge = input.edge
  let splines = input.splines
  let label_attr = input.label_attr
  let is_head = input.is_head
  let fallback = input.fallback
  let edge_port_label_pos_fn = input.edge_port_label_pos_fn
  if !@edge_semantics.edge_attr_non_empty(edge, label_attr) {
    return None
  }
  if splines.length() == 0 {
    return fallback
  }
  let spline = if is_head { splines[splines.length() - 1] } else { splines[0] }
  match edge_port_label_pos_fn({ edge, spline, is_head }) {
    Some(pos) => Some(pos)
    None => fallback
  }
}

///|
/// Graphviz parity: routed edge output stays in original edge iteration order.
/// Do not change behavior without updating fixtures/tests.
fn collect_input_order_edge_ids(
  edges : Array[@cgraph.Edge],
  has_layout : (Int) -> Bool,
) -> Array[Int] {
  let ordered_ids : Array[Int] = []
  for edge in edges {
    let edge_id = edge.id()
    if has_layout(edge_id) {
      ordered_ids.push(edge_id)
    }
  }
  ordered_ids
}

///|
fn remap_edge_layout_edge(
  edge : @cgraph.Edge,
  layout : DotLayoutEdge,
  edge_port_label_pos_fn : EdgePortLabelPosFn,
) -> DotLayoutEdge {
  let label_pos = if @edge_semantics.edge_attr_non_empty(edge, "label") {
    layout.label_pos
  } else {
    None
  }
  let head_label_pos = remap_port_label_pos({
    edge,
    splines: layout.splines,
    label_attr: "headlabel",
    is_head: true,
    fallback: layout.head_label_pos,
    edge_port_label_pos_fn,
  })
  let tail_label_pos = remap_port_label_pos({
    edge,
    splines: layout.splines,
    label_attr: "taillabel",
    is_head: false,
    fallback: layout.tail_label_pos,
    edge_port_label_pos_fn,
  })
  let xlabel_pos = if @edge_semantics.edge_attr_non_empty(edge, "xlabel") {
    layout.xlabel_pos
  } else {
    None
  }
  {
    edge,
    splines: layout.splines,
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}

///|
/// Graphviz parity: final routed edge output keeps remap-then-input-order flow.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct FinalizeRoutedEdgesInput {
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  edges_out_by_id : Map[Int, DotLayoutEdge]
  edge_port_label_pos_fn : EdgePortLabelPosFn
}

///|
fn finalize_routed_edges(
  input : FinalizeRoutedEdgesInput,
) -> Array[DotLayoutEdge] {
  let edges = input.edges
  let ranks = input.ranks
  let edges_out_by_id = input.edges_out_by_id
  remap_parallel_edge_layouts({
    edges,
    ranks,
    edges_out_by_id,
    edge_port_label_pos_fn: input.edge_port_label_pos_fn,
  })
  let ordered_output_edge_ids = collect_input_order_edge_ids(edges, edge_id => {
    edges_out_by_id.get(edge_id) is Some(_)
  })
  let edges_out : Array[DotLayoutEdge] = []
  for edge_id in ordered_output_edge_ids {
    match edges_out_by_id.get(edge_id) {
      Some(value) => edges_out.push(value)
      None => ()
    }
  }
  edges_out
}
