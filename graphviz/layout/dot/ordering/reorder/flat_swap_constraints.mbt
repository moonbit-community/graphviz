///|
// mincross.c left2right swaps the matrix indices under GD_flip. The
// topological flat graph itself retains its original direction.
fn flat_swap_constraints(
  constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[String, Bool] {
  guard graphviz_flip else { return constraints }
  let reversed : Map[String, Bool] = Map([])
  for key, enabled in constraints {
    guard enabled else { continue }
    guard @rank_constraints.parse_flat_constraint_key(key) is Some((tail, head)) else {
      continue
    }
    reversed["\{head}|\{tail}"] = true
  }
  reversed
}
