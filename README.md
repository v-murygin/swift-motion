<p align="center">
  <img src="assets/logo.svg" width="112" height="112" alt="swift-motion logo: a spring settling onto its rest line">
</p>

<h1 align="center">swift-motion</h1>

<p align="center">
  <b>Motion and UI-craft taste for coding agents building SwiftUI apps.</b><br>
  Animations and gestures that feel first-party, reviews that trim what shouldn't move, and layouts tested against worst-case data.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/iOS-17%2B-informational.svg" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Swift-6-orange.svg" alt="Swift 6">
  <a href="https://skills.sh/v-murygin/swift-motion"><img src="https://skills.sh/b/v-murygin/swift-motion" alt="skills.sh"></a>
</p>

---

## Why

Agents can write SwiftUI animation code. What they lack is motion taste: knowing what should move, how, for how long, and when it shouldn't move at all. Each slip looks harmless on its own, and together they make an app feel slow and cheap:

- **`.easeIn` on an entrance.** It starts slowly, which delays the exact moment the user is watching.
- **`.transition(.scale)`.** It scales from 0, and nothing real appears out of nothing. Start at 0.95 with a fade instead.
- **Animating a ⌘-shortcut's result.** Shortcuts are an expert's fast path, and motion around them reads as delay.
- **Dead flicks.** A drag that ends in `withAnimation(.easeOut(duration: 0.3))` drops the finger's velocity, so every fling lands the same way. Add a distance-only threshold and a quick flick never dismisses at all.
- **Bounce on a tap-opened panel, a bare `withAnimation {}`, no Reduce Motion branch, a haptic fired from a completion handler** that lands 300 ms late.

These skills give the agent a decision order, chosen values, and the reasons behind them, so the first draft is the one a strict reviewer would approve. Sometimes the right answer is zero lines of motion code, and the skills say so.

## Install

