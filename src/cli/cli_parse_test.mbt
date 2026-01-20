///|
test "parse cli args uses stdin when input missing" {
  let action = parse_cli_args(["-Tdot"])
  guard action is CliAction::Render(job) else {
    fail("expected render action")
  }
  assert_eq(job.input, None)
}

///|
test "parse cli args uses stdin for dash input" {
  let action = parse_cli_args(["-Tdot", "-"])
  guard action is CliAction::Render(job) else {
    fail("expected render action")
  }
  assert_eq(job.input, Some("-"))
}
