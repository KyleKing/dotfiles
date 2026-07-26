---
name: mermaid-diagrams
description: Draw mermaid diagrams to the user's conventions — C4 model diagrams, flowcharts, and sequence diagrams for docs, Linear proposals, design docs, and READMEs. Use whenever producing a mermaid block, choosing a diagram type, or reviewing an existing diagram that has grown too dense.
---

# Mermaid diagrams

Keep diagrams under roughly 15 nodes. Group related items rather than enumerating
them individually.

Put detail in a reference table below the diagram, not in node labels. A node label
carries the name; the table carries what it does.

## Picking the type

Use the correct C4 level rather than defaulting to one: System Landscape, C1
Context, C2 Container, C3 Component, Deployment, or Dynamic.

Outside C4: `flowchart` for decision trees, `sequenceDiagram` for request and
failure flows.

For a design proposal specifically, a run-lifecycle `sequenceDiagram` plus an
interface `classDiagram` carries more than a single high-level flowchart. Linear
renders mermaid natively.
