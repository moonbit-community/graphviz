///|
fn fixture_require_object(json : Json) -> Map[String, Json] raise {
  match json {
    Json::Object(obj) => obj
    _ => fail("expected JSON object")
  }
}

///|
fn require_object_local(json : Json) -> Map[String, Json] raise {
  fixture_require_object(json)
}

///|
fn fixture_json_int_option(value : Json) -> Int? raise {
  if value == Json::null() {
    None
  } else {
    Some(@json.from_json(value))
  }
}

///|
fn fixture_json_string_option(value : Json) -> String? raise {
  if value == Json::null() {
    None
  } else {
    Some(@json.from_json(value))
  }
}

///|
fn fixture_build_rank_order_map(ranks : Array[Array[Int]]) -> Map[Int, Int] raise {
  let map : Map[Int, Int] = Map::new()
  let mut rank_idx = 0
  for rank_nodes in ranks {
    let mut order = 0
    for id in rank_nodes {
      if map.get(id) is Some(_) {
        fail("duplicate node id \{id} in rank list \{rank_idx}")
      }
      map[id] = order
      order = order + 1
    }
    rank_idx = rank_idx + 1
  }
  map
}
