///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() == 0 {
    return ()
  }
  let program = args[0]
  let cli_args : Array[String] = []
  for i in 1..<args.length() {
    cli_args.push(args[i])
  }
  let output = try @cli.run_cli(cli_args, program=program) catch {
    err => {
      println("cli error: \{err}")
      @sys.exit(1)
      ""
    }
  }
  if output != "" {
    println(output)
  }
}
