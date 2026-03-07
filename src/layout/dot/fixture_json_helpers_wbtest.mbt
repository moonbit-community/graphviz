///|
fn require_object_local(json : Json) -> Map[String, Json] raise {
  match json {
    Json::Object(obj) => obj
    _ => fail("expected JSON object")
  }
}
