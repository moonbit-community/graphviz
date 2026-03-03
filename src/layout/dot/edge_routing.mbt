///|
fn edge_polyline_points(
  edge : @cgraph.Edge,
  tail_name : String,
  head_name : String,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnode_positions : Map[String, @geom.Point],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  nodesep_pt : Double,
  label_width_pt : Double,
  dotted_weight : Double,
  use_cluster_tuning : Bool,
  split_label : Bool,
  same_local_cluster : Bool,
) -> Array[@geom.Point] {
  let points : Array[@geom.Point] = [tail_anchor]
  let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  let tail_rank_opt = ranks.get(tail_name)
  let head_rank_opt = ranks.get(head_name)
  if vnodes.length() > 0 {
    match (tail_rank_opt, head_rank_opt) {
      (Some(tail_rank), Some(head_rank)) => {
        let span = head_rank - tail_rank
        if span == 0 {
          let push_flat_point = (name : String) => {
            match vnode_positions.get(name) {
              Some(pos) =>
                if label_width_pt > 0.0 {
                  let half = label_width_pt / 2.0
                  let bend_y =
                    match edge_mid_label_metrics(edge) {
                      Some(metrics) => {
                        let label_top = pos.y + metrics.height / 2.0
                        let source_y =
                          if tail_anchor.x <= head_anchor.x {
                            tail_anchor.y
                          } else {
                            head_anchor.y
                          }
                        let ydelta = (pos.y - source_y) / 6.0
                        let lift = if ydelta > 5.0 { ydelta } else { 5.0 }
                        label_top - lift
                      }
                      None => pos.y
                    }
                  if tail_anchor.x <= head_anchor.x {
                    points.push({ x: pos.x - half, y: bend_y })
                    points.push({ x: pos.x + half, y: bend_y })
                  } else {
                    points.push({ x: pos.x + half, y: bend_y })
                    points.push({ x: pos.x - half, y: bend_y })
                  }
                } else {
                  points.push(pos)
                }
              None => ()
            }
          }
          if tail_anchor.x <= head_anchor.x {
            for name in vnodes {
              push_flat_point(name)
            }
          } else {
            let mut idx = vnodes.length()
            while idx > 0 {
              idx = idx - 1
              let name = vnodes[idx]
              push_flat_point(name)
            }
          }
        } else {
          let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
          let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
          let label_rank = if label_width_pt > 0.0 {
            (min_rank + max_rank) / 2
          } else {
            -1
          }
          let y_dir = if head_anchor.y < tail_anchor.y { 1.0 } else { -1.0 }
          let style_value = match edge.get_attr("style") {
            Some(value) => value.to_lower()
            None => ""
          }
          let is_dotted = style_value.contains("dotted")
          let has_explicit_port =
            @dot_shared.port_is_explicit(tail_port) || @dot_shared.port_is_explicit(head_port)
          let base_vnode_weight =
            if use_cluster_tuning {
              if is_dotted {
                if same_local_cluster { dotted_weight * 0.7 } else { dotted_weight }
              } else if split_label {
                0.3
              } else if label_width_pt > 0.0 && !has_explicit_port {
                if same_local_cluster {
                  1.0
                } else {
                  0.4
                }
              } else {
                0.0
              }
            } else {
              DEFAULT_VNODE_WEIGHT
            }
          let span_f = Double::from_int(span)
          let push_point = (name : String) => {
            match vnode_positions.get(name) {
              Some(pos) =>
                match vnode_ranks.get(name) {
                  Some(rank) => {
                    let t_raw = Double::from_int(rank - tail_rank) / span_f
                    let t =
                      if use_cluster_tuning && !is_dotted && head_anchor.x >= tail_anchor.x {
                        if split_label && rank == label_rank {
                          t_raw
                        } else {
                          t_raw * t_raw
                        }
                      } else {
                        t_raw
                      }
                    let interp_x = tail_anchor.x + (head_anchor.x - tail_anchor.x) * t
                    let base_y = match rank_y.get(rank) {
                      Some(value) => value
                      None => pos.y
                    }
                    let base_offset = match rank_ht1.get(rank) {
                      Some(value) => value
                      None => 0.0
                    }
                    let y = base_y + base_offset
                    let vnode_weight = base_vnode_weight
                    let x = pos.x * vnode_weight + interp_x * (1.0 - vnode_weight)
                    if split_label && rank == label_rank {
                      let split_width = label_width_pt * 1.5
                      let split_x = x - nodesep_pt * 1.25
                      points.push({
                        x: split_x - nodesep_pt,
                        y: y + nodesep_pt * y_dir,
                      })
                      points.push({
                        x: split_x + split_width * 0.5,
                        y: y - nodesep_pt * y_dir,
                      })
                    } else {
                      points.push({ x, y })
                    }
                  }
                  None => ()
                }
              None => ()
            }
          }
          if tail_rank <= head_rank {
            for name in vnodes {
              push_point(name)
            }
          } else {
            let mut idx = vnodes.length()
            while idx > 0 {
              idx = idx - 1
              let name = vnodes[idx]
              push_point(name)
            }
          }
        }
      }
      _ => ()
    }
  }
  points.push(head_anchor)
  points
}
