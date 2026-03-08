///|
/// Shared geometry/assembly helpers for unranked engines: geometry
/// parsing/scaling, straight-line splines, and output projection/layout-tree
/// assembly.

type NodeSize = @node_primitives.NodeSize
type RecordOrientation = @shared.RecordOrientation
type RankDir = @rankdir.RankDir

///|
/// Shared point parsing/scaling and straight-line spline helpers used by
/// unranked layout assembly and fixed-position edge reuse.

///|
fn try_parse_double(text : String) -> Double? {
  try @strconv.parse_double(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_numbers(text : String, limit : Int) -> Array[Double] {
  let numbers : Array[Double] = []
  let mut current = StringBuilder::new()
  let mut seen = false
  for ch in text {
    if ch.is_ascii_digit() ||
      ch == '-' ||
      ch == '+' ||
      ch == '.' ||
      ch == 'e' ||
      ch == 'E' {
      current.write_char(ch)
      seen = true
      continue
    }
    if seen {
      match try_parse_double(current.to_string()) {
        Some(value) => numbers.push(value)
        None => ()
      }
      if numbers.length() >= limit {
        return numbers
      }
      current = StringBuilder::new()
      seen = false
    }
  }
  if seen {
    match try_parse_double(current.to_string()) {
      Some(value) => numbers.push(value)
      None => ()
    }
  }
  numbers
}

///|
pub fn parse_point_attr(text : String) -> @geom.Point? {
  let numbers = parse_numbers(text, 2)
  if numbers.length() < 2 {
    None
  } else {
    Some({ x: numbers[0], y: numbers[1] })
  }
}

///|
pub fn scale_point(point : @geom.Point, factor : Double) -> @geom.Point {
  { x: point.x * factor, y: point.y * factor }
}

///|
fn line_control_points(
  start : @geom.Point,
  end : @geom.Point,
) -> Array[@geom.Point] {
  let control1 : @geom.Point = {
    x: (start.x * 2.0 + end.x) / 3.0,
    y: (start.y * 2.0 + end.y) / 3.0,
  }
  let control2 : @geom.Point = {
    x: (start.x + end.x * 2.0) / 3.0,
    y: (start.y + end.y * 2.0) / 3.0,
  }
  [start, control1, control2, end]
}

///|
fn line_spline(
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> @geom.Spline {
  let start = @node_primitives.clip_to_rect(tail_pos, tail_size, head_pos)
  let end = @node_primitives.clip_to_rect(head_pos, head_size, tail_pos)
  {
    start: Some(start),
    end: Some(end),
    points: line_control_points(start, end),
  }
}

///|
pub fn node_size_with_fallback(
  sizes : Map[String, NodeSize],
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  match sizes.get(node.name()) {
    Some(value) => value
    None => @node_geometry.node_size(node, record_orientation)
  }
}

///|
pub struct EngineGeometryContext {
  scale_factor : Double
  rankdir : RankDir
  record_orientation : RecordOrientation
}

///|
pub fn build_engine_geometry_context(
  graph : @cgraph.Graph,
  scale : Double,
) -> EngineGeometryContext {
  let scale_value = if scale <= 0.0 { 72.0 } else { scale }
  let scale_factor = 72.0 / scale_value
  let rankdir = @rankdir.graph_rankdir(graph)
  let record_orientation = @shared.record_layout_orientation(rankdir)
  { scale_factor, rankdir, record_orientation }
}

///|
pub fn straight_line_edge_splines(
  _edge : @cgraph.Edge,
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> Array[@geom.Spline] {
  [line_spline(tail_pos, head_pos, tail_size, head_size)]
}

///|
/// Dot-package bridge for unranked engine output projection and layout-tree
/// finalization.

type LayoutTree = @shared.LayoutTree
type DotLayoutNode = @shared.DotLayoutNode
type DotLayoutEdge = @shared.DotLayoutEdge
type ClusterBboxHeightPair = @clustering.ClusterBboxHeightPair

///|
pub(all) struct EngineNodeProjection {
  positions : Map[String, @geom.Point]
  nodes_out : Array[DotLayoutNode]
}

///|
pub(all) struct EngineNodeProjectionWithSizes {
  projection : EngineNodeProjection
  sizes : Map[String, NodeSize]
}

///|
pub fn build_projected_nodes_from_positions(
  nodes : Array[@cgraph.Node],
  positions : Map[String, @geom.Point],
  node_size_for : (@cgraph.Node) -> NodeSize,
) -> Array[DotLayoutNode] {
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let pos = match positions.get(node.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = node_size_for(node)
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    })
  }
  nodes_out
}

///|
pub fn project_scaled_nodes_with_sizes(
  nodes : Array[@cgraph.Node],
  positions : Array[@geom.Point],
  scale_factor : Double,
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> EngineNodeProjectionWithSizes {
  let positions_map : Map[String, @geom.Point] = Map::new()
  for i in 0..<nodes.length() {
    let node = nodes[i]
    positions_map[node.name()] = scale_point(positions[i], scale_factor)
  }
  let nodes_out =
    build_projected_nodes_from_positions(
      nodes,
      positions_map,
      node => node_size_with_fallback(sizes, node, record_orientation),
    )
  {
    projection: { positions: positions_map, nodes_out },
    sizes,
  }
}

///|
pub fn build_edges_from_positions(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  node_size_for : (@cgraph.Node) -> NodeSize,
  edge_splines_for :
    (@cgraph.Edge, @geom.Point, @geom.Point, NodeSize, NodeSize) -> Array[@geom.Spline],
) -> Array[DotLayoutEdge] {
  let edges_out : Array[DotLayoutEdge] = []
  for edge in graph.edges() {
    let tail = edge.tail()
    let head = edge.head()
    let tail_pos = match positions.get(tail.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let head_pos = match positions.get(head.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let tail_size = node_size_for(tail)
    let head_size = node_size_for(head)
    edges_out.push({
      edge,
      splines: edge_splines_for(edge, tail_pos, head_pos, tail_size, head_size),
      label_pos: None,
      head_label_pos: None,
      tail_label_pos: None,
      xlabel_pos: None,
    })
  }
  edges_out
}

///|
/// Graphviz parity: noop/neato output assembly mirrors dot postprocess shape:
/// cluster subgraph recursion + bbox expansion + root label placement.
pub fn finalize_unranked_layout_tree(
  graph : @cgraph.Graph,
  rankdir : RankDir,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
) -> LayoutTree {
  let base_bbox = @bbox.compute_bbox(nodes_out, edges_out)
  let empty_cluster_ln_x : Map[String, Double] = Map::new()
  let empty_cluster_rn_x : Map[String, Double] = Map::new()
  let empty_cluster_bbox_heights : Map[String, ClusterBboxHeightPair] = Map::new()
  let empty_ranks : Map[String, Int] = Map::new()
  let empty_rank_y : Map[Int, Double] = Map::new()
  let empty_rank_ht1 : Map[Int, Double] = Map::new()
  let empty_rank_ht2 : Map[Int, Double] = Map::new()
  let subgraphs =
    @clustering.layout_subgraphs(
      {
        graph,
        nodes_out,
        edges_out,
        cluster_ln_x: empty_cluster_ln_x,
        cluster_rn_x: empty_cluster_rn_x,
        cluster_bbox_heights: empty_cluster_bbox_heights,
        rankdir,
        ranks: empty_ranks,
        rank_y: empty_rank_y,
        rank_ht1: empty_rank_ht1,
        rank_ht2: empty_rank_ht2,
      },
    )
  let mut bbox = if subgraphs.length() > 0 {
    @clustering.expand_bbox_with_subgraphs(base_bbox, subgraphs)
  } else {
    base_bbox
  }
  let mut label_pos : @geom.Point? = None
  if graph.is_root() {
    match @label_metrics.graph_label_metrics(graph) {
      Some(metrics) => {
        let loc = @shared.graph_label_loc(graph)
        let just = @shared.graph_label_just(graph)
        bbox =
          @shared.expand_bbox_for_label(
            bbox,
            metrics.width_pt,
            metrics.height_pt,
            loc,
          )
        label_pos = Some(
          @shared.graph_label_pos(
            bbox,
            metrics.width_pt,
            metrics.height_pt,
            loc,
            just,
          ),
        )
      }
      None => ()
    }
  }
  {
    graph,
    bbox,
    label_pos,
    nodes: nodes_out,
    edges: edges_out,
    subgraphs,
  }
}
