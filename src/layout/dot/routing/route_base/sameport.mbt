/// Graphviz parity: samehead/sametail group collection aligned to
/// refs/graphviz/lib/dotgen/sameport.c (dot_sameports/sameedge).
/// Do not change behavior without updating fixtures/tests.
fn add_sameport_group_edge(
  groups : Map[String, Array[@cgraph.Edge]],
  group_order : Array[String],
  key : String,
  edge : @cgraph.Edge,
) -> Unit {
  match groups.get(key) {
    Some(list) => list.push(edge)
    None => {
      groups[key] = [edge]
      group_order.push(key)
    }
  }
}

///|
fn sameport_merge_key(edge : @cgraph.Edge) -> String {
  let label = @edge_semantics.edge_attr_or_empty(edge, "label")
  "\{edge.tail().name()}|\{edge.head().name()}|\{label}|\{@edge_identity.port_key(edge.tail_port())}|\{@edge_identity.port_key(edge.head_port())}"
}

///|
fn collect_sameport_classes(
  edges : Array[@cgraph.Edge],
) -> Map[String, Array[@cgraph.Edge]] {
  let classes : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    if @edge_semantics.edge_is_self(edge) {
      continue
    }
    let key = sameport_merge_key(edge)
    match classes.get(key) {
      Some(list) => list.push(edge)
      None => classes[key] = [edge]
    }
  }
  classes
}

///|
fn for_each_sameport_class_member_edge_id(
  merge_classes : Map[String, Array[@cgraph.Edge]],
  edge : @cgraph.Edge,
  apply_id : (Int) -> Unit,
) -> Unit {
  if @edge_semantics.edge_has_label(edge) {
    apply_id(edge.id())
    return ()
  }
  match merge_classes.get(sameport_merge_key(edge)) {
    Some(class_edges) =>
      for member_edge in class_edges {
        apply_id(member_edge.id())
      }
    None => apply_id(edge.id())
  }
}

///|
fn assign_sameport_override(
  overrides : Map[Int, @geom.Point],
  merge_classes : Map[String, Array[@cgraph.Edge]],
  edge : @cgraph.Edge,
  anchor : @geom.Point,
) -> Unit {
  for_each_sameport_class_member_edge_id(
    merge_classes,
    edge,
    (member_edge_id) => overrides[member_edge_id] = anchor,
  )
}

///|
fn assign_sameport_group_size(
  group_sizes : Map[Int, Int],
  merge_classes : Map[String, Array[@cgraph.Edge]],
  edge : @cgraph.Edge,
  group_size : Int,
) -> Unit {
  for_each_sameport_class_member_edge_id(
    merge_classes,
    edge,
    (member_edge_id) => group_sizes[member_edge_id] = group_size,
  )
}

///|
fn sameport_node_penwidth_pt(node : @cgraph.Node) -> Double {
  match node.get_attr("penwidth") {
    Some(value) => {
      let penwidth = @numeric.parse_double_or(value, 1.0)
      if penwidth < 0.0 {
        0.0
      } else {
        penwidth
      }
    }
    None => 1.0
  }
}

///|
fn sameport_shape_has_outline(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "plain" | "plaintext" | "none" => false
    _ => true
  }
}

///|
/// Graphviz parity: sameport anchor construction aligned to
/// refs/graphviz/lib/dotgen/sameport.c (sameport).
/// Do not change behavior without updating fixtures/tests.
priv struct SameportAnchorInput {
  node : @cgraph.Node
  group_edges : Array[@cgraph.Edge]
  head_group : Bool
  positions : Map[String, @geom.Point]
  sizes : Map[String, NodeSize]
  node_size_for_missing : (@cgraph.Node) -> NodeSize
  layout_rankdir : RankDir
  ranksep_pt : Double
}

