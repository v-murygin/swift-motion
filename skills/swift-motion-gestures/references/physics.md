# Gesture physics

The math behind every release decision: the helpers to copy, then the reasoning for each one.
Read this file whenever you write release logic (snap, commit, dismiss, rubber-band, velocity hand-off).

Everything here typechecks for an iOS 17 deployment target, in Swift 5 and Swift 6 language modes.

## Contents

1. [Helpers (copy what you use, privately)](#1-helpers-copy-what-you-use-privately)
2. [Projection](#2-projection)
3. [Snap-point selection](#3-snap-point-selection)
4. [Commit and dismiss: distance OR velocity](#4-commit-and-dismiss-distance-or-velocity)
5. [Rubber-banding](#5-rubber-banding)
6. [Slop, hysteresis and axis lock](#6-slop-hysteresis-and-axis-lock)
7. [Velocity hand-off](#7-velocity-hand-off)
8. [Clamping the rendered value](#8-clamping-the-rendered-value)
9. [Linked values](#9-linked-values)
10. [Detecting a pause](#10-detecting-a-pause)
11. [Optional: a shared motion system](#11-optional-a-shared-motion-system)

---

## 1. Helpers (copy what you use, privately)

Paste the members a gesture needs into the file you're editing, as a `private extension` of the view that owns
the drag. Members of the view can't collide with anything else in the module; a top-level `func project` or
`extension Animation { static let settle }` would, and it also changes the project's public vocabulary without
anyone asking. Copy only what the code calls: most gestures use four or five of these.

```swift
import SwiftUI

struct YourView: View {               // stands in for the view that owns the drag
    var body: some View { Color.clear }
}

private extension YourView {
    // Release springs. Same duration/bounce model as Animation.spring(duration:bounce:).
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }       // commit to a hard edge, snap back, Reduce Motion
    var fling: Spring { Spring(duration: 0.3, bounce: 0.2) }      // free target reached with momentum
    var reposition: Spring { Spring(duration: 0.4, bounce: 0) }   // throw across the screen

    /// A release spring that starts at the finger's speed. `velocity` is in pt/s; SwiftUI wants it
    /// relative to the remaining distance (fraction of the change per second), so convert, guard and cap.
    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }          // already there: nothing to carry
        let relative = min(max(velocity / distance, -30), 30)               // a tiny distance would explode it
        return .interpolatingSpring(spring, initialVelocity: Double(relative))
    }

    /// Distance (pt) a fling travels under UIScrollView-like deceleration.
    func project(_ velocity: CGFloat, rate: CGFloat = 0.998) -> CGFloat {
        (velocity / 1000) * rate / (1 - rate)
    }

    /// The stop nearest to where the gesture is going, not to where the finger lifted.
    func snapTarget(from position: CGFloat, velocity: CGFloat, points: [CGFloat]) -> CGFloat {
        let projected = position + project(velocity)
        return points.min { abs($0 - projected) < abs($1 - projected) } ?? position
    }

    /// Distance OR velocity in one rule. Pass values signed so that "toward the commit" is positive.
    func shouldCommit(translation: CGFloat, velocity: CGFloat, travel: CGFloat, fraction: CGFloat = 0.4) -> Bool {
        translation + project(velocity) > fraction * travel
    }

    /// UIScrollView-style resistance. x = signed overshoot past the bound, d = dimension.
    func rubberband(_ x: CGFloat, dimension d: CGFloat, c: CGFloat = 0.55) -> CGFloat {
        let m = abs(x)
        return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)
    }

    /// 1:1 inside `range`, rubber-banded outside it.
    func rubberbanded(_ value: CGFloat, in range: ClosedRange<CGFloat>, dimension d: CGFloat) -> CGFloat {
        if value < range.lowerBound { return range.lowerBound + rubberband(value - range.lowerBound, dimension: d) }
        if value > range.upperBound { return range.upperBound + rubberband(value - range.upperBound, dimension: d) }
        return value
    }

    /// Fire-once threshold: arm at `threshold`, disarm only `band` pt back.
    func isArmed(_ value: CGFloat, threshold: CGFloat, wasArmed: Bool, band: CGFloat = 20) -> Bool {
        wasArmed ? value > threshold - band : value >= threshold
    }

    /// Decide once, on the first onChanged (the 10 pt slop has already passed by then).
    func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }

    /// Drag progress clamped to 0...1, for linked values (scrim, scale, corner radius).
    func dragProgress(_ value: CGFloat, over distance: CGFloat) -> CGFloat {
        min(max(value / max(distance, 1), 0), 1)
    }

    /// Reports a size now and whenever it changes (iOS 17-safe). Use as `.background(sizeReader { ... })`.
    func sizeReader(_ action: @escaping (CGSize) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear.onChange(of: proxy.size, initial: true) { _, size in action(size) }
        }
    }
}
```

All inputs are points and points per second. `DragGesture.Value.velocity` (iOS 17) is a `CGSize` in pt/s, so pass
`.width` or `.height`.

- **The spring values are this skill's defaults**, chosen from Apple's spring guidance (bounce 0 unless momentum
  justifies a little; nothing above ~0.4 on UI) and tuned by feel. If the project already defines motion tokens,
  use those instead of adding these.
- **Inline is fine too.** A file with one release can write `Spring(duration: 0.3, bounce: 0)` at the call site.
  The goal is that the edit stays inside the file and reads on its own.
- **Name clash.** If the view already has a member called `project` or `settle`, rename the helper.

---

## 2. Projection

A thrown object shouldn't snap to the target nearest its release point. Project where it would come to rest
from its release velocity, then pick the target nearest that projection. The same idea works for position,
scale and rotation; Apple presents it in the WWDC18 talk "Designing Fluid Interfaces".

```
project(v) = (v / 1000) · rate / (1 − rate)
```

- **The rate.** 0.998 matches `UIScrollView.DecelerationRate.normal`; `.fast` is about 0.99. These raw values are
  widely printed but not stated in Apple's docs; check them on a device
  (`UIScrollView.DecelerationRate.normal.rawValue`) before you rely on an exact number.
- **The magnitude.** At 0.998 the projection is **0.499 × v**: a 1000 pt/s flick projects about 499 pt.
  At 0.99 it is **0.099 × v**. Pass `rate: 0.99` when the content should feel heavy or the stops are close
  together, as in a small picker.
- **The sign is preserved.** A downward flick projects downward and a flick back projects backward. That is what
  makes a reversing release snap home.
- **Don't use `v² / 2a`.** That textbook constant-deceleration model isn't what iOS uses; stops chosen with it
  feel wrong next to the scroll views beside them.

**`predictedEndTranslation` vs `project()`.** `DragGesture.Value.predictedEndTranslation` and
`predictedEndLocation` are SwiftUI's built-in projection. Apple's docs don't state the constant, but the SDK
defines `velocity` as `4 × (predictedEndLocation − location)`, so `predictedEndTranslation` is
`translation + 0.25 × velocity`: roughly a 0.996 rate, half what `project()` gives at 0.998. It therefore throws
noticeably shorter. Use `project()` when the feel must match system scrolling or the rate must be tunable;
`predictedEndTranslation` is fine for a coarse nearest-snap:

```swift
import SwiftUI

struct Pager: View {
    let lastPage: Int
    @State private var page = 0

    var body: some View {
        Text("Page \(page + 1)")
            .gesture(DragGesture().onEnded { value in
                // A coarse "next page or not" decision.
                let projected = value.predictedEndTranslation.width
                page = projected < 0 ? min(page + 1, lastPage) : max(page - 1, 0)
            })
    }
}
```

Real paging or snapping of scroll content is not a gesture problem at all: use `.scrollTargetBehavior(.paging)` or
`.viewAligned` with `.scrollTargetLayout()` (17), or a custom `ScrollTargetBehavior`. Never build a `DragGesture`
carousel.

---

## 3. Snap-point selection

```
target = the stop nearest to (position + project(velocity))
```

- **Project first, then take the nearest stop.** "Nearest to where the finger lifted" ignores the throw: a
  gentle flick from just below the middle would snap back instead of advancing.
- **Skipping stops is correct.** A hard flick from the top can project past the middle and land at the bottom,
  just as a scroll view coasts past content.
- **A minimum-velocity gate on top is usually a mistake.** Projection already scales smoothly from "no throw" to
  "big throw"; a gate adds a cliff the user can feel. Tune on a device before adding one.
- **Keep stops and position in one coordinate space.** Compute the stops once per `body` pass (from a
  `GeometryReader`) and pass them into the gesture.
- **Haptic on the catch, not the completion.** Attach `.sensoryFeedback(.impact(weight: .light), trigger: detent)`
  to the detent state you set in `onEnded`. That is the causal frame; the animation's completion is ~0.3 s late.
- **2D targets** (corners): project each axis separately and pick the target with the smallest distance to the
  projected point. See the PiP recipe in `recipes.md`.

---

## 4. Commit and dismiss: distance OR velocity

```
commit = (translation + project(velocity)) > 0.4 × travel      // in the dismiss direction
```

The 40 % is a house guideline (practitioners use 40–50 %), not an Apple number. Why one projected rule instead of
"distance > X || velocity > Y":

- **A short, fast flick commits.** A small translation plus a large projection crosses the line.
- **A slow, long drag commits** once its translation alone passes 40 %.
- **A flick back cancels, even past the threshold.** A negative projection pulls the sum back under the line,
  so the user can change their mind at the last moment. A distance-only rule ignores this.
- **Corroboration:** 0.4 × a 600 pt sheet = 240 pt, so a ~480 pt/s flick from rest commits.

**Travel** is the distance to fully gone:

| Interaction | Travel |
|---|---|
| Bottom card or custom sheet | card height + bottom safe-area inset |
| Toast swiped toward its edge | toast height |
| Swipe card, left or right | card width |
| Full-swipe delete on a row | row width, and the finger must itself cross the threshold (below) |

**Signs.** `shouldCommit` expects "toward the commit" to be positive. Flip both values when it isn't:

```
Top toast, dismissed upward (negative y):
  shouldCommit(translation: -offset, velocity: -velocity.height, travel: height)
Two-sided (swipe card): take the side from the projection, then apply the rule to signed values:
  side = x + project(velocity.width) >= 0 ? 1 : -1
  shouldCommit(translation: side * x, velocity: side * velocity.width, travel: width)
```

**Full-screen media viewers** (Photos-style pull to dismiss) use a different pair, because 40 % of the screen is
too far to drag a photo: commit if the vertical velocity away from the centre is above **~1000 pt/s**, **or** the
distance is past **¼ of the screen height**. These are reference values from a well-known messaging app's media
viewer, not Apple numbers; tune them on a device. The recipe is in `recipes.md`.

**Commit timing by consequence.** A lightweight effect (revealing a search field) may fire mid-gesture. A
destructive one commits only on release, so the user can still reverse. It also shouldn't rest on the full
0.998 projection: an ordinary reveal flick (40 pt at 600 pt/s) projects to 339 pt, past 40 % of a 390 pt row, and
would delete instead of opening. Require the finger's own travel to cross the threshold (the same `isArmed` flag
that plays the arm haptic), and keep the projected rule only so a flick back still cancels.

**Dropped alternatives.** A fixed pixel threshold, a fixed speed threshold, or an averaged web velocity each
ignore half of the gesture.

---

## 5. Rubber-banding

```
rubberband(x, d) = (|x| · d · c) / (d + c · |x|) · sign(x),   c = 0.55
```

- **x** is the signed overshoot past the bound, **d** is the dimension of the view or container, and
  **c = 0.55** is the constant that makes overscroll match system scroll views. It is community-derived from
  measuring `UIScrollView`, not documented by Apple.
- **Worked values** (d = 800): pull 50 → 26.6, 100 → 51.5, 200 → 96.7, 400 → 172.5. The result is bounded by
  d: a user can pull forever without the view escaping.
- **Near the bound** it moves at slope c, then resistance grows smoothly.
- **Choosing d:** the size of the thing that moves (card height, drawer container height, row width). A larger
  d gives a longer, softer stretch.
- **Stateless.** Apply it to the raw `start + translation` on every frame. Never feed a rubber-banded result
  back in; the resistance would compound.
- **The alternative** `sign · |x|^0.7` is much stiffer and independent of size. It's acceptable for standalone
  objects, but c = 0.55 matches the scroll views next to it, so prefer it.
- **Release from overdrag** with `settle` (bounce 0) back to the bound. A bounce would re-enter the overdrag zone.
- **Never hard-clamp** with `max(0, translation)`. A dead stop under a moving finger reads as a frozen phone.

---

## 6. Slop, hysteresis and axis lock

**Slop: 10 pt.** Apple describes iOS waiting about 10 pt before a touch becomes a drag, and `DragGesture()`
defaults to `minimumDistance: 10`. Leave it: taps and scrolling depend on it. The one exception is 0, for a control
that must respond on touch-down, such as a scrubber thumb. Even then, track *presses* with
`ButtonStyle.configuration.isPressed`, never a zero-distance drag (it blocks scrolling and loses the button's
accessibility).

**Axis lock.** Decide the axis the moment the slop is passed (`isHorizontal` on the first `onChanged`, stored in
`@State`), ignore the other axis until `onEnded`, then reset it. Inside a vertical `ScrollView`, claim only the
horizontal axis.

**Threshold hysteresis** (a house guideline). Arm at the threshold and disarm about **20 pt** back (`isArmed`).
Without the band, a finger resting on the line flips the state every frame, and every flip fires a haptic.
Recompute the Bool in `onChanged` (it's a cheap state write) and fire the haptic on its flip in one direction only:
`.sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new }`.

**Long press defaults** (Apple): `minimumDuration` 0.5 s, `maximumDistance` 10 pt. Drifting past 10 pt fails the
press, and `onPressingChanged(false)` reports it.

---

## 7. Velocity hand-off

**Pass the release velocity explicitly.** Every release that follows a drag (a throw, a dismissal, a snap-back,
a snap to a detent) uses `release(_:velocity:from:to:)` from §1, which builds
`.interpolatingSpring(spring, initialVelocity:)` with a *relative* velocity:

```
relative = velocity (pt/s) / (target − current) (pt)       guarded within 1 pt of the target, capped at ±30
```

Apple documents `initialVelocity` in units of the value being animated: a fraction of the change per second. A
1500 pt/s fling with 300 pt left is a relative velocity of 5, not 1500.

Why explicit rather than relying on SwiftUI:

- **Apple documents automatic tracking, but you can't see it or rely on it.** `Transaction.tracksVelocity` says
  gesture `onChanged` and `updating` callbacks track velocity so a later animation *can* preserve it. In practice a
  `withAnimation(.spring(...))` in `onEnded` has been observed to start from rest (a simulator measurement on
  iOS 26: identical first frames with and without tracking, while an explicit `initialVelocity` started at the
  finger's speed). An explicit value is visible in review, testable, and survives refactors that move the write out
  of the gesture callback.
- **No double push.** In the same measurement, an explicit `initialVelocity` after tracked writes moved exactly as
  it did after untracked writes. If a release on a device ever looks like it got twice the push, write the
  tracked value inside `withTransaction` with `tracksVelocity = false` and keep the explicit velocity.
- **It is one formula across frameworks.** UIKit's `UISpringTimingParameters(duration:bounce:initialVelocity:)`
  and `UIView.animate(springDuration:bounce:initialSpringVelocity:...)` take the same relative value.
- **Linked values inherit it.** A scrim or scale derived in `body` from the same offset interpolates over the same
  transaction, so it gets the same relative start and stays in step.

**The guard and the cap.** Within 1 pt of the target there is no distance to divide by, so `release` falls back to
a plain spring. The cap of 30 stops the spring from exploding when the remaining distance is tiny.

**Overshoot at bounce 0.** A critically damped spring still passes its target when the relative velocity is larger
than about 2π / duration (≈ 21 for 0.3 s). At the cap it overshoots by under 2 % of the distance: invisible
off-screen, a couple of points at rest. Where even that shows against a visible edge, clamp (§8).

**How retargeting merges** (Apple): `spring` animations *replace* an in-flight spring on the same property and
carry its velocity; `interpolatingSpring` animations *add* to it; timing curves carry nothing. A release with
`interpolatingSpring` therefore combines with whatever was still moving, which is what a re-thrown view should do.
A button-driven change uses a plain `.spring(...)`.

**2D throws.** A scalar `initialVelocity` applies to the whole animated value, and a diagonal has a different
relative velocity on each axis. Keep `x` and `y` as separate state, render them with two `.offset` modifiers, and
release each in its own `withAnimation`.

**Non-gesture streams** (a slider value, a server-driven position): keep the last sample's speed yourself and pass
it the same way. Apple's documented alternative is `tracksVelocity = true` on the intermediate changes and an
animation on the final one (the two are mutually exclusive in one transaction); check on a device that it carries.

**Pre-iOS-17 fallbacks** such as `(predictedEnd − location) / 100` have the wrong units. Don't use them.

---

## 8. Clamping the rendered value

When a release commits to a target with a **visible hard edge** right behind it (a panel docked against a screen
edge, an element in a corner inset), overshoot past the edge flashes a gap. Clamp the *rendered* value on every
frame with a geometry effect, kept private to the file:

```swift
import SwiftUI

/// An offset along one axis that is clamped on every animation frame, not only at the target.
private struct ClampedOffset: GeometryEffect {
    var value: CGFloat
    var range: ClosedRange<CGFloat>
    var axis: Axis = .vertical

    var animatableData: CGFloat {
        get { value }
        set { value = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let v = min(max(value, range.lowerBound), range.upperBound)
        return ProjectionTransform(axis == .vertical
            ? CGAffineTransform(translationX: 0, y: v)
            : CGAffineTransform(translationX: v, y: 0))
    }
}

struct DockedPanel: View {
    let travel: CGFloat                       // docked at y = travel against the bottom edge
    @State private var y: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            // Overshoot below `travel` would flash a gap, so clamp that side only.
            .modifier(ClampedOffset(value: y, range: -.infinity...travel))
    }
}
```

- `.offset(y: min(y, travel))` doesn't do this. SwiftUI interpolates the modifier's value, so `min` only clamps
  the start and end, and the spring can still overshoot in between.
- Clamp only the side with the hard edge. Don't narrow the range at release: `range` isn't part of
  `animatableData`, so a rubber-banded value of −30 would snap to the new bound in one frame and the settle from
  overdrag would never be seen.
- When the target is off-screen (a dismissal), overshoot is invisible and no clamp is needed.
- An alternative for surfaces anchored to an edge: let the surface's background extend past the edge, so a
  rubber-band or overshoot never shows a gap. The card recipe does this.

---

## 9. Linked values

The dragged element is rarely alone: a scrim fades, the page behind scales, a corner radius grows. Derive these
from the drag progress in `body`. Don't animate them separately.

```
p = dragProgress(offset, over: fadeDistance)
scrim opacity = maxDim · (1 − p)          // maxDim is the design's dim, not a motion value
```

One source of truth means the overlay is always exactly as faded as the surface is dismissed, including
mid-gesture, including when the user reverses. Two separate animations drift apart the moment a gesture is
interrupted. Because the drag value is tracked 1:1 and then animated by the release spring, everything derived from
it follows both for free.

- **Fade over a distance the eye can follow.** For a full-screen photo or card, fade the backdrop progressively
  over roughly **half the container height**, which is how a Photos-style pull feels: at the ¼-height commit point
  the backdrop is about half faded, so the user sees the dismissal coming. A backdrop that is fully gone after
  80 pt reads as a switch, not a fade. Small chrome (a close button, a caption) can fade faster, over the first ~50 pt, so it gets out of
  the way.
- **Optionally scale the card down a little**, to about 0.86 over the same distance, and round its corners: it reads
  as "going back to where it came from". This is a depth cue: drop it under Reduce Motion.
- Clamp the progress to 0...1 even when the offset rubber-bands past the bound.
- A bottom card or drawer can fade its scrim over its own travel (its height), since that is the whole dismissal.

**Details worth stealing** (ideas from well-regarded apps; tune the numbers on a device):

- **A slider drag survives leaving the track.** Keep tracking when the finger drifts off the control, and show the
  value above the finger, where the thumb would hide it.
- **The first touch owns the drag.** A second finger landing mid-drag shouldn't change what the first one is
  doing; check this on a device for any custom recognizer.
- **A gesture can carry spatial intent.** Let people drag an "add" button to the spot where the new item should
  go; the drop point decides where it's created.

---

## 10. Detecting a pause

Detect intent from velocity, never from a timer. Apple describes the Home gesture recognizing "the user paused"
from the finger decelerating, not after a fixed delay. A practical rule (reference values from a public
reimplementation of those demos): a pause is the speed dropping by more than 90 % across the last ~7 samples,
while |v| ≤ 100 pt/s and the offset is at least 50 pt.

```swift
import CoreGraphics

/// Feed it from onChanged (velocity in pt/s along the drag axis, offset in pt).
private struct PauseDetector {
    private var samples: [CGFloat] = []

    mutating func update(velocity: CGFloat, offset: CGFloat) -> Bool {
        samples.append(abs(velocity))
        if samples.count > 7 { samples.removeFirst() }
        guard samples.count == 7, let first = samples.first, first > 0, let last = samples.last else { return false }
        return last < first * 0.1 && last <= 100 && abs(offset) >= 50
    }

    mutating func reset() { samples.removeAll() }
}
```

Store it in `@State`, call `update` in `onChanged`, and drive any visual or haptic from the resulting Bool flip,
not from `onChanged` itself.

---

## 11. Optional: a shared motion system

Only when the project already has a motion system, or the user asks for one. Then keep **one** copy per app, shared
with the other swift-motion skills, and namespace the gesture helpers so they don't take generic global names. If
the project already has tokens under other names, map to those instead of adding a second set.

```swift
import SwiftUI

extension Animation {
    // Press
    static let pressDown   = Animation.spring(duration: 0.15, bounce: 0)
    static let pressUp     = Animation.spring(duration: 0.3,  bounce: 0)
    // Components
    static let control     = Animation.spring(duration: 0.25, bounce: 0)   // toggle, chip, small state
    static let popIn       = Animation.spring(duration: 0.3,  bounce: 0)   // popover, menu, list change, numbers
    static let popOut      = Animation.spring(duration: 0.2,  bounce: 0)
    // Surfaces
    static let surfaceIn   = Animation.spring(duration: 0.4,  bounce: 0)   // custom sheet, toast enter
    static let surfaceOut  = Animation.spring(duration: 0.3,  bounce: 0)   // button dismiss, toast exit
    static let modalIn     = Animation.spring(duration: 0.35, bounce: 0)
    // Gestures
    static let settle      = Animation.spring(duration: 0.3,  bounce: 0)   // commit to hard edge, snap back
    static let fling       = Animation.spring(duration: 0.3,  bounce: 0.2) // free target with momentum
    static let reposition  = Animation.spring(duration: 0.4,  bounce: 0)   // PiP-style throw
    // Effects
    static let fade        = Animation.easeOut(duration: 0.2)              // Reduce Motion substitute, opacity
    static let crossfade   = Animation.easeInOut(duration: 0.2)
    // Rare tier only
    static let celebrate   = Animation.bouncy                              // 0.5 s, bounce 0.3
}

enum Stagger {
    static let step = 0.04      // s
    static let cap  = 6         // index
    static func delay(_ i: Int) -> Double { Double(min(i, cap)) * step }
}

enum GesturePhysics {
    static let slop: CGFloat = 10
    static let decelerationRate: CGFloat = 0.998
    static let rubberBand: CGFloat = 0.55
    static let commitFraction: CGFloat = 0.4
    static let maxRelativeVelocity: CGFloat = 30
}

// MARK: - Gesture helpers, namespaced

extension GesturePhysics {
    static func project(_ velocity: CGFloat, rate: CGFloat = decelerationRate) -> CGFloat {
        (velocity / 1000) * rate / (1 - rate)
    }

    static func shouldCommit(translation: CGFloat, velocity: CGFloat, travel: CGFloat,
                             fraction: CGFloat = commitFraction) -> Bool {
        translation + project(velocity) > fraction * travel
    }

    static func rubberband(_ x: CGFloat, dimension d: CGFloat, c: CGFloat = rubberBand) -> CGFloat {
        let m = abs(x)
        return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)
    }

    static func relativeVelocity(_ v: CGFloat, from current: CGFloat, to target: CGFloat) -> Double {
        let distance = target - current
        guard abs(distance) >= 1 else { return 0 }
        return Double(min(max(v / distance, -maxRelativeVelocity), maxRelativeVelocity))
    }

    static func isArmed(_ value: CGFloat, threshold: CGFloat, wasArmed: Bool, band: CGFloat = 20) -> Bool {
        wasArmed ? value > threshold - band : value >= threshold
    }
}
```

`Animation` is `Sendable`, so the stored statics are fine under Swift 6. With the shared version in place, these
Swift Testing tests lock in the curves and numbers (replace `YourApp` with the module):

```swift
import Testing
import CoreGraphics
@testable import YourApp

struct GesturePhysicsTests {
    @Test func projectionKeepsSignAndScale() {
        #expect(GesturePhysics.project(0) == 0)
        #expect(abs(GesturePhysics.project(1000) - 499) < 0.5)              // 0.499 × v at 0.998
        #expect(GesturePhysics.project(-1000) == -GesturePhysics.project(1000))
        #expect(abs(GesturePhysics.project(1000, rate: 0.99) - 99) < 0.5)   // 0.099 × v at 0.99
    }

    @Test func rubberbandMatchesWorkedValues() {
        #expect(abs(GesturePhysics.rubberband(50, dimension: 800) - 26.6) < 0.1)
        #expect(abs(GesturePhysics.rubberband(400, dimension: 800) - 172.5) < 0.1)
        #expect(GesturePhysics.rubberband(100_000, dimension: 800) < 800)   // bounded by d
    }

    @Test func projectedCommitRule() {
        #expect(GesturePhysics.shouldCommit(translation: 40, velocity: 1500, travel: 400))     // short fast flick
        #expect(!GesturePhysics.shouldCommit(translation: 280, velocity: -2000, travel: 400))  // flicked back
        #expect(GesturePhysics.shouldCommit(translation: 0, velocity: 490, travel: 600))       // ~480 pt/s from rest
        #expect(!GesturePhysics.shouldCommit(translation: 0, velocity: 470, travel: 600))
    }

    @Test func relativeVelocityIsGuardedAndCapped() {
        #expect(GesturePhysics.relativeVelocity(1500, from: 0, to: 300) == 5)
        #expect(GesturePhysics.relativeVelocity(1500, from: 299.5, to: 300) == 0)
        #expect(GesturePhysics.relativeVelocity(5000, from: 0, to: 10) == 30)
    }

    @Test func hysteresisBand() {
        #expect(GesturePhysics.isArmed(100, threshold: 100, wasArmed: false))
        #expect(GesturePhysics.isArmed(85, threshold: 100, wasArmed: true))     // inside the 20 pt band
        #expect(!GesturePhysics.isArmed(79, threshold: 100, wasArmed: true))
    }
}
```

The projection tests assume a rate of 0.998. If you switch to reading `UIScrollView.DecelerationRate.normal` at
runtime, print its `rawValue` before changing the numbers.
