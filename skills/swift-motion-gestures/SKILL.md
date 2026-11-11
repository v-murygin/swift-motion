---
name: swift-motion-gestures
description: Build drag, swipe, fling and hold interactions in SwiftUI that track the finger 1:1, hand the release velocity to the settle spring and snap by projected momentum. Use it whenever building or fixing code that uses DragGesture, @GestureState, gesture velocity or predictedEndTranslation, or when building swipe-to-dismiss cards, toasts and photo viewers, custom drawers and detents (including choosing between a system sheet and a custom one), swipe cards, swipe-to-reveal or swipe-to-delete rows, drag-to-reorder, PiP-style throws, hold-to-confirm, rubber-banding, or a drag that fights a ScrollView. Use it too for complaints like "it doesn't follow my finger", "it jumps when I let go", "the fling feels dead" or "I can't grab it mid-animation". Send tap-driven animation, transitions and choreography to swift-motion-animate, reviews and audits of existing motion to swift-motion-review, and worst-case layout testing to swift-motion-break-ui.
---

# Gesture-driven motion

A gesture is direct manipulation: while the finger is down, the UI is the finger; the moment it lifts, physics
takes over. Every rule below follows from that split. The goal is a view that is glued to the finger, keeps
moving the way it was thrown, and can be grabbed again at any moment.

Baseline iOS 17. Newer APIs are marked **(iOS 18)**, **(iOS 26)** or **(iOS 27)**.

**Scope.** This skill covers motion a finger drives: tracking, release, snapping, dismissal, reordering, holds.
Route the rest:

- **swift-motion-animate**: tap-triggered transitions, press feedback (`ButtonStyle`), a toast's entrance and
  exit, list changes, choreography, performance of non-gesture motion.
- **swift-motion-review**: auditing or trimming existing motion code.
- **swift-motion-break-ui**: stress-testing layouts with worst-case data.

**Where the guidance comes from.** Some of it is Apple's: SDK behaviour, the HIG, WWDC talks such as "Designing
Fluid Interfaces" (2018) and "Animate with springs" (2023). The rest are house guidelines: thresholds and spring
values chosen because they feel right next to the system, such as the 40 % commit point or the 0.3 s release
springs. Follow both, but only the first is "Apple says"; keep that distinction when you explain a choice.

## 0. Editing the user's code

The user asked for a gesture, not a refactor. Keep the change small enough to review at a glance:

- **Stay inside the files the user named.** No new source files, no app-wide token system, no public
  `extension Animation` / `Color` / `View` with generic names (`.settle`, `.fade`, `.control`) unless the project
  already has such a system or the user asks for one.
- **Put helpers in the edited file, private.** Write values inline, or add a `private extension TheirView` at the
  bottom of the file with only the helpers the gesture calls (`release`, `shouldCommit`, `rubberband`, ...). Members
  of the view can't collide with anything else in the module. The helper set is in `references/physics.md` §1.
- **Reuse what exists.** If the project already defines motion tokens or physics helpers, use them.
- **Don't change behaviour nobody asked about.** A toast's lifetime, a card's size, padding, colours, copy: leave
  them, and suggest the change in your reply. Keep existing non-gesture paths (a Close button) working.
- **The recipes in `references/recipes.md` are single-file drop-ins** built this way. Adapt one to the user's
  types and layout rather than pasting it beside them.

## 1. Check for a system component first

Doing a sheet gesture right means momentum-based dragging, overlay opacity matched to drag progress,
velocity-aware dismissal, scroll hand-off, focus and VoiceOver. That is weeks of edge cases, not an afternoon.
A system component carries Apple's tuned timing, Reduce Motion handling, haptics and accessibility. Stop at the
first row that fits:

