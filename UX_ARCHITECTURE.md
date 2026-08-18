# ORGANISM CARGO — UX / PRESENTATION ARCHITECTURE

Status: **CANONICAL PHASE 6 — UX / PRESENTATION ARCHITECTURE LOCKED**
Last updated: 2026-08-15

This file defines the player-facing state flow, controls, layout, transit presentation, causal review, onboarding, visual/audio language, accessibility, device boundaries, settings, edge cases, and Phase-6 acceptance criteria for **Organism Cargo**.

This file does not alter simulation authority. `MECHANICS.md` remains canonical for transit logic and `DECISION_ARCHITECTURE.md` remains canonical for action legality, previews, supports, scoring, uncertainty, and contract predicates. Visuals, animation, input timing, camera behavior, playback speed, and UI feedback may never change authoritative simulation outcomes.

---

# 1. UX objectives

The UX must make the game feel like operating a compact living transport system rather than manipulating abstract puzzle tokens.

The interface must accomplish five things simultaneously:

1. **Planning is frictionless.** Moving, rotating, inspecting, undoing, comparing, and trying alternatives must feel immediate and non-punitive.
2. **Rules are readable before commitment without solving the puzzle.** The player sees facts and immediate influence, but not a future-simulation oracle.
3. **Transit is dramatic but deterministic.** The player can understand that the hold is evolving while animation remains subordinate to discrete ticks.
4. **Failure produces a usable explanation.** The causal-review screen must turn a failed run into a concrete hypothesis for the next attempt.
5. **The whole game remains compact.** No screen should create the impression of a ship-management sim, logistics empire, creature-care game, or spreadsheet tool.

The central UX rhythm is:

**read → arrange → verify → commit → observe → explain → revise**.

---

# 2. Complete player-facing state flow

## 2.1 Boot

Sequence:
1. studio/logo splash, skippable after first frame;
2. accessibility safety preflight on first launch only;
3. title screen.

First-launch safety preflight offers only high-impact options:
- text/UI scale;
- reduced flashing;
- reduced motion;
- master volume;
- subtitle/caption mode for non-speech audio cues;
- input method detection.

All can be changed later.

## 2.2 Main menu

Primary entries:
- Continue;
- Campaign;
- Challenges;
- Codex;
- Settings;
- Credits;
- Quit.

Rules:
- `Continue` resumes the most recent safe state, normally planning for the current contract or the campaign map.
- If the user quit during transit, Continue returns to the exact committed run in paused playback if persistence supports that state; if Phase 8 chooses snapshot-only transit persistence, Continue reconstructs the committed transit deterministically to the saved tick and pauses there.
- The main menu never auto-launches a contract.

## 2.3 Campaign map / contract select

The campaign is presented as a compact route board, not a free-roaming world.

Each contract node shows:
- contract name;
- chapter;
- hold silhouette;
- manifest summary;
- route-hazard icons;
- best medal earned;
- new-rule / discovery marker when applicable;
- completion state;
- optional mastery marker.

Selecting a node opens a contract brief.

## 2.4 Contract brief

The brief contains:
- short one- or two-sentence flavor premise;
- mandatory delivery conditions;
- optional Bronze/Silver/Gold conditions where applicable;
- manifest cards;
- hold preview;
- known route timeline;
- available support allowance;
- unknown-information markers;
- first-time lesson cue if this contract teaches a rule.

Actions:
- `Plan Cargo`;
- `Back`;
- `Codex` filtered to relevant known entries.

The brief does not reveal a recommended layout.

## 2.5 Planning

Planning is the primary interactive screen and the player's home during a contract.

Player actions:
- drag/drop organisms;
- rotate legal body plans;
- install/remove supports;
- set support priority/link where applicable;
- inspect organisms/cells/supports/hazards/objectives;
- toggle overlays;
- undo/redo;
- reset to initial contract setup;
- compare with last launch after an attempt;
- launch when structurally valid.

No real-time pressure exists.

## 2.6 Launch confirmation

Launch is a deliberate commitment because transit forbids rearrangement.

If there are no warnings, clicking Launch opens a compact confirmation strip:
- `Commit this arrangement?`;
- route length / tick count;
- unresolved unknown-information marker if relevant;
- `Launch` / `Cancel`.

If known warnings exist, the strip also lists up to three highest-priority warnings, such as:
- known blocked growth footprint;
- organism already inside a dangerous current influence;
- support will lose power during a known brownout under current priority;
- optional medal already impossible at time zero.

Warnings never convert a legal plan into an invalid plan.

The player may choose `Launch anyway`.

## 2.7 Transit playback

Transit begins from the committed time-zero state.

The player cannot change:
- positions;
- orientation;
- support links;
- support priority;
- route sequence;
- simulation speed in a way that changes authority.

The player may:
- pause playback;
- change playback speed;
- step one authoritative tick while paused;
- inspect entities and cells;
- toggle selected presentation overlays;
- open a compact event feed;
- skip to completion only after the first authored tutorial contract has taught transit reading.

No rewind changes the run. Rewind/scrub is review-only after authoritative completion or fail-fast.

