///|
/// Edge attribute interpretation and edge-behavior helpers shared across dot
/// ranking, ordering, routing, and final layout emission.

///|
/// Edge direction for directed edge endpoint markers and routing behavior.
pub(all) enum EdgeDir {
  Forward
  Back
  Both
  None
} derive(Show, Eq)

///|
pub fn parse_edge_dir(value : String) -> EdgeDir? {
  match value.to_lower() {
    "forward" | "f" => Some(EdgeDir::Forward)
    "back" | "b" => Some(EdgeDir::Back)
    "both" => Some(EdgeDir::Both)
    "none" => Some(EdgeDir::None)
    _ => None
  }
}

///|
pub fn edge_dir_for(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> EdgeDir {
  if kind == @cgraph.GraphKind::Undirected {
    return EdgeDir::None
  }
  match edge.get_attr("dir") {
    Some(value) =>
      match parse_edge_dir(value) {
        Some(dir) => dir
        None => EdgeDir::Forward
      }
    None => EdgeDir::Forward
  }
}

///|
pub fn arrow_attr_is_none(value : String?) -> Bool {
  match value {
    Some(raw) => raw.trim().to_lower() == "none"
    None => false
  }
}

///|
pub fn edge_has_head_marker(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> Bool {
  match edge_dir_for(edge, kind) {
    EdgeDir::Forward | EdgeDir::Both => !arrow_attr_is_none(edge.get_attr("arrowhead"))
    _ => false
  }
}

///|
pub fn edge_has_tail_marker(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> Bool {
  match edge_dir_for(edge, kind) {
    EdgeDir::Back | EdgeDir::Both => !arrow_attr_is_none(edge.get_attr("arrowtail"))
    _ => false
  }
}

///|
pub fn edge_is_self(edge : @cgraph.Edge) -> Bool {
  edge.tail().name() == edge.head().name()
}

///|
pub fn edge_has_label(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("label") {
    Some(value) => value != ""
    None => false
  }
}

///|
pub fn edge_attr_non_empty(edge : @cgraph.Edge, name : String) -> Bool {
  match edge.get_attr(name) {
    Some(value) => value != ""
    None => false
  }
}

///|
pub fn edge_attr_or_empty(edge : @cgraph.Edge, name : String) -> String {
  match edge.get_attr(name) {
    Some(value) => value
    None => ""
  }
}

///|
pub(all) struct EdgeRankSpan {
  min_rank : Int
  max_rank : Int
}

///|
/// Graphviz parity: edge rank span is resolved from tail/head node ranks
/// before long-edge label and vnode rank-based adjustments.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_rank_span(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
) -> EdgeRankSpan? {
  let tail_rank = match ranks.get(edge.tail().name()) {
    Some(value) => value
    None => return None
  }
  let head_rank = match ranks.get(edge.head().name()) {
    Some(value) => value
    None => return None
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  Some({ min_rank, max_rank })
}

///|
/// Graphviz mapbool() parity for edge `constraint` handling.
pub fn edge_is_constraint(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("constraint") {
    Some(value) => {
      // Graphviz mapbool() parity:
      // - empty string keeps default (constraint=true)
      // - unknown non-empty tokens map to false
      let trimmed = value.trim()
      if trimmed == "" {
        true
      } else {
        let lower = trimmed.to_lower()
        if lower == "false" || lower == "no" {
          false
        } else if lower == "true" || lower == "yes" {
          true
        } else {
          match lower.get_char(0) {
            Some(c) =>
              if c.is_ascii_digit() {
                let mut acc = 0
                let mut seen = false
                for ch in lower {
                  if ch.is_ascii_digit() {
                    seen = true
                    acc = acc * 10 + (ch.to_int() - '0'.to_int())
                  } else {
                    break
                  }
                }
                seen && acc != 0
              } else {
                false
              }
            None => true
          }
        }
      }
    }
    None => true
  }
}

///|
pub fn edge_weight(edge : @cgraph.Edge) -> Int {
  let weight_value = @attrs.parse_double(edge.get_attr("weight"), 1.0)
  let mut weight = weight_value.round().to_int()
  if weight < 0 {
    weight = 0
  }
  if !edge_is_constraint(edge) {
    return 0
  }
  let tail_group = match edge.tail().get_attr("group") {
    Some(value) => value
    None => ""
  }
  let head_group = match edge.head().get_attr("group") {
    Some(value) => value
    None => ""
  }
  if tail_group != "" && tail_group == head_group {
    weight = weight * 100
  }
  weight
}

///|
pub fn edge_minlen(edge : @cgraph.Edge) -> Int {
  let minlen_value = @attrs.parse_double(edge.get_attr("minlen"), 1.0)
  let minlen = minlen_value.round().to_int()
  if minlen < 1 {
    1
  } else {
    minlen
  }
}

///|
pub fn edge_xpenalty(edge : @cgraph.Edge) -> Int {
  let penalty_value = @attrs.parse_double(edge.get_attr("xpenalty"), 1.0)
  let mut penalty = penalty_value.round().to_int()
  if penalty < 0 {
    penalty = 0
  }
  if !edge_is_constraint(edge) {
    return 0
  }
  penalty
}
