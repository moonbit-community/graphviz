///|
/// Exterior-label placement core: xlabel metrics, overlap scoring, candidate
/// search, and xlabels.c-style candidate selection.

const XLXDENOM : Double = 8.0

///|
const XLYDENOM : Double = 2.0

const XLPXPY : Int = 0
const XLCXPY : Int = 1
const XLNXPY : Int = 2
const XLPXCY : Int = 3
const XLNXCY : Int = 5
const XLPXNY : Int = 6
const XLCXNY : Int = 7
const XLNXNY : Int = 8

///|
priv struct XBestPos {
  n : Int
  area : Double
  pos : @geom.Point
}

fn rect_overlap_area(a : @geom.Rect, b : @geom.Rect) -> Double {
  let min_x = if a.llx > b.llx { a.llx } else { b.llx }
  let max_x = if a.urx < b.urx { a.urx } else { b.urx }
  let min_y = if a.lly > b.lly { a.lly } else { b.lly }
  let max_y = if a.ury < b.ury { a.ury } else { b.ury }
  if max_x > min_x && max_y > min_y {
    (max_x - min_x) * (max_y - min_y)
  } else {
    0.0
  }
}

fn rect_from_object(obj : XObject) -> @geom.Rect {
  let llx = obj.pos.x.round()
  let lly = obj.pos.y.round()
  let urx = (obj.pos.x + obj.width).round()
  let ury = (obj.pos.y + obj.height).round()
  { llx, lly, urx, ury }
}

fn rect_from_label(label : XLabel) -> @geom.Rect {
  let llx = label.pos.x.round()
  let lly = label.pos.y.round()
  let urx = (label.pos.x + label.width).round()
  let ury = (label.pos.y + label.height).round()
  { llx, lly, urx, ury }
}

fn label_encloses_point(label : XLabel, point_obj : XObject) -> Bool {
  let px = point_obj.pos.x
  let py = point_obj.pos.y
  px > label.pos.x &&
    px < label.pos.x + label.width &&
    py > label.pos.y &&
    py < label.pos.y + label.height
}

fn get_intrsx_index(
  op : XObject,
  cp : XObject,
  labels : Array[XLabel],
) -> Int {
  let op_set = match op.label_index {
    Some(idx) => labels[idx].set
    None => false
  }
  let cp_set = match cp.label_index {
    Some(idx) => labels[idx].set
    None => false
  }
  if !op_set || !cp_set {
    return -1
  }
  if (op.pos.x == 0.0 && op.pos.y == 0.0) ||
    (cp.pos.x == 0.0 && cp.pos.y == 0.0) {
    return -1
  }
  if cp.pos.y < op.pos.y {
    if cp.pos.x < op.pos.x {
      return XLPXPY
    }
    if cp.pos.x > op.pos.x {
      return XLNXPY
    }
    return XLCXPY
  }
  if cp.pos.y > op.pos.y {
    if cp.pos.x < op.pos.x {
      return XLPXNY
    }
    if cp.pos.x > op.pos.x {
      return XLNXNY
    }
    return XLCXNY
  }
  if cp.pos.x < op.pos.x {
    return XLPXCY
  }
  if cp.pos.x > op.pos.x {
    return XLNXCY
  }
  -1
}

fn record_intersection_slot(
  objs : Array[XObject],
  labels : Array[XLabel],
  op_idx : Int,
  cp_idx : Int,
  rect : @geom.Rect,
  area : Double,
  intrsx : Array[Int?],
) -> Double {
  let op = objs[op_idx]
  let cp = objs[cp_idx]
  let mut idx = get_intrsx_index(op, cp, labels)
  if idx < 0 {
    // Graphviz parity: default to XLNXCY when get_intrsx_index returns -1.
    idx = XLNXCY
  }
  match intrsx[idx] {
    Some(existing_idx) => {
      let mut max_area = 0.0
      let srect = rect_from_object(objs[existing_idx])
      let sa = rect_overlap_area(rect, srect)
      if sa > area {
        max_area = sa
      }
      match objs[existing_idx].label_index {
        Some(label_idx) => {
          let existing_label = labels[label_idx]
          let srect = rect_from_label(existing_label)
          let sa = rect_overlap_area(rect, srect)
          if sa > area && sa > max_area {
            max_area = sa
          }
        }
        None => ()
      }
      if max_area > 0.0 {
        return max_area
      }
      intrsx[idx] = Some(cp_idx)
      area
    }
    None => {
      intrsx[idx] = Some(cp_idx)
      area
    }
  }
}