## 2.8 Transit completion / fail-fast

When the run ends:
1. playback pauses on final authoritative state;
2. a result ribbon appears: `Delivered`, `Condition failed`, or contract-specific equivalent;
3. the game highlights the first decisive failed predicate or confirms success;
4. user enters Causal Review.

The player is not immediately thrown back to planning.

## 2.9 Causal Review

This is a full contract state, not a modal pop-up.

The review supports:
- timeline scrub;
- event grouping;
- jump to first failed condition;
- jump to first cause;
- organism focus;
- cell/zone focus;
- direct vs propagated effect distinction;
- compare start vs final state;
- medal breakdown;
- `Retry from last launch`;
- `Reset contract`;
- `Return to map` after success or deliberate abandon.

## 2.10 Successful completion

After a successful run:
- mandatory predicate success is shown first;
- medal conditions are scored second;
- new codex entries/unlocks appear as compact cards;
- next unlocked contract(s) appear.

Actions:
- Continue;
- Retry for medal;
- Review timeline;
- Return to map.

Unlock presentation must not interrupt causal review until the player requests completion flow.

## 2.11 Recoverable failure

Failure defaults to:
- Review;
- Retry from last launch.

The exact committed layout becomes the new planning baseline. The game visually marks changed cells/entities only after the user edits them, enabling targeted hypothesis testing.

## 2.12 Campaign completion

After the final authored contract:
- brief completion vignette/summary;
- total campaign medal summary;
- unlock generated/mastery challenges if not already available;
- no forced New Game+ system.

Campaign completion returns to the map with all completed nodes still replayable.

---

# 3. Mouse-first controls

## 3.1 Pointer conventions

Left mouse:
- select;
- drag;
- place;
- activate primary button;
- scrub timeline;
- select overlay target.

Right mouse:
- open contextual inspection shortcut on entity/cell;
- cancel current drag/link assignment;
- close non-blocking inspector subpanel.

Mouse wheel:
- scroll lists/panels;
- optional hold zoom only within bounded range if needed for accessibility; default full hold remains visible.

Middle mouse:
- not required for any mandatory action.

## 3.2 Drag/drop

Organism drag behavior:
1. press on organism card or placed organism;
2. lift visually after small threshold to prevent accidental drags;
3. show footprint ghost under cursor;
4. legal target cells glow with neutral valid contour;
5. illegal target cells show reason-specific icon/color pattern;
6. release on legal target commits placement;
7. release on illegal target returns entity to prior valid state;
8. dragging out of hold toward manifest tray removes placed organism to tray.

No placement is lost because the cursor crosses an illegal region.

## 3.3 Rotation

Primary shortcut: `R` rotates selected/dragged entity to next unique legal orientation.

Secondary UI:
- rotate-left / rotate-right buttons beside inspector when relevant;
- optional mouse-wheel + modifier disabled by default to avoid accidental rotation.

If rotation would make current placement illegal, the preview shows the rotated footprint but does not commit until a legal anchor exists.

## 3.4 Inspection

Single click selects.

Double click or `I` opens pinned inspector mode if desired.

Hover card/board entity provides a concise tooltip only. Full rule text belongs in the inspector to avoid tooltip walls.

## 3.5 Overlays

Keyboard defaults:
- `1` Heat;
- `2` Stress field;
- `3` Contamination;
- `4` Feeding / compatibility;
- `5` Symbiosis / support links;
- `6` Growth preview;
- `0` Clear overlays.

`Tab` cycles the most recently used overlay set.

Only one environmental full-board heatmap is primary at a time. Relationship overlays may coexist with a selected organism.

## 3.6 Undo / redo

- `Ctrl+Z` undo;
- `Ctrl+Y` redo;
- also visible buttons in planning toolbar.

Undo/redo buttons show disabled state with tooltip explaining launch clears history.

## 3.7 Reset

- `Backspace` opens reset menu only when not typing/searching;
- toolbar button labeled `Reset`.

Choices:
- Reset to last launch;
- Reset contract.

Both require confirmation only if current planning differs from recoverable baseline.

## 3.8 Launch

- `Space` focuses Launch when planning state is structurally valid;
- second `Space` confirms only if the launch confirmation strip has focus;
- mouse click always available.

No single accidental key press can launch a layout.

## 3.9 Transit playback controls

Defaults:
- `Space` pause/play;
- `.` step one tick while paused;
- `1x`, `2x`, `4x` speed buttons;
- keyboard `[` slower, `]` faster;
- `Home` jump visual focus to tick 0 in review only;
- arrow keys move one tick in review only.

Base allowed live playback speeds:
- 0.5x;
- 1x;
- 2x;
- 4x.

Tutorial transit may temporarily cap max speed at 2x until event-reading is taught.

## 3.10 Post-run navigation

Default shortcuts:
- `Enter` retry from last launch when failure review is active;
- `Esc` backs out one UX layer but never discards planning edits without confirmation;
- `C` toggles compare start/final in review;
- `F` jumps to first failed predicate;
- `J` jumps to selected event's direct cause.

