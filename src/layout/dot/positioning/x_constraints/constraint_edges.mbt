///|
/// Graphviz parity: x-constraint edges carry minlen/weight plus optional
/// tail/head port tags used by ordering-sensitive edge-constraint assembly.
pub(all) struct ConstraintEdge {
  tail : String
  head : String
  minlen : Int
  weight : Int
  tail_port : String?
  head_port : String?
}

///|
/// Graphviz parity: duplicated constraint keys keep the max(minlen, weight)
/// just like constraint accumulation in xpos wiring.
fn upsert_constraint_with_max(
  constraints : Map[String, ConstraintEdge],
  key : String,
  tail : String,
  head : String,
  minlen : Int,
  weight : Int,
) -> Unit {
  match constraints.get(key) {
    Some(entry) => {
      constraints[key] = {
        tail: entry.tail,
        head: entry.head,
        minlen: if minlen > entry.minlen { minlen } else { entry.minlen },
        weight: if weight > entry.weight { weight } else { entry.weight },
        tail_port: None,
        head_port: None,
      }
    }
    None => {
      constraints[key] = { tail, head, minlen, weight, tail_port: None, head_port: None }
    }
  }
}

///|
/// Graphviz parity: constraint edges are added only when both endpoints are
/// present in the current simplex index.
pub fn add_constraint_edge_if_present(
  graph : @network_simplex.NsGraph,
  index : Map[String, Int],
  edge : ConstraintEdge,
) -> Unit {
  match index.get(edge.tail) {
    Some(tail_idx) =>
      match index.get(edge.head) {
        Some(head_idx) => {
          let _ = @network_simplex.add_edge(
            graph,
            tail_idx,
            head_idx,
            edge.minlen,
            edge.weight,
          )
        }
        None => ()
      }
    None => ()
  }
}
