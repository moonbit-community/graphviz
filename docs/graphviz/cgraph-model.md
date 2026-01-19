# Cgraph Data Model and Attributes

This document summarizes the cgraph data model, how attributes are stored,
and how subgraphs relate to the root graph. It is a reference for designing
MoonBit equivalents.

## Core object types

Cgraph exposes a small set of object types used across the codebase:

- Agraph_t: graph or subgraph
- Agnode_t: node within a graph
- Agedge_t: edge within a graph
- Agsym_t: attribute symbol (name + default + index)
- Agrec_t: internal record header for custom data

Cgraph owns all memory allocation for these objects.

## Root graph and namespaces

- A root graph defines the universe of nodes, edges, and subgraphs.
- Objects belong to exactly one root graph and cannot be shared across roots.
- Graphs can be directed or undirected and strict or non-strict.
  - strict disallows multi-edges (and strict+no-loops is "simple").
- Graph names are stored and preserved when writing DOT but are otherwise
  not interpreted by cgraph.

## Nodes

- Nodes are identified by a string name and an internal numeric ID.
- Nodes can be anonymous (name = NULL) when created through the API.
- Nodes have in-edge and out-edge sets even in undirected graphs.
- Creation and lookup share the same API; a create flag controls behavior.

## Edges

- An edge is a node pair: ordered in directed graphs, unordered in undirected.
- Cgraph still stores tail/head fields even for undirected graphs.
  - The tail/head assignment is based on creation order.
- Edge identity is (tail, head, name). The same name can be reused for
  different node pairs but not duplicated for the same pair.
- Internally, edges have separate in-edge and out-edge representations;
  the pointers differ. Use ageqedge for equality and agopp to flip direction.

## Subgraphs

- Subgraphs form a tree (hierarchy) within a root graph.
- A subgraph can contain any nodes and edges from its parent.
- Adding a node/edge to a subgraph implicitly adds it to all ancestors
  up to the root.
- Subgraph names are scoped to their parent.

## Traversal order

- Iteration over nodes/edges is in creation order in the root graph.
- For undirected graphs, an orientation is assigned for in/out traversal.

## Attribute system (string attributes)

Attributes are stored as string name/value pairs but are tracked through
per-kind attribute dictionaries.

- Attributes are declared per kind: graph, node, or edge.
- All objects of a kind share the same attribute schema in a root graph.
- Agsym_t stores:
  - name: attribute name
  - defval: default value for new objects
  - id: index into the per-object value array

Access patterns:

- agattr: create or look up an attribute (by name + kind)
- agget/agset: access by attribute name (string lookup)
- agxget/agxset: access by Agsym_t (index lookup)
- agsafeset: define if missing, then set
- agcopyattr: copy all attribute values between objects (same kind)

Note: agset fails if the attribute was not defined via agattr.

## Internal records (binary data)

String attributes are insufficient for algorithmic state, so cgraph
supports per-object binary records.

- A record must begin with Agrec_t header.
- Records are attached to graphs, nodes, or edges.
- Records can be attached per-object (agbindrec) or to all objects of a kind
  in a graph (aginit).
- aggetrec looks up by name; agdelrec removes.

Performance feature:

- Records can be locked to the head of the internal record list.
- AGDATA(obj) returns the locked record pointer for direct access.

## String pool

Cgraph manages a reference-counted string pool:

- agstrdup / agstrbind / agstrfree for string lifetime
- agstrdup_html for HTML-like labels
- agstrcanon to produce canonical DOT-safe strings

This reduces memory usage for shared strings across large graphs.

## Disciplines (I/O + ID mapping)

Cgraph supports custom disciplines to override:

- ID allocation/mapping
- I/O behavior for read/write

The ID discipline supports mapping between names and numeric IDs and
is required for DOT I/O compatibility.

## Implications for MoonBit

- Model a root-graph namespace with a stable object identity system.
- Use per-kind attribute tables with fast per-object value arrays.
- Separate public string attributes from internal algorithm records.
- Preserve subgraph hierarchy and membership propagation rules.

## References

- refs/graphviz/doc/libgraph/Agraph.tex
- refs/graphviz/lib/cgraph/cgraph.3
- refs/graphviz/lib/cgraph/cgraph.h
- refs/graphviz/lib/cdt
