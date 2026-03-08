///|
/// Remaining Mincross fixture tests are retirement meta-checks only.
/// Shared parser/case-runner support now lives in `mincross_test_support_wbtest`.

fn mincross_case_has_distinct_output(
  input : MincrossInput,
  output : MincrossOutput,
) -> Bool {
  input.ranks != output.ranks
}

///|
/// Graphviz parity: owner-local direct tests now cover a small subset of
/// exact integrated reorder fixtures whose signal is maintainable outside the
/// fixture harness, including the compact edge_vnode_spacing ladder, the L0
/// wide normal tree, two maintainable yours_truly slices (one clustered
/// skeleton slice and one stable named multi-cluster startpass=2 slice), and
/// the dense non-clustered abstract reorder slice.
fn mincross_case_has_owner_local_integrated_coverage(
  input : MincrossInput,
) -> Bool {
  if input.case_id == 1 && input.graph == "edge_vnode_spacing" {
    return true
  }
  if input.case_id == 1 &&
    input.graph == "L0" &&
    input.startpass == 0 &&
    input.nodes.length() == 43 &&
    input.edges.length() == 42 {
    return true
  }
  if input.case_id == 1 &&
    input.graph == "yours_truly" &&
    input.startpass == 0 &&
    input.nodes.length() == 30 &&
    input.edges.length() == 32 {
    return true
  }
  if input.case_id == 15 &&
    input.graph == "yours_truly" &&
    input.startpass == 2 &&
    input.nodes.length() == 44 &&
    input.edges.length() == 44 {
    return true
  }
  if input.case_id == 1 &&
    input.graph == "abstract" &&
    input.startpass == 0 &&
    input.nodes.length() == 91 &&
    input.edges.length() == 112 {
    return true
  }
  false
}

///|
/// Graphviz parity: keep fixture replay for cases that still carry distinct
/// reorder signal, plus a small set of unchanged integrated graphs that still
/// add signal beyond the owner-local direct coverage above. The compact
/// edge_vnode_spacing ladder, the stable wide normal tree behind L0, the
/// small clustered skeleton yours_truly slice, the stable named multi-cluster
/// yours_truly startpass=2 slice, and the dense abstract layered case are now
/// covered directly in rank_reorder_wbtest.
fn mincross_case_needs_integrated_replay(
  input : MincrossInput,
  output : MincrossOutput,
) -> Bool {
  if mincross_case_has_owner_local_integrated_coverage(input) {
    return false
  }
  if mincross_case_has_distinct_output(input, output) {
    return true
  }
  match input.graph {
    "yours_truly" => input.startpass > 0
    _ => false
  }
}

///|
/// Graphviz parity: direct rank_reorder tests now cover every plugin case
/// with distinct reorder output, from the compact cluster_gd and cluster_core
/// slices up through the dense integrated `G case=11 startpass=2` graph. Keep
/// the mapping explicit so this meta-test can confirm plugin fixture replay is
/// fully retired.
fn mincross_plugin_case_has_owner_local_coverage(input : MincrossInput) -> Bool {
  if input.case_id == 10 && input.graph == "cluster_gd" {
    return true
  }
  if input.case_id == 4 && input.graph == "cluster_core" {
    return true
  }
  input.case_id == 11 && input.graph == "G" && input.startpass == 2
}

///|
test "mincross integrated fixture replay is fully retired" {
  let fixtures = load_mincross_fixtures()
  let mut matched = 0
  for pair in fixtures.cases {
    let (input, output) = pair
    if !mincross_case_needs_integrated_replay(input, output) {
      continue
    }
    matched = matched + 1
    run_mincross_case_with_name_order(input, output, fixtures.name_order)
  }
  assert_eq(matched, 0)
}

///|
test "mincross plugin fixture replay is fully retired" {
  let fixtures = load_mincross_fixtures_from(
    "tests/fixtures/graphviz/mincross.plugins.jsonl",
  )
  let mut matched = 0
  for pair in fixtures.cases {
    let (input, output) = pair
    if !mincross_case_has_distinct_output(input, output) {
      continue
    }
    if mincross_plugin_case_has_owner_local_coverage(input) {
      continue
    }
    matched = matched + 1
  }
  assert_eq(matched, 0)
}
