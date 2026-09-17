// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
pub(all) struct ConcentratedSegment {
  tail : String
  head : String
  vnodes : Array[String]
}

///|
priv struct ConcentratedAuxiliaryRoutes {
  flat_out : Map[String, Array[@cgraph.Edge]]
  other : Map[String, Array[@cgraph.Edge]]
  main_edges : Map[Int, @cgraph.Edge]
}

///|
/// ND_flat_out and ND_other participate in the same qsort as live chains,
/// even though they do not produce concentrated junction segments.
fn concentrated_auxiliary_routes(
  fast : @setup.ConcentrateFastGraph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
) -> ConcentratedAuxiliaryRoutes {
  let flat_out : Map[String, Array[@cgraph.Edge]] = Map([])
  let other : Map[String, Array[@cgraph.Edge]] = Map([])
  let main_edges : Map[Int, @cgraph.Edge] = Map([])
  let fast_owners : Map[Int, Bool] = Map([])
  let representatives : Map[String, @cgraph.Edge] = Map([])
  let parallel_key = (edge : @cgraph.Edge) => {
    @edge_ops.edge_parallel_key(
      edge.tail().name(),
      edge.head().name(),
      edge.tail_port(),
      edge.head_port(),
    )
  }
  for edge in fast.edges {
    guard edge.original is Some(owner) else { continue }
    fast_owners[owner.id()] = true
    representatives[parallel_key(owner)] = owner
  }
  let flat_representatives : Map[String, @cgraph.Edge] = Map([])
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let flat = ranks.get(tail) == ranks.get(head)
    let adjacency = if flat {
      let key = "\{tail}|\{head}"
      if flat_representatives.get(key) is Some(main) {
        main_edges[edge.id()] = main
        other
      } else {
        flat_representatives[key] = edge
        main_edges[edge.id()] = edge
        if tail == head {
          other
        } else {
          flat_out
        }
      }
    } else {
      guard fast_owners.get(edge.id()) is None &&
        @membership.node_cluster_key(edge.tail()) !=
        @membership.node_cluster_key(edge.head()) else {
        continue
      }
      guard representatives.get(parallel_key(edge)) is Some(main) else {
        continue
      }
      main_edges[edge.id()] = main
      other
    }
    if adjacency.get(tail) is Some(group) {
      group.push(edge)
    } else {
      adjacency[tail] = [edge]
    }
  }
  { flat_out, other, main_edges, }
}

///|
priv struct ConcentratedRouteEntry {
  owner : Int
  main : @cgraph.Edge
  segment : ConcentratedSegment
  ports : (@geom.Point?, @geom.Point?)
  auxiliary : Bool
  edge_type : Int
}

///|
fn compare_concentrated_ports(
  first : @geom.Point?,
  second : @geom.Point?,
) -> Int {
  guard first is Some(a) else { if second is Some(_) { -1 } else { 0 } }
  guard second is Some(b) else { 1 }
  guard a.x == b.x else { a.x.compare(b.x) }
  a.y.compare(b.y)
}

///|
/// edgecmp compares ports inherited by the first fast edge, falling back to
/// the main edge only when neither fast endpoint has a defined port.
fn compare_concentrated_entries(
  first : ConcentratedRouteEntry,
  second : ConcentratedRouteEntry,
  ranks : Map[String, Int],
  positions : Map[String, @geom.Point],
) -> Int {
  guard first.edge_type == second.edge_type else {
    second.edge_type.compare(first.edge_type)
  }
  let a = first.main
  let b = second.main
  let a_span = (ranks[a.tail().name()] - ranks[a.head().name()]).abs()
  let b_span = (ranks[b.tail().name()] - ranks[b.head().name()]).abs()
  guard a_span == b_span else { a_span.compare(b_span) }
  let a_dx = (positions[a.tail().name()].x - positions[a.head().name()].x).abs()
  let b_dx = (positions[b.tail().name()].x - positions[b.head().name()].x).abs()
  guard a_dx == b_dx else { a_dx.compare(b_dx) }
  guard a.id() == b.id() else { a.id().compare(b.id()) }
  let tail_order = compare_concentrated_ports(first.ports.0, second.ports.0)
  guard tail_order == 0 else { tail_order }
  let head_order = compare_concentrated_ports(first.ports.1, second.ports.1)
  guard head_order == 0 else { head_order }
  guard first.auxiliary == second.auxiliary else {
    if first.auxiliary {
      1
    } else {
      -1
    }
  }
  first.owner.compare(second.owner)
}