**Any agent that reads `SKILL.md` (via [skills.sh](https://skills.sh/v-murygin/swift-motion))**

```bash
# all four skills
npx skills add v-murygin/swift-motion

# or just one
npx skills add v-murygin/swift-motion --skill swift-motion-gestures
```

**Claude Code plugin**

```text
/plugin marketplace add v-murygin/swift-motion
/plugin install swift-motion@swift-motion
```

**Manual (Claude Code skills directory)**

```bash
git clone https://github.com/v-murygin/swift-motion.git
cd swift-motion
mkdir -p ~/.claude/skills
for s in skills/*; do ln -sfn "$PWD/$s" ~/.claude/skills/"$(basename "$s")"; done
```

To link a single skill: `ln -sfn "$PWD/skills/swift-motion-animate" ~/.claude/skills/swift-motion-animate`. `-sfn` replaces an existing link on a re-run; if `~/.claude/skills/<name>` is a copied directory rather than a link, remove it first.

## Skills

| Skill | What it does | Try saying |
|---|---|---|
| [`swift-motion-animate`](skills/swift-motion-animate/SKILL.md) | Builds an animation through a decision order that ends in working code: whether to animate at all, purpose, API, spring values, interruption, exit, Reduce Motion and haptics. Covers transitions, press styles, toasts, menus, counters, symbol effects, heroes and zoom, keyframes, choreography, Liquid Glass morphs and porting CSS / Framer Motion. | "Make the heart tap and the toast feel like a polished iOS app." |
| [`swift-motion-gestures`](skills/swift-motion-gestures/SKILL.md) | Builds drag, swipe, fling and hold interactions that track the finger 1:1, hand the release velocity to the settle spring and snap by projected momentum. Covers dismiss cards, drawers and detents, swipe cards, swipe-to-delete, reorder, PiP throws, hold-to-confirm and ScrollView conflicts. | "Add swipe-down-to-dismiss like Photos. A quick flick should dismiss even if I didn't drag far." |
| [`swift-motion-review`](skills/swift-motion-review/SKILL.md) | Reviews motion code in four modes: **Review** a diff or file into severity-ranked findings with a Block / Request changes / Approve verdict, **Audit** a codebase into a prioritized report and executable plans, **Find** places that should animate, **Remove** motion that should go (subtraction only). | "Review the animations in InboxView.swift. Be strict." |
| [`swift-motion-break-ui`](skills/swift-motion-break-ui/SKILL.md) | Stress-tests a view with realistic worst-case data and environments: builds fixtures, renders them as named `#Preview` variants, and reports every break as Broken / Ugly / Fragile with a fix. Fixes only when asked. | "Try to break my ProfileHeaderView with worst-case data before I ship it." |

The skills route to each other: a tap-driven animation that also needs a drag hands that part to `swift-motion-gestures`, and a layout break caused by an animation is reported in `break-ui` and handed to `review`.

## What's inside

### The decision order (`swift-motion-animate`)

0. **Native check.** If a system component or semantic API already moves this (`NavigationStack`, `.sheet`, `Menu`, `.symbolEffect`, `.contentTransition`, glass styles on iOS 26), use it and stop.
1. **Should it animate at all?** Frequency decides. 100+/day actions (tab switches, keystrokes, ⌘-shortcuts) get no custom animation; tens/day stay near-imperceptible; occasional surfaces get a standard value; delight lives in the rare tier.
2. **Purpose** in one word: feedback, spatial consistency, state indication, preventing a jarring change, explanation, or delight.
3. **Tool:** the cheapest rung that fits, from a native component down to `TimelineView` + `Canvas`.
4. **Properties:** render-only modifiers first; never enter from nothing; anchor to the trigger.
5. **Spring values** from a fixed table, written inline.
6. **Interruption:** springs retarget and carry velocity; no keyframes on anything re-triggerable; no input locks.
7. **Exit** along the entry path, a little faster.
8. **Reduce Motion** branch, and 9. **haptic pairing**, in the same change.

### Spring presets (excerpt)

Bounce 0 is the default. 0.2 only for a gesture release with momentum, 0.3 only in the rare tier, never above 0.4.

| For | Value |
|---|---|
| Button press in / release | spring 0.15 / 0.3, bounce 0 |
| Toggle, chip, small state | spring 0.25, bounce 0 |
| Popover, menu, list change, numbers: in / out | spring 0.3 / 0.2, bounce 0 |
| Custom sheet, toast: in / out | spring 0.4 / 0.3, bounce 0 |
| Gesture releases | settle 0.3 b0, fling 0.3 b0.2, reposition 0.4 b0 |
| Reduce Motion substitute | `.easeOut(duration: 0.2)` |

The full per-interaction table, API facts (what `.default`, `.snappy` and `.spring(response:dampingFraction:)` really are), duration ceilings and value conversions are in [`springs-and-timing.md`](skills/swift-motion-animate/references/springs-and-timing.md).

### Gesture physics (`swift-motion-gestures`)

- **Track:** while the finger is down, `position = start + translation`, 1:1, with no animation.
- **Release:** a spring started at the finger's velocity, passed explicitly as a relative `initialVelocity` (pt/s divided by remaining distance, capped at ±30).
- **Projection:** `project(v) = (v / 1000) · 0.998 / (1 − 0.998)`, matching normal scroll deceleration, then snap to the nearest stop.
- **Commit:** `translation + project(velocity) > 0.4 × travel`, so a short flick commits and a flick back cancels.
- **Edges:** rubber-band with `c = 0.55`, never a hard wall.
- **Slop:** 10 pt, then lock the axis; `.simultaneousGesture` inside a `ScrollView`.
- **Cancel safety:** a `@GestureState` flag catches system-cancelled drags that never reach `onEnded`.

### Reduce Motion and haptics

Reduce Motion means fewer and gentler, not zero: travel, scale-in, zoom, depth, blur and loops become a 0.2 s fade; bounce goes to 0; gesture tracking, in-place feedback, colour changes and haptics stay. Haptics fire as one `.sensoryFeedback` per commit, snap or outcome, on the same trigger as the visual, never from a completion handler, never per frame, and never on a system control that already plays one. The skills also flag feedback types that are silent on iPhone (`.levelChange`, `.start` / `.stop`).

### Also inside

- **Recipes** that typecheck: press buttons, toasts, menus, counters, error shake, success check, card hero / zoom, staggered first-run, Liquid Glass morph, segmented pill; and on the gesture side, drag-to-dismiss card, detent drawer, Photos-style viewer, swipe card, PiP throw, hold-to-confirm, reorder and swipe-to-delete.
- **A review checklist** of about 70 rules in 12 groups (gate, scope, values, interruptibility, enter/exit, gestures, choreography, Reduce Motion, haptics, performance, SwiftUI pitfalls, adjacent layout), each with a default severity and wrong → right code.
- **A worst-case catalog** for `break-ui`: names, unbreakable strings, nil and empty fields, huge and negative numbers, currency, plurals, broken images, RTL, Dynamic Type to AX5, iPhone SE to iPad and iPhone Duo, plus a preview harness and before/after fixes.

## Example prompts

```text
Add a press effect to this card button.
This toast just pops in and out. Make it feel native.
The drawer jumps when I let go. Fix the release.
Build a swipe card deck with like / skip, iOS 17.
Is there too much animation in this screen?
Audit the motion in this app and plan the cleanup.
Where should SettingsView animate? Be picky.
Port this Framer Motion spring to SwiftUI.
Will this row hold up at AX5 in German? Add worst-case previews.
```

## How it was built and verified

**An evidence-ranked canon.** Every value comes from a ranked set of sources: Apple first (SDK behaviour, WWDC sessions, the HIG, measured system behaviour), then the best-evidenced source for each remaining value. The skills keep the two apart in what they tell you: Apple's guidance is cited as Apple's, and house values (duration ceilings, the 3 % press scale, the 40 % commit point, stagger steps) are presented as guidelines with their reason.

**Compile-checked code.** Every Swift code block in the skills was typechecked against the iOS 27.2 Simulator SDK (Swift 6.4 toolchain) at its marked deployment target. The baseline is iOS 17; newer APIs are marked iOS 18, 26, 27 or 27.1.

**Evals.** Each skill ships an eval case in its `evals/` directory (Claude plugin eval format: a prompt, input files and 9 to 11 graders). In blind A/B judging against the same model without the skill (iteration 2), scores on a 1–10 scale:

| Skill | With skill | Without | Δ |
|---|---:|---:|---:|
| `swift-motion-animate` | 8.6 | 7.5 | +1.1 |
| `swift-motion-gestures` | 8.5 | 6.0 | +2.5 |
| `swift-motion-review` | 8.8 | 8.0 | +0.8 |
| `swift-motion-break-ui` | 8.5 | 7.0 | +1.5 |

This is a small sample: one case per skill, one run each, one judge per case. Read it as a direction, not a benchmark. More cases and repeated runs are welcome contributions.

## Compatibility

- **Claude Code**, as a plugin (manifests in [`.claude-plugin/`](.claude-plugin)) or as skills in `~/.claude/skills/`.
- **Any agent that reads `SKILL.md`**, installed through `npx skills`.
- **Targets:** SwiftUI, iOS 17+ baseline, with iOS 18, 26 and 27 (27.1 for iPhone Duo) additions marked.

## Roadmap

- **UIKit coverage.** Today UIKit appears where SwiftUI needs it: a UIKit bridge for exact mid-flight catches and recognizer gating in `swift-motion-gestures`, and hosting UIKit views in `#Preview` for `swift-motion-break-ui`. First-class UIKit guidance is planned.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the ground rules. To run a skill's evals, from its directory:

```bash
cd skills/swift-motion-gestures
claude plugin eval . --scaffold --allow-tools Write Edit Bash
```

`--scaffold` runs the case's `place-files.sh`, which copies the input files into the run's working directory; `--allow-tools` grants the gated tools (Write, Edit, Bash) the cases need. A no-skill baseline arm runs alongside by default.

The score table above comes from a separate blind 1–10 judge. `claude plugin eval` reports grader pass rates (0–1), defaults to 3 runs per arm (`--runs 1` for a quick pass) and publishes its HTML report to claude.ai unless you pass `--no-publish`.

## License

[MIT](LICENSE) © Vladislav Murygin
