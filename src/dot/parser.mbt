///|
priv struct Parser {
  lexer : Lexer
  mut current : TokenWithPos
  mut next : TokenWithPos
}

///|
priv struct NodeId {
  name : String
  port : @cgraph.Port?
}

///|
priv enum Endpoint {
  Node(NodeId)
  Subgraph(@cgraph.Graph)
}

///|
fn dot_parse_trace(message : String) -> Unit {
  if @sys.get_env_var("DOT_TRACE") is Some(_) {
    println(message)
  }
}

///|
fn Parser::new(src : String) -> Parser raise DotParseError {
  let bytes = @utf8.encode(src, bom=false)
  let lexer = Lexer::new(bytes)
  let current = lexer.next_token()
  let next = lexer.next_token()
  dot_parse_trace("dot: first token=\{token_label(current.token)}")
  { lexer, current, next }
}

///|
fn Parser::advance(self : Parser) -> Unit raise DotParseError {
  self.current = self.next
  self.next = self.lexer.next_token()
}

///|
fn Parser::is_keyword(self : Parser, keyword : String) -> Bool {
  match self.current.token {
    Id(value) => value == keyword
    _ => false
  }
}

///|

///|
fn Parser::expect_token(
  self : Parser,
  expected : Token,
) -> Unit raise DotParseError {
  if self.current.token == expected {
    self.advance()
  } else {
    raise DotParseError::InvalidToken(
      pos=self.current.pos,
      token=token_label(self.current.token),
    )
  }
}

///|
fn Parser::parse_id(self : Parser) -> String raise DotParseError {
  match self.current.token {
    Id(value) => {
      self.advance()
      value
    }
    String(value) => {
      self.advance()
      value
    }
    Html(value) => {
      self.advance()
      value
    }
    _ =>
      raise DotParseError::InvalidToken(
        pos=self.current.pos,
        token=token_label(self.current.token),
      )
  }
}

