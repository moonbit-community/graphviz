///|
test "plugins root/remincross mincross inputs match graphviz fixtures" {
  let fixture_path = "tests/fixtures/graphviz/mincross.plugins.jsonl"
  let root_expected = find_mincross_input_case(fixture_path, 1)
  let remincross_expected = find_mincross_input_case(fixture_path, 11)

  root_mincross_input_snapshot.val = None
  remincross_input_snapshot.val = None

  @sys.set_env_var("DOT_CAPTURE_ORDERING_INPUTS", "1")
  @sys.set_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE", "1")
  let graph = @dot_parser.parse_dot_file("refs/graphviz/doc/infosrc/plugins.gv")
  let prep = match @input_stage.prepare_layout_prep(
    graph,
    { rankdir: None, nodesep: None, ranksep: None, splines: None },
  ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  ignore(@rank_stage.compute_dot_rank_stage({ graph, prep }))
  @sys.unset_env_var("DOT_CAPTURE_ORDERING_INPUTS")
  @sys.unset_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE")

  let root_actual = match root_mincross_input_snapshot.val {
    Some(value) => value
    None => fail("missing captured root mincross input snapshot")
  }
  let remincross_actual = match remincross_input_snapshot.val {
    Some(value) => value
    None => fail("missing captured remincross input snapshot")
  }

  assert_canonical_ordering_input_eq(
    "plugins root mincross input",
    canonical_root_snapshot_input(root_actual),
    canonical_fixture_ordering_input(root_expected),
  )
  assert_canonical_ordering_input_eq(
    "plugins remincross input",
    canonical_remincross_snapshot_input(remincross_actual),
    canonical_fixture_ordering_input(remincross_expected),
  )

  root_mincross_input_snapshot.val = None
  remincross_input_snapshot.val = None
}
