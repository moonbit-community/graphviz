///|
/// Output format selector for CLI.
pub(all) enum OutputFormat {
  Dot
  XDot
  Svg
  Other(name~ : String)
} derive(Show, Eq)

///|
/// Output format + optional variant (e.g. png:cairo).
pub(all) struct FormatSpec {
  format : OutputFormat
  variant : String?
} derive(Show, Eq)

///|
/// Layout engine selector.
pub(all) enum LayoutEngine {
  Dot
  Neato
  Fdp
  Sfdp
  Twopi
  Circo
  Osage
  Patchwork
  Nop
  Other(name~ : String)
} derive(Show, Eq)

///|
/// Attribute assignment parsed from -G/-N/-E flags.
pub(all) struct AttrAssignment {
  name : String
  value : String
} derive(Show, Eq)

///|
/// Parsed CLI job describing a single render pipeline.
pub(all) struct CliJob {
  input : String?
  output : String?
  engine : LayoutEngine
  format : FormatSpec
  graph_attrs : Array[AttrAssignment]
  node_attrs : Array[AttrAssignment]
  edge_attrs : Array[AttrAssignment]
  scale : Double?
  neato_no_op : Int?
  neato_prune : Bool
  verbose : Bool
} derive(Show, Eq)

///|
/// CLI actions supported by the dot/neato frontends.
pub(all) enum CliAction {
  Render(CliJob)
  ListFormats
  ShowVersion
} derive(Show, Eq)

///|
/// Errors reported while parsing CLI flags.
pub(all) suberror CliError {
  UnknownFlag(flag~ : String)
  MissingValue(flag~ : String)
  InvalidAssignment(flag~ : String, value~ : String)
  InvalidNumber(flag~ : String, value~ : String)
  MultipleInputs
} derive(Show, Eq)

///|
/// Resolve default engine from the program name (dot, neato, etc.).
#declaration_only
pub fn default_engine(program? : String = "dot") -> LayoutEngine {
  ...
}

///|
/// Resolve default output format for a given engine.
#declaration_only
pub fn default_format(engine : LayoutEngine) -> FormatSpec {
  ...
}

///|
/// Parse CLI arguments into an action.
/// Supports -T, -K, -o, -G/-N/-E, -s, -n, -x, -v, -V.
#declaration_only
pub fn parse_cli_args(
  args : Array[String],
  program? : String = "dot",
) -> CliAction raise CliError {
  ...
}
