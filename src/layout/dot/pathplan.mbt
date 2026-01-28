///|
const CCW_ISCCW : Int = 1
const CCW_ISCW : Int = 2
const CCW_ISON : Int = 3

///|
priv struct PathNode {
  point : @geom.Point
  mut link : Int?
}

///|
priv struct TriEdge {
  a : Int
  b : Int
  mut right : Int?
}

///|
priv struct PathTriangle {
  mut mark : Int
  edges : Array[TriEdge]
}

///|
priv struct Deque {
  pnlps : Array[Int]
  mut fp : Int
  mut lp : Int
  mut apex : Int
}

///|
fn ccw(p1 : @geom.Point, p2 : @geom.Point, p3 : @geom.Point) -> Int {
  let d = (p1.y - p2.y) * (p3.x - p2.x) - (p3.y - p2.y) * (p1.x - p2.x)
  if d > 0.0 {
    CCW_ISCW
  } else if d < 0.0 {
    CCW_ISCCW
  } else {
    CCW_ISON
  }
}

///|
fn between(pa : @geom.Point, pb : @geom.Point, pc : @geom.Point) -> Bool {
  if ccw(pa, pb, pc) != CCW_ISON {
    return false
  }
  let pba_x = pb.x - pa.x
  let pba_y = pb.y - pa.y
  let pca_x = pc.x - pa.x
  let pca_y = pc.y - pa.y
  pca_x * pba_x + pca_y * pba_y >= 0.0 &&
  pca_x * pca_x + pca_y * pca_y <= pba_x * pba_x + pba_y * pba_y
}

///|
fn intersects(
  pa : @geom.Point,
  pb : @geom.Point,
  pc : @geom.Point,
  pd : @geom.Point,
) -> Bool {
  let ccw1 = ccw(pa, pb, pc)
  let ccw2 = ccw(pa, pb, pd)
  let ccw3 = ccw(pc, pd, pa)
  let ccw4 = ccw(pc, pd, pb)
  if ccw1 == CCW_ISON || ccw2 == CCW_ISON || ccw3 == CCW_ISON || ccw4 == CCW_ISON {
    between(pa, pb, pc) ||
    between(pa, pb, pd) ||
    between(pc, pd, pa) ||
    between(pc, pd, pb)
  } else {
    let v1 = if ccw1 == CCW_ISCCW { 1 } else { 0 }
    let v2 = if ccw2 == CCW_ISCCW { 1 } else { 0 }
    let v3 = if ccw3 == CCW_ISCCW { 1 } else { 0 }
    let v4 = if ccw4 == CCW_ISCCW { 1 } else { 0 }
    (v1 != v2) && (v3 != v4)
  }
}

///|
fn is_diagonal(
  i : Int,
  ip2 : Int,
  points : Array[Int],
  nodes : Array[PathNode],
) -> Bool {
  let pointn = points.length()
  let ip1 = (i + 1) % pointn
  let im1 = (i + pointn - 1) % pointn
  let p_im1 = nodes[points[im1]].point
  let p_i = nodes[points[i]].point
  let p_ip1 = nodes[points[ip1]].point
  let p_ip2 = nodes[points[ip2]].point
  let res =
    if ccw(p_im1, p_i, p_ip1) == CCW_ISCCW {
      ccw(p_i, p_ip2, p_im1) == CCW_ISCCW && ccw(p_ip2, p_i, p_ip1) == CCW_ISCCW
    } else {
      ccw(p_i, p_ip2, p_ip1) == CCW_ISCW
    }
  if !res {
    return false
  }
  for j in 0..<pointn {
    let jp1 = (j + 1) % pointn
    if j == i || jp1 == i || j == ip2 || jp1 == ip2 {
      continue
    }
    let p_j = nodes[points[j]].point
    let p_jp1 = nodes[points[jp1]].point
    if intersects(p_i, p_ip2, p_j, p_jp1) {
      return false
    }
  }
  true
}

///|
fn load_triangle(
  triangles : Array[PathTriangle],
  a : Int,
  b : Int,
  c : Int,
) -> Bool {
  let edges : Array[TriEdge] = [
    { a, b, right: None },
    { a: b, b: c, right: None },
    { a: c, b: a, right: None },
  ]
  triangles.push({ mark: 0, edges })
  true
}

///|
fn triangulate(
  points : Array[Int],
  nodes : Array[PathNode],
  triangles : Array[PathTriangle],
) -> Bool {
  if points.length() > 3 {
    let pointn = points.length()
    for i in 0..<pointn {
      let ip1 = (i + 1) % pointn
      let ip2 = (i + 2) % pointn
      if is_diagonal(i, ip2, points, nodes) {
        if !load_triangle(triangles, points[i], points[ip1], points[ip2]) {
          return false
        }
        let mut idx = ip1
        while idx + 1 < points.length() {
          points[idx] = points[idx + 1]
          idx = idx + 1
        }
        let _ = points.pop()
        return triangulate(points, nodes, triangles)
      }
    }
    return false
  } else {
    if points.length() == 3 {
      return load_triangle(triangles, points[0], points[1], points[2])
    }
    false
  }
}

