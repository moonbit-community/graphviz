// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Unranked engine public APIs: root-level error mapping plus layout-tree to
/// public-layout bridging for neato/noop entry paths.

///|
pub fn layout_neato(
  text_context~ : @text_layout.Context,
  graph : @cgraph.Graph,
  scale~ : Double = 72.0,
  prune~ : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  @label_layout.reset_label_caches()
  let layout_tree = match
    @unranked_engine.prepare_neato_layout_tree(
      text_context~,
      graph,
      scale,
      prune,
    ) {
    Ok(value) => value
    Err(message) => raise DotLayoutError::InvalidGraph(message~)
  }
  dot_layout_graph_from_layout_tree(text_context~, layout_tree)
}

///|
pub fn layout_neato_noop(
  text_context~ : @text_layout.Context,
  graph : @cgraph.Graph,
  no_op_level~ : Int32 = 1,
  scale~ : Double = 72.0,
  prune~ : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  @label_layout.reset_label_caches()
  let layout_tree = match
    @unranked_engine.prepare_noop_layout_tree(
      text_context~,
      graph,
      no_op_level,
      scale,
      prune,
    ) {
    Ok(value) => value
    Err(message) => raise DotLayoutError::InvalidGraph(message~)
  }
  dot_layout_graph_from_layout_tree(text_context~, layout_tree)
}

///|
pub fn layout_dot_noop(
  text_context~ : @text_layout.Context,
  graph : @cgraph.Graph,
  no_op_level~ : Int32 = 1,
  scale~ : Double = 72.0,
  prune~ : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  layout_neato_noop(text_context~, graph, no_op_level~, scale~, prune~)
}
