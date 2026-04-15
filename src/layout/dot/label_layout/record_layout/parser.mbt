// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Record-label parser owner: record field syntax, nested group parsing,
/// text normalization, and the cached public record-node parser entry.

///|
pub(all) struct RecordField {
  name : String?
  text : String
}

///|
pub(all) enum RecordNode {
  Field(RecordField)
  Group(Array[RecordNode])
}

///|
let record_nodes_cache : Ref[Map[String, Array[RecordNode]]] = @ref.new(
  Map::new(),
)

///|
pub(all) struct RecordParser {
  chars : Array[Char]
  mut index : Int
}

///|
pub fn parse_record_nodes(parser : RecordParser) -> Array[RecordNode] {
  let nodes : Array[RecordNode] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut in_port = false
  let mut segment_has_node = false
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if escaping {
      escaping = false
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '\\' {
      escaping = true
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '<' {
      in_port = true
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '>' {
      in_port = false
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if !in_port && ch == '{' {
      let text = sb.to_string()
      if text.trim(chars=" \n\r\t") != "" {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
        segment_has_node = true
      }
      sb = StringBuilder::new()
      parser.index = parser.index + 1
      let children = parse_record_nodes(parser)
      nodes.push(RecordNode::Group(children))
      segment_has_node = true
      continue
    }
    if !in_port && ch == '|' {
      let text = sb.to_string()
      if !segment_has_node {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
      }
      sb = StringBuilder::new()
      segment_has_node = false
      parser.index = parser.index + 1
      continue
    }
    if !in_port && ch == '}' {
      let text = sb.to_string()
      if !segment_has_node {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
      }
      sb = StringBuilder::new()
      parser.index = parser.index + 1
      return nodes
    }
    sb.write_char(ch)
    parser.index = parser.index + 1
  }
  let text = sb.to_string()
  if !segment_has_node {
    nodes.push(RecordNode::Field(record_field_from_text(text)))
  }
  nodes
}

///|
fn record_field_from_text(field : String) -> RecordField {
  let trimmed = field.trim(chars=" \n\r\t").to_string()
  let (port_name, raw_text) : (String?, String) = if trimmed.has_prefix("<") {
    match trimmed.find(">") {
      Some(pos) => {
        let name = if pos > 1 {
          trimmed.unsafe_substring(start=1, end=pos)
        } else {
          ""
        }
        let len = trimmed.length()
        let text = if pos + 1 < len {
          trimmed.unsafe_substring(start=pos + 1, end=len)
        } else {
          ""
        }
        let port_name : String? = if name == "" { None } else { Some(name) }
        (port_name, text)
      }
      None => (None, trimmed)
    }
  } else {
    (None, trimmed)
  }
  let normalized = normalize_record_text(raw_text)
    .trim(chars=" \n\r\t")
    .to_string()
  let text = if normalized == "" { " " } else { normalized }
  { name: port_name, text }
}

///|
fn normalize_record_text(text : String) -> String {
  let sb = StringBuilder::new()
  let mut escaping = false
  for ch in text {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        sb.write_char('\\')
        sb.write_char(ch)
      } else {
        sb.write_char(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    sb.write_char(ch)
  }
  if escaping {
    sb.write_char('\\')
  }
  sb.to_string()
}

///|
pub fn record_nodes(label : String) -> Array[RecordNode] {
  match record_nodes_cache.val.get(label) {
    Some(cached) => cached
    None => {
      let chars : Array[Char] = []
      for ch in label {
        chars.push(ch)
      }
      let parser = RecordParser::{ chars, index: 0 }
      // Graphviz parity: preserve outer braces as an explicit group.
      // Do not flatten a single top-level group; it flips field orientation.
      let nodes = parse_record_nodes(parser)
      record_nodes_cache.val[label] = nodes
      nodes
    }
  }
}