///|
fn connect_triangles(triangles : Array[PathTriangle]) -> Unit {
  for i in 0..<triangles.length() {
    for j in (i + 1)..<triangles.length() {
      let tri_i = triangles[i]
      let tri_j = triangles[j]
      for ei in 0..<3 {
        for ej in 0..<3 {
          let edge_i = tri_i.edges[ei]
          let edge_j = tri_j.edges[ej]
          let same_dir = edge_i.a == edge_j.a && edge_i.b == edge_j.b
          let opp_dir = edge_i.a == edge_j.b && edge_i.b == edge_j.a
          if same_dir || opp_dir {
            triangles[i].edges[ei].right = Some(j)
            triangles[j].edges[ej].right = Some(i)
          }
        }
      }
    }
  }
}

///|
fn point_in_tri(
  tri : PathTriangle,
  nodes : Array[PathNode],
  point : @geom.Point,
) -> Bool {
  let mut sum = 0
  for edge in tri.edges {
    let a = nodes[edge.a].point
    let b = nodes[edge.b].point
    if ccw(a, b, point) != CCW_ISCW {
      sum = sum + 1
    }
  }
  sum == 3 || sum == 0
}

///|
fn mark_tri_path(
  triangles : Array[PathTriangle],
  trii : Int,
  trij : Int,
) -> Bool {
  if triangles[trii].mark != 0 {
    return false
  }
  triangles[trii].mark = 1
  if trii == trij {
    return true
  }
  for edge in triangles[trii].edges {
    match edge.right {
      Some(next) =>
        if mark_tri_path(triangles, next, trij) {
        return true
      }
      None => ()
    }
  }
  triangles[trii].mark = 0
  false
}

///|
fn add_to_deque(
  dq : Deque,
  side_front : Bool,
  node_idx : Int,
  nodes : Array[PathNode],
) -> Unit {
  if side_front {
    if dq.lp >= dq.fp {
      nodes[node_idx].link = Some(dq.pnlps[dq.fp])
    }
    dq.fp = dq.fp - 1
    dq.pnlps[dq.fp] = node_idx
  } else {
    if dq.lp >= dq.fp {
      nodes[node_idx].link = Some(dq.pnlps[dq.lp])
    }
    dq.lp = dq.lp + 1
    dq.pnlps[dq.lp] = node_idx
  }
}

///|
fn split_deque(dq : Deque, side_front : Bool, index : Int) -> Unit {
  if side_front {
    dq.lp = index
  } else {
    dq.fp = index
  }
}

///|
fn find_deque_split(
  dq : Deque,
  nodes : Array[PathNode],
  node_idx : Int,
) -> Int {
  let point = nodes[node_idx].point
  let mut idx = dq.fp
  while idx < dq.apex {
    let next = nodes[dq.pnlps[idx + 1]].point
    let current = nodes[dq.pnlps[idx]].point
    if ccw(next, current, point) == CCW_ISCCW {
      return idx
    }
    idx = idx + 1
  }
  idx = dq.lp
  while idx > dq.apex {
    let prev = nodes[dq.pnlps[idx - 1]].point
    let current = nodes[dq.pnlps[idx]].point
    if ccw(prev, current, point) == CCW_ISCW {
      return idx
    }
    idx = idx - 1
  }
  dq.apex
}

///|
fn prepare_polygon_nodes(points : Array[@geom.Point]) -> Array[PathNode] {
  let nodes : Array[PathNode] = []
  for point in points {
    nodes.push({ point, link: None })
  }
  nodes
}

///|
fn normalize_polygon_order(points : Array[@geom.Point]) -> Array[@geom.Point] {
  if points.length() < 3 {
    return points
  }
  let mut min_x = 0.0
  let mut min_idx = 0
  let mut seen = false
  for i in 0..<points.length() {
    let p = points[i]
    if !seen || p.x < min_x {
      min_x = p.x
      min_idx = i
      seen = true
    }
  }
  let p2 = points[min_idx]
  let p1 = points[(min_idx + points.length() - 1) % points.length()]
  let p3 = points[(min_idx + 1) % points.length()]
  let needs_reverse =
    (p1.x == p2.x && p2.x == p3.x && p3.y > p2.y) || ccw(p1, p2, p3) != CCW_ISCCW
  if !needs_reverse {
    let deduped : Array[@geom.Point] = []
    let mut idx = 0
    while idx < points.length() {
      if idx > 0 {
        let prev = points[idx - 1]
        let cur = points[idx]
        if cur.x == prev.x && cur.y == prev.y {
          idx = idx + 1
          continue
        }
      }
      deduped.push(points[idx])
      idx = idx + 1
    }
    return deduped
  }
  let reversed : Array[@geom.Point] = []
  let mut idx = points.length()
  while idx > 0 {
    idx = idx - 1
    if idx + 1 < points.length() {
      let prev = points[idx + 1]
      let cur = points[idx]
      if cur.x == prev.x && cur.y == prev.y {
        continue
      }
    }
    reversed.push(points[idx])
  }
  reversed
}

