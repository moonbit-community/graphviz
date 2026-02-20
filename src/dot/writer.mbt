///|
const MAX_OUTPUT_LINE : Int = 128

///|
fn is_html_label_value(value : String) -> Bool {
  let trimmed = value.trim(chars=" \n\r\t").to_string()
  trimmed.length() >= 3 && trimmed.has_prefix("<<") && trimmed.has_suffix(">")
}

///|
fn is_graphviz_id_char(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '.' || ch == '-' ||
  ch.to_int() > 0x7F
}

///|
fn is_escape_at(chars : Array[Char], index : Int) -> Bool {
  if index < 0 || index >= chars.length() {
    return false
  }
  if chars[index] != '\\' || index + 1 >= chars.length() {
    return false
  }
  match chars[index + 1] {
    'E' | 'G' | 'H' | 'L' | 'N' | 'T' | 'l' | 'n' | 'r' | '\\' | '"' => true
    _ => false
  }
}

///|
fn is_keyword_token(id : String) -> Bool {
  let lower = id.to_lower()
  match lower {
    "node" | "edge" | "strict" | "graph" | "digraph" | "subgraph" => true
    _ => false
  }
}

///|
fn canonical_id(raw : String) -> String {
  if is_html_label_value(raw) {
    return raw
  }
  if raw == "" {
    return "\"\""
  }
  let chars : Array[Char] = []
  for ch in raw {
    chars.push(ch)
  }
  if chars.length() == 0 {
    return "\"\""
  }
  let out = StringBuilder::new()
  out.write_char('"')
  let mut cnt = 0
  let mut dotcnt = 0
  let mut needs_quotes = false
  let mut part_of_escape = false
  let first = chars[0]
  let mut maybe_num = first.is_ascii_digit() || first == '.' || first == '-'
  let mut backslash_pending = false
  for i in 0..<chars.length() {
    let uc = chars[i]
    if uc == '"' && !part_of_escape {
      out.write_char('\\')
      needs_quotes = true
    } else if !part_of_escape && is_escape_at(chars, i) {
      needs_quotes = true
      part_of_escape = true
    } else if maybe_num {
      if uc == '-' {
        if cnt > 0 {
          maybe_num = false
          needs_quotes = true
        }
      } else if uc == '.' {
        if dotcnt > 0 {
          maybe_num = false
          needs_quotes = true
        }
        dotcnt = dotcnt + 1
      } else if !uc.is_ascii_digit() {
        maybe_num = false
        needs_quotes = true
      }
      part_of_escape = false
    } else if !(uc.is_ascii_alphabetic() || uc.is_ascii_digit() || uc == '_' ||
      uc.to_int() > 0x7F) {
      needs_quotes = true
      part_of_escape = false
    } else {
      part_of_escape = false
    }
    out.write_char(uc)
    cnt = cnt + 1
    if MAX_OUTPUT_LINE > 0 && i + 1 < chars.length() {
      let next = chars[i + 1]
      let can_break = !(is_graphviz_id_char(uc) || uc == '\\') &&
        is_graphviz_id_char(next)
      if backslash_pending && can_break {
        out.write_char('\\')
        out.write_char('\n')
        needs_quotes = true
        backslash_pending = false
        cnt = 0
      } else if cnt >= MAX_OUTPUT_LINE {
        if can_break {
          out.write_char('\\')
          out.write_char('\n')
          needs_quotes = true
          cnt = 0
        } else {
          backslash_pending = true
        }
      }
    }
  }
  out.write_char('"')
  let quoted = out.to_string()
  if needs_quotes || (chars.length() == 1 && (chars[0] == '.' || chars[0] == '-')) {
    return quoted
  }
  if is_keyword_token(raw) {
    return quoted
  }
  raw
}

///|
fn write_id(id : String) -> String {
  canonical_id(id)
}

///|
fn compass_label(compass : @cgraph.Compass) -> String {
  match compass {
    N => "n"
    NE => "ne"
    E => "e"
    SE => "se"
    S => "s"
    SW => "sw"
    W => "w"
    NW => "nw"
    C => "c"
  }
}

