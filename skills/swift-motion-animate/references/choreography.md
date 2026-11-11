# Choreography: several elements, one motion

Read this when two or more things move in response to the same event: a group entering, a stagger, a hero
entrance, a view swap inside a container, an element leaving while its siblings close the gap, a cause-then-
effect pair, or an attention loop. A single animation's spring, duration and origin come from
`springs-and-timing.md`; this file covers the relationships between animations: order, overlap, timing and
stillness.

## Contents

1. Posture
2. Hard rules
3. Cast the elements
4. Pick the relationship for each pair
5. Numbers
6. Stagger patterns in SwiftUI
7. Sync secondary motion to the moment that matters
8. Adapt timing to what changed
9. Direction and exits
10. Interruption
11. Attention loops
12. Reduce Motion and haptics
13. Output: timeline first

---

## 1. Posture

Agents choreograph by adding. Every child gets a `delay(Double(i) * 0.1)`, the panel slides in and then its
items trickle in, and the old view waits politely for the new one. Each piece is smooth on its own. Put
together, the user waits for the interface to finish performing before they can use it.

Good choreography is mostly about **cutting moving parts and running the remaining ones in parallel**.
Sequence only when order carries meaning: reading order, cause and effect, or one thing physically arriving
before another. When a sequence feels right it reads as one gesture, a wave. When it feels wrong it reads as
a queue.

## 2. Hard rules

1. **One entrance per container.** If the panel slides in, its content is already there. Never animate a
   parent's entrance *and* stagger its children. That's two layers of entrance, and the user waits through both.
2. **Never stagger high-frequency UI:** menus, dropdown rows, tab content, `List` / `LazyVStack` rows. Lazy rows
   are recycled and re-fire their entrance on scroll-back, which reads as flicker. Stagger only on the first
   appearance of a rarely seen group.
3. **Choreography never blocks interaction.** Everything visible is tappable at once. No
   `.allowsHitTesting(false)` while a sequence plays, unless you state why.
4. **Every sequence survives interruption.** Keep imperative sequences in a `Task` (or `.task(id:)`) and cancel
   before restarting; never stack them. Chain on `withAnimation(_:completionCriteria:_:completion:)`, never on
   `DispatchQueue.main.asyncAfter` sized to a duration.
5. **Exits are simultaneous, shorter and simpler.** No reverse stagger out. The user has already decided to leave.
6. **Properties may finish at different times.** That is physical, not a bug: the iOS app launch uses several
   springs with staggered starts and ends. Don't force everything to land on the same frame.
7. **Uniform stagger is a smell.** If every item has the same delay, distance and duration, the group moves
   like a metronome. Vary the treatment by role (section 3).

## 3. Cast the elements

List every element that moves on the event and give each one a role before writing any timing.

| Role | Who | Motion |
|---|---|---|
| **Lead** | the acted-on item, the new view, the title | moves first, travels most (12 pt) |
| **Support** | subtitle, CTAs, the rest of the group | follows, shorter and smaller (6–8 pt) |
| **Decoration** | pills, badges, dividers | fade only (0 pt), or nothing |
| **Static** | containers whose content animates, persistent chrome, backgrounds | **does not move** |

- More than one Lead is a hierarchy problem that motion can't fix. Say so.
- Most groups shrink at this step. A side panel with eight items becomes one move: the panel slides, and the
  items are simply there.
- **Persistent elements never fade out and back in.** Chrome present in both states lives in a surviving
  parent, or morphs with `matchedGeometryEffect`. Rebuilding it in both branches of an `if/else` gives a cut.
- **Unified interpolation.** Elements driven by one value (a chart line, its label, a tick, a badge) share one
  `Animation` constant in one transaction, so they can't drift apart when interrupted. Stagger is for
  independent elements only.

## 4. Pick the relationship for each pair