///|
fn path_nodes_to_points(
  nodes : Array[PathNode],
  start_idx : Int,
) -> Array[@geom.Point] {
  let out : Array[@geom.Point] = []
  let mut current = start_idx
  while true {
    out.push(nodes[current].point)
    match nodes[current].link {
      Some(next) => current = next
      None => break
    }
  }
  let reversed : Array[@geom.Point] = []
  let mut idx = out.length()
  while idx > 0 {
    idx = idx - 1
    reversed.push(out[idx])
  }
  reversed
}

///|
fn shortest_path_in_poly(
  poly_points : Array[@geom.Point],
  start : @geom.Point,
  end : @geom.Point,
) -> Array[@geom.Point] {
  if poly_points.length() < 3 {
    return [start, end]
  }
  let normalized = normalize_polygon_order(poly_points)
  let nodes = prepare_polygon_nodes(normalized)
  let start_idx = nodes.length()
  nodes.push({ point: start, link: None })
  let end_idx = nodes.length()
  nodes.push({ point: end, link: None })
  let point_indices : Array[Int] = []
  for i in 0..<normalized.length() {
    point_indices.push(i)
  }
  let triangles : Array[PathTriangle] = []
  if !triangulate(point_indices, nodes, triangles) {
    return [start, end]
  }
  connect_triangles(triangles)
  let mut start_tri = -1
  let mut end_tri = -1
  for i in 0..<triangles.length() {
    if start_tri == -1 && point_in_tri(triangles[i], nodes, start) {
      start_tri = i
    }
    if end_tri == -1 && point_in_tri(triangles[i], nodes, end) {
      end_tri = i
    }
  }
  if start_tri == -1 || end_tri == -1 {
    return [start, end]
  }
  if start_tri == end_tri {
    return [start, end]
  }
  if !mark_tri_path(triangles, start_tri, end_tri) {
    return [start, end]
  }
  let dq_size = normalized.length() * 2 + 4
  let dq = Deque::{ pnlps: Array::make(dq_size, 0), fp: dq_size / 2, lp: dq_size / 2 - 1, apex: 0 }
  add_to_deque(dq, true, start_idx, nodes)
  dq.apex = dq.fp
  let mut trii = start_tri
  while trii != -1 {
    triangles[trii].mark = 2
    let mut exit_edge_idx = -1
    for ei in 0..<3 {
      match triangles[trii].edges[ei].right {
        Some(next) =>
          if triangles[next].mark == 1 {
            exit_edge_idx = ei
            break
          }
        None => ()
      }
    }
    let mut lp = end_idx
    let mut rp = end_idx
    if exit_edge_idx == -1 {
      let front = nodes[dq.pnlps[dq.fp]].point
      let back = nodes[dq.pnlps[dq.lp]].point
      if ccw(end, front, back) == CCW_ISCCW {
        lp = dq.pnlps[dq.lp]
        rp = end_idx
      } else {
        lp = end_idx
        rp = dq.pnlps[dq.lp]
      }
    } else {
      let edge = triangles[trii].edges[exit_edge_idx]
      let next_edge = triangles[trii].edges[(exit_edge_idx + 1) % 3]
      let pivot = nodes[next_edge.b].point
      let a = nodes[edge.a].point
      let b = nodes[edge.b].point
      if ccw(a, pivot, b) == CCW_ISCCW {
        lp = edge.b
        rp = edge.a
      } else {
        lp = edge.a
        rp = edge.b
      }
    }
    if trii == start_tri {
      add_to_deque(dq, false, lp, nodes)
      add_to_deque(dq, true, rp, nodes)
    } else {
      let front_idx = dq.pnlps[dq.fp]
      let back_idx = dq.pnlps[dq.lp]
      if front_idx != rp && back_idx != rp {
        let split_idx = find_deque_split(dq, nodes, rp)
        split_deque(dq, false, split_idx)
        add_to_deque(dq, true, rp, nodes)
        if split_idx > dq.apex {
          dq.apex = split_idx
        }
      } else {
        let split_idx = find_deque_split(dq, nodes, lp)
        split_deque(dq, true, split_idx)
        add_to_deque(dq, false, lp, nodes)
        if split_idx < dq.apex {
          dq.apex = split_idx
        }
      }
    }
    let mut next_tri = -1
    for edge in triangles[trii].edges {
      match edge.right {
        Some(next) =>
          if triangles[next].mark == 1 {
            next_tri = next
            break
          }
        None => ()
      }
    }
    trii = next_tri
  }
  path_nodes_to_points(nodes, end_idx)
}
