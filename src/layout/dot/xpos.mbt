///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128

///|
const ROOT_COMPRESS_WEIGHT : Int = 1000

///|
type ConstraintEdge = @positioning.ConstraintEdge

///|
priv struct XposConstraintNodeSnapshot {
  name : String?
  kind : @network_simplex.NodeKind
  rank : Int
  order : Int
  left_pt : Double
  right_pt : Double
  height_pt : Double
}

///|
priv struct XposConstraintEdgeSnapshot {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
priv struct XposConstraintSnapshot {
  nodes : Array[XposConstraintNodeSnapshot]
  edges : Array[XposConstraintEdgeSnapshot]
}

///|
fn touch_constraint_snapshot(snapshot : XposConstraintSnapshot) -> Unit {
  let _ = snapshot.nodes
  let _ = snapshot.edges
  for node in snapshot.nodes {
    let _ = node.name
    let _ = node.kind
    let _ = node.rank
    let _ = node.order
    let _ = node.left_pt
    let _ = node.right_pt
    let _ = node.height_pt
  }
  for edge in snapshot.edges {
    let _ = edge.tail
    let _ = edge.head
    let _ = edge.minlen
    let _ = edge.weight
  }
}

///|
type SlackSegment = @positioning.SlackSegment

fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> Map[String, Map[String, RecordPort]] {
  let offsets : Map[String, Map[String, RecordPort]] = Map::new()
  let rankdir = if nodes.length() > 0 {
    graph_rankdir(nodes[0].graph())
  } else {
    RankDir::TB
  }
  let record_orientation = record_layout_orientation(rankdir)
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  for node in nodes {
    let name = node.name()
    let base_size = match output_sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    let label = label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    let ports =
      if has_html {
        html_ports(node, origin, base_size)
      } else if is_record_shape(node) {
        record_ports(node, origin, base_size, record_orientation)
      } else {
        Map::new()
      }
    if ports.length() > 0 {
      let node_offsets : Map[String, RecordPort] = Map::new()
      for port_name, port_info in ports {
        let offset = layout_port_offset(port_info.center, rankdir)
        let size = match rankdir {
          RankDir::LR | RankDir::RL => swap_node_size(port_info.size)
          _ => port_info.size
        }
        node_offsets[port_name] = { center: offset, size, sides: port_info.sides }
      }
      offsets[name] = node_offsets
    }
  }
  offsets
}

///|
fn fallback_compass_size() -> NodeSize {
  let width_pt = @dot_shared.default_node_width_in() * 72.0
  let height_pt = @dot_shared.default_node_height_in() * 72.0
  let half = width_pt / 2.0
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: half,
    right_pt: half,
  }
}

///|
fn node_size_for_compass(
  node_name : String,
  sizes : Map[String, NodeSize],
) -> NodeSize {
  match sizes.get(node_name) {
    Some(value) => value
    None => fallback_compass_size()
  }
}

///|
fn compass_uses_shape_clipping(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      true
    "diamond"
    | "mdiamond"
    | "triangle"
    | "invtriangle"
    | "trapezium"
    | "invtrapezium"
    | "parallelogram"
    | "egg"
    | "house"
    | "invhouse"
    | "pentagon"
    | "hexagon"
    | "septagon"
    | "octagon"
    | "doubleoctagon"
    | "tripleoctagon" =>
      true
    "polygon" => {
      let attrs = polygon_shape_attrs(node)
      if attrs.sides < 3 {
        true
      } else {
        !polygon_is_box_like(
          attrs.sides,
          attrs.orientation,
          attrs.distortion,
          attrs.skew,
        )
      }
    }
    _ => false
  }
}

