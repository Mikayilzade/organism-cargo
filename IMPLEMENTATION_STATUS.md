# IMPLEMENTATION STATUS

Branch: `main`

## Phase state
- 12A Vertical Slice: **COMPLETE**
- 12B Core Simulation Expansion: **COMPLETE**
- 12C Full Gameplay Systems: **COMPLETE**
- 12D Full Content Population: **COMPLETE**
- 12E UX / Accessibility / Controller / Deck: **COMPLETE**
- 12F Adversarial QA / Persistence / Recovery: **COMPLETE**
- 12G Empirical validation / platform polish: **IN PROGRESS — BLOCKED ON GENUINE EXTERNAL EVIDENCE**
- 12H Release Candidate: **NO**
- IMPLEMENTATION COMPLETE: **NO**

## Current implementation checkpoint — Increment 215

### Phase / subsystem
**Production boot repair follow-up — remaining Deck Planning overflow and fresh-review selection state repaired; awaiting same-PR CI verification**

### Actual failures and root causes
- Authoritative `Godot Headless Tests` run #240 confirms `CriticalSignalPresentationBuilder` and critical-signal acceptance now pass. `PrimaryAction` is also on-screen at 1280x800/200%.
- `Player-facing vertical slice control contract test` has three remaining failures: PlanningPanel still extends outside the maximum-scale viewport; a second review selects `retry` instead of expected `return_to_map` after two right moves; accepting it remains in `CAUSAL_REVIEW` instead of reaching `CAMPAIGN_MAP`.
- The Planning root is now centered correctly, but `PlanningPanel` is a plain `VBoxContainer`. Its manifest, hold grid, status, and Phase-12E semantic/support labels contribute their full combined minimum height to the panel, so the panel itself can exceed the 640x400 logical Deck viewport even though the fixed primary action remains visible.
- The two review failures share one state-lifecycle cause. `Phase12ENavigationSurface._selected_review_index` remains at Reset Contract (index 1) after leaving the first review. A second transit can complete directly through the flow before the navigation surface synchronizes, so the next right move starts from stale index 1 instead of a fresh review's safe Retry default at index 0.
- Temporary Codex return is distinct from a genuinely new review and must preserve the current review selection.
- Intentional corrupt-save JSON diagnostics remain expected recovery-test output and were not changed.

### Implemented in Increment 215
- Converted `PlanningPanel` into a vertically expandable `ScrollContainer` with horizontal scrolling disabled and focus-follow enabled; moved the existing planning widgets into a dedicated full-width `PlanningContent` VBox.
- Moved accessible semantic-focus and support-status labels into the same scrollable PlanningContent. Required Planning controls and rule text remain present, readable, focus reachable, and vertically scrollable rather than clipped, hidden, or shrunk.
- Added navigation-surface state tracking. Entry into a genuinely new Causal Review resets selection to safe-default Retry; return from Codex to the same review preserves selection.
- `review_move` and `review_activate_selected` synchronize entry state before using the selected index, covering direct flow completion before the first semantic review command.
- Did not change review actions, tests, UI scale, gameplay, accessibility requirements, or frozen semantics.

### Validation / policy
- Re-read `PHASE11_UX_ACCESSIBILITY.md`: required actions must remain reachable at maximum scale, Planning must remain fully operable, and wrapped rule content may scroll rather than clip.
- Inspected the full Planning minimum-size chain and verified the bounded outer node named `PlanningPanel` now owns scrollable content instead of inheriting the content's unbounded vertical extent.
- Traced both review sequences: new Transit -> Review resets to index 0; Review -> Codex -> same Review preserves the selected index; Reset -> Planning -> new Transit -> Review resets to index 0 before navigation.
- Confirmed repository JSON still parses, all `content/contracts` documents declare `kind: contracts`, and campaign definitions cover C01–C48 exactly once.
- `git diff --check` passes.
- Local Godot 4.7.1 execution remains unavailable because this environment has no engine binary and blocks the pinned download with HTTP 403. Authoritative rendered/state verification remains the next run on existing draft PR #1.

### Current phase state / blockers
- **12G remains IN PROGRESS and empirical validation must not continue yet.**
- All three known run-#240 failures are repaired. Full `Godot Headless Tests` green status awaits the same-PR rerun.
- Phase 12H must not begin. This is not `IMPLEMENTATION COMPLETE = YES`.

### Canonical contradictions
- **NONE discovered.** The changes implement the frozen maximum-scale reachability and safe fresh-review focus behavior.

## NEXT ACTION
Push this coherent repair to existing draft PR #1 and inspect the resulting `Godot Headless Tests` run:

1. Confirm the bounded `PlanningPanel` rectangle is enclosed at 1280x800/200%, required Planning content remains focus-reachable through its scroll container, and the Player-facing control layout assertion passes.
2. Confirm every genuinely new Causal Review defaults to Retry, two right moves select Return to map, acceptance reaches Campaign Map, and Codex round-trips preserve same-review selection.
3. If another first failure appears, inspect its exact complete Godot output and repair only that directly related defect without weakening tests or changing frozen gameplay/accessibility behavior.
4. Continue through the blocker chain until the complete `Godot Headless Tests` workflow is genuinely green.
5. Resume Phase 12G only after executable and suite verification is genuinely green; do not begin 12H while 12G is open.

Do not report overall completion until Phase 12G is genuinely closed, 12H is completed, and `IMPLEMENTATION COMPLETE = YES`.