```
Do both elements belong to the same visual object or the same moment?
├── Yes → TOGETHER. Same start, same timing family. (A container's height and its content; a chip leaving
│        and its siblings closing the gap.)
└── No → Does the order carry meaning (reading order, cause → effect, one arrives before the other)?
         ├── No → TOGETHER. Order without meaning is just delay.
         └── Yes → Would showing both at once look broken (overlap, passing through, two rich views fighting)?
                   ├── Yes → SEQUENCE. The second starts as the first finishes, or just before it.
                   └── No → OVERLAP. A stagger: the second starts while the first is still moving.
```

A fifth option that isn't a timing: **Carry.** When you can't control a child's path directly (shared layout),
animate the **parent** and let the children ride along. Add `geometryGroup()` (iOS 17) when children fly in from
the wrong place during a parent's geometry change.

**Together, by default**

- An element that leaves stops taking up space immediately, so its siblings slide into the gap *while* it
  fades. In SwiftUI this is the default: a removal inside `withAnimation` reflows siblings in the same transaction.
- Swapping views in one container is a crossfade: the old view exits while the new one enters. That is also the
  default for an `if/else` swap inside one `withAnimation`.
- Sub-animations of one component share a timing family. If a container opens with a 0.4 s spring and then
  resizes with an unrelated 0.25 s one, it reads as two objects. Inner content may use a lighter treatment (a slower fade so
  the swap is visible) but stays in the same family: springs inside springs.

**Sequence: when to wait**

- **Two rich states in a container that changes size in both dimensions.** Morphing between two dense views
  looks chaotic when both are visible, so the old content leaves before the new content starts. Use two-phase
  state with `withAnimation(_:completionCriteria:_:completion:)`.
- **One element would visibly pass through another.** Delay just the part that would overlap, not the whole flow.
- **Drawing has a cause and an effect.** A checkbox square draws, then the check mark draws.

Make the hand-off overlap slightly. Starting the second move just before the first ends is what turns a queue
into one gesture (recipe 8B starts a 0.4 s check at 0.5 s of a 0.6 s square).

## 5. Numbers

These are this skill's guidelines, distilled from practitioner work; Apple publishes no stagger values. Present
them as recommendations and tune them on a device.

| Rule | Value |
|---|---|
| Stagger step (product UI) | **40 ms** default; allowed 30–80 ms. Longer feels slow; shorter reads as simultaneous. |
| Stagger cap | items after index 6 share index 6's delay: `Double(min(i, 6)) * 0.04`, at most 0.24 s |
| Group span (product) | total stagger ≤ 0.3 s |
| Over budget | per item > 80 ms or span > 0.3 s → cap the step at 30 ms, or fade the group as one |
| First-run / marketing | 100–150 ms steps on 0.5–0.6 s entrances (for example 120 ms steps, 0.6 s, a 10 pt rise). Rare tier only. |
| Entrance distance | Lead 12 pt, Support 6–8 pt, Decoration 0 (fade only) |
| Non-uniform delays (optional) | ease-out over the index: `delay(i) = span * (1 - pow(1 - i/n, 2))`. Uniform gaps read as a metronome. |
| Accent timing | accents land in the last ~20 % of the lead's timeline; secondary lines start ~40 ms behind the first |
| Attention loop | first run after ~2.5 s, repeat every ~6 s at most, stop on interaction |
| Text stagger | emphasise key words only (`TextRenderer`, iOS 18); fade the rest over 0.2 s. Per-glyph motion everywhere reads samey. |
| Effects vs spatial | opacity and colour settle faster than position (a 0.2 s fade next to a 0.3 s move) |

SwiftUI has no stagger modifier; a stagger is a per-item `.delay(_:)`.

## 6. Stagger patterns in SwiftUI

Both patterns write the values inline: a 0.3 s bounce-free spring, a 0.2 s ease-out fade under Reduce Motion,
and a delay of `Double(min(i, 6)) * 0.04`. If the project already has motion constants, use those.

**Pattern A: the views exist, a real state flag flips.** Use it when the group is already in the tree and
becomes visible because something happened (the container finished opening, a step completed), never because
of `onAppear`.