///|
fn compass_from_string(value : String) -> @cgraph.Compass? {
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
fn Parser::parse_node_id(self : Parser) -> NodeId raise DotParseError {
  let name = self.parse_id()
  let mut port : @cgraph.Port? = None
  if self.current.token == Colon {
    self.advance()
    let first = self.parse_id()
    let mut name_value : String? = None
    let mut compass : @cgraph.Compass? = None
    if self.current.token == Colon {
      self.advance()
      let second = self.parse_id()
      name_value = Some(first)
      compass = compass_from_string(second)
    } else {
      let compass_guess = compass_from_string(first)
      match compass_guess {
        Some(value) => compass = Some(value)
        None => name_value = Some(first)
      }
    }
    port = Some({ name: name_value, compass })
  }
  { name, port }
}

///|
fn Parser::parse_attr_list(
  self : Parser,
) -> Map[String, String] raise DotParseError {
  let attrs : Map[String, String] = Map::new()
  while self.current.token == LBracket {
    self.advance()
    while self.current.token != RBracket && self.current.token != Eof {
      if self.current.token == Comma || self.current.token == Semi {
        self.advance()
        continue
      }
      let key = self.parse_id()
      let mut value = ""
      if self.current.token == Eq {
        self.advance()
        value = self.parse_id()
      }
      attrs[key] = value
      if self.current.token == Comma || self.current.token == Semi {
        self.advance()
      }
    }
    self.expect_token(RBracket)
  }
  attrs
}

///|
fn Parser::parse_subgraph(
  self : Parser,
  graph : @cgraph.Graph,
) -> @cgraph.Graph raise DotParseError {
  let mut name : String? = None
  if self.is_keyword("subgraph") {
    self.advance()
    if self.current.token != LBrace {
      name = Some(self.parse_id())
    }
  }
  let subgraph = match name {
    Some(label) => graph.subgraph(name=label)
    None => graph.subgraph()
  }
  if self.current.token == LBrace {
    self.advance()
    self.parse_stmt_list(subgraph)
    self.expect_token(RBrace)
  }
  subgraph
}

///|
fn Parser::parse_endpoint(
  self : Parser,
  graph : @cgraph.Graph,
) -> Endpoint raise DotParseError {
  if self.is_keyword("subgraph") || self.current.token == LBrace {
    Endpoint::Subgraph(self.parse_subgraph(graph))
  } else {
    Endpoint::Node(self.parse_node_id())
  }
}

///|
fn Parser::endpoint_nodes(
  graph : @cgraph.Graph,
  endpoint : Endpoint,
) -> (Array[@cgraph.Node], @cgraph.Port?) {
  match endpoint {
    Node(node_id) => {
      let node = match graph.find_node(node_id.name) {
        Some(value) => value
        None => graph.node(node_id.name)
      }
      ([node], node_id.port)
    }
    Subgraph(sub) => (sub.nodes(), None)
  }
}

///|
fn Parser::parse_edge_stmt(
  self : Parser,
  graph : @cgraph.Graph,
  left : Endpoint,
) -> Unit raise DotParseError {
  let endpoints : Array[Endpoint] = [left]
  while self.current.token == EdgeDirected ||
        self.current.token == EdgeUndirected {
    let op = self.current.token
    if graph.kind() == @cgraph.GraphKind::Directed && op != EdgeDirected {
      raise DotParseError::InvalidSyntax(
        pos=self.current.pos,
        message="undirected edge in digraph",
      )
    }
    if graph.kind() == @cgraph.GraphKind::Undirected && op != EdgeUndirected {
      raise DotParseError::InvalidSyntax(
        pos=self.current.pos,
        message="directed edge in graph",
      )
    }
    self.advance()
    endpoints.push(self.parse_endpoint(graph))
  }
  let attrs = self.parse_attr_list()
  for i in 0..<(endpoints.length() - 1) {
    let (left_nodes, left_port) = Parser::endpoint_nodes(graph, endpoints[i])
    let (right_nodes, right_port) = Parser::endpoint_nodes(
      graph,
      endpoints[i + 1],
    )
    for tail in left_nodes {
      for head in right_nodes {
        let edge = match left_port {
          Some(tail_port) =>
            match right_port {
              Some(head_port) => graph.edge(tail, head, tail_port~, head_port~)
              None => graph.edge(tail, head, tail_port~)
            }
          None =>
            match right_port {
              Some(head_port) => graph.edge(tail, head, head_port~)
              None => graph.edge(tail, head)
            }
        }
        for key, value in attrs {
          edge.set_attr(key, value)
        }
      }
    }
  }
}

///|
fn Parser::parse_stmt(
  self : Parser,
  graph : @cgraph.Graph,
) -> Unit raise DotParseError {
  if self.is_keyword("graph") && self.next.token == LBracket {
    self.advance()
    let attrs = self.parse_attr_list()
    for key, value in attrs {
      graph.set_default_attr(@cgraph.AttrKind::Graph, key, value)
    }
    return
  }
  if self.is_keyword("node") && self.next.token == LBracket {
    self.advance()
    let attrs = self.parse_attr_list()
    for key, value in attrs {
      graph.set_default_attr(@cgraph.AttrKind::Node, key, value)
    }
    return
  }
  if self.is_keyword("edge") && self.next.token == LBracket {
    self.advance()
    let attrs = self.parse_attr_list()
    for key, value in attrs {
      graph.set_default_attr(@cgraph.AttrKind::Edge, key, value)
    }
    return
  }
  if self.is_keyword("subgraph") || self.current.token == LBrace {
    let subgraph = self.parse_subgraph(graph)
    if self.current.token == EdgeDirected ||
      self.current.token == EdgeUndirected {
      self.parse_edge_stmt(graph, Endpoint::Subgraph(subgraph))
    }
    return
  }
  let node_id = self.parse_node_id()
  if self.current.token == Eq {
    self.advance()
    let value = self.parse_id()
    graph.set_attr(node_id.name, value)
    return
  }
  if self.current.token == EdgeDirected || self.current.token == EdgeUndirected {
    self.parse_edge_stmt(graph, Endpoint::Node(node_id))
    return
  }
  let node = graph.node(node_id.name)
  let attrs = self.parse_attr_list()
  for key, value in attrs {
    node.set_attr(key, value)
  }
}

///|
fn Parser::parse_stmt_list(
  self : Parser,
  graph : @cgraph.Graph,
) -> Unit raise DotParseError {
  while self.current.token != RBrace && self.current.token != Eof {
    self.parse_stmt(graph)
    while self.current.token == Semi {
      self.advance()
    }
  }
}

///|
fn Parser::parse_graph(self : Parser) -> @cgraph.Graph raise DotParseError {
  let mut strict = false
  if self.is_keyword("strict") {
    strict = true
    self.advance()
  }
  let kind = if self.is_keyword("digraph") {
    self.advance()
    @cgraph.GraphKind::Directed
  } else if self.is_keyword("graph") {
    self.advance()
    @cgraph.GraphKind::Undirected
  } else {
    raise DotParseError::InvalidSyntax(
      pos=self.current.pos,
      message="expected graph or digraph",
    )
  }
  let name = if self.current.token == LBrace {
    None
  } else {
    Some(self.parse_id())
  }
  self.expect_token(LBrace)
  let graph = match name {
    Some(label) => @cgraph.Graph::new(kind, name=label, strict~)
    None => @cgraph.Graph::new(kind, strict~)
  }
  self.parse_stmt_list(graph)
  self.expect_token(RBrace)
  graph
}

///|
pub fn parse_dot(src : String) -> @cgraph.Graph raise DotParseError {
  let parser = Parser::new(src)
  let graph = parser.parse_graph()
  if parser.current.token != Eof {
    raise DotParseError::InvalidSyntax(
      pos=parser.current.pos,
      message="trailing tokens",
    )
  }
  graph
}

///|
pub fn parse_dot_file(path : String) -> @cgraph.Graph raise DotParseError {
  let bytes = try @fs.read_file_to_bytes(path) catch {
    err =>
      raise DotParseError::InvalidSyntax(
        pos={ line: 1, column: 1, offset: 0 },
        message=err.to_string(),
      )
  } noraise {
    data => data
  }
  let src = try @utf8.decode(bytes) catch {
    _ => {
      let buf = @buffer.new(size_hint=bytes.length() * 2)
      for b in bytes {
        let value = b.to_int()
        if value < 0x80 {
          buf.write_byte(b)
        } else {
          let upper = (0xC0 + (value >> 6)).to_byte()
          let lower = (0x80 + (value & 0x3F)).to_byte()
          buf.write_byte(upper)
          buf.write_byte(lower)
        }
      }
      let utf8_bytes = buf.to_bytes()
      try @utf8.decode(utf8_bytes) catch {
        _ =>
          raise DotParseError::InvalidSyntax(
            pos={ line: 1, column: 1, offset: 0 },
            message="invalid utf8",
          )
      } noraise {
        text => text
      }
    }
  } noraise {
    text => text
  }
  parse_dot(src)
}
