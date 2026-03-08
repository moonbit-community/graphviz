///|
test "plugins root/remincross mincross inputs match graphviz fixtures" {
  let fixture_path = "tests/fixtures/graphviz/mincross.plugins.jsonl"
  let fixture_cases = load_mincross_fixtures_from(fixture_path)
  let mut root_expected : MincrossInput? = None
  let mut remincross_expected : MincrossInput? = None
  for pair in fixture_cases {
    let (input, _output) = pair
    if input.case_id == 1 {
      root_expected = Some(input)
    }
    if input.case_id == 11 {
      remincross_expected = Some(input)
    }
  }

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

  let root_expected_input = match root_expected {
    Some(value) => value
    None => fail("missing mincross fixture case 1 in \{fixture_path}")
  }
  let remincross_expected_input = match remincross_expected {
    Some(value) => value
    None => fail("missing mincross fixture case 11 in \{fixture_path}")
  }

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
    canonical_fixture_ordering_input(root_expected_input),
  )
  assert_canonical_ordering_input_eq(
    "plugins remincross input",
    canonical_remincross_snapshot_input(remincross_actual),
    canonical_fixture_ordering_input(remincross_expected_input),
  )

  root_mincross_input_snapshot.val = None
  remincross_input_snapshot.val = None
}
