// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
type NodeSize = @node_primitives.NodeSize

///|
type RankDir = @rankdir.RankDir

///|
type RouteEdgesPipelineInput = @routing.RouteEdgesPipelineInput

///|
type RouteBaseDeps = @routing.RouteBaseDeps

///|
type EdgeRouteBase = @routing.EdgeRouteBase

///|
type RouteDynamicPortAnchor = @routing.RouteDynamicPortAnchor

///|
const PORT_SIDE_BOTTOM : Int = 1

///|
const PORT_SIDE_TOP : Int = 4

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
