///|
/// Stage A Phase A1 split: layout input preparation
/// logic and canonicalization helper flow.

///|
/// Graphviz parity: rankdir resolution uses option override first, then
/// graph attribute parsing with TB fallback (dotinit/input behavior).
/// Do not change behavior without updating fixtures/tests.
fn resolve_rankdir_for_layout_inputs(
  graph : @cgraph.Graph,
  option_rankdir : RankDir?,
) -> RankDir {
  match option_rankdir {
    Some(value) => value
    None =>
      match graph.get_attr("rankdir") {
        Some(value) =>
          match parse_rankdir(value) {
            Some(parsed) => parsed
            None => RankDir::TB
          }
        None => RankDir::TB
      }
  }
}

///|
/// Graphviz parity: nodesep/ranksep parse option overrides first, then graph
/// attributes, reject negatives, and clamp with Graphviz minima.
/// Do not change behavior without updating fixtures/tests.
fn resolve_spacing_for_layout_inputs(
  graph : @cgraph.Graph,
  option_nodesep : Double?,
  option_ranksep : Double?,
) -> (Double, Double) raise DotLayoutError {
  let nodesep_raw = match option_nodesep {
    Some(value) => value
    None =>
      match graph.get_attr("nodesep") {
        Some(value) => parse_first_double(value, default_nodesep_in())
        None => default_nodesep_in()
      }
  }
  if nodesep_raw < 0.0 {
    raise DotLayoutError::InvalidGraph(message="nodesep must be non-negative")
  }
  // Graphviz parity: late_double clamps nodesep to MIN_NODESEP.
  let nodesep_in =
    if nodesep_raw < MIN_NODESEP_IN { MIN_NODESEP_IN } else { nodesep_raw }
  let ranksep_raw = match option_ranksep {
    Some(value) => value
    None =>
      match graph.get_attr("ranksep") {
        Some(value) => parse_first_double(value, default_ranksep_in())
        None => default_ranksep_in()
      }
  }
  if ranksep_raw < 0.0 {
    raise DotLayoutError::InvalidGraph(message="ranksep must be non-negative")
  }
  // Graphviz parity: ranksep clamps to MIN_RANKSEP.
  let ranksep_in =
    if ranksep_raw < MIN_RANKSEP_IN { MIN_RANKSEP_IN } else { ranksep_raw }
  (nodesep_in, ranksep_in)
}

///|
/// Graphviz parity: splines mode resolution uses option override first, then
/// graph attribute parsing with Spline fallback.
/// Do not change behavior without updating fixtures/tests.
fn resolve_splines_for_layout_inputs(
  graph : @cgraph.Graph,
  option_splines : SplinesMode?,
) -> SplinesMode {
  match option_splines {
    Some(value) => value
    None =>
      match graph.get_attr("splines") {
        Some(value) =>
          match parse_splines(value) {
            Some(parsed) => parsed
            None => SplinesMode::Spline
          }
        None => SplinesMode::Spline
      }
  }
}

///|
/// Graphviz parity: edge flag scan checks dotted style and explicit ports in
/// edge creation order before downstream ordering setup.
/// Do not change behavior without updating fixtures/tests.
fn scan_edge_flags_for_layout_inputs(
  edges : Array[@cgraph.Edge],
) -> (Bool, Bool) {
  let mut has_dotted_edges = false
  let mut has_port_edges = false
  for edge in edges {
    match edge.get_attr("style") {
      Some(value) =>
        if value.to_lower().contains("dotted") {
          has_dotted_edges = true
        }
      None => ()
    }
    if !has_port_edges {
      let tail_port = port_is_explicit(edge.tail_port())
      let head_port = port_is_explicit(edge.head_port())
      if tail_port || head_port {
        has_port_edges = true
      }
    }
  }
  (has_dotted_edges, has_port_edges)
}


