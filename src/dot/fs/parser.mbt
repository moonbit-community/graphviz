// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
async fn decode_dot_file(path : String) -> (String, Bool) {
  let bytes = try @async_fs.read_file(path).binary() catch {
    err =>
      raise @dot.DotParseError::InvalidSyntax(
        pos={ line: 1, column: 1, offset: 0 },
        message="\{err}",
      )
  } noraise {
    data => data
  }
  let mut used_latin1_fallback = false
  let src = try @utf8.decode(bytes) catch {
    _ => {
      used_latin1_fallback = true
      let buf = Buffer(size_hint=bytes.length() * 2)
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
          raise @dot.DotParseError::InvalidSyntax(
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
  (src, used_latin1_fallback)
}

///|
pub async fn parse_dot_file(path : String) -> @cgraph.Graph {
  let (src, used_latin1_fallback) = decode_dot_file(path)
  let graph = @dot.parse_dot(src)
  if used_latin1_fallback {
    graph.set_attr(@dot.INPUT_LATIN1_FALLBACK_ATTR, "true")
  }
  graph
}

///|
pub async fn parse_dot_file_all(path : String) -> Array[@cgraph.Graph] {
  let (src, used_latin1_fallback) = decode_dot_file(path)
  let graphs = @dot.parse_dot_all(src)
  if used_latin1_fallback {
    for graph in graphs {
      graph.set_attr(@dot.INPUT_LATIN1_FALLBACK_ATTR, "true")
    }
  }
  graphs
}
