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

## Current implementation checkpoint — Increment 216

### Phase / subsystem
**Production boot repair follow-up — Planning viewport minimum-size propagation isolated; awaiting same-PR CI verification**

### Actual failure and corrected root cause
- Authoritative `Godot Headless Tests` run #241 confirms both Review / Return-to-map failures are fixed. The only remaining actual failure in `Player-facing vertical slice control contract test` is `Planning panel remains inside the rendered Deck viewport at 200 percent`.
- Run #241 disproved Increment 215's claim that converting the node named `PlanningPanel` directly into a `ScrollContainer` fully repaired the bound. The content became scrollable, and PrimaryAction stayed visible, but the outer PlanningPanel rectangle still exceeded the 640x400 logical viewport.
- The remaining cause is Godot Container minimum-size propagation: because `PlanningPanel` itself was the `ScrollContainer`, its large `PlanningContent` could still contribute to the scroll container's combined minimum size and therefore to the parent VBox allocation. Scrolling content does not by itself guarantee that the scroll viewport's own outer rectangle is bounded.
- Intentional corrupt-save JSON parse diagnostics remain expected recovery-fixture output and were not changed.

### Implemented in Increment 216
- Replaced the node named `PlanningPanel` with a vertically expanding plain `Control`, creating a genuine allocation boundary whose combined minimum size is independent of its oversized descendants.
- Added a full-rect child `PlanningScroll` inside that bounded panel. The existing `PlanningContent` VBox and all manifest, grid, status, semantic-focus, and support-status content remain inside this scroll container.
- Preserved vertical scrolling, disabled horizontal scrolling, and retained `follow_focus` so keyboard/controller focus keeps required controls visible.
- The parent VerticalSliceControl VBox now bounds PlanningPanel to its available height, while only PlanningContent grows beyond that height and scrolls internally.
- Did not change the test, 200% scale, text size, required content, PrimaryAction placement, gameplay, or frozen accessibility semantics.

### Validation / policy
- Re-read the maximum-scale Planning requirements in `PHASE11_UX_ACCESSIBILITY.md` and inspected the relevant minimum-size chain: root visible rect -> centered VerticalSliceControl -> plain bounded PlanningPanel -> full-rect PlanningScroll -> oversized PlanningContent.
- Verified structurally that the node asserted by the test is now the plain outer boundary, not the descendant ScrollContainer that receives PlanningContent's minimum size.
- Confirmed Review navigation repairs remain unchanged.
- Confirmed repository JSON still parses, all `content/contracts` documents declare `kind: contracts`, and campaign definitions cover C01–C48 exactly once.
- `git diff --check` passes.
- Local Godot 4.7.1 execution remains unavailable because this environment has no engine binary and blocks the pinned download with HTTP 403. Authoritative rectangle verification remains the next run on existing draft PR #1.

### Current phase state / blockers
- **12G remains IN PROGRESS and empirical validation must not continue yet.**
- Review navigation is verified fixed. The sole run-#241 PlanningPanel bound is repaired architecturally but awaits rendered same-PR verification.
- Phase 12H must not begin. This is not `IMPLEMENTATION COMPLETE = YES`.

### Canonical contradictions
- **NONE discovered.** The repair constrains the viewport rather than its accessible content.

## NEXT ACTION
Push this coherent repair to existing draft PR #1 and inspect the resulting `Godot Headless Tests` run:

1. Confirm at 1280x800/200% that the root visible rect encloses the VerticalSliceControl, bounded outer PlanningPanel, and PrimaryAction, while oversized PlanningContent scrolls inside PlanningScroll with focus-follow intact.
2. If the Player-facing vertical slice control contract passes, continue through all remaining headless cases and inspect the next authoritative first failure, if any.
3. Repair only directly evidenced failures without weakening tests or changing frozen gameplay/accessibility behavior until the complete `Godot Headless Tests` workflow is genuinely green.
4. Resume Phase 12G only after executable and suite verification is genuinely green; do not begin 12H while 12G is open.

Do not report overall completion until Phase 12G is genuinely closed, 12H is completed, and `IMPLEMENTATION COMPLETE = YES`.
