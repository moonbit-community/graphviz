///|
/// Root-graph geometry kernels: cluster/port padding, root label bbox
/// placement, and root margin expansion. These helpers do not mutate
/// DotLayoutGraph trees directly.

type RankDir = @shared.RankDir
type LabelLoc = @shared.LabelLoc
type LabelJust = @shared.LabelJust

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
pub struct RootClusterPadding {
  root_cluster_pad_top : Double
  root_cluster_pad_bottom : Double
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_root_cluster_padding(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  all_ranks : Array[Int],
  ranks : Map[String, Int],
) -> RootClusterPadding {
  if graph.is_root() && @shared.graph_has_cluster(graph) && all_ranks.length() > 0 {
    let min_rank = all_ranks[0]
    let max_rank = all_ranks[all_ranks.length() - 1]
    let mut cluster_at_min = false
    let mut cluster_at_max = false
    for node in nodes {
      let cluster_key = @clustering.node_local_cluster_key(node)
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
    let pad = @clustering.cluster_margin_pt(graph)
    {
      root_cluster_pad_top: if cluster_at_min { pad } else { 0.0 },
      root_cluster_pad_bottom: if cluster_at_max { pad } else { 0.0 },
    }
  } else {
    { root_cluster_pad_top: 0.0, root_cluster_pad_bottom: 0.0 }
  }
}


///|
/// Graphviz parity: rankdir=BT flips top/bottom root cluster padding because
/// ranks are inverted before postprocess transform.
pub fn root_cluster_padding_for_rankdir(
  rankdir : RankDir,
  root_cluster_padding : RootClusterPadding,
) -> (Double, Double) {
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
}

///|
/// Graphviz parity: record port padding impact aligned to refs/graphviz/lib/dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_root_port_padding(
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
fn root_graph_label_metrics(graph : @cgraph.Graph) -> @shared.GraphLabelMetrics? {
  @shared.graph_label_metrics_with(graph, @label_metrics.label_text_dimensions)
}

///|
/// Root-label bbox and margin helpers used by final postprocess.

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
pub struct RootLabelBBoxOutput {
  bbox : @geom.Rect
  label_pos : @geom.Point?
}

///|
priv struct RootLabelPlacementSpec {
  padded_width : Double
  padded_height : Double
  loc : LabelLoc
  just : LabelJust
}

///|
/// Graphviz parity: root-label placement spec reads graph label metrics + attrs
/// once per call path before bbox/position emission.
fn root_label_placement_spec(
  graph : @cgraph.Graph,
) -> RootLabelPlacementSpec? {
  if !graph.is_root() {
    return None
  }
  match root_graph_label_metrics(graph) {
    Some(metrics) => {
      let pad = @clustering.CLUSTER_LABEL_PAD_PT
      Some({
        padded_width: metrics.width_pt + pad * 2.0,
        padded_height: metrics.height_pt + pad,
        loc: @shared.graph_label_loc(graph),
        just: @shared.graph_label_just(graph),
      })
    }
    None => None
  }
}

///|
/// Graphviz parity: root label bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
pub fn apply_root_label_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> RootLabelBBoxOutput {
  let mut bbox = bbox
  let mut label_pos : @geom.Point? = None
  match root_label_placement_spec(graph) {
    Some(spec) => {
      bbox =
        expand_root_bbox_for_label(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          rankdir,
        )
      label_pos = Some(
        @shared.graph_label_pos(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          spec.just,
        ),
      )
    }
    None => ()
  }
  { bbox, label_pos }
}

///|
/// Graphviz parity: root label placement aligned to refs/graphviz/lib/common/postproc.c
/// (place_root_label).
/// Do not change behavior without updating fixtures/tests.
pub fn root_label_pos_for_bbox(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Point? {
  match root_label_placement_spec(graph) {
    Some(spec) =>
      Some(
        @shared.graph_label_pos(
          bbox,
          spec.padded_width,
          spec.padded_height,
          spec.loc,
          spec.just,
        ),
      )
    None => None
  }
}

///|
/// Graphviz parity: root graph margin aligned to refs/graphviz/lib/common/input.c + dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_root_margin_x(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Rect {
  if graph.is_root() {
    let margin_x = if @shared.graph_has_cluster(graph) {
      @label_attrs.graph_margin_x_pt(graph)
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
