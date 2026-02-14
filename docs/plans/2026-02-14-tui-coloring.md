# TUI Coloring Implementation Plan (Reviewed & Rewritten)

**Date:** 2026-02-14  
**Scope:** `ministry-of-future-plans/browser/Render.psm1`, `ministry-of-future-plans/tests/Render.Tests.ps1`  
**Source palette:** `ministry-of-future-plans/docs/TuiColoring.md`

## Review Findings (from previous draft)

### High severity
1. **Public API leakage in rendering internals** (`ministry-of-future-plans/docs/plans/2026-02-14-tui-coloring.md:134`, `ministry-of-future-plans/docs/plans/2026-02-14-tui-coloring.md:273`)  
   The draft exports `Get-PriorityColor`, `Get-RiskColor`, and `Write-ColorSegments`. These are internal rendering helpers and should stay private to avoid coupling tests and callers to unstable internals.

2. **Line-ending behavior is ambiguous and error-prone** (`ministry-of-future-plans/docs/plans/2026-02-14-tui-coloring.md:482`)  
   The draft identifies a newline problem late and resolves it ad hoc with `Write-Host ''`. This is fragile and likely to cause off-by-one line bugs.

3. **Architecture claim and tasks diverge** (`ministry-of-future-plans/docs/plans/2026-02-14-tui-coloring.md:7`)  
   The architecture says `Get-IdeaLineColors` / `Get-DetailLineColors` will be introduced, but tasks implement different helpers. This mismatch increases implementation drift.

### Medium severity
1. **Insufficient regression tests for render invariants** (`ministry-of-future-plans/docs/plans/2026-02-14-tui-coloring.md:300`)  
   Marking changes as “visual-only” misses testable invariants: width accounting, segment truncation, selected/unselected color mapping, and scrollbar marker precedence.

2. **Repeated tag-row logic remains a design risk** (`ministry-of-future-plans/docs/plans/2026-02-14-tui-coloring.md:351`)  
   The draft notices repetition but keeps too much row assembly inside `Render-BrowserState`, increasing bug surface.

3. **No explicit handling of null/empty content fields** (`ministry-of-future-plans/docs/plans/2026-02-14-tui-coloring.md:559`)  
   Detail lines should degrade safely when `Summary`, `Rationale`, `Tags`, `Priority`, or `Risk` are missing.

### Low severity
1. **Non-portable process guidance in plan text** (`ministry-of-future-plans/docs/plans/2026-02-14-tui-coloring.md:3`)  
   Tool-specific note (“For Claude”) should be removed to keep the plan repo-native.

## Design Goals

1. Keep state flow unchanged (render-only changes; no reducer/input/model mutation paths).
2. Make line composition deterministic and unit-testable.
3. Keep all row width behavior explicit and centrally enforced.
4. Keep helper APIs private unless required externally.
5. Preserve current UX while applying semantic color hierarchy.

## Color Contract

| Element | Color |
|---|---|
| Active `[Tags]` / `[Ideas]` header | `Cyan` |
| Inactive headers (`[Tags]`, `[Ideas]`, `[Details]`) | `DarkGray` |
| Cursor marker `>` | `Cyan` |
| Scroll thumb (`░`) | `Gray` |
| Scroll track (`│`) | `DarkGray` |
| Tag unselectable | `DarkGray` |
| Tag selected | `Green` |
| Tag normal | `Gray` |
| Idea ID | `DarkGray` |
| Idea title (normal) | `Gray` |
| Idea title (selected) | `White` on `DarkCyan` |
| Detail labels (`ID:`, `Summary:`, etc.) | `DarkYellow` |
| Detail values | `Gray` |
| Detail ID value | `DarkGray` |
| Priority `P0/P1` | `Red` |
| Priority `P2` | `Yellow` |
| Priority `P3` | `DarkCyan` |
| Risk `H` | `Red` |
| Risk `M` | `Yellow` |
| Risk `L` | `DarkGray` |
| Status line | `DarkGray` |

## Implementation Plan

### Task 1: Introduce pure color/segment composition helpers (private)

**Files:**
- Modify: `ministry-of-future-plans/browser/Render.psm1`
- Test: `ministry-of-future-plans/tests/Render.Tests.ps1`

**Add private helpers (do not export):**
- `Get-PriorityColor([string]$Priority)`
- `Get-RiskColor([string]$Risk)`
- `Get-MarkerColor([string]$Marker)`
- `Build-IdeaSegments(...)`
- `Build-DetailSegments(...)`