All shortcuts must be remappable where practical.

---

# 4. Planning-screen layout

The authoritative default layout targets 16:9 at 1920x1080 but must scale safely down to 1280x720.

## 4.1 Central hold

The hold occupies approximately 55–65% of usable screen area.

Requirements:
- full usable grid visible by default;
- blocked cells and fixtures legible without overlay;
- zone boundaries subtle until relevant;
- organism silhouettes readable at normal scale;
- future-growth ghosts visible only on selection/overlay;
- hold never scrolls under ordinary launch sizes.

## 4.2 Left manifest tray

Contains mandatory organisms and cargo-cell supports not yet placed.

Each organism card shows:
- silhouette;
- species name;
- body footprint icon;
- primary current state;
- 1–3 trait-family icons;
- warning badge if current contract gives special restriction/unknown information.

Placed organisms remain represented in tray as dimmed cards with a board-locate button rather than disappearing completely.

## 4.3 Right inspector

Context-sensitive panel for:
- selected organism;
- support;
- cell/zone;
- route hazard;
- objective.

Organism inspector hierarchy:
1. name + silhouette + body stage;
2. mandatory delivery requirements;
3. current primary state + condition flags;
4. internal meters as labeled bars with numeric values when known;
5. trait cards;
6. compatibility/current influence summary;
7. future growth preview control if applicable;
8. codex link.

Trait cards use one-line summary first; expansion reveals exact documented arithmetic/range.

## 4.4 Top route timeline

Persistent compact timeline with ticks grouped into route phases.

Displays:
- current tick during transit;
- known hazard windows;
- unknown bounded segments as striped/hatched regions;
- brownout windows;
- zone-specific hazard markers.

Hover/click opens detail without covering the hold.

## 4.5 Bottom objective / support strip

Left section:
- mandatory objectives;
- current plan-independent status labels such as `must arrive CALM`, `contamination <= 4`.

Middle section:
- support allowance inventory;
- installed support count;
- power usage `used / capacity`;
- brownout priority button if relevant.

Right section:
- undo;
- redo;
- reset;
- overlays;
- Launch.

## 4.6 Launch status

Launch button states:
- disabled `Manifest incomplete`;
- disabled `Illegal placement`;
- disabled `Power exceeded`;
- enabled normal;
- enabled with warning dot.

Hovering disabled launch always names the exact blocking reason(s).

Warnings are yellow/hatched and non-blocking. Invalidity is red/crossed and blocking. These semantics must never swap.

---

# 5. Information hierarchy and anti-spreadsheet rules

The player may access exact rules, but not all at once.

The hierarchy is:
1. silhouette/posture/effect;
2. state icon;
3. concise label;
4. meter/relationship highlight;
5. exact numeric rule on inspection;
6. historical event detail in review.

Rules:
- no persistent table listing every organism meter simultaneously;
- no default full-board numeric channel labels;
- no dependency graph rendered across the entire hold;
- no more than three simultaneous relationship-line styles;
- selected-object focus may reveal more detail than the global board;
- exact numbers appear on demand, not as wallpaper.

---

# 6. Transit presentation

## 6.1 Tick-to-animation contract

Simulation authority resolves one complete tick before its animation package plays.

Visual sequence per tick:
1. route hazard cue begins;
2. environment field changes animate;
3. direct interactions animate;
4. meter/state changes animate;
5. state-entry pulses/consequences animate;
6. end-of-tick objective alerts update.

Animation may overlap cosmetically but cannot delay or alter the next authoritative tick's state.

At normal 1x speed, a tick should usually occupy roughly 0.6–1.0 seconds of presentation depending event density. At 4x, low-priority animations collapse while state changes remain legible.

## 6.2 Event emphasis

Events have presentation priority:
- P0: contract fail/success decisive event;
- P1: primary-state transition, CRITICAL, growth, support power loss, contamination threshold;
- P2: feeding, soothing, source/sink activation, route hazard onset;
- P3: routine per-tick environmental drift.

At high speed, P3 can be visually compressed; P0/P1 must remain visible through persistent markers.

## 6.3 State-change readability

Examples:
- CALM → AGITATED: posture tightens + state icon edge pulse;
- AGITATED → PANICKED: stronger posture/emission pulse + distinct warning shape;
- sleep: body folds/dims + moon-like non-color icon;
- contaminated: mottled overlay + contamination badge;
- growth: footprint ghost flashes before authoritative transition animation, then new cells fill;
- growth blocked: attempted footprint outline appears with blocked-cell hatch, then organism receives flag;
- support brownout: cable/fixture loses pulse, support icon becomes slashed-power state.

## 6.4 Environmental overlays in transit

Default transit shows subtle diegetic cues rather than full heatmaps.

Player may toggle full overlays:
- heat: cell wash + rising-wave texture;
- stress: directional ripple/noise texture;
- contamination: particulate/mottled residue texture.

Color is supplemental. Each channel has unique shape/motion/pattern language.

## 6.5 Pause

Pause freezes presentation immediately after current frame while authoritative state remains at the latest completed tick.