///|
fn sameport_anchor_for_group(
  input : SameportAnchorInput,
) -> @geom.Point? {
  let node = input.node
  let group_edges = input.group_edges
  let head_group = input.head_group
  let positions = input.positions
  let sizes = input.sizes
  let node_size_for_missing = input.node_size_for_missing
  let layout_rankdir = input.layout_rankdir
  let ranksep_pt = input.ranksep_pt
  let node_name = node.name()
  let node_pos = match positions.get(node_name) {
    Some(value) => value
    None => return None
  }
  let node_size =
    size_for_name_or_node(
      sizes,
      node_name,
      node,
      node_size_for_missing,
    )
  let base_clip_size =
    match layout_rankdir {
      RankDir::LR | RankDir::RL =>
        @node_primitives.node_size_from_points(node_size.height_pt, node_size.width_pt)
      RankDir::TB | RankDir::BT => node_size
    }
  let clip_size =
    if group_edges.length() > 3 {
      base_clip_size
    } else {
      let clip_size =
        if sameport_shape_has_outline(node) {
          let penwidth = sameport_node_penwidth_pt(node)
          if penwidth > 0.0 {
            @node_primitives.node_size_from_points(
              base_clip_size.width_pt + penwidth / 2.0,
              base_clip_size.height_pt + penwidth / 2.0,
            )
          } else {
            base_clip_size
          }
        } else {
          base_clip_size
        }
      if group_edges.length() > 2 {
        @node_primitives.node_size_from_points(
          clip_size.width_pt + 2.0,
          clip_size.height_pt + 2.0,
        )
      } else {
        clip_size
      }
    }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for edge in group_edges {
    let peer_name = if head_group { edge.tail().name() } else { edge.head().name() }
    let peer_pos = match positions.get(peer_name) {
      Some(value) => value
      None => continue
    }
    let dx = peer_pos.x - node_pos.x
    let dy = peer_pos.y - node_pos.y
    let len = Double::sqrt(dx * dx + dy * dy)
    if len <= 0.0 {
      continue
    }
    sum_x = sum_x + dx / len
    sum_y = sum_y + dy / len
  }
  let sum_len = Double::sqrt(sum_x * sum_x + sum_y * sum_y)
  if sum_len <= 0.0 {
    return None
  }
  let dir_x = sum_x / sum_len
  let dir_y = sum_y / sum_len
  let far = max_double(
    clip_size.left_pt + clip_size.right_pt,
    clip_size.height_pt + ranksep_pt,
  )
  let target = @edge_spline.point(node_pos.x + dir_x * far, node_pos.y + dir_y * far)
  let clipped0 = clip_to_node_shape(node, node_pos, clip_size, target)
  let clipped =
    if group_edges.length() > 3 {
      if Double::abs(dir_x) <= Double::abs(dir_y) * 0.25 {
        @edge_spline.point(clipped0.x + dir_x, clipped0.y + dir_y)
      } else {
        clipped0
      }
    } else {
      let sameport_nudge =
        if group_edges.length() > 2 {
          0.5
        } else {
          1.0
        }
      @edge_spline.point(
        clipped0.x + dir_x * sameport_nudge,
        clipped0.y + dir_y * sameport_nudge,
      )
    }
  // Graphviz sameport stores integer offset from node center.
  let rel_x = (clipped.x - node_pos.x).round()
  let rel_y = (clipped.y - node_pos.y).round()
  Some(@edge_spline.point(node_pos.x + rel_x, node_pos.y + rel_y))
}

///|
priv struct SameportOverrides {
  samehead_anchors : Map[Int, @geom.Point]
  sametail_anchors : Map[Int, @geom.Point]
  samehead_group_sizes : Map[Int, Int]
  sametail_group_sizes : Map[Int, Int]
}

///|
priv struct EdgeSameportOrientationInfo {
  tail_anchor : @geom.Point?
  head_anchor : @geom.Point?
  tail_group_size : Int
  head_group_size : Int
}

///|
priv struct OrientedEdgeEndpointsForRoute {
  tail_name : String
  head_name : String
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_node : @cgraph.Node
  head_node : @cgraph.Node
}