///|
/// dotsplines starts at real nodes and splineMerge nodes, then follows the
/// live chain only as far as the next real node or junction. The first fast
/// edge's original owns the resulting spline, including interior segments.
fn collect_concentrated_segments(
  fast : @setup.ConcentrateFastGraph,
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  positions : Map[String, @geom.Point],
  edges? : Array[@cgraph.Edge] = [],
  initial_port_points? : Map[Int, (@geom.Point?, @geom.Point?)] = {},
  route_order? : Map[Int, Int] = {},
) -> Map[Int, Array[ConcentratedSegment]] {
  let segments : Map[Int, Array[ConcentratedSegment]] = Map([])
  let entries : Array[ConcentratedRouteEntry] = []
  let auxiliary = concentrated_auxiliary_routes(fast, edges, ranks)
  let order_index = @rank_groups.build_order_index(groups)
  let junction = name => {
    fast.incoming.get(name).unwrap_or_default().length() > 1 ||
    fast.outgoing.get(name).unwrap_or_default().length() > 1
  }
  let rank_keys = groups.keys().to_array()
  rank_keys.sort()
  for rank in rank_keys {
    for tail in groups[rank] {
      let outgoing = fast.outgoing.get(tail).unwrap_or_default()
      guard !@edge_identity.is_edge_vnode_name(tail) || junction(tail) else {
        continue
      }
      for index in outgoing {
        let edge = fast.edges[index]
        guard edge.original is Some(owner) else { continue }
        let vnodes : Array[String] = []
        let head = for head = edge.head {
          guard @edge_identity.is_edge_vnode_name(head) && !junction(head) else {
            break head
          }
          let next = fast.outgoing.get(head).unwrap_or_default()
          guard next.length() == 1 else { break head }
          vnodes.push(head)
          continue fast.edges[next[0]].head
        }
        let original_ports = initial_port_points
          .get(owner.id())
          .unwrap_or((None, None))
        let tail_port = if edge.tail_port is Some(_) {
          if edge.tail == owner.tail().name() {
            original_ports.0
          } else {
            original_ports.1
          }
        } else {
          None
        }
        let head_port = if edge.head_port is Some(_) {
          if edge.head == owner.head().name() {
            original_ports.1
          } else {
            original_ports.0
          }
        } else {
          None
        }
        let ports = if tail_port is Some(_) || head_port is Some(_) {
          (tail_port, head_port)
        } else {
          original_ports
        }
        entries.push({
          owner: owner.id(),
          main: owner,
          segment: { tail, head, vnodes, },
          ports,
          auxiliary: false,
          edge_type: 1,
        })
      }
      for adjacency in [auxiliary.flat_out, auxiliary.other] {
        for edge in adjacency.get(tail).unwrap_or_default() {
          let main = auxiliary.main_edges[edge.id()]
          let own_ports = initial_port_points
            .get(edge.id())
            .unwrap_or((None, None))
          let defined = own_ports.0 is Some(_) || own_ports.1 is Some(_)
          let ports = if defined {
            own_ports
          } else {
            initial_port_points.get(main.id()).unwrap_or((None, None))
          }
          let port_edge = if defined { edge } else { main }
          let reverse = auxiliary.main_edges.get(port_edge.id()) is Some(_) &&
            (
              ranks[port_edge.tail().name()] > ranks[port_edge.head().name()] ||
              (
                ranks[port_edge.tail().name()] == ranks[port_edge.head().name()] &&
                order_index[port_edge.tail().name()] >
                order_index[port_edge.head().name()]
              )
            )
          let edge_type = if edge.tail().name() == edge.head().name() {
            if defined {
              4
            } else {
              8
            }
          } else if ranks[edge.tail().name()] == ranks[edge.head().name()] {
            2
          } else {
            1
          }
          entries.push({
            owner: edge.id(),
            main,
            segment: {
              tail: edge.tail().name(),
              head: edge.head().name(),
              vnodes: [],
            },
            ports: if reverse {
              (ports.1, ports.0)
            } else {
              ports
            },
            auxiliary: true,
            edge_type,
          })
        }
      }
    }
  }
  let compare = (a, b) => {
    compare_concentrated_entries(entries[a], entries[b], ranks, positions)
  }
  let indices = entries.mapi((index, _) => index)
  indices.sort_by(compare)
  let priorities = Array::make(entries.length(), 0)
  for index in 1..<indices.length() {
    let previous = indices[index - 1]
    let current = indices[index]
    priorities[current] = if compare(previous, current) == 0 {
      priorities[previous]
    } else {
      index
    }
  }
  // Preserve equality for qsort's unstable permutation; sorting by a unique
  // creation index changes installation order and recover_slack side effects.
  for index in sort_concentrated_route_indices(priorities) {
    let entry = entries[index]
    let owner = entry.owner
    let segment = entry.segment
    if route_order.get(owner) is None {
      route_order[owner] = route_order.length()
    }
    guard @edge_identity.is_edge_vnode_name(segment.tail) ||
      @edge_identity.is_edge_vnode_name(segment.head) else {
      continue
    }
    if segments.get(owner) is Some(group) {
      group.push(segment)
    } else {
      segments[owner] = [segment]
    }
  }
  segments
}
