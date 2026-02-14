# Future Ideas Backlog

Canonical backlog of deferred work, enhancements, and speculative features.
Maintained via the procedure in [Instruction.HarvestFutureIdeas.md](../Instruction.HarvestFutureIdeas.md).

## Taxonomy

| TopLevel     | SubLevel     | Description                                              |
|--------------|--------------|----------------------------------------------------------|
| Architecture | DataModel    | State model and update granularity improvements          |
| Architecture | Rendering    | Terminal rendering pipeline and performance enhancements |
| Tooling      | Export       | Output and sharing helpers                              |
| UX           | Interaction  | Interactive browser usability features                  |

## Architecture

### DataModel

#### [FI-Architecture-DataModel-0001] Partial Frame Rebuild by State Delta
Status: Candidate
TopLevel: Architecture
SubLevel: DataModel
Priority: P2
Effort: L
Risk: M
Origin:
- SourceDoc: OffScreenFrameBuffer.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [rendering, state, optimization]
Summary: Rebuild only rows affected by specific state changes instead of rebuilding the full frame each cycle.
Rationale: This can reduce CPU and allocation cost for high-frequency navigation workloads.
SuccessCriteria:
- Build pipeline can skip untouched rows when only cursor state changes.
- Tests verify identical visual output compared to full-frame rebuild for equivalent state transitions.
Dependencies: []
Related: [FI-Architecture-Rendering-0002, FI-Architecture-Rendering-0005]

### Rendering

#### [FI-Architecture-Rendering-0001] ANSI Stream Row Flush
Status: Candidate
TopLevel: Architecture
SubLevel: Rendering
Priority: P2
Effort: M
Risk: M
Origin:
- SourceDoc: OffScreenFrameBuffer.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [rendering, ansi, performance]
Summary: Replace per-segment `Write-Host` calls with a single ANSI string write per changed row.
Rationale: Fewer host calls should reduce flush latency and improve responsiveness under rapid updates.
SuccessCriteria:
- Changed rows are rendered through one console write operation per row.
- Manual smoke test shows lower perceived lag during sustained key-repeat navigation.
Dependencies: []
Related: [FI-Architecture-Rendering-0002]

#### [FI-Architecture-Rendering-0002] Cell-Level Dirty Tracking
Status: Candidate
TopLevel: Architecture
SubLevel: Rendering
Priority: P3
Effort: L
Risk: M
Origin:
- SourceDoc: OffScreenFrameBuffer.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [rendering, diff, optimization]
Summary: Track dirty cells within changed rows and rewrite only the cells that differ.
Rationale: This may reduce write volume further for cursor-only moves where most row content is unchanged.
SuccessCriteria:
- Diff engine can identify changed cell ranges for at least cursor-move scenarios.
- Regression tests show visual parity with row-level diff output.
Dependencies: []
Related: [FI-Architecture-Rendering-0001, FI-Architecture-DataModel-0001]

#### [FI-Architecture-Rendering-0003] Alternate Screen Buffer Mode
Status: Candidate
TopLevel: Architecture
SubLevel: Rendering
Priority: P2
Effort: M
Risk: M
Origin:
- SourceDoc: OffScreenFrameBuffer.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [rendering, terminal, ux]
Summary: Enter the terminal alternate screen buffer on browser start and restore main buffer on exit.
Rationale: This preserves user scrollback and isolates browser rendering from normal shell output.
SuccessCriteria:
- Browser entry switches to alternate screen on supported terminals.
- Exiting browser restores prior shell content without artifacts.
Dependencies: []
Related: [FI-UX-Interaction-0005]

#### [FI-Architecture-Rendering-0004] Frame Object Pooling
Status: Candidate
TopLevel: Architecture
SubLevel: Rendering
Priority: P3
Effort: M
Risk: M
Origin:
- SourceDoc: OffScreenFrameBuffer.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [rendering, gc, performance]
Summary: Reuse frame row and segment objects across renders to reduce short-lived allocations.
Rationale: Lower allocation pressure can help keep interactive behavior smooth under sustained input.
SuccessCriteria:
- Frame construction path reuses pooled objects without leaking stale data.
- Profiling shows reduced allocation count compared to baseline full-allocation path.
Dependencies: []
Related: [FI-Architecture-DataModel-0001]

#### [FI-Architecture-Rendering-0005] Unicode and ANSI Capability Probe
Status: Candidate
TopLevel: Architecture
SubLevel: Rendering
Priority: P1
Effort: M
Risk: L
Origin:
- SourceDoc: Plan.FutureIdeasBrowser.md
- SourceSection: 3.6 Rendering Strategy
- Captured: 2026-02-14
Tags: [rendering, compatibility, robustness]
Summary: Add explicit capability probing for ANSI sequences and Unicode box-drawing support, with deterministic fallback behavior.
Rationale: Host capability variance is a known risk and should be handled before advanced rendering features are enabled.
SuccessCriteria:
- Browser detects terminal capabilities at startup and records the mode in runtime state.
- Unsupported terminals fall back to compatible rendering without runtime exceptions.
Dependencies: []
Related: [FI-Architecture-Rendering-0003]