The game never pauses halfway through an authoritative phase.

If user presses pause during a tick animation, the visual animation freezes, but inspection labels must identify the authoritative tick whose resolved state is being shown.

## 6.6 Skip to completion

Available after onboarding threshold.

When used:
- remaining authoritative ticks simulate deterministically without full animation;
- result opens in review;
- timeline contains full event history;
- first decisive failure is still emphasized.

Skipping cannot change scoring.

---

# 7. Causal-review UX

Causal Review is designed to answer **what happened first, what propagated, and what to change next**.

## 7.1 Layout

Center:
- hold at selected historical tick.

Top:
- scrub timeline with event density markers.

Left:
- grouped event feed.

Right:
- selected organism/cell event details + predicate status.

Bottom:
- start/final compare;
- retry;
- reset;
- return.

## 7.2 Event grouping

Events are grouped by authoritative tick and then by causal family:
- Route;
- Environment;
- Interaction;
- Internal meter;
- State transition;
- Consequence;
- Objective.

Collapsed group example:
`Tick 7 — 6 events: heat surge → 2 stress increases → Pulse Mite panicked → heat pulse → Glass Larva critical`.

Expanding shows exact records.

## 7.3 Direct vs propagated effects

Every selected event labels its role:
- **Trigger** — exogenous route/support/state entry event;
- **Direct effect** — immediately caused by selected source;
- **Propagated effect** — consequence one or more causal steps later;
- **Predicate failure** — contract condition violated.

Use solid connector for direct selected cause and dashed connector for propagated chain. Never render all causal lines globally.

## 7.4 Jump to cause

For any P0/P1 event:
- `Why?` button selects immediate causal event;
- repeated use walks backward through causal chain;
- `Root trigger` jumps to first external or earlier-state cause available in recorded history.

If multiple additive causes contributed, the detail panel lists contributors ranked by absolute contribution, but does not falsely name one as sole cause.

## 7.5 First decisive failure

On a failed run the review initially selects:
1. first irreversible mandatory-predicate failure, if any;
2. otherwise final failed predicate;
3. and highlights its earliest causal ancestor.

This gives the player a starting point without recommending a solution.

## 7.6 Start/final comparison

Toggle shows:
- ghosted time-zero footprint vs final footprint;
- state icon before/after;
- objective values before/after;
- support on/off changes;
- contamination/heat/stress-field selected-channel delta.

No full automatic “solution difference” is displayed.

## 7.7 Retry-from-last-launch

Default retry action:
1. exits review;
2. reconstructs exact committed time-zero layout;
3. marks all pieces as unchanged;
4. first player edit marks affected piece/cell as modified;
5. optional `Show last result hotspot` highlights only the selected failed entity/cause, not a suggested destination.

---

# 8. First 10 contracts onboarding

These ten contracts are both campaign opening and public-demo spine. Exact species/hazards are from Phase 5 content set; difficulty values remain balance-tunable.

## Contract 1 — First Hold
Teaches:
- select;
- drag/drop;
- legal vs illegal placement;
- manifest completion;
- Launch commitment;
- simple transit playback.

Content:
- simple fixed-footprint organisms;
- one readable source/sink relationship;
- no route hazard;
- no support.

Scaffolding:
- illegal reason callout remains persistent;
- Launch blocked until mandatory organisms placed;
- no medal pressure.

Demonstration gate:
- player must place at least one organism twice or inspect its trait before Launch prompt becomes highlighted.

## Contract 2 — Too Warm
Teaches:
- heat overlay;
- source vs sink;
- local environmental range;
- exact current-state contribution.

Content example:
- Ember Pod + Frost Finch.

Scaffolding removal:
- overlay hotkey hint fades after first use;
- full-screen tutorial card never repeats.

## Contract 3 — Keep Them Calm
Teaches:
- internal stress vs stress field distinction;
- Hushling/soothing;
- CALM/AGITATED/PANICKED states;
- causal event feed.

Demonstration gate:
- player must select an organism and view state thresholds once before launch confirmation tutorial closes permanently.

## Contract 4 — Dirty Air
Teaches:
- contamination channel;
- source vs filter feeder;
- persistence across ticks;
- contamination load vs cell contamination.

Content:
- Spore Bell + Mire Sipper or Silt Grazer.

## Contract 5 — Route Event
Teaches:
- route timeline;
- hazard window;
- zone marker;
- planning around future known input without future auto-simulation.

Content:
- simple thermal surge or contamination leak.

Scaffolding:
- timeline hazard pulses once on contract entry.

## Contract 6 — Support Space
Teaches:
- support allowance;
- cargo-cell support cost;
- Feed Cartridge or Baffle;
- support placement legality.

Demonstration gate:
- install then remove/reposition one support, or inspect its opportunity cost.

## Contract 7 — Growth Needs Space
Teaches:
- future-growth ghost;
- growth direction/orientation;
- known blocked-growth warning is non-blocking;
- review of growth-blocked failure.

Content:
- Glass Larva or Silt Grazer.

