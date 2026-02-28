///|
/// Stage C Phase C0 split: shared ordering base-context
/// and position-name helpers for dispatch setup.

///|
/// Graphviz parity: existing-name map is seeded from declared nodes before
/// vnode synthesis and flat-label augmentation overlays.
/// Do not change behavior without updating fixtures/tests.
fn build_existing_node_names_map_for_positions(
  nodes : Array[@cgraph.Node],
) -> Map[String, Bool] {
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  existing_names
}
