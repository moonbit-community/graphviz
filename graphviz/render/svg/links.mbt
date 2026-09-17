// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
priv struct SvgLink {
  href : String?
  title : String?
  target : String?
}

///|
fn substitute_svg_link(text : String, values : Map[Char, String]) -> String {
  let result = StringBuilder()
  let mut escaped = false
  for ch in text {
    if escaped {
      if values.get(ch) is Some(value) {
        result.write_string(value)
      } else {
        if ch != '\\' {
          result.write_char('\\')
        }
        result.write_char(ch)
      }
      escaped = false
    } else if ch == '\\' {
      escaped = true
    } else {
      result.write_char(ch)
    }
  }
  if escaped {
    result.write_char('\\')
  }
  result.to_string()
}

///|
fn svg_link(
  href : String?,
  tooltip : String?,
  target : String?,
  fallback_title : String?,
  substitutions : Map[Char, String],
) -> SvgLink? {
  let href = nonempty_attr_value(href)
  let tooltip = nonempty_attr_value(tooltip)
  guard href is Some(_) || tooltip is Some(_) else { return None }
  Some({
    href: href.map(value => substitute_svg_link(value, substitutions)),
    title: tooltip
    .map_or(nonempty_attr_value(fallback_title), value => Some(value))
    .map(value => substitute_svg_link(value, substitutions)),
    target: nonempty_attr_value(target).map(value => {
      substitute_svg_link(value, substitutions)
    }),
  })
}

///|
fn write_svg_link_start(
  sb : StringBuilder,
  id : String,
  link : SvgLink?,
  indent : String,
  pretty : Bool,
) -> Bool {
  guard link is Some(link) else { return false }
  let attrs = StringBuilder()
  if link.href is Some(href) {
    attrs.write_string(" xlink:href=\"\{escape_xml(href)}\"")
  }
  if link.title is Some(title) {
    attrs.write_string(" xlink:title=\"\{escape_xml_with_dash(title)}\"")
  }
  if link.target is Some(target) {
    attrs.write_string(" target=\"\{escape_xml(target)}\"")
  }
  write_line(
    sb,
    "<g id=\"a_\{escape_xml_with_dash(id)}\"><a\{attrs.to_string()}>",
    indent,
    pretty,
  )
  true
}

///|
fn write_svg_link_end(
  sb : StringBuilder,
  opened : Bool,
  indent : String,
  pretty : Bool,
) -> Unit {
  if opened {
    write_line(sb, "</a>", indent, pretty)
    write_line(sb, "</g>", indent, pretty)
  }
}

///|
fn graph_svg_link(graph : @cgraph.Graph) -> SvgLink? {
  svg_link(
    first_svg_link_attr(name => inherited_graph_attr(graph, name), [
      "href", "URL",
    ]),
    inherited_graph_attr(graph, "tooltip"),
    inherited_graph_attr(graph, "target"),
    graph_label_text(graph),
    { 'G': graph.name().unwrap_or_default() },
  )
}

///|
fn first_svg_link_attr(
  get_attr : (String) -> String?,
  names : Array[String],
) -> String? {
  for name in names {
    if nonempty_attr_value(get_attr(name)) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
fn edge_svg_link(edge : @cgraph.Edge, part : String) -> SvgLink? {
  let get_attr = (name : String) => edge_attr(edge, name)
  let prefix = if part == "" { "edge" } else { part }
  let href = first_svg_link_attr(get_attr, [
    "\{prefix}href",
    "\{prefix}URL",
    "href",
    "URL",
  ])
  let tooltip = if part == "" {
    first_svg_link_attr(get_attr, ["tooltip", "edgetooltip"])
  } else {
    edge_attr(edge, "\{prefix}tooltip")
  }
  let label_attr = if part == "head" || part == "tail" {
    "\{part}label"
  } else {
    "label"
  }
  let target = first_svg_link_attr(get_attr, ["\{prefix}target", "target"])
  let arrow = if edge.tail().graph().kind() == @cgraph.GraphKind::Directed {
    "->"
  } else {
    "--"
  }
  svg_link(href, tooltip, target, edge_attr(edge, label_attr), {
    'G': root_graph_for_node(edge.tail()).name().unwrap_or_default(),
    'T': edge.tail().name(),
    'H': edge.head().name(),
    'E': "\{edge.tail().name()}\{arrow}\{edge.head().name()}",
    'L': edge_attr(edge, label_attr).unwrap_or_default(),
  })
}
