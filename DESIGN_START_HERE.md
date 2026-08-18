# START HERE — GPT Game Autonomy

## Purpose
This repository is the persistent source of truth for an autonomous game-design project driven by repeated user prompts of **"го"**.

The project deliberately separates **design** from **implementation**. The first objective is to produce an unusually complete, internally consistent, implementation-ready game specification. Only after the design has survived research, revision, contradiction checks, edge-case review, balancing review, UX review, technical feasibility review, and final completeness passes may implementation begin.

The intended outcome is that a fresh ChatGPT/Codex session can read this repository and implement the game without inventing important design decisions on its own.

---

## Critical continuation rule
A new chat must **not** reconstruct project state from memory or ask the user to retell prior work.

Always read in this order:
1. `START_HERE.md`
2. `STATUS.md`
3. `GAME_BIBLE.md`
4. `RESEARCH.md` when the current step depends on market/reference research

Then continue from the exact `NEXT ACTION` in `STATUS.md`.

The repository, not chat history, is authoritative.

---

## User interaction protocol
The user normally sends only:

> го

Interpret it as authorization to perform the next meaningful project step autonomously.

During work, chat output should be minimal:
- `В процессе.` while work is underway when an update is needed.
- `Завершено.` when the cycle has been saved to GitHub.

Do not dump research, design notes, reasoning, or long summaries into chat unless the user explicitly asks. Save substantive work in GitHub instead.

Each `го` should advance the project by one coherent chunk large enough to matter, while avoiding oversized operations likely to fail before the state is saved.

At the end of every cycle:
1. update the relevant design/research file(s);
2. update `STATUS.md` with completed work and the exact next action;
3. ensure no important decision exists only in chat.

---

## Core operating principles

### 1. Design before code
Do not begin production implementation while `DESIGN COMPLETE` in `STATUS.md` is `NO`.

Tiny throwaway calculations or experiments may be used later to validate mechanics, but they must not become an accidental codebase before design closure.

### 2. One coherent game, not a pile of features
Every mechanic must serve the core fantasy, core loop, player motivation, or meaningful long-term progression. Remove systems that merely sound interesting but dilute the game.

### 3. Research first, imitate never
Study current and older games for demand signals, proven interaction patterns, failure modes, saturation, player complaints, and unexplored combinations. Do not clone a title. Extract design lessons and combine them into an original product thesis.

### 4. Scope is a design variable
Prefer concepts that can become deep through systems, procedural combinations, simulation, rules, replayability, and emergent interactions rather than requiring thousands of handcrafted assets, cutscenes, voiced lines, or bespoke levels.

### 5. A hook must be demonstrable
The eventual concept should be understandable from a short sentence, screenshot, GIF, or 10–30 second clip. Discovery cannot rely on players first reading a long lore explanation.

### 6. Depth over raw content volume
Aim for mechanics that recombine. A small number of interacting rules is preferable to a huge checklist of disconnected content.

### 7. Build for implementation by another session
The final specification must define not only what the player sees, but also rules, states, inputs, outputs, formulas, data structures at a conceptual level, failure states, transitions, save behavior, edge cases, balancing knobs, UI feedback, and acceptance tests.

### 8. Challenge assumptions repeatedly
Periodically stop adding features and run destructive review passes:
- what is boring?
- what is redundant?
- what can be exploited?
- what contradicts another rule?
- what creates excessive production cost?
- what would confuse a first-time player?
- what fails after 20+ hours?
- what prevents implementation from being deterministic?

### 9. Current evidence is not permanent truth
Market observations are dated evidence, not eternal rules. Preserve dates and sources in `RESEARCH.md`. Distinguish hard data, journalism, estimates, and hypotheses.

### 10. Preserve compact repository structure
Default files:
- `START_HERE.md` — permanent operating instructions and handoff
- `STATUS.md` — exact current state and next action
- `GAME_BIBLE.md` — canonical game design specification
- `RESEARCH.md` — external research, candidate concepts, comparisons, rejected paths

Do not create extra files unless a real complexity threshold is reached.

---

## Project phases

### Phase 0 — Foundation
Define workflow, constraints, scoring framework, handoff method, and completion gates.

