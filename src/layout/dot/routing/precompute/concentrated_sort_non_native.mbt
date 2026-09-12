// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn sort_concentrated_route_indices(priorities : Array[Int]) -> Array[Int] {
  let indices = priorities.mapi((index, _) => index)
  indices.sort_by((a, b) => priorities[a].compare(priorities[b]))
  indices
}