This contract intentionally allows the player to launch a predictably blocked arrangement so causal review can teach the loop.

## Contract 8 — Power Priority
Teaches:
- utility support;
- power capacity;
- known brownout;
- support priority ordering.

Scaffolding:
- priority panel opens automatically once, then remains user-invoked.

## Contract 9 — Discovery Cargo
Teaches:
- bounded unknown information;
- unknown marker semantics;
- discovery cue vs tutorial cue;
- evidence learned from actual transit.

Rules:
- no hidden random behavior;
- unknown is bounded to one documented family/range;
- player is not told what conclusion to draw.

## Contract 10 — Living Manifest
Demo-closing synthesis:
- growth timing;
- route hazard;
- support tradeoff;
- at least three interacting known species;
- no new fundamental rule during transit.

The player must demonstrate:
- reading route timeline;
- using at least one influence overlay;
- making a valid future-space plan;
- recovering from one plausible failed run or completing directly.

Onboarding after Contract 10 becomes contextual only. No mandatory full-screen tutorial cards remain.

---

# 9. Tutorial cues vs discovery cues

Tutorial cue means **the system rule is known and the game is teaching interface interpretation**.

Visual:
- clean instructional frame;
- direct language: `Heat spreads from this source`;
- may point to exact UI control;
- dismissible after demonstration.

Discovery cue means **the player is intentionally missing bounded information**.

Visual:
- striped/question-mark motif;
- language: `This trait belongs to the contamination family, but its trigger is undocumented`;
- never points to a correct placement;
- after observation, codex updates with evidence or confirmed rule as authored by content progression.

Discovery styling must never resemble an error/missing-data state.

---

# 10. Visual language

## 10.1 Body plans

Each of the four body plans has a strong shape identity independent of species texture:
- B01 Dot: compact one-cell rounded body;
- B02 Domino: elongated two-cell body with clear head/orientation notch where relevant;
- B03 Corner: L-shaped three-cell body with visible joint;
- B04 Bar: linear multi-cell body with directional segmentation.

Silhouette remains readable in grayscale.

## 10.2 Primary behavioral states

State communicates through posture + icon + optional color:
- CALM: open/neutral posture, circular icon;
- AGITATED: tense posture, zig/chevron icon;
- PANICKED: expanded/shaking posture, burst icon;
- ASLEEP: folded posture, crescent/closed-eye icon.

## 10.3 Condition flags

- CONTAMINATED: mottled/spore texture badge;
- CRITICAL: heavy outlined cross/diamond alert badge;
- GROWTH_BLOCKED: footprint/block icon;
- DELIVERY_FAILED: contract-stamp icon in review only.

No condition relies on color alone.

## 10.4 Environmental channels

Heat:
- warm gradient where color available;
- rising-wave texture;
- heat shimmer at high intensity.

Stress field:
- sharp concentric ripple / vibration lines;
- angular pulse glyph.

Contamination:
- particulate dots / speckled tile texture;
- lingering residue animation.

## 10.5 Feeding and symbiosis

Feeding edge:
- dotted flow line with small directional bite/food glyph;
- only shown for selected/hovered source/consumer or feeding overlay.

Symbiosis edge:
- paired bracket/link shape;
- benefit channel icon attached.

Support links:
- mechanical cable/beam visual distinct from organism relationships.

## 10.6 Growth preview

Known next footprint:
- translucent hatched cells;
- arrow from current growth origin;
- blocked future cell shows crosshatch, not red-only fill.

The preview is labeled `Next documented footprint`, never `Will grow here` unless growth trigger is already certain at current state and wording is technically accurate.

## 10.7 Route zones/hazards

Zones use subtle boundary pattern + letter/symbol.

Hazards use:
- timeline icon;
- matching zone icon;
- optional brief hold-border pulse when active.

## 10.8 Unknown information

Unknown facts use a consistent `bounded unknown` motif:
- striped card edge;
- `?` badge;
- family icon remains visible if family is known;
- exact unknown value hidden.

## 10.9 Medal predicates

Mandatory:
- shield/check icon.

Bronze/Silver/Gold optional predicates:
- distinct medal shapes in addition to metallic colors;
- textual requirement always inspectable.

---

# 11. Art-direction production grammar

The art system must support 22 species without 22 bespoke animation pipelines.

## 11.1 Reusable construction layers

Each species visual is built from:
1. one of 4 body-plan rigs/silhouette bases;
2. species-specific primary contour modifications within rig limits;
3. palette/pattern material set;
4. up to two decorative attachments;
5. trait-state effect emitters;
6. shared behavioral animation set;
7. optional lifecycle morph between already supported body-plan stages.

## 11.2 Shared animation ceiling

Foundation behavioral animations per body plan:
- idle calm;
- agitated;
- panicked;
- sleep/awake transition;
- asleep loop;
- feed/consume;
- receive soothing/buffer;
- contamination reaction;
- critical;
- growth/maturation transition where body plan supports it;
- generic reactive pulse/emission.

Species may customize timing/amplitude but should not require bespoke animation logic.

## 11.3 Asset ceilings