| Need | Use | iOS |
|---|---|---|
| A sheet with detents | `.sheet` + `.presentationDetents([.medium, .large, .height(h), .fraction(f)], selection:)` + `.presentationDragIndicator(.visible)` | 17 |
| A map-style sheet with the screen behind still live | `.presentationBackgroundInteraction(.enabled(upThrough: .medium))`. The default content interaction already grows the sheet before scrolling, as Maps does | 17 |
| Sheet content that should scroll before the sheet grows | `.presentationContentInteraction(.scrolls)` | 17 |
| Block an accidental swipe-dismiss | `.interactiveDismissDisabled(hasUnsavedChanges)` | 17 |
| Card or thumbnail → detail, swipe down to close | `.navigationTransition(.zoom(sourceID:in:))` + `.matchedTransitionSource(id:in:)` **(iOS 18)** | 18 |
| Row swipe actions | `.swipeActions` in a `List`; outside `List` with `.swipeActionsContainer()` **(iOS 27)** | 17 |
| Reordering | `List` + `ForEach.onMove`; stacks and grids with `.reorderable()` + `.reorderContainer(for:)` **(iOS 27)** | 17 |
| Paging or a snapping carousel | `.scrollTargetBehavior(.paging / .viewAligned)` + `.scrollTargetLayout()`. Never a `DragGesture` carousel | 17 |
| Pinch, rotate | `MagnifyGesture`, `RotateGesture` (not the deprecated `MagnificationGesture` / `RotationGesture`) | 17 |
| Pull to refresh, back swipe, sliders, menus | `.refreshable`, `NavigationStack`, `Slider`, `.contextMenu` | 17 |

Zoom transitions: key the source by a stable model ID, and don't branch on "in transition" (an interrupted push
completes and becomes a pop). Whether zoom adapts to Reduce Motion isn't documented; check on a device.

Hand-roll only a bespoke interaction: an inline card that isn't a presentation, a viewer you pull down on an
iOS 17 target, a swipe-card deck, a drawer embedded in a screen. Say in one line why the system component
didn't fit. When the best answer is "use the system component" but the user asked to fix or extend their custom
one, say so, and still give the minimal corrected custom version: some teams keep custom motion on purpose.

## 2. Two phases: track, then release

```
Finger down → TRACK:   position = start + translation, 1:1. No easing, no duration, no spring.
Finger up   → RELEASE: physics finishes. A spring started at the release velocity. Never a fixed ease, never keyframes.
```

This split is Apple's model for fluid interfaces; mixing the phases up is why most gestures feel wrong.

**Track phase.**

