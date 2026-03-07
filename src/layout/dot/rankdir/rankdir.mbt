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
