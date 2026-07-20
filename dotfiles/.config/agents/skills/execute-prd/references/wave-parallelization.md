# Wave Parallelization Examples

Load this during Phase 4 before executing children.

## Rules

1. Compute likely file scopes for each ready child from the issue body, related PRs, and codebase search.
2. Two children can run in parallel only when their file scopes are disjoint, neither depends on the other's output, and they do not both modify shared configuration such as package manifests or migrations.
3. Group concurrent children into waves. Waves execute sequentially; children inside a wave execute in parallel.
4. If file scope estimation is uncertain, run serially. False parallelism costs more than it saves.

## Example

```text
Wave 1: [child-A, child-B]  <- disjoint scopes, run in parallel
Wave 2: [child-C]           <- depends on child-A's output
Wave 3: [child-D, child-E]  <- disjoint scopes, both depend on child-C
```
