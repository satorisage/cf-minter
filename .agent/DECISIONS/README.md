# Project Decisions

Append-only register of architectural decisions. Each decision lives in
its own file at `.agent/DECISIONS/DECISION-XXXX-slug.md` and progresses
through a defined lifecycle.

`.agent/PROJECT-SCOPE.md` (`## Hard constraints`) governs binding force:
decisions marked **Binding** here apply until explicitly superseded by a
new dated decision.

## Lifecycle

Each decision has a **Status**:

- **Proposed** — under discussion, not yet ratified. Implementation should
  not depend on this decision until ratified.
- **Binding** — ratified, in effect. Cited by file:section in other
  artifacts. Changing direction requires a superseding decision, not an
  edit.
- **Superseded by D-YYYY** — was Binding, replaced by a later decision.
- **Updated by D-YYYY** — still **Binding**; a later decision retired one
  named clause and everything else stands (D-0128). Not retirement — read both.
  The original file stays; the index row notes the supersession.

Orthogonal to Status, each decision carries a **Grade** (D-0123) —
`invariant` (held to; revised only by supersession) or `working` (a
position taken to proceed; Binding, but revised *in place* by
`decision-log amend`, which adds a dated `Amended:` header line and
marks the index row). An ungraded decision reads as `invariant`.

## Three-surface sync at ratification

When a decision moves Proposed → Binding, three surfaces update in
lockstep:

1. **The decision file** — `Status:` Binding, add `Ratified:` date.
2. **This index** — update the row; if it supersedes an earlier decision,
   mark the earlier row "Superseded by D-XXXX (date)".
3. **`PROJECT-STATE.md`** — clear any "deferred until D-XXXX ratified"
   notes referencing this decision.

Missing any of the three is drift. The `decision-log/` tool
automates this.

## Index

| ID | Date | Title |
|---|---|---|

(Add a row per decision in numeric order. Mark superseded decisions
inline in the title cell: `— **Superseded by 0NNN (YYYY-MM-DD)**`.
Mark an amended working decision the same way: `— **amended YYYY-MM-DD**`
— written by `decision-log amend`: one marker per row, carrying the latest
amendment date (the file's `Amended:` lines hold the full history).
Mark a draft withdrawn with no successor: `— **Withdrawn (YYYY-MM-DD)**`
Mark a decision amended in part: `— **Updated by DECISION-NNNN (YYYY-MM-DD)**`
followed by the clause — never "Superseded", which would read as retired.
— written by `decision-log withdraw` (D-0124), the date from the file's
`**Withdrawn:** YYYY-MM-DD — <reason>` line; a draft withdrawn in favour
of a successor carries `— **Withdrawn in favour of DECISION-N (YYYY-MM-DD)**`
instead (D-0107). All these markers share one shape — ` — **…**` after
the title — which is what the index reader splits on; a marker outside
that shape is read as part of a plain title.)