///|
fn write_port(port : @cgraph.Port?) -> String {
  match port {
    None => ""
    Some(value) => {
      let mut out = ""
      match value.name {
        Some(label) => {
          out = ":\{write_id(label)}"
          match value.compass {
            Some(compass) => out = "\{out}:\{compass_label(compass)}"
            None => ()
          }
        }
        None =>
          match value.compass {
            Some(compass) => out = ":\{compass_label(compass)}"
            None => ()
          }
      }
      out
    }
  }
}

///|
priv enum AttrGroup {
  Graph
  Node
  Edge
}

///|
fn graph_attr_rank(name : String) -> Int {
  match name {
    "_draw_" => 0
    "_ldraw_" => 1
    "bb" => 2
    "bgcolor" => 3
    "color" => 4
    "fontcolor" => 5
    "fontname" => 6
    "fontsize" => 7
    "label" => 8
    "labelloc" => 9
    "lheight" => 10
    "lp" => 11
    "lwidth" => 12
    "nodesep" => 13
    "rank" => 14
    "rankdir" => 15
    "size" => 16
    "xdotversion" => 17
    "margin" => 18
    "page" => 19
    "ratio" => 20
    "splines" => 21
    "overlap" => 22
    "ordering" => 23
    "charset" => 24
    "ranksep" => 25
    _ => 200
  }
}

///|
fn node_attr_rank(name : String) -> Int {
  match name {
    "_draw_" => 0
    "_ldraw_" => 1
    "color" => 2
    "fillcolor" => 3
    "fontcolor" => 4
    "fontname" => 5
    "fontsize" => 6
    "distortion" => 7
    "height" => 8
    "kind" => 9
    "label" => 10
    "orientation" => 11
    "peripheries" => 12
    "pname" => 13
    "pos" => 14
    "rects" => 15
    "regular" => 16
    "shape" => 17
    "sides" => 18
    "skew" => 19
    "style" => 20
    "subkind" => 21
    "width" => 22
    "id" => 23
    _ => 200
  }
}

///|
fn edge_attr_rank(name : String) -> Int {
  match name {
    "_draw_" => 0
    "_hdraw_" => 1
    "_ldraw_" => 2
    "_tdraw_" => 3
    "_hldraw_" => 4
    "_tldraw_" => 5
    "arrowhead" => 6
    "arrowtail" => 7
    "arrowsize" => 8
    "color" => 9
    "constraint" => 10
    "dir" => 11
    "fontcolor" => 12
    "fontname" => 13
    "fontsize" => 14
    "head_lp" => 15
    "headlabel" => 16
    "id" => 17
    "label" => 18
    "labelangle" => 19
    "labeldistance" => 20
    "lp" => 21
    "lhead" => 22
    "ltail" => 23
    "minlen" => 24
    "pos" => 25
    "samearrowhead" => 26
    "samearrowtail" => 27
    "samehead" => 28
    "sametail" => 29
    "tail_lp" => 30
    "taillabel" => 31
    "weight" => 32
    "wt" => 33
    _ => 200
  }
}

///|
fn attr_rank(group : AttrGroup, name : String) -> Int {
  match group {
    AttrGroup::Graph => graph_attr_rank(name)
    AttrGroup::Node => node_attr_rank(name)
    AttrGroup::Edge => edge_attr_rank(name)
  }
}

///|
fn sort_attrs(
  attrs : Array[(String, String)],
  group : AttrGroup,
) -> Array[(String, String)] {
  let indexed : Array[(Int, (String, String))] = []
  for i, pair in attrs {
    indexed.push((i, pair))
  }
  indexed.sort_by_key(entry => {
    let (index, pair) = entry
    let (name, _value) = pair
    attr_rank(group, name) * 1000 + index
  })
  let out : Array[(String, String)] = []
  for entry in indexed {
    out.push(entry.1)
  }
  out
}

