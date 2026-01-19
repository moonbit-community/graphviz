# DOT Language and Attribute System

This document captures the DOT input language as used by Graphviz, with
an emphasis on grammar, attribute scoping, and CLI flags relevant for
parsing and serialization in the MoonBit rewrite.

## Purpose and model

- DOT is a text language for graphs.
- Graphviz tools read DOT, build a graph model, then attach layout
  attributes and render.
- The same language is used for input and for some outputs (e.g. -Tdot
  and -Txdot).

## Grammar (summary)

From the Graphviz dot guide, the abstract grammar is:

- graph := [strict] (digraph | graph) id { stmt-list }
- stmt-list := [ stmt [;] [stmt-list] ]
- stmt := attr-stmt | node-stmt | edge-stmt | subgraph | id = id
- attr-stmt := (graph | node | edge) attr-list
- attr-list := [ [a-list] ] [attr-list]
- a-list := id = id [ , ] [a-list]
- node-stmt := node-id [attr-list]
- node-id := id [port]
- port := : id [ : id ]
- edge-stmt := (node-id | subgraph) edgeRHS [attr-list]
- edgeRHS := edgeop (node-id | subgraph) [edgeRHS]
- subgraph := [subgraph id] { stmt-list } | subgraph id

Notes:

- edgeop is "->" for directed graphs and "--" for undirected graphs.
- Semicolons are optional, except for a rare subgraph ambiguity case.
- C++-style comments are supported: /* ... */ and // ...

## IDs and quoting

- id can be:
  - an alphanumeric string not starting with a digit (underscores allowed),
  - a number, or
  - a quoted string (double quotes; escaped quotes allowed).
- Attribute values that include whitespace or punctuation should be quoted.

## Statements and creation rules

- Nodes are created when their name first appears.
- Edges are created by edge statements (node-id edgeop node-id).
- A graph can be declared strict to forbid multiple edges between the
  same endpoints.

## Attribute scopes and defaults

- Attributes are name=value string pairs, attached to graphs, nodes, or edges.
- Attribute lists are written in square brackets: [key=value, key2=value2].
- Default attributes can be set with attr-stmt:
  - graph [key=value];
  - node [key=value];
  - edge [key=value];
- Defaults apply to objects created after the statement. Order matters.

Example (defaults and override):

```
digraph G {
  node [shape=box, style=filled];
  edge [color=red];
  a -> b;       // uses defaults
  c [shape=ellipse];
  c -> d [color=blue];
}
```

## Subgraphs and clusters

- subgraph groups nodes and edges for layout constraints and attributes.
- A subgraph whose name starts with "cluster" is treated as a cluster.
- Clusters draw a bounding rectangle and can have labels and styles.
- compound=true on the root graph allows edges to connect to clusters
  via lhead/ltail attributes.

Example (cluster):

```
digraph G {
  subgraph cluster_0 {
    label="core";
    a; b;
  }
  a -> b;
}
```

## Ports and record/HTML labels

- Ports let edges attach to specific points on nodes.
- Syntax: node:port:compass, where compass is one of n, ne, e, se, s, sw, w, nw.
- Record shapes and HTML-like labels define named fields usable as ports.

Example (record ports):

```
digraph G {
  node [shape=record];
  n0 [label="<f0> left|<f1> right"];
  n1 [label="<f0> a|<f1> b"];
  n0:f1 -> n1:f0;
}
```

## Labels

- label sets the visible text for graphs, nodes, or edges.
- Multi-line labels use \n in quoted strings.
- HTML-like labels are supported (e.g. label=<<TABLE>...</TABLE>>)
  and can define ports via the PORT attribute on table cells.

## Attribute units (selected)

- Many geometry values are in points (72 points per inch).
- Some sizes are in inches (e.g. node width/height).
- Graphviz serializes values as strings; parsers must interpret per
  attribute type.

## CLI flags that affect DOT parsing/serialization

From Dot.ref:

- -Gname=value: set graph default attribute
- -Nname=value: set node default attribute
- -Ename=value: set edge default attribute
- -Tformat: output format (dot, xdot, svg, png, pdf, etc.)
- -ooutfile: write output to file
- -s[scale]: input scale (defaults to 72 if omitted)
- -n[num]: no-op layout for neato (treats nodes as pre-positioned)
- -x: prune isolated nodes/peninsulas in neato
- -v / -V: verbose / version
- -l<libfile>: device-dependent library files for renderers

## Reference files

- refs/graphviz/doc/Dot.ref
- refs/graphviz/doc/dotguide/dotguide.tex
- refs/graphviz/doc/schema/attributes.xml
- refs/graphviz/doc/char.html (redirects to graphviz.org)