Launch ceiling:
- 4 base body rigs;
- <= 12 core reusable animation clips per body plan;
- <= 2 custom decorative attachment meshes/sprites per species;
- <= 2 cosmetic flavor variants per species, optional;
- trait VFX built from <= 12 reusable effect families;
- no species requires unique skeletal topology unless approved by scope review.

## 11.4 Intentional-not-generated look

Even if tooling uses AI assistance internally, the shipped asset set must be art-directed and consistent:
- fixed silhouette grammar;
- fixed material language;
- curated palettes;
- repeated iconography;
- no mismatched rendering styles;
- no visibly synthetic one-off illustration flood.

---

# 12. Audio language

Audio reinforces causality but is never authoritative alone.

## 12.1 Core cues

Placement legal:
- soft lock/snug sound;
- visual contour snap.

Placement illegal:
- low muted click;
- explicit reason icon/text.

Heat hazard onset:
- rising thermal hum;
- timeline flash + heat border texture.

Stress escalation:
- short agitation chirp/rattle;
- state icon/posture transition.

Panic:
- distinct urgent species-layer + global soft alert;
- burst icon/posture/emission.

Contamination threshold:
- wet/spore hiss;
- mottled badge/effect.

Growth:
- stretch/pop organic sound;
- footprint transition animation.

Growth blocked:
- muted thump/strain;
- blocked footprint hatch.

Support power loss:
- relay click-down;
- slashed power icon + fixture dim.

Mandatory predicate failure:
- brief low alert motif;
- persistent review marker.

Success:
- restrained positive delivery motif;
- result ribbon.

## 12.2 Non-audio equivalents

Every cue above has:
- state icon;
- animation/posture;
- text/event feed when important;
- optional caption in `Gameplay captions` mode.

Gameplay captions examples:
- `[Thermal surge begins — Port zone]`
- `[Pulse Mite enters PANICKED]`
- `[Filter loses power]`

No spatial audio direction is required to solve a contract.

---

# 13. Accessibility

## 13.1 UI and text scale

Settings:
- 90%;
- 100%;
- 115%;
- 130%;
- 150%.

At 150%, panels may collapse into tabs but core hold remains usable.

Minimum critical text target at 1080p: equivalent of approximately 18px visual height for ordinary body text; final implementation must validate legibility rather than rely on raw pixel number.

## 13.2 Color independence

Every critical semantic channel uses at least two of:
- color;
- shape;
- pattern;
- icon;
- motion;
- label.

Provide channel-palette presets but do not make palette switching the only accessibility strategy.

## 13.3 Reduced motion

Options:
- Full;
- Reduced;
- Minimal.

Reduced:
- less shaking;
- less camera/board pulse;
- VFX duration shortened;
- no screen-space distortion.

Minimal:
- no shake;
- no shimmer distortion;
- state changes use discrete fades/icons;
- growth uses shape crossfade rather than stretch.

## 13.4 Flashing

`Reduced flashing` replaces bright pulses with border emphasis and icon expansion. No required information relies on repeated flashes.

## 13.5 Playback flexibility

Player may:
- pause transit;
- step by tick;
- use 0.5x speed;
- speed up to 4x;
- scrub completed run;
- skip remaining playback once feature unlocked.

No timer punishes slower reading.

## 13.6 Input remapping

Keyboard shortcuts for gameplay actions are remappable.

Mouse primary/secondary behavior may be swapped where practical.

Gamepad mapping remains separate preset.

## 13.7 Information density

Modes:
- Standard;
- Compact;
- Detailed.

Standard is authored default.

Detailed exposes more exact values in inspector/review, never recommendations.

Compact reduces persistent labels while keeping icons/tooltips.

## 13.8 Dyslexia-friendly option

If practical within font licensing/implementation, include a readable alternate font designed for clear letter distinction. This is optional at specification level; required baseline is a highly legible UI font with good `I/l/1`, `O/0`, and weight contrast.

## 13.9 Captions

Gameplay captions can report non-speech audio events. They are off by default but independently configurable from dialogue subtitles if any flavor voice is ever added.

---

# 14. Gamepad / Steam Deck boundary

Mouse-first PC design remains authoritative.

Gamepad support is targeted for complete core play if it can be achieved without redesigning the game around radial menus.

## 14.1 Gamepad cursor model

Default gamepad mode uses:
- left stick/D-pad grid focus navigation;
- face button pick/place;
- shoulder buttons rotate;
- trigger opens overlay radial or cycles overlay;
- another face button inspect/cancel;
- bumpers switch tray/hold/inspector focus;
- dedicated pause/play in transit.

## 14.2 Steam Deck

Goals:
- 1280x800 safe layout;
- readable at native handheld size using 115–130% UI scale;
- no hover-only information;
- touchscreen may act as mouse but is not required;
- all core actions achievable with controls.

## 14.3 Boundary

Do not compromise mouse planning speed to force identical interaction on controller.

If drag-and-drop is cumbersome on gamepad, use pick-up / move ghost / place sequence while preserving the same authoritative action result.