///|
fn merge_attrs_keep_order(
  base : Array[(String, String)],
  overrides : Array[(String, String)],
) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  let index : Map[String, Int] = Map::new()
  for pair in base {
    let (key, value) = pair
    match index.get(key) {
      Some(slot) => out[slot] = (key, value)
      None => {
        index[key] = out.length()
        out.push((key, value))
      }
    }
  }
  for pair in overrides {
    let (key, value) = pair
    match index.get(key) {
      Some(slot) => out[slot] = (key, value)
      None => {
        index[key] = out.length()
        out.push((key, value))
      }
    }
  }
  out
}

///|
fn write_tabs(sb : StringBuilder, level : Int) -> Unit {
  for _ in 0..<level {
    sb.write_char('\t')
  }
}

///|
fn write_attr_block(
  sb : StringBuilder,
  attrs : Array[(String, String)],
  group : AttrGroup,
  indent : Int,
  close_on_newline : Bool,
) -> Unit {
  let ordered = sort_attrs(attrs, group)
  sb.write_char('[')
  for i, pair in ordered {
    if i > 0 {
      sb.write_string(",\n")
      write_tabs(sb, indent + 1)
    }
    let (key, value) = pair
    let value = if (
      (key == "_draw_" || key == "_hdraw_" || key == "_tdraw_" ||
        key == "_ldraw_" || key == "_hldraw_" || key == "_tldraw_") &&
      value != "" && !value.has_suffix(" ")
    ) {
      value + " "
    } else {
      value
    }
    sb.write_string(write_id(key))
    sb.write_char('=')
    sb.write_string(write_id(value))
  }
  if close_on_newline && ordered.length() > 1 {
    sb.write_char('\n')
    write_tabs(sb, indent)
  }
  sb.write_char(']')
}

///|
fn write_default_stmt(
  sb : StringBuilder,
  indent : Int,
  name : String,
  attrs : Array[(String, String)],
  group : AttrGroup,
) -> Unit {
  if attrs.length() == 0 {
    return
  }
  write_tabs(sb, indent)
  sb.write_string(name)
  sb.write_char(' ')
  write_attr_block(sb, attrs, group, indent, true)
  sb.write_string(";\n")
}

///|
fn filter_nondefault_node_attrs(
  graph : @cgraph.Graph,
  node : @cgraph.Node,
) -> Array[(String, String)] {
  let filtered : Array[(String, String)] = []
  for pair in node.attrs() {
    let (key, value) = pair
    match graph.get_default_attr(@cgraph.AttrKind::Node, key) {
      Some(default_value) => {
        if default_value != value {
          filtered.push((key, value))
        }
      }
      None =>
        if value != "" {
          filtered.push((key, value))
        }
    }
  }
  filtered
}

///|
fn filter_nondefault_edge_attrs(
  graph : @cgraph.Graph,
  edge : @cgraph.Edge,
) -> Array[(String, String)] {
  let filtered : Array[(String, String)] = []
  for pair in edge.attrs() {
    let (key, value) = pair
    match graph.get_default_attr(@cgraph.AttrKind::Edge, key) {
      Some(default_value) => {
        if default_value != value {
          filtered.push((key, value))
        }
      }
      None =>
        if value != "" {
          filtered.push((key, value))
        }
    }
  }
  filtered
}

///|
fn has_no_edges(
  graph_edges : Array[@cgraph.Edge],
  node : @cgraph.Node,
) -> Bool {
  let name = node.name()
  for edge in graph_edges {
    if edge.tail().name() == name || edge.head().name() == name {
      return false
    }
  }
  true
}

///|
fn node_has_nondefault_attrs(
  graph : @cgraph.Graph,
  node : @cgraph.Node,
) -> Bool {
  for pair in node.attrs() {
    let (key, value) = pair
    match graph.get_default_attr(@cgraph.AttrKind::Node, key) {
      Some(default_value) =>
        if default_value != value {
          return true
        }
      None =>
        if value != "" {
          return true
        }
    }
  }
  false
}

///|
fn write_node_stmt(
  graph : @cgraph.Graph,
  node : @cgraph.Node,
  sb : StringBuilder,
  indent : Int,
) -> Unit {
  write_tabs(sb, indent)
  sb.write_string(write_id(node.name()))
  let attrs = filter_nondefault_node_attrs(graph, node)
  if attrs.length() > 0 {
    sb.write_char('\t')
    write_attr_block(sb, attrs, AttrGroup::Node, indent, false)
  }
  sb.write_string(";\n")
}

