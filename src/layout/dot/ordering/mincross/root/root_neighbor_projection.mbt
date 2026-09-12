// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Keep adjacency insertion order, but consume only the edge multiplicities
/// retained by root class2 projection and parallel-edge merging.
fn project_root_neighbor_hints(
  hints : Map[String, Array[String]],
  edge_sources : Array[String],
  edge_targets : Array[String],
) -> Map[String, Array[String]] {
  let remaining : Map[(String, String), Int] = Map([])
  for index, source in edge_sources {
    let key = (source, edge_targets[index])
    remaining[key] = remaining.get(key).unwrap_or_default() + 1
  }
  let projected : Map[String, Array[String]] = Map([])
  for source, neighbors in hints {
    let retained : Array[String] = []
    for target in neighbors {
      let key = (source, target)
      let count = remaining.get(key).unwrap_or_default()
      guard count > 0 else { continue }
      retained.push(target)
      remaining[key] = count - 1
    }
    projected[source] = retained
  }
  projected
}
