///|
const MAX_OUTPUT_LINE : Int = 128

///|
fn is_html_label_value(value : String) -> Bool {
  let trimmed = value.trim(chars=" \n\r\t").to_string()
  if trimmed.length() < 3 || !trimmed.has_prefix("<") || !trimmed.has_suffix(">") {
    return false
  }
  let inner = trimmed.unsafe_substring(start=1, end=trimmed.length() - 1)
  for ch in inner {
    if ch.is_whitespace() {
      continue
    }
    return ch == '<'
  }
  false
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
fn compass_from_label(value : String) -> @cgraph.Compass? {
  match value.to_lower() {
    "n" => Some(@cgraph.Compass::N)
    "ne" => Some(@cgraph.Compass::NE)
    "e" => Some(@cgraph.Compass::E)
    "se" => Some(@cgraph.Compass::SE)
    "s" => Some(@cgraph.Compass::S)
    "sw" => Some(@cgraph.Compass::SW)
    "w" => Some(@cgraph.Compass::W)
    "nw" => Some(@cgraph.Compass::NW)
    "c" => Some(@cgraph.Compass::C)
    _ => None
  }
}

///|
fn split_once_colon(value : String) -> (String, String)? {
  match value.find(":") {
    Some(index) =>
      Some((
        value.unsafe_substring(start=0, end=index),
        value.unsafe_substring(start=index + 1, end=value.length()),
      ))
    None => None
  }
}

///|
fn parse_port_attr_value(raw : String) -> @cgraph.Port? {
  let value = raw.trim().to_string()
  if value == "" {
    return None
  }
  if value.has_prefix(":") {
    let rest = value.unsafe_substring(start=1, end=value.length())
    if rest == "" {
      return Some({ name: Some(""), compass: None })
    }
    match split_once_colon(rest) {
      Some((name_part, compass_part)) =>
        Some({ name: Some(name_part), compass: compass_from_label(compass_part) })
      None =>
        match compass_from_label(rest) {
          Some(compass) => Some({ name: Some(""), compass: Some(compass) })
          None => Some({ name: Some(rest), compass: None })
        }
    }
  } else {
    match split_once_colon(value) {
      Some((name_part, compass_part)) =>
        Some({ name: Some(name_part), compass: compass_from_label(compass_part) })
      None =>
        match compass_from_label(value) {
          Some(compass) => Some({ name: None, compass: Some(compass) })
          None => Some({ name: Some(value), compass: None })
        }
    }
  }
}

///|
fn effective_edge_port(
  edge : @cgraph.Edge,
  explicit : @cgraph.Port?,
  attr_name : String,
) -> @cgraph.Port? {
  match explicit {
    Some(port) => Some(port)
    None =>
      match edge.get_attr(attr_name) {
        Some(raw) => parse_port_attr_value(raw)
        None => None
      }
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
fn is_internal_graph_attr(name : String) -> Bool {
  name == INPUT_LATIN1_FALLBACK_ATTR
}

///|
fn graph_attr_rank(name : String) -> Int {
  match name {
    "URL" | "url" | "href" => -1
    "_draw_" => 0
    "_ldraw_" => 1
    "bb" => 2
    "charset" => 3
    "bgcolor" => 3
    "color" => 4
    "concentrate" => 5
    "colorscheme" => 5
    "center" => 6
    "fontcolor" => 7
    "fontname" => 8
    "fontsize" => 9
    "label" => 10
    "labeljust" => 11
    "labelloc" => 12
    "lheight" => 13
    "lp" => 14
    "lwidth" => 15
    "ordering" => 20
    "orientation" => 17
    "page" => 18
    "margin" => 19
    "nodesep" => 20
    "overlap" => 21
    "rank" => 22
    "rankdir" => 23
    "ranksep" => 24
    "ratio" => 25
    "size" => 26
    "splines" => 27
    "xdotversion" => 1000
    _ => 200
  }
}

///|
fn node_attr_rank(name : String) -> Int {
  match name {
    "URL" | "url" | "href" => -1
    "_draw_" => 0
    "_ldraw_" => 1
    "color" => 2
    "colorscheme" => 3
    "fillcolor" => 4
    "fixedsize" => 5
    "distortion" => 5
    "fontcolor" => 6
    "fontname" => 7
    "fname" => 8
    "fontsize" => 9
    "height" => 10
    "hight" => 11
    "image" => 11
    "kind" => 11
    "label" => 12
    "orientation" => 13
    "peripheries" => 14
    "pname" => 15
    "margin" => 16
    "pos" => 17
    "rects" => 18
    "regular" => 19
    "shape" => 20
    "sides" => 21
    "skew" => 22
    "style" => 23
    "subkind" => 24
    "root" => 24
    "width" => 25
    "id" => 26
    _ => 200
  }
}

///|
fn edge_attr_rank(name : String) -> Int {
  match name {
    "URL" | "url" | "href" | "edgeURL" | "edgeurl" | "edgehref"
    | "headURL" | "headurl" | "headhref" | "tailURL" | "tailurl"
    | "tailhref" | "labelURL" | "labelurl" | "labelhref" => -1
    "_draw_" => 0
    "_hdraw_" => 1
    "_hldraw_" => 2
    "_ldraw_" => 3
    "_tdraw_" => 4
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
    "len" => 20
    "lp" => 21
    "lhead" => 22
    "ltail" => 23
    "minlen" => 24
    "pos" => 25
    "radius" => 26
    "samearrowhead" => 26
    "samearrowtail" => 27
    "samehead" => 28
    "sametail" => 29
    "style" => 30
    "tail_lp" => 31
    "taillabel" => 32
    "xlabel" => 33
    "xlp" => 34
    "w" => 35
    "weight" => 35
    "wt" => 36
    // Graphviz emits unknown/custom edge attrs (for example, `len`/`f`)
    // ahead of generated `pos`, while still keeping them after label/minlen.
    _ => 24
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
fn filter_internal_graph_attrs(
  attrs : Array[(String, String)],
) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  for pair in attrs {
    let (name, _value) = pair
    if is_internal_graph_attr(name) {
      continue
    }
    out.push(pair)
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
      value != ""
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
        if value != "" || key == "distortion" || key == "style" ||
          key == "label" {
          filtered.push((key, value))
        }
    }
  }
  if node.get_attr("distortion") is None {
    match graph.get_default_attr(@cgraph.AttrKind::Node, "distortion") {
      Some(default_value) =>
        if default_value != "" {
          filtered.push(("distortion", ""))
        }
      None => ()
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
        if value != "" || key == "style" || key == "label" {
          filtered.push((key, value))
        }
    }
  }
  if edge.get_attr("style") is None {
    match graph.get_default_attr(@cgraph.AttrKind::Edge, "style") {
      Some(default_value) =>
        if default_value != "" {
          filtered.push(("style", ""))
        }
      None => ()
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
        if value != "" || key == "distortion" || key == "style" ||
          key == "label" {
          return true
        }
    }
  }
  if node.get_attr("distortion") is None {
    match graph.get_default_attr(@cgraph.AttrKind::Node, "distortion") {
      Some(default_value) => if default_value != "" { return true }
      None => ()
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
  emit_attrs : Bool,
) -> Unit {
  write_tabs(sb, indent)
  sb.write_string(write_id(node.name()))
  if emit_attrs {
    let attrs = filter_nondefault_node_attrs(graph, node)
    if attrs.length() > 0 {
      sb.write_char('\t')
      write_attr_block(sb, attrs, AttrGroup::Node, indent, false)
    }
  }
  sb.write_string(";\n")
}

///|
fn edge_stmt_attrs(
  graph : @cgraph.Graph,
  edge : @cgraph.Edge,
  emit_attrs : Bool,
) -> Array[(String, String)] {
  if !emit_attrs {
    match edge.name() {
      Some(name) => if name != "" { return [("key", name)] }
      None => ()
    }
    return []
  }
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
  emit_attrs : Bool,
) -> Unit {
  let tail_port = effective_edge_port(edge, edge.tail_port(), "tailport")
  let head_port = effective_edge_port(edge, edge.head_port(), "headport")
  write_tabs(sb, indent)
  sb.write_string(write_id(edge.tail().name()))
  sb.write_string(write_port(tail_port))
  sb.write_string(match graph.kind() {
    @cgraph.GraphKind::Directed => " -> "
    @cgraph.GraphKind::Undirected => " -- "
  })
  sb.write_string(write_id(edge.head().name()))
  sb.write_string(write_port(head_port))
  let attrs = edge_stmt_attrs(graph, edge, emit_attrs)
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
  node_attrs_written : Map[String, Bool]
  edge_attrs_written : Map[Int, Bool]
  edge_target_paths : Map[Int, String]
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
fn attrs_already_written_for_node(ctx : WriteContext, node_name : String) -> Bool {
  ctx.node_attrs_written.get(node_name) is Some(_)
}

///|
fn attrs_already_written_for_edge(ctx : WriteContext, edge_id : Int) -> Bool {
  ctx.edge_attrs_written.get(edge_id) is Some(_)
}

///|
fn child_graph_path(path : String, index : Int) -> String {
  if path == "" {
    "\{index}"
  } else {
    "\{path}/\{index}"
  }
}

///|
fn graph_contains_node_name_raw(graph : @cgraph.Graph, name : String) -> Bool {
  for node in graph.nodes() {
    if node.name() == name {
      return true
    }
  }
  false
}

fn is_rankset_graph(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("rank") {
    Some(value) => {
      let lower = value.to_lower()
      lower == "same" ||
        lower == "min" ||
        lower == "max" ||
        lower == "source" ||
        lower == "sink"
    }
    None => false
  }
}

fn graph_is_within_cluster_name(graph : @cgraph.Graph, cluster_name : String) -> Bool {
  if cluster_name == "" {
    return false
  }
  let mut current : @cgraph.Graph? = Some(graph)
  while true {
    match current {
      Some(value) => {
        match value.name() {
          Some(name) =>
            if name == cluster_name {
              return true
            }
          None => ()
        }
        current = value.parent()
      }
      None => break
    }
  }
  false
}

fn node_in_rankset_outside_cluster(
  root : @cgraph.Graph,
  node_name : String,
  cluster_name : String,
) -> Bool {
  if cluster_name == "" {
    return false
  }
  let stack : Array[@cgraph.Graph] = [root]
  while stack.length() > 0 {
    let current = stack[stack.length() - 1]
    let _ = stack.pop()
    if !graph_contains_node_name_raw(current, node_name) {
      continue
    }
    if is_rankset_graph(current) &&
      !graph_is_within_cluster_name(current, cluster_name) {
      return true
    }
    for child in current.subgraphs() {
      stack.push(child)
    }
  }
  false
}

///|
fn graph_contains_node_name(graph : @cgraph.Graph, name : String) -> Bool {
  if !graph_contains_node_name_raw(graph, name) {
    return false
  }
  // Graphviz parity: nodes merged into an external rankset are deleted from
  // cluster membership before final dot emission (dotgen/node_induce).
  if is_cluster_subgraph(graph) {
    let root = root_graph(graph)
    let cluster_name = match graph.name() {
      Some(value) => value
      None => ""
    }
    if node_in_rankset_outside_cluster(root, name, cluster_name) {
      return false
    }
  }
  true
}

///|
fn is_cluster_subgraph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn graph_contains_edge_id(graph : @cgraph.Graph, edge_id : Int) -> Bool {
  for edge in graph.edges() {
    if edge.id() == edge_id {
      return true
    }
  }
  false
}

///|
fn edge_home_path_recursive(
  graph : @cgraph.Graph,
  path : String,
  edge_id : Int,
) -> String {
  for i, subgraph in graph.subgraphs() {
    if should_skip_layout_subgraph(graph, subgraph, true) {
      continue
    }
    if !graph_contains_edge_id(subgraph, edge_id) {
      continue
    }
    let child_path = child_graph_path(path, i)
    return edge_home_path_recursive(subgraph, child_path, edge_id)
  }
  path
}

///|
fn parse_non_negative_int(text : String) -> Int? {
  if text == "" {
    return None
  }
  let mut value = 0
  for ch in text {
    if !ch.is_ascii_digit() {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn graph_at_path(root : @cgraph.Graph, path : String) -> @cgraph.Graph? {
  if path == "" {
    return Some(root)
  }
  let mut current = root
  for part in path.split("/") {
    let segment = part.to_string()
    if segment == "" {
      continue
    }
    let index = match parse_non_negative_int(segment) {
      Some(value) => value
      None => return None
    }
    let subgraphs = current.subgraphs()
    if index >= subgraphs.length() {
      return None
    }
    current = subgraphs[index]
  }
  Some(current)
}

///|
fn cluster_lca_path_recursive(
  graph : @cgraph.Graph,
  path : String,
  tail_name : String,
  head_name : String,
) -> String {
  for i, subgraph in graph.subgraphs() {
    if should_skip_layout_subgraph(graph, subgraph, true) {
      continue
    }
    if !is_cluster_subgraph(subgraph) {
      continue
    }
    if !graph_contains_node_name(subgraph, tail_name) {
      continue
    }
    if !graph_contains_node_name(subgraph, head_name) {
      continue
    }
    let child_path = child_graph_path(path, i)
    return cluster_lca_path_recursive(
      subgraph,
      child_path,
      tail_name,
      head_name,
    )
  }
  path
}

///|
fn edge_target_path(
  edge : @cgraph.Edge,
  root : @cgraph.Graph,
  ctx : WriteContext,
) -> String {
  let id = edge.id()
  match ctx.edge_target_paths.get(id) {
    Some(path) => path
    None => {
      let home_path = edge_home_path_recursive(root, "", id)
      let cluster_path = cluster_lca_path_recursive(
        root,
        "",
        edge.tail().name(),
        edge.head().name(),
      )
      let path = if home_path == "" {
        cluster_path
      } else {
        match graph_at_path(root, home_path) {
          Some(home_graph) =>
            if graph_contains_node_name(home_graph, edge.tail().name()) &&
              graph_contains_node_name(home_graph, edge.head().name()) {
              home_path
            } else {
              cluster_path
            }
          None => cluster_path
        }
      }
      ctx.edge_target_paths[id] = path
      path
    }
  }
}

///|
fn write_body(
  graph : @cgraph.Graph,
  sb : StringBuilder,
  indent : Int,
  preorder : Int,
  graph_path : String,
  is_layout_output : Bool,
  ctx : WriteContext,
) -> Unit {
  let graph_edges = if is_layout_output {
    let root = root_graph(graph)
    let edges : Array[@cgraph.Edge] = []
    for edge in root.edges() {
      if edge_target_path(edge, root, ctx) == graph_path {
        edges.push(edge)
      }
    }
    edges
  } else {
    graph.edges()
  }
  let graph_nodes =
    if is_layout_output {
      let nodes : Array[@cgraph.Node] = []
      for node in graph.nodes() {
        if graph_contains_node_name(graph, node.name()) {
          nodes.push(node)
        }
      }
      nodes
    } else {
      graph.nodes()
    }
  if !is_layout_output {
    graph_nodes.sort_by_key(node => node.name())
  } else {
    let root_nodes = root_graph(graph).nodes()
    let root_order : Map[String, Int] = Map::new()
    for i, node in root_nodes {
      root_order[node.name()] = i
    }
    graph_nodes.sort_by_key(node => match root_order.get(node.name()) {
      Some(value) => value
      None => 100000
    })
  }
  let node_order : Map[String, Int] = Map::new()
  for i, node in graph_nodes {
    node_order[node.name()] = i
  }
  for node in graph_nodes {
    if should_write_node(graph, node, graph_edges, preorder, ctx) {
      write_node_stmt(
        graph,
        node,
        sb,
        indent,
        !attrs_already_written_for_node(ctx, node.name()),
      )
      ctx.node_last_written[node.name()] = preorder
      ctx.node_attrs_written[node.name()] = true
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
        write_node_stmt(
          graph,
          head,
          sb,
          indent,
          !attrs_already_written_for_node(ctx, head_name),
        )
        ctx.node_last_written[head_name] = preorder
        ctx.node_attrs_written[head_name] = true
        prev_head = head_name
      }
      if should_write_edge(edge, preorder, ctx) {
        write_edge_stmt(
          graph,
          edge,
          sb,
          indent,
          !attrs_already_written_for_edge(ctx, edge.id()),
        )
        ctx.edge_last_written[edge.id()] = preorder
        ctx.edge_attrs_written[edge.id()] = true
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
  path : String,
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
  let graph_defaults = filter_internal_graph_attrs(
    graph.default_attrs(@cgraph.AttrKind::Graph),
  )
  let graph_attrs = filter_internal_graph_attrs(graph.attrs())
  let graph_dict_attrs = merge_attrs_keep_order(
    graph_defaults,
    graph_attrs,
  )
  write_default_stmt(sb, inner, "graph", graph_dict_attrs, AttrGroup::Graph)
  let node_defaults = graph.default_attrs(@cgraph.AttrKind::Node)
  let node_defaults =
    if is_root && is_layout_output {
      let mut has_label = false
      for pair in node_defaults {
        let (key, _) = pair
        if key == "label" {
          has_label = true
          break
        }
      }
      if has_label {
        node_defaults
      } else {
        let out : Array[(String, String)] = []
        for pair in node_defaults {
          out.push(pair)
        }
        out.push(("label", "\\N"))
        out
      }
    } else {
      node_defaults
    }
  write_default_stmt(sb, inner, "node", node_defaults, AttrGroup::Node)
  let edge_defaults = graph.default_attrs(@cgraph.AttrKind::Edge)
  write_default_stmt(sb, inner, "edge", edge_defaults, AttrGroup::Edge)
  for i, subgraph in graph.subgraphs() {
    if should_skip_layout_subgraph(graph, subgraph, is_layout_output) {
      continue
    }
    let child_path = child_graph_path(path, i)
    write_graph_recursive(
      subgraph,
      sb,
      inner,
      child_path,
      false,
      is_layout_output,
      ctx,
    )
  }
  write_body(graph, sb, inner, preorder, path, is_layout_output, ctx)
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
    node_attrs_written: Map::new(),
    edge_attrs_written: Map::new(),
    edge_target_paths: Map::new(),
  }
  write_graph_recursive(graph, sb, 0, "", true, is_layout_output, ctx)
  sb.to_string()
}

///|
fn inherited_graph_attr(graph : @cgraph.Graph, name : String) -> String? {
  let mut current = graph
  while true {
    match current.get_attr(name) {
      Some(value) => return Some(value)
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  None
}

///|
fn graph_uses_latin1_charset(graph : @cgraph.Graph) -> Bool {
  if inherited_graph_attr(graph, INPUT_LATIN1_FALLBACK_ATTR) is Some(_) {
    return true
  }
  match inherited_graph_attr(graph, "charset") {
    Some(value) => {
      let lower = value.to_lower()
      lower == "latin1" || lower == "latin-1"
    }
    None => false
  }
}

///|
fn latin1_output_bytes(output : String) -> Bytes {
  let bytes : Array[Byte] = []
  for ch in output {
    let code = ch.to_int()
    if code <= 0xFF {
      bytes.push(code.to_byte())
    } else {
      bytes.push(b'?')
    }
  }
  Bytes::from_array(bytes)
}

///|
pub fn write_dot_bytes(graph : @cgraph.Graph) -> Bytes {
  let output = write_dot(graph)
  if graph_uses_latin1_charset(graph) {
    latin1_output_bytes(output)
  } else {
    @utf8.encode(output, bom=false)
  }
}