## Tooling

### Export

#### [FI-Tooling-Export-0001] Export Filtered View as Markdown Table
Status: Candidate
TopLevel: Tooling
SubLevel: Export
Priority: P2
Effort: S
Risk: L
Origin:
- SourceDoc: Plan.FutureIdeasBrowser.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [export, workflow, planning]
Summary: Provide a command to export the currently filtered and sorted idea list as a markdown table.
Rationale: This supports planning meetings and sharing without manual copy/paste formatting.
SuccessCriteria:
- Command emits a markdown table reflecting current filter and sort state.
- Export output includes ID and title columns at minimum.
Dependencies: []
Related: []

#### [FI-Tooling-Export-0002] Clipboard Export for Selected Idea
Status: Candidate
TopLevel: Tooling
SubLevel: Export
Priority: P2
Effort: S
Risk: L
Origin:
- SourceDoc: Plan.FutureIdeasBrowser.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [clipboard, export, workflow]
Summary: Add a host-aware action to copy a selected idea snippet to the clipboard.
Rationale: Faster transfer of structured idea data into plan docs improves iteration speed.
SuccessCriteria:
- Browser command copies selected idea summary text to clipboard on supported hosts.
- Unsupported hosts show a clear non-fatal message in status area.
Dependencies: []
Related: [FI-Tooling-Export-0001]

## UX

### Interaction

#### [FI-UX-Interaction-0001] Bookmark and Pin Ideas
Status: Candidate
TopLevel: UX
SubLevel: Interaction
Priority: P2
Effort: M
Risk: L
Origin:
- SourceDoc: Plan.FutureIdeasBrowser.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [ux, shortlist, persistence]
Summary: Allow users to mark ideas as bookmarked and maintain a local shortlist.
Rationale: A shortlist improves triage workflows when reviewing many candidate ideas.
SuccessCriteria:
- Users can toggle bookmark status from the browser UI.
- Bookmarked ideas can be listed or filtered independently from the full set.
Dependencies: []
Related: []

#### [FI-UX-Interaction-0002] Dependency Graph View
Status: Candidate
TopLevel: UX
SubLevel: Interaction
Priority: P2
Effort: L
Risk: M
Origin:
- SourceDoc: Plan.FutureIdeasBrowser.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [ux, dependencies, visualization]
Summary: Add an ASCII graph view showing relationships from `Dependencies` and `Related` fields.
Rationale: Visual relationship mapping helps identify sequencing and coupling between ideas.
SuccessCriteria:
- Detail view can render a readable dependency graph for entries with relationship metadata.
- Graph rendering degrades gracefully when relationship fields are empty.
Dependencies: []
Related: []

#### [FI-UX-Interaction-0003] Quick Add Timestamped Note
Status: Candidate
TopLevel: UX
SubLevel: Interaction
Priority: P3
Effort: M
Risk: M
Origin:
- SourceDoc: Plan.FutureIdeasBrowser.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [ux, notes, editing]
Summary: Add a quick command to append a timestamped note to the selected idea without leaving the browser.
Rationale: Capturing context during review is valuable and currently requires manual document editing.
SuccessCriteria:
- Command appends a timestamped note under the selected entry in the idea document.
- Validation still passes after note insertion.
Dependencies: []
Related: []

#### [FI-UX-Interaction-0004] Help Overlay for Keybindings
Status: Candidate
TopLevel: UX
SubLevel: Interaction
Priority: P2
Effort: S
Risk: L
Origin:
- SourceDoc: Plan.FutureIdeasBrowser.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [ux, discoverability, keybindings]
Summary: Add an in-app help overlay that lists keybindings and modes.
Rationale: This reduces onboarding friction and makes non-obvious actions discoverable.
SuccessCriteria:
- Pressing `?` toggles a modal help overlay.
- Overlay content includes all active keybindings and exits cleanly back to prior state.
Dependencies: []
Related: []

#### [FI-UX-Interaction-0005] Multi-Document Idea Browser
Status: Candidate
TopLevel: UX
SubLevel: Interaction
Priority: P2
Effort: L
Risk: M
Origin:
- SourceDoc: Plan.FutureIdeasBrowser.md
- SourceSection: Future Extensions
- Captured: 2026-02-14
Tags: [ux, multi-source, scalability]
Summary: Support browsing ideas from multiple `FutureIdeas.md` files in one session.
Rationale: Cross-document browsing becomes necessary as backlog data grows across modules.
SuccessCriteria:
- Browser can load and display entries from more than one idea document path.
- Entries preserve source-document identity in list or detail view.
Dependencies: []
Related: [FI-Architecture-Rendering-0003]
