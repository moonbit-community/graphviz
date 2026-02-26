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
  bytes : Bytes
  mut index : Int
  mut line : Int
  mut column : Int
}

///|
fn Lexer::new(bytes : Bytes) -> Lexer {
  { bytes, index: 0, line: 1, column: 1 }
}

///|
fn Lexer::position(self : Lexer) -> Position {
  { line: self.line, column: self.column, offset: self.index }
}

///|
fn Lexer::peek_byte(self : Lexer, offset? : Int = 0) -> Byte? {
  self.bytes.get(self.index + offset)
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  let ch = self.peek_byte()
  match ch {
    Some(value) => {
      self.index = self.index + 1
      if value == b'\n' {
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
    let ch = self.peek_byte()
    match ch {
      Some(value) if is_ascii_whitespace_byte(value) => {
        self.advance()
        continue
      }
      Some(value) if value == b'/' => {
        match self.peek_byte(offset=1) {
          Some(next) if next == b'/' => {
            self.advance()
            self.advance()
            while self.peek_byte() is Some(next) && next != b'\n' {
              self.advance()
            }
            continue
          }
          Some(next) if next == b'*' => {
            self.advance()
            self.advance()
            let mut done = false
            while !done {
              let next = self.peek_byte()
              if next is None {
                break
              }
              if next == Some(b'*') && self.peek_byte(offset=1) == Some(b'/') {
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
      Some(value) if value == b'#' => {
        self.advance()
        while self.peek_byte() is Some(next) && next != b'\n' {
          self.advance()
        }
        continue
      }
      _ => break
    }
  }
}

///|
fn is_ascii_whitespace_byte(ch : Byte) -> Bool {
  let code = ch.to_int()
  code == 0x20 ||
    code == 0x09 ||
    code == 0x0a ||
    code == 0x0d ||
    code == 0x0b ||
    code == 0x0c
}

///|
fn is_id_byte(ch : Byte) -> Bool {
  if ch.to_int() < 0x80 {
    (ch >= b'a' && ch <= b'z') ||
      (ch >= b'A' && ch <= b'Z') ||
      (ch >= b'0' && ch <= b'9') ||
      ch == b'_' ||
      ch == b'.'
  } else {
    true
  }
}

///|
fn decode_bytes(view : BytesView) -> String {
  try @utf8.decode(view) catch {
    _ => view.to_string()
  } noraise {
    text => text
  }
}

///|
fn Lexer::read_quoted_string(self : Lexer) -> String raise DotParseError {
  let start = self.position()
  self.advance()
  let start_index = self.index
  while true {
    let ch = self.peek_byte()
    match ch {
      None => raise DotParseError::UnexpectedEof(pos=start)
      Some(value) if value == b'"' => {
        let end_index = self.index
        self.advance()
        let view = self.bytes[start_index:end_index]
        return decode_bytes(view)
      }
      Some(value) if value == b'\\' => {
        self.advance()
        let escaped = self.peek_byte()
        match escaped {
          None => raise DotParseError::UnexpectedEof(pos=start)
          Some(_) => self.advance()
        }
      }
      Some(_) => {
        self.advance()
      }
    }
  }
  ""
}

///|
fn Lexer::read_html(self : Lexer) -> String raise DotParseError {
  let start = self.position()
  let start_index = self.index
  self.advance()
  let mut depth = 1
  while true {
    let ch = self.peek_byte()
    match ch {
      None => raise DotParseError::UnexpectedEof(pos=start)
      Some(value) => {
        self.advance()
        if value == b'<' {
          depth = depth + 1
        } else if value == b'>' {
          depth = depth - 1
          if depth == 0 {
            let end_index = self.index
            let view = self.bytes[start_index:end_index]
            return decode_bytes(view)
          }
        }
      }
    }
  }
  ""
}

///|
fn Lexer::read_id(self : Lexer) -> String {
  let start = self.index
  while self.peek_byte() is Some(ch) && is_id_byte(ch) {
    self.advance()
  }
  let view = self.bytes[start:self.index]
  decode_bytes(view)
}

///|
fn Lexer::next_token(self : Lexer) -> TokenWithPos raise DotParseError {
  self.skip_whitespace_and_comments()
  let pos = self.position()
  let ch = self.peek_byte()
  match ch {
    None => { token: Eof, pos }
    Some(value) if value == b'{' => {
      self.advance()
      { token: LBrace, pos }
    }
    Some(value) if value == b'}' => {
      self.advance()
      { token: RBrace, pos }
    }
    Some(value) if value == b'[' => {
      self.advance()
      { token: LBracket, pos }
    }
    Some(value) if value == b']' => {
      self.advance()
      { token: RBracket, pos }
    }
    Some(value) if value == b';' => {
      self.advance()
      { token: Semi, pos }
    }
    Some(value) if value == b',' => {
      self.advance()
      { token: Comma, pos }
    }
    Some(value) if value == b'=' => {
      self.advance()
      { token: Eq, pos }
    }
    Some(value) if value == b':' => {
      self.advance()
      { token: Colon, pos }
    }
    Some(value) if value == b'-' =>
      match self.peek_byte(offset=1) {
        Some(next) if next == b'>' => {
          self.advance()
          self.advance()
          { token: EdgeDirected, pos }
        }
        Some(next) if next == b'-' => {
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
    Some(value) if value == b'\"' => {
      let value = self.read_quoted_string()
      { token: String(value), pos }
    }
    Some(value) if value == b'<' =>
      {
        let value = self.read_html()
        { token: Html(value), pos }
      }
    Some(value) if is_id_byte(value) => {
      let id = self.read_id()
      { token: Id(id), pos }
    }
    Some(value) =>
      raise DotParseError::InvalidToken(
        pos~,
        token=value.to_char().to_string(),
      )
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
