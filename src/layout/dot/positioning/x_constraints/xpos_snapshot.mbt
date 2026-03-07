///|
type SnapshotNodeSize = @shared.NodeSize

///|
pub(all) struct XposConstraintNodeSnapshot {
  name : String?
  kind : @network_simplex.NodeKind
  rank : Int
  order : Int
  left_pt : Double
  right_pt : Double
  height_pt : Double
}

///|
pub(all) struct XposConstraintEdgeSnapshot {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
pub(all) struct XposConstraintSnapshot {
  nodes : Array[XposConstraintNodeSnapshot]
  edges : Array[XposConstraintEdgeSnapshot]
}

///|
fn touch_constraint_snapshot(snapshot : XposConstraintSnapshot) -> Unit {
  let _ = snapshot.nodes
  let _ = snapshot.edges
  for node in snapshot.nodes {
    let _ = node.name
    let _ = node.kind
    let _ = node.rank
    let _ = node.order
    let _ = node.left_pt
    let _ = node.right_pt
    let _ = node.height_pt
  }
  for edge in snapshot.edges {
    let _ = edge.tail
    let _ = edge.head
    let _ = edge.minlen
    let _ = edge.weight
  }
}

///|
pub let xpos_constraint_snapshot : Ref[XposConstraintSnapshot?] = Ref::new(None)

///|
pub fn should_capture_xpos_snapshot(graph : @cgraph.Graph) -> Bool {
  match @sys.get_env_var("DOT_CAPTURE_XPOS_CONSTRAINTS") {
    None => false
    Some(value) => {
      if value == "" || value == "1" {
        return true
      }
      match graph.name() {
        Some(name) => name == value
        None => false
      }
    }
  }
}

///|
pub fn build_constraint_snapshot(
  graph : @network_simplex.NsGraph,
  index : Map[String, Int],
  sizes : Map[String, SnapshotNodeSize],
  order_index : Map[String, Int],
) -> XposConstraintSnapshot {
  let names : Array[String?] = []
  for _ in 0..<graph.nodes.length() {
    names.push(None)
  }
  for name, idx in index {
    names[idx] = Some(name)
  }
  let nodes : Array[XposConstraintNodeSnapshot] = []
  for i in 0..<graph.nodes.length() {
    let node = graph.nodes[i]
    let name = names[i]
    let mut left_pt = 1.0
    let mut right_pt = 1.0
    let mut height_pt = 1.0
    let mut order = 0
    match name {
      Some(value) =>
        match sizes.get(value) {
          Some(size) => {
            left_pt = size.left_pt
            right_pt = size.right_pt
            height_pt = size.height_pt
          }
          None => ()
        }
      None => ()
    }
    match name {
      Some(value) =>
        match order_index.get(value) {
          Some(value) => order = value
          None => ()
        }
      None => ()
    }
    nodes.push({
      name,
      kind: node.kind,
      rank: node.rank,
      order,
      left_pt,
      right_pt,
      height_pt,
    })
  }
  let edges : Array[XposConstraintEdgeSnapshot] = []
  for edge in graph.edges {
    edges.push({
      tail: edge.tail,
      head: edge.head,
      minlen: edge.minlen,
      weight: edge.weight,
    })
  }
  let snapshot = { nodes, edges }
  touch_constraint_snapshot(snapshot)
  snapshot
}