### Phase 1 — Opportunity discovery
Research current and durable game patterns. Generate a wide concept field. Identify underserved combinations and traps/saturated areas.

### Phase 2 — Concept tournament
Score candidate concepts against the project criteria. Stress-test the strongest ideas. Merge compatible ideas where useful. Reject weak concepts explicitly.

### Phase 3 — Product thesis lock
Select one game. Lock target player, platform, genre framing, one-sentence hook, core fantasy, session structure, core loop, differentiator, and scope ceiling.

### Phase 4 — Mechanical architecture
Fully design rules, verbs, resources, simulation systems, progression, challenge generation, fail/win states, difficulty, balancing variables, and interaction hierarchy.

### Phase 5 — Content architecture
Define environments, entities, items, events, objectives, modifiers, progression content, procedural grammars, authored content needs, narrative delivery if any, and expansion logic.

### Phase 6 — UX / presentation architecture
Define controls, camera, HUD, menus, onboarding, accessibility, feedback, audio cues, visual language, readability, pause/settings, save/load, failure/recovery flows, and first-session experience.

### Phase 7 — Economy / retention / commercial model
If relevant: pricing, progression economy, unlock pacing, replay incentives, achievements, difficulty modes, Steam features, demo strategy, monetization boundaries, and anti-grind principles.

### Phase 8 — Technical implementation specification
Choose engine/runtime direction and define scene/state architecture, conceptual data model, deterministic rules, persistence, procedural generation contracts, performance assumptions, input abstraction, localization readiness, test hooks, and implementation order.

### Phase 9 — Whole-game simulation on paper
Walk through:
- first launch;
- first 5 minutes;
- first hour;
- early mastery;
- midgame;
- late game;
- repeat play / 20+ hour behavior;
- unusual and hostile player behavior.

Repair inconsistencies.

### Phase 10 — Adversarial review
Run dedicated passes for:
- fun risk;
- scope risk;
- technical risk;
- balance exploits;
- economy exploits;
- UX ambiguity;
- content exhaustion;
- repetition;
- accessibility blockers;
- save corruption / state edge cases;
- implementation ambiguity.

### Phase 11 — Specification freeze
Every important unknown must be answered or explicitly marked as intentionally implementation-flexible. Produce acceptance criteria. Set `DESIGN COMPLETE = YES` only when another implementation session should not need to invent game design.

### Phase 12 — Implementation
Only after design freeze. Build in small, verifiable vertical slices while preserving the Game Bible as the contract. Any necessary design changes must first be reconciled back into the Bible.

### Phase 13 — Test / polish / release preparation
Playtest, balance, optimize, package, prepare store assets/text, demo if appropriate, QA saves and edge cases, and define post-launch boundaries.

---

## Initial product constraints
These are working constraints unless later evidence justifies changing them:
- Favor PC/Steam-first concepts because they support premium indie games, demos, community discovery, and system-heavy designs without mandatory mobile F2P economics.
- A mobile port may be considered only if the chosen controls/UI naturally support it.
- Favor single-player as the baseline because networking/backend/live-ops multiply implementation and QA cost. Multiplayer may survive only if evidence shows it is central enough to justify that cost.
- Prefer stylized, readable, low-to-moderate asset burden.
- Prefer system-driven replayability over large handcrafted worlds.
- Avoid concepts whose marketability depends mainly on expensive art production.
- Avoid direct trend-chasing when a microgenre is already rapidly filling with clones.
- A concept must offer a recognizable hook plus at least one second-order source of depth.

---

## Completion standard for the Game Bible
Before implementation, the Bible should let a new builder answer, without guessing:
- What exactly is the player trying to do?
- What can the player do at every moment?
- Why is each action interesting?
- How does the game create pressure, choices, surprise, mastery, and recovery?
- What changes from minute 1 to hour 20?
- What content is authored vs generated?
- What are all major state transitions?
- What happens when the player behaves unexpectedly?
- What is saved and when?
- What variables control balance?
- What does every important UI element communicate?
- What constitutes a valid vertical slice?
- What constitutes feature completeness?
- What is explicitly out of scope?

If the answer to an important question is "the developer can decide later," design is not finished unless that freedom is intentional and harmless.

---

## Current repository state
Initialized 2026-08-15.

Continue from `STATUS.md`.
