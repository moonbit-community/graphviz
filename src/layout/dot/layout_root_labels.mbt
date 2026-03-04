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
  { llx, lly, urx, ury }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
priv struct RootLabelBBoxOutput {
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
fn root_label_placement_spec(
  graph : @cgraph.Graph,
) -> RootLabelPlacementSpec? {
  if !graph.is_root() {
    return None
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let pad = CLUSTER_LABEL_PAD_PT
      Some({
        padded_width: metrics.width_pt + pad * 2.0,
        padded_height: metrics.height_pt + pad,
        loc: graph_label_loc(graph),
        just: graph_label_just(graph),
      })
    }
    None => None
  }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
fn apply_root_label_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> RootLabelBBoxOutput {
  let mut bbox = bbox
  let mut label_pos : @geom.Point? = None
  match root_label_placement_spec(graph) {
    Some(spec) => {
      bbox =
        expand_root_bbox_for_label(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          rankdir,
        )
      label_pos = Some(
        graph_label_pos(
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
  { bbox, label_pos }
}

///|
/// Graphviz parity: root label placement aligned to refs/graphviz/lib/common/postproc.c
/// (place_root_label).
/// Do not change behavior without updating fixtures/tests.
fn root_label_pos_for_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Point? {
  match root_label_placement_spec(graph) {
    Some(spec) =>
      Some(
        graph_label_pos(
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
fn apply_root_margin_x(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Rect {
  if graph.is_root() {
    let margin_x = if @dot_shared.graph_has_cluster(graph) {
      graph_margin_x_pt(graph)
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
