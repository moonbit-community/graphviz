// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Root-coordinate finalization helpers: ratio scaling, root padding, origin
/// normalization, and root-label refresh after final layout transforms.

///|
/// Final-layout ratio=fill scaling and root-coordinate frame helpers used by
/// postprocess.

///|
fn scale_layout_tree(
  layout : LayoutTree,
  sx : Double,
  sy : Double,
  round_node_pos : Bool,
) -> LayoutTree {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let scaled_pos = if round_node_pos {
      @scale_geometry.scale_point_rounded(node_layout.pos, sx, sy)
    } else {
      @scale_geometry.scale_point(node_layout.pos, sx, sy)
    }
    nodes.push({
      node: node_layout.node,
      pos: scaled_pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: @scale_geometry.scale_optional_point(
        node_layout.label_pos,
        sx,
        sy,
      ),
      xlabel_pos: @scale_geometry.scale_optional_point(
        node_layout.xlabel_pos,
        sx,
        sy,
      ),
    })
  }
  let subgraphs : Array[LayoutTree] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(scale_layout_tree(subgraph, sx, sy, round_node_pos))
  }
  {
    graph: layout.graph,
    bbox: {
      llx: layout.bbox.llx * sx,
      lly: layout.bbox.lly * sy,
      urx: layout.bbox.urx * sx,
      ury: layout.bbox.ury * sy,
    },
    label_pos: @scale_geometry.scale_optional_point(layout.label_pos, sx, sy),
    nodes,
    edges: @scale_geometry.scale_edge_layout_output(layout.edges, sx, sy),
    subgraphs,
  }
}

///|
/// Graphviz parity: root-cluster padding input keeps the pre-padding layout and
/// top/bottom pad deltas grouped for one shift + bbox rebuild boundary.
priv struct RootClusterPaddingApplyInput {
  layout : LayoutTree
  root_cluster_pad_top : Double
  root_cluster_pad_bottom : Double
}

///|
/// Graphviz parity: translate to origin aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn shift_layout_to_origin(layout : LayoutTree) -> LayoutTree {
  if layout.graph.is_root() {
    let dx = -layout.bbox.llx
    let dy = -layout.bbox.lly
    if dx != 0.0 || dy != 0.0 {
      shift_layout_graph(layout, dx, dy)
    } else {
      layout
    }
  } else {
    layout
  }
}

///|
fn refresh_root_label_position(layout : LayoutTree) -> LayoutTree {
  if layout.graph.is_root() {
    let label_pos = match root_label_pos_for_bbox(layout.graph, layout.bbox) {
      Some(pos) => Some(pos)
      None => layout.label_pos
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    }
  } else {
    layout
  }
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn apply_root_cluster_padding(
  input : RootClusterPaddingApplyInput,
) -> LayoutTree {
  let layout = input.layout
  if layout.graph.is_root() &&
    (input.root_cluster_pad_top > 0.0 || input.root_cluster_pad_bottom > 0.0) {
    let padded = shift_layout_graph(layout, 0.0, input.root_cluster_pad_bottom)
    let padded_bbox : @geom.Rect = {
      llx: layout.bbox.llx,
      lly: layout.bbox.lly,
      urx: layout.bbox.urx,
      ury: layout.bbox.ury +
      input.root_cluster_pad_bottom +
      input.root_cluster_pad_top,
    }
    let label_pos = match root_label_pos_for_bbox(layout.graph, padded_bbox) {
      Some(pos) => Some(pos)
      None => padded.label_pos
    }
    {
      graph: padded.graph,
      bbox: padded_bbox,
      label_pos,
      nodes: padded.nodes,
      edges: padded.edges,
      subgraphs: padded.subgraphs,
    }
  } else {
    layout
  }
}

///|
/// Graphviz parity: root ratio=fill scaling aligned to refs/graphviz/lib/dotgen/position.c
/// (set_aspect R_FILL branch + ND_coord rounding).
fn apply_ratio_fill_scale(
  layout : LayoutTree,
  rankdir : RankDir,
  ratio_bbox : @geom.Rect,
) -> LayoutTree {
  if !layout.graph.is_root() {
    return layout
  }
  match
    @scale_geometry.ratio_fill_scale_factors(layout.graph, ratio_bbox, rankdir) {
    Some(scale_factors) =>
      if scale_factors.sx == 1.0 && scale_factors.sy == 1.0 {
        layout
      } else {
        // Graphviz parity: set_aspect rounds ND_coord after scaling.
        scale_layout_tree(layout, scale_factors.sx, scale_factors.sy, true)
      }
    None => layout
  }
}

///|
/// Graphviz parity: final root-coordinate frame applies margin, then origin
/// translation, then root label refresh.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_coordinates(layout : LayoutTree) -> LayoutTree {
  let with_margin : LayoutTree = {
    graph: layout.graph,
    bbox: apply_root_margin_x(layout.graph, layout.bbox),
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs: layout.subgraphs,
  }
  refresh_root_label_position(shift_layout_to_origin(with_margin))
}
