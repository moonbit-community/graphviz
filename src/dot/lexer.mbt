///|
priv enum Token {
  Id(String)
  String(String)
  Html(String)
  LBrace
  RBrace
  LBracket
  RBracket
  Semi
  Comma
  Eq
  Colon
  EdgeDirected
  EdgeUndirected
  Eof
} derive(Eq)

///|
priv struct TokenWithPos {
  token : Token
  pos : Position
}

///|
priv struct Lexer {
  src : String
  mut index : Int
  mut line : Int
  mut column : Int
}

///|
fn Lexer::new(src : String) -> Lexer {
  { src, index: 0, line: 1, column: 1 }
}

///|
fn Lexer::position(self : Lexer) -> Position {
  { line: self.line, column: self.column, offset: self.index }
}

///|
fn Lexer::peek_char(self : Lexer, offset? : Int = 0) -> Char? {
  self.src.get_char(self.index + offset)
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  let ch = self.peek_char()
  match ch {
    Some(value) => {
      self.index = self.index + 1
      if value == '\n' {
        self.line = self.line + 1
        self.column = 1
      } else {
        self.column = self.column + 1
      }
    }
    None => ()
  }
}

///|
fn Lexer::skip_whitespace_and_comments(self : Lexer) -> Unit {
  while true {
    let ch = self.peek_char()
    match ch {
      Some(value) if value.is_ascii_whitespace() => {
        self.advance()
        continue
      }
      Some('/') => {
        match self.peek_char(offset=1) {
          Some('/') => {
            self.advance()
            self.advance()
            while self.peek_char() is Some(next) && next != '\n' {
              self.advance()
            }
            continue
          }
          Some('*') => {
            self.advance()
            self.advance()
            let mut done = false
            while !done {
              let next = self.peek_char()
              if next is None {
                break
              }
              if next == Some('*') && self.peek_char(offset=1) == Some('/') {
                self.advance()
                self.advance()
                done = true
              } else {
                self.advance()
              }
            }
            continue
          }
          _ => ()
        }
        break
      }
      Some('#') => {
        self.advance()
        while self.peek_char() is Some(next) && next != '\n' {
          self.advance()
        }
        continue
      }
      _ => break
    }
  }
}

///|
fn is_id_char(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_' || ch == '.'
}

///|
fn Lexer::read_quoted_string(self : Lexer) -> String raise DotParseError {
  let start = self.position()
  self.advance()
  let sb = StringBuilder::new()
  while true {
    let ch = self.peek_char()
    match ch {
      None => raise DotParseError::UnexpectedEof(pos=start)
      Some('"') => {
        self.advance()
        break
      }
      Some('\\') => {
        self.advance()
        let escaped = self.peek_char()
        match escaped {
          None => raise DotParseError::UnexpectedEof(pos=start)
          Some(value) => {
            self.advance()
            sb.write_char('\\')
            sb.write_char(value)
          }
        }
      }
      Some(value) => {
        self.advance()
        sb.write_char(value)
      }
    }
  }
  sb.to_string()
}

///|
fn Lexer::read_html(self : Lexer) -> String raise DotParseError {
  let start = self.position()
  let sb = StringBuilder::new()
  self.advance()
  self.advance()
  sb.write_string("<<")
  let mut depth = 2
  while true {
    let ch = self.peek_char()
    match ch {
      None => raise DotParseError::UnexpectedEof(pos=start)
      Some(value) => {
        self.advance()
        sb.write_char(value)
        if value == '<' {
          depth = depth + 1
        } else if value == '>' {
          depth = depth - 1
          if depth == 0 {
            break
          }
        }
      }
    }
  }
  sb.to_string()
}

///|
fn Lexer::read_id(self : Lexer) -> String {
  let sb = StringBuilder::new()
  while self.peek_char() is Some(ch) && is_id_char(ch) {
    self.advance()
    sb.write_char(ch)
  }
  sb.to_string()
}

///|
fn Lexer::next_token(self : Lexer) -> TokenWithPos raise DotParseError {
  self.skip_whitespace_and_comments()
  let pos = self.position()
  let ch = self.peek_char()
  match ch {
    None => { token: Eof, pos }
    Some('{') => {
      self.advance()
      { token: LBrace, pos }
    }
    Some('}') => {
      self.advance()
      { token: RBrace, pos }
    }
    Some('[') => {
      self.advance()
      { token: LBracket, pos }
    }
    Some(']') => {
      self.advance()
      { token: RBracket, pos }
    }
    Some(';') => {
      self.advance()
      { token: Semi, pos }
    }
    Some(',') => {
      self.advance()
      { token: Comma, pos }
    }
    Some('=') => {
      self.advance()
      { token: Eq, pos }
    }
    Some(':') => {
      self.advance()
      { token: Colon, pos }
    }
    Some('-') =>
      match self.peek_char(offset=1) {
        Some('>') => {
          self.advance()
          self.advance()
          { token: EdgeDirected, pos }
        }
        Some('-') => {
          self.advance()
          self.advance()
          { token: EdgeUndirected, pos }
        }
        _ => {
          self.advance()
          let rest = self.read_id()
          let id = if rest == "" { "-" } else { "-\{rest}" }
          { token: Id(id), pos }
        }
      }
    Some('"') => {
      let value = self.read_quoted_string()
      { token: String(value), pos }
    }
    Some('<') =>
      if self.peek_char(offset=1) == Some('<') {
        let value = self.read_html()
        { token: Html(value), pos }
      } else {
        let id = self.read_id()
        { token: Id(id), pos }
      }
    Some(value) if is_id_char(value) => {
      let id = self.read_id()
      { token: Id(id), pos }
    }
    Some(value) =>
      raise DotParseError::InvalidToken(pos~, token=value.to_string())
  }
}

///|
fn token_label(token : Token) -> String {
  match token {
    Id(value) => "id(\{value})"
    String(value) => "string(\{value})"
    Html(_) => "html"
    LBrace => "{"
    RBrace => "}"
    LBracket => "["
    RBracket => "]"
    Semi => ";"
    Comma => ","
    Eq => "="
    Colon => ":"
    EdgeDirected => "->"
    EdgeUndirected => "--"
    Eof => "eof"
  }
}
