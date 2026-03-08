///|
/// Graphviz-facing rank fixture retirement checks. Shared parser/case
/// support now lives in `rank_fixture_support_wbtest`.

///|
test "rank fixture final replay is fully retired" {
  let cases = load_rank_fixtures()
  let mut matched = 0
  for case_info in cases {
    if !simplex_case_has_distinct_final_output(case_info) {
      continue
    }
    matched = matched + 1
    run_simplex_case(case_info.input, case_info.output)
  }
  assert_eq(matched, 0)
}

///|
test "rank fixture feasible_tree replay is fully retired" {
  let cases = load_rank_fixtures()
  let mut matched = 0
  for case_info in cases {
    if !simplex_case_needs_integrated_replay(case_info) {
      continue
    }
    matched = matched + 1
    run_feasible_tree_case(case_info)
  }
  assert_eq(matched, 0)
}

///|
test "rank fixture pre_balance replay is fully retired" {
  let cases = load_rank_fixtures()
  let mut matched = 0
  for case_info in cases {
    if !simplex_case_needs_integrated_replay(case_info) {
      continue
    }
    matched = matched + 1
    run_pre_balance_case(case_info)
  }
  assert_eq(matched, 0)
}
