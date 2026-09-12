///|
test "plain label blank lines use integer truncated line spacing" {
  let (lines, _, height) = label_metrics("first\\n\\nlast", "Arial", 9.0)
  @test.assert_eq(lines.length(), 3)
  @test.assert_eq(lines[1].width_pt, 0.0)
  @test.assert_eq(lines[1].height_pt, 10.0)
  @test.assert_eq(height, lines[0].height_pt + 10.0 + lines[2].height_pt)
}
