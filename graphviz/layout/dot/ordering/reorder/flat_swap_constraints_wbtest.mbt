///|
test "flipped flat swap constraints preserve the topological graph" {
  let constraints : Map[String, Bool] = { "a|b": true, "b|c": true }
  let horizontal = flat_swap_constraints(constraints, true)
  @test.assert_eq(horizontal.get("b|a"), Some(true))
  @test.assert_eq(horizontal.get("c|b"), Some(true))
  @test.assert_eq(horizontal.get("a|b"), None)
  @test.assert_eq(constraints.get("a|b"), Some(true))
  @test.assert_eq(constraints.get("b|a"), None)
  @test.assert_eq(flat_swap_constraints(constraints, false), constraints)
}