///|
fn edge_stmt_attrs(
  graph : @cgraph.Graph,
  edge : @cgraph.Edge,
) -> Array[(String, String)] {
  let attrs = filter_nondefault_edge_attrs(graph, edge)
  match edge.name() {
    Some(name) =>
      if name != "" {
        let out : Array[(String, String)] = [("key", name)]
        for pair in attrs {
          if pair.0 != "key" {
            out.push(pair)
          }
        }
        out
      } else {
        attrs
      }
    None => attrs
  }
}

///|
fn write_edge_stmt(
  graph : @cgraph.Graph,
  edge : @cgraph.Edge,
  sb : StringBuilder,
  indent : Int,
) -> Unit {
  write_tabs(sb, indent)
  sb.write_string(write_id(edge.tail().name()))
  sb.write_string(write_port(edge.tail_port()))
  sb.write_string(match graph.kind() {
    @cgraph.GraphKind::Directed => " -> "
    @cgraph.GraphKind::Undirected => " -- "
  })
  sb.write_string(write_id(edge.head().name()))
  sb.write_string(write_port(edge.head_port()))
  let attrs = edge_stmt_attrs(graph, edge)
  if attrs.length() > 0 {
    sb.write_char('\t')
    write_attr_block(sb, attrs, AttrGroup::Edge, indent, false)
  }
  sb.write_string(";\n")
}

///|
fn map_get_or_zero_str(map : Map[String, Int], key : String) -> Int {
  match map.get(key) {
    Some(value) => value
    None => 0
  }
}

///|
fn map_get_or_zero_int(map : Map[Int, Int], key : Int) -> Int {
  match map.get(key) {
    Some(value) => value
    None => 0
  }
}

///|
priv struct WriteContext {
  mut preorder_next : Int
  node_last_written : Map[String, Int]
  edge_last_written : Map[Int, Int]
}

///|
fn should_write_node(
  graph : @cgraph.Graph,
  node : @cgraph.Node,
  graph_edges : Array[@cgraph.Edge],
  preorder : Int,
  ctx : WriteContext,
) -> Bool {
  if map_get_or_zero_str(ctx.node_last_written, node.name()) >= preorder {
    return false
  }
  if has_no_edges(graph_edges, node) || node_has_nondefault_attrs(graph, node) {
    return true
  }
  false
}

///|
fn should_write_edge(
  edge : @cgraph.Edge,
  preorder : Int,
  ctx : WriteContext,
) -> Bool {
  map_get_or_zero_int(ctx.edge_last_written, edge.id()) < preorder
}

///|
fn write_body(
  graph : @cgraph.Graph,
  sb : StringBuilder,
  indent : Int,
  preorder : Int,
  is_layout_output : Bool,
  ctx : WriteContext,
) -> Unit {
  let graph_edges = graph.edges()
  let graph_nodes = graph.nodes()
  if !is_layout_output {
    graph_nodes.sort_by_key(node => node.name())
  }
  let node_order : Map[String, Int] = Map::new()
  for i, node in graph_nodes {
    node_order[node.name()] = i
  }
  for node in graph_nodes {
    if should_write_node(graph, node, graph_edges, preorder, ctx) {
      write_node_stmt(graph, node, sb, indent)
      ctx.node_last_written[node.name()] = preorder
    }
    let mut prev_head = node.name()
    let out_edges : Array[@cgraph.Edge] = []
    for edge in graph_edges {
      if edge.tail().name() != node.name() {
        continue
      }
      out_edges.push(edge)
    }
    if is_layout_output {
      out_edges.sort_by_key(edge => {
        let head_order = match node_order.get(edge.head().name()) {
          Some(value) => value
          None => 100000
        }
        head_order * 100000 + edge.id()
      })
    }
    for edge in out_edges {
      let head = edge.head()
      let head_name = head.name()
      if prev_head != head_name &&
        should_write_node(graph, head, graph_edges, preorder, ctx) {
        write_node_stmt(graph, head, sb, indent)
        ctx.node_last_written[head_name] = preorder
        prev_head = head_name
      }
      if should_write_edge(edge, preorder, ctx) {
        write_edge_stmt(graph, edge, sb, indent)
        ctx.edge_last_written[edge.id()] = preorder
      }
    }
  }
}

