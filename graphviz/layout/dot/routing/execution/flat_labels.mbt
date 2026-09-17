///|
priv struct FlatLabelEdge {
  base : EdgeRouteBase
  width : Double
  height : Double
  labeled : Bool
}

///|
// dotsplines.c makeSimpleFlatLabels: widest label first, then alternate
// below and above the preceding labels in a shared routing polygon.
fn maybe_build_flat_labeled_group(
  input : OrderedEdgeLayoutAttemptInput,
) -> Bool {
  guard input.base.is_flat_adjacent &&
    input.input.regular_pass_input.spline_mode > 1 else {
    return false
  }
  let group : Array[FlatLabelEdge] = []
  for edge in input.input.ordered_edges {
    guard input.input.base_cache.get(edge.id()) is Some(base) &&
      same_endpoint_set(input.base, base) else {
      continue
    }
    guard !@edge_identity.port_is_explicit(edge.tail_port()) &&
      !@edge_identity.port_is_explicit(edge.head_port()) &&
      !@edge_ops.edge_has_sameport_mark(edge) else {
      return false
    }
    let metrics = @edge_label_metrics.edge_mid_label_metrics(edge)
    group.push({
      base,
      width: metrics.map_or(0.0, value => value.width),
      height: metrics.map_or(0.0, value => value.height),
      labeled: metrics is Some(_),
    })
  }
  group.sort_by((a, b) => {
    guard a.labeled == b.labeled else { if a.labeled { -1 } else { 1 } }
    let width_cmp = cmp_double(b.width, a.width)
    guard width_cmp == 0 else { width_cmp }
    cmp_double(b.height, a.height)
  })
  guard group.length() > 1 && group[0].labeled else { return false }
  let base = input.base
  let forward = base.tail_pos.x < base.head_pos.x
  let tp = if forward { base.tail_pos } else { base.head_pos }
  let hp = if forward { base.head_pos } else { base.tail_pos }
  let tail_size = if forward { base.tail_size } else { base.head_size }
  let head_size = if forward { base.head_size } else { base.tail_size }
  let leftend = tp.x + tail_size.right_pt
  let rightend = hp.x - head_size.left_pt
  let ctrx = (leftend + rightend) / 2.0
  let space = 6.0
  let uminx = ctrx - group[0].width / 2.0
  let umaxx = ctrx + group[0].width / 2.0
  let mut miny = tp.y + space / 2.0
  let mut maxy = miny + group[0].height
  let mut lminx = 0.0
  let mut lmaxx = 0.0
  for i, entry in group {
    let (bezier, label_y) = if i == 0 {
      ([tp, tp, hp, hp], tp.y + (entry.height + space) / 2.0)
    } else {
      let (polygon, label_y) = if i % 2 == 1 {
        if i == 1 {
          lminx = if entry.labeled {
            ctrx - entry.width / 2.0
          } else {
            (2.0 * leftend + rightend) / 3.0
          }
          lmaxx = if entry.labeled {
            ctrx + entry.width / 2.0
          } else {
            (leftend + 2.0 * rightend) / 3.0
          }
        }
        miny -= space + entry.height
        (
          [
            tp,
            { x: tp.x, y: miny - space, },
            { x: hp.x, y: miny - space, },
            hp,
            { x: lmaxx, y: hp.y, },
            { x: lmaxx, y: miny, },
            { x: lminx, y: miny, },
            { x: lminx, y: tp.y, },
          ],
          miny + entry.height / 2.0,
        )
      } else {
        let polygon = [
          tp,
          { x: uminx, y: tp.y, },
          { x: uminx, y: maxy, },
          { x: umaxx, y: maxy, },
          { x: umaxx, y: hp.y, },
          hp,
          { x: hp.x, y: maxy + space, },
          { x: tp.x, y: maxy + space, },
        ]
        let label_y = maxy + entry.height / 2.0 + space
        maxy += entry.height + space
        (polygon, label_y)
      }
      let points = @pathplan.shortest_path_in_poly(polygon, tp, hp)
      let barriers = polygon.mapi((index, point) => {
        (point, polygon[(index + 1) % polygon.length()])
      })
      (
        @edge_spline.edge_spline_raw_for_points(
          points,
          { x: 0.0, y: 0.0, },
          { x: 0.0, y: 0.0, },
          false,
          route_barriers=barriers,
        ),
        label_y,
      )
    }
    let oriented = if entry.base.tail_pos.x < entry.base.head_pos.x {
      bezier
    } else {
      bezier.rev()
    }
    let layout = @emit.build_flat_adjacent_layout(
      entry.base,
      oriented,
      input.callbacks.build_edge_layout_fn,
    )
    input.state.edges_out_by_id[entry.base.edge.id()] = {
      ..layout,
      label_pos: if entry.labeled {
        Some({ x: ctrx, y: label_y, })
      } else {
        None
      },
    }
  }
  true
}