fn compass_port_point(
  node_name : String,
  node : @cgraph.Node?,
  compass : @cgraph.Compass,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
) -> @geom.Point {
  let base_size = node_size_for_compass(node_name, sizes)
  let half_height = base_size.height_pt / 2.0
  let left = -base_size.left_pt
  let right = base_size.right_pt
  let top = half_height
  let bottom = -half_height
  let base_point = match compass {
    @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
    _ =>
      match node {
        Some(value) =>
          if compass_uses_shape_clipping(value) {
            @edge_spline.compass_port_point_on_shape(
              value,
              @edge_spline.point(0.0, 0.0),
              base_size,
              compass,
              rankdir,
            )
          } else {
            match compass {
              @cgraph.Compass::N => @geom.Point::{ x: 0.0, y: top }
              @cgraph.Compass::NE => @geom.Point::{ x: right, y: top }
              @cgraph.Compass::E => @geom.Point::{ x: right, y: 0.0 }
              @cgraph.Compass::SE => @geom.Point::{ x: right, y: bottom }
              @cgraph.Compass::S => @geom.Point::{ x: 0.0, y: bottom }
              @cgraph.Compass::SW => @geom.Point::{ x: left, y: bottom }
              @cgraph.Compass::W => @geom.Point::{ x: left, y: 0.0 }
              @cgraph.Compass::NW => @geom.Point::{ x: left, y: top }
              @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
            }
          }
        None =>
          match compass {
            @cgraph.Compass::N => @geom.Point::{ x: 0.0, y: top }
            @cgraph.Compass::NE => @geom.Point::{ x: right, y: top }
            @cgraph.Compass::E => @geom.Point::{ x: right, y: 0.0 }
            @cgraph.Compass::SE => @geom.Point::{ x: right, y: bottom }
            @cgraph.Compass::S => @geom.Point::{ x: 0.0, y: bottom }
            @cgraph.Compass::SW => @geom.Point::{ x: left, y: bottom }
            @cgraph.Compass::W => @geom.Point::{ x: left, y: 0.0 }
            @cgraph.Compass::NW => @geom.Point::{ x: left, y: top }
            @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
          }
      }
  }
  layout_port_offset(base_point, rankdir)
}

///|
fn compass_port_offset(
  compass : @cgraph.Compass,
  node_name : String,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  let node = nodes_by_name.get(node_name)
  let unrotated = compass_port_point(node_name, node, compass, sizes, RankDir::TB)
  match node {
    Some(value) =>
      if is_record_shape(value) || @html_label.is_html_label_text(label_text(value)) {
        // Preserve record/html order behavior for explicit label ports.
        unrotated.x
      } else {
        // Graphviz parity: make_edge_pairs consumes compassPort rankdir-rotated
        // ED_{tail,head}_port.p.x for non-record compass-only endpoints.
        layout_port_offset(unrotated, rankdir).x
      }
    None => layout_port_offset(unrotated, rankdir).x
  }
}

///|
fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match offsets.get(node_name) {
            Some(node_offsets) =>
              match node_offsets.get(name) {
                Some(port_info) =>
                  match value.compass {
                    Some(compass) =>
                      match compass {
                        @cgraph.Compass::E
                        | @cgraph.Compass::NE
                        | @cgraph.Compass::SE => {
                          let half = port_info.size.width_pt / 2.0
                          port_info.center.x + half
                        }
                        @cgraph.Compass::W
                        | @cgraph.Compass::NW
                        | @cgraph.Compass::SW => {
                          let half = port_info.size.width_pt / 2.0
                          port_info.center.x - half
                        }
                        _ => port_info.center.x
                      }
                    None => port_info.center.x
                  }
                None =>
                  match value.compass {
                    Some(compass) =>
                      compass_port_offset(
                        compass,
                        node_name,
                        sizes,
                        rankdir,
                        nodes_by_name,
                      )
                    None => 0.0
                  }
              }
            None =>
              match value.compass {
                Some(compass) =>
                  compass_port_offset(
                    compass,
                    node_name,
                    sizes,
                    rankdir,
                    nodes_by_name,
                  )
                None => 0.0
              }
          }
        None =>
          match value.compass {
            Some(compass) =>
              compass_port_offset(
                compass,
                node_name,
                sizes,
                rankdir,
                nodes_by_name,
              )
            None => 0.0
          }
      }
    None => 0.0
  }
}

///|
/// Graphviz parity: port order uses compassPort angle quantization
/// (MC_SCALE=256) for mincross medians (shapes.c + mincross.c).
/// Do not change behavior without updating fixtures/tests.
fn port_order_fraction(point : @geom.Point) -> Double {
  if point.x == 0.0 && point.y == 0.0 {
    return 0.5
  }
  let two_pi = 2.0 * @math.PI
  let mut angle = @edge_spline.libm_atan2(point.y, point.x) + 1.5 * @math.PI
  if angle >= two_pi {
    angle = angle - two_pi
  }
  let scaled = (256.0 * angle / two_pi).trunc()
  scaled / 256.0
}

