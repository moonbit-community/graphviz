///|
fn program_basename(program : String) -> String {
  let mut name = program
  for part in program.split("/") {
    name = part.to_string()
  }
  if name == "" {
    program
  } else {
    name
  }
}

///|
fn cli_trace(message : String) -> Unit {
  if @sys.get_env_var("DOT_TRACE") is Some(_) {
    println(message)
  }
}

///|
fn parse_engine_name(name : String) -> LayoutEngine {
  match name.to_lower() {
    "dot" => LayoutEngine::Dot
    "neato" => LayoutEngine::Neato
    "fdp" => LayoutEngine::Fdp
    "sfdp" => LayoutEngine::Sfdp
    "twopi" => LayoutEngine::Twopi
    "circo" => LayoutEngine::Circo
    "osage" => LayoutEngine::Osage
    "patchwork" => LayoutEngine::Patchwork
    "nop" => LayoutEngine::Nop
    _ => LayoutEngine::Other(name~)
  }
}

///|
pub fn default_engine(program? : String = "dot") -> LayoutEngine {
  parse_engine_name(program_basename(program))
}

///|
pub fn default_format(_engine : LayoutEngine) -> FormatSpec {
  { format: OutputFormat::Dot, variant: None }
}

///|
fn parse_format_spec(text : String) -> FormatSpec {
  let mut format_name = ""
  let mut variant : String? = None
  let mut idx = 0
  for part in text.split(":") {
    if idx == 0 {
      format_name = part.to_string()
    } else if idx == 1 {
      variant = Some(part.to_string())
    }
    idx = idx + 1
  }
  if format_name == "" {
    format_name = text
  }
  let lower = format_name.to_lower()
  let format = match lower {
    "dot" => OutputFormat::Dot
    "xdot" => OutputFormat::XDot
    "svg" => OutputFormat::Svg
    _ => OutputFormat::Other(name=format_name)
  }
  { format, variant }
}

///|
fn parse_assignment(
  flag : String,
  text : String,
) -> AttrAssignment raise CliError {
  let name_sb = StringBuilder::new()
  let value_sb = StringBuilder::new()
  let mut seen_eq = false
  for ch in text {
    if !seen_eq && ch == '=' {
      seen_eq = true
      continue
    }
    if seen_eq {
      value_sb.write_char(ch)
    } else {
      name_sb.write_char(ch)
    }
  }
  if !seen_eq {
    raise CliError::InvalidAssignment(flag~, value=text)
  }
  let name = name_sb.to_string()
  if name == "" {
    raise CliError::InvalidAssignment(flag~, value=text)
  }
  { name, value: value_sb.to_string() }
}

///|
fn parse_double(flag : String, text : String) -> Double raise CliError {
  @strconv.parse_double(text) catch {
    _ => raise CliError::InvalidNumber(flag~, value=text)
  }
}

///|
fn parse_int(flag : String, text : String) -> Int raise CliError {
  @strconv.parse_int(text) catch {
    _ => raise CliError::InvalidNumber(flag~, value=text)
  }
}

