# Plan: Future Ideas Browser (TUI)

## 1. Overview
Create `ministry-of-future-plans/Browse-Ideas.ps1`, a read-only terminal browser for `docs/FutureIdeas.md`.

The implementation follows a strict **Model-Update-View** flow:
1. Input is translated into typed Actions.
2. A pure reducer computes next State.
3. Rendering reads State only and paints a frame.
4. Any side effects (console IO, capability probe, load file) are isolated.

This keeps behavior traceable and testable as complexity grows.

Primary target: **Windows Terminal** (full ANSI and Unicode). Graceful degradation for other hosts via capability probe.

## 2. Scope and Non-Goals

### In scope
- Interactive browsing with tag filters, idea list, and detail pane.
- Stable layout with resize handling and minimum-terminal fallback.
- Refactor `ConvertFrom-IdeaDoc` in `common/IdeaDocCore.psm1` to return fully typed entries with parsed fields.
- Fix existing callers (`Analyze.ps1`, `Validate.ps1`) to work with the refactored parser.
- Automated tests for parser helpers, reducer logic, layout math, filtering/sorting/search helpers, and reducer action sequences.

### Out of scope for this plan
- Mouse support.
- Editing `FutureIdeas.md` from the browser.
- Complex integration testing of raw key-loop timing behavior.

## 3. Architecture

## 3.1 Data Contracts

`IdeaDocCore.psm1`'s `ConvertFrom-IdeaDoc` will be refactored so that each entry in `.Entries` is a fully typed object. Callers no longer need to re-parse raw markdown lines for fields.

Typed entry shape:
```powershell
[pscustomobject]@{
    Id              = 'FI-...'
    Title           = '...'
    TopLevel        = '...'
    SubLevel        = '...'
    Status          = 'Candidate'
    Priority        = 'P0|P1|P2|P3'
    Effort          = 'S|M|L|XL'
    Risk            = 'L|M|H'
    Tags            = @('tag1', 'tag2')
    Summary         = '...'
    Rationale       = '...'
    Captured        = [datetime]::Parse('2026-02-13')
    OriginSourceDoc = '...'
    OriginSection   = '...'
    SuccessCriteria = @('...', '...')
    Dependencies    = @(...)
    Related         = @(...)
    StartLine       = 0
    LineNumber      = 0       # alias for StartLine for caller readability
    RawLines        = @(...)   # preserved for callers that need it
}
```

Supporting helpers added to `IdeaDocCore.psm1`:
- `ConvertFrom-TagString` — parses `[tag1, tag2, ...]` into a string array. Handles empty brackets, trailing commas, whitespace.
- `Get-SectionPresence` — fix to also return `StartIndex`/`EndIndex` alongside `Found`/`Items`, resolving the existing API mismatch.

Migration strategy:
- `ConvertFrom-IdeaDoc` always returns typed entries. The old raw-lines-only shape is removed.
- `Analyze.ps1` and `Validate.ps1` are updated to consume typed entries directly, eliminating their inline field parsing.
- `Get-FieldMap` remains available for edge-case callers but is no longer the primary API.

## 3.2 Browser State

State is the single source of truth and is externally immutable.

```powershell
$State = @{
    Data = @{
        AllIdeas = @(...)     # Typed idea entries
        AllTags  = @(...)
    }
    Ui = @{
        ActivePane  = 'Tags'  # Tags | Ideas | Detail
        IsMaximized = $false
        Layout      = @{}     # Calculated rectangles
    }
    Query = @{
        SelectedTags = [System.Collections.Generic.HashSet[string]]::new()
        SearchText   = ''     # Phase 3
        SearchMode   = 'None' # None | Regex
        SortMode     = 'Default' # Default | Priority | Risk | CapturedDesc
    }
    Derived = @{
        VisibleIdeaIds = @()  # recomputed when Query changes
        VisibleTags    = @()  # optional: per-tag counts for current filtered set
    }
    Cursor = @{
        TagIndex      = 0
        TagScrollTop  = 0
        IdeaIndex     = 0
        IdeaScrollTop = 0
        DetailScroll  = 0
    }
    Runtime = @{
        IsRunning      = $true
        LastError      = $null
        TerminalCaps   = @{}
        LastWindowSize = @{ Width = 0; Height = 0 }
    }
}
```

## 3.3 Derived State: `Get-VisibleIdeaIds`

The derivation function is explicit and pure:

