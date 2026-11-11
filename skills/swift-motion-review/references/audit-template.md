# Audit: recon, report and plan template

Use this in Mode 2 (Audit), and for the recon searches in any mode. The audit is read-only on source code. Its value is that another agent, with no access to this conversation and no taste of its own, can pick up any one plan and execute it correctly. So every plan carries its own context: files, current code, exact target code with every value written out, and how to check the result.

## Contents

- [Recon](#recon)
- [Report outline](#report-outline)
- [Plan template](#plan-template)
- [Worked example](#worked-example)
- [plans/README.md](#plansreadmemd)

---

## Recon

Map the motion surface before judging it.

- **Stack:** SwiftUI only, or UIKit too (`UIView.animate`, `UIViewPropertyAnimator`, Core Animation); deployment target (decides whether iOS 18 / 26 APIs need `if #available`); Swift language mode.
- **Where motion lives:** a motion-constant file (`extension Animation`), view modifiers, `ButtonStyle`s, gesture handlers, third-party animation packages.
- **Conventions:** existing animation constants, helpers (`PressScaleStyle`, `project`, `rubberband`) and file placement. Plans use these; they never invent a parallel set or redeclare a helper the project already has. If there are none, plans write values out and put any helper `private` in the file that uses it. A shared motion file is an optional plan the user opts into, never a silent first step.
- **Personality:** a crisp utility earns fewer and subtler motions than a playful consumer app.
- **Frequency map:** which surfaces are 100+/day, tens/day, occasional, rare. Severity follows it.

Searches (ripgrep):

```bash
# Every motion site
rg -n --type swift \
  -e 'withAnimation' -e '\.animation\(' -e '\.transition\(' -e 'contentTransition' \
  -e 'matchedGeometryEffect' -e 'geometryGroup' -e 'navigationTransition' -e 'matchedTransitionSource' \
  -e 'spring' -e 'timingCurve' -e 'easeIn' -e 'easeOut' -e 'linear\(' -e 'repeatForever' -e '\.delay\(' \
  -e 'PhaseAnimator' -e 'phaseAnimator' -e 'KeyframeAnimator' -e 'keyframeAnimator' \
  -e 'symbolEffect' -e 'sensoryFeedback' -e 'FeedbackGenerator' \
  -e 'DragGesture' -e 'MagnifyGesture' -e 'MagnificationGesture' -e 'RotationGesture' -e 'LongPressGesture' \
  -e 'GestureState' -e 'predictedEnd' -e 'scrollTransition' -e 'visualEffect' -e 'TimelineView' -e 'asyncAfter' \
  -e 'GeometryReader' -e 'onGeometryChange' -e 'onScrollGeometryChange' -e '\.id\(' -e 'isLuminanceReduced' \
  -e 'drawingGroup' -e 'compositingGroup' -e 'glassEffect' \
  -e 'UIView\.animate' -e 'UIViewPropertyAnimator' -e 'UISpringTimingParameters' .

# Reduce Motion coverage: compare against the files the first search found
rg -l --type swift 'accessibilityReduceMotion|isReduceMotionEnabled' .

# Motion constants present?
rg -n --type swift 'extension Animation' .

# Quick smells
rg -nP --type swift '\.animation\((?![^\n]*value:)' .          # value-less .animation (B1); see note below
rg -n --type swift -e 'transition\(\.scale\)' -e 'scaleEffect\([^)]*\? 1 : 0\)' .   # scale from 0 (C2)
rg -n --type swift -e 'max\(0, *value\.translation' .           # hard clamp (F5)
rg -n --type swift -e 'initialVelocity: *value\.velocity' .     # raw pt/s (F3)
rg -n --type swift -e '\.levelChange' -e 'sensoryFeedback\(\.(start|stop)' .   # silent on iPhone (I4)
rg -n --type swift -e 'onTapGesture' .                          # buttons without pressed state (F7)
```

The first search over-matches on purpose (`spring` hits variable names too). Treat hits as leads: open each one, decide its tier and purpose, then run the checklist.

The B1 search lists `.animation(` lines with no `value:` on the same line. It also lists the scoped `.animation(_:body:)` form (`.animation(.spring(duration: 0.25, bounce: 0)) { content in`), which is correct, and it misses a call whose `value:` sits on the next line, which is also correct; check multi-line calls by eye.

---

## Report outline

Print the report in chat. The only files an audit writes are the plans and `plans/README.md`.

```markdown
**Mode: Audit** · <app or module> · <date> · commit <short sha> · <N> motion sites in <M> files

## Summary
- <3–5 lines: overall state, the worst pattern, the single most valuable fix.>
- Motion constants: <present at path / none>. Reduce Motion: <X of Y files with custom motion branch for it>.
- Deployment target: iOS <n>. Personality: <crisp / playful>.

## Surface map
| Surface | Frequency tier | Motion sites |
|---|---|---|
| Home feed (tab root) | 100+/day | `FeedView.swift:40`, `FeedRow.swift:22` |
| Filters sheet | Occasional | `FiltersSheet.swift:15` |
| Onboarding | Rare | `Onboarding/*.swift` (6 sites) |

## Findings (by leverage)
| # | Severity | Problem the user feels | Locations | Fix summary | Plan |
|---|---|---|---|---|---|
| 1 | Critical | Slides and zooms still play with Reduce Motion on | 11 files (listed in plan) | Fade instead (`.opacity`, `.easeOut(duration: 0.2)`) when Reduce Motion is on | 001 |
| 2 | Critical | Cards lag behind the finger while dragging | `CardStack.swift:88` | Track the finger directly; spring only on release | 002 |
| 3 | High | Whole screens wobble on unrelated changes (value-less `.animation`) | 14 sites | Tie each animation to the value that should move it | 003 |

## Missed opportunities (additive, 2–4)
- <Places that cut where motion would prevent a jarring change, each with tier and purpose. Run them through the gates in opportunities-and-removal.md first.>

## Kept as is (earned)
- <Motion you checked and approve, with tier and purpose, so the reader knows it was reviewed.>

## Verification limits
- Checked from code: <…>
- Needs a physical device, Release build (Instruments SwiftUI + Animation Hitches): <…>
```

**Ordering and severity:** see SKILL.md § Severity and Mode 2 step 5.

**Plain words.** The report and the plans are read by people who don't have this skill. Describe what the user feels and why it happens; checklist IDs and reference file names stay out. Where a reason is Apple guidance, say so; where it is this skill's threshold, call it a guideline.

**Grouping.** Group findings into plans by the change an executor makes in one sitting, not by file. "Replace bare `withAnimation` with chosen springs" is one plan even if it touches 20 files. One plan should be reviewable as one diff. Two findings that share every file and the same fix pattern may merge.

---

## Plan template

Write each plan to `plans/NNN-short-slug.md` (use `motion-plans/` if `plans/` already exists for something else; continue the existing numbering). Stamp it with `git rev-parse --short HEAD`.

````markdown
# NNN: <Imperative title, e.g. "Make the card stack drag 1:1 with a projected dismiss">

- **Status:** TODO
- **Commit:** <short sha when written>
- **Severity:** Critical | High | Medium | Low
- **Surface tier:** <100+/day | tens/day | occasional | rare>
- **Depends on:** <002 | none>
- **Estimated scope:** <n files, rough size>

## Problem

What the user feels, where, and why it happens, in two or three sentences. Cite every location as
`path/File.swift:123` and quote the current code verbatim:

```swift
// Features/Cards/CardStack.swift:88 (current)
.animation(.spring(), value: dragOffset)
```

## Target

The exact end state in one or two sentences, including Reduce Motion and haptics. Every value spelled out
(`.spring(duration: 0.3, bounce: 0)`), thresholds, anchors; when the project has animation constants, their names and values.

## Repo conventions to follow

- Motion constants: <their file and the names to use, or "none: write the values out as below">.
- Exemplar that already does this right: `<path:line>`.

## Steps

1. In `<path>`, replace:
   ```swift
   <exact current code>
   ```
   with:
   ```swift
   <exact new code>
   ```
2. <next step, same format; one concrete edit per step>

## Reduce Motion

<The branch added, or "no movement involved".>

## Haptics

<The feedback, its trigger state and direction, or "none: <reason>".>

## Boundaries

- Do NOT touch <system components, unrelated animations, files outside the list>.
- Do NOT change structure or layout; motion only, unless a step says otherwise.
- Do NOT add dependencies, new source files, or public extensions on `Animation`, `Color` or `View`; helpers go `private` in the file that uses them.
- Do NOT change behaviour the finding isn't about (other timings, a toast's lifetime, sizes, copy); note it under Verification instead.
- If the code you find doesn't match the "current" excerpts (drift since the commit stamp), STOP and report instead of improvising.

## Verification

- **Mechanical:** builds with no new warnings (Swift 6 language mode if the project uses it);
  `rg -n '<removed pattern>' <paths>` returns nothing; affected `#Preview`s render.
- **Reduce Motion:** with Settings › Accessibility › Motion › Reduce Motion on, it fades instead of moving.
- **Feel check (physical device, Release build):** <specific things to feel, e.g. "a short fast flick dismisses;
  a slow drag to 45 % dismisses; a drag reversed before release snaps back; no lag behind the finger at 120 Hz">.
  Also run it in slow motion (Simulator › Debug › Slow Animations is fine for this one check) and look for
  <e.g. "the menu grows from its button, not its centre">.
- **Done when:** <eye- or machine-checkable criteria>.
````

Rules for the plan author:

- Write for the weakest executor. Exact paths, current-code excerpts, exact target code, ordered steps, hard boundaries. Never "use the usual spring" or "as discussed above": the executor has no "above".
- Pull every value from `standards.md`. Never approximate. No checklist IDs in the plan: say what is wrong and why in plain words.
- Any helper the target code uses (`project`, `rubberband`, `relativeVelocity`, `PressScaleStyle`) is pasted into the plan in full as a `private` declaration at the bottom of the file being fixed, unless recon found the project already defines it: then the plan names that file and reuses it. When several files need the same helper, the plan may propose one shared file, as a decision for the user to approve.
- A plan that adds the optional token set (`standards.md` § Optional: a motion token set) exists only when the user asked for an app-wide motion system. No other plan depends on it unless the user approved it.
- The feel check is not optional. Motion can be mechanically correct and still feel wrong; give the executor concrete things to watch for.
- Line numbers are as of the commit stamp. Tell the executor to match on code, not line numbers.

---

## Worked example

````markdown
# 002: Make the card stack drag 1:1 with a projected dismiss

- **Status:** TODO
- **Commit:** 4f2a91c
- **Severity:** Critical
- **Surface tier:** tens/day
- **Depends on:** none
- **Estimated scope:** 1 file, ~40 lines

## Problem

The top card trails the finger while dragging, because a spring animation is attached to the dragged
offset. Dismissal checks distance only, so a quick flick snaps back while a slow drag past 200 pt dismisses
even when the user is reversing. Dragging upward hard-stops at the top edge.

```swift
// Features/Cards/CardStack.swift:86–97 (current)
TopCard(card: top)
    .offset(y: dragOffset)
    .animation(.spring(), value: dragOffset)
    .gesture(DragGesture()
        .onChanged { value in
            dragOffset = max(0, value.translation.height)
        }
        .onEnded { value in
            if value.translation.height > 200 { dismissTop() }
            dragOffset = 0
        })
```

## Target

The card follows the finger exactly. On release it dismisses when translation plus projected travel passes
40 % of the card height, sliding off with `.spring(duration: 0.3, bounce: 0)` (the rendered offset clamped at
the card height); otherwise it snaps home with the same spring, inheriting the finger's velocity
(no overshoot: past rest it would read as re-opening). Above the top edge it resists progressively
(rubber-band, c = 0.55). Reduce Motion needs no extra branch: tracking is 1:1 and the release has no bounce.

## Repo conventions to follow

- Motion constants: none in the project, so values are written out.
- The two gesture helpers go `private` at the bottom of `CardStack.swift`; no new file.

## Steps

1. At the bottom of `Features/Cards/CardStack.swift`, add:
   ```swift
   /// Distance (pt) a fling travels under UIScrollView-like deceleration. `velocity` in pt/s.
   private func project(_ velocity: CGFloat, rate: CGFloat = 0.998) -> CGFloat {
       (velocity / 1000) * rate / (1 - rate)
   }

   /// UIScrollView-style resistance. x = signed overshoot past the bound, d = dimension.
   private func rubberband(_ x: CGFloat, dimension d: CGFloat, c: CGFloat = 0.55) -> CGFloat {
       let m = abs(x)
       return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)   // ≡ (1 − 1/(m·c/d + 1))·d
   }
   ```
2. In `CardStack`, add next to the other properties:
   ```swift
   private let cardHeight: CGFloat = 480   // matches TopCard's fixed frame at CardStack.swift:40
   ```
3. Replace lines 86–97 (quoted above) with:
   ```swift
   TopCard(card: top)
       .offset(y: min(dragOffset, cardHeight))
       .gesture(DragGesture()
           .onChanged { value in
               let t = value.translation.height
               dragOffset = t >= 0 ? t : rubberband(t, dimension: cardHeight)
           }
           .onEnded { value in
               let projected = value.translation.height + project(value.velocity.height)
               let shouldDismiss = projected > cardHeight * 0.4   // commit at 40 % of the travel
               withAnimation(.spring(duration: 0.3, bounce: 0)) {
                   dragOffset = shouldDismiss ? cardHeight : 0
               } completion: {
                   if shouldDismiss {
                       dismissTop()
                       dragOffset = 0
                   }
               }
           })
   ```

## Reduce Motion

No branch needed: tracking stays 1:1 and the only release spring has bounce 0.

## Haptics

None added: `CardStack.swift:120` already plays `.impact(weight: .light)` on `topCardID`. Keep it.

## Boundaries

- Do NOT touch the haptic at `CardStack.swift:120` or the `NavigationStack` push in `CardList.swift`.
- Do NOT change `TopCard`'s layout.
- If lines 86–97 don't match the excerpt, STOP and report.

## Verification

- **Mechanical:** builds with no new warnings;
  `rg -n 'animation\(\.spring\(\), value: dragOffset\)|translation\.height > 200|max\(0, value' Features/Cards` returns nothing.
- **Preview:** dragging up past the top edge resists instead of stopping dead.
- **Feel check (device, Release):** a short fast flick dismisses; a slow drag to 45 % dismisses; a drag reversed
  before release snaps back without passing its rest position; no lag behind the finger at 120 Hz.
- **Done when:** all of the above hold.
````

---

## plans/README.md

Create or update it after writing plans:

```markdown
# Motion plans

| # | Title | Severity | Depends on | Status |
|---|---|---|---|---|
| 001 | Fade instead of slide when Reduce Motion is on | Critical | none | TODO |
| 002 | Make the card stack drag 1:1 with a projected dismiss | Critical | none | TODO |

**Execution order:** 001 → 002 → …
**Notes:** <shared files two plans both touch; anything a human must check on a device.>
```

When asked to re-check plans later, compare each against the current code: mark finished plans DONE, refresh stale `file:line` references, and retire findings the code no longer has.
