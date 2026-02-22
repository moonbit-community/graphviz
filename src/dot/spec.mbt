///|
/// Source position for parse errors.
struct Position {
  line : Int
  column : Int
  offset : Int
} derive(Show, Eq)

///|
/// DOT parse errors with position info.
pub(all) suberror DotParseError {
  UnexpectedEof(pos~ : Position)
  InvalidToken(pos~ : Position, token~ : String)
  InvalidSyntax(pos~ : Position, message~ : String)
} derive(Show, Eq)

///|
/// Parse DOT source into a cgraph Graph.
#declaration_only
pub fn parse_dot(src : String) -> @cgraph.Graph raise DotParseError {
  ...
}

///|
/// Parse DOT from a file.
#declaration_only
pub fn parse_dot_file(path : String) -> @cgraph.Graph raise DotParseError {
  ...
}

///|
/// Serialize a cgraph Graph to canonical DOT output.
#declaration_only
pub fn write_dot(graph : @cgraph.Graph) -> String {
  ...
}

///|
/// Serialize a cgraph Graph to DOT bytes (Latin1 when charset=latin1).
#declaration_only
pub fn write_dot_bytes(graph : @cgraph.Graph) -> Bytes {
  ...
}
