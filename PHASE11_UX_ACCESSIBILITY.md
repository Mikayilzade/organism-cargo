# ORGANISM CARGO — PHASE 11 UX / ACCESSIBILITY ACCEPTANCE CONTRACT

Status: **CANONICAL PHASE-11 FREEZE SUPPLEMENT — UX/ACCESSIBILITY**
Last updated: 2026-08-15

This document closes the remaining Phase-11 ambiguity around input parity, Steam Deck layout, maximum UI scale, no-audio play, non-color signaling, reduced motion/flashing and remapping. It does not alter simulation rules. Until folded into `UX_ARCHITECTURE.md`, this file is the more specific authority for mandatory accessibility and device acceptance paths.

---

# 1. Required complete input paths

Every mandatory gameplay path must be completable with each of the following independently:

1. mouse + keyboard;
2. keyboard-only;
3. controller-only;
4. Steam Deck built-in controller at 1280x800.

Pointer use may remain the preferred desktop interaction, but controller is **not optional** and a virtual free cursor cannot be the only controller solution.

Mandatory path means, at minimum:
- first-run preflight;
- title/menu navigation;
- campaign node selection;
- contract brief inspection;
- manifest selection;
- organism placement/movement/removal;
- legal rotation;
- support placement/removal;
- support target/link configuration;
- support power-priority configuration;
- overlays;
- objective inspection;
- Launch confirmation and cancellation;
- Transit pause/play/speed/tick-step where available;
- entity/cell inspection during playback;
- entering and operating Causal Review;
- timeline significant-event navigation;
- jump to failed predicate/cause;
- Retry / Reset / Return to map;
- Codex and Settings;
- save-recovery choices;
- campaign completion flow.

No required action may exist only as drag-and-drop, hover, right-click, mouse wheel or a tiny pointer target.

---

# 2. Keyboard-only planning contract

Keyboard-only mode uses explicit logical focus regions: `MANIFEST`, `HOLD`, `INSPECTOR`, `ROUTE`, `OBJECTIVES_SUPPORTS`, `TOOLBAR`.

Rules:
- a visible focus indicator is always present;
- a single remappable action cycles regions forward and another backward;
- arrow/D-pad navigation within HOLD moves by logical grid cell, not pixel position;
- Accept picks up/selects and places;
- Cancel returns carried item to prior valid state or exits the current submode;
- Rotate operates the carried/selected legal organism;
- Remove returns selected placed item/support to tray when legal;
- link/power-priority modes use ordered lists plus clear source/target labels;
- every pointer tooltip fact is reachable via Inspect/focus;
- focus cannot escape behind a modal.

A keyboard-only player may complete the game without enabling mouse keys or OS pointer emulation.

---

# 3. Controller-only / Deck planning contract

Controller planning uses grid focus and discrete region navigation.

Minimum semantic mapping family:
- D-pad / left stick: move logical focus;
- South/Accept: select/pick/place/activate;
- East/Cancel: cancel/back;
- shoulder/face remappable action: rotate;
- shoulders/triggers: region/tab cycling and/or overlay cycling;
- dedicated remappable Inspect;
- dedicated remappable Undo and Redo or chorded actions that are discoverable and never conflict with required navigation;
- Launch requires deliberate two-step focus/confirmation, never a single accidental face-button press from ordinary planning.

Controller glyphs update dynamically when input source changes. Text labels remain available so glyph recognition is not the sole instruction.

Steam Deck touch screen/trackpad may improve convenience but is never required to satisfy Deck acceptance.

---

# 4. Remapping contract

All gameplay actions that can affect progression or required navigation are remappable on keyboard and controller.

Required remappable semantic actions include:
- navigate/focus movement;
- accept;
- cancel/back;
- inspect;
- rotate;
- remove/return to tray where separate;
- region next/previous;
- overlay next/previous or overlay menu;
- undo;
- redo;
- launch/launch-focus action;
- pause/playback;
- speed up/down;
- tick step;
- Review significant-event previous/next;
- jump to failed predicate;
- jump to cause/root;
- compare start/final;
- tab/panel navigation.

Rules:
- conflicts are detected before saving;
- user may intentionally bind one action to the same key only where contexts are mutually exclusive and UI explains it;
- there is always `Reset bindings to default` per device class;
- a remap cannot strand the user inside the remapping screen: Accept/Cancel recovery path is guaranteed;
- controller remapping cannot require a mouse to confirm;
- keyboard remapping cannot require a controller to confirm;
- saved bindings are settings, not campaign state, and may remain device-local.

---

# 5. Steam Deck / 1280x800 layout acceptance

At 1280x800 default UI scale:
- full normal hold remains visible without mandatory scrolling;
- current mandatory objectives remain reachable without obscuring the hold during placement;
- route timeline remains readable or collapses into a single-row/tappable focus strip;
- manifest, inspector and support/objective panels may use tabs/drawers rather than shrinking below readable size;
- Launch, Undo/Redo, overlays and support power status remain directly reachable;
- no text is clipped in source language under normal localized expansion allowance;
- focus indicators remain visible at all screen edges;
- modal confirmation fits fully within safe area.

At maximum supported UI scale on 1280x800:
- side panels may become mutually exclusive drawers;
- hold may use bounded zoom/pan only if keyboard/controller access is complete and the player can always reset view;
- required action buttons never fall off-screen;
- no objective, warning or unknown-information marker becomes inaccessible;
- Causal Review may stack timeline/inspector panels vertically or use tabs, but significant-event navigation remains one-action reachable.

