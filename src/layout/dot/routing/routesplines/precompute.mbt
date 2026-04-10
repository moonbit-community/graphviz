// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Routesplines precompute owner: path adjacency, merged routing maps, and
/// global left/right pathplan bounds.

///|
pub struct PathAdjacency {
  out_edges : Map[String, Array[String]]
  in_edges : Map[String, Array[String]]
}

///|
/// Graphviz parity: path adjacency follows layout edge direction (after acyclic reversal).
/// Do not change behavior without updating fixtures/tests.
pub fn build_path_adjacency(
  edges : Array[@cgraph.Edge],
  edge_vnodes : Map[String, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> PathAdjacency {
  let out_edges : Map[String, Array[String]] = Map::new()
  let in_edges : Map[String, Array[String]] = Map::new()
  let mut edge_idx = 0
  for edge in edges {
    let key = @edge_identity.edge_vnode_key(edge)
    let vnodes = match edge_vnodes.get(key) {
      Some(list) => list
      None => []
    }
    let (tail, head) = edge_endpoints_at(edge, edge_idx, edge_tail, edge_head)
    let path_nodes : Array[String] = []
    path_nodes.push(tail)
    for name in vnodes {
      path_nodes.push(name)
    }
    path_nodes.push(head)
    if path_nodes.length() < 2 {
      edge_idx = edge_idx + 1
      continue
    }
    let mut idx = 0
    while idx + 1 < path_nodes.length() {
      let tail = path_nodes[idx]
      let head = path_nodes[idx + 1]
      // Graphviz path adjacency is based on distinct predecessor/successor
      // links in the virtual chain; parallel multiplicity must not duplicate
      // neighbor entries here, or pathplan ordering drifts.
      match out_edges.get(tail) {
        Some(list) => push_unique_string(list, head)
        None => out_edges[tail] = [head]
      }
      match in_edges.get(head) {
        Some(list) => push_unique_string(list, tail)
        None => in_edges[head] = [tail]
      }
      idx = idx + 1
    }
    edge_idx = edge_idx + 1
  }
  { out_edges, in_edges }
}

///|
fn merge_positions(
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
) -> Map[String, @geom.Point] {
  let merged : Map[String, @geom.Point] = Map::new()
  for name, pos in positions {
    merged[name] = pos
  }
  for name, pos in vnode_positions {
    merged[name] = pos
  }
  merged
}

fn pathplan_sizes(
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  _nodesep_pt : Double,
) -> Map[String, NodeSize] {
  let adjusted : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    adjusted[name] = size
  }
  for name, size in vnode_sizes {
    adjusted[name] = size
  }
  adjusted
}

///|
pub(all) struct PathplanBounds {
  left : Double
  right : Double
}

///|
fn compute_horizontal_bounds(
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
) -> PathplanBounds {
  let mut min_rank : Int? = None
  let mut max_rank : Int? = None
  for rank, _ in x_groups {
    match min_rank {
      Some(value) => if rank < value { min_rank = Some(rank) }
      None => min_rank = Some(rank)
    }
    match max_rank {
      Some(value) => if rank > value { max_rank = Some(rank) }
      None => max_rank = Some(rank)
    }
  }
  let (start_rank, end_rank) = match (min_rank, max_rank) {
    (Some(start), Some(end)) => (start, end)
    _ => return { left: 0.0, right: 0.0 }
  }
  let mut left_bound = 0.0
  let mut right_bound = 0.0
  let mut rank = start_rank
  while rank <= end_rank {
    match x_groups.get(rank) {
      Some(names) =>
        if names.length() > 0 {
          let left_name = names[0]
          let right_name = names[names.length() - 1]
          let left_pos = match positions.get(left_name) {
            Some(value) => value
            None => {
              rank = rank + 1
              continue
            }
          }
          let right_pos = match positions.get(right_name) {
            Some(value) => value
            None => {
              rank = rank + 1
              continue
            }
          }
          let left_size = size_for_name(left_name, sizes)
          let right_size = size_for_name(right_name, sizes)
          let left = left_pos.x - left_size.left_pt
          let right = right_pos.x + right_size.right_pt
          if left < left_bound {
            left_bound = left
          }
          if right > right_bound {
            right_bound = right
          }
        }
      None => ()
    }
    left_bound = left_bound - ROUTE_MIN_WIDTH
    right_bound = right_bound + ROUTE_MIN_WIDTH
    rank = rank + 1
  }
  { left: left_bound, right: right_bound }
}

///|
/// Graphviz parity: compute pathplan left/right bounds once (sd.LeftBound/RightBound).
/// Do not change behavior without updating fixtures/tests.
pub fn pathplan_bounds(
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
) -> PathplanBounds {
  let merged_positions = merge_positions(positions, vnode_positions)
  let route_sizes = pathplan_sizes(sizes, vnode_sizes, 0.0)
  compute_horizontal_bounds(merged_positions, route_sizes, x_groups)
}

///|
fn push_unique_string(list : Array[String], value : String) -> Unit {
  for item in list {
    if item == value {
      return ()
    }
  }
  list.push(value)
}

///|
fn edge_endpoints_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (String, String) {
  let tail = if edge_idx < edge_tail.length() {
    edge_tail[edge_idx]
  } else {
    edge.tail().name()
  }
  let head = if edge_idx < edge_head.length() {
    edge_head[edge_idx]
  } else {
    edge.head().name()
  }
  (tail, head)
}
