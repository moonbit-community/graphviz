///|
type NodeSize = @node_primitives.NodeSize

///|
type RankDir = @rankdir.RankDir

///|
type EdgeRouteBase = @routing.EdgeRouteBase

///|
type EdgeVnodeInfo = @routing.EdgeVnodeInfo

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
  if a < b { a } else { b }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}