---

# 15. Settings

## 15.1 Display

- resolution;
- display monitor;
- fullscreen / borderless / windowed;
- VSync;
- frame-rate cap;
- UI scale;
- safe-area margin;
- reduced motion;
- reduced flashing;
- channel palette preset.

## 15.2 Audio

Independent sliders:
- master;
- music;
- gameplay/SFX;
- UI;
- ambience;
- voice/dialogue if later used.

Also:
- mute when unfocused;
- gameplay captions.

## 15.3 Controls

- key rebinding;
- reset bindings;
- mouse sensitivity only if any camera pan/zoom exists;
- swap mouse buttons;
- controller vibration intensity;
- controller glyph preference auto/manual.

## 15.4 Gameplay / information

- information density;
- default transit speed;
- pause on P1 major event optional;
- confirm before launch always / warnings only;
- tutorial reminders;
- exact numeric inspector values standard/detailed as allowed by known information;
- auto-open review on failure default ON.

No setting may expose future-solver information.

---

# 16. Resolution, aspect ratio, localization

## 16.1 Aspect ratio

Supported design targets:
- 16:9 primary;
- 16:10;
- 21:9;
- 4:3 minimum fallback.

Ultrawide may expand side margins/panels but must not reveal additional future information or change hold gameplay area.

## 16.2 Small resolution fallback

At 1280x720:
- manifest tray may collapse to icon cards;
- inspector becomes tabbed drawer;
- route timeline remains visible;
- Launch and mandatory objectives remain persistent.

## 16.3 Localization-safe layout

Rules:
- no gameplay-critical text baked into textures;
- buttons support approximately +40% text expansion from English baseline;
- inspector labels may wrap to two lines;
- German/Russian-length strings must fit baseline test set;
- CJK font fallback planned;
- right-to-left not required at launch unless localization scope later includes it, but data structures should not prevent it;
- icon + text semantics prevent dependence on compact English abbreviations.

Missing localization string falls back to English key-resolved text, never blank UI.

---

# 17. Content-warning boundaries

The game uses stylized fictional organisms and may depict:
- stress/panic;
- contamination/infection-like states;
- critical welfare states;
- organic growth;
- feeding.

It must avoid graphic gore or realistic animal suffering as a core presentation strategy.

Settings/about page may state these themes clearly. No heavy content-warning interstitial is required unless future art becomes more intense than this spec.

---

# 18. UX failure and edge cases

## 18.1 Illegal drop

Behavior:
- do not commit;
- return to prior valid state;
- show exact reason at cursor and in brief tooltip;
- reason disappears after successful placement or pointer moves away.

## 18.2 Impossible support link

If target invalid:
- line becomes broken/dashed;
- inspector states reason;
- required-link support blocks Launch;
- optional-link support may launch inactive if canonical support rule permits.

## 18.3 Overlapping modal prevention

Only one blocking modal can exist at a time.

Priority:
1. OS/system save corruption/error;
2. quit/unsaved confirmation;
3. launch confirmation;
4. tutorial card;
5. non-blocking inspector.

Opening a higher-priority modal dismisses or suspends lower-priority nonessential overlays.

## 18.4 Launch with warnings

Warnings are summarized in launch strip. Up to three displayed; extras collapsed under `+N more`.

Player can always cancel and inspect source of warning.

## 18.5 Quit during planning

Current planning setup autosaves locally after each committed planning action with short debounce.

Quit returns safely to same planning state on Continue.

Exact persistence mechanics finalized Phase 8.

## 18.6 Quit during transit

The committed initial state, content version, route seed/profile, and latest completed tick must be recoverable.

Phase 8 may save full tick snapshots or deterministically replay to latest saved tick. User-facing result must resume paused at a stable tick, never midway through visual-only animation.

## 18.7 Quit during review

Review state persists selected run as latest result. Continue returns to review or campaign map depending implementation preference, but the last committed run must remain inspectable until a new run replaces it or contract is exited.

## 18.8 Controller disconnect

Transit auto-pauses.

Planning shows reconnect prompt but keyboard/mouse remains usable immediately.

No run is lost.

## 18.9 Missing localization

Fallback to English. Missing key may additionally be written to debug log, never shown as raw localization token to player in release build.

## 18.10 Corrupted hold/layout reference

If a save references unavailable/corrupt authored layout:
- do not guess a replacement during active contract;
- mark current contract recovery invalid;
- preserve campaign progression;
- return player to contract brief with `Setup could not be restored; this contract will restart`;
- retain diagnostic log for QA.

## 18.11 Corrupted planning entity position

If serialized placement violates current content definition:
- reject only that planning snapshot;
- fall back to contract initial state or last validated launch snapshot;
- never overlap entities silently.

## 18.12 Changed content version

If content version differs and deterministic replay cannot be guaranteed:
- completed historical score remains recorded with version tag;
- in-progress transit restarts from committed launch under old compatible data if packaged, otherwise returns to planning with explicit restart notice;
- no false deterministic claim.

---

# 19. First-session paper walkthrough

## Step 1 — First launch