```powershell
function Get-VisibleIdeaIds {
    param($AllIdeas, $SelectedTags, $SearchText, $SearchMode, $SortMode)
    # Filter -> Sort -> Return IDs
}
```

Invariants:
- Empty `SelectedTags` means "show all" (not "show none").
- Null `SelectedTags` is treated as empty.
- AND semantics: an idea must have **all** selected tags to be visible.
- Sort stability: when two items tie on the sort key, fall back to ID order.
- This is the single most important function to unit test.

Optional enhancement:
- Derive `VisibleTags` from the current filtered set to show tag counts (e.g., `security (5)`), and optionally sort tags by local relevance.

## 3.4 Actions and Reducer

Action examples:
- `Initialize(data, caps, size)`
- `MoveUp`, `MoveDown`, `PageUp`, `PageDown`
- `SwitchPane`
- `ToggleTag(tag)`
- `SetSearch(text, mode)`
- `CycleSort`
- `ToggleMaximize`
- `Resize(width, height)`
- `Quit`

Reducer rules:
- Pure, deterministic, no IO.
- Any action that changes query inputs invalidates and recomputes `Derived.VisibleIdeaIds`.
- Cursor clamping is centralized so indices never go out of range.

Cursor/scroll clamping invariants:
1. `IdeaIndex` is always in `[0, max(0, VisibleCount - 1)]`.
2. If `VisibleCount == 0`, Detail pane shows "No matching ideas".
3. `ScrollTop` is clamped to `max(0, VisibleCount - viewportHeight)`.
4. After any filter/sort change, `IdeaIndex` resets to 0.

## 3.5 Input Handling

Implement a key reader that normalizes raw key input into action names, isolating terminal quirks from the reducer.

- Use `[Console]::ReadKey($true)` (reliable on Windows Terminal).
- Normalize arrow key escape sequences and modifier keys.
- Handle key repeat / buffered input so holding Down scrolls smoothly without queuing.
- The key reader is testable independently of the reducer.
- `Esc` behavior:
  - If detail is maximized: unmaximize (back action).
  - If not maximized and active query is non-empty: clear query (selected tags + search).
  - If already at base state: no-op (do not quit on `Esc`; quitting stays on `Q`).

## 3.6 Rendering Strategy

### Phase 1: Simple redraw

Use `[Console]::SetCursorPosition` + `Write-Host` with `[Console]::CursorVisible = $false`. Clear-and-redraw on every action. Simple and sufficient for ~75 ideas.
Use named console colors (e.g., `Gray`, `Cyan`, `Yellow`) for MVP compatibility; defer ANSI/RGB styling until capability probe confirms support.

### Phase 2: Off-screen frame buffer

Introduce an off-screen frame model:
1. Render state into a buffer (text + style per cell/segment).
2. Prefer line-based diff with previous frame (compare full rendered lines, repaint changed lines).
3. Write only changed regions.

Benefits:
- Minimal flicker during resize/maximize/wrap transitions.
- No stale characters after layout changes.

Fallback (both phases):
- If terminal is too small, render a compact message: `"Window too small. Need at least WxH."`

## 4. File Organization

`Browse-Ideas.ps1` remains the executable entrypoint, but logic is split into helper files for testability.

Proposed layout:
- `ministry-of-future-plans/Browse-Ideas.ps1` (main loop and wiring only)
- `ministry-of-future-plans/common/IdeaDocCore.psm1` (parser + typed extraction)
- `ministry-of-future-plans/browser/Actions.ps1` (action creation helpers)
- `ministry-of-future-plans/browser/Reducer.ps1` (pure state transitions)
- `ministry-of-future-plans/browser/Layout.ps1` (layout calculation and clamping)
- `ministry-of-future-plans/browser/Filtering.ps1` (filter/sort/search helpers, including `Get-VisibleIdeaIds`)
- `ministry-of-future-plans/browser/Render.ps1` (frame generation + diff)
- `ministry-of-future-plans/browser/Input.ps1` (key reader and key-to-action mapping)

If we keep a single-file script initially, the same boundaries are preserved via clearly named regions/functions.

## 5. Implementation Phases

### Phase 0: Contracts, Safety, and Test Harness

Goals:
- Refactor `ConvertFrom-IdeaDoc` to return fully typed entries.
- Fix existing callers to work with the new typed output.
- Fix `Get-SectionPresence` API mismatch (add `StartIndex`/`EndIndex`).
- Add `ConvertFrom-TagString` helper to `IdeaDocCore.psm1`.
- Add capability probe.
- Establish testing framework and first unit tests.

