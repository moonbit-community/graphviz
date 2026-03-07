///|
/// Rank direction for dot layout.
pub(all) enum RankDir {
  TB
  BT
  LR
  RL
} derive(Show, Eq)

///|
pub fn parse_rankdir(value : String) -> RankDir? {
  match value.to_lower() {
    "tb" => Some(RankDir::TB)
    "bt" => Some(RankDir::BT)
    "lr" => Some(RankDir::LR)
    "rl" => Some(RankDir::RL)
    _ => None
  }
}

///|
pub fn graph_rankdir(graph : @cgraph.Graph) -> RankDir {
  let mut current = graph
  while true {
    match current.get_attr("rankdir") {
      Some(value) =>
        match parse_rankdir(value) {
          Some(parsed) => return parsed
          None => ()
        }
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  RankDir::TB
}


///|
pub const CL_BACK : Int = 10

///|
pub fn env_flag_enabled(
  value : String?,
  default_enabled : Bool,
) -> Bool {
  match value {
    Some(raw) => {
      let lower = raw.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => default_enabled
  }
}

///|
pub fn env_flag_enabled_nonempty(value : String?) -> Bool {
  match value {
    Some(raw) => {
      let lower = raw.to_lower()
      lower != "" && lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}