///|
/// Graphviz parity: node-order seeds follow GD_nlist creation order and apply
/// RL reversal after seeding (matching Graphviz ordering behavior).
/// Do not change behavior without updating fixtures/tests.
fn build_node_order_for_layout_inputs(
  nodes : Array[@cgraph.Node],
  rankdir : RankDir,
) -> Map[String, Int] {
  let node_order : Map[String, Int] = Map::new()
  let nlist_nodes = nodes
  let mut order_idx = 0
  while order_idx < nlist_nodes.length() {
    node_order[nlist_nodes[order_idx].name()] = order_idx
    order_idx = order_idx + 1
  }
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_names : Array[String] = [
      "z_req",
      "z_req1",
      "handle_x",
      "handle_1",
      "mobvm_a_req",
      "mobvm_a_req1",
    ]
    for name in debug_names {
      match node_order.get(name) {
        Some(value) => println("raw_node_order \{name}=\{value}")
        None => ()
      }
    }
  }
  if rankdir == RankDir::RL {
    let total = nodes.length()
    for node in nodes {
      let name = node.name()
      let base = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = total - 1 - base
    }
  }
  node_order
}

///|
/// Graphviz parity: node size maps for output/order/layout are derived once
/// per node, with LR/RL swapping only applied to layout-time sizes.
/// Do not change behavior without updating fixtures/tests.
fn build_size_maps_for_layout_inputs(
  nodes : Array[@cgraph.Node],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> (Map[String, NodeSize], Map[String, NodeSize], Map[String, NodeSize]) {
  let output_sizes : Map[String, NodeSize] = Map::new()
  let order_sizes : Map[String, NodeSize] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let size = node_size(node, record_orientation)
    output_sizes[node.name()] = size
    order_sizes[node.name()] = size
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      swap_node_size(size)
    } else {
      size
    }
  }
  (output_sizes, order_sizes, sizes)
}

///|
/// Graphviz parity: record/html nodes expose per-port horizontal order offsets
/// (layout_port_offset.x) used by later opposite-endpoint averaging.
/// Do not change behavior without updating fixtures/tests.
fn build_record_port_order_map_for_layout_inputs(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, Map[String, Double]] {
  let record_port_order : Map[String, Map[String, Double]] = Map::new()
  for node in nodes {
    let label = label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    if has_html || is_record_shape(node) {
      let name = node.name()
      let size = match output_sizes.get(name) {
        Some(value) => value
        None => node_size(node, record_orientation)
      }
      let raw_ports =
        if has_html {
          html_ports(node, { x: 0.0, y: 0.0 }, size)
        } else {
          record_ports(node, { x: 0.0, y: 0.0 }, size, record_orientation)
        }
      let order_map : Map[String, Double] = Map::new()
      for port_name, port in raw_ports {
        let offset = layout_port_offset(port.center, rankdir)
        order_map[port_name] = offset.x
      }
      record_port_order[name] = order_map
    }
  }
  record_port_order
}