///|
fn oriented_edge_endpoints_for_route(
  edge : @cgraph.Edge,
  swap_ends : Bool,
) -> OrientedEdgeEndpointsForRoute {
  if swap_ends {
    {
      tail_name: edge.head().name(),
      head_name: edge.tail().name(),
      tail_port: edge.head_port(),
      head_port: edge.tail_port(),
      tail_node: edge.head(),
      head_node: edge.tail(),
    }
  } else {
    {
      tail_name: edge.tail().name(),
      head_name: edge.head().name(),
      tail_port: edge.tail_port(),
      head_port: edge.head_port(),
      tail_node: edge.tail(),
      head_node: edge.head(),
    }
  }
}

///|
/// Graphviz parity: same-rank intercluster edges keep original direction in
/// route base setup even when edgecmp would otherwise swap endpoints.
priv struct RouteBaseSwapEndsInput {
  edge : @cgraph.Edge
  orig_tail_name : String
  orig_head_name : String
  ranks : Map[String, Int]
  order_index : Map[String, Int]
  node_local_cluster_key_fn : (@cgraph.Node) -> String
}

///|
fn edge_swap_ends_for_route_base(
  input : RouteBaseSwapEndsInput,
) -> Bool {
  let edge = input.edge
  let orig_tail_name = input.orig_tail_name
  let orig_head_name = input.orig_head_name
  let ranks = input.ranks
  let order_index = input.order_index
  let node_local_cluster_key_fn = input.node_local_cluster_key_fn
  let swap_ends_raw =
    @edge_ops.edge_swap_ends(orig_tail_name, orig_head_name, ranks, order_index)
  let tail_rank_for_swap = ranks.get(orig_tail_name).unwrap_or_default()
  let head_rank_for_swap = ranks.get(orig_head_name).unwrap_or_default()
  if tail_rank_for_swap == head_rank_for_swap &&
    node_local_cluster_key_fn(edge.tail()) != node_local_cluster_key_fn(edge.head()) {
    false
  } else {
    swap_ends_raw
  }
}

///|
fn edge_sameport_orientation_info(
  edge_id : Int,
  sameport_overrides : SameportOverrides,
  swap_ends : Bool,
) -> EdgeSameportOrientationInfo {
  let samehead_anchor = sameport_overrides.samehead_anchors.get(edge_id)
  let sametail_anchor = sameport_overrides.sametail_anchors.get(edge_id)
  let samehead_group_size =
    sameport_overrides.samehead_group_sizes.get(edge_id).unwrap_or_default()
  let sametail_group_size =
    sameport_overrides.sametail_group_sizes.get(edge_id).unwrap_or_default()
  let tail_anchor = if swap_ends { samehead_anchor } else { sametail_anchor }
  let head_anchor = if swap_ends { sametail_anchor } else { samehead_anchor }
  let tail_group_size =
    if swap_ends { samehead_group_size } else { sametail_group_size }
  let head_group_size =
    if swap_ends { sametail_group_size } else { samehead_group_size }
  { tail_anchor, head_anchor, tail_group_size, head_group_size }
}

///|
priv struct SameportGroupOverridesApplyInput {
  groups : Map[String, Array[@cgraph.Edge]]
  group_order : Array[String]
  head_group : Bool
  overrides : Map[Int, @geom.Point]
  group_sizes : Map[Int, Int]
  merge_classes : Map[String, Array[@cgraph.Edge]]
  positions : Map[String, @geom.Point]
  sizes : Map[String, NodeSize]
  node_size_for_missing : (@cgraph.Node) -> NodeSize
  layout_rankdir : RankDir
  ranksep_pt : Double
}

