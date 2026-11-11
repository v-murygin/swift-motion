# Reduce Motion and haptics

Read this at steps 8 and 9 of the decision order, which means for every animation you write. Both ship in the
same change as the animation, never as a follow-up.

## Contents

1. Reading the settings
2. Reduce Motion replacement table
3. What to keep, what else to check
4. Reduce Motion code patterns
5. Haptics: event → `SensoryFeedback`
6. Haptic sync rules
7. When not to use haptics
8. Haptic code patterns

---

## 1. Reading the settings

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

UIKit: `UIAccessibility.isReduceMotionEnabled` plus `UIAccessibility.reduceMotionStatusDidChangeNotification`.
`@Environment(\.accessibilityPrefersCrossFadeTransitions)` is true when Reduce Motion **and** Prefer Cross-Fade
Transitions are on. It is iOS 26.4, so gate it with `#available`; before that, and in UIKit, read
`UIAccessibility.prefersCrossFadeTransitions`.

The system does **not** tone down your custom motion. Native components, Liquid Glass (its elasticity is removed
automatically) and system transitions adapt on their own; every app-authored animation needs its own branch.

Reduce Motion means **fewer and gentler, not zero.** Remove travel, depth, zoom, bounce and loops; keep the
opacity and colour changes that explain what happened.

## 2. Reduce Motion replacement table

The fade below is `.easeOut(duration: 0.2)`; the crossfade is `.easeInOut(duration: 0.2)`. Most rows are HIG
guidance (replace travel with fades, avoid zoom, depth, blur and repetitive motion); the 0.2 s values and the
error-shake row are this skill's guidelines.

| Original | Replace with |
|---|---|
| Slide / move / push / offset entrance | `.transition(.opacity)` with `.easeOut(duration: 0.2)` |
| Scale / pop / zoom-in entrance | `.opacity`, 0.2 s |
| Custom hero / `matchedGeometryEffect` travel | drop the match; crossfade with `.easeInOut(duration: 0.2)` |
| `.navigationTransition(.zoom)` | the plain push (`.automatic`), or `.crossFade` (iOS 27). Branch explicitly; don't rely on the system adapting the zoom. |
| Any bounce > 0 | bounce 0, same or shorter duration |
| Gesture tracking | **unchanged, 1:1**: the user is producing that motion |
| Gesture release / throw | `.spring(duration: 0.3, bounce: 0)`, no throw overshoot |
| 3D, `rotation3DEffect`, parallax, depth | static |
| Blur transitions (`.blurReplace`, animated `.blur`) | `.opacity` |
| Stagger / choreography | collapse: no delays, no travel, the group fades together. If the sequence *is* the explanation, step between frames. |
| Loops (`repeatForever`, a triggerless `phaseAnimator`, `keyframeAnimator(repeating:)`, `.symbolEffect` with `.repeat`, `.pulse` / `.breathe` with `isActive`) | stop; show a static end state |
| SF Symbol effects | `.symbolEffectsRemoved(reduceMotion)` for decorative ones; keep `.replace` content transitions |
| Error shake | no shake; tint / colour + the `.error` haptic |
| Opacity / colour changes that explain state | **keep** |
| Haptics | **keep**: they aren't motion |

Fallback ladder when unsure: (1) a 0.2 s crossfade → (2) the same motion shortened to 0.10–0.15 s, bounce 0 →
(3) instant.

**Insufficient branches** (these fail review):

- Swapping only the curve while keeping the same travel:

```swift
import SwiftUI

struct DrawerBranches: View {
    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Button("Toggle") {
                // Wrong: a different curve, the same slide.
                // withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) { isShown.toggle() }

                // Right: the animation and the transition both change.
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) { isShown.toggle() }
            }
            if isShown {
                Text("Drawer")
                    .transition(reduceMotion ? AnyTransition.opacity
                                             : .move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
```

- Removing all feedback (the state change must still be visible).
- Leaving a shimmer, pulse or idle loop running.

## 3. What to keep, what else to check

**Keep:** opacity and colour changes that explain a state change; the state change itself; haptics; system
component motion (it adapts by itself).

**Also check:**

- Reduce Transparency (`accessibilityReduceTransparency`): materials become solid.
- Increase Contrast (`colorSchemeContrast == .increased`).
- `accessibilityDimFlashingLights` and `accessibilityPlayAnimatedImages`.
- At any setting, avoid sustained oscillation near **0.2 Hz** (one cycle per 5 s) and large peripheral motion.

## 4. Reduce Motion code patterns

Pick the transition, the animation and any delay from one flag:

```swift
import SwiftUI

struct ReduceMotionPatterns: View {
    let items: [String]
    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Button("Show") {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) { isShown = true }
            }
            if isShown {
                Text("Banner")
                    .transition(reduceMotion ? AnyTransition.opacity
                                             : .move(edge: .bottom).combined(with: .opacity))
            }
            ForEach(Array(items.enumerated()), id: \.element) { i, item in
                Text(item)
                    .opacity(isShown ? 1 : 0)
                    .animation(reduceMotion ? .easeOut(duration: 0.2)
                                            : .spring(duration: 0.3, bounce: 0).delay(Double(min(i, 6)) * 0.04),
                               value: isShown)
            }
        }
    }
}
```

Spell the first branch of a transition ternary as `AnyTransition.opacity` so both branches resolve to one type.

**Hero that becomes a crossfade:** apply `matchedGeometryEffect` conditionally (`heroMatch` in recipe 9B of
`recipes.md`), so under Reduce Motion the two views just fade.

