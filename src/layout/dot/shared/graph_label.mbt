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
