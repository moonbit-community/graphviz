///|
/// Graphviz-facing xpos constraint fixture checks. Shared parser/capture
/// support now lives in `xpos_fixture_support_wbtest`.

///|
test "xpos constraint fixture is well formed for complex" {
  let fixture = load_complex_xpos_fixture()
  assert_xpos_constraint_fixture_is_well_formed(fixture)
}

///|
test "xpos constraint captured case matches Graphviz for complex" {
  let case = load_complex_xpos_constraint_case()
  assert_xpos_constraint_fixture_is_well_formed(case.fixture)
  assert_xpos_constraint_multisets_match(case)
  assert_xpos_constraint_named_nodes_match(case)
}