fn xlintersections(
  objs : Array[XObject],
  labels : Array[XLabel],
  obj_idx : Int,
  intrsx : Array[Int?],
) -> XBestPos {
  let obj = objs[obj_idx]
  let label_idx = match obj.label_index {
    Some(value) => value
    None => return { n: 0, area: 0.0, pos: @edge_spline.point(0.0, 0.0) }
  }
  let label = labels[label_idx]
  let mut count = 0
  let mut area = 0.0
  for i in 0..<objs.length() {
    if i == obj_idx {
      continue
    }
    let other = objs[i]
    if other.width > 0.0 && other.height > 0.0 {
      continue
    }
    if label_encloses_point(label, other) {
      count = count + 1
    }
  }
  let rect = rect_from_label(label)
  for i in 0..<objs.length() {
    if i == obj_idx {
      continue
    }
    let other = objs[i]
    let srect = rect_from_object(other)
    let overlap = rect_overlap_area(rect, srect)
    if overlap > 0.0 {
      let ra =
        record_intersection_slot(objs, labels, obj_idx, i, rect, overlap, intrsx)
      count = count + 1
      area = area + ra
    }
    match other.label_index {
      Some(other_label_idx) => {
        let other_label = labels[other_label_idx]
        if other_label.set {
          let srect = rect_from_label(other_label)
          let overlap = rect_overlap_area(rect, srect)
          if overlap > 0.0 {
            let ra =
              record_intersection_slot(
                objs,
                labels,
                obj_idx,
                i,
                rect,
                overlap,
                intrsx,
              )
            count = count + 1
            area = area + ra
          }
        }
      }
      None => ()
    }
  }
  { n: count, area, pos: label.pos }
}

fn xladjust(
  objs : Array[XObject],
  labels : Array[XLabel],
  obj_idx : Int,
) -> XBestPos {
  let obj = objs[obj_idx]
  let label_idx = match obj.label_index {
    Some(value) => value
    None => return { n: 0, area: 0.0, pos: @edge_spline.point(0.0, 0.0) }
  }
  let label = labels[label_idx]
  let xincr = (2.0 * label.width + obj.width) / XLXDENOM
  let yincr = (2.0 * label.height + obj.height) / XLYDENOM
  let intrsx : Array[Int?] = []
  for _ in 0..<9 {
    intrsx.push(None)
  }
  let set_label = (pos : @geom.Point) => {
    let updated = {
      target: label.target,
      width: label.width,
      height: label.height,
      pos,
      set: label.set,
    }
    labels[label_idx] = updated
  }
  // x left
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y + obj.height))
  let mut best = xlintersections(objs, labels, obj_idx, intrsx)
  if best.n == 0 {
    return best
  }
  // mid
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y))
  let mut candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x - label.width, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // x mid
  set_label(@edge_spline.point(obj.pos.x, obj.pos.y + obj.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // x right
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y + obj.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // mid
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }
  // bottom
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y - label.height))
  candidate = xlintersections(objs, labels, obj_idx, intrsx)
  if candidate.n == 0 {
    return candidate
  }
  if candidate.area < best.area {
    best = candidate
  }

  // sliding from top left
  if intrsx[XLPXNY] is Some(_) ||
    intrsx[XLCXNY] is Some(_) ||
    intrsx[XLNXNY] is Some(_) ||
    intrsx[XLPXCY] is Some(_) ||
    intrsx[XLPXPY] is Some(_) {
    if intrsx[XLCXNY] is None && intrsx[XLNXNY] is None {
      let mut x = obj.pos.x - label.width
      while x <= obj.pos.x + obj.width {
        set_label(@edge_spline.point(x, obj.pos.y + obj.height))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        x = x + xincr
      }
    }
    if intrsx[XLPXCY] is None && intrsx[XLPXPY] is None {
      let mut y = obj.pos.y + obj.height
      while y >= obj.pos.y - label.height {
        set_label(@edge_spline.point(obj.pos.x - label.width, y))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        y = y - yincr
      }
    }
  }

  // sliding from bottom right
  set_label(@edge_spline.point(obj.pos.x + obj.width, obj.pos.y - label.height))
  if intrsx[XLNXPY] is Some(_) ||
    intrsx[XLCXPY] is Some(_) ||
    intrsx[XLPXPY] is Some(_) ||
    intrsx[XLNXCY] is Some(_) ||
    intrsx[XLNXNY] is Some(_) {
    if intrsx[XLCXPY] is None && intrsx[XLPXPY] is None {
      let mut x = obj.pos.x + obj.width
      while x >= obj.pos.x - label.width {
        set_label(@edge_spline.point(x, obj.pos.y - label.height))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        x = x - xincr
      }
    }
    if intrsx[XLNXCY] is None && intrsx[XLNXNY] is None {
      let mut y = obj.pos.y - label.height
      while y <= obj.pos.y + obj.height {
        set_label(@edge_spline.point(obj.pos.x + obj.width, y))
        candidate = xlintersections(objs, labels, obj_idx, intrsx)
        if candidate.n == 0 {
          return candidate
        }
        if candidate.area < best.area {
          best = candidate
        }
        y = y + yincr
      }
    }
  }
  best
}

fn place_labels(
  objs : Array[XObject],
  labels : Array[XLabel],
  force : Bool,
) -> Unit {
  for i in 0..<objs.length() {
    let obj = objs[i]
    let label_idx = match obj.label_index {
      Some(value) => value
      None => continue
    }
    let best = xladjust(objs, labels, i)
    if best.n == 0 {
      let label = labels[label_idx]
      labels[label_idx] = {
        target: label.target,
        width: label.width,
        height: label.height,
        pos: label.pos,
        set: true,
      }
    } else if best.area == 0.0 || force {
      let label = labels[label_idx]
      labels[label_idx] = {
        target: label.target,
        width: label.width,
        height: label.height,
        pos: best.pos,
        set: true,
      }
    }
  }
}
