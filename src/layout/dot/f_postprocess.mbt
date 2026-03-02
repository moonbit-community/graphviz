///|
priv struct PortLayoutMaps {
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
priv struct HeadPortMetrics {
  head_port_counts : Map[String, Int]
  head_port_min_dist : Map[String, Double]
  head_port_max_dist : Map[String, Double]
}

///|
fn count_cluster_subgraphs(graph : @cgraph.Graph) -> Int {
  let mut count = 0
  for subgraph in graph.subgraphs() {
    if @dot_shared.is_cluster_graph(subgraph) {
      count = count + 1
    }
    count = count + count_cluster_subgraphs(subgraph)
  }
  count
}

fn expand_bbox_for_label_pos(
  bbox : @geom.Rect,
  pos : @geom.Point?,
  metrics : (Double, Double)?,
) -> @geom.Rect {
  match (pos, metrics) {
    (Some(center), Some((width, height))) => {
      let half_w = width / 2.0
      let half_h = height / 2.0
      let min_x = center.x - half_w
      let max_x = center.x + half_w
      let min_y = center.y - half_h
      let max_y = center.y + half_h
      {
        llx: if min_x < bbox.llx { min_x } else { bbox.llx },
        lly: if min_y < bbox.lly { min_y } else { bbox.lly },
        urx: if max_x > bbox.urx { max_x } else { bbox.urx },
        ury: if max_y > bbox.ury { max_y } else { bbox.ury },
      }
    }
    _ => bbox
  }
}

///|
/// Graphviz parity: edge label bbox expansion aligned to refs/graphviz/lib/common/utils.c
/// (addLabelBB/compute_bb) + dotgen/dotsplines.c (updateBB for edge labels).
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_for_edge_labels(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  ranks : Map[String, Int],
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutGraph {
  if !graph.is_root() {
    return layout
  }
  // Graphviz parity: addLabelBB applies GD_flip for LR/RL, so swap label
  // dimensions in pre-rotation space to match compute_bb.
  let rankdir = graph_rankdir(graph)
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let adjust_metrics = (metrics : (Double, Double)?) => {
    match metrics {
      Some((width, height)) =>
        if flip {
          Some((height, width))
        } else {
          Some((width, height))
        }
      None => None
    }
  }
  let mut bbox = layout.bbox
  for edge_layout in layout.edges {
    let edge = edge_layout.edge
    let tail = edge.tail().name()
    let head = edge.head().name()
    let is_flat =
      match (ranks.get(tail), ranks.get(head)) {
        (Some(tail_rank), Some(head_rank)) => tail_rank == head_rank
        _ => false
      }
    let has_flat_label_vnode =
      match flat_label_edge_vnodes.get(@dot_shared.edge_key(edge)) {
        Some(_) => true
        None => false
      }
    // Graphviz parity: adjacent flat-edge labels do not update BB
    // (dotsplines.c makeSimpleFlatLabels has no updateBB call).
    // Graphviz parity: self-edge labels still update BB via dotsplines.
    let skip_mid_label = is_flat && !has_flat_label_vnode && tail != head
    bbox = expand_bbox_for_label_pos(
      bbox,
      if skip_mid_label { None } else { edge_layout.label_pos },
      if skip_mid_label {
        None
      } else {
        adjust_metrics(edge_mid_label_metrics(edge))
      },
    )
    if !flip && is_flat && has_flat_label_vnode && tail != head {
      match edge_layout.label_pos {
        Some(center) => {
          let orientation = record_layout_orientation(rankdir)
          let tail_size = node_size(edge.tail(), orientation)
          let head_size = node_size(edge.head(), orientation)
          let tail_half = tail_size.height_pt / 2.0
          let head_half = head_size.height_pt / 2.0
          let half_height = if tail_half > head_half { tail_half } else { head_half }
          let top = center.y + half_height
          if top > bbox.ury {
            bbox = { llx: bbox.llx, lly: bbox.lly, urx: bbox.urx, ury: top }
          }
        }
        None => ()
      }
    }
    bbox = expand_bbox_for_label_pos(
      bbox,
      edge_layout.head_label_pos,
      adjust_metrics(
        edge_label_metrics_for_attr(
          edge_layout.edge,
          "headlabel",
          true,
        ),
      ),
    )
    bbox = expand_bbox_for_label_pos(
      bbox,
      edge_layout.tail_label_pos,
      adjust_metrics(
        edge_label_metrics_for_attr(
          edge_layout.edge,
          "taillabel",
          true,
        ),
      ),
    )
  }
  if bbox == layout.bbox {
    layout
  } else {
    {
      graph: layout.graph,
      bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    }
  }
}

///|
/// Graphviz parity: cluster bbox + label placement aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + lib/common/input.c (cluster label borders) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
fn layout_subgraphs(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, (Double, Double)],
  rankdir : RankDir,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Array[DotLayoutGraph] {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let result : Array[DotLayoutGraph] = []
  for subgraph in graph.subgraphs() {
    let node_set : Map[String, Bool] = Map::new()
    for node in subgraph.nodes() {
      if graph_contains_node(subgraph, node) {
        node_set[node.name()] = true
      }
    }
    let edge_set : Map[String, Bool] = Map::new()
    for edge in subgraph.edges() {
      edge_set[@dot_shared.edge_key(edge)] = true
    }
    let sub_nodes : Array[DotLayoutNode] = []
    for node_layout in nodes_out {
      if node_set.get(node_layout.node.name()) is Some(_) {
        sub_nodes.push(node_layout)
      }
    }
    let sub_edges : Array[DotLayoutEdge] = []
    for edge_layout in edges_out {
      if edge_set.get(@dot_shared.edge_key(edge_layout.edge)) is Some(_) {
        let tail_name = edge_layout.edge.tail().name()
        let head_name = edge_layout.edge.head().name()
        if node_set.get(tail_name) is Some(_) &&
          node_set.get(head_name) is Some(_) {
          sub_edges.push(edge_layout)
        }
      }
    }
    let mut bbox = compute_bbox(sub_nodes, sub_edges)
    let mut label_pos : @geom.Point? = None
    let mut label_info : (Double, Double, LabelLoc, LabelJust, Bool)? = None
    let sub_subgraphs =
      layout_subgraphs(
        subgraph,
        nodes_out,
        edges_out,
        cluster_ln_x,
        cluster_rn_x,
        cluster_bbox_heights,
        rankdir,
        ranks,
        rank_y,
        rank_ht1,
        rank_ht2,
      )
    if @dot_shared.is_cluster_graph(subgraph) {
      // Graphviz parity: empty clusters (no descendant nodes) are omitted.
      let cluster_nodes : Map[String, Bool] = Map::new()
      @dot_shared.collect_graph_nodes(subgraph, cluster_nodes)
      if cluster_nodes.length() == 0 {
        continue
      }
    }
    if sub_subgraphs.length() > 0 {
      bbox = expand_bbox_with_subgraphs(bbox, sub_subgraphs)
    }
    if @dot_shared.is_cluster_graph(subgraph) {
      let pad = cluster_margin_pt(subgraph)
      let mut pad_left = pad
      let mut pad_right = pad
      let mut pad_y = pad
      let mut use_rank_bbox = false
      // Graphviz parity: cluster y bounds come from rank positions (dot_compute_bb).
      let mut min_rank : Int? = None
      let mut max_rank : Int? = None
      let cluster_nodes : Map[String, Bool] = Map::new()
      @dot_shared.collect_graph_nodes(subgraph, cluster_nodes)
      for name, _ in cluster_nodes {
        match ranks.get(name) {
          Some(rank) => {
            match min_rank {
              Some(value) => if rank < value { min_rank = Some(rank) }
              None => min_rank = Some(rank)
            }
            match max_rank {
              Some(value) => if rank > value { max_rank = Some(rank) }
              None => max_rank = Some(rank)
            }
          }
          None => ()
        }
      }
      match (min_rank, max_rank) {
        (Some(min_rank_value), Some(max_rank_value)) => {
          let max_rank_y = match rank_y.get(max_rank_value) {
            Some(value) => value
            None => bbox.lly
          }
          let min_rank_y = match rank_y.get(min_rank_value) {
            Some(value) => value
            None => bbox.ury
          }
          let mut ht1 = match rank_ht1.get(max_rank_value) {
            Some(value) => value
            None => 0.0
          }
          let mut ht2 = match rank_ht2.get(min_rank_value) {
            Some(value) => value
            None => 0.0
          }
          match subgraph.name() {
            Some(cluster_name) =>
              match cluster_bbox_heights.get(cluster_name) {
                Some((cluster_ht1, cluster_ht2)) => {
                  ht1 = cluster_ht1
                  ht2 = cluster_ht2
                }
                None => ()
              }
            None => ()
          }
          bbox =
            { llx: bbox.llx, lly: max_rank_y - ht1, urx: bbox.urx, ury: min_rank_y + ht2 }
          pad_y = 0.0
          use_rank_bbox = true
        }
        _ => ()
      }
      // Graphviz parity: cluster x bounds come from ln/rn positions (dot_compute_bb).
      match subgraph.name() {
        Some(cluster_name) => {
          match cluster_ln_x.get(cluster_name) {
            Some(value) => {
              bbox = { llx: value, lly: bbox.lly, urx: bbox.urx, ury: bbox.ury }
              pad_left = 0.0
            }
            None => ()
          }
          match cluster_rn_x.get(cluster_name) {
            Some(value) => {
              bbox = { llx: bbox.llx, lly: bbox.lly, urx: value, ury: bbox.ury }
              pad_right = 0.0
            }
            None => ()
          }
        }
        None => ()
      }
      let llx = bbox.llx - pad_left
      let lly = bbox.lly - pad_y
      let urx = bbox.urx + pad_right
      let ury = bbox.ury + pad_y
      bbox = { llx, lly, urx, ury }
      match graph_label_metrics(subgraph) {
        Some(metrics) => {
          let loc = graph_label_loc(subgraph)
          let just = graph_label_just(subgraph)
          let pad = CLUSTER_LABEL_PAD_PT
          let padded_width = metrics.width_pt + pad * 2.0
          let padded_height = metrics.height_pt + pad
          if flip {
            let border_x = padded_height
            let border_y = padded_width
            let mut llx = bbox.llx
            let mut urx = bbox.urx
            let mut lly = bbox.lly
            let mut ury = bbox.ury
            if !use_rank_bbox {
              match loc {
                LabelLoc::Top => urx = urx + border_x
                LabelLoc::Bottom => llx = llx - border_x
              }
            }
            let span = ury - lly
            if border_y > span {
              let diff = (border_y - span) / 2.0
              lly = lly - diff
              ury = ury + diff
            }
            bbox = { llx, lly, urx, ury }
            label_info = Some((border_x, border_y, loc, just, true))
          } else {
            if !use_rank_bbox {
              bbox =
                expand_bbox_for_label(
                  bbox,
                  metrics.width_pt,
                  metrics.height_pt,
                  loc,
                )
            }
            label_info = Some((padded_width, padded_height, loc, just, false))
          }
        }
        None => ()
      }
      bbox = round_bbox(bbox)
    }
    match label_info {
      Some((width_pt, height_pt, loc, just, flipped)) =>
        label_pos =
          Some(
            if flipped {
              graph_label_pos_flip(bbox, width_pt, height_pt, loc, just)
            } else {
              graph_label_pos(bbox, width_pt, height_pt, loc, just)
            },
          )
      None => ()
    }
    result.push({
      graph: subgraph,
      bbox,
      label_pos,
      nodes: sub_nodes,
      edges: sub_edges,
      subgraphs: sub_subgraphs,
    })
  }
  result
}

///|
/// Graphviz parity: node layout assembly aligned to refs/graphviz/lib/dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_layout_nodes(
  nodes : Array[@cgraph.Node],
  positions : Map[String, @geom.Point],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Array[DotLayoutNode] {
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = match output_sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
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
/// Graphviz parity: port layout maps aligned to refs/graphviz/lib/common/shapes.c (record/html ports).
/// Do not change behavior without updating fixtures/tests.
fn build_port_layout_maps(
  nodes_out : Array[DotLayoutNode],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  rankdir : RankDir,
  has_port_edges : Bool,
) -> PortLayoutMaps {
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  let label_ports_raw : Map[String, Map[String, RecordPort]] = Map::new()
  if has_port_edges {
    for node_layout in nodes_out {
      let name = node_layout.node.name()
      let final_size = match output_sizes.get(name) {
        Some(value) => value
        None => node_size(node_layout.node, record_orientation)
      }
      let label = label_text(node_layout.node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html {
        let raw_ports = html_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      } else if is_record_shape(node_layout.node) {
        let raw_ports = record_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
          record_orientation,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      }
    }
  }
  { label_ports_map, label_ports_raw }
}

///|
/// Graphviz parity: cluster routing bboxes aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
fn compute_cluster_route_bboxes(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, (Double, Double)],
  rankdir : RankDir,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Map[String, @geom.Rect] {
  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  if @dot_shared.graph_has_cluster(graph) {
    let cluster_layouts =
      layout_subgraphs(
        graph,
        nodes_out,
        [],
        cluster_ln_x,
        cluster_rn_x,
        cluster_bbox_heights,
        rankdir,
        ranks,
        rank_y,
        rank_ht1,
        rank_ht2,
      )
    collect_cluster_bboxes(cluster_layouts, cluster_bboxes)
  }
  cluster_bboxes
}

///|
/// Graphviz parity: label edge counts aligned to refs/graphviz/lib/dotgen/dotsplines.c (label spacing).
/// Do not change behavior without updating fixtures/tests.
fn build_label_edge_counts(
  edges : Array[@cgraph.Edge],
) -> Map[String, Int] {
  let label_edge_counts : Map[String, Int] = Map::new()
  for edge in edges {
    if edge_mid_label_text(edge) is Some(_) {
      let tail = edge.tail().name()
      let current = match label_edge_counts.get(tail) {
        Some(value) => value
        None => 0
      }
      label_edge_counts[tail] = current + 1
    }
  }
  label_edge_counts
}

///|
/// Graphviz parity: complex tuning toggle mirrors fixture gating for dotsplines heuristics.
/// Do not change behavior without updating fixtures/tests.
fn complex_tuning_enabled() -> Bool {
  match @sys.get_env_var("DOT_COMPLEX_TUNING") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}

///|
/// Graphviz parity: port padding aligned to refs/graphviz/lib/dotgen/position.c (sameport/compound spacing).
/// Do not change behavior without updating fixtures/tests.
priv struct PortPadding {
  port_pad_below : Double
  port_pad_above : Double
}

///|
/// Graphviz parity: port padding aligned to refs/graphviz/lib/dotgen/position.c (sameport/compound spacing).
/// Do not change behavior without updating fixtures/tests.
fn compute_port_padding(
  has_clusters : Bool,
  has_port_edges : Bool,
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> PortPadding {
  if has_clusters || !has_port_edges {
    { port_pad_below: 0.0, port_pad_above: 0.0 }
  } else {
    let (port_pad_below, port_pad_above) =
      record_port_padding_y(edges, positions, label_ports_map)
    { port_pad_below, port_pad_above }
  }
}

///|
/// Graphviz parity: head port metrics aligned to refs/graphviz/lib/dotgen/dotsplines.c (curve offsets).
/// Do not change behavior without updating fixtures/tests.
fn collect_head_port_metrics(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  label_ports_map : Map[String, Map[String, RecordPort]],
  record_orientation : RecordOrientation,
  enable_complex_tuning : Bool,
) -> HeadPortMetrics {
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if enable_complex_tuning {
    for edge in edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      let head_port = @dot_shared.port_key(edge.head_port())
      let key =
        if head_port == "" {
        if is_record_shape(edge.head()) { head_name } else { "" }
      } else {
        "\{head_name}:\{head_port}"
      }
      if key == "" {
        continue
      }
      let tail_pos = match positions.get(tail_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let head_pos = match positions.get(head_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let tail_size = match sizes.get(tail_name) {
        Some(value) => value
        None => node_size(edge.tail(), record_orientation)
      }
      let head_size = match sizes.get(head_name) {
        Some(value) => value
        None => node_size(edge.head(), record_orientation)
      }
      let (tail_anchor, _) = port_geometry(
        tail_name,
        edge.tail_port(),
        label_ports_map,
        tail_pos,
        tail_size,
      )
      let (head_anchor, _) = port_geometry(
        head_name,
        edge.head_port(),
        label_ports_map,
        head_pos,
        head_size,
      )
      let dx = head_anchor.x - tail_anchor.x
      let dy = head_anchor.y - tail_anchor.y
      let dist = Double::sqrt(dx * dx + dy * dy)
      let current = match head_port_counts.get(key) {
        Some(value) => value
        None => 0
      }
      head_port_counts[key] = current + 1
      let mut min_dist = match head_port_min_dist.get(key) {
        Some(value) => value
        None => dist
      }
      let mut max_dist = match head_port_max_dist.get(key) {
        Some(value) => value
        None => dist
      }
      if dist < min_dist {
        min_dist = dist
      }
      if dist > max_dist {
        max_dist = dist
      }
      head_port_min_dist[key] = min_dist
      head_port_max_dist[key] = max_dist
    }
  }
  { head_port_counts, head_port_min_dist, head_port_max_dist }
}

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
///|
/// Graphviz parity: rank-based bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_bbox(
  nodes_out : Array[DotLayoutNode],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> @geom.Rect {
  if nodes_out.length() == 0 {
    return { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut first = true
  for node_layout in nodes_out {
    let name = node_layout.node.name()
    let left = node_left_pt(name, sizes)
    let right = node_right_pt(name, sizes)
    let llx = node_layout.pos.x - left
    let urx = node_layout.pos.x + right
    if first {
      min_x = llx
      max_x = urx
      first = false
    } else {
      if llx < min_x { min_x = llx }
      if urx > max_x { max_x = urx }
    }
  }
  let mut min_y = 0.0
  let mut max_y = 0.0
  if all_ranks.length() > 0 {
    let min_rank = all_ranks[0]
    let max_rank = all_ranks[all_ranks.length() - 1]
    let max_rank_y = match rank_y.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    let min_rank_y = match rank_y.get(min_rank) {
      Some(value) => value
      None => 0.0
    }
    let ht1 = match rank_ht1.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    let ht2 = match rank_ht2.get(min_rank) {
      Some(value) => value
      None => 0.0
    }
    min_y = max_rank_y - ht1
    max_y = min_rank_y + ht2
  }
  { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
}

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
priv struct FinalLayoutGeometry {
  final_nodes : Array[DotLayoutNode]
  final_edges : Array[DotLayoutEdge]
  rank_bbox : @geom.Rect
}

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn build_final_layout_geometry(
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> FinalLayoutGeometry {
  let base_bbox = compute_dot_bbox(
    nodes_out,
    all_ranks,
    sizes,
    rank_y,
    rank_ht1,
    rank_ht2,
  )
  { final_nodes: nodes_out, final_edges: edges_out, rank_bbox: base_bbox }
}

///|
/// Graphviz parity: cluster bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
priv struct SubgraphsAndBBox {
  subgraphs : Array[DotLayoutGraph]
  base_bbox : @geom.Rect
}

///|
/// Graphviz parity: cluster bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
fn build_subgraphs_and_bbox(
  graph : @cgraph.Graph,
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
  bbox : @geom.Rect,
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, (Double, Double)],
  rankdir : RankDir,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> SubgraphsAndBBox {
  let subgraphs =
    layout_subgraphs(
      graph,
      nodes,
      edges,
      cluster_ln_x,
      cluster_rn_x,
      cluster_bbox_heights,
      rankdir,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
    )
  let expanded = if subgraphs.length() > 0 {
    expand_bbox_with_clusters(bbox, subgraphs)
  } else {
    bbox
  }
  { subgraphs, base_bbox: expanded }
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterPadding {
  root_cluster_pad_top : Double
  root_cluster_pad_bottom : Double
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn compute_root_cluster_padding(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  all_ranks : Array[Int],
  ranks : Map[String, Int],
) -> RootClusterPadding {
  if graph.is_root() && @dot_shared.graph_has_cluster(graph) && all_ranks.length() > 0 {
    let min_rank = all_ranks[0]
    let max_rank = all_ranks[all_ranks.length() - 1]
    let mut cluster_at_min = false
    let mut cluster_at_max = false
    for node in nodes {
      let cluster_key = node_local_cluster_key(node)
      if cluster_key == "" {
        continue
      }
      match ranks.get(node.name()) {
        Some(rank) => {
          if rank == min_rank {
            cluster_at_min = true
          }
          if rank == max_rank {
            cluster_at_max = true
          }
        }
        None => ()
      }
      if cluster_at_min && cluster_at_max {
        break
      }
    }
    let pad = cluster_margin_pt(graph)
    {
      root_cluster_pad_top: if cluster_at_min { pad } else { 0.0 },
      root_cluster_pad_bottom: if cluster_at_max { pad } else { 0.0 },
    }
  } else {
    { root_cluster_pad_top: 0.0, root_cluster_pad_bottom: 0.0 }
  }
}

///|
/// Graphviz parity: record port padding impact aligned to refs/graphviz/lib/dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn apply_root_port_padding(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
  port_pad_below : Double,
  port_pad_above : Double,
) -> @geom.Rect {
  if graph.is_root() && (rankdir == RankDir::TB || rankdir == RankDir::BT) {
    if port_pad_below > 0.0 || port_pad_above > 0.0 {
      {
        llx: bbox.llx,
        lly: bbox.lly - port_pad_below,
        urx: bbox.urx,
        ury: bbox.ury + port_pad_above,
      }
    } else {
      bbox
    }
  } else {
    bbox
  }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
fn expand_root_bbox_for_label(
  bbox : @geom.Rect,
  padded_width : Double,
  padded_height : Double,
  loc : LabelLoc,
  rankdir : RankDir,
) -> @geom.Rect {
  let mut llx = bbox.llx
  let mut lly = bbox.lly
  let mut urx = bbox.urx
  let mut ury = bbox.ury
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    match loc {
      LabelLoc::Top => urx = urx + padded_height
      LabelLoc::Bottom => llx = llx - padded_height
    }
    let span = ury - lly
    if padded_width > span {
      let diff = (padded_width - span) / 2.0
      lly = lly - diff
      ury = ury + diff
    }
  } else {
    match loc {
      LabelLoc::Top =>
        if rankdir == RankDir::TB {
          ury = ury + padded_height
        } else {
          lly = lly - padded_height
        }
      LabelLoc::Bottom =>
        if rankdir == RankDir::TB {
          lly = lly - padded_height
        } else {
          ury = ury + padded_height
        }
    }
    let span = urx - llx
    if padded_width > span {
      let diff = (padded_width - span) / 2.0
      llx = llx - diff
      urx = urx + diff
    }
  }
  { llx, lly, urx, ury }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
priv struct RootLabelBBoxOutput {
  bbox : @geom.Rect
  label_pos : @geom.Point?
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
fn apply_root_label_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> RootLabelBBoxOutput {
  let mut bbox = bbox
  let mut label_pos : @geom.Point? = None
  if graph.is_root() {
    match graph_label_metrics(graph) {
      Some(metrics) => {
        let loc = graph_label_loc(graph)
        let just = graph_label_just(graph)
        let pad = CLUSTER_LABEL_PAD_PT
        let padded_width = metrics.width_pt + pad * 2.0
        let padded_height = metrics.height_pt + pad
        bbox =
          expand_root_bbox_for_label(
            bbox,
            padded_width,
            padded_height,
            loc,
            rankdir,
          )
        label_pos = Some(
          graph_label_pos(bbox, padded_width, padded_height, loc, just),
        )
      }
      None => ()
    }
  }
  { bbox, label_pos }
}

///|
/// Graphviz parity: root label placement aligned to refs/graphviz/lib/common/postproc.c
/// (place_root_label).
/// Do not change behavior without updating fixtures/tests.
fn root_label_pos_for_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Point? {
  if graph.is_root() {
    match graph_label_metrics(graph) {
      Some(metrics) => {
        let loc = graph_label_loc(graph)
        let just = graph_label_just(graph)
        let pad = CLUSTER_LABEL_PAD_PT
        let padded_width = metrics.width_pt + pad * 2.0
        let padded_height = metrics.height_pt + pad
        Some(
          graph_label_pos(bbox, padded_width, padded_height, loc, just),
        )
      }
      None => None
    }
  } else {
    None
  }
}

///|
/// Graphviz parity: root graph margin aligned to refs/graphviz/lib/common/input.c + dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn apply_root_margin_x(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Rect {
  if graph.is_root() {
    let margin_x = if @dot_shared.graph_has_cluster(graph) {
      graph_margin_x_pt(graph)
    } else {
      0.0
    }
    if margin_x > 0.0 {
      {
        llx: bbox.llx - margin_x,
        lly: bbox.lly,
        urx: bbox.urx + margin_x,
        ury: bbox.ury,
      }
    } else {
      bbox
    }
  } else {
    bbox
  }
}

///|
fn parse_graph_size_pt(graph : @cgraph.Graph) -> (Double, Double)? {
  match graph.get_attr("size") {
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(",") {
        let cleaned = part.trim(chars=" \n\r\t!").to_string()
        if cleaned != "" {
          parts.push(cleaned)
        }
      }
      if parts.length() == 0 {
        return None
      }
      let width_in = @attrs.parse_double(Some(parts[0]), -1.0)
      let height_in = if parts.length() > 1 {
        @attrs.parse_double(Some(parts[1]), -1.0)
      } else {
        width_in
      }
      if width_in <= 0.0 || height_in <= 0.0 {
        return None
      }
      Some((width_in * 72.0, height_in * 72.0))
    }
    None => None
  }
}

///|
/// Graphviz parity: ratio=fill scaling aligned to refs/graphviz/lib/dotgen/position.c
/// (set_aspect R_FILL branch).
fn ratio_fill_scale_factors(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> (Double, Double)? {
  let ratio = match graph.get_attr("ratio") {
    Some(value) => value.trim().to_lower()
    None => return None
  }
  if ratio != "fill" {
    return None
  }
  let (target_w, target_h) = match parse_graph_size_pt(graph) {
    Some(size) => size
    None => return None
  }
  let mut span_w = bbox.urx - bbox.llx
  let mut span_h = bbox.ury - bbox.lly
  if span_w <= 0.0 || span_h <= 0.0 {
    return None
  }
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    let tmp = span_w
    span_w = span_h
    span_h = tmp
  }
  let mut xf = target_w / span_w
  let mut yf = target_h / span_h
  if xf <= 0.0 || yf <= 0.0 {
    return None
  }
  if xf < 1.0 || yf < 1.0 {
    if xf < yf {
      yf = yf / xf
      xf = 1.0
    } else {
      xf = xf / yf
      yf = 1.0
    }
  }
  if flip {
    let tmp = xf
    xf = yf
    yf = tmp
  }
  Some((xf, yf))
}

///|
fn scale_layout_point(point : @geom.Point, sx : Double, sy : Double) -> @geom.Point {
  { x: point.x * sx, y: point.y * sy }
}

///|
fn scale_layout_point_rounded(
  point : @geom.Point,
  sx : Double,
  sy : Double,
) -> @geom.Point {
  { x: (point.x * sx).round(), y: (point.y * sy).round() }
}

///|
fn scale_layout_optional_point(
  point : @geom.Point?,
  sx : Double,
  sy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(scale_layout_point(value, sx, sy))
    None => None
  }
}

///|
fn scale_layout_spline(
  spline : @geom.Spline,
  sx : Double,
  sy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(scale_layout_point(point, sx, sy))
  }
  {
    start: scale_layout_optional_point(spline.start, sx, sy),
    end: scale_layout_optional_point(spline.end, sx, sy),
    points,
  }
}

///|
fn scale_layout_graph(
  layout : DotLayoutGraph,
  sx : Double,
  sy : Double,
  round_node_pos : Bool,
) -> DotLayoutGraph {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let scaled_pos =
      if round_node_pos {
        scale_layout_point_rounded(node_layout.pos, sx, sy)
      } else {
        scale_layout_point(node_layout.pos, sx, sy)
      }
    nodes.push({
      node: node_layout.node,
      pos: scaled_pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: scale_layout_optional_point(node_layout.label_pos, sx, sy),
      xlabel_pos: scale_layout_optional_point(node_layout.xlabel_pos, sx, sy),
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(scale_layout_spline(spline, sx, sy))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: scale_layout_optional_point(edge_layout.label_pos, sx, sy),
      head_label_pos: scale_layout_optional_point(
        edge_layout.head_label_pos,
        sx,
        sy,
      ),
      tail_label_pos: scale_layout_optional_point(
        edge_layout.tail_label_pos,
        sx,
        sy,
      ),
      xlabel_pos: scale_layout_optional_point(edge_layout.xlabel_pos, sx, sy),
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(scale_layout_graph(subgraph, sx, sy, round_node_pos))
  }
  {
    graph: layout.graph,
    bbox: {
      llx: layout.bbox.llx * sx,
      lly: layout.bbox.lly * sy,
      urx: layout.bbox.urx * sx,
      ury: layout.bbox.ury * sy,
    },
    label_pos: scale_layout_optional_point(layout.label_pos, sx, sy),
    nodes,
    edges,
    subgraphs,
  }
}

///|
fn apply_ratio_fill_scale(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  rankdir : RankDir,
  ratio_bbox : @geom.Rect,
) -> DotLayoutGraph {
  if !graph.is_root() {
    return layout
  }
  match ratio_fill_scale_factors(graph, ratio_bbox, rankdir) {
    Some((sx, sy)) => {
      if sx == 1.0 && sy == 1.0 {
        layout
      } else {
        // Graphviz parity: set_aspect rounds ND_coord after scaling.
        scale_layout_graph(layout, sx, sy, true)
      }
    }
    None => layout
  }
}

///|
/// Exterior edge-label nudge heuristic (DOT_ADJUST_EDGE_LABELS only).
fn adjust_edge_labels_if_enabled(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  if edge_label_adjust_enabled() {
    let adjusted_for_clusters =
      adjust_labels_for_clusters(layout, nodesep_pt)
    adjust_labels_for_overlaps(
      adjusted_for_clusters,
      nodesep_pt,
      rankdir,
    )
  } else {
    layout
  }
}

///|
fn mirror_layout_points(
  layout : DotLayoutGraph,
  point_bbox : @geom.Rect,
  bbox_bbox : @geom.Rect,
) -> DotLayoutGraph {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    nodes.push({
      node: node_layout.node,
      pos: transform_point(node_layout.pos, point_bbox, RankDir::BT),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: transform_optional_point(
        node_layout.label_pos,
        point_bbox,
        RankDir::BT,
      ),
      xlabel_pos: transform_optional_point(
        node_layout.xlabel_pos,
        point_bbox,
        RankDir::BT,
      ),
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(transform_spline(spline, point_bbox, RankDir::BT))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: transform_optional_point(
        edge_layout.label_pos,
        point_bbox,
        RankDir::BT,
      ),
      head_label_pos: transform_optional_point(
        edge_layout.head_label_pos,
        point_bbox,
        RankDir::BT,
      ),
      tail_label_pos: transform_optional_point(
        edge_layout.tail_label_pos,
        point_bbox,
        RankDir::BT,
      ),
      xlabel_pos: transform_optional_point(
        edge_layout.xlabel_pos,
        point_bbox,
        RankDir::BT,
      ),
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(
      mirror_layout_points(subgraph, point_bbox, bbox_bbox),
    )
  }
  let mirrored_bbox =
    transform_bbox_with_root(layout.bbox, bbox_bbox, RankDir::BT)
  {
    graph: layout.graph,
    bbox: mirrored_bbox,
    label_pos: layout.label_pos,
    nodes,
    edges,
    subgraphs,
  }
}

///|
fn refresh_cluster_labels(
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(refresh_cluster_labels(subgraph))
  }
  let label_pos =
    if @dot_shared.is_cluster_graph(layout.graph) {
      match graph_label_metrics(layout.graph) {
        Some(metrics) => {
          let pad = CLUSTER_LABEL_PAD_PT
          Some(
            graph_label_pos(
              layout.bbox,
              metrics.width_pt + pad * 2.0,
              metrics.height_pt + pad,
              graph_label_loc(layout.graph),
              graph_label_just(layout.graph),
            ),
          )
        }
        None => layout.label_pos
      }
    } else {
      layout.label_pos
    }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs,
  }
}

///|
/// Graphviz parity: translate to origin aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn shift_layout_to_origin(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  if graph.is_root() {
    let dx = -layout.bbox.llx
    let dy = -layout.bbox.lly
    if dx != 0.0 || dy != 0.0 {
      shift_layout_graph(layout, dx, dy)
    } else {
      layout
    }
  } else {
    layout
  }
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn apply_root_cluster_padding(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  root_cluster_pad_top : Double,
  root_cluster_pad_bottom : Double,
) -> DotLayoutGraph {
  if graph.is_root() &&
    (root_cluster_pad_top > 0.0 || root_cluster_pad_bottom > 0.0) {
    let padded = shift_layout_graph(layout, 0.0, root_cluster_pad_bottom)
    let padded_bbox : @geom.Rect = {
      llx: layout.bbox.llx,
      lly: layout.bbox.lly,
      urx: layout.bbox.urx,
      ury: layout.bbox.ury + root_cluster_pad_bottom + root_cluster_pad_top,
    }
    let label_pos =
      match root_label_pos_for_bbox(graph, padded_bbox) {
        Some(pos) => Some(pos)
        None => padded.label_pos
      }
    {
      graph: padded.graph,
      bbox: padded_bbox,
      label_pos,
      nodes: padded.nodes,
      edges: padded.edges,
      subgraphs: padded.subgraphs,
    }
  } else {
    layout
  }
}

///|
fn refresh_root_label_position(
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  if layout.graph.is_root() {
    let label_pos =
      match root_label_pos_for_bbox(layout.graph, layout.bbox) {
        Some(pos) => Some(pos)
        None => layout.label_pos
      }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    }
  } else {
    layout
  }
}

///|
/// Graphviz parity: postprocess pipeline aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess) + dotgen/position.c (cluster/label spacing).
/// Do not change behavior without updating fixtures/tests.
fn finalize_layout_graph(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
  rankdir : RankDir,
  splines : SplinesMode,
  all_ranks : Array[Int],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, (Double, Double)],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  nodesep_pt : Double,
  port_pad_below : Double,
  port_pad_above : Double,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutGraph {
  let final_geometry =
    build_final_layout_geometry(
      nodes_out,
      edges_out,
      all_ranks,
      sizes,
      rank_y,
      rank_ht1,
      rank_ht2,
    )
  let subgraphs_and_bbox =
    build_subgraphs_and_bbox(
      graph,
      final_geometry.final_nodes,
      final_geometry.final_edges,
      final_geometry.rank_bbox,
      cluster_ln_x,
      cluster_rn_x,
      cluster_bbox_heights,
      rankdir,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
    )
  let root_cluster_padding =
    compute_root_cluster_padding(graph, nodes, all_ranks, ranks)
  // Graphviz parity: rankdir=BT flips top/bottom cluster padding (ranks are inverted).
  let (root_cluster_pad_top, root_cluster_pad_bottom) =
    if rankdir == RankDir::BT {
      (
        root_cluster_padding.root_cluster_pad_bottom,
        root_cluster_padding.root_cluster_pad_top,
      )
    } else {
      (
        root_cluster_padding.root_cluster_pad_top,
        root_cluster_padding.root_cluster_pad_bottom,
      )
    }
  let bbox =
    apply_root_port_padding(
      graph,
      subgraphs_and_bbox.base_bbox,
      rankdir,
      port_pad_below,
      port_pad_above,
    )
  let layout_with_root_pad =
    apply_root_cluster_padding(
      graph,
      {
        graph,
        bbox,
        label_pos: None,
        nodes: final_geometry.final_nodes,
        edges: final_geometry.final_edges,
        subgraphs: subgraphs_and_bbox.subgraphs,
      },
      root_cluster_pad_top,
      root_cluster_pad_bottom,
    )
  // Graphviz parity: ratio=fill uses pre-spline bbox; include rank/cluster
  // padding that is part of set_ycoords before final edge bbox expansion.
  let ratio_bbox = layout_with_root_pad.bbox
  // Graphviz parity: edge splines update bbox after dot_compute_bb (dotsplines.c).
  let bbox =
    expand_bbox_with_edges(layout_with_root_pad.bbox, layout_with_root_pad.edges)
  let layout = {
    graph: layout_with_root_pad.graph,
    bbox,
    label_pos: layout_with_root_pad.label_pos,
    nodes: layout_with_root_pad.nodes,
    edges: layout_with_root_pad.edges,
    subgraphs: layout_with_root_pad.subgraphs,
  }
  let layout =
    apply_ratio_fill_scale(graph, layout, rankdir, ratio_bbox)
  let adjusted = adjust_edge_labels_if_enabled(layout, nodesep_pt, rankdir)
  let labeled =
    expand_bbox_for_edge_labels(
      graph,
      adjusted,
      ranks,
      flat_label_edge_vnodes,
    )
  let with_xlabels = apply_xlabels(graph, labeled, splines)
  let root_label_bbox =
    apply_root_label_bbox(graph, with_xlabels.bbox, rankdir)
  let labeled_with_root = {
    graph: with_xlabels.graph,
    bbox: root_label_bbox.bbox,
    label_pos: root_label_bbox.label_pos,
    nodes: with_xlabels.nodes,
    edges: with_xlabels.edges,
    subgraphs: with_xlabels.subgraphs,
  }
  let rotated = if rankdir == RankDir::TB {
    labeled_with_root
  } else {
    rotate_layout_graph(labeled_with_root, labeled_with_root.bbox, rankdir)
  }
  let cluster_mirror_bbox =
    transform_bbox_with_root(final_geometry.rank_bbox, labeled_with_root.bbox, rankdir)
  let use_cluster_point_mirror =
    subgraphs_and_bbox.base_bbox.urx > final_geometry.rank_bbox.urx &&
    (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(graph)
  let use_lr_multi_cluster_creation_order_mode =
    (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    count_cluster_subgraphs(graph) > 1
  // Graphviz parity: clustered LR/RL layouts are mirrored back after rankdir
  // rotation (dotgen cluster decompose + postproc map_point ordering).
  let rotated = if (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(graph) &&
    !use_lr_multi_cluster_creation_order_mode {
    if use_cluster_point_mirror {
      refresh_cluster_labels(
        mirror_layout_points(
          rotated,
          cluster_mirror_bbox,
          rotated.bbox,
        ),
      )
    } else {
      rotate_layout_graph(rotated, rotated.bbox, RankDir::BT)
    }
  } else {
    rotated
  }
  let rotated_with_margin = {
    graph: rotated.graph,
    bbox: apply_root_margin_x(graph, rotated.bbox),
    label_pos: rotated.label_pos,
    nodes: rotated.nodes,
    edges: rotated.edges,
    subgraphs: rotated.subgraphs,
  }
  refresh_root_label_position(
    shift_layout_to_origin(graph, rotated_with_margin),
  )
}