///|
fn try_parse_double(text : String) -> Double? {
  try @strconv.parse_double(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn try_parse_int(text : String) -> Int? {
  try @strconv.parse_int(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn required_flag_value(
  args : Array[String],
  index : Int,
  flag : String,
  prefix_len : Int,
) -> (String, Int) raise CliError {
  let arg = args[index]
  if arg.length() > prefix_len {
    let value = arg.unsafe_substring(start=prefix_len, end=arg.length())
    return (value, index)
  }
  let next_index = index + 1
  if next_index >= args.length() {
    raise CliError::MissingValue(flag~)
  }
  let value = args[next_index]
  if value.has_prefix("-") {
    raise CliError::MissingValue(flag~)
  }
  (value, next_index)
}

///|
fn optional_int_flag_value(
  args : Array[String],
  index : Int,
  flag : String,
  prefix_len : Int,
) -> (Int?, Int) raise CliError {
  let arg = args[index]
  if arg.length() > prefix_len {
    let value = arg.unsafe_substring(start=prefix_len, end=arg.length())
    return (Some(parse_int(flag, value)), index)
  }
  let next_index = index + 1
  if next_index < args.length() {
    let value = args[next_index]
    if !value.has_prefix("-") {
      match try_parse_int(value) {
        Some(parsed) => return (Some(parsed), next_index)
        None => ()
      }
    }
  }
  (None, index)
}

///|
fn optional_double_flag_value(
  args : Array[String],
  index : Int,
  flag : String,
  prefix_len : Int,
) -> (Double?, Int) raise CliError {
  let arg = args[index]
  if arg.length() > prefix_len {
    let value = arg.unsafe_substring(start=prefix_len, end=arg.length())
    return (Some(parse_double(flag, value)), index)
  }
  let next_index = index + 1
  if next_index < args.length() {
    let value = args[next_index]
    if !value.has_prefix("-") {
      match try_parse_double(value) {
        Some(parsed) => return (Some(parsed), next_index)
        None => ()
      }
    }
  }
  (None, index)
}

///|
pub fn parse_cli_args(
  args : Array[String],
  program? : String = "dot",
) -> CliAction raise CliError {
  let mut engine = default_engine(program~)
  let mut format = default_format(engine)
  let mut format_set = false
  let mut input : String? = None
  let mut output : String? = None
  let graph_attrs : Array[AttrAssignment] = []
  let node_attrs : Array[AttrAssignment] = []
  let edge_attrs : Array[AttrAssignment] = []
  let mut scale : Double? = None
  let mut neato_no_op : Int? = None
  let mut neato_prune = false
  let mut verbose = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-V" {
      return CliAction::ShowVersion
    }
    if arg == "-v" {
      verbose = true
      i = i + 1
      continue
    }
    if arg.has_prefix("-T") {
      let mut value = if arg.length() > 2 {
        arg.unsafe_substring(start=2, end=arg.length())
      } else {
        ""
      }
      if value == "" {
        if i + 1 < args.length() && !args[i + 1].has_prefix("-") {
          value = args[i + 1]
          i = i + 1
        } else {
          return CliAction::ListFormats
        }
      }
      format = parse_format_spec(value)
      format_set = true
      i = i + 1
      continue
    }
    if arg.has_prefix("-K") {
      let (value, next) = required_flag_value(args, i, "-K", 2)
      engine = parse_engine_name(value)
      if !format_set {
        format = default_format(engine)
      }
      i = next + 1
      continue
    }
    if arg.has_prefix("-o") {
      let (value, next) = required_flag_value(args, i, "-o", 2)
      output = Some(value)
      i = next + 1
      continue
    }
    if arg.has_prefix("-G") {
      let (value, next) = required_flag_value(args, i, "-G", 2)
      graph_attrs.push(parse_assignment("-G", value))
      i = next + 1
      continue
    }
    if arg.has_prefix("-N") {
      let (value, next) = required_flag_value(args, i, "-N", 2)
      node_attrs.push(parse_assignment("-N", value))
      i = next + 1
      continue
    }
    if arg.has_prefix("-E") {
      let (value, next) = required_flag_value(args, i, "-E", 2)
      edge_attrs.push(parse_assignment("-E", value))
      i = next + 1
      continue
    }
    if arg.has_prefix("-s") {
      let (value, next) = optional_double_flag_value(args, i, "-s", 2)
      match value {
        Some(parsed) => scale = Some(parsed)
        None => scale = Some(72.0)
      }
      i = next + 1
      continue
    }
    if arg.has_prefix("-n") {
      let (value, next) = optional_int_flag_value(args, i, "-n", 2)
      match value {
        Some(parsed) => neato_no_op = Some(parsed)
        None => neato_no_op = Some(1)
      }
      i = next + 1
      continue
    }
    if arg == "-x" {
      neato_prune = true
      i = i + 1
      continue
    }
    if arg == "-" {
      match input {
        Some(_) => raise CliError::MultipleInputs
        None => input = Some(arg)
      }
      i = i + 1
      continue
    }
    if arg.has_prefix("-") {
      raise CliError::UnknownFlag(flag=arg)
    }
    match input {
      Some(_) => raise CliError::MultipleInputs
      None => input = Some(arg)
    }
    i = i + 1
  }
  CliAction::Render({
    input,
    output,
    engine,
    format,
    graph_attrs,
    node_attrs,
    edge_attrs,
    scale,
    neato_no_op,
    neato_prune,
    verbose,
  })
}

///|
fn apply_attrs(graph : @cgraph.Graph, job : CliJob) -> Unit {
  for attr in job.graph_attrs {
    graph.set_attr(attr.name, attr.value)
  }
  for attr in job.node_attrs {
    graph.set_default_attr(@cgraph.AttrKind::Node, attr.name, attr.value)
  }
  for attr in job.edge_attrs {
    graph.set_default_attr(@cgraph.AttrKind::Edge, attr.name, attr.value)
  }
}

///|
fn layout_for_job(
  job : CliJob,
  graph : @cgraph.Graph,
) -> @layout_dot.DotLayoutGraph raise {
  match job.engine {
    LayoutEngine::Dot => @layout_dot.layout_dot(graph)
    LayoutEngine::Neato => {
      let scale = match job.scale {
        Some(value) => value
        None => 72.0
      }
      match job.neato_no_op {
        Some(level) =>
          @layout_dot.layout_neato_noop(
            graph,
            no_op_level=level,
            scale~,
            prune=job.neato_prune,
          )
        None => @layout_dot.layout_neato(graph, scale~, prune=job.neato_prune)
      }
    }
    LayoutEngine::Fdp
    | LayoutEngine::Sfdp
    | LayoutEngine::Twopi
    | LayoutEngine::Circo
    | LayoutEngine::Osage
    | LayoutEngine::Patchwork
    | LayoutEngine::Nop
    | LayoutEngine::Other(_) =>
      raise @layout_dot.DotLayoutError::UnsupportedFeature(
        message="layout engine not implemented",
      )
  }
}

///|
pub fn render_job(job : CliJob) -> String raise {
  cli_trace("cli: parse start")
  let graph = read_dot_input(job.input)
  cli_trace("cli: parse done")
  apply_attrs(graph, job)
  cli_trace("cli: layout start")
  let layout = layout_for_job(job, graph)
  cli_trace("cli: layout done")
  match job.format.format {
    OutputFormat::Dot => {
      layout.apply()
      @dot.write_dot(layout.graph)
    }
    OutputFormat::XDot => @xdot.render_xdot(layout)
    OutputFormat::Svg => @svg.render_svg(layout)
    OutputFormat::Other(_) => {
      layout.apply()
      @dot.write_dot(layout.graph)
    }
  }
}

///|
fn render_job_bytes(job : CliJob) -> Bytes raise {
  cli_trace("cli: parse start")
  let graph = read_dot_input(job.input)
  cli_trace("cli: parse done")
  apply_attrs(graph, job)
  cli_trace("cli: layout start")
  let layout = layout_for_job(job, graph)
  cli_trace("cli: layout done")
  match job.format.format {
    OutputFormat::Dot => {
      layout.apply()
      @utf8.encode(@dot.write_dot(layout.graph), bom=false)
    }
    OutputFormat::XDot => @xdot.render_xdot_bytes(layout)
    OutputFormat::Svg => @utf8.encode(@svg.render_svg(layout), bom=false)
    OutputFormat::Other(_) => {
      layout.apply()
      @utf8.encode(@dot.write_dot(layout.graph), bom=false)
    }
  }
}

///|
fn read_dot_input(input : String?) -> @cgraph.Graph raise {
  let path = match input {
    None => "/dev/stdin"
    Some(path) => if path == "-" { "/dev/stdin" } else { path }
  }
  @dot.parse_dot_file(path)
}

///|
fn formats_list() -> String {
  ["dot", "xdot", "svg"].join("\n") + "\n"
}

///|
fn version_text() -> String {
  "graphviz.mbt"
}

///|
pub fn run_cli(args : Array[String], program? : String = "dot") -> String raise {
  match parse_cli_args(args, program~) {
    CliAction::Render(job) => {
      match job.output {
        Some(path) => {
          @fs.write_bytes_to_file(path, render_job_bytes(job))
          ""
        }
        None => render_job(job)
      }
    }
    CliAction::ListFormats => formats_list()
    CliAction::ShowVersion => version_text()
  }
}

///|
pub fn run_cli_bytes(
  args : Array[String],
  program? : String = "dot",
) -> Bytes raise {
  match parse_cli_args(args, program~) {
    CliAction::Render(job) => {
      match job.output {
        Some(path) => {
          @fs.write_bytes_to_file(path, render_job_bytes(job))
          @utf8.encode("", bom=false)
        }
        None => render_job_bytes(job)
      }
    }
    CliAction::ListFormats => @utf8.encode(formats_list(), bom=false)
    CliAction::ShowVersion => @utf8.encode(version_text(), bom=false)
  }
}
