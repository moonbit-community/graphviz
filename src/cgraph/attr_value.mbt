///|
/// DOT attribute syntax is independent of its text. HTML values retain their
/// outer delimiters, matching the existing string attribute API.
pub(all) enum AttrValue {
  Text(String)
  Html(String)
} derive(Eq, Debug)

///|
/// Returns the attribute spelling without losing the stored syntax.
pub fn AttrValue::text(self : AttrValue) -> String {
  match self {
    Text(value) | Html(value) => value
  }
}
