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
    let (width, height) =
      label_text_dimensions(fixture.text, fixture.font, fixture.size)
    let _ = fixture.flags
    let _ = fixture.yoffset_layout
    let _ = fixture.yoffset_centerline
    assert_eq(width, fixture.width)
    assert_eq(height, fixture.height)
  }
}
