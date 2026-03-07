///|
/// Graphviz parity: edge label bbox expansion geometry helper aligned to
/// refs/graphviz/lib/common/utils.c (addLabelBB/compute_bb).
pub(all) struct LabelExtent {
  width : Double
  height : Double
}

///|
/// Graphviz parity: edge label bbox expansion input keeps edge/rank snapshots
/// grouped before updateBB-equivalent traversal.
pub(all) struct ExpandEdgeLabelBboxInput {
  bbox : @geom.Rect
  edges : Array[DotLayoutEdge]
  ranks : Map[String, Int]
  flat_label_edge_vnodes : Map[String, String]
  rankdir : @rankdir.RankDir
}


///|
priv struct FlatEdgeLabelFlags {
  is_flat : Bool
  has_flat_label_vnode : Bool
  skip_mid_label : Bool
}

///|
pub fn expand_bbox_for_label_pos(
  bbox : @geom.Rect,
  pos : @geom.Point?,
  metrics : LabelExtent?,
) -> @geom.Rect {
  match (pos, metrics) {
    (Some(center), Some(extent)) => {
      let half_w = extent.width / 2.0
      let half_h = extent.height / 2.0
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
fn edge_label_extent_for_rankdir(
  metrics : LabelExtent?,
  flip : Bool,
) -> LabelExtent? {
  match metrics {
    Some(value) =>
      if flip {
        Some({ width: value.height, height: value.width })
      } else {
        Some({ width: value.width, height: value.height })
      }
    None => None
  }
}

///|
fn classify_flat_edge_label(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  flat_label_edge_vnodes : Map[String, String],
) -> FlatEdgeLabelFlags {
  let tail = edge.tail().name()
  let head = edge.head().name()
  let is_flat =
    match (ranks.get(tail), ranks.get(head)) {
      (Some(tail_rank), Some(head_rank)) => tail_rank == head_rank
      _ => false
    }
  let has_flat_label_vnode =
    match flat_label_edge_vnodes.get(@edge_identity.edge_key(edge)) {
      Some(_) => true
      None => false
    }
  // Graphviz parity: adjacent flat-edge labels do not update BB
  // (dotsplines.c makeSimpleFlatLabels has no updateBB call).
  // Graphviz parity: self-edge labels still update BB via dotsplines.
  let skip_mid_label = is_flat && !has_flat_label_vnode && tail != head
  { is_flat, has_flat_label_vnode, skip_mid_label }
}

///|
fn expand_bbox_for_edge_mid_label(
  bbox : @geom.Rect,
  edge_layout : DotLayoutEdge,
  flags : FlatEdgeLabelFlags,
  flip : Bool,
) -> @geom.Rect {
  expand_bbox_for_label_pos(
    bbox,
    if flags.skip_mid_label { None } else { edge_layout.label_pos },
    if flags.skip_mid_label {
      None
    } else {
      edge_label_extent_for_rankdir(
        match @edge_label_metrics.edge_mid_label_metrics(edge_layout.edge) {
          Some(metrics) => Some({ width: metrics.width, height: metrics.height })
          None => None
        },
        flip,
      )
    },
  )
}

///|
fn maybe_raise_flat_edge_vnode_bbox_top(
  bbox : @geom.Rect,
  edge_layout : DotLayoutEdge,
  flags : FlatEdgeLabelFlags,
  rankdir : @rankdir.RankDir,
  flip : Bool,
) -> @geom.Rect {
  let edge = edge_layout.edge
  let tail = edge.tail().name()
  let head = edge.head().name()
  if flip || !flags.is_flat || !flags.has_flat_label_vnode || tail == head {
    return bbox
  }
  match edge_layout.label_pos {
    Some(center) => {
      let orientation = @shared.record_layout_orientation(rankdir)
      let tail_half = @node_geometry.node_size(edge.tail(), orientation).height_pt / 2.0
      let head_half = @node_geometry.node_size(edge.head(), orientation).height_pt / 2.0
      let half_height = if tail_half > head_half { tail_half } else { head_half }
      let top = center.y + half_height
      if top > bbox.ury {
        { llx: bbox.llx, lly: bbox.lly, urx: bbox.urx, ury: top }
      } else {
        bbox
      }
    }
    None => bbox
  }
}

///|
fn expand_bbox_for_edge_endpoint_label(
  bbox : @geom.Rect,
  edge_layout : DotLayoutEdge,
  label_pos : @geom.Point?,
  label_attr : String,
  flip : Bool,
) -> @geom.Rect {
  expand_bbox_for_label_pos(
    bbox,
    label_pos,
    edge_label_extent_for_rankdir(
      match @edge_label_metrics.edge_label_metrics_for_attr(edge_layout.edge, label_attr, true) {
        Some(metrics) => Some({ width: metrics.width, height: metrics.height })
        None => None
      },
      flip,
    ),
  )
}

///|
/// Graphviz parity: edge label bbox expansion aligned to refs/graphviz/lib/common/utils.c
/// (addLabelBB/compute_bb) + dotgen/dotsplines.c (updateBB for edge labels).
/// Do not change behavior without updating fixtures/tests.
pub fn expand_bbox_for_edge_labels(
  input : ExpandEdgeLabelBboxInput,
) -> @geom.Rect {
  // Graphviz parity: addLabelBB applies GD_flip for LR/RL, so swap label
  // dimensions in pre-rotation space to match compute_bb.
  let flip =
    input.rankdir == @rankdir.RankDir::LR ||
    input.rankdir == @rankdir.RankDir::RL
  let mut bbox = input.bbox
  for edge_layout in input.edges {
    let flags =
      classify_flat_edge_label(
        edge_layout.edge,
        input.ranks,
        input.flat_label_edge_vnodes,
      )
    bbox =
      expand_bbox_for_edge_mid_label(
        bbox,
        edge_layout,
        flags,
        flip,
      )
    bbox =
      maybe_raise_flat_edge_vnode_bbox_top(
        bbox,
        edge_layout,
        flags,
        input.rankdir,
        flip,

      )
    bbox =
      expand_bbox_for_edge_endpoint_label(
        bbox,
        edge_layout,
        edge_layout.head_label_pos,
        "headlabel",
        flip,
      )
    bbox =
      expand_bbox_for_edge_endpoint_label(
        bbox,
        edge_layout,
        edge_layout.tail_label_pos,
        "taillabel",
        flip,
      )
  }
  bbox
}
