// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
type NodeSize = @node_primitives.NodeSize

///|
type RankDir = @rankdir.RankDir

///|
type EdgeRouteBase = @routing.EdgeRouteBase

///|
type EdgeVnodeInfo = @setup.EdgeVnodeInfo

///|
type HeadPortMetrics = @precompute.HeadPortMetrics

///|
type RoutingContext = @precompute.RoutingContext

///|
type EdgeSplineResult = @routing.EdgeSplineResult

///|
const PORT_SIDE_BOTTOM : Int = 1

///|
const PORT_SIDE_TOP : Int = 4

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
