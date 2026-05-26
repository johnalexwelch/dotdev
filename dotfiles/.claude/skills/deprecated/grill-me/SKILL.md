---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shard understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design,m or mentions "grill me".
version: 0.1.0
---

## Deprecation Status

Status: deprecated. Historical reference only; do not route new work here.

- Replaced by: `grill-with-docs, v1-idea-grill, dnd-grill, or dnd-grill-with-canon`
- Reason: Superseded by domain-specific grilling workflows and decision logging.
- Date: 2026-05-21


Interview me relentlessly about every aspect of this plan untill we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.

For every accepted recommendation or user-edited answer, use `decision-log` to record the question, final decision, what else was considered, and tradeoffs accepted. Future planning workflows should consume that log instead of re-grilling settled decisions.