```swift
import SwiftUI

struct FeatureList: View {
    let features: [String]
    let revealed: Bool                                   // flipped by a real event, not onAppear
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                Label(feature, systemImage: "checkmark.circle")
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed || reduceMotion ? 0 : 8)
                    .animation(reduceMotion ? .easeOut(duration: 0.2)
                                            : .spring(duration: 0.3, bounce: 0).delay(Double(min(index, 6)) * 0.04),
                               value: revealed)
            }
        }
    }
}
```

**Pattern B: the views are inserted.** Use it when items arrive (a first-run checklist loads, steps are added). Put the delay on
the insertion transition and keep removal plain so exits stay simultaneous.

```swift
import SwiftUI

func staggeredEntrance(_ index: Int, reduceMotion: Bool) -> AnyTransition {
    if reduceMotion { return .opacity }
    return .asymmetric(
        insertion: .opacity.combined(with: .offset(y: 8))
            .animation(.spring(duration: 0.3, bounce: 0).delay(Double(min(index, 6)) * 0.04)),
        removal: .opacity
    )
}
```

Insert inside `withAnimation(.spring(duration: 0.3, bounce: 0))` so removals use the transaction's spring. A complete version is recipe 10
in `recipes.md`.

**Radiate from the touch.** For a group the user triggered, delays grow outward from the tapped item:

```swift
import SwiftUI

func radiatingDelay(index: Int, tapped: Int) -> Double {
    Double(min(abs(index - tapped), 6)) * 0.04
}
```

**Eased delays.** When the gaps should tighten toward the end:

```swift
import Foundation

func easedDelay(_ i: Int, of n: Int, span: Double) -> Double {
    guard n > 0 else { return 0 }
    return span * (1 - pow(1 - Double(i) / Double(n), 2))
}
```

Keep `span` ≤ 0.3 s in product UI.

## 7. Sync secondary motion to the moment that matters

Each supporting animation hooks onto a specific moment of the lead (its start, its impact, or its settle), not
onto a delay that happens to look about right.

- **Sync to the cause, not the trigger before it.** The background pulses on the tap, together with the
  press, not on an earlier highlight.
- **Land the accents with the lead.** Lines or sparkles around an icon finish as the main shape finishes: a
  short burst in the last ~20 % of the timeline, the most important line first, the others ~40 ms behind.
- **A repeat action skips the build-up.** Keep the internal proportions and move the whole thing earlier.
- **Haptics land on the causal frame**, the same state change that drives the lead, never in a completion.

## 8. Adapt timing to what changed

- **Size of the change sets the duration** when a container resizes between views: a big jump needs the full
  move, a tiny jump with the same duration looks like a flicker. Derive it from the delta and clamp:
  `d = min(max(abs(deltaHeight) / 500, 0.15), 0.27)`. Measure the height with `onGeometryChange(for:of:action:)`:
  the form with a `{ newValue in }` action is back-deployed to iOS 16, so it works at the baseline; only the
  `{ oldValue, newValue in }` form needs iOS 18.
- **Smaller elements read bounce less.** A large view with the same bounce takes longer to settle and looks
  heavier. Stay inside the bounce band for the trigger regardless (`springs-and-timing.md` §3).
- **With a small, finite number of states, hard-code the values per transition.** A dozen hand-tuned
  transitions beat a clever formula you can't fine-tune.

## 9. Direction and exits

- **Forward moves content toward leading** (new content enters from trailing); back is the reverse. If Next and
  Back slide the same way, the motion contradicts the action. Use `.move(edge: .leading/.trailing)` or
  `.push(from:)`, which mirror in right-to-left layouts; `offset(x:)` does not.
- **Exits read the direction at the moment they start.** Set the direction state first, then change the step
  in a separate `withAnimation`, so the leaving view uses the new direction. Changing both in one transaction
  may give the leaving view the old direction; check it on a device.
- **An exit matches its entry.** Something that slid in from trailing leaves toward trailing on close. It
  doesn't just fade.
- **Exits are simultaneous.** Everything goes at once.

