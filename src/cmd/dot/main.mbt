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
  let output = @cli.run_cli_bytes(cli_args, program~) catch {
    err => {
      println("cli error: \{err}")
      @sys.exit(1)
      @utf8.encode("", bom=false)
    }
  }
  if output.length() > 0 {
    @fs.write_bytes_to_file("/dev/stdout", output) catch {
      err => {
        println("cli error: \{err}")
        @sys.exit(1)
      }
    }
  }
}