Player boots game, chooses default accessibility, selects Campaign, enters Contract 1.

Expected comprehension:
- `I need to place all living cargo in this hold.`

The player drags first organism. Legal cells outline. They attempt an overlap; the piece returns to prior spot with `Overlap` label. They place correctly.

## Step 2 — First contract planning

Player inspects a trait card and sees a short local rule. They complete manifest.

Launch becomes enabled.

Expected comprehension:
- `Placement is reversible; launch is the commitment.`

## Step 3 — First transit

Player confirms Launch. Hold animates through short deterministic transit. One organism emits heat, another reduces it.

No failure occurs.

Expected comprehension:
- `Things continue happening after the doors close.`

## Step 4 — First meaningful failure

By Contract 3 or 4, player creates a plausible but bad arrangement. During transit:
- a route/source raises local field;
- one organism crosses threshold;
- its new state emits another effect;
- mandatory condition fails.

Result ribbon appears and review selects the failed organism.

## Step 5 — Causal review

Player clicks `Why?` and walks backward:
- failed predicate;
- PANICKED state;
- stress increase;
- adjacent alarm/source relationship.

Expected comprehension:
- `The game can explain the chain; I can change one cause instead of guessing.`

## Step 6 — Retry

Player selects Retry from last launch.

Planning returns to identical layout. They move one organism and relaunch.

Changed piece is visually marked relative to prior attempt.

## Step 7 — Successful retry

Transit succeeds. Review shows mandatory condition passed and Bronze/Silver/Gold breakdown if relevant.

Expected comprehension:
- `My hypothesis was testable and the outcome was reproducible.`

This loop is the minimum UX proof for the product thesis.

---

# 20. Phase-6 acceptance tests

Phase 6 is considered closed only if all tests below are satisfied on paper/specification level.

## 20.1 State flow
- Every player-facing state from boot through campaign completion has an entry and exit path.
- Failure always reaches review before destructive reset.
- Retry preserves exact committed setup.
- No state requires live backend connectivity.

## 20.2 Planning controls
- Every mandatory planning action is achievable with mouse.
- Every mandatory planning action has a gamepad-compatible conceptual equivalent.
- Illegal placement cannot destroy or lose an entity.
- Rotation cannot silently commit an illegal state.
- Undo/redo covers all reversible planning actions.
- Launch requires deliberate confirmation.

## 20.3 Information boundary
- Pre-launch facts never reveal full future solution.
- Immediate overlays show only current/direct known influence.
- Unknown information is visibly marked, not omitted deceptively.
- Post-run review may reveal exact historical facts for the completed run.

## 20.4 Transit integrity
- Playback speed does not change authority.
- Pause never stops midway through an authoritative phase.
- Visual animation never determines collision, growth, range, state, or scoring.
- High-speed mode preserves all P0/P1 event readability.

## 20.5 Causal review
- Player can identify first decisive failed predicate.
- Player can navigate from failure to immediate cause to root trigger where history supports it.
- Additive multiple causes are represented honestly.
- Review does not render an unreadable whole-hold dependency graph by default.
- Retry from review requires no manual reconstruction.

## 20.6 Onboarding
- First 10 contracts teach interface and rule-reading in explicit progression.
- No advanced rule appears as mandatory knowledge before being taught or bounded as discovery.
- Tutorial cues and discovery cues use different visual language.
- Full-screen mandatory tutorial scaffolding ends by Contract 10.

## 20.7 Accessibility
- Color is never sole carrier of critical information.
- Critical audio has non-audio equivalent.
- Transit can pause and run at 0.5x.
- Reduced motion and reduced flashing preserve all information.
- UI scales to at least 150% with functional fallback layout.
- Steam Deck-sized layout remains operable without hover-only information.

## 20.8 Presentation scope
- 22 species fit within four rig/body-plan families.
- No species requires unique animation system to communicate foundation rules.
- VFX uses bounded reusable families.
- Art direction remains consistent and readable rather than asset-volume driven.

## 20.9 Edge cases
- Quit during planning is recoverable.
- Quit during transit resumes/reconstructs only at stable authoritative tick.
- Controller disconnect cannot lose a run.
- Missing localization cannot blank a critical control.
- Corrupted layout reference fails safely without inventing a replacement.

---

# 21. Phase-6 closure

The UX architecture is now sufficiently specified for later technical implementation planning.

Locked outcomes:
- complete player-facing state flow;
- mouse-first and keyboard controls;
- controller/Steam Deck boundary;
- planning-screen information hierarchy;
- launch confirmation semantics;
- deterministic transit presentation contract;
- event-priority model;
- causal-review interaction model;
- first-ten-contract onboarding structure;
- visual state/channel language;
- reusable art production grammar and asset ceilings;
- audio cue language and non-audio equivalents;
- accessibility requirements;
- settings and localization-safe layout rules;
- UX edge-case behavior;
- first-session walkthrough;
- acceptance tests.

No production code has started.

Phase 6 may be reopened only if later commercial, technical, simulation, or adversarial review exposes a contradiction or implementation blocker.