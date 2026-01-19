///|
fn is_plain_id(id : String) -> Bool {
  if id is "" {
    return false
  }
  let mut first = true
  for ch in id {
    if first {
      if !(ch.is_ascii_alphabetic() || ch == '_') {
        return false
      }
      first = false
      continue
    }
    if !(ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_') {
      return false
    }
  }
  true
}

///|
fn is_numeric_id(id : String) -> Bool {
  if id is "" {
    return false
  }
  let mut has_digit = false
  for ch in id {
    if ch.is_ascii_digit() {
      has_digit = true
    } else if ch == '.' {
      continue
    } else {
      return false
    }
  }
  has_digit
}

///|
fn write_quoted(raw : String) -> String {
  let sb = StringBuilder::new()
  sb.write_char('"')
  let mut pending_escape = false
  for ch in raw {
    if pending_escape {
      sb.write_char('\\')
      sb.write_char(ch)
      pending_escape = false
      continue
    }
    if ch == '\\' {
      pending_escape = true
      continue
    }
    match ch {
      '"' => sb.write_string("\\\"")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(ch)
    }
  }
  if pending_escape {
    sb.write_char('\\')
  }
  sb.write_char('"')
  sb.to_string()
}

///|
fn write_id(id : String) -> String {
  if id.has_prefix("<<") && id.has_suffix(">>") {
    return id
  }
  if is_plain_id(id) || is_numeric_id(id) {
    return id
  }
  write_quoted(id)
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
        None => {
          match value.compass {
            Some(compass) => out = ":\{compass_label(compass)}"
            None => ()
          }
        }
      }
      out
    }
  }
}

///|
fn write_attr_list(sb : StringBuilder, attrs : Array[(String, String)]) -> Unit {
  if attrs.length() == 0 {
    return
  }
  sb.write_string("[")
  for i, pair in attrs {
    let (key, value) = pair
    if i > 0 {
      sb.write_string(", ")
    }
    sb.write_string(write_id(key))
    if value != "" {
      sb.write_char('=')
      sb.write_string(write_id(value))
    }
  }
  sb.write_string("]")
}

///|
fn write_indent(sb : StringBuilder, indent : Int) -> Unit {
  for _ in 0..<indent {
    sb.write_char(' ')
  }
}

///|
fn write_graph(
  graph : @cgraph.Graph,
  sb : StringBuilder,
  indent : Int,
  is_root : Bool,
) -> Unit {
  write_indent(sb, indent)
  if is_root {
    if graph.is_strict() {
      sb.write_string("strict ")
    }
    let kind = match graph.kind() {
      @cgraph.GraphKind::Directed => "digraph"
      @cgraph.GraphKind::Undirected => "graph"
    }
    sb.write_string(kind)
  } else {
    sb.write_string("subgraph")
  }
  match graph.name() {
    Some(name) => {
      sb.write_char(' ')
      sb.write_string(write_id(name))
    }
    None => ()
  }
  sb.write_string(" {\n")
  let inner = indent + 2

  let graph_defaults = graph.default_attrs(@cgraph.AttrKind::Graph)
  if graph_defaults.length() > 0 {
    write_indent(sb, inner)
    sb.write_string("graph ")
    write_attr_list(sb, graph_defaults)
    sb.write_string(";\n")
  }
  let node_defaults = graph.default_attrs(@cgraph.AttrKind::Node)
  if node_defaults.length() > 0 {
    write_indent(sb, inner)
    sb.write_string("node ")
    write_attr_list(sb, node_defaults)
    sb.write_string(";\n")
  }
  let edge_defaults = graph.default_attrs(@cgraph.AttrKind::Edge)
  if edge_defaults.length() > 0 {
    write_indent(sb, inner)
    sb.write_string("edge ")
    write_attr_list(sb, edge_defaults)
    sb.write_string(";\n")
  }

  for pair in graph.attrs() {
    let (key, value) = pair
    write_indent(sb, inner)
    sb.write_string(write_id(key))
    sb.write_string("=")
    sb.write_string(write_id(value))
    sb.write_string(";\n")
  }

  for subgraph in graph.subgraphs() {
    write_graph(subgraph, sb, inner, false)
  }

  let nodes = graph.nodes()
  nodes.sort_by_key((node) => node.name())
  for node in nodes {
    write_indent(sb, inner)
    sb.write_string(write_id(node.name()))
    let attrs = node.attrs()
    if attrs.length() > 0 {
      sb.write_char(' ')
      write_attr_list(sb, attrs)
    }
    sb.write_string(";\n")
  }

  if graph.is_root() {
    let edge_op = match graph.kind() {
      @cgraph.GraphKind::Directed => "->"
      @cgraph.GraphKind::Undirected => "--"
    }
    for edge in graph.edges() {
      let tail = edge.tail()
      let head = edge.head()
      write_indent(sb, inner)
      sb.write_string(write_id(tail.name()))
      sb.write_string(write_port(edge.tail_port()))
      sb.write_char(' ')
      sb.write_string(edge_op)
      sb.write_char(' ')
      sb.write_string(write_id(head.name()))
      sb.write_string(write_port(edge.head_port()))
      let attrs = edge.attrs()
      if attrs.length() > 0 {
        sb.write_char(' ')
        write_attr_list(sb, attrs)
      }
      sb.write_string(";\n")
    }
  }

  write_indent(sb, indent)
  sb.write_string("}\n")
}

///|
pub fn write_dot(graph : @cgraph.Graph) -> String {
  let sb = StringBuilder::new()
  write_graph(graph, sb, 0, true)
  sb.to_string()
}