- **1:1 means 1:1.** Write the value in `onChanged` with no animation; a spring while tracking makes the view
  trail the finger like it's dragged through syrup. Strip ancestor animations with
  `.transaction { if dragStart != nil { $0.animation = nil } }`, keyed off a flag `onEnded` clears in the same
  update, not off `@GestureState` (its reset order relative to `onEnded` isn't documented).
- **Keep the grab offset.** `start + value.translation`, never `value.location` (the view would jump).
- **Measure in a stable space.** When the dragged view itself moves, use `DragGesture(coordinateSpace: .global)`
  or a named space. Local translation feeds back on itself and jitters.
- **No work in `onChanged`** beyond state writes. It fires at 60–120 Hz, against a frame budget of 8.3 ms at
  120 Hz. Haptics, analytics and model commits go in `onEnded` or on a derived `Bool` flip.

**Release phase.**

- **Finish with a spring that starts at the gesture's velocity, passed explicitly** (§9). A fixed-duration ease
  makes every fling land identically, which reads as fake.
- **Bounce means momentum.** A drag applies force, so a slight bounce on release to a free target feels physical;
  the same element closed by a button gets **zero** bounce. Apple treats bounce above ~0.4 as exaggerated for UI.
- **No keyframes, `phaseAnimator` or `repeatForever` on anything a gesture can touch**: they can't be caught.

The canonical shape, as it would sit in the user's file:

```swift
import SwiftUI

struct DraggablePanel: View {
    let stops: [CGFloat]                                   // layout inputs, e.g. [0, 300]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false           // only to detect a cancel
    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat?

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.background)
            .offset(y: offset)
            .transaction { if dragStart != nil { $0.animation = nil } }      // 1:1 while tracking
            .gesture(
                DragGesture(coordinateSpace: .global)                        // minimumDistance 10 = system slop
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        let start = dragStart ?? offset                      // captured once per drag
                        dragStart = start
                        offset = start + value.translation.height            // 1:1
                    }
                    .onEnded { value in
                        dragStart = nil
                        let v = value.velocity.height
                        let projected = offset + (v / 1000) * 0.998 / (1 - 0.998)    // where the throw would rest
                        let target = stops.min { abs($0 - projected) < abs($1 - projected) } ?? offset
                        let spring = reduceMotion ? settle : fling
                        withAnimation(release(spring, velocity: v, from: offset, to: target)) { offset = target }
                    }
            )
            .onChange(of: isDragging) { _, dragging in
                guard !dragging, let start = dragStart else { return }      // cancelled: onEnded never ran
                dragStart = nil
                withAnimation(.spring(settle)) { offset = start }
            }
    }
}

private extension DraggablePanel {
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }
    var fling: Spring { Spring(duration: 0.3, bounce: 0.2) }

    /// Starts the spring at the finger's speed. SwiftUI wants it relative: pt/s ÷ remaining distance.
    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }
}
```

## 3. Where state lives: `@State` or `@GestureState`

- **`@State` for anything the release animates to a target.** Write it in `onChanged`, animate it in `onEnded`
  with the release velocity.
- **`@GestureState` for transient values that should just spring home** (a peek offset, an "is pressing" flag).
  It resets on end **and on cancel**, and `onEnded` does *not* run on cancel. Animate the reset with
  `resetTransaction`; it can't take the release velocity, so use `@State` when the return should keep the throw.
- **Use both for cancel safety.** Keep the value in `@State`, add `@GestureState var isDragging`; when it flips to
  false while `dragStart` is still set, the system cancelled the drag (a call, Notification Center, a parent
  gesture): settle home. This assumes `onEnded` runs first, which Apple doesn't document; if a normal release ever
  snaps home on a device, defer the check one turn (`references/recipes.md` §2).
- **Keep per-frame state in the leaf view**, never in an `@Observable` model or environment value many views read.

## 4. Choose the target by where the gesture is going

A thrown object should land where its momentum carries it, not at the stop nearest the release point (Apple's
projection idea from WWDC18). Project the resting point from the release velocity, then snap to the nearest stop:

```
project(v) = (v / 1000) · rate / (1 − rate)      rate 0.998 → 0.499 × v,   0.99 → 0.099 × v
```

- `0.998` matches `UIScrollView.DecelerationRate.normal`, 0.99 `.fast` (widely printed, not in Apple's docs).
- `predictedEndTranslation` is `translation + 0.25 × velocity` (about 0.996), so it throws half as far as
  `project()`: fine for a coarse "next page or not", not when the feel must match system scrolling.
- Skipping a stop on a hard flick is correct; a minimum-velocity gate on top adds a cliff. For 2D targets (a PiP
  corner), project each axis and pick the target nearest the projected point.

## 5. Commit or snap back: distance OR velocity

```
commit = (translation + project(velocity)) > 0.4 × travel        // in the dismiss direction
```

- **Travel** is the distance to fully gone: card height plus bottom safe area, toast height, card width.
- **The 40 % is a house guideline**, not an Apple number. One rule covers both halves: a short fast flick commits,
  a slow drag commits past 40 %, and a flick back cancels even past the threshold. Sign flips and worked values:
  `references/physics.md` §4.
- **Full-screen media** (pull a photo to dismiss): ~1000 pt/s **or** ¼ of the screen height instead, reference
  values from a well-known media viewer.
- **Commit timing by consequence.** A lightweight effect may fire mid-gesture; a destructive one commits only on
  release, and only once the finger itself has crossed the threshold: a quick reveal flick projects past 40 % of a
  row (`references/recipes.md` §10).

## 6. Release springs

House defaults, built on Apple's spring model (`Spring(duration:bounce:)`, bounce 0 unless momentum justifies a
little). The trigger, not the component, picks the damping: Apple's own Music player opens with no bounce from a
tap and closes with a little after a swipe.

| Release case | Spring | Value |
|---|---|---|
| Commit to a target with a hard edge behind it (off-screen, docked, a corner inset) | `settle` | `Spring(duration: 0.3, bounce: 0)` + clamp the rendered value if the edge is visible |
| Snap back below the threshold (the user didn't commit) | `settle` | same; overshooting rest would read as re-opening |
| Release from a rubber-banded overdrag | `settle` | same; a bounce would re-enter the overdrag zone |
| Snap to a free target with momentum (drawer to a detent, a floating card back to centre after a fling) | `fling` | `Spring(duration: 0.3, bounce: 0.2)` |
| Throw across the screen (PiP to a corner) | `reposition` | `Spring(duration: 0.4, bounce: 0)` |
| Swipe-to-delete slide-out, then remove | — | `Spring(duration: 0.25, bounce: 0)` to −width with the velocity, then removal in `.spring(duration: 0.3, bounce: 0)` |
| Hold-to-confirm: hold / early release | — | `.linear(duration: T)` / `.spring(duration: 0.2, bounce: 0)`; T = 0.5 s (the system long-press default), ~1–2 s for destructive |
| Tap-opened custom sheet / button close | — | `.spring(duration: 0.4, bounce: 0)` / `.spring(duration: 0.3, bounce: 0)` |
| Any release under Reduce Motion | `settle` | no throw overshoot |

**Clamping.** `.offset(y: min(y, bound))` clamps only the endpoints, and a fast throw overshoots a little even at
bounce 0. Clamp every frame with a geometry effect on the hard-edge side (`references/physics.md` §8), or let the
surface's background extend past the edge. Off-screen overshoot is invisible and needs neither.

## 7. Edges: rubber-band, never a wall

```
rubberband(x, d) = (|x| · d · c) / (d + c · |x|) · sign(x),   c = 0.55
```

- **x** is the signed overshoot past the bound, **d** the view or container dimension. c = 0.55 is
  community-derived from measuring `UIScrollView`, so overscroll matches the scroll views next to it.
- A hard stop under a moving finger (`max(0, translation)`) reads as a frozen phone; resistance says "there's
  nothing further". Apply it to the raw `start + translation` each frame; never feed the result back in.

## 8. Slop, axis lock and ScrollView conflicts

- **Slop is 10 pt**, the default `minimumDistance` of `DragGesture()` and the distance Apple describes iOS waiting
  before a touch becomes a drag. Leave it; taps and scrolls depend on it.
- **Lock the axis** the moment the slop is passed: `abs(dx) > abs(dy)` on the first `onChanged`, ignore the other
  axis until the gesture ends.
- **Press feedback is a `ButtonStyle`** (swift-motion-animate), never `DragGesture(minimumDistance: 0)`: it
  blocks scrolling and loses the button's accessibility.
- **Hit targets** are at least 44 × 44 pt (HIG). Grow the hit area with `.contentShape`, not the visual.

| Composition | Behaviour | Use it when |
|---|---|---|
| `.gesture(_:)` | Subview gestures win over this one. A drag on a child can block the scroll view's pan | Not inside a scroll view |
| `.simultaneousGesture(_:)` | Both recognize | A drag inside a `ScrollView` that claims only the axis the scroll doesn't use (axis lock) |
| `.highPriorityGesture(_:)` | Yours wins, including over scrolling | Only on purpose; it takes scrolling away |
| `a.exclusively(before: b)` | Tries `a`, falls back to `b` | Double tap before single tap. A double tap delays single taps by ~0.5 s; pay that only where it exists |
| `LongPressGesture().sequenced(before: DragGesture())` | The drag starts only after a hold | Lift-to-reorder inside a scroll view |
| `.gesture(_:isEnabled:)`, same as `.gesture(_:including: enabled ? .all : .subviews)` | Toggles a gesture without changing view identity mid-drag | Disable pull-to-dismiss while zoomed |
| `DragGesture(inputKinds:)` **(iOS 27)** | Restricts input sources (`.directTouch`, `.pencil`, `.pointer`, ...) | A drag that should ignore the pointer or Pencil |
| `UIGestureRecognizerRepresentable` **(iOS 18)** | A real UIKit delegate (`gestureRecognizerShouldBegin`) | Axis lock still leaks scroll jitter. See `references/uikit-bridge.md` §D |

## 9. Velocity hand-off and interruption

The user must be able to throw a view and catch it again: the release spring starts at the finger's speed, and
nothing locks input while it settles.

- **Pass the velocity explicitly** for throws, dismissals, snap-backs and detent snaps:
  `withAnimation(release(settle, velocity: value.velocity.height, from: offset, to: target))`. Apple documents
  `interpolatingSpring`'s `initialVelocity` as *relative* (a fraction of the remaining change per second), so
  `release` divides pt/s by the remaining distance, falls back to a plain spring within 1 pt, and caps at ±30. Raw
  pt/s is the classic bug: the view rockets past its target.
- **Why not leave it to SwiftUI.** Apple documents that gesture callbacks set `Transaction.tracksVelocity` so a
  later animation *can* keep the velocity, but nothing in the code shows whether it did, and in a simulator
  measurement on iOS 26 a plain `withAnimation(.spring(...))` in `onEnded` started from rest while an explicit
  `initialVelocity` left at the finger's speed. Explicit is visible in review, survives moving the write into a
  view model, and is the formula UIKit uses too. More in `references/physics.md` §7.
- **It carries to linked values and per axis.** A scrim derived from the offset animates in the same transaction
  with the same relative start. For 2D throws keep `x` and `y` separate (two `.offset`s, one `withAnimation` each).
- **Retargeting** (Apple): `spring` *replaces* an in-flight spring and carries its velocity; `interpolatingSpring`
  *adds* to it; timing curves carry nothing. Button-driven changes use a plain `.spring(...)`.
- **Never lock input during a settle.** No `.allowsHitTesting(false)`. An *animated* re-trigger (a tap mid-settle)
  retargets from where the eye is; it never restarts from zero.
- **Catching mid-flight is the exception.** `@State` holds the *target*, so a drag that grabs a view mid-settle
  measures from where it was heading. Writing in `onChanged` through `withAnimation(.interactiveSpring())` turns
  the jump into a ~0.15 s glide, but the view still ends up at old target + finger delta
  (`references/recipes.md` §11). For an exact catch, use `UIViewPropertyAnimator.stopAnimation(true)`
  (`references/uikit-bridge.md` §A).

## 10. Linked values: one source of truth

The dragged element is rarely alone: a scrim fades, the page behind scales, a corner radius grows. Derive them all
from the same drag progress in `body`:

```
let p = min(max(y / (containerHeight / 2), 0), 1)    // 0 at rest, 1 at half the height
Color.black.opacity(1 - p)                           // follows the finger and the release spring
```

Two separate animations drift apart the moment a gesture is interrupted; one source can't. The whole component
then moves as one entity.

- **Fade over a distance the eye can follow.** A full-screen photo or card fades its backdrop over about half the
  container height, so the dismissal is visible as it builds; one gone after 80 pt reads as a switch. Chrome (a
  close button) can fade over ~50 pt; a bottom card fades its scrim over its own height. Optionally scale the card
  down a little (to about 0.86 over the same distance), dropped under Reduce Motion.

**Spatial consistency.** An element dismisses in the direction it entered. A toast that slides down from the top
is swiped up to dismiss. A gesture that dismisses along an axis the element never moved on has to be learned;
one that reverses the entrance is *felt*.

## 11. Haptics

Fire a haptic on the same state change that drives the visual, on the same frame, once per user action. Never as
the only feedback: many people have haptics off (HIG). The mapping below is a house guideline built on the
`SensoryFeedback` cases Apple provides.

| Moment | Feedback |
|---|---|
| A detent catches, a drag commits, an item snaps home or into a corner, a row lifts | `.impact(weight: .light)` |
| Two-stage threshold: armed → committed (full-swipe delete) | `.impact(weight: .light)` at arm, `.impact(weight: .medium)` at commit |
| A destructive action fires | `.impact(weight: .medium)` |
| A reorder slot is crossed, a custom picker or slider steps | `.selection` |
| Hold-to-confirm completes; an operation succeeds or fails | `.success` / `.error` (a destructive hold commits with `.impact(weight: .medium)`) |
| Dragged into alignment with a guide | `.alignment` |
| Impact that scales with the throw | `.impact(weight:intensity:)`, intensity 0…1 mapped from velocity |
| **(iOS 26)** Custom slider grabbed / released / hits min or max | `.press(.slider)`, `.release(.slider)`, `.selection(.minimum / .maximum)` |

- **Thresholds fire on a derived `Bool` flip with hysteresis**: arm at the threshold, disarm ~20 pt back, so a
  finger resting on the line doesn't buzz every frame. One direction only:
  `.sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new }`. Never call a haptic in `onChanged`.
- **Not from a completion handler** (it's ~0.3 s late), and **no duplicates**: system sheets, `.swipeActions`,
  `List` reordering, `Slider` and `Picker` already play theirs.
- **Silent on iPhone**: `.levelChange` (macOS), `.start` / `.stop` (watchOS), `.increase` / `.decrease` (watchOS,
  visionOS). Haptics stay on under Reduce Motion; budget a handful per app, not per screen.

## 12. Reduce Motion

`@Environment(\.accessibilityReduceMotion) private var reduceMotion`. Tracking is direct manipulation (the user is
producing the motion), so it stays.

- **Tracking: unchanged, 1:1. Every release: `settle`**, no `fling` (Apple: tighten springs, remove elasticity).
- **Drop motion derived from the drag** that isn't the travel itself: tilt, parallax, 3D, scaling the card or the
  page behind. Keep opacity changes that explain state (scrim, chrome fade).
- **Button-driven presentation and dismissal** of the same surface fade in place (`.easeOut(duration: 0.2)` with
  `.transition(.opacity)`), or the same motion shortened to 0.10–0.15 s with bounce 0 when a fade can't express it
  (a drawer changing detent).

## 13. Accessibility: every gesture needs a non-gesture path

VoiceOver, Switch Control, Voice Control and many people with motor impairments can't perform a precise drag.
Ship the alternative with the gesture:

| Gesture | Alternative |
|---|---|
| Swipe or drag to dismiss | A visible close button, plus `.accessibilityAction(.escape) { close() }` (the VoiceOver two-finger Z scrub) |
| Swipe card left / right | Visible buttons, plus `.accessibilityAction(named: "Like")` / `"Skip"` |
| Drawer detents | A tappable grabber that steps detents, plus `.accessibilityAdjustableAction` and a localized value |
| Swipe to reveal / delete | `.accessibilityAction(named: "Delete")` on the row; hide the revealed button from accessibility so it isn't announced twice |
| Drag to reorder | `.accessibilityAction(named: "Move up")` / `"Move down"`; `EditButton` with `List.onMove` |
| Hold to confirm | `.accessibilityAction { commit() }`; for an irreversible action, route it through a `confirmationDialog` |
| Throw to a corner | `.accessibilityAction(named: "Move to next corner")` |
| Auto-dismissing toast | `.accessibilityAction(named: "Dismiss")` and an `AccessibilityNotification.Announcement` |

## 14. Anti-patterns

- `.animation(.spring(), value: offset)` on the tracked value → the view lags the finger; no animation while
  tracking, animate only in `onEnded`.
- `withAnimation(.easeOut(duration: 0.3))` after a drag → every fling lands the same; `release(settle, velocity:...)`.
- `initialVelocity: value.velocity.height` (raw pt/s) → the view rockets past its target; divide by the remaining
  distance, guard near zero, cap at 30.
- `if value.translation.height > 200 { dismiss() }` → distance only; add `project(value.velocity.height)` and
  compare with 40 % of the travel.
- `offset = max(0, translation)` → a wall; rubber-band past the bound.
- A haptic in `onChanged` → a derived `Bool` trigger with hysteresis.
- Bounce on a release with no momentum (button close, snap-back against an edge) → `settle`.
- A hand-rolled sheet where `.sheet` + detents fit → the system sheet (plus the minimal fix if they keep theirs).
- `.highPriorityGesture` inside a `ScrollView` without a stated reason → `.simultaneousGesture` + axis lock.
- Scrim and offset as two separate animations → derive the scrim from the offset.
- A backdrop fully faded after a few dozen points of a full-screen pull → fade over about half the height.
- `onEnded` as the only cleanup → add the `@GestureState` cancel check.
- A full-swipe delete decided by projection alone → also require the finger to cross the threshold.
- A gesture with no button or accessibility action → add the non-gesture path.
- A new helper file or app-wide `Animation` extension for one gesture → private helpers in the edited file.
- Detecting a pause with a timer → detect it from deceleration (`references/physics.md` §10).

## 15. Output

Write the code first. Then a few lines at most, written for the user:

1. **Gate:** the system component considered and why the custom gesture is needed, or "used the system X".
2. **What it does:** how it tracks, what decides dismiss vs snap-back, how the release keeps the finger's speed,
   haptics, Reduce Motion and the non-gesture path.
3. **Suggestions** for anything outside the request worth changing (a lifetime, a layout value).
4. **Feel-check on device** (Release build, physical device, 120 Hz and 60 Hz, at 1× and in slow motion): slow
   drag vs flick, a reversal at release, a re-grab mid-settle, a drag inside a scroll view, a cancel mid-drag,
   Reduce Motion on. The Simulator and Debug builds hide hand-off problems and hitches.

**Write it in plain language.** The user hasn't read this skill: never cite its section numbers, reference file
names or internal labels. Say the reason instead ("a quick flick dismisses even from a short drag, because the
release adds where the throw would carry it"). Say "Apple's guidance" only for Apple's guidance, and call house
values guidelines ("a 40 % threshold is a good default").

Make the call: never present motion options as a menu. "Use the system sheet" and "this needs a device" are valid
answers. Don't pad this into a report. A spring that feels weird usually needs more damping (less bounce).

## Reference files

- **`references/physics.md`**: read it before writing any release logic. The private helper set, the math behind
  each helper, clamping, linked values, pause detection, and an optional shared motion system with unit tests.
- **`references/recipes.md`**: read it when building one of these; each is a single-file drop-in that typechecks.
  System sheet, drag-to-dismiss card, detent drawer (+ iOS 18 scroll hand-off), swipe-to-dismiss toast, photo
  viewer, swipe card, PiP throw, hold-to-confirm, drag-to-reorder, swipe to reveal / delete, softening a
  mid-settle grab, `@GestureState` peek, and the device feel-check list.
- **`references/uikit-bridge.md`**: read it when SwiftUI can't do the job: an exact mid-flight catch, UIKit springs
  with initial velocity, motion values shared with UIKit (iOS 18), recognizer gating against a scroll view (iOS 18).