Tasks:
1. Refactor `ConvertFrom-IdeaDoc` to parse all fields into typed entry objects (Priority, Effort, Risk, Tags, Captured, Origin, SuccessCriteria, Dependencies, Related).
2. Add `ConvertFrom-TagString` helper for tag parsing.
3. Fix `Get-SectionPresence` to return `StartIndex`/`EndIndex` alongside `Found`/`Items`.
4. Update `Analyze.ps1` to consume typed entries directly (remove inline field parsing, fix broken SourceDocuments stats at line 145).
5. Update `Validate.ps1` to consume typed entries where applicable.
6. Add parser unit tests: canonical entry parse, missing optional fields, malformed Tags, Origin extraction, Captured date parsing, edge cases.
7. Add a capability probe helper returning: host type, ANSI support, expected Unicode box-drawing support.
   - Verify required `[Console]` APIs (`ReadKey`, `SetCursorPosition`, `WindowWidth`, `WindowHeight`) before entering interactive mode.
8. Introduce Pester test bootstrap and test scripts for non-interactive helpers.

Exit criteria:
- `Analyze.ps1` and `Validate.ps1` produce correct output with the refactored parser.
- New typed parser tests pass.
- `ConvertFrom-TagString` tests cover empty brackets, trailing commas, whitespace, and valid input.

### Phase 1: MVP Browser (Navigation + Filtering)

Goals:
- Data on screen with deterministic navigation.
- Tag filtering and detail display.

Features:
- Three-pane layout: Tags, Ideas, Details.
- Keys: `Tab`, `Up/Down`, `Space`, `Q`.
- AND semantics for selected tags.
- Robust scroll behavior for long lists.
- Simple clear-and-redraw rendering.
- Key reader that normalizes raw input into action names.

Tasks:
1. Implement key reader with input normalization.
2. Implement `Get-VisibleIdeaIds` with filter/sort logic and AND tag semantics.
3. Implement reducer with cursor clamping invariants.
4. Implement simple redraw renderer.
   - Layout calculations use `[Console]::WindowWidth`/`WindowHeight` (not BufferWidth/BufferHeight) to avoid horizontal scroll behavior.
5. Wire main loop in `Browse-Ideas.ps1`.
6. Add reducer unit tests (pane switching, cursor clamping, tag toggle, derived list invalidation).
7. Add reducer sequence tests (multi-action scenarios testing state consistency).
8. Add filtering tests (AND semantics, empty filter, empty result set, sort stability).

Exit criteria:
- No cursor out-of-range errors under normal resize and navigation usage.
- Filter state and visible list remain consistent.
- Empty result set shows "No matching ideas" in detail pane.
- Resize events ignore transient invalid sizes (sanity guard before dispatching `Resize`).

### Phase 2: Usability and Robust Rendering

Features:
- Off-screen frame buffer with diff-based rendering.
- Color coding for Priority/Effort/Risk.
- Unicode box drawing (ASCII fallback via capability probe).
- Detail maximize mode (`Enter` maximize, `Esc` restore).
- Word wrapping with deterministic line splitting.
- Status bar with totals, filtered count, selected tag count, active sort/search mode.
- Resize action handling with full relayout and cursor clamp.

Exit criteria:
- No visual artifacts when toggling maximize, scrolling, and resizing repeatedly.

### Phase 3: Advanced Query Features

Features:
- Regex/text search mode (`/`).
- Sort cycling (`s`) by priority/risk/captured.
- Optional action helper (`m`) to emit selected-idea markdown snippet for reuse in plan docs.

Exit criteria:
- Search/sort/tag filter composition is deterministic and test-covered.

## 6. Testing Strategy

Use **Pester** for unit tests of pure/helper functions. Interactive loop testing remains minimal and pragmatic.
Module import in tests must be path-stable (relative to test file location), so tests do not depend on caller working directory.

Test categories:
1. Parser tests (`IdeaDocCore`):
   - Canonical entry parse (all fields present).
   - Missing optional fields (Dependencies, Related, Notes).
   - Malformed `Tags` field handling (empty brackets, no brackets, trailing commas).
   - Tag parsing variants: `[one, two]`, `[one,two]`, `[ one , two ]`, `[]`, and `one, two` (define whether strict-invalid or lenient parse).
   - Origin extraction correctness (SourceDoc, SourceSection, Captured).
   - `ConvertFrom-TagString` edge cases.
   - Typed entry field types (Tags is array, Captured is datetime or null).
