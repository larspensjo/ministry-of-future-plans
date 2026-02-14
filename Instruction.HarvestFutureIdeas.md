# Instruction Document — Initialize and Harvest `FutureIdeas.md`

Version: 2026-02-14
Purpose: Define one workflow for:
1. Creating a new `FutureIdeas.md` from template (first-time setup).
2. Incrementally harvesting deferred ideas into an existing `FutureIdeas.md`.

## Source of Truth

Use these documents in this order:
1. `docs/FutureIdeas-template.md`:
   - Canonical file structure.
   - Canonical entry shape and field names.
   - Taxonomy section placement.
2. This instruction document:
   - Process rules.
   - Dedup/merge rules.
   - Output format by mode.

If this document and the template overlap, prefer the template for structure/format and this document for workflow behavior.

## Mode Selection

Choose mode before writing output:

- `Initialize` mode:
  - Use when target `FutureIdeas.md` does not exist yet.
  - Output is a full file content based on the template.
- `Harvest` mode:
  - Use when target `FutureIdeas.md` already exists.
  - Output is patch-only (`Adds`, `Updates`, `Merges`, `Uncertain`).
  - Do not rewrite the entire file.

## Definition — “Future Idea”

A future idea is deferred, optional, or next-phase work such as:
- explicit “future/later/phase 2”
- postponed robustness/performance/tooling/docs work
- UX and architecture extensions
- TODOs not required for current plan completion

Exclude:
- work already implemented
- historical notes without actionable follow-up
- trivial duplicates already covered by existing entries

## Taxonomy Rules

- Two levels are mandatory: `TopLevel` and `SubLevel`.
- Taxonomy table under `## Taxonomy` is the local authority for valid combinations.
- Keep naming stable and codebase-relevant (avoid one-off labels).
- If classification is unclear, place candidate in `Uncertain` with 1-3 options.

## Priority / Effort / Risk Heuristics

Priority:
- `P0`: correctness/safety/security blocker
- `P1`: high leverage, likely near-term
- `P2`: useful medium-priority improvement
- `P3`: speculative or nice-to-have

Effort:
- `S`: hours to 1 day
- `M`: 2-5 days
- `L`: 1-3 weeks
- `XL`: multi-week/cross-cutting

Risk:
- `L`: straightforward
- `M`: some integration/unknowns
- `H`: high uncertainty or correctness sensitivity

If unclear: default to `Risk: M` and state uncertainty in `Notes`.

## Deduplication and Merge Rules

Before creating new entries:
1. Check existing `FutureIdeas.md` for semantic duplicates.
2. If same idea exists, prefer `Updates` over `Adds`.
3. If two entries overlap heavily, use `Merges` and keep the strongest ID.
4. If related but distinct, keep both and add `Related`.

Never hard-delete entries; resolve via merge instructions.

## Procedure

1. Scan source docs for deferred/future signals.
2. Collect candidate notes (raw, internal).
3. Normalize to template-compliant entries.
4. Classify into taxonomy.
5. Deduplicate against existing ideas (Harvest mode).
6. Emit output in the required mode format.

## Output Contract by Mode

### Initialize Mode Output

Output a complete `FutureIdeas.md` document:
- Must start from `docs/FutureIdeas-template.md`.
- Must retain `## Taxonomy` at top.
- Must follow heading structure from template:
  - `## <TopLevel>`
  - `### <SubLevel>`
  - `#### [FI-...] <Title>`
- Must sort sections by `TopLevel`, then `SubLevel`.

### Harvest Mode Output

Output only:
- `Adds`
- `Updates`
- `Merges`
- `Uncertain`

Do not output full-file rewrites.

Patch template:

```md
# Patch

## Adds
<zero or more full entry blocks>

## Updates
- Target: [FI-...]
  Changes:
  - <field-level change>
  - <field-level change>
  Notes: <optional>

## Merges
- Keep: [FI-...]
  Merge: [FI-...], [FI-...]
  Rationale: <short>

## Uncertain
- Candidate: <short title>
  Why uncertain: <taxonomy/duplication/scope/etc>
  Suggested TopLevel/SubLevel:
  - <option 1>
  - <option 2>
  Proposed entry draft:
  <template-compliant entry>
```

## ID Rules

- Use format: `FI-<TopLevel>-<SubLevel>-NNNN`.
- If the file already has numbering, continue the sequence within that bucket.
- If reliable numbering cannot be determined, use `0000` and list in `Uncertain` for assignment.

## Quality Constraints

- Prefer fewer, concrete, testable ideas over many vague ones.
- Keep titles short and specific.
- Keep `Summary` concrete and `SuccessCriteria` observable.
- Always include `Origin` (`SourceDoc`, `SourceSection`, `Captured`).
- Do not invent facts not present in source documents.

## Validation Gate

After updating/creating `FutureIdeas.md`, run:

```powershell
.\ministry-of-future-plans\Validate.ps1 -IdeasPath .\ministry-of-future-plans\docs\FutureIdeas.md
```

For project-root ideas files, adjust `-IdeasPath` accordingly.