///|
fn root_graph(graph : @cgraph.Graph) -> @cgraph.Graph {
  let mut current = graph
  while true {
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  current
}

///|
fn should_emit_default_node_label(graph : @cgraph.Graph) -> Bool {
  graph.get_attr("bb") is Some(_)
}

///|
fn should_skip_layout_subgraph(
  parent : @cgraph.Graph,
  child : @cgraph.Graph,
  is_layout_output : Bool,
) -> Bool {
  if !is_layout_output {
    return false
  }
  if child.name() is Some(_) {
    return false
  }
  if parent.name() is Some(_) {
    return false
  }
  if parent.edges().length() == 0 {
    return false
  }
  if child.attrs().length() > 0 {
    return false
  }
  if child.default_attrs(@cgraph.AttrKind::Graph).length() > 0 {
    return false
  }
  if child.default_attrs(@cgraph.AttrKind::Node).length() > 0 {
    return false
  }
  if child.default_attrs(@cgraph.AttrKind::Edge).length() > 0 {
    return false
  }
  if child.edges().length() > 0 {
    return false
  }
  if child.subgraphs().length() > 0 {
    return false
  }
  true
}

///|
fn write_graph_recursive(
  graph : @cgraph.Graph,
  sb : StringBuilder,
  indent : Int,
  is_root : Bool,
  is_layout_output : Bool,
  ctx : WriteContext,
) -> Unit {
  let preorder = ctx.preorder_next
  ctx.preorder_next = ctx.preorder_next + 1
  write_tabs(sb, indent)
  if is_root {
    if graph.is_strict() {
      sb.write_string("strict ")
    }
    sb.write_string(match graph.kind() {
      @cgraph.GraphKind::Directed => "digraph"
      @cgraph.GraphKind::Undirected => "graph"
    })
    sb.write_char(' ')
  } else {
    match graph.name() {
      Some(_) => sb.write_string("subgraph ")
      None => ()
    }
  }
  match graph.name() {
    Some(name) => {
      sb.write_string(write_id(name))
      sb.write_char(' ')
    }
    None => ()
  }
  sb.write_string("{\n")
  let inner = indent + 1
  let graph_dict_attrs = merge_attrs_keep_order(
    graph.default_attrs(@cgraph.AttrKind::Graph),
    graph.attrs(),
  )
  write_default_stmt(sb, inner, "graph", graph_dict_attrs, AttrGroup::Graph)
  let node_defaults = graph.default_attrs(@cgraph.AttrKind::Node)
  write_default_stmt(sb, inner, "node", node_defaults, AttrGroup::Node)
  let edge_defaults = graph.default_attrs(@cgraph.AttrKind::Edge)
  write_default_stmt(sb, inner, "edge", edge_defaults, AttrGroup::Edge)
  for subgraph in graph.subgraphs() {
    if should_skip_layout_subgraph(graph, subgraph, is_layout_output) {
      continue
    }
    write_graph_recursive(
      subgraph,
      sb,
      inner,
      false,
      is_layout_output,
      ctx,
    )
  }
  write_body(graph, sb, inner, preorder, is_layout_output, ctx)
  write_tabs(sb, indent)
  sb.write_string("}\n")
}

///|
pub fn write_dot(graph : @cgraph.Graph) -> String {
  let sb = StringBuilder::new()
  let is_layout_output = should_emit_default_node_label(root_graph(graph))
  let ctx : WriteContext = {
    preorder_next: 1,
    node_last_written: Map::new(),
    edge_last_written: Map::new(),
  }
  write_graph_recursive(graph, sb, 0, true, is_layout_output, ctx)
  sb.to_string()
}
