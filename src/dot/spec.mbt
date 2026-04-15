// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Source position for parse errors.
struct Position {
  line : Int
  column : Int
  offset : Int
} derive(Debug, Eq)

///|
/// DOT parse errors with position info.
pub(all) suberror DotParseError {
  UnexpectedEof(pos~ : Position)
  InvalidToken(pos~ : Position, token~ : String)
  InvalidSyntax(pos~ : Position, message~ : String)
} derive(Debug, Eq)

///|
/// Parse DOT source into a cgraph Graph.
#declaration_only
pub fn parse_dot(src : String) -> @cgraph.Graph raise DotParseError {
  ...
}

///|
/// Parse DOT source containing one or more graphs.
#declaration_only
pub fn parse_dot_all(src : String) -> Array[@cgraph.Graph] raise DotParseError {
  ...
}

///|
/// Parse DOT from a file.
#declaration_only
pub fn parse_dot_file(path : String) -> @cgraph.Graph raise DotParseError {
  ...
}

///|
/// Parse DOT file containing one or more graphs.
#declaration_only
pub fn parse_dot_file_all(
  path : String,
) -> Array[@cgraph.Graph] raise DotParseError {
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
