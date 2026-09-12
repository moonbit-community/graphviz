///|
test "node href follows height while uppercase URL precedes geometry" {
  let sorted = sort_attrs([
    ("label", "node"),
    ("href", "link"),
    ("URL", "link"),
    ("height", "1"),
  ])
  assert_true(sorted[0].0 == "URL")
  assert_true(sorted[1].0 == "height")
  assert_true(sorted[2].0 == "href")
  assert_true(sorted[3].0 == "label")
}
