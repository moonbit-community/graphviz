// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
async fn main {
  let args = @env.args()
  if args.length() == 0 {
    return ()
  }
  let program = args[0]
  let cli_args : Array[String] = []
  for i in 1..<args.length() {
    cli_args.push(args[i])
  }
  let output = @cli.run_cli_bytes(cli_args, program~) catch {
    err => fail("cli error: \{err}")
  }
  if output.length() > 0 {
    @stdio.stdout.write(output) catch {
      err => fail("cli error: \{err}")
    }
  }
}