///|
fn record_port_point(
  port_info : RecordPort,
  compass : @cgraph.Compass?,
) -> @geom.Point {
  let center = port_info.center
  let half_w = port_info.size.width_pt / 2.0
  let half_h = port_info.size.height_pt / 2.0
  match compass {
    Some(value) =>
      match value {
        @cgraph.Compass::N => { x: center.x, y: center.y + half_h }
        @cgraph.Compass::NE => { x: center.x + half_w, y: center.y + half_h }
        @cgraph.Compass::E => { x: center.x + half_w, y: center.y }
        @cgraph.Compass::SE => { x: center.x + half_w, y: center.y - half_h }
        @cgraph.Compass::S => { x: center.x, y: center.y - half_h }
        @cgraph.Compass::SW => { x: center.x - half_w, y: center.y - half_h }
        @cgraph.Compass::W => { x: center.x - half_w, y: center.y }
        @cgraph.Compass::NW => { x: center.x - half_w, y: center.y + half_h }
        @cgraph.Compass::C => center
      }
    None => center
  }
}

///|
fn edge_port_order(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  if !@dot_shared.port_is_explicit(port) {
    // Graphviz parity: absent ports contribute neutral 0.0 offset/order.
    return 0.0
  }
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match offsets.get(node_name) {
            Some(node_offsets) =>
              match node_offsets.get(name) {
                Some(port_info) =>
                  port_order_fraction(record_port_point(port_info, value.compass))
                None =>
                  match value.compass {
                    Some(compass) =>
                      port_order_fraction(
                        compass_port_point(
                          node_name,
                          nodes_by_name.get(node_name),
                          compass,
                          sizes,
                          rankdir,
                        ),
                      )
                    None => 0.5
                  }
              }
            None =>
              match value.compass {
                Some(compass) =>
                  port_order_fraction(
                    compass_port_point(
                      node_name,
                      nodes_by_name.get(node_name),
                      compass,
                      sizes,
                      rankdir,
                    ),
                  )
                None => 0.5
              }
          }
        None =>
          match value.compass {
            Some(compass) =>
              port_order_fraction(
                compass_port_point(
                  node_name,
                  nodes_by_name.get(node_name),
                  compass,
                  sizes,
                  rankdir,
                ),
              )
            None => 0.5
          }
      }
    None => 0.5
  }
}

fn segment_slack_minlen(
  segment : SlackSegment,
  port_offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  real_by_name : Map[String, @cgraph.Node],
) -> (Int, Int) {
  let tail_offset = edge_port_offset(
    segment.tail,
    segment.tail_port,
    port_offsets,
    sizes,
    rankdir,
    real_by_name,
  )
  let head_offset = edge_port_offset(
    segment.head,
    segment.head_port,
    port_offsets,
    sizes,
    rankdir,
    real_by_name,
  )
  let delta = head_offset - tail_offset
  let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
  let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
  (m0, m1)
}