2. Reducer tests:
   - Pane switching.
   - Cursor clamping at list boundaries.
   - Tag toggle and derived list invalidation.
   - Maximize/restore transitions.
   - Filter producing zero results (IdeaIndex, detail message).
   - Scroll clamping edge cases (`Index=Count-1` move down, `Index>=Count` after filter shrink).
3. Reducer sequence tests:
   - Multi-action scenarios (e.g., Initialize -> ToggleTag -> MoveDown -> ToggleTag -> verify state).
   - State consistency after interleaved navigation and filtering.
   - These are pure (no IO) and catch state corruption bugs that single-action tests miss.
4. Filtering/sort/search tests:
   - AND semantics for tags.
   - Empty filter shows all ideas.
   - Empty result set behavior.
   - Regex match and invalid regex fallback.
   - Stable sort tie-breakers (fall back to ID order).
5. Layout tests:
   - Many width/height combinations.
   - Non-negative dimensions.
   - Pane non-overlap.
   - Minimum-size fallback (e.g., width=10/height=10 yields explicit "TooSmall" layout mode).
6. Rendering helper tests:
   - Wrap logic.
   - Truncation/ellipsis logic.
   - Line-based frame diff correctness for changed lines (Phase 2).

Manual smoke tests (interactive):
- Start browser, navigate, filter, resize, maximize, quit.
- Validate no exceptions and legible redraw in supported terminals.

## 7. Blockers and Risks

### Blockers
1. **`Get-SectionPresence` API mismatch** — `Analyze.ps1` uses `.Start`/`.End` properties that don't exist. Must be fixed in Phase 0 before any exit gate can be trusted.
2. **Parser refactor caller migration** — `ConvertFrom-IdeaDoc` returning typed entries will break `Analyze.ps1` and `Validate.ps1` until they are updated. Must be done atomically in Phase 0.
3. **Terminal capability differences** across hosts may impact ANSI/Unicode behavior. Mitigated by capability probe.
4. **Pester availability** in environment (module install/setup) is required for automated tests.
5. **`[Console]` API availability** — `SetCursorPosition`, `ReadKey`, `WindowWidth`, and `WindowHeight` work in Windows Terminal but may fail silently in ISE or VS Code terminal. Capability probe must verify these.

### Risks
1. Large detail text can still be expensive to re-wrap each frame.
   - Mitigation: cache wrapped lines per selected idea and pane width.
2. Regex search can throw parse errors.
   - Mitigation: trap and surface status-bar error without terminating loop.
3. FutureIdeas format drift.
   - Mitigation: typed parser with strict validation + graceful fallback values for optional fields.
4. Render performance may degrade if per-cell diff is used in PowerShell.
   - Mitigation: line-based diff as default strategy.

## 8. Future Extensions

Ideas beyond the current plan scope, worth capturing for later consideration:

1. **Bookmark / pin ideas** — mark ideas as "interested" for a personal shortlist, persisted to a local file.
2. **Dependency graph view** — show `Related` and `Dependencies` as an ASCII DAG in the detail pane.
3. **Quick-add note** — append a timestamped note to an idea's `Notes:` field without opening an editor.
4. **Export filtered view** — export current filtered/sorted list as markdown table for planning meetings.
5. **Heatmap by captured date** — color tag/category counts by recency to spot "hot areas."
6. **Multi-document support** — browse ideas across multiple FutureIdeas files if the project grows.
7. **Help overlay (`?`)** — render an in-app keybinding reference modal.
8. **Clipboard export helper** — export selected idea snippet to clipboard with host-aware implementation (`Set-Clipboard`/`clip.exe` on Windows).

## 9. Task Summary

1. Fix `Get-SectionPresence` API and `Analyze.ps1` broken SourceDocuments stats.
2. Refactor `ConvertFrom-IdeaDoc` to return fully typed entries. Add `ConvertFrom-TagString`.
3. Update `Analyze.ps1` and `Validate.ps1` to consume typed entries.
4. Add parser, tag, and typed-entry unit tests.
5. Build browser action/reducer/layout/filter/render helpers.
6. Implement key reader with input normalization.
7. Implement main loop wiring in `Browse-Ideas.ps1`.
8. Add reducer unit tests and reducer sequence tests.
9. Add robust rendering (frame buffer) + resize + maximize behavior.
10. Add search/sort extension hooks.
11. Finalize with test pass and manual smoke verification.
