// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Parse DOT from a file.
#declaration_only
pub async fn parse_dot_file(path : String) -> @cgraph.Graph {
  ...
}

///|
/// Parse DOT file containing one or more graphs.
#declaration_only
pub async fn parse_dot_file_all(path : String) -> Array[@cgraph.Graph] {
  ...
}
