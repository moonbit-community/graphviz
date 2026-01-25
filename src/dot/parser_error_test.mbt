///|
test "parse_dot reports invalid token at start" {
  let result : Result[@cgraph.Graph, DotParseError] = try? @dot.parse_dot("@")
  match result {
    Err(DotParseError::InvalidToken(pos~, token~)) => {
      ignore(pos)
      assert_eq(token, "@")
    }
    _ => fail("expected InvalidToken")
  }
}

///|
test "parse_dot requires graph or digraph" {
  let result : Result[@cgraph.Graph, DotParseError] =
    try? @dot.parse_dot("node { }")
  match result {
    Err(DotParseError::InvalidSyntax(pos~, message~)) => {
      ignore(pos)
      assert_eq(message, "expected graph or digraph")
    }
    _ => fail("expected InvalidSyntax")
  }
}

///|
test "parse_dot rejects undirected edges in digraph" {
  let result : Result[@cgraph.Graph, DotParseError] =
    try? @dot.parse_dot("digraph { a -- b; }")
  match result {
    Err(DotParseError::InvalidSyntax(pos~, message~)) => {
      ignore(pos)
      assert_eq(message, "undirected edge in digraph")
    }
    _ => fail("expected InvalidSyntax")
  }
}

///|
test "parse_dot flags trailing tokens" {
  let result : Result[@cgraph.Graph, DotParseError] =
    try? @dot.parse_dot("digraph { a } extra")
  match result {
    Err(DotParseError::InvalidSyntax(pos~, message~)) => {
      ignore(pos)
      assert_eq(message, "trailing tokens")
    }
    _ => fail("expected InvalidSyntax")
  }
}

///|
test "parse_dot reports unexpected eof in strings" {
  let result : Result[@cgraph.Graph, DotParseError] = try? @dot.parse_dot("\"")
  match result {
    Err(DotParseError::UnexpectedEof(pos~)) => ignore(pos)
    _ => fail("expected UnexpectedEof")
  }
}