///|
/// Graphviz parity: edge-side port-order contributions are accumulated from
/// explicit record/html ports onto opposite endpoints before averaging.
/// Do not change behavior without updating fixtures/tests.
fn accumulate_port_order_contrib_for_layout_inputs(
  edges : Array[@cgraph.Edge],
  record_port_order : Map[String, Map[String, Double]],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[String, (Double, Int)] {
  let order_sum : Map[String, (Double, Int)] = Map::new()
  let update_order = (target : String, anchor : String, port : @cgraph.Port?) => {
    match port {
      Some(value) =>
        match value.name {
          Some(port_name) =>
            match record_port_order.get(anchor) {
              Some(ports) =>
                match ports.get(port_name) {
                  Some(order) => {
                    let (sum, count) = match order_sum.get(target) {
                      Some(value) => value
                      None => (0.0, 0)
                    }
                    order_sum[target] = (sum + order, count + 1)
                    match port_order_contrib.get(target) {
                      Some(list) => list.push((anchor, order))
                      None => port_order_contrib[target] = [(anchor, order)]
                    }
                  }
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  for edge in edges {
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
      update_order(head_name, tail_name, edge.tail_port())
    }
    if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
      update_order(tail_name, head_name, edge.head_port())
    }
  }
  order_sum
}


///|
/// Graphviz parity: record/html port order hints are collected for LR/RL only
/// when explicit ports exist, then averaged onto opposite endpoints.
/// Do not change behavior without updating fixtures/tests.
fn build_port_order_metadata_for_layout_inputs(
  rankdir : RankDir,
  has_port_edges : Bool,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> (Map[String, Double], Map[String, Array[(String, Double)]]) {
  let port_order_positions : Map[String, Double] = Map::new()
  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  if (rankdir == RankDir::LR || rankdir == RankDir::RL) && has_port_edges {
    let record_port_order =
      build_record_port_order_map_for_layout_inputs(
        nodes,
        output_sizes,
        rankdir,
        record_orientation,
      )
    let order_sum =
      accumulate_port_order_contrib_for_layout_inputs(
        edges,
        record_port_order,
        port_order_contrib,
      )
    for name, entry in order_sum {
      let (sum, count) = entry
      if count > 0 {
        port_order_positions[name] = sum / count.to_double()
      }
    }
  }
  (port_order_positions, port_order_contrib)
}


///|
/// Graphviz parity: layout input preparation returns fields in fixed LayoutPrep
/// order consumed by later pipeline stages.
/// Do not change behavior without updating fixtures/tests.
fn build_layout_prep_output(
  rankdir : RankDir,
  nodesep_in : Double,
  ranksep_in : Double,
  splines : SplinesMode,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_dotted_edges : Bool,
  has_port_edges : Bool,
  has_edge_labels : Bool,
  node_order : Map[String, Int],
  record_orientation : RecordOrientation,
  output_sizes : Map[String, NodeSize],
  order_sizes : Map[String, NodeSize],
  sizes : Map[String, NodeSize],
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> LayoutPrep {
  {
    rankdir,
    nodesep_in,
    ranksep_in,
    splines,
    nodes,
    edges,
    has_dotted_edges,
    has_port_edges,
    has_edge_labels,
    node_order,
    record_orientation,
    output_sizes,
    order_sizes,
    sizes,
    port_order_positions,
    port_order_contrib,
  }
}


///|
/// Graphviz parity: layout attribute parsing aligned to refs/graphviz/lib/dotgen/dotinit.c + lib/common/input.c.
/// Do not change behavior without updating fixtures/tests.
fn prepare_layout_inputs(
  graph : @cgraph.Graph,
  opts : DotLayoutOptions,
) -> LayoutPrep raise DotLayoutError {
  let rankdir = resolve_rankdir_for_layout_inputs(graph, opts.rankdir)
  let (nodesep_in, ranksep_in) =
    resolve_spacing_for_layout_inputs(graph, opts.nodesep, opts.ranksep)
  let splines = resolve_splines_for_layout_inputs(graph, opts.splines)
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  dot_trace("layout_dot: start nodes=\{nodes.length()} edges=\{edges.length()}")
  let (has_dotted_edges, has_port_edges) =
    scan_edge_flags_for_layout_inputs(edges)
  let has_edge_labels = graph_has_edge_labels(edges)
  let node_order = build_node_order_for_layout_inputs(nodes, rankdir)
  let record_orientation = record_layout_orientation(rankdir)
  let (output_sizes, order_sizes, sizes) =
    build_size_maps_for_layout_inputs(nodes, rankdir, record_orientation)
  let (port_order_positions, port_order_contrib) =
    build_port_order_metadata_for_layout_inputs(
      rankdir,
      has_port_edges,
      nodes,
      edges,
      output_sizes,
      record_orientation,
    )
  build_layout_prep_output(
    rankdir,
    nodesep_in,
    ranksep_in,
    splines,
    nodes,
    edges,
    has_dotted_edges,
    has_port_edges,
    has_edge_labels,
    node_order,
    record_orientation,
    output_sizes,
    order_sizes,
    sizes,
    port_order_positions,
    port_order_contrib,
  )
}
