# Springs and timing

Read this when you need an exact value: which spring fits an interaction, what a spring parameter really
does, how long something may take, or how to convert a value someone handed you. If an interaction is missing,
take the closest row and say so; don't invent a new number.

**Where the numbers come from.** Section 1 is Apple's SDK behaviour and documentation, so state it as fact.
"Start at zero bounce" and "bounce comes from momentum" are Apple's WWDC guidance. The specific durations,
scales, ceilings and the toast lifetime in sections 3–6 are this skill's house guidelines: distilled from
WWDC talks, Apple's sample code and practitioner work, consistent with each other, and the first things to
tune on a device. When you explain one to a user, call it a guideline and give the reason ("a 0.3 s exit
keeps the menu out of the way"), never "Apple requires".

## Contents

1. API facts the values rely on
2. Optional: a shared token block, for teams that want a motion system
3. Bounce bands
4. Preset table by interaction
5. Fixed curves (only when a spring is not possible)
6. Durations and hard bars
7. Converting values you were handed

---

## 1. API facts the values rely on

| API | Exact values | iOS |
|---|---|---|
| `Animation.default` (and a bare `withAnimation {}`) | `spring(response: 0.55, dampingFraction: 1.0, blendDuration: 0)`, i.e. duration 0.55, bounce 0. Before iOS 17 it was `easeInOut`. | 17 |
| `.spring(duration:bounce:blendDuration:)` | defaults 0.5 / 0.0 / 0. Bounce runs −1…1: 0 is critically damped, < 0 overdamped, 1 undamped. | 17 |
| `.spring(response:dampingFraction:blendDuration:)` | defaults 0.5 / **0.825** / 0, about bounce 0.175. Not the same as `.default`. | 17 |
| `.smooth` / `.snappy` / `.bouncy` (`duration:extraBounce:`) | duration 0.5; base bounce **0 / 0.15 / 0.3**; `extraBounce` adds to the base. | 17 |
| `.interactiveSpring(response:dampingFraction:blendDuration:)` | 0.15 / 0.86 / 0.25 (about bounce 0.14). For finger-down retargeting. | 17 |
| `.interactiveSpring(duration:extraBounce:blendDuration:)` | duration 0.15, base bounce **0.15** (`extraBounce`, default 0, adds to it), blendDuration 0.25 | 17 |
| `.interpolatingSpring(duration:bounce:initialVelocity:)` | 0.5 / 0 / 0. Overlapping ones **add**. `initialVelocity` is **relative**: a fraction of the change per second, not pt/s. | 17 |
| Retargeting | A new `spring` on the same property **replaces** the running one and carries its velocity. `interpolatingSpring`s **add**. Timing curves don't merge: they combine additively and carry no velocity. | 17 |
| What `duration` means | Perceptual, roughly the settle time; for very bouncy springs it is the period. Real settling takes longer and is unpredictable, so never wait on it. Completions fire at the perceptual end (`.logicallyComplete`). | 17 |
| `Spring` type | `init(duration:bounce:)`, `init(response:dampingRatio:)`, `init(mass:stiffness:damping:allowOverDamping:)`, `init(settlingDuration:dampingRatio:epsilon:)`; `.settlingDuration`, `value(target:initialVelocity:time:)`, `velocity(...)`. | 17 |
| UIKit parity | `UIView.animate(springDuration:bounce:initialSpringVelocity:...)` (17), `UISpringTimingParameters(duration:bounce:)` (17), `UIView.animate(_: SwiftUI.Animation)` (18, creates no CAAnimation). One spring model across frameworks. | 17 / 18 |

Everything in this table is available at the iOS 17 baseline. Elsewhere in this skill, anything newer is marked
18, 26 or 27. The `@Animatable` macro needs the Xcode 26 toolchain but deploys back to the iOS 17 baseline.

---

## 2. Optional: a shared token block

**Default: don't add this.** When you edit a user's view, write the value inline
(`.spring(duration: 0.3, bounce: 0)`) or, if one value repeats inside the file, as a `private` constant there.
Every recipe and snippet in this skill does that, so none of them depends on this block.

Add the block only when the user asks for a motion system or consistent motion across the app, or when the
project already has one and you are extending it. Reasons to hold back: `static let fade` or `.control` on
`Animation` are generic names that collide with existing extensions and packages, they silently become app-wide
vocabulary nobody agreed on, and they add a file to a change that was about one view.

When it is wanted: if the project already has motion constants, map onto them instead of adding a second set;
two vocabularies for one intent is how an app ends up animating the same interaction three ways. Otherwise keep
one copy per app, in its own file (for example `Animation+Tokens.swift`), and search the project for
`static let pressDown` first. If it's there (the swift-motion skills share this block), reuse it and add only
what's missing; a second copy fails to compile with "invalid redeclaration". The names below are also the
shorthand this skill uses for each value in prose.

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
```

`GesturePhysics` is used by gesture-driven motion (the `swift-motion-gestures` skill); keep it in the same file
so both skills share one source of truth.

---

## 3. Bounce bands

Choose the duration first (pacing), then the bounce (character). Start every spring at zero.

| Bounce | Feel | Use |
|---|---|---|
| 0 | smooth, long tail | **Default.** Every tap-, button- or programmatically-driven motion. The most versatile; use it when unsure. |
| ~0.15 | brisk tail, not visibly bouncy | Allowed for small controls when the app's character is "precise" (`.snappy`). Not the default. |
| 0.2 | a little squish | **Gesture release with momentum** (flick, throw, drag release to a free target). Music's Now Playing is opened by a tap with full damping and dismissed by a swipe with 80 % damping: the trigger, not the component, picks the damping. |
| 0.3 | noticeably bouncy | Rare / first-time delight only (`.bouncy`). |
| > 0.4 | exaggerated | **Never** on a UI element. |

Smaller elements read bounce less, so a tiny playful element may sit at the top of its band; it still never
exceeds 0.4. Ignore advice like "bounce 0.15–0.25 for most UI": a tap carries no momentum, so a tap-opened
panel that wobbles reads as broken.

---

## 4. Preset table by interaction

Prefer the native component in the first column whenever it fits; the values are for the custom case.

| Interaction | Value | Properties | iOS | Why |
|---|---|---|---|---|
| **Press down** (custom `ButtonStyle`) | `.spring(duration: 0.15, bounce: 0)` | `scaleEffect(0.97)`; optional `opacity(0.85)` only for glyph-only buttons | 17 | The highlight must start on touch-down and be near-instant (90 % done at ~90 ms). 0.97 is the 3 % ceiling for frequent controls. |
| **Press up** (release) | `.spring(duration: 0.3, bounce: 0)` | back to 1.0 | 17 | Respond instantly, animate the release (the Calculator pattern). A tap carries no momentum, so no bounce. |
| Press scale for large cards | `scaleEffect(0.97)`; range 0.96–0.98, never below 0.95 | | 17 | Big surfaces read a 3–4 % dip clearly. |
| iOS 26 glass buttons | `.buttonStyle(.glass)` / `.glassProminent`, `.glassEffect(.regular.interactive())`, **no extra scale** | system | 26 | Glass already scales, bounces and shimmers on touch. |
| **Toggle / chip / small state** (custom only) | `.spring(duration: 0.25, bounce: 0)` | offset / opacity / colour | 17 | Tap-driven, so fully damped. Prefer the native `Toggle`. |
| **Popover / menu present** (custom only) | `.spring(duration: 0.3, bounce: 0)`; `.scale(scale: 0.95, anchor: <trigger side>).combined(with: .opacity)` | scale + opacity, anchored | 17 | Grows from its trigger. Prefer native `Menu` / `.popover` (they morph from their source on iOS 26). |
| **Popover / menu dismiss** | `.spring(duration: 0.2, bounce: 0)` | same transition, reversed | 17 | Exits are faster than entrances. |
| **Sheet present** (custom drawer only) | `.spring(duration: 0.4, bounce: 0)`; `.transition(.move(edge: .bottom))` | offset by its own height | 17 | Tap-opened drawer: full damping. Use `.sheet` + detents whenever possible. |
| **Sheet dismiss by button** | `.spring(duration: 0.3, bounce: 0)` | | 17 | No force applied, no bounce; about 25 % faster than present. |
| **Sheet dismiss / snap after a drag** | velocity hand-off; build it with `swift-motion-gestures` | | 17 | |
| **Modal overlay card** (custom, centred) | `.spring(duration: 0.35, bounce: 0)`; card `.scale(scale: 0.96).combined(with: .opacity)` + backdrop `.opacity` **in the same transaction** | | 17 | Modals stay centred (the origin rule doesn't apply). |
| **Push** | system `NavigationStack` push (about 0.35 s). **Never override.** | system | 17 | Platform convention; keeps the interactive back swipe. |
| **Zoom** (card → detail, button → sheet) | `.navigationTransition(.zoom(sourceID: id, in: ns))` on the destination root + `.matchedTransitionSource(id: id, in: ns)` on the source | system spring | 18 | Continuously interactive, system-tuned. |
| **Cross-fade presentation** | `.navigationTransition(.crossFade)` | opacity | 27 | The sheet fades in over the content. |
| **Toast / banner enter** | `.spring(duration: 0.4, bounce: 0)`; `.move(edge: .top).combined(with: .opacity)` (or `.bottom` when anchored to a bottom action) | offset + opacity | 17 | A spring, so a dismissal that starts mid-entrance reverses from where the toast is. |
| **Toast exit** | `.spring(duration: 0.3, bounce: 0)`, same edge | | 17 | About 20 % faster; the same path makes swipe-to-dismiss obvious. |
| Toast lifetime | For a new toast, 4 s (a guideline); pause while `scenePhase != .active`; post an accessibility announcement; a toast with an action stays until acted on or dismissed. **When editing, keep the lifetime the code already has** and suggest a change in a line if it seems too short. | | 17 | Apple's HIG asks you to keep time-limited UI to a minimum. Lifetime is behaviour, not motion. |
| **List / stack insert and remove** | `withAnimation(.spring(duration: 0.3, bounce: 0))`; custom stacks: `.transition(.opacity.combined(with: .scale(scale: 0.95)))` | opacity + small scale; siblings reflow in the same transaction | 17 | The exiting item frees its space immediately. |
| **Accordion / expand** | prefer `DisclosureGroup`. Custom: `.spring(duration: 0.3, bounce: 0)` + `.clipped()` | height (a sanctioned layout exception), small subtree only | 17 | |
| **Numeric change** | `.contentTransition(.numericText(value: n))` + `.monospacedDigit()`, changed inside `withAnimation(.spring(duration: 0.3, bounce: 0))` | content transition | 17 | Needs an animation in the transaction. **Bounce must be 0**: overshoot rolls the digits back toward the old value. |
| **Symbol swap** | `.contentTransition(.symbolEffect(.replace))` (17); `.replace.magic(fallback:)` (18) | | 17 / 18 | |
| **Content swap in place** | `.transition(.blurReplace)` or `.contentTransition(.interpolate)`; `.spring(duration: 0.3, bounce: 0)` | | 17 | The native form of a blur-masked crossfade. |
| **Error shake** | `keyframeAnimator(initialValue: 0, trigger: attempts)` on `offset(x:)`: `CubicKeyframe(-8, duration: 0.08)`, `CubicKeyframe(8, duration: 0.08)`, `CubicKeyframe(-5, duration: 0.08)`, `SpringKeyframe(0, duration: 0.16, spring: Spring(duration: 0.16))` (about 0.4 s); with `.sensoryFeedback(.error, trigger: attempts)`. SF Symbol: `.symbolEffect(.wiggle, value:)` (18) | offset x (RTL-neutral) | 17 | No source publishes these numbers; tune them on a device. Cubic keyframes pass through each offset exactly; a `SpringKeyframe` with its default 0.5 s spring reaches only about ±2 pt in a 0.08 s segment. One-shot keyframes are fine here because a submit can't re-trigger faster than the shake plays. Reduce Motion: no shake; tint + haptic. |
| **Success** (rare tier) | `.symbolEffect(.bounce, value: done)` + `.sensoryFeedback(.success, trigger: done)`; drawn check mark: `trim` the square with `.timingCurve(0.645, 0.045, 0.355, 1, duration: 0.6)`, the check with `duration: 0.4` starting at 0.5 s; celebration springs may use `.bouncy` (bounce 0.3) | | 17 | Cause → effect, with the hand-off overlapping slightly. |
| **Hold to confirm** | while pressed: `.linear(duration: T)` on progress; early release: `.spring(duration: 0.2, bounce: 0)` back to 0; commit: `.sensoryFeedback(.success)` (`.impact(weight: .medium)` when the action is destructive). T = 0.5 s (the system long-press default) unless the action is destructive; then the fill itself is the safety, about 1–2 s | mask / fill width | 17 | Linear because the fill shows time. Asymmetric on purpose: slow where the user decides, fast where the system responds. The destructive length is a starting point to tune. |
| **Gesture release** | build with `swift-motion-gestures` | | 17 | |
| **Tab / segment indicator** (custom only) | `Capsule().matchedGeometryEffect(id: "pill", in: ns)`, `.spring(duration: 0.3, bounce: 0)`; `.sensoryFeedback(.selection, trigger: selection)` | x + width (the childless-pill exception) | 17 | Tens/day, so keep it subtle. Prefer `Picker(.segmented)`. |
| **Liquid Glass morph** | `GlassEffectContainer(spacing:)` + `.glassEffectID(id, in: ns)`; state change in `withAnimation(.smooth)` (0.5, bounce 0). `.glassEffectTransition(.matchedGeometry)` (the default, within spacing) / `.materialize` (farther apart) | system-rendered | 26 | The system provides the glass elasticity, so never add bounce on top. `.smooth` (0.5, bounce 0) names a critically damped spring close to the system default (0.55, bounce 0); feel-check the morph on a device. |
| **Opacity / colour only** | `.spring(duration: 0.2, bounce: 0)` or `.easeOut(duration: 0.15)` | | 17 | Effects settle faster than spatial motion, always critically damped. |
| **Hover** (iPad / Mac pointer) | `.hoverEffect(.highlight / .lift)`; custom colour `.easeInOut(duration: 0.15)` | colour / opacity | 17 | Never the only affordance. |
| **Determinate progress / spinner / marquee** | `ProgressView` / `Gauge`; custom `.linear(duration:).repeatForever(autoreverses: false)` | | 17 | Linear only for constant processes. |

---

## 5. Fixed curves (only when a spring is not possible)

Use a timing curve only for UIKit / Core Animation parity, opacity-only changes, constant processes, or a
deliberately fixed-length beat that is never re-triggered mid-flight. Everything else is a spring, because
only springs keep velocity continuous when something interrupts them.

| Token | Value | Use |
|---|---|---|
| strong ease-out | `.timingCurve(0.23, 1, 0.32, 1, duration: d)` | entrances / exits when a spring can't be used. Stronger than the built-in `.easeOut`. |
| on-screen move | `.timingCurve(0.77, 0, 0.175, 1, duration: d)` | A → B repositioning without a gesture |
| line drawing | `.timingCurve(0.645, 0.045, 0.355, 1, duration: 0.6)` | `trim`-based strokes |
| iOS-sheet curve | `.timingCurve(0.32, 0.72, 0, 1, duration: 0.5)` | the web's imitation of the iOS sheet. **Never needed natively**: use `.sheet`. |
| **Never** | `.easeIn` on any appearance, press or response | It starts slowly, delaying the very moment the user is watching. |

---

## 6. Durations and hard bars

| Scale | Fixed curve | Spring `duration` |
|---|---|---|
| Press feedback | 0.10–0.15 s | 0.15 (down) / 0.3 (up) |
| Small control state | 0.15–0.20 s | 0.25 |
| Popover / menu / list change | 0.20 s | 0.3 (exit 0.2) |
| Sheet / drawer / toast / modal | 0.25–0.30 s | 0.35–0.4 (exit 0.3) |
| Screen transition | system | system (about 0.35 s push) |
| Rare / onboarding | ≤ about 1 s | ≤ 0.6 |

Frequency budgets (from the decision order): **tens/day** → fixed curves ≤ 0.15 s, springs `duration ≤ 0.25` with
bounce 0 for the response to a touch, opacity / scale changes ≤ 3 %. The 0.3 s springs used in this tier (a press
release, a digit roll, an indicator pill) are within budget because the user already has
the answer on the first frame; the spring only animates the way there. **Occasional** → component springs ≤ 0.35, screen / sheet springs ≤ 0.5.
**Rare** → up to about 1 s, still interruptible and skippable.

Review thresholds (house guidelines, not Apple rules): a fixed-curve UI animation over 0.3 s, a component spring over 0.35, or a screen-scale spring over
0.5 needs a stated reason. `.easeInOut(duration: 0.5)` or longer on a control is a defect. The ceilings exist
because people wait through every millisecond of a frequent animation; a value that feels luxurious in a demo
is drag by the tenth repetition.

---

## 7. Converting values you were handed

Convert, then snap to the nearest value in the preset table. Keep the converted value only for a deliberate one-off, and say why.

| Given | SwiftUI |
|---|---|
| `{ duration, bounce }` (Motion, Apple design tools) | `.spring(duration:bounce:)`, 1:1. It is the same model. |
| `response`, `dampingFraction` | for bounce ≥ 0: `duration = response`, `bounce = 1 − dampingFraction` (so `dampingFraction: 0.8` is `bounce: 0.2`) |
| `{ mass, stiffness, damping }` | `.spring(Spring(mass:stiffness:damping:))` for UI state, because it replaces and carries velocity when re-triggered; `.interpolatingSpring(mass:stiffness:damping:initialVelocity:)` only when you want overlapping runs to add. Check the damping ratio: `Spring(mass: 1, stiffness: 100, damping: 10)` is duration 0.63, bounce 0.5, far too bouncy for UI. |
| CSS `cubic-bezier(a, b, c, d)` + ms | `.timingCurve(a, b, c, d, duration: s)`, in **seconds** |
| A web ease-out of duration T | a spring with `duration ≈ 1.5 × T`, bounce 0 (a 200 ms dropdown ≈ `.spring(duration: 0.3, bounce: 0)`), then feel-check |

Spring maths, with mass 1:

```
stiffness     = (2π / duration)²
damping       = 4π(1 − bounce) / duration        (bounce ≥ 0)
damping       = 4π / (duration · (1 + bounce))   (bounce < 0)
dampingRatio  = damping / (2·√(stiffness·mass))
```

Sanity check: `Spring(duration: 0.5, bounce: 0.3)` gives stiffness 157.9 and damping 17.6.

**Why a spring "looks shorter" than its duration.** A critically damped spring with `duration D` is about 50 %
done at 0.26 D, 90 % at 0.62 D, 95 % at 0.76 D and 99 % at 1.06 D. So `.smooth` (0.5) looks like a roughly
300 ms ease-out, which is where the 1.5 × rule comes from.