///|
fn apply_sameport_group_overrides(
  input : SameportGroupOverridesApplyInput,
) -> Unit {
  let groups = input.groups
  let group_order = input.group_order
  let head_group = input.head_group
  let overrides = input.overrides
  let group_sizes = input.group_sizes
  let merge_classes = input.merge_classes
  let positions = input.positions
  let sizes = input.sizes
  let node_size_for_missing = input.node_size_for_missing
  let layout_rankdir = input.layout_rankdir
  let ranksep_pt = input.ranksep_pt
  for key in group_order {
    let group_edges = match groups.get(key) {
      Some(value) => value
      None => continue
    }
    if group_edges.length() <= 1 {
      continue
    }
    let anchor_node =
      if head_group { group_edges[0].head() } else { group_edges[0].tail() }
    match sameport_anchor_for_group(
      {
        node: anchor_node,
        group_edges,
        head_group,
        positions,
        sizes,
        node_size_for_missing,
        layout_rankdir,
        ranksep_pt,
      },
    ) {
      Some(anchor) =>
        for edge in group_edges {
          assign_sameport_override(overrides, merge_classes, edge, anchor)
          assign_sameport_group_size(
            group_sizes,
            merge_classes,
            edge,
            group_edges.length(),
          )
        }
      None => ()
    }
  }
}

///|
/// Graphviz parity: samehead/sametail handling aligned to
/// refs/graphviz/lib/dotgen/sameport.c (dot_sameports).
/// Do not change behavior without updating fixtures/tests.
priv struct SameportOverridesCollectInput {
  edges : Array[@cgraph.Edge]
  positions : Map[String, @geom.Point]
  sizes : Map[String, NodeSize]
  node_size_for_missing : (@cgraph.Node) -> NodeSize
  layout_rankdir : RankDir
  ranksep_pt : Double
}

///|
fn collect_sameport_overrides(
  input : SameportOverridesCollectInput,
) -> SameportOverrides {
  let edges = input.edges
  let positions = input.positions
  let sizes = input.sizes
  let node_size_for_missing = input.node_size_for_missing
  let layout_rankdir = input.layout_rankdir
  let ranksep_pt = input.ranksep_pt
  let samehead_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  let sametail_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  let samehead_group_order : Array[String] = []
  let sametail_group_order : Array[String] = []
  let merge_classes = collect_sameport_classes(edges)
  for edge in edges {
    if @edge_semantics.edge_is_self(edge) {
      continue
    }
    let samehead_id = @edge_semantics.edge_attr_or_empty(edge, "samehead")
    if samehead_id != "" {
      add_sameport_group_edge(
        samehead_groups,
        samehead_group_order,
        "\{edge.head().name()}|\{samehead_id}",
        edge,
      )
    }
    let sametail_id = @edge_semantics.edge_attr_or_empty(edge, "sametail")
    if sametail_id != "" {
      add_sameport_group_edge(
        sametail_groups,
        sametail_group_order,
        "\{edge.tail().name()}|\{sametail_id}",
        edge,
      )
    }
  }
  let samehead_overrides : Map[Int, @geom.Point] = Map::new()
  let samehead_group_sizes : Map[Int, Int] = Map::new()
  apply_sameport_group_overrides(
    {
      groups: samehead_groups,
      group_order: samehead_group_order,
      head_group: true,
      overrides: samehead_overrides,
      group_sizes: samehead_group_sizes,
      merge_classes,
      positions,
      sizes,
      node_size_for_missing,
      layout_rankdir,
      ranksep_pt,
    },
  )
  let sametail_overrides : Map[Int, @geom.Point] = Map::new()
  let sametail_group_sizes : Map[Int, Int] = Map::new()
  apply_sameport_group_overrides(
    {
      groups: sametail_groups,
      group_order: sametail_group_order,
      head_group: false,
      overrides: sametail_overrides,
      group_sizes: sametail_group_sizes,
      merge_classes,
      positions,
      sizes,
      node_size_for_missing,
      layout_rankdir,
      ranksep_pt,
    },
  )
  {
    samehead_anchors: samehead_overrides,
    sametail_anchors: sametail_overrides,
    samehead_group_sizes,
    sametail_group_sizes,
  }
}