/// Graphviz parity: constraint graph uses GD_nlist order for existing
/// nodes and appends aux slack/cluster nodes per create_aux_edges.
/// Do not change behavior without updating fixtures/tests.
///|
fn x_positions_from_simplex(
  graph_root : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  output_sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  extra_nodes : Array[@ordering.ExtraConstraintNode],
  extra_edges : Array[ConstraintEdge],
  edge_vnodes : Map[String, Array[String]],
  root_ln_targets : Array[String],
  root_rn_targets : Array[String],
  compress_width_minlen : Int?,
) -> Map[String, Double] {
  let xpos_nlist_order =
    @positioning.build_xpos_nlist_order(
      {
        rankdir: graph_rankdir(graph_root),
        nlist_order,
        gdnlist_order,
        cluster_keys,
        rank_keys,
        groups,
      },
    )
  let order_index = @ordering.build_order_index(groups)
  let mut has_port_edges = false
  for edge in edges {
    if @dot_shared.port_is_explicit(edge.tail_port()) || @dot_shared.port_is_explicit(edge.head_port()) {
      has_port_edges = true
      break
    }
  }
  let port_offsets =
    if has_port_edges {
      port_offsets_for_nodes(nodes, output_sizes)
    } else {
      Map::new()
    }
  let rankdir =
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
  let root_margin = if nodes.length() > 0 {
    cluster_margin_pt(nodes[0].graph())
  } else {
    CLUSTER_MARGIN_PT
  }
  let constraint_graph =
    @positioning.build_constraint_graph(
      {
        nodes,
        edges,
        edge_tail,
        edge_head,
        edge_out_order,
        nlist_order: xpos_nlist_order,
        gdnlist_order: xpos_nlist_order,
        ranks,
        rank_keys,
        groups,
        sizes,
        cluster_keys,
        nodesep_pt,
        has_edge_labels,
        extra_nodes,
        extra_edges,
        edge_vnodes,
        root_ln_targets,
        root_rn_targets,
        compress_width_minlen,
        segment_minlen:
          (segment, real_by_name) =>
            segment_slack_minlen(
              segment,
              port_offsets,
              sizes,
              rankdir,
              real_by_name,
            ),
        edge_has_mid_label: edge => edge_mid_label_metrics(edge) is Some(_),
        edge_degree_increment:
          edge =>
            if edge_dir_for(edge, edge.tail().graph().kind()) is EdgeDir::Both {
              2
            } else {
              1
            },
        root_margin,
        root_compress_weight: ROOT_COMPRESS_WEIGHT,
        node_left_pt,
        node_right_pt,
        round_int,
        trunc_int,
      },
    )
  // Graphviz parity: constraint graph reorder follows GD_nlist sequence.
  let order =
    @positioning.build_constraint_reorder(
      {
        graph: constraint_graph.graph,
        index: constraint_graph.index,
        nlist_order: xpos_nlist_order,
      },
    )
  let reordered =
    @positioning.reorder_constraint_graph(
      {
        graph: constraint_graph.graph,
        index: constraint_graph.index,
        order,
      },
    )
  if should_capture_xpos_snapshot(graph_root) {
    xpos_constraint_snapshot.val = Some(
      build_constraint_snapshot(
        reordered.graph,
        reordered.index,
        sizes,
        order_index,
      ),
    )
  }
  @network_simplex.network_simplex(
    reordered.graph,
    0x7fffffff,
    @network_simplex.BalanceMode::LR,
  )
  let positions : Map[String, Double] = Map::new()
  for node in nodes {
    let name = node.name()
    let idx = match reordered.index.get(name) {
      Some(value) => value
      None => 0
    }
    positions[name] = @network_simplex.node_rank(reordered.graph, idx).to_double()
  }
  for extra_node in extra_nodes {
    let idx = match reordered.index.get(extra_node.name) {
      Some(value) => value
      None => 0
    }
    positions[extra_node.name] =
      @network_simplex.node_rank(reordered.graph, idx).to_double()
  }
  positions
}

///|
/// Graphviz parity: xpos payload keeps rank/group/cluster snapshots grouped so
/// position.c/cluster.c constraint wiring remains explicit and stable.
priv struct XPositionsInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  sizes : Map[String, NodeSize]
  output_sizes : Map[String, NodeSize]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  extra_nodes : Array[@ordering.ExtraConstraintNode]
  flat_label_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/position.c + cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_x_positions(
  input : XPositionsInput,
) -> Map[String, Double] {
  let graph = input.graph
  let cluster_constraints =
    build_cluster_constraints(
    graph,
    input.nodes,
    input.edges,
    input.ranks,
    input.rank_keys,
    input.groups,
    input.sizes,
    input.cluster_keys,
    input.nodesep_pt,
    input.has_edge_labels,
    input.edge_vnodes,
  )
  let all_extra_nodes = input.extra_nodes.copy()
  for pair in cluster_constraints.extra_nodes {
    all_extra_nodes.push(pair)
  }
  let all_extra_edges = cluster_constraints.extra_edges.copy()
  for edge in input.flat_label_edges {
    all_extra_edges.push(edge)
  }
  let rankdir = graph_rankdir(graph)
  let compress_width_minlen = compress_width_minlen_pt(graph, rankdir)
  let all_root_ln_targets = cluster_constraints.root_ln_targets.copy()
  let all_root_rn_targets = cluster_constraints.root_rn_targets.copy()
  match compress_width_minlen {
    Some(_) => {
      // Graphviz parity: contain_nodes constrains per-rank leftmost/rightmost
      // nodes against root ln/rn before adding the compress edge.
      @positioning.append_missing_rank_boundary_targets(
        input.rank_keys,
        input.groups,
        all_root_ln_targets,
        all_root_rn_targets,
      )
    }
    None => ()
  }
  x_positions_from_simplex(
    graph,
    input.nodes,
    input.edges,
    input.edge_tail,
    input.edge_head,
    input.edge_out_order,
    input.nlist_order,
    input.gdnlist_order,
    input.ranks,
    input.rank_keys,
    input.groups,
    input.sizes,
    input.output_sizes,
    input.cluster_keys,
    input.nodesep_pt,
    input.has_edge_labels,
    all_extra_nodes,
    all_extra_edges,
    input.edge_vnodes,
    all_root_ln_targets,
    all_root_rn_targets,
    compress_width_minlen,
  )
}