The exact maximum scale percentage is implementation-flexible only if it is at least the product's declared accessibility maximum and passes all acceptance paths. The current technical test reference of 200% is a minimum stress target, not permission to hide mandatory controls.

---

# 6. No-audio acceptance

The entire game is completable with master volume at 0 and all audio devices unavailable.

Every gameplay-significant audio cue has a visual/text equivalent, including:
- route hazard onset/end;
- state transition;
- alarm/panic;
- growth and blocked growth;
- feeding/soothing activation when mechanically relevant;
- support Brownout/power loss;
- discovery evidence event;
- mandatory predicate failure;
- transit completion.

Non-speech gameplay captions are available independently of spoken-subtitle settings and identify source when source matters, e.g. `Ember Pod — alarm pulse` rather than only `[alarm]`.

Audio never carries an otherwise unavailable timing fact.

---

# 7. Non-color-only acceptance

Color may reinforce state, but every critical distinction also uses at least one of shape, icon, pattern, label or posture.

Frozen channel languages:
- heat: wave/thermal-line pattern + heat icon;
- stress field: ripple/jagged directional pattern + stress icon;
- contamination: particulate/mottled pattern + contamination icon.

Other required distinctions:
- legal placement: valid contour/icon;
- illegal placement: crossed/blocked icon + reason text on inspection;
- warning: caution pattern/icon distinct from invalid;
- powered support: explicit power symbol/state label;
- Brownout/off: slashed-power symbol;
- sleep: sleep icon/posture;
- documented vs bounded-unknown knowledge: different iconography/labels, not hue alone;
- success vs failure: text/icon + shape, never green/red alone.

A grayscale/simulation screenshot test must preserve all progression-critical distinctions.

---

# 8. Reduced motion contract

Reduced Motion changes presentation only and never changes authoritative ticks, event order, checksums or information availability.

With Reduced Motion enabled:
- long travel tweens collapse to short fades/position snaps;
- camera/board shake is disabled;
- looping organism idle motion is reduced or removed;
- growth uses static before/after outline + brief fade rather than expansion tween;
- environmental overlays may use static patterns rather than scrolling waves/particles;
- Causal Review timeline scrolling can snap without inertial motion;
- severe event emphasis uses icon/border persistence rather than screen movement.

No required cue disappears when motion is removed.

---

# 9. Reduced flashing contract

Reduced Flashing is available at first-run preflight and Settings.

With it enabled:
- no full-screen flash;
- no rapidly alternating high-contrast effect;
- panic/alarm emphasis uses persistent outline/icon/caption;
- hazard cues use bounded fade and static warning strip;
- selected/invalid-cell feedback uses outline/pattern rather than strobe;
- discovery evidence uses icon/caption rather than flash.

Any presentation effect that would exceed the project's flash-safety threshold must automatically use the reduced variant when setting is enabled. The authoritative simulation is unchanged.

---

# 10. Maximum UI scale acceptance path

At maximum supported UI scale on each minimum supported resolution:
- every mandatory menu item is reachable;
- every modal can be accepted/cancelled;
- Planning can place/rotate/remove every legal footprint;
- all structural launch blockers expose readable reason;
- all mandatory objectives can be read before launch;
- support power/priority can be configured;
- Causal Review can reach first failure/root and Retry;
- Codex exact arithmetic remains viewable through scroll/tab without clipping;
- Settings remains navigable so scale can be reduced again.

Text containers wrap/scroll; text itself is not truncated into inaccessible ellipses when it contains a game rule.

---

# 11. Acceptance matrix

Before UX domain freeze passes, QA must complete the following matrix on at least one full representative contract containing placement, rotation, one support link, Brownout priority, dynamic transit failure and Causal Review:

| Path | Mouse+KB | Keyboard only | Controller only | Deck 1280x800 |
|---|---|---|---|---|
| Boot/preflight/menu | PASS required | PASS required | PASS required | PASS required |
| Brief -> Planning | PASS required | PASS required | PASS required | PASS required |
| Place/move/rotate/remove | PASS required | PASS required | PASS required | PASS required |
| Support config + priority | PASS required | PASS required | PASS required | PASS required |
| Inspect objectives/unknowns | PASS required | PASS required | PASS required | PASS required |
| Launch/cancel warnings | PASS required | PASS required | PASS required | PASS required |
| Transit controls/inspection | PASS required | PASS required | PASS required | PASS required |
| Review cause navigation | PASS required | PASS required | PASS required | PASS required |
| Retry/reset/map | PASS required | PASS required | PASS required | PASS required |
| Settings/remap/recovery | PASS required | PASS required | PASS required | PASS required |

Repeat representative path with:
- maximum UI scale;
- master audio 0;
- non-color-only inspection (grayscale or equivalent test mode);
- Reduced Motion ON;
- Reduced Flashing ON;
- remapped non-default keyboard bindings;
- remapped non-default controller bindings.

Any missing required path is a release blocker, not a polish backlog item.

---

# 12. Freeze verdict for this domain

The required interaction/accessibility behavior is now specified without relying on “mouse primary” as an excuse for incomplete controller/keyboard paths. Implementation may choose exact visual composition, glyph set, panel animation and default physical bindings, but may not remove parity, remapping, no-audio/non-color signaling, maximum-scale reachability, reduced-motion/reduced-flash behavior or Deck acceptance.