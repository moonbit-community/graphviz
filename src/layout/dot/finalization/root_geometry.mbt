// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Root-graph geometry kernels: cluster padding, root label bbox
/// placement, and root margin expansion. These helpers do not mutate
/// DotLayoutGraph trees directly.
type LabelLoc = @graph_label.LabelLoc

///|
type LabelJust = @graph_label.LabelJust

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
pub struct RootClusterPadding {
  root_cluster_pad_top : Double
  root_cluster_pad_bottom : Double
}

///|
/// Computes only the extra vertical space required by outer cluster bounds.
/// position.c clust_ht takes a maximum with existing node extents; it does
/// not add a margin to every rank containing a cluster member.
pub fn compute_root_cluster_padding(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  subgraphs : Array[LayoutTree],
) -> RootClusterPadding {
  guard graph.is_root() else {
    return { root_cluster_pad_top: 0.0, root_cluster_pad_bottom: 0.0, }
  }
  let pending = subgraphs.copy()
  let mut top = 0.0
  let mut bottom = 0.0
  while pending.length() > 0 {
    guard pending.pop() is Some(subgraph) else { break }
    if @cluster_graph.is_cluster_graph(subgraph.graph) {
      top = Double::max(
        top,
        subgraph.bbox.ury + @clustering.CLUSTER_MARGIN_PT - bbox.ury,
      )
      bottom = Double::max(
        bottom,
        bbox.lly - subgraph.bbox.lly + @clustering.CLUSTER_MARGIN_PT,
      )
    } else {
      for child in subgraph.subgraphs {
        pending.push(child)
      }
    }
  }
  { root_cluster_pad_top: top, root_cluster_pad_bottom: bottom, }
}

///|
fn root_graph_label_metrics(
  graph : @cgraph.Graph,
) -> @graph_label.GraphLabelMetrics? {
  @graph_label.graph_label_metrics_with(
    graph, @label_metrics.label_text_dimensions,
  )
}

///|
/// Root-label bbox and margin helpers used by final postprocess.

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
fn expand_root_bbox_for_label(
  bbox : @geom.Rect,
  padded_width : Double,
  padded_height : Double,
  loc : LabelLoc,
  rankdir : RankDir,
) -> @geom.Rect {
  let mut llx = bbox.llx
  let mut lly = bbox.lly
  let mut urx = bbox.urx
  let mut ury = bbox.ury
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    match loc {
      LabelLoc::Top => urx = urx + padded_height
      LabelLoc::Bottom => llx = llx - padded_height
    }
    let span = ury - lly
    if padded_width > span {
      let diff = (padded_width - span) / 2.0
      lly = lly - diff
      ury = ury + diff
    }
  } else {
    match loc {
      LabelLoc::Top =>
        if rankdir == RankDir::TB {
          ury = ury + padded_height
        } else {
          lly = lly - padded_height
        }
      LabelLoc::Bottom =>
        if rankdir == RankDir::TB {
          lly = lly - padded_height
        } else {
          ury = ury + padded_height
        }
    }
    let span = urx - llx
    if padded_width > span {
      let diff = (padded_width - span) / 2.0
      llx = llx - diff
      urx = urx + diff
    }
  }
  { llx, lly, urx, ury, }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
pub struct RootLabelBBoxOutput {
  bbox : @geom.Rect
  label_pos : @geom.Point?
}

///|
priv struct RootLabelPlacementSpec {
  padded_width : Double
  padded_height : Double
  loc : LabelLoc
  just : LabelJust
}

///|
/// Graphviz parity: root-label placement spec reads graph label metrics + attrs
/// once per call path before bbox/position emission.
fn root_label_placement_spec(graph : @cgraph.Graph) -> RootLabelPlacementSpec? {
  if !graph.is_root() {
    return None
  }
  match root_graph_label_metrics(graph) {
    Some(metrics) => {
      let pad = @cluster_geometry.CLUSTER_LABEL_PAD_PT
      Some({
        padded_width: metrics.width_pt + pad * 2.0,
        padded_height: metrics.height_pt + pad,
        loc: @graph_label.graph_label_loc(graph),
        just: @graph_label.graph_label_just(graph),
      })
    }
    None => None
  }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
pub fn apply_root_label_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> RootLabelBBoxOutput {
  let mut bbox = bbox
  let mut label_pos : @geom.Point? = None
  match root_label_placement_spec(graph) {
    Some(spec) => {
      bbox = expand_root_bbox_for_label(
        bbox,
        spec.padded_width,
        spec.padded_height,
        spec.loc,
        rankdir,
      )
      label_pos = Some(
        @graph_label.graph_label_pos(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          spec.just,
        ),
      )
    }
    None => ()
  }
  { bbox, label_pos, }
}

///|
/// Graphviz parity: root label placement aligned to refs/graphviz/lib/common/postproc.c
/// (place_root_label).
/// Do not change behavior without updating fixtures/tests.
pub fn root_label_pos_for_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Point? {
  match root_label_placement_spec(graph) {
    Some(spec) =>
      Some(
        @graph_label.graph_label_pos(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          spec.just,
        ),
      )
    None => None
  }
}

///|
/// Graphviz parity: root graph margin aligned to refs/graphviz/lib/common/input.c + dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_root_margin_x(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Rect {
  if graph.is_root() {
    let margin_x = if @cluster_graph.graph_has_cluster(graph) {
      @label_attrs.graph_margin_x_pt(graph)
    } else {
      0.0
    }
    if margin_x > 0.0 {
      {
        llx: bbox.llx - margin_x,
        lly: bbox.lly,
        urx: bbox.urx + margin_x,
        ury: bbox.ury,
      }
    } else {
      bbox
    }
  } else {
    bbox
  }
}
