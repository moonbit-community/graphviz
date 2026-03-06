///|
struct TextspanFixture {
  font : String
  size : Double
  flags : Int
  text : String
  width : Double
  height : Double
  yoffset_layout : Double
  yoffset_centerline : Double
} derive(FromJson)

///|
fn load_textspan_fixtures() -> Array[TextspanFixture] raise {
  let data = @fs.read_file_to_string("tests/fixtures/graphviz/textspan.jsonl")
  let fixtures : Array[TextspanFixture] = []
  for line in data.split("\n") {
    if line.length() == 0 {
      continue
    }
    let json = @json.parse(line)
    let fixture : TextspanFixture = @json.from_json(json)
    fixtures.push(fixture)
  }
  fixtures
}

///|
test "textspan fixtures match label_text_dimensions" {
  let fixtures = load_textspan_fixtures()
  for fixture in fixtures {
    let (width, height, yoffset_layout, yoffset_centerline) =
      @label_metrics.label_text_metrics(fixture.text, fixture.font, fixture.size)
    assert_eq(fixture.flags, 0)
    assert_eq(width, fixture.width)
    assert_eq(height, fixture.height)
    assert_eq(yoffset_layout, fixture.yoffset_layout)
    assert_eq(yoffset_centerline, fixture.yoffset_centerline)
  }
}

///|
test "textspan combines multiline overrides" {
  let (width, height) =
    @label_metrics.label_text_dimensions("Edge Label A\\nEdge Label B Longer", "Times-Roman", 14.0)
  assert_eq(width, 117.75)
  assert_eq(height, 33.0)
}
