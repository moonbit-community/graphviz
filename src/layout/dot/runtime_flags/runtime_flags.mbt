// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
pub fn env_flag_enabled(value : String?, default_enabled : Bool) -> Bool {
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