**Symbol effects that would loop:**

```swift
import SwiftUI

struct RecordingIndicator: View {
    let isRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "waveform")
            .symbolEffect(.variableColor.iterative, isActive: isRecording)
            .symbolEffectsRemoved(reduceMotion)
    }
}
```

An indefinite effect like this is allowed only while something real is ongoing (recording), never as idle decoration.

---

## 5. Haptics: event → `SensoryFeedback`

`.sensoryFeedback(_:trigger:)` is iOS 17 unless marked.

| Event | Feedback | iOS |
|---|---|---|
| A value ticks past a discrete step (picker, slider detent, segmented control, custom tab) | `.selection` | 17 |
| Snap into place, a sheet detent catches, a drag commits, an item snaps home | `.impact(weight: .light)` (or `.impact(flexibility: .soft)`) | 17 |
| A heavy object lands, a destructive action fires | `.impact(weight: .medium)` | 17 |
| Threshold armed → committed (two stages) | `.impact(weight: .light)` at arm, `.impact(weight: .medium)` at commit | 17 |
| A task succeeded / failed / completed with a warning | `.success` / `.error` / `.warning`. Task outcomes only: `.warning` doesn't mean "about to be destructive". | 17 |
| Dragged into alignment with a guide | `.alignment` | 17 |
| A drawn path or gesture completes | `.pathComplete` | 17.5 |
| A custom control's touch-down / touch-up, matching system controls | `.press(.button / .buttonIconOnly / .slider / .tab / .toggle)`, `.release(.slider)`. Opt-in: standard buttons have no press haptic. | 26 |
| A custom toggle on / off, a slider hits min / max | `.selection(.on / .off / .minimum / .maximum)` | 26 |
| Impact that scales with velocity | `.impact(weight:intensity:)` with `intensity` 0…1 mapped from the velocity | 17 |

**Silent on iPhone, so never use them for iOS UI:** `.levelChange` (macOS only), `.start` / `.stop` (watchOS
only). Apple lists `.increase` / `.decrease` for watchOS and visionOS only; don't rely on them for iPhone UI.
iPad has no Taptic Engine.

## 6. Haptic sync rules

1. **Same trigger as the visual, same frame.** Attach `.sensoryFeedback` to the very state change that drives
   the animation (the detent catching), never to the animation's completion. A haptic that lands 300 ms after
   the thing it confirms feels like a separate, unexplained event.
2. **One direction when the trigger toggles.** `.sensoryFeedback(.warning, trigger: showDelete)` fires on present
   *and* dismiss. Use the condition form `{ _, new in new }`, or the closure form returning `nil` to skip.
3. **Thresholds fire on a derived `Bool` flip**, with hysteresis (arm at the threshold, disarm about 20 pt
   back) so the haptic doesn't chatter, never from `onChanged` per frame. Building the drag itself belongs to
   `swift-motion-gestures`.
4. `.sensoryFeedback` prepares the generator for you. In UIKit, call `prepare()` at gesture begin or touch-down,
   not right before firing, and reuse generators.
5. **One per user action.** A staggered group gets zero or one haptic, never one per item.

## 7. When not to use haptics

- On scroll ticks, per frame, on every tap, on entrances the user didn't cause, at cold launch, on a new
  message arriving in the foreground.
- On system controls that already play one (`Toggle`, `Picker`, `Slider`, `.swipeActions`, detents of a system
  sheet). That's a duplicate.
- As the only feedback. Haptics are optional and often off; the visual must stand on its own.
- With a meaning other than the documented one (`.success` for a plain tap).
- As long-running patterns; prefer short transients. Haptics can disturb camera, gyro and microphone use.
- Budget: a handful of haptic moments per app, not per screen. If nobody would miss a haptic when it's switched
  off, cut it.
- Reduce Motion does **not** remove haptics.

"None" is a valid haptic decision; when you choose it, say why in one line ("none: the system `Toggle`
already plays one").

## 8. Haptic code patterns

```swift
import SwiftUI

enum SendStatus: Equatable { case idle, sending, sent, failed }

struct HapticPatterns: View {
    @State private var isArmed = false
    @State private var status: SendStatus = .idle
    @State private var savedCount = 0

    var body: some View {
        VStack {
            Text("Pull to arm")
                // Condition form: fire only when the value becomes true.
                .sensoryFeedback(.impact(weight: .light), trigger: isArmed) { _, new in new }

            Text("Send")
                // Dynamic form: choose the feedback from the new value, or nil for none.
                .sensoryFeedback(trigger: status) { _, new in
                    switch new {
                    case .sent: .success      // a task outcome; a send fired many times a day may drop to nil
                    case .failed: .error
                    default: nil
                    }
                }

            Button("Save") { savedCount += 1 }
                // Counter trigger: every success fires once.
                .sensoryFeedback(.success, trigger: savedCount)
        }
    }
}
```

**Velocity-scaled impact.** Map the release speed to `intensity`, so a gentle drop taps lightly and a hard throw
lands harder:

```swift
import SwiftUI

struct LandingHaptic: ViewModifier {
    let landings: Int
    let speed: CGFloat                  // pt/s at release
    let maxSpeed: CGFloat               // the fastest release you expect; tune it on a device

    func body(content: Content) -> some View {
        content.sensoryFeedback(.impact(weight: .medium, intensity: Double(min(speed / maxSpeed, 1))),
                                trigger: landings)
    }
}
```
