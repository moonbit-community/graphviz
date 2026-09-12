///|
// common/splines.c beginpath/endpath, FLATEDGE branch.
fn flat_endpoint_boxes(
  bounds : @geom.Rect,
  pos : @geom.Point,
  size : NodeSize,
  anchor : @geom.Point,
  side : Int,
  route_side : Int,
  tail : Bool,
  ranksep : Double,
  rank_height : Double,
  port_box : @geom.Rect?,
) -> EndpathResult {
  let boxes : Array[@geom.Rect] = []
  let top = pos.y + size.height_pt / 2.0
  let bottom = pos.y - size.height_pt / 2.0
  let endpoint = if (side & SIDE_TOP) != 0 {
    boxes.push({ ..bounds, lly: min_double(bounds.lly, anchor.y), })
    { ..anchor, y: anchor.y + 1.0, }
  } else if (side & SIDE_BOTTOM) != 0 {
    if route_side == SIDE_TOP {
      if tail {
        boxes.push(
          rect(anchor.x, bottom - ranksep / 2.0, bounds.urx + 1.0, bottom),
        )
        boxes.push(rect(pos.x + size.right_pt, bottom, bounds.urx + 1.0, top))
      } else {
        boxes.push(
          rect(bounds.llx - 1.0, bottom - ranksep / 2.0, anchor.x, bottom),
        )
        boxes.push(
          rect(bounds.llx - 1.0, bottom, pos.x - size.left_pt - 2.0, top),
        )
      }
    } else {
      boxes.push({ ..bounds, ury: max_double(bounds.ury, anchor.y), })
    }
    { ..anchor, y: anchor.y - 1.0, }
  } else if (side & SIDE_LEFT) != 0 {
    boxes.push(
      if route_side == SIDE_TOP {
        rect(bounds.llx, anchor.y - 1.0, anchor.x + 1.0, top)
      } else {
        rect(bounds.llx, bottom, anchor.x + 1.0, anchor.y + 1.0)
      },
    )
    { ..anchor, x: anchor.x - 1.0, }
  } else if (side & SIDE_RIGHT) != 0 {
    boxes.push(
      if route_side == SIDE_TOP {
        let pad = if tail { 0.0 } else { 1.0 }
        rect(anchor.x - pad, anchor.y - pad, bounds.urx, top)
      } else {
        rect(
          anchor.x - (if tail { 0.0 } else { 1.0 }),
          bottom,
          bounds.urx,
          anchor.y + (if tail { 1.0 } else { 0.0 }),
        )
      },
    )
    { ..anchor, x: anchor.x + 1.0, }
  } else {
    boxes.push(
      port_box.unwrap_or(
        if route_side == SIDE_TOP {
          { ..bounds, lly: anchor.y, }
        } else {
          { ..bounds, ury: anchor.y, }
        },
      ),
    )
    anchor
  }
  let last = boxes[boxes.length() - 1]
  let extension = if route_side == SIDE_TOP {
    rect(bounds.llx, last.ury, bounds.urx, pos.y + rank_height)
  } else {
    rect(bounds.llx, pos.y - rank_height, bounds.urx, last.lly)
  }
  if extension.llx < extension.urx && extension.lly < extension.ury {
    boxes.push(extension)
  }
  { boxes, endpoint, }
}

///|
fn flat_corridor_route(
  tail : EndpathResult,
  head : EndpathResult,
  route_side : Int,
  stepx : Double,
  stepy : Double,
) -> PathplanResult? {
  let first = tail.boxes[tail.boxes.length() - 1]
  let last = head.boxes[head.boxes.length() - 1]
  let middle = if route_side == SIDE_TOP {
    [
      rect(first.llx, first.ury, first.urx + stepx, first.ury + stepy),
      rect(first.llx, first.ury + stepy, last.urx, first.ury + 2.0 * stepy),
      rect(last.llx - stepx, last.ury, last.urx, first.ury + stepy),
    ]
  } else {
    [
      rect(first.llx, first.lly - stepy, first.urx + stepx, first.lly),
      rect(first.llx, first.lly - 2.0 * stepy, last.urx, first.lly - stepy),
      rect(last.llx - stepx, first.lly - stepy, last.urx, last.lly),
    ]
  }
  let boxes = [..tail.boxes, ..middle]
  for i = head.boxes.length() - 1; i >= 0; i = i - 1 {
    boxes.push(head.boxes[i])
  }
  guard route_pathplan_from_boxes(boxes, tail.endpoint, head.endpoint)
    is Some(route) else {
    return None
  }
  Some({
    points: route.points,
    barriers: polygon_edges(route.polygon),
    boxes: route.boxes,
    segments: [],
  })
}
