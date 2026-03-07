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
