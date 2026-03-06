///|
pub(all) enum LabelLoc {
  Top
  Bottom
}

///|
pub(all) enum LabelJust {
  Left
  Center
  Right
}

///|
pub(all) struct GraphLabelMetrics {
  width_pt : Double
  height_pt : Double
}

///|
pub fn parse_label_loc(value : String?, default_loc : LabelLoc) -> LabelLoc {
  match value {
    Some(text) => {
      let lower = text.to_lower()
      match lower {
        "t" | "top" => LabelLoc::Top
        "b" | "bottom" => LabelLoc::Bottom
        _ => default_loc
      }
    }
    None => default_loc
  }
}

///|
pub fn parse_label_just(value : String?) -> LabelJust {
  match value {
    Some(text) => {
      let lower = text.to_lower()
      match lower {
        "l" | "left" => LabelJust::Left
        "r" | "right" => LabelJust::Right
        "c" | "center" => LabelJust::Center
        _ => LabelJust::Center
      }
    }
    None => LabelJust::Center
  }
}

///|
pub fn graph_attr_inherited(
  graph : @cgraph.Graph,
  key : String,
) -> String? {
  let mut current = Some(graph)
  while current is Some(_) {
    match current {
      Some(value) =>
        match value.get_attr(key) {
          Some(found) => return Some(found)
          None => current = value.parent()
        }
      None => ()
    }
  }
  None
}

///|
pub fn graph_label_loc(graph : @cgraph.Graph) -> LabelLoc {
  let default_loc = if graph.is_root() {
    LabelLoc::Bottom
  } else {
    LabelLoc::Top
  }
  parse_label_loc(graph.get_attr("labelloc"), default_loc)
}

///|
pub fn graph_label_just(graph : @cgraph.Graph) -> LabelJust {
  parse_label_just(graph_attr_inherited(graph, "labeljust"))
}

///|
/// Graphviz parity: label text metrics honor inherited graph font attributes.
pub fn graph_label_metrics_with(
  graph : @cgraph.Graph,
  label_text_dimensions_for : (String, String, Double) -> (Double, Double),
) -> GraphLabelMetrics? {
  match graph.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(
          graph_attr_inherited(graph, "fontsize"),
        )
        let font = @attrs.font_name(graph_attr_inherited(graph, "fontname"))
        let (width_pt, height_pt) =
          (label_text_dimensions_for)(value, font, font_size_pt)
        Some({ width_pt, height_pt })
      }
    None => None
  }
}

///|
/// Graphviz parity: label-anchor placement aligned to refs/graphviz/lib/common/labels.c.
pub fn graph_label_pos(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
  just : LabelJust,
) -> @geom.Point {
  let x = match just {
    LabelJust::Left => bbox.llx + label_width_pt / 2.0
    LabelJust::Right => bbox.urx - label_width_pt / 2.0
    LabelJust::Center => (bbox.llx + bbox.urx) / 2.0
  }
  let y = match loc {
    LabelLoc::Top => bbox.ury - label_height_pt / 2.0
    LabelLoc::Bottom => bbox.lly + label_height_pt / 2.0
  }
  { x, y }
}

///|
/// Graphviz parity: flipped label-anchor placement aligned to
/// refs/graphviz/lib/common/postproc.c (place_flip_graph_label).
pub fn graph_label_pos_flip(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
  just : LabelJust,
) -> @geom.Point {
  let x = match loc {
    LabelLoc::Top => bbox.urx - label_width_pt / 2.0
    LabelLoc::Bottom => bbox.llx + label_width_pt / 2.0
  }
  let y = match just {
    LabelJust::Left => bbox.ury - label_height_pt / 2.0
    LabelJust::Right => bbox.lly + label_height_pt / 2.0
    LabelJust::Center => (bbox.lly + bbox.ury) / 2.0
  }
  { x, y }
}

///|
/// Graphviz parity: label bbox expansion aligned to refs/graphviz/lib/common/input.c
/// border handling used by root/cluster label postprocess.
pub fn expand_bbox_for_label(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
) -> @geom.Rect {
  let pad = 8.0
  let mut llx = bbox.llx
  let mut lly = bbox.lly
  let mut urx = bbox.urx
  let mut ury = bbox.ury
  match loc {
    LabelLoc::Top => ury = ury + label_height_pt + pad
    LabelLoc::Bottom => lly = lly - label_height_pt - pad
  }
  let label_width = label_width_pt + pad * 2.0
  let current_width = urx - llx
  if label_width > current_width {
    let extra = label_width - current_width
    llx = llx - extra / 2.0
    urx = urx + extra / 2.0
  }
  { llx, lly, urx, ury }
}