**Requirements:**
- Helpers are pure (no `Write-Host`, no console state writes).
- Unknown priority/risk values fall back to `Gray`.
- Null/missing idea fields must render as empty strings, not throw.

**Tests to add:**
- Priority/risk mapping tests.
- Marker color precedence (`>`, thumb, track, blank).
- Detail segment generation for missing fields.

### Task 2: Add one width-safe segment writer with explicit newline mode

**Files:**
- Modify: `ministry-of-future-plans/browser/Render.psm1`
- Test: `ministry-of-future-plans/tests/Render.Tests.ps1`

**Add helper:**
- `Write-ColorSegments -Segments <array> -Width <int> -NoNewline:<bool> [-BackgroundColor <ConsoleColor>] [-NoEmit]`

**Requirements:**
- Width always equals requested width when `Width > 0`.
- Truncation uses existing ellipsis policy (`...`) consistently.
- `NoNewline` semantics are explicit; no implicit `Write-Host ''` hacks.
- `NoEmit` returns normalized segments for tests.

**Tests to add:**
- Fits width, truncates width, pads width, empty segment list, width <= 0.
- Returned segment text total length equals target width.

### Task 3: Refactor `Render-BrowserState` to use helper pipeline

**Files:**
- Modify: `ministry-of-future-plans/browser/Render.psm1`

**Changes:**
- Header colors based on `ActivePane` (`Tags`/`Ideas` active in `Cyan`; inactive `DarkGray`; Details always inactive `DarkGray`).
- Tag rows: render marker color separately from tag body color.
- Idea rows: render marker, ID, and title segments separately.
- Selected idea row: apply `DarkCyan` background with white title.
- Detail pane: render label/value segments semantically, including priority/risk coloring.

**Guardrails:**
- Keep current layout math and scrolling behavior unchanged.
- Keep `Render-BrowserState` as orchestrator; segment assembly moved to helpers.

### Task 4: Lock behavior with targeted tests

**Files:**
- Modify: `ministry-of-future-plans/tests/Render.Tests.ps1`

**Tests to add (unit-level):**
- Segment builders return expected color sequence for:
  - unselected idea
  - selected idea
  - scrollbar-only row
- Detail line coloring for ID, labels, priority/risk values.
- Width invariants for rendered segment normalization.

**Testing strategy note:**
- Do not unit test `Write-Host` side effects directly.
- Unit test pure builders and `-NoEmit` behavior.
- Keep existing `Get-ScrollThumb` tests unchanged.

### Task 5: Manual visual verification

Run:
- `pwsh -File .\ministry-of-future-plans\Browse-Ideas.ps1`

Checklist:
- Active/inactive header colors swap correctly with Tab.
- Cursor marker is always `Cyan`.
- Scrollbar thumb/track colors are correct in both panes.
- Idea ID/title contrast matches contract.
- Selected row uses `White` on `DarkCyan` with clean alignment.
- Detail labels/values and priority/risk semantics are correct.
- No wrapping, ghost characters, or width drift on resize.

### Task 6: Final validation in repo workflow

Run (after implementation is complete):
- `cargo build`
- `cargo clippy --all-targets -- -D warnings`
- `Invoke-Pester .\ministry-of-future-plans\tests\ -Output Detailed`

## Blockers and Decisions

1. **Console color capability variance**  
   Some terminals may ignore background colors or map ANSI colors differently. Decision: treat this as acceptable compatibility variance; preserve semantic mapping and avoid non-ANSI dependencies.

2. **No native render snapshot framework**  
   Direct terminal pixel/snapshot assertions are not available. Decision: rely on pure segment-builder tests and manual visual checklist.

3. **Details pane focus semantics**  
   Current UX does not navigate to Details pane. Decision: keep `[Details]` inactive (`DarkGray`) unless navigation model changes.

## Lessons Learned / Preventive Design

1. Centralize color and marker rules in pure helpers to prevent repeated inline condition bugs.
2. Separate “compose line segments” from “emit to console” to improve testability.
3. Enforce width invariants in one place to avoid truncation/alignment regressions.
4. Keep internal render helpers private to avoid accidental API contracts.

## Future Extensions (Nice-to-have)

1. Add a theme table (`$Theme`) to allow alternate palettes without changing render logic.
2. Add optional emphasis parsing in details (e.g., markdown `**bold**` -> `White`).
3. Add a high-contrast accessibility mode toggle.
4. Add a tiny render telemetry hook (`engine_debug!` equivalent in PowerShell context) for row width mismatches during development.