## 10. Interruption

A sequence has more states than a single animation. Test each:

- **Re-trigger mid-sequence.** Tap Next twice fast; switch tabs while a panel is still opening. Each run must
  cancel the in-flight sequence before starting; never stack.
- **Elements already on screen retarget from where they are**, because springs replace and carry velocity.
  Don't reset to the start state before re-running.
- **Wait for completion before chaining** with the completion form, which fires once at the perceptual end:

```swift
import SwiftUI

struct TwoStepReveal: View {
    @State private var step = 0
    @State private var isCelebrating = false
    @State private var badgeShown = false
    @State private var detailShown = false

    var body: some View {
        VStack {
            if step >= 1 { Text("Step one").transition(.opacity) }
            if step >= 2 { Text("Step two").transition(.opacity) }
            if badgeShown { Image(systemName: "star.fill").transition(.scale(scale: 0.9).combined(with: .opacity)) }
            if detailShown { Text("You did it").transition(.opacity) }
            Button("Next") { advance() }
            Button(isCelebrating ? "Hide" : "Celebrate") { isCelebrating.toggle() }
        }
        // A cancellable sequence: "Hide" mid-sequence cancels the run, so the detail never pops in afterwards.
        .task(id: isCelebrating) {
            guard isCelebrating else {
                withAnimation(.spring(duration: 0.2, bounce: 0)) { badgeShown = false; detailShown = false }   // exits together
                return
            }
            withAnimation(.bouncy) { badgeShown = true }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.3, bounce: 0)) { detailShown = true }
        }
    }

    private func advance() {
        withAnimation(.spring(duration: 0.4, bounce: 0)) {
            step = 1
        } completion: {
            withAnimation(.spring(duration: 0.3, bounce: 0)) { step = 2 }
        }
    }
}
```

`completionCriteria` defaults to `.logicallyComplete` (the perceptual end). Use `.removed` only when the next step
needs the animation fully finished, such as before removing a view that is still visibly moving.

## 11. Attention loops

An idle animation that invites interaction (a hand that occasionally taps, an icon that wiggles) waits about
2.5 s before the first run, repeats every ~6 s at most, stops while the user interacts, and resumes only after
the interaction's reset has finished. For a symbol on iOS 18, set `showsHint` about 2.5 s after the screen
settles and clear it on the first interaction:
`.symbolEffect(.wiggle, options: .repeat(.periodic(delay: 6)), isActive: showsHint && !reduceMotion)`.
Never on idle UI under Reduce Motion.

## 12. Reduce Motion and haptics

- **Collapse the choreography; don't just shorten it.** No delays and no travel: the group fades in together
  with a 0.2 s ease-out. If the sequence *is* the explanation (a step-by-step illustration), step between its frames
  instead of animating between them.
- **Haptics never stagger.** At most one per user action, on the causal frame. A staggered group of ten rows
  gets zero or one haptic, never ten.

## 13. Output: timeline first

Before writing code for a group, write the timeline and check it against the budget. Then list what doesn't move.

| Element | Role | Starts | Duration | Motion | Relationship |
|---|---|---|---|---|---|
| Title | Lead | 0 ms | spring 0.3, bounce 0 | fade + 12 pt rise | — |
| Subtitle | Support | 40 ms | spring 0.3, bounce 0 | fade + 8 pt rise | overlaps title |
| CTAs | Support | 80 ms | spring 0.3, bounce 0 | fade + 6 pt rise | overlaps subtitle |
| Pill | Decoration | 0 ms | ease-out 0.2 | fade only | together with title |
| Background | Static | — | — | — | — |

**What doesn't move, and why:** 2–5 elements you deliberately left still, each with its reason ("menu rows: one
entrance per container, the panel carries them").

**Feel-check:** name what code can't settle (whether the stagger reads as a wave, whether the crossfade reads
as one object) and the moment to scrub in a slow-motion screen recording. After naming the phases, the usual fix
is to *decrease* the delays and the stagger, not add more.
