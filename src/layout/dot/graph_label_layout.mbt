///|
/// Graphviz parity: label placement aligned to refs/graphviz/lib/common/labels.c (fixtures).
/// Xlabel placement lives in xlabel_layout.mbt (refs/graphviz/lib/label/xlabels.c).
/// Do not change behavior without updating fixtures/tests.
priv enum LabelLoc {
  Top
  Bottom
}

///|
priv enum LabelJust {
  Left
  Center
  Right
}

///|
fn parse_label_loc(value : String?, default_loc : LabelLoc) -> LabelLoc {
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
fn parse_label_just(value : String?) -> LabelJust {
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
fn graph_label_loc(graph : @cgraph.Graph) -> LabelLoc {
  let default_loc = if graph.is_root() {
    LabelLoc::Bottom
  } else {
    LabelLoc::Top
  }
  parse_label_loc(graph.get_attr("labelloc"), default_loc)
}

///|
fn graph_attr_inherited(
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
fn graph_label_just(graph : @cgraph.Graph) -> LabelJust {
  parse_label_just(graph_attr_inherited(graph, "labeljust"))
}

///|
priv struct GraphLabelMetrics {
  width_pt : Double
  height_pt : Double
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> GraphLabelMetrics? {
  match graph.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(
          graph_attr_inherited(graph, "fontsize"),
        )
        let font = @attrs.font_name(graph_attr_inherited(graph, "fontname"))
        let (width_pt, height_pt) = label_text_dimensions(
          value, font, font_size_pt,
        )
        Some({ width_pt, height_pt })
      }
    None => None
  }
}

///|
fn graph_label_pos(
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
/// Graphviz parity: flipped cluster label placement aligned to
/// refs/graphviz/lib/common/postproc.c (place_flip_graph_label).
/// Do not change behavior without updating fixtures/tests.
fn graph_label_pos_flip(
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
fn min_double(a : Double, b : Double) -> Double {
  if a < b { a } else { b }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

///|
fn rect_from_center(
  center : @geom.Point,
  width : Double,
  height : Double,
  pad : Double,
) -> @geom.Rect {
  let half_w = width / 2.0 + pad
  let half_h = height / 2.0 + pad
  {
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  }
}
