# Motion standards: the full checklist

Every checklist ID from SKILL.md with its rule, the reason, a default severity and wrong → right SwiftUI code. Baseline is iOS 17; later APIs are marked.

The IDs (A1, J3…) and the section names here are for finding your way in this file. They never appear in what the user reads: explain the problem itself instead.

Default severity is a starting point. Move it up one level on 100+/day or tens/day surfaces, down one level in the rare tier. A2, A3 and G2 already encode their frequency, so they never move.

**How to read the snippets.** Every snippet writes its values out (`.spring(duration: 0.3, bounce: 0)`), so a fix can be pasted into a project that has no motion system. When the project already has named animation constants, use its names for the nearest value instead. The helpers in [Helpers](#helpers) below (`project`, `rubberband`, `relativeVelocity`, `PressScaleStyle`) are self-contained; a fix that needs one pastes it as `private` into the file being fixed. Snippets that are not complete declarations are fragments from inside a view's `body`. The state they read is plain `@State` on that view (`isShown: Bool`, `offset: CGFloat`, `count: Int`, `items: [Item]` with `Item: Identifiable`, and so on), and `reduceMotion` is `@Environment(\.accessibilityReduceMotion)`. Names like `Card()`, `Toast(_:)`, `ItemRow(item:)` stand for the app's own views. Each Right snippet fixes the rule it illustrates; most leave out the Reduce Motion branch to stay short, so a fix that moves, scales or bounces still ships with one (H1).

**Where the rules come from.** Some rules are Apple's: SDK behaviour, deprecations and defaults, and guidance in the Human Interface Guidelines and WWDC sessions. Most numbers are this skill's guidelines: well-reasoned defaults that keep an app consistent, not platform rules. In user-facing text, attribute the first kind to Apple and call the second kind a guideline ("a good ceiling is…", "I'd keep this under…"). Never write "Apple requires 0.3 s".

| Group | Apple (HIG, WWDC, SDK) | Guideline of this skill |
|---|---|---|
| A. Gate | Prefer system components (HIG); avoid motion for its own sake and on frequent interactions (HIG Motion); widget limits and Always-On (docs) | The four frequency tiers and their budgets; the purpose list |
| B. Scope | Value-less `.animation` is deprecated; scoping APIs and their behaviour; `.default` values; completions (SDK, WWDC23) | Writing values out instead of defaults; bounce 0 for numeric text |
| C. Values | Springs keep velocity and retarget (WWDC23); start springs at bounce 0, bounce for momentum (WWDC18, WWDC23); system menus grow from their source | Every duration bar, the bounce bands and the 0.4 ceiling, entrance scale 0.9–0.97, press 0.97, "no ease-in" |
| D. Interruptibility | People can interrupt motion (HIG); how springs, keyframes and loops retarget (SDK) | — |
| E. Enter / exit | 0.5 s long-press default (SDK) | Faster exits, same path, hold durations |
| F. Gestures | 1:1 tracking, velocity hand-off, projection, rubber-banding at edges, accessible alternatives (WWDC18, HIG) | The 40 % commit fraction, c = 0.55, the 30 velocity cap |
| G. Choreography | — | All of it, including stagger steps and loop timing |
| H. Reduce Motion | Replace travel, zoom and depth with fades; stop repetitive motion; keep meaning (HIG Accessibility) | The exact replacement curves |
| I. Haptics | Meanings, platform availability, don't overuse, never the only feedback (HIG, docs) | The event-to-feedback picks where Apple names none |
| J. Performance | Render-only effects, identity, matched geometry, zoom placement (SDK, WWDC23–24) | 20 pt blur ceiling, spinner delays |
| K. Pitfalls | How transactions, `onAppear`, `List` and `.id` behave (SDK behaviour; verify on device where noted) | — |
| L. Layout | `List` row insets, backgrounds and selection (SDK) | — |

## Contents

- [Helpers](#helpers)
- [A. Gate](#a-gate): A1–A6
- [B. Scope and API](#b-scope-and-api): B1–B6
- [C. Values and curves](#c-values-and-curves): C1–C8
- [D. Interruptibility](#d-interruptibility): D1–D4
- [E. Enter / exit](#e-enter--exit): E1–E4
- [F. Gestures](#f-gestures): F1–F8
- [G. Choreography](#g-choreography): G1–G6
- [H. Reduce Motion](#h-reduce-motion): H1–H4, replacement table
- [I. Haptics](#i-haptics): I1–I5, event table
- [J. Performance](#j-performance): J1–J10, diagnostic order
- [K. SwiftUI motion pitfalls](#k-swiftui-motion-pitfalls): K1–K5
- [L. Layout next to motion](#l-layout-next-to-motion): L1–L3
- [Lint one-liners](#lint-one-liners)
- [Optional: a motion token set](#optional-a-motion-token-set)

---

## Helpers

```swift
import SwiftUI

// Self-contained: paste only the helpers a fix uses, as `private` in the file being fixed.

/// Distance (pt) a fling travels under UIScrollView-like deceleration. `velocity` in pt/s.
/// 0.998 is the commonly printed raw value of `.normal` (0.99 for `.fast`); verify on device.
func project(_ velocity: CGFloat, rate: CGFloat = 0.998) -> CGFloat {
    (velocity / 1000) * rate / (1 - rate)
}

/// UIScrollView-style resistance. x = signed overshoot past the bound, d = dimension.
func rubberband(_ x: CGFloat, dimension d: CGFloat, c: CGFloat = 0.55) -> CGFloat {
    let m = abs(x)
    return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)   // ≡ (1 − 1/(m·c/d + 1))·d
}

/// Relative `initialVelocity` for `interpolatingSpring` and UIKit springs. Never pass raw pt/s.
func relativeVelocity(_ v: CGFloat, from current: CGFloat, to target: CGFloat) -> Double {
    let distance = target - current
    guard abs(distance) >= 1 else { return 0 }          // guard: divide-by-~0
    let cap: CGFloat = 30
    return Double(min(max(v / distance, -cap), cap))    // cap 30
}

/// Press feedback for custom buttons: near-instant press, animated release.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97      // large cards: 0.96–0.98, never below 0.95
    var dims = false               // glyph-only buttons: add a light dim

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(dims && configuration.isPressed ? 0.85 : 1)
            .animation(configuration.isPressed ? .spring(duration: 0.15, bounce: 0) : .spring(duration: 0.3, bounce: 0), value: configuration.isPressed)
    }
}
```

`PressScaleStyle` behaves like the one swift-motion-animate ships, and `project`, `rubberband` and `relativeVelocity` match swift-motion-gestures' helpers. If the project already has any of them, reuse it rather than declaring a second one (a second copy fails with "invalid redeclaration"). Otherwise paste the one helper the fix needs, `private`, into the file being fixed; don't create a new file for it. It needs no Reduce Motion branch: a ≤ 3 % dip is feedback, not travel, depth or zoom, and it is the only sign the tap landed (H1).

Projection worked numbers: at 0.998, `project(v) = 0.499 × v`; at 0.99, `0.099 × v`. Rubber-band at d = 800: a pull of 50 shows 26.6, 100 → 51.5, 200 → 96.7, 400 → 172.5, never more than d.

---

## A. Gate

### A1. Native first

**Default: Critical when system motion is broken (stripped push, lost back-swipe, sheet without its spring); High for a hand-rolled copy.**

A system component carries tuned timing, velocity dismiss, scroll hand-off, focus, VoiceOver and Reduce Motion. A copy loses weeks of edge cases and feels foreign next to the rest of the device. Custom motion fills gaps; it never duplicates or replaces system motion.

```swift
// Wrong: a hand-rolled bottom sheet for a tap-opened panel
ZStack(alignment: .bottom) {
    Color.clear
    if showFilters {
        Text("Filters").frame(maxWidth: .infinity, minHeight: 300).background(.regularMaterial)
            .transition(.move(edge: .bottom))
    }
}
// Right: the system sheet
Color.clear
    .sheet(isPresented: $showFilters) {
        Text("Filters")
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
```

```swift
// Wrong: pushing with the system animation stripped
Button("Open") {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { path.append(item) }
}
// Right
Button("Open") { path.append(item) }
```

```swift
// Wrong (iOS 26): a second press effect stacked on a glass button
Button("Play") {}.buttonStyle(.glass).scaleEffect(isPressed ? 0.97 : 1)
// Right: glass already scales, bounces and shimmers on touch
Button("Play") {}.buttonStyle(.glass)
```

Prefer, in order: `NavigationStack` push, `.sheet` + `.presentationDetents`, `Menu`, `.popover`, `.contextMenu`, `.swipeActions`, `.refreshable`, `DisclosureGroup`, `Picker(.segmented)`, `Toggle`, zoom transitions **(iOS 18)**. On iOS 26, remove custom `presentationBackground` from sheets so they get the inset glass.

### A2. No custom animation on 100+/day actions

**Default: Critical.** Novelty wears off: a 300 ms flourish seen 200 times a day is a minute of waiting. Apple's HIG asks apps to avoid adding motion to interactions that happen often; the tier list in SKILL.md is this skill's guideline for what "often" means. Anything driven per keystroke, per scroll tick or per launch counts. Tabs are peers; a slide implies depth that isn't there.

```swift
// Wrong: search results re-animate on every keystroke
List(results) { item in ItemRow(item: item) }
    .animation(.default, value: searchText)
// Right: results update instantly
List(results) { item in ItemRow(item: item) }
```

```swift
// Wrong: the tab content slides in with the selection
ZStack {
    switch tab {
    case .inbox: Text("Inbox").transition(.move(edge: .trailing))
    case .sent:  Text("Sent").transition(.move(edge: .trailing))
    }
}
Button { withAnimation(.spring(duration: 0.3, bounce: 0)) { tab = .inbox } } label: { Label("Inbox", systemImage: "tray") }
// Right: the content switches instantly
ZStack {
    switch tab {
    case .inbox: Text("Inbox")
    case .sent:  Text("Sent")
    }
}
Button { tab = .inbox } label: { Label("Inbox", systemImage: "tray") }
```

App tab switches (a `TabView` or a custom tab bar) never animate their content. A custom selection pill in the bar may still move, with its animation scoped to the pill so the content stays instant (J8 `TabIndicator`). An in-content segment control is tens/day (A3), not this rule.

Also a finding: `.tabViewStyle(.page)` for app tabs; custom animation wrapped around a `.keyboardShortcut` or `onKeyPress` action (people use shortcuts to go fast, so a flourish there reads as delay); and imitating the keyboard with a notification + timing curve (the keyboard uses a private spring; follow its real position with safe-area avoidance or `.safeAreaInset(edge: .bottom)`). The rule covers custom motion layered on top; system motion stays. A shortcut that opens an occasional surface (⌘N for a composer) doesn't make that surface 100+/day: judge it by how often it opens, and use the shortcut as one more reason to keep its motion short or system-provided.

Exception that proves the rule: an app whose most frequent action *is* the product (a habit tracker's check-in) can give it the most feel. That is a brand decision with a reason, not a default.

### A3. Tens/day motion is near-imperceptible

**Default: Medium (High when it bounces or exceeds 0.3 s); never moved for frequency.** Press feedback, row taps, segmented controls, row expansion, custom tab indicators and chips are seen tens of times a day. Budget: fixed curves ≤ 0.15 s; springs `duration ≤ 0.25`, bounce 0; opacity or scale changes ≤ 3 %. Or nothing.

Two values sit above the budget on purpose; don't flag them. The 0.3 s press release is fine because the touch-down response already happened at 0.15 s. A custom tab or segment indicator pill on a 0.3 s spring travels across the control (J8). Everything else on a tens/day surface takes a 0.25 s bounce-0 spring or less.

```swift
// Wrong: a bouncy 10 % pop on a chip
Text("Unread").padding(8)
    .scaleEffect(isOn ? 1.1 : 1)
    .animation(.bouncy, value: isOn)
// Right: colour only, on a short bounce-0 spring
Text("Unread").padding(8)
    .background(isOn ? Color.accentColor.opacity(0.2) : Color.clear, in: .capsule)
    .animation(.spring(duration: 0.25, bounce: 0), value: isOn)
```

Filter chips in a core feed are 100+/day (A2): no animation at all.

### A4. Every animation has a one-word purpose

**Default: Medium.** The purposes are feedback, spatial consistency, state indication, preventing a jarring change, explanation, and delight (rare tier only). If you can't name one, the motion costs time and returns nothing. The fix is deletion. In the finding, name the purpose you looked for and didn't find.

```swift
// Wrong: an idle, spinning decoration in a toolbar seen all day
Image(systemName: "sparkles")
    .rotationEffect(.degrees(spin ? 360 : 0))
    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: spin)
// Right
Image(systemName: "sparkles")
```

### A5. Functional data doesn't move for style

**Default: Medium (High on a dashboard opened many times a day).** Charts that redraw from zero on appear, balances that count up on load and table rows that animate in delay the data the user came to read. Animate a value only when it changes because of a user action.

```swift
// Wrong: the balance counts up from 0 every time the screen appears
Text(shownBalance, format: .currency(code: "EUR"))
    .contentTransition(.numericText(value: shownBalance))
    .onAppear {
        shownBalance = 0
        withAnimation(.smooth(duration: 1)) { shownBalance = balance }
    }
// Right: show the value; animate only changes the user causes (see B4)
Text(balance, format: .currency(code: "EUR"))
    .monospacedDigit()
    .contentTransition(.numericText(value: balance))
```

### A6. Widgets and Live Activities

**Default: Medium.** Widget and Live Activity animations have a 2 s maximum, so anything longer is cut short. With the Always-On display the system skips animations to save battery: check `isLuminanceReduced` before animating a change. Text changes already get a blurred content transition by default. Numbers use `.numericText` with a short spring: `.spring(duration: 0.2, bounce: 0)` matches Apple's widget example.

```swift
// Right: a Live Activity or widget view
struct ScoreView: View {
    let score: Int
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Text(score, format: .number)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(score)))
            .animation(isLuminanceReduced ? nil : .spring(duration: 0.2, bounce: 0), value: score)
    }
}
```

---

## B. Scope and API

### B1. No `.animation(_:)` without a value

**Default: High.** The value-less form is deprecated since iOS 15 and animates *every* change that reaches the view, including ones from unrelated state, rotation and Dynamic Type.

```swift
// Wrong
Circle().scaleEffect(scale).animation(.spring())
// Right: scoped to the value that should animate
Circle().scaleEffect(scale).animation(.spring(duration: 0.3, bounce: 0), value: scale)
```

### B2. Scope to the smallest subtree

**Default: Medium.** An implicit animation high in the tree animates everything below it whenever its value changes; a broad `withAnimation` around a model reload animates every view that reads the model. Put `withAnimation` at the mutation site (never inside `body`), put `.animation(_:value:)` on the smallest subtree, and use `.animation(_:body:)` to scope to specific modifiers. A nearer `.animation(_:value:)` overrides an outer `withAnimation` for its subtree.

```swift
// Wrong: one root modifier animates every change below it
ScrollView {
    VStack { ForEach(items) { item in ItemRow(item: item) } }
}
.animation(.default, value: items)
// Right: animate the mutation that should move
Button("Add") { withAnimation(.spring(duration: 0.3, bounce: 0)) { items.append(Item()) } }
```

```swift
// Right: in a container, scope the animation to the modifiers that should move
Text("Synced")
    .foregroundStyle(isActive ? .primary : .secondary)        // changes instantly
    .animation(.spring(duration: 0.25, bounce: 0)) { content in
        content.scaleEffect(isActive ? 1 : 0.97)              // only this animates
    }
```

To opt out locally: `.transaction(value: x) { $0.animation = nil }` or `withTransaction(\.disablesAnimations, true) { … }`.

If a closing animation driven by `withAnimation` + completion gets cut off on a view whose parent rebuilds often, move it to `.animation(_:value:)` on the animated view itself. Confirm the cut-off on a device before reporting it.

### B3. Chosen values, not defaults or one-offs

**Default: Medium.** A bare `withAnimation { }` means nobody chose (it is `.default`: 0.55 s, bounce 0, slower than most UI needs). A hand-typed `.spring(response: 0.34, dampingFraction: 0.82)` drifts from every other spring in the app and hides a bounce of about 0.18. The fix is a deliberate value written out, `.spring(duration: 0.3, bounce: 0)`, or the project's own constant if it already has a motion system. Don't introduce a new one for a single finding.

```swift
// Wrong
Button("Show") { withAnimation { isShown = true } }
Button("Show") { withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { isShown = true } }
// Right
Button("Show") { withAnimation(.spring(duration: 0.4, bounce: 0)) { isShown = true } }
```

Five nearly identical hand-typed springs is one pattern finding. Suggest gathering them into a few `private` constants in the file, or, if the user wants an app-wide motion system, the optional token set at the end of this file. Suggest it; don't add it.

### B4. Content transitions need an animation

**Default: Medium.** `.contentTransition(...)` does nothing unless the change happens inside an animated transaction. For `.numericText`, the spring must have bounce 0 (overshoot rolls digits back toward the old value), and digits should be tabular so the width doesn't jitter.

```swift
// Wrong: no animation in the transaction, the digits cut
Text(count, format: .number).contentTransition(.numericText(value: Double(count)))
Button("Add") { count += 1 }
// Right: animated change, bounce 0, tabular digits
Text(count, format: .number)
    .monospacedDigit()
    .contentTransition(.numericText(value: Double(count)))
Button("Add") { withAnimation(.spring(duration: 0.3, bounce: 0)) { count += 1 } }
```

```swift
// Right: symbol swap in place
Image(systemName: isOn ? "bell.fill" : "bell")
    .contentTransition(.symbolEffect(.replace))
Button("Toggle") { withAnimation(.spring(duration: 0.3, bounce: 0)) { isOn.toggle() } }
```

`.replace.magic(fallback:)` is **iOS 18**.

### B5. Entrances from a transition, not an `onAppear` flip

**Default: Medium.** An `onAppear { appeared = true }` flip re-fires on every appear (including cell reuse and tab return), and leaves a hidden start state that breaks when the animation is removed later. Drive insertion from real state, or let content that should already be there simply be there.

```swift
// Wrong
ItemRow(item: item)
    .opacity(appeared ? 1 : 0)
    .onAppear { withAnimation { appeared = true } }
// Right: conditional insertion; isLoaded changes inside withAnimation(.spring(duration: 0.3, bounce: 0))
if isLoaded {
    ItemRow(item: item).transition(.opacity)
}
```

### B6. Chain sequences on completions, not timers

**Default: Medium.** `asyncAfter` sized to a duration drifts from the real animation, can't be cancelled and stacks on rapid taps. `withAnimation(_:_:completion:)` (iOS 17) fires once, at the perceptual end.

```swift
// Wrong
Button("Next") {
    withAnimation { step = 1 }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { withAnimation { step = 2 } }
}
// Right
Button("Next") {
    withAnimation(.spring(duration: 0.3, bounce: 0)) { step = 1 } completion: {
        withAnimation(.spring(duration: 0.3, bounce: 0)) { step = 2 }
    }
}
```

---

## C. Values and curves

### C1. No `.easeIn` on UI

**Default: High.** Ease-in starts slow, delaying exactly the moment the user is watching, then stops abruptly. Don't use it on an appearance, a press or a response (a widely shared motion-design guideline rather than an Apple rule; system presentations use springs).

```swift
// Wrong
Toast("Saved").offset(y: isShown ? 0 : 80)
    .animation(.easeIn(duration: 0.3), value: isShown)
// Right: spring (or the strong ease-out curve when a curve is required, C6), moved by its own size (C7)
VStack {
    if isShown {
        Toast("Saved").transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
.animation(.spring(duration: 0.4, bounce: 0), value: isShown)
```

### C2. Never enter from nothing

**Default: High.** Nothing in the real world appears from scale 0. Start at 0.9–0.97 scale plus opacity. A bare `.scale` transition grows from 0.

```swift
// Wrong
if isShown { Card().transition(.scale) }
Card().scaleEffect(isShown ? 1 : 0)
// Right
if isShown { Card().transition(.scale(scale: 0.95).combined(with: .opacity)) }
Card().scaleEffect(isShown ? 1 : 0.95).opacity(isShown ? 1 : 0)
```

### C3. Anchored to the source

**Default: Medium.** A menu or popover grows from the button that opened it, so the eye sees where it came from. Native `Menu` and `.popover` do this already (and on iOS 26 morph out of their source). Centred modals are exempt: they stay centred.

```swift
// Wrong: a custom menu under a top-trailing button grows from its own centre
if isMenuOpen {
    MenuPanel().transition(.scale(scale: 0.95).combined(with: .opacity))
}
// Right: anchored at the trigger side
if isMenuOpen {
    MenuPanel().transition(.scale(scale: 0.95, anchor: .topTrailing).combined(with: .opacity))
}
// Present with .spring(duration: 0.3, bounce: 0), dismiss with .spring(duration: 0.2, bounce: 0)
```

### C4. Duration bars

**Default: Medium.** These bars are this skill's guidelines, not Apple numbers: a fixed-curve UI animation over 0.3 s, a component spring over 0.35, or a screen-scale spring over 0.5 needs a stated reason. `.easeInOut(duration: 0.5+)` on a control is a finding.

| Scale | Fixed curve | Spring `duration` |
|---|---|---|
| Press feedback | 0.10–0.15 s | 0.15 (down) / 0.3 (up) |
| Small control state | 0.15–0.20 s | 0.25 |
| Popover / menu / list change | 0.20 s | 0.3 (exit 0.2) |
| Sheet / drawer / toast / modal | 0.25–0.30 s | 0.35–0.4 (exit 0.3) |
| Screen transition | system | system (≈ 0.35 s push) |
| Rare / onboarding | ≤ ~1 s | ≤ 0.6 |

The table is by scale. On a tens/day surface the tighter A3 budget wins (fixed ≤ 0.15 s, spring ≤ 0.25), with the two exceptions A3 names.

```swift
// Wrong
Capsule().fill(isOn ? Color.green : Color.gray).frame(width: 50, height: 30)
    .animation(.easeInOut(duration: 0.5), value: isOn)
// Right
Capsule().fill(isOn ? Color.green : Color.gray).frame(width: 50, height: 30)
    .animation(.spring(duration: 0.25, bounce: 0), value: isOn)
```

To translate a web ease-out duration T to a spring: spring `duration ≈ 1.5 × T`, then feel-check.

### C5. Bounce means momentum

**Default: High.** Start every spring at bounce 0; Apple's WWDC23 spring session recommends it as the starting point, and WWDC18's fluid-interfaces talk ties overshoot to momentum. Add overshoot only when the gesture driving it carried momentum (flick, throw, drag release), or for a deliberately playful rare moment. A tap-opened panel that wobbles reads as broken. The bands below are guidelines.

| Bounce | Use |
|---|---|
| 0 | Default: every tap-, button- or programmatically-driven motion |
| ~0.15 (`.snappy`) | Allowed for small controls in a deliberately "precise" app; not the default |
| 0.2 | Gesture release with momentum to a free target |
| 0.3 | Rare / first-time delight only (`.bouncy`) |
| > 0.4 | Avoid on UI elements: it reads as cartoonish (guideline) |

```swift
// Wrong: no momentum, yet it bounces
Button("Menu") { withAnimation(.bouncy) { isMenuOpen = true } }
// Right
Button("Menu") { withAnimation(.spring(duration: 0.3, bounce: 0)) { isMenuOpen = true } }
```

Liquid Glass **(iOS 26)** already has system elasticity; never add bounce on top of it.

### C6. Springs by default

**Default: Medium.** Only springs keep position and velocity continuous and retarget mid-flight. Use a fixed curve only for opacity-only changes, constant processes, UIKit/Core Animation parity, or a fixed-length beat that is never re-triggered.

| Fixed curve | Value | Use |
|---|---|---|
| strong ease-out | `.timingCurve(0.23, 1, 0.32, 1, duration: d)` | entrances/exits when a spring can't be used |
| on-screen move | `.timingCurve(0.77, 0, 0.175, 1, duration: d)` | A→B repositioning without a gesture |
| line drawing | `.timingCurve(0.645, 0.045, 0.355, 1, duration: 0.6)` | `trim`-based strokes |
| opacity / colour only | `.easeOut(duration: 0.15)` or `.spring(duration: 0.2, bounce: 0)` | effects settle faster than movement |
| constant process | `.linear(duration:)`, `.repeatForever(autoreverses: false)` for spinners, marquees, hold fills | |

The web "iOS sheet" curve `(0.32, 0.72, 0, 1)` is never needed natively: use `.sheet`.

UIKit parity uses the same spring model, so a UIKit animation next to SwiftUI motion takes the same spring values: `UIView.animate(springDuration:bounce:initialSpringVelocity:delay:options:animations:completion:)` and `UISpringTimingParameters(duration:bounce:initialVelocity:)` (iOS 17), or `UIView.animate(_:changes:completion:)` with a SwiftUI `Animation` **(iOS 18)**. A `UIView.animate(withDuration:)` curve where one of these fits is a C6 finding; raw pt/s passed as a UIKit spring's initial velocity is F3.

```swift
// Wrong: an expand the user can reverse mid-flight, on a curve that can't carry velocity on reversal
DisclosureRow(isExpanded: isExpanded)
    .animation(.easeInOut(duration: 0.3), value: isExpanded)
// Right
DisclosureRow(isExpanded: isExpanded)
    .animation(.spring(duration: 0.3, bounce: 0), value: isExpanded)
```

### C7. Move by own size

**Default: Low.** A hard-coded offset is wrong on every other screen size and Dynamic Type setting. `.move(edge:)` moves by the view's own size, and leading/trailing flip in right-to-left layouts (`offset(x:)` does not).

```swift
// Wrong
Toast("Saved").offset(y: isShown ? 0 : 300)
// Right
if isShown {
    Toast("Saved").transition(.move(edge: .bottom).combined(with: .opacity))
}
```

### C8. Press feedback values

**Default: Medium.** Highlight starts on touch-down and is near-instant (a 0.15 s bounce-0 spring reaches 90 % in about 90 ms); the release animates (0.3 s, bounce 0), and a tap carries no momentum, so no bounce. Scale 0.97 is the 3 % ceiling for frequent controls; large cards may use 0.96–0.98, never below 0.95. Glyph-only buttons may add `opacity(0.85)`.

```swift
// Wrong: a deep, slow, symmetric press
struct DeepPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.3), value: configuration.isPressed)
    }
}
// Right: PressScaleStyle from Helpers above
struct BuyButton: View {
    var body: some View {
        Button("Buy") {}.buttonStyle(PressScaleStyle())
    }
}
```

---

## D. Interruptibility

### D1. No fixed sequences on re-triggerable UI

**Default: High.** `keyframeAnimator` and `phaseAnimator` play a fixed track: re-triggered, they restart instead of retargeting, and they can't reverse mid-flight. `repeatForever` can't be caught at all. Fine for a one-shot that can't be re-triggered faster than it plays (the error shake); wrong on toggles, toasts and anything draggable.

```swift
// Wrong: the knob replays a fixed track on every tap
Circle().frame(width: 24, height: 24)
    .keyframeAnimator(initialValue: CGFloat.zero, trigger: isOn) { content, x in
        content.offset(x: x)
    } keyframes: { _ in
        CubicKeyframe(20, duration: 0.2)
        CubicKeyframe(0, duration: 0.2)
    }
// Right: a spring retargets from wherever the knob is
Circle().frame(width: 24, height: 24)
    .offset(x: isOn ? 20 : 0)
    .animation(.spring(duration: 0.25, bounce: 0), value: isOn)
```

### D2. Never lock input during motion

**Default: Critical.** People should never wait for an animation to finish. Disabling controls or hit-testing while something animates turns motion into latency.

```swift
// Wrong: the list ignores taps until the banner finishes
List(items) { item in ItemRow(item: item) }
    .allowsHitTesting(!isAnimating)
// Right
List(items) { item in ItemRow(item: item) }
```

A stated reason (a destructive commit already in flight) makes it acceptable; flag it if the comment is missing.

### D3. Retarget from where the eye is

**Default: Medium.** On re-trigger, `spring` replaces the running animation and carries its velocity; `interpolatingSpring` adds; timing curves combine additively and carry no velocity. Resetting a value to its start before animating makes every re-trigger jump back to zero.

```swift
// Wrong: every tap snaps the badge back to 0.5 before growing again
Button("Ping") {
    badgeScale = 0.5
    withAnimation(.easeOut(duration: 0.3)) { badgeScale = 1 }
}
// Right: a one-shot symbol effect for a ping, or a spring toward the new target
Image(systemName: "bell").symbolEffect(.bounce, value: pings)
Button("Ping") { pings += 1 }
```

### D4. Cancellable sequences that never stack

**Default: Medium.** An imperative sequence started per tap without cancellation interleaves with the previous one. Use `.task(id:)` (cancelled automatically when the id changes) or a stored `Task` you cancel before restarting.

```swift
// Wrong: each tap starts another loop; they fight over `step`
Button("Replay") {
    Task {
        for i in 0..<3 {
            withAnimation(.spring(duration: 0.3, bounce: 0)) { step = i }
            try? await Task.sleep(for: .seconds(0.6))
        }
    }
}
// Right: one sequence per trigger value; a new tap cancels the running one
Button("Replay") { replays += 1 }
StepsView(step: step)
    .task(id: replays) {
        guard replays > 0 else { return }
        for i in 0..<3 {
            withAnimation(.spring(duration: 0.3, bounce: 0)) { step = i }
            do { try await Task.sleep(for: .seconds(0.6)) } catch { return }   // reading pause
        }
    }
```

---

## E. Enter / exit

### E1. Exit the way you entered, faster

**Default: Medium.** Enter and exit share one path, so the dismissal gesture is felt rather than learned. Exits are shorter: a 0.3 s popover enters and leaves in 0.2 s; a 0.4 s toast or drawer leaves in 0.3 s. A toast leaves by the edge it came from.

```swift
// Wrong: enters from the bottom, leaves by shrinking in place
if let message {
    Toast(message).transition(.asymmetric(insertion: .move(edge: .bottom), removal: .scale))
}
// Right: same edge both ways, shorter exit
if let message {
    Toast(message).transition(.move(edge: .bottom).combined(with: .opacity))
}
Button("Dismiss") { withAnimation(.spring(duration: 0.3, bounce: 0)) { message = nil } }
```

`.asymmetric(insertion:removal:)` is fine with a stated reason (a sent message leaves upward).

### E2. Exits are simultaneous

**Default: Low.** No reverse stagger out: everything leaves together, shorter and simpler than it came in. A reverse stagger makes the user wait to see the screen they asked for.

### E3. Modal card and backdrop in one transaction

**Default: Medium.** When the backdrop and the card follow separate implicit animations they drift apart and the scrim flashes. Insert both under one `withAnimation`.

```swift
// Wrong: two animations with different timing
Color.black.opacity(isShown ? 0.4 : 0).animation(.easeIn(duration: 0.5), value: isShown)
Card().opacity(isShown ? 1 : 0).animation(.spring(), value: isShown)
// Right: one state change, one transaction
ZStack {
    if isShown {
        Color.black.opacity(0.4).ignoresSafeArea().transition(.opacity)
        Card().transition(.scale(scale: 0.96).combined(with: .opacity))
    }
}
Button("Show") { withAnimation(.spring(duration: 0.35, bounce: 0)) { isShown = true } }
```

### E4. Slow where the user decides, fast where the system responds

**Default: Medium.** A hold that commits fills slowly and linearly (the fill shows time), and cancels quickly. Symmetric timing on a hold or press is a finding. Hold duration T = 0.5 s (the system long-press default); for a destructive action the fill itself is the safety, so about 1–2 s, and the commit plays `.impact(weight: .medium)` instead of `.success` (the event table's "destructive action fires" row; `.success` reports a task outcome).

```swift
struct HoldToConfirm: View {
    var title: String
    var holdDuration: Double = 0.5          // ~1–2 s when the action is destructive
    var onConfirm: () -> Void
    @State private var progress: CGFloat = 0
    @State private var confirmations = 0

    var body: some View {
        Text(title)
            .padding()
            .frame(maxWidth: .infinity)
            .background(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: proxy.size.width * progress)   // childless fill: sanctioned layout exception
                }
            }
            .clipShape(.capsule)
            .onLongPressGesture(minimumDuration: holdDuration) {
                confirmations += 1
                onConfirm()
            } onPressingChanged: { pressing in
                if pressing {
                    withAnimation(.linear(duration: holdDuration)) { progress = 1 }
                } else {
                    withAnimation(.spring(duration: 0.2, bounce: 0)) { progress = 0 }   // 0.2 s, bounce 0: cancels fast
                }
            }
            .sensoryFeedback(.success, trigger: confirmations)   // destructive: .impact(weight: .medium)
            .accessibilityAction(named: Text(title)) { onConfirm() }   // non-gesture route (F8)
    }
}
```

---

## F. Gestures

### F1. Tracking is 1:1

**Default: Critical.** While a finger is down, content moves exactly with it. A spring on the tracked value makes the view trail the finger: the most common reason a drag "feels wrong". Write the offset in `onChanged` with no animation; physics only takes over in `onEnded`.

```swift
// Wrong: the card lags behind the finger
Card()
    .offset(y: offset)
    .animation(.spring(), value: offset)
    .gesture(DragGesture().onChanged { offset = $0.translation.height })
// Right: 1:1 during the drag, spring only on release (snap home: .spring(duration: 0.3, bounce: 0), F3)
Card()
    .offset(y: offset)
    .gesture(DragGesture()
        .onChanged { offset = $0.translation.height }
        .onEnded { _ in withAnimation(.spring(duration: 0.3, bounce: 0)) { offset = 0 } })
```

If an outer animation still reaches the dragged value, cut it during the drag: `.transaction { if isDragging { $0.animation = nil } }`. A view that must be catchable mid-flight can drive `onChanged` with `withAnimation(.interactiveSpring())` so each change retargets and the release inherits velocity; feel-check the slight trailing on a device.

### F2. Keep the grab offset

**Default: Medium.** Position = where it was + translation. Using `value.location` snaps the view's origin under the finger on the first frame. When the dragged view itself moves, read the gesture in `.global` (or a named space) so the moving local space doesn't feed back and jitter.

```swift
// Wrong: jumps so its origin sits under the finger
Card()
    .offset(drag)
    .gesture(DragGesture().onChanged { drag = CGSize(width: $0.location.x, height: $0.location.y) })
// Right: base + translation, global space
Card()
    .offset(x: base.width + drag.width, y: base.height + drag.height)
    .gesture(DragGesture(coordinateSpace: .global)
        .onChanged { drag = $0.translation }
        .onEnded { value in
            base.width += value.translation.width
            base.height += value.translation.height
            drag = .zero
        })
```

### F3. Release is a spring that carries velocity

**Default: High.** A fixed-duration ease after a drag lands every fling the same way and jerks at the hand-off. On iOS 17+, when `onChanged` writes `@State` directly and `onEnded` sets the final value in `withAnimation(.spring…)`, SwiftUI carries the gesture's velocity into the spring automatically. Take the manual path only when that doesn't apply (velocity from `@GestureState`, two-axis springs, UIKit, non-gesture streams), and then `initialVelocity` is **relative**.

```swift
// Wrong: fixed ease; and raw pt/s passed as a relative velocity
Card().offset(y: offset)
    .gesture(DragGesture()
        .onChanged { offset = $0.translation.height }
        .onEnded { value in
            withAnimation(.easeOut(duration: 0.3)) { offset = 0 }
            // or: .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: value.velocity.height)
        })
// Right: automatic hand-off on iOS 17+
Card().offset(y: offset)
    .gesture(DragGesture()
        .onChanged { offset = $0.translation.height }
        .onEnded { _ in withAnimation(.spring(duration: 0.3, bounce: 0)) { offset = 0 } })
// Right: manual path, relative and capped (relativeVelocity from Helpers)
Card().offset(y: offset)
    .gesture(DragGesture()
        .onChanged { offset = $0.translation.height }
        .onEnded { value in
            let target: CGFloat = 0
            withAnimation(.interpolatingSpring(duration: 0.3, bounce: 0,
                initialVelocity: relativeVelocity(value.velocity.height, from: offset, to: target))) {
                offset = target
            }
        })
```

Release presets: commit to a hard edge (off-screen, dock) `.spring(duration: 0.3, bounce: 0)` with the rendered value clamped at the bound; snap to a free target with momentum `.spring(duration: 0.3, bounce: 0.2)`; throw across the screen to a corner `.spring(duration: 0.4, bounce: 0)`; snap back below the threshold `.spring(duration: 0.3, bounce: 0)`; swipe-to-delete slide-out `.spring(duration: 0.25, bounce: 0)` to −width, then remove inside `withAnimation(.spring(duration: 0.3, bounce: 0))`. Under Reduce Motion, every release uses `.spring(duration: 0.3, bounce: 0)`. A 2D throw needs separate x and y state with their own springs; a scalar `initialVelocity` applies to the whole `CGSize`. UIKit has the same trap: `UISpringTimingParameters(duration:bounce:initialVelocity:)` and `UIView.animate(springDuration:bounce:initialSpringVelocity:…)` take relative velocity too (the vector form per axis), so pass `relativeVelocity(...)`, never the recognizer's pt/s.

### F4. Commit by projection

**Default: High.** A distance-only threshold ignores intent: a short fast flick snaps back, and a slow drag past the line dismisses even while the finger is reversing. Project the resting point from the release velocity and compare it with 40 % of the travel. The velocity sign decides, so a flick back cancels even past the line.

```swift
// Wrong
Sheet().offset(y: offset)
    .gesture(DragGesture()
        .onChanged { offset = max(0, $0.translation.height) }
        .onEnded { value in
            if value.translation.height > 200 { dismiss() } else { offset = 0 }
        })
// Right (project and rubberband from Helpers)
Sheet().offset(y: offset)
    .gesture(DragGesture()
        .onChanged { value in
            let t = value.translation.height
            offset = t >= 0 ? t : rubberband(t, dimension: sheetHeight)
        }
        .onEnded { value in
            let projected = value.translation.height + project(value.velocity.height)
            let commit = projected > sheetHeight * 0.4
            withAnimation(.spring(duration: 0.3, bounce: 0)) { offset = commit ? sheetHeight : 0 } completion: {
                if commit { dismiss() }
            }
        })
```

Corroboration: on a 600 pt sheet the line is 240 pt, so a flick of just over 480 pt/s from rest commits. `DragGesture.Value.predictedEndTranslation` already projects: accept a check on it for plain nearest-snap, and flag it only when the feel must match the scroll views next to it or the rate must be tunable (then `project()`). For full-screen media viewers, where 40 % of the screen is too far, commit when |v| > ~1000 pt/s **or** the distance passes ¼ of the screen height. Destructive commits happen only on release, so the user can still reverse.

### F5. Rubber-band at edges

**Default: High.** A hard clamp (`max(0, translation)`) reads as a frozen phone. Past a bound, motion continues with rising resistance, matching the scroll views next to it (c = 0.55). Release from overdrag with `.spring(duration: 0.3, bounce: 0)` (no bounce: overshoot would re-enter the overdrag zone). F4's Right block shows the pattern.

```swift
// Wrong
Panel().offset(y: offset)
    .gesture(DragGesture().onChanged { offset = max(0, $0.translation.height) })
// Right (rubberband from Helpers)
Panel().offset(y: offset)
    .gesture(DragGesture()
        .onChanged { value in
            let t = value.translation.height
            offset = t >= 0 ? t : rubberband(t, dimension: panelHeight)
        }
        .onEnded { _ in withAnimation(.spring(duration: 0.3, bounce: 0)) { offset = 0 } })
```

### F6. Linked values from one progress

**Default: Medium.** Scrim opacity, the scale of what's behind and corner radius should all derive from the same drag progress in `body`. Separate animations on each drift apart and lag the finger.

```swift
// Right
let p = min(max(offset / sheetHeight, 0), 1)
ZStack(alignment: .bottom) {
    Color.black.opacity(0.4 * (1 - p)).ignoresSafeArea()
    Sheet()
        .clipShape(.rect(cornerRadius: 12 + 20 * p))
        .offset(y: offset)
}
```

### F7. Presses use `Button` and a `ButtonStyle`

**Default: High.** `onTapGesture` has no pressed state and no button traits for VoiceOver; `DragGesture(minimumDistance: 0)` press tracking blocks scrolling and loses accessibility too. Press feedback lives in `ButtonStyle` via `configuration.isPressed`.

```swift
// Wrong
Text("Delete").onTapGesture { delete() }
Card().scaleEffect(isPressed ? 0.97 : 1)
    .gesture(DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false })
// Right (PressScaleStyle from Helpers)
Button("Delete", role: .destructive) { delete() }.buttonStyle(PressScaleStyle())
```

### F8. Non-gesture routes and current gesture APIs

**Default: Low (High when a custom gesture is the only way to do something).** Every custom gesture needs a Button, an accessibility action or an edit mode that does the same thing. `MagnificationGesture` and `RotationGesture` are deprecated; use `MagnifyGesture` and `RotateGesture` (iOS 17).

```swift
// Wrong: deprecated
Image(systemName: "map").scaleEffect(zoom)
    .gesture(MagnificationGesture().onChanged { zoom = $0 })
// Right
Image(systemName: "map").scaleEffect(zoom)
    .gesture(MagnifyGesture().onChanged { zoom = $0.magnification })
    .accessibilityAction(named: Text("Zoom in")) { zoom = min(zoom * 1.5, 4) }
```

Also check: a `DragGesture` inside a `ScrollView` steals scrolling (axis-lock at a 10 pt slop; use `.simultaneousGesture` or a higher `minimumDistance`; `.highPriorityGesture` steals scroll too); `.gesture(_:isEnabled:)` (back-deployed, Xcode 16+ toolchain) toggles a gesture without changing identity mid-drag; double-tap delays single taps by about 0.5 s, so only pay that where a double-tap exists; hit targets are ≥ 44 × 44 pt via `.contentShape`, not a bigger visual. Scroll snapping is `.scrollTargetBehavior(.paging / .viewAligned)` + `.scrollTargetLayout()`, never a `DragGesture` carousel.

---

## G. Choreography

### G1. One entrance per container

**Default: Medium.** If the panel slides in, its content is already there. Animating the parent's entrance and staggering its children doubles the motion and the wait. When a child flies in from the wrong place under a parent's layout animation, animate the parent and let children ride: `geometryGroup()` (iOS 17).

### G2. No stagger on high-frequency UI

**Default: High.** Menus, dropdown rows, tab content and `List` / `LazyVStack` rows are seen constantly, and lazy rows recycle and re-fire on scroll-back (flicker). Stagger only the first appearance of a rarely seen group.

```swift
// Wrong: index ids, uncapped 0.1 s steps, inside a list seen all day
List {
    ForEach(items.indices, id: \.self) { i in
        ItemRow(item: items[i])
            .opacity(shown ? 1 : 0)
            .animation(.default.delay(Double(i) * 0.1), value: shown)
    }
}
// Right: rows are simply there
List(items) { item in ItemRow(item: item) }
```

### G3. Stagger within the numbers

**Default: Medium.** Step 40 ms (30–80 ms allowed); items after index 6 share index 6's delay (max 0.24 s); total span ≤ 0.3 s. Over budget (> 80 ms per item or > 0.3 s span): cap at 30 ms or fade the group as one. Entrance distance varies by role: lead 12 pt, support 6–8 pt, decoration 0 (fade only). First-run screens may use 100–150 ms steps on 0.5–0.6 s entrances.

```swift
// Right: a rare group, stable ids, capped 40 ms steps, collapsed under Reduce Motion
ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
    CardView(card: card)
        .opacity(shown ? 1 : 0)
        .offset(y: shown || reduceMotion ? 0 : 8)
        .animation(.spring(duration: 0.3, bounce: 0).delay(reduceMotion ? 0 : Double(min(i, 6)) * 0.04), value: shown)
}
```

### G4. Choreography never blocks interaction

**Default: Medium.** Everything visible is tappable at once. No `.allowsHitTesting(false)` while a sequence plays without a stated reason (see D2).

### G5. Persistent elements stay put

**Default: Medium.** Chrome present in both states lives in a surviving parent, or morphs via `matchedGeometryEffect`. A title that exists in both branches of an `if/else` fades out and back in.

```swift
// Wrong: the title is in both branches
if isEditing {
    VStack { Text("Profile").font(.title); Text("Form") }
} else {
    VStack { Text("Profile").font(.title); Text("Summary") }
}
// Right: hoisted into a parent that survives
VStack {
    Text("Profile").font(.title)
    if isEditing { Text("Form") } else { Text("Summary") }
}
```

Elements driven by one value (a chart line, its label, a badge) share one `Animation` value; stagger is for independent elements only. More than one lead element is a hierarchy problem that motion can't fix: say so.

### G6. Attention loops within budget

**Default: Medium.** A coach mark or nudge that loops is decoration until it has waited for the user: start it after about 2.5 s of inactivity, repeat at most every ~6 s, and stop for good on the first interaction. Faster or endless loops read as nagging and drain attention from the task. A loop within this budget is legitimate in Remove mode; it still stops under Reduce Motion (H3).

```swift
// Right: a hint that waits, repeats slowly, and stops once the user acts
struct SwipeHint: View {
    @Binding var hasInteracted: Bool
    @State private var nudges = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "hand.draw")
            .symbolEffect(.bounce, value: nudges)
            .task(id: hasInteracted) {
                guard !hasInteracted, !reduceMotion else { return }
                do {
                    try await Task.sleep(for: .seconds(2.5))      // first run after ~2.5 s
                    while !Task.isCancelled {
                        nudges += 1
                        try await Task.sleep(for: .seconds(6))    // at most every ~6 s
                    }
                } catch { return }
            }
    }
}
```

---

## H. Reduce Motion

### H1. Every app-authored animation that moves has a branch

**Default: Critical.** The system tones down its own components (and Liquid Glass removes its elasticity), but it does not touch custom motion. Any app-authored animation with travel, scale or zoom, depth, bounce, blur or a loop reads `accessibilityReduceMotion` and branches; a missing branch there ignores an accessibility setting. Opacity and colour changes, 1:1 gesture tracking, bounce-0 releases and a ≤ 3 % press scale are already the Reduce Motion form and need no branch (H4).

```swift
// Right
if isShown {
    Toast("Saved")
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
}
Button("Save") {
    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) { isShown = true }
}
```

In an audit, list the files with custom motion and the files that read `accessibilityReduceMotion`; the difference is the list of H1 leads. Open each: a file whose only motion is a fade, a colour change or 1:1 tracking is not a finding.

### H2. The branch removes travel, not just the curve

**Default: High.** Swapping only the curve while keeping the same slide is insufficient; so is removing all feedback.

```swift
// Wrong: same travel, different curve
if isShown { Toast("Saved").transition(.move(edge: .bottom)) }
Button("Save") {
    withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) { isShown = true }
}
// Right: see H1
```

### H3. Loops and decorative effects stop

**Default: High.** Loops (`repeatForever`, a `phaseAnimator` with no trigger, `keyframeAnimator(repeating:)`, `.symbolEffect` with `.repeat`, `.pulse` / `.breathe` **(iOS 18)** with `isActive`) stop and show their static end state. Decorative symbol effects go with `.symbolEffectsRemoved(reduceMotion)`; `.replace` content transitions stay.

```swift
// Right
Image(systemName: "dot.radiowaves.left.and.right")
    .symbolEffect(.pulse, isActive: isLive && !reduceMotion)
Image(systemName: "sparkles")
    .symbolEffect(.bounce, value: count)
    .symbolEffectsRemoved(reduceMotion)
```

Avoid sustained oscillation near 0.2 Hz (one cycle per 5 s) and large peripheral motion for everyone.

### H4. Fewer and gentler, not zero

**Default: Low.** Opacity and colour changes that explain what happened stay, and so do haptics (they are not motion). Gesture tracking stays 1:1.

Replacement table:

| Original | Under Reduce Motion |
|---|---|
| Slide / move / push / offset entrance | `.transition(.opacity)`, `.easeOut(duration: 0.2)` |
| Scale / pop / zoom-in entrance | `.opacity`, 0.2 s |
| Custom hero / `matchedGeometryEffect` travel | crossfade, `.easeInOut(duration: 0.2)` |
| `.navigationTransition(.zoom)` **(iOS 18)** | system `.automatic` push, or `.crossFade` **(iOS 27)**; whether the system zoom already adapts is unverified, so branch explicitly |
| Any bounce > 0 | bounce 0, same or shorter duration |
| Gesture tracking | unchanged, 1:1 |
| Gesture release / throw | `.spring(duration: 0.3, bounce: 0)`, no throw overshoot |
| 3D / `rotation3DEffect` / parallax / depth | static |
| Blur in/out (`.blurReplace`, animated `.blur`) | `.opacity` |
| Stagger / choreography | no delays, no travel, the group fades together; if the sequence *is* the explanation, step between frames |
| Loops | stopped; static end state |
| SF Symbol effects | `.symbolEffectsRemoved(reduceMotion)` for decorative ones; keep `.replace` |
| Error shake | no shake; tint/colour + `.error` haptic |
| Opacity / colour changes that explain state | keep |
| Haptics | keep |

Fallback when unsure: (1) crossfade 0.2 s, (2) the same motion shortened to 0.10–0.15 s with bounce 0, (3) instant.

Also check Reduce Transparency (`accessibilityReduceTransparency`: materials become solid), Increase Contrast (`colorSchemeContrast == .increased`), `accessibilityDimFlashingLights` and `accessibilityPlayAnimatedImages`.

---

## I. Haptics

Event → feedback on iPhone:

| Event | Feedback |
|---|---|
| A value ticks past a discrete step (picker, slider detent, segmented control, custom tab) | `.selection` |
| Snap into place, sheet detent catches, drag commits, item snaps home | `.impact(weight: .light)` (or `.impact(flexibility: .soft)`) |
| Heavy object lands, destructive action fires | `.impact(weight: .medium)` |
| Threshold armed → committed | `.impact(weight: .light)` at arm, `.impact(weight: .medium)` at commit |
| Task succeeded / failed / completed with a warning | `.success` / `.error` / `.warning` (task outcomes only) |
| Dragged into alignment with a guide | `.alignment` |
| Path or drawing completed | `.pathComplete` (iOS 17.5) |
| Custom control press / release matching system controls **(iOS 26)** | `.press(.button / .buttonIconOnly / .slider / .tab / .toggle)`, `.release(.slider)` |
| Custom toggle on/off, slider at min/max **(iOS 26)** | `.selection(.on / .off / .minimum / .maximum)` |
| Velocity-scaled impact | `.impact(weight:intensity:)`, intensity 0…1 from velocity |

### I1. Same trigger, same frame

**Default: Medium.** Attach `.sensoryFeedback` to the very state change that drives the visual (the detent catching), never to the animation's completion: by then the eye has moved on.

```swift
// Wrong: fires when the animation ends
Button("Snap") {
    withAnimation(.spring(duration: 0.3, bounce: 0)) { snap = .high } completion: { haptics += 1 }
}
.sensoryFeedback(.impact(weight: .light), trigger: haptics)
// Right: same state, same frame
Button("Snap") { withAnimation(.spring(duration: 0.3, bounce: 0)) { snap = .high } }
    .sensoryFeedback(.impact(weight: .light), trigger: snap)
```

### I2. One direction for one-way feedback on a toggling trigger

**Default: Medium (High when a warning or error plays on cancel).** A `Bool` trigger fires on every flip, present *and* dismiss. When the feedback means one direction only (a warning, a success, a commit), use the condition form so it doesn't play when the user backs out. A custom toggle is the opposite case: it should answer both ways, with `.selection` or `.selection(.on / .off)` **(iOS 26)** (event table).

```swift
// Wrong
Button("Delete") { showDelete.toggle() }
    .sensoryFeedback(.warning, trigger: showDelete)
// Right: condition form
Button("Delete") { showDelete.toggle() }
    .sensoryFeedback(.warning, trigger: showDelete) { _, new in new }
```

### I3. Never per frame, never uncaused

**Default: Medium.** No haptics on scroll ticks, per `onChanged` frame, on every tap, on entrances the user didn't cause, at cold launch or on a foreground message arriving. A threshold haptic fires on a derived `Bool` flip with hysteresis: arm at the threshold, disarm about 20 pt back, so it never chatters.

```swift
struct PullToArchive: View {
    var onArchive: () -> Void
    @State private var pull: CGFloat = 0
    @State private var armed = false
    private let threshold: CGFloat = 80

    var body: some View {
        Text("Pull to archive")
            .offset(x: pull)
            .gesture(DragGesture()
                .onChanged { value in
                    pull = value.translation.width
                    if !armed && pull > threshold { armed = true }
                    else if armed && pull < threshold - 20 { armed = false }
                }
                .onEnded { _ in
                    if armed { onArchive() }               // destructive commit only on release
                    armed = false
                    withAnimation(.spring(duration: 0.3, bounce: 0)) { pull = 0 }
                })
            .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new }
            .accessibilityAction(named: Text("Archive")) { onArchive() }   // non-gesture route (F8)
    }
}
```

### I4. Only feedback that plays on iPhone

**Default: Low.** `.levelChange` is macOS only, and `.start` / `.stop` are watchOS only: silent on iPhone. Apple lists `.increase` / `.decrease` for watchOS and visionOS; don't rely on them for iPhone UI. iPad has no Taptic Engine, so iPad UI never depends on haptics.

```swift
// Wrong: silent on iPhone
Stepper("Level", value: $level).sensoryFeedback(.levelChange, trigger: level)
// Right
Stepper("Level", value: $level).sensoryFeedback(.selection, trigger: level)
```

### I5. Never alone, never doubled, always the documented meaning

**Default: Medium.** Many people have haptics off, so the visual must stand on its own. System controls (`Toggle`, `Picker`, `Slider`, `.swipeActions`, system sheet detents) already play one; a second is a duplicate. `.success` for a plain tap, or `.warning` for "about to be destructive", is the wrong meaning. Budget: a handful of haptic moments per app, not per screen. Long-running haptics can disrupt the camera, gyro and microphone.

```swift
// Wrong: duplicates the toggle's own feedback
Toggle("Wi-Fi", isOn: $isOn).sensoryFeedback(.selection, trigger: isOn)
// Right
Toggle("Wi-Fi", isOn: $isOn)
```

---

## J. Performance

### J1. Animate render-only modifiers

**Default: Medium.** `.offset`, `.scaleEffect`, `.rotationEffect`, `.opacity`, `.visualEffect` and `GeometryEffect` interpolate without calling your `body` or re-running layout. `.frame`, `.padding`, stack spacing, `Spacer` length, font size and `.position` re-run layout of the subtree every frame. Sanctioned layout exceptions: a childless pill or progress fill (width keeps its corner radius; `scaleEffect(x:)` would smear it), and an accordion with a small subtree. Don't fix text-height animation with `scaleEffect` (it distorts text): use a fixed container, translate the content and `.clipped()`.

```swift
// Wrong: padding animates layout for the whole grid
Card().padding(isSelected ? 0 : 8).animation(.spring(duration: 0.25, bounce: 0), value: isSelected)
// Right: render-only
Card().scaleEffect(isSelected ? 1 : 0.97).animation(.spring(duration: 0.25, bounce: 0), value: isSelected)
```

### J2. No animated shadows or large blur

**Default: High.** Animated shadow radius and blur cost per frame and hitch first on older devices. Crossfade the opacity of a static pre-shadowed layer, put `.shadow` on a simple `Shape` background, and add `.compositingGroup()` before a container shadow on a transparent container (otherwise every child gets its own). Check before claiming that: once the container has an opaque `.background`, the shadow follows that background's shape instead, and the per-child problem doesn't apply. A shadow on a bouncy spring also overshoots the radius and throbs. Animated blur stays under 20 pt (2–4 pt softens a crossfade), never on large views or materials; prefer `.transition(.blurReplace)`. UIKit: set `shadowPath`.

```swift
// Wrong
Card().shadow(radius: isLifted ? 24 : 4).animation(.spring(duration: 0.3, bounce: 0), value: isLifted)
// Right: a static shadow on a simple shape, crossfaded
Card()
    .background {
        RoundedRectangle(cornerRadius: 16)
            .fill(.background)
            .shadow(radius: 24)
            .opacity(isLifted ? 1 : 0)
    }
    .animation(.spring(duration: 0.3, bounce: 0), value: isLifted)
```

### J3. Identity: `.id()` resets and `if/else` "morphs"

**Default: High.** Changing `.id()` destroys the view and builds a new one. Everything attached to the old identity resets: `@State`, scroll position, focus, a running animation, and `onAppear` / `.task` fire again, so entrance animations and loops restart. Inside an animated transaction the change plays as a removal plus an insertion (a crossfade by default), not a morph. The common causes are `.id(UUID())` or `.id(refreshToken)` used to "force a refresh", and an `.id` keyed on content that changes. Two exclusive `if/else` views are a cut, not a morph; animate one persistent view instead. `ForEach` needs stable ids: not `indices` over a mutable array, and not `id: \.self` or a title that the user can edit (every edit then destroys and re-inserts the row).

```swift
// Wrong: a new identity each time the title changes
Text(title).id(title)
// Right: same view, animated content (the transaction carries an animation, B4)
Text(title)
    .contentTransition(.interpolate)
    .animation(.spring(duration: 0.3, bounce: 0), value: title)
```

```swift
// Wrong: two views, so the "morph" is a crossfade
if isExpanded {
    RoundedRectangle(cornerRadius: 24).frame(height: 300)
} else {
    RoundedRectangle(cornerRadius: 12).frame(height: 80)
}
// Right: one persistent view
RoundedRectangle(cornerRadius: isExpanded ? 24 : 12)
    .frame(height: isExpanded ? 300 : 80)
```

Rare exception: an SF Symbol name swap inside `List` cells that breaks the cell animation may need separate `if/else` identities; note it when you see one.

### J4. No geometry churn

**Default: Medium.** A `GeometryReader`, preference or scroll-geometry value written to `@State` every frame re-runs `body` for everything that reads it, and it gets worse as content grows. Coarsen it to a `Bool` first, or let the renderer read geometry with `.visualEffect` / `.scrollTransition` (iOS 17).

```swift
// Wrong: writes the header's position to state on every scroll frame
ScrollView {
    GeometryReader { proxy in
        Color.clear.onChange(of: proxy.frame(in: .global).minY) { _, y in headerY = y }
    }
    .frame(height: 0)
    ForEach(items) { item in ItemRow(item: item) }
}
// Right (iOS 17): render-only, no state writes
ScrollView {
    ForEach(items) { item in
        ItemRow(item: item)
            .scrollTransition { content, phase in
                content.opacity(phase.isIdentity ? 1 : 0.6)
            }
    }
}
```

```swift
// Right (iOS 18): coarsen before it reaches state
ScrollView { ForEach(items) { item in ItemRow(item: item) } }
    .onScrollGeometryChange(for: Bool.self) { geometry in
        geometry.contentOffset.y > 40
    } action: { _, collapsed in
        isCollapsed = collapsed
    }
```

### J5. Per-frame state in the leaf

**Default: Medium.** Custom `Animatable` bodies, `TimelineView(.animation)`, `keyframeAnimator` content closures and `DragGesture.onChanged` run per frame (60–120 Hz). Keep them in leaf views and do nothing in `onChanged` beyond a state write: haptics, analytics and model commits go in `onEnded` or on a derived `Bool`. A per-frame value in an `@Observable` model, `EnvironmentObject` or environment value read by many views is the inherited-variable trap.

```swift
// Wrong: the drag offset lives in a shared model; every view reading it re-renders per frame
@Observable final class BoardModel {
    var titles: [String] = []
    var dragOffset: CGSize = .zero
}

// Right: per-frame state in the view that moves; resets with a spring on end or cancel
struct DraggableTile: View {
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.3, bounce: 0))) private var drag = CGSize.zero

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .frame(width: 120, height: 120)
            .offset(drag)
            .gesture(DragGesture().updating($drag) { value, state, _ in
                state = value.translation
            })
    }
}
```

`@GestureState` resets on end *and* cancel; `onEnded` doesn't fire on cancel.

### J6. `.drawingGroup()` only after measuring

**Default: Low.** It flattens a subtree into one Metal layer, which helps only for many shapes or particles and renders UIKit-backed views (text fields, maps, web, media) as placeholders. `compositingGroup()` is for visual composition (stops children showing through during a fade), not speed.

```swift
// Wrong: flattening a form
Form { TextField("Name", text: $name) }.drawingGroup()
// Right: a shape-heavy leaf that Instruments showed hitching
ZStack {
    ForEach(0..<200, id: \.self) { i in
        Circle().fill(Color.blue.opacity(0.3)).frame(width: 6, height: 6)
            .offset(x: CGFloat(i % 20) * 8, y: CGFloat(i / 20) * 8)
    }
}
.drawingGroup()
```

### J7. Keep the main thread free during motion

**Default: Medium.** JSON or image decoding, SwiftData fetches and file I/O at the trigger hitch the transition they start. Move the work off the main actor, prefetch before triggering, or defer it to the animation's completion. System transitions (push, sheet, symbol effects) are more resilient than custom ones; custom motion under load is where to look first.

### J8. Matched geometry and zoom transitions

**Default: Medium.** Exactly one `isSource: true` view per `matchedGeometryEffect` id at a time, and the insert and remove happen in the same transaction. `.navigationTransition(.zoom)` **(iOS 18)** goes on the destination's root, never inside a container in it; the source gets `.matchedTransitionSource`. Capture a stable model id, not a view, and don't branch on "in transition": an interrupted zoom push completes instantly and becomes a pop.

```swift
// Right (iOS 18): zoom from the thumbnail; a plain push under Reduce Motion
struct PhotoGrid: View {
    let photos: [String]
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                    ForEach(photos, id: \.self) { name in
                        NavigationLink {
                            if reduceMotion {
                                Image(systemName: name)
                            } else {
                                Image(systemName: name)
                                    .navigationTransition(.zoom(sourceID: name, in: zoom))
                            }
                        } label: {
                            Image(systemName: name)
                                .frame(width: 100, height: 100)
                                .matchedTransitionSource(id: name, in: zoom)
                        }
                    }
                }
            }
        }
    }
}
```

```swift
// Right: a custom tab or segment indicator, one pill that moves (prefer Picker(.segmented)).
// The animation is scoped to the pill, so content that reads `selection` switches instantly (A2).
struct TabIndicator: View {
    let tabs: [String]
    @Binding var selection: String
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            ForEach(tabs, id: \.self) { tab in
                Button(tab) { selection = tab }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background {
                        if selection == tab {
                            Capsule().fill(.quaternary)
                                // Reduce Motion: one id per tab, so the pills crossfade instead of travelling
                                .matchedGeometryEffect(id: reduceMotion ? tab : "pill", in: ns)
                        }
                    }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
```

### J9. Liquid Glass (iOS 26)

**Default: Low.** Limit the number of glass effects on screen; group nearby ones in a `GlassEffectContainer` so they render and morph together. Never glass on glass; tint only primary actions.

```swift
// Right (iOS 26)
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 16) {
        Image(systemName: "pencil").padding().glassEffect()
        Image(systemName: "eraser").padding().glassEffect()
    }
}
```

### J10. No spinner flash

**Default: Low.** A spinner for an operation under 300 ms reads as a glitch. Show a loader only after a 150–300 ms delay, and once shown keep it at least 300–500 ms, or a load that ends just after the delay flashes the spinner for a frame. Both halves live in one place: the view that knows when loading ends. Skeletons match the real layout (`.redacted(reason: .placeholder)`).

```swift
/// Shows `content` when loading ends. The spinner appears only after 300 ms and,
/// once shown, stays at least 400 ms.
struct LoadingGate<Content: View>: View {
    var isLoading: Bool
    @ViewBuilder var content: () -> Content
    @State private var spinnerShownAt: ContinuousClock.Instant?

    var body: some View {
        Group {
            if spinnerShownAt != nil {
                ProgressView()
            } else if !isLoading {
                content()
            }
        }
        .task(id: isLoading) {
            let clock = ContinuousClock()
            if isLoading {
                do { try await clock.sleep(for: .milliseconds(300)) } catch { return }  // fast loads never show it
                if spinnerShownAt == nil { spinnerShownAt = clock.now }
            } else if let shownAt = spinnerShownAt {
                do { try await clock.sleep(until: shownAt.advanced(by: .milliseconds(400))) } catch { return }
                spinnerShownAt = nil                                                    // minimum display time met
            }
        }
    }
}
```

### Diagnostic order for janky motion

1. Which properties animate? Layout first, then shadow, clip and corner radius.
2. Does the jank coincide with busy work (decode, fetch, I/O)?
3. Is `body` re-running per frame (geometry churn, per-frame state high in the tree)?
4. Does it get worse as content grows?
5. Animated blur over 20 pt, or offscreen passes?
6. Only now consider `drawingGroup()` or `compositingGroup()`.

Measure before claiming: Instruments **SwiftUI** template (long body updates, cause-and-effect graph), **Animation Hitches** and Time Profiler, on a mid-range physical device, Release build, also in Low Power Mode. The frame budget is 8.3 ms at 120 Hz (only about 5 ms usable) and 16.7 ms at 60 Hz. Custom `CADisplayLink`-driven animation on iPhone needs `CADisableMinimumFrameDurationOnPhone = YES` in Info.plist to exceed 60 Hz. Say which findings were verified from code and which need a device recording.

---

## K. SwiftUI motion pitfalls

Bugs that come from how SwiftUI applies animations, not from the values. They are easy to miss because each line looks fine on its own; the symptom only shows when something else changes in the same update.

### K1. A loop started in `onAppear` catches more than it should

**Default: High on persistent chrome (toolbars, tab bars, headers); Medium elsewhere.** `withAnimation(.repeatForever) { flag = true }` in `onAppear` runs while the view is still settling into its first layout. The repeating animation applies to every animatable change in that transaction, so the view's own position and size can join the loop: a toolbar button bobs or drifts in from a corner. When the toolbar or list rebuilds (push and pop, rotation, the search field activating), the view may be recreated: the loop restarts, or stops because the flag is already `true` and nothing changes, or a second loop stacks on the first. A loop on chrome is also usually decorative (A4) and must stop under Reduce Motion (H3), so the first question is whether it should exist at all.

```swift
// Wrong: the repeating transaction can also animate layout that changes in the same update
Image(systemName: "bell")
    .scaleEffect(pulse ? 1.1 : 1)
    .onAppear {
        withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true }
    }
// Right, for an SF Symbol: an effect that runs only while it means something, and not under Reduce Motion
Image(systemName: "bell")
    .symbolEffect(.pulse, isActive: hasUnread && !reduceMotion)
// Right, for anything else: the loop can only reach the modifier inside the closure
Circle()
    .frame(width: 12, height: 12)
    .animation(.easeInOut(duration: 0.8).repeatForever()) { content in
        content.scaleEffect(pulse ? 1.1 : 1)
    }
    .onAppear { pulse = !reduceMotion }
```

When attention is the goal, a one-shot tied to an event beats any loop: `.symbolEffect(.bounce, value: newCount)`.

### K2. Animations that catch layout and the first appearance

**Default: Medium (High when it animates the first appearance of a frequent screen).** An animation reaches more than the line it sits on:

- A value-less `.animation(_:)`, or one high in the tree, animates the first layout and every later layout change: rows slide in from the top on launch, content jumps when the keyboard, search field or a rotation changes the size (B1, B2).
- `withAnimation` around the first data load in `onAppear` or `.task` animates content that should simply be there.
- `.animation(_:value:)` on a whole screen animates anything in that screen that changes in the same update as the value, not just the view you meant.
- Order matters: `.animation(_:value:)` animates the view and the modifiers written above it. A modifier written after it is outside its reach and changes instantly.

```swift
// Wrong: the first load is animated, so the rows slide in on every launch
List(items) { item in ItemRow(item: item) }
    .task {
        let loaded = await loadItems()
        withAnimation(.spring(duration: 0.3, bounce: 0)) { items = loaded }
    }
// Right: the first load just appears; changes the user causes animate at their mutation
List(items) { item in ItemRow(item: item) }
    .task { items = await loadItems() }
```

```swift
// Wrong: on the whole screen, so anything else that changes with showPanel animates too
ItemList()
    .overlay(alignment: .bottom) {
        if showPanel { Panel().transition(.move(edge: .bottom).combined(with: .opacity)) }
    }
    .animation(.spring(duration: 0.4, bounce: 0), value: showPanel)
// Right: inside the overlay, the animation reaches only the panel
ItemList()
    .overlay(alignment: .bottom) {
        ZStack {
            if showPanel { Panel().transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.spring(duration: 0.4, bounce: 0), value: showPanel)
    }
```

```swift
// Order: only the scale animates; the opacity written after .animation changes instantly
Circle()
    .scaleEffect(isOn ? 1 : 0.97)
    .animation(.spring(duration: 0.25, bounce: 0), value: isOn)
    .opacity(isOn ? 1 : 0.5)
```

### K3. Motion inside `List` rows

**Default: Medium.** A `List` manages its rows the way a UIKit collection view does: when a change arrives in an animated transaction, the list inserts, deletes, moves and resizes rows with its own animation. A custom `.transition` on a row is not reliably honoured and behaves differently between iOS versions (confirm on a device before saying it does nothing). Inside a row, content added with `if` changes the row's height; the list animates that only when the change is animated, and the new content can draw over the next row mid-animation, so prefer `DisclosureGroup`. Row `onAppear` entrances replay whenever a row scrolls back into view (B5, G2).

```swift
// Wrong: a custom transition on List rows, fighting the list's own row animation
List {
    ForEach(items) { item in
        ItemRow(item: item).transition(.slide)
    }
}
// Right: no row transition; animate the mutation and let the list animate its rows
List {
    ForEach(items) { item in ItemRow(item: item) }
}
Button("Add") { withAnimation(.spring(duration: 0.3, bounce: 0)) { items.insert(Item(), at: 0) } }
```

### K4. Transitions need a container that stays

**Default: Medium.** A `.transition` plays only when the view is inserted or removed inside an animated transaction, and the animation must come from something that outlives the view: a `withAnimation` at the mutation, or `.animation(_:value:)` on a container that stays on screen. An `.animation` attached to the conditional view itself leaves with it, so the removal has nothing to run. In a `ZStack`, a view on its way out can drop behind its siblings; `.zIndex(1)` keeps the exit visible.

```swift
// Wrong: the animation is on the view being removed, so the exit cuts
if isShown {
    Toast("Saved")
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(duration: 0.4, bounce: 0), value: isShown)
}
// Right: a container that stays carries the animation; zIndex keeps the exit on top
ZStack(alignment: .bottom) {
    Color.clear
    if isShown {
        Toast("Saved")
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1)
    }
}
.animation(.spring(duration: 0.4, bounce: 0), value: isShown)
```

### K5. One owner per change

**Default: Medium.** When two or three sources can animate the same change (a value-less `.animation` on a list, a `withAnimation` in an `onChange`, an `.animation(_:value:)` on the screen), the nearest implicit animation wins for its subtree. Which curve plays then depends on modifier order and on what happened to change together, so the timing varies from one time to the next and nobody can tune it. Give each change one owner: the `withAnimation` at the mutation, or one `.animation(_:value:)` on the smallest view that moves. Delete the others. In a review, name every source that competes and say which one should stay.

---

## L. Layout next to motion

Layout problems that change how motion reads. Report them when they sit next to the motion you're reviewing; leave deeper layout work to swift-motion-break-ui.

### L1. Card styling inside `List` rows

**Default: Medium (Low when the list has no selection or highlight).** `.padding()` plus `.background(...)` on a row's content draws a box inside the system row: the padding adds to the row's own insets, and an opaque background paints over the system's press highlight and selection, so a tap seems to do nothing and selection has to be faked with extra motion (a shadow, a scale). Let the row draw itself and adjust it with the row modifiers.

```swift
// Wrong: doubled insets, and the background hides the highlight and selection
List(items, selection: $selection) { item in
    ItemRow(item: item)
        .padding()
        .background(.background)
}
// Right: the system row, highlight and selection; row modifiers only if the defaults don't fit
List(items, selection: $selection) { item in
    ItemRow(item: item)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
}
```

### L2. Tap targets on rows

**Default: Medium.** `onTapGesture` on a row's content responds only where something is drawn, so a tap in the empty space beside the text does nothing, and there is no touch-down highlight (F7). Use `List(selection:)`, a `NavigationLink` or a `Button` for the row; if a gesture must stay, add `.contentShape(Rectangle())`.

### L3. Fixed sizes on surfaces that animate

**Default: Low.** A custom panel with `.frame(height: 300)` clips at large Dynamic Type and ignores the keyboard; a bottom overlay that doesn't respect the safe area slides under the home indicator. A motion fix doesn't change these sizes silently: mention them as a suggestion, and if the surface moves to a system sheet, note that the sheet sizes itself.

---

## Lint one-liners

Quick patterns to flag on sight, each with its fix:

| Pattern | Fix | ID |
|---|---|---|
| `.animation(.spring())` with no `value:` | `.animation(.spring(duration: 0.3, bounce: 0), value: x)` | B1 |
| `withAnimation {` with no animation | a chosen value | B3 |
| `.transition(.scale)` or `scaleEffect(show ? 1 : 0)` | 0.95 + opacity | C2 |
| `.easeIn(` on UI | bounce-0 spring | C1 |
| `.easeInOut(duration: 0.5)` or longer on a control | `.spring(duration: 0.25, bounce: 0)` | C4 |
| `.bouncy` on a tap-opened surface | `.spring(duration: 0.3, bounce: 0)` (0.4 for a panel) | C5 |
| Hard-coded `offset(y: 300)` entrance | `.move(edge:)` | C7 |
| `phaseAnimator` / `keyframeAnimator` / `repeatForever` on a toggle, toast or draggable | spring | D1 |
| `.disabled(isAnimating)`, `.allowsHitTesting(false)` with no comment | remove | D2 |
| `asyncAfter(deadline: .now() + 0.3…)` around `withAnimation` | completion | B6 |
| `onAppear { withAnimation { appeared = true } }` | conditional insertion | B5 |
| `.animation(…, value: offset)` on a dragged value | remove; spring in `onEnded` | F1 |
| `max(0, value.translation…)` | rubber-band | F5 |
| `translation.height > 200` alone | projection | F4 |
| `initialVelocity: value.velocity…` | `relativeVelocity(...)` | F3 |
| `onTapGesture` on something that acts like a button | `Button` + `PressScaleStyle` | F7 |
| `DragGesture(minimumDistance: 0)` for press tracking | `ButtonStyle` | F7 |
| `MagnificationGesture` / `RotationGesture` | `MagnifyGesture` / `RotateGesture` | F8 |
| `TabView` selection in `withAnimation`; `.tabViewStyle(.page)` for app tabs | no animation (a custom pill scopes its own, J8) | A2 |
| Widget or Live Activity animation over 2 s, or animating with `isLuminanceReduced` | ≤ 2 s; skip when luminance is reduced | A6 |
| `repeatForever` or a `Task` loop on a hint with no start delay or stop | G6 budget: 2.5 s, every 6 s, stop on interaction | G6 |
| `UIView.animate(withDuration:)` beside SwiftUI springs; raw pt/s into a UIKit spring | `UIView.animate(springDuration:bounce:…)`; `relativeVelocity` | C6, F3 |
| `.delay(Double(i) * …)` inside `List` / `LazyVStack` | remove | G2 |
| Title duplicated in both `if/else` branches | hoist | G5 |
| `.sensoryFeedback(.warning / .success / .error / .impact…, trigger: someBool)` on a toggling Bool | condition form | I2 |
| `.levelChange`, `.start`, `.stop` on iPhone | iOS case | I4 |
| `.shadow(radius: x ? … : …)` or `.blur(radius: x ? … : …)` animated on a big view | crossfade a static layer | J2 |
| `.id(` on a view that changes inside `withAnimation` | stable identity + content transition | J3 |
| `GeometryReader` + `onChange` writing `@State` | coarsen / `.visualEffect` / `.scrollTransition` | J4 |
| `ProgressView()` shown immediately for fast work | delayed spinner | J10 |
| Hand-rolled sheet, menu, alert or push | native component | A1 |
| Second press effect on `.buttonStyle(.glass)` | remove | A1 |
| `withAnimation(….repeatForever())` in `onAppear` | `.symbolEffect(…, isActive:)` or a loop scoped with `.animation(_:body:)` | K1 |
| `withAnimation` around the first data load in `onAppear` / `.task` | plain assignment | K2 |
| `.transition(` on a `List` row | remove; animate the mutation | K3 |
| `.animation(…, value: x)` on the view inside `if x { }` | move it to the container that stays | K4 |
| Two or more animation sources on one change | one owner | K5 |
| `.padding()` + `.background(` on `List` row content | system row; `.listRowInsets` / `.listRowBackground` | L1 |

---

## Optional: a motion token set

An optional resource, not part of any fix. Offer it only when the user asks for an app-wide motion system, or when a codebase has many hand-picked springs and the user wants them consolidated; then add it where the user says (for example a new `Motion.swift`). If the project already has its own set, map its names to the nearest values here instead of adding a second one. The values are this skill's guidelines (Apple publishes no token set).

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
