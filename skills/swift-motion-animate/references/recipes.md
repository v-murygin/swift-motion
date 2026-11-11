# Recipes

Read this when the request matches one of these interactions. Each recipe has already been through the
decision order; its **Gate** line says what was decided and why.

**Building new vs. editing existing code.** The recipes are complete components, written for the case where
you are building one from scratch. When the user hands you a file to improve, take the *pattern* (the
transition, the spring values, the cancellable timer, the Reduce Motion branch, the haptic) and fit it into
the code that's already there. Keep the user's structure, names, lifetimes, sizes and copy; don't paste in a
presenter, a new type or a new file the request didn't need. Recipe 3A shows what that looks like.

**Values and helpers.** Spring values are written inline, so any block compiles on its own and nothing new
needs to exist app-wide. Small helpers (`PressScaleStyle`, `heroMatch`, `zoomSource`) are `private`, so they
stay inside the file you put them in; recipes 2A, 8A and 9 reuse `PressScaleStyle` from recipe 1, and recipe 12
reuses `heroMatch` from recipe 9B, each in the same file. If the project already has its own press style or
motion constants, use those instead. Baseline is iOS 17; anything newer is gated with `#available` or
`@available`.

## Contents

1. Press feedback button
2. Toggle and morphing button
3. Toast enter and exit (upgrading an existing one, or a reusable presenter)
4. Custom menu / popover
5. List insert and remove
6. Numeric counter (and a badge pop with a triggered `phaseAnimator`)
7. Error shake
8. Success check (everyday save, and a drawn check for rare moments)
9. Card expand hero (zoom push, or in-place match)
10. Staggered first-run entrance
11. Liquid Glass morph (iOS 26)
12. Segmented indicator pill

---

## 1. Press feedback button

**Gate:** tens/day, purpose: feedback. Scale only, so nothing re-lays out.

```swift
import SwiftUI

private struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97      // large cards: 0.96–0.98, never below 0.95
    var dims = false               // glyph-only buttons: add a light dim

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(dims && configuration.isPressed ? 0.85 : 1)
            // In fast (0.15 s), back slower (0.3 s); both bounce 0.
            .animation(.spring(duration: configuration.isPressed ? 0.15 : 0.3, bounce: 0),
                       value: configuration.isPressed)
    }
}

struct AddToCartButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add to Cart", systemImage: "cart.badge.plus")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.tint, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressScaleStyle())
    }
}
```

- `isPressed` turns true on touch-down, so the dip starts before the finger lifts. Inside a `ScrollView` or
  `List` the system holds the pressed state back briefly so a scroll can win; that lag is expected, so don't
  replace the `Button` to remove it. Down is near-instant (0.15 s); the release is the part that animates
  (0.3 s). Both are bounce 0: a tap carries no momentum.
- Use a real `Button`, never `onTapGesture` or `DragGesture(minimumDistance: 0)`: you keep the pressed state,
  accessibility traits, keyboard activation, and scrolling still works.
- Don't add this on top of `.buttonStyle(.glass)` / `.glassProminent` (iOS 26): glass already responds.
- **Reduce Motion:** keep it. A 3 % dip is not travel, depth or zoom, and it is the only sign the tap landed.
- **Haptic:** none. Standard buttons don't play a press haptic. On iOS 26 a custom control that imitates a
  system one may opt into `.sensoryFeedback(.press(.button), trigger:)`.
- **Feel-check:** tap fast and repeatedly on a device; the dip must never lag or stack.

---

## 2. Toggle and morphing button

**Gate:** tens/day, purpose: state indication. The native `Toggle` comes first: it already animates, plays
its own haptic and adapts to Reduce Motion. Build these only when the design needs an icon button or a
custom control.

**A. Morphing icon (play ↔ pause)**

```swift
import SwiftUI
// Uses: PressScaleStyle from recipe 1.

struct PlayPauseButton: View {
    @Binding var isPlaying: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25, bounce: 0)) { isPlaying.toggle() }
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.title)
                .contentTransition(.symbolEffect(.replace))
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressScaleStyle(dims: true))
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}
```

- `contentTransition` is inert without an animation in the transaction; that's why the toggle sits inside
  `withAnimation`.
- On iOS 18, `.contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))` morphs symbols that
  share a shape (adding or removing a slash, for example).
- **Reduce Motion:** keep `.replace`; symbol content transitions stay under Reduce Motion.

**B. Custom switch**

```swift
import SwiftUI

struct PillToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Text(title)
                Spacer()
                Capsule()
                    .fill(isOn ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 51, height: 31)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle().fill(.white).padding(2)
                    }
                    .animation(.spring(duration: 0.25, bounce: 0), value: isOn)          // scoped to the track only
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(ToggleHaptic(isOn: isOn))
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// Matches the system switch on iOS 26; a plain selection tick before that.
private struct ToggleHaptic: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.sensoryFeedback(trigger: isOn) { _, new in new ? .selection(.on) : .selection(.off) }
        } else {
            content.sensoryFeedback(.selection, trigger: isOn)
        }
    }
}
```

- `.animation(_:value:)` sits on the capsule, so the title never animates.
- **Reduce Motion:** the thumb travels 20 pt inside its own track, the user caused it, and the native switch
  does the same, so it stays. If your thumb travels farther, swap the movement for a colour change.
- **Feel-check:** double-tap quickly; the thumb must reverse from where it is, never jump to an end.

---

## 3. Toast enter and exit

**Gate:** occasional, purpose: feedback (an outcome to notice, not act on). Enter and exit on the same edge;
exit about 20 % faster.

**A. Upgrading a toast that already exists.** The usual starting point: an `if showX { … }` that pops in and
a `DispatchQueue.main.asyncAfter` that pops it out. The smallest change that makes it feel right touches
three things and nothing else.

```swift
import SwiftUI

struct CopyLinkRow: View {
    let copy: () -> Void
    @State private var showCopied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button("Copy Link", systemImage: "link") {
            copy()
            // 1. Insert inside an animated transaction (0.4 s spring in; a fade under Reduce Motion).
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) {
                showCopied = true
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .overlay(alignment: .bottom) {
            if showCopied {
                Text("Link copied")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    // 2. A transition with a path: up from the bottom edge, plain opacity under Reduce Motion.
                    .transition(reduceMotion ? AnyTransition.opacity
                                             : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        // 3. Was `DispatchQueue.main.asyncAfter(deadline: .now() + 1.5)`. The task is cancelled whenever
        //    `showCopied` changes or the view goes away, so a stale timer can't hide a newer toast.
        .task(id: showCopied) {
            guard showCopied else { return }
            try? await Task.sleep(for: .seconds(1.5))          // the file's own lifetime, unchanged
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0)) {
                showCopied = false
            }
        }
    }
}
```

- What stayed: the lifetime, the layout, the copy, the overlay position and the state shape. If one of those
  looks wrong (a 1.5 s toast is short to read), say so in a line and leave the code as it was.
- If a re-tap should restart the timer, key the task on a counter the tap increments instead of the `Bool`.
- In a `ZStack` rather than an overlay, give the toast `.zIndex(1)` so its removal stays visible on top.
- Exit 0.3 s against an entrance of 0.4 s: same path, a little faster, because the user has seen it.

**B. A reusable presenter for new code.** When there's no toast yet and the app needs one, or the user asks
for a shared component:

```swift
import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

struct ToastPresenter: ViewModifier {
    @Binding var toast: Toast?
    var lifetime: Duration = .seconds(4)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var shown: (id: UUID, elapsed: Duration)?     // time already on screen, kept across pauses

    private struct TimerKey: Hashable {
        let id: UUID?
        let isActive: Bool
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast.message)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)                                  // stays inside the safe area
                        .id(toast.id)
                        .transition(reduceMotion ? AnyTransition.opacity
                                                 : .move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: toast?.id) { _, newID in
                guard newID != nil, let message = toast?.message else { return }
                AccessibilityNotification.Announcement(message).post()
            }
            .task(id: TimerKey(id: toast?.id, isActive: scenePhase == .active)) {
                // Cancelled when the app goes inactive, so the lifetime pauses and resumes on return.
                guard let id = toast?.id, scenePhase == .active else { return }
                let elapsed = shown.map { $0.id == id ? $0.elapsed : .zero } ?? .zero
                let start = ContinuousClock.now
                do {
                    try await Task.sleep(for: lifetime - elapsed)
                } catch {
                    shown = (id, elapsed + (ContinuousClock.now - start))
                    return
                }
                shown = nil
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0)) { toast = nil }
            }
    }
}

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastPresenter(toast: toast))
    }
}

struct EditorScreen: View {
    @State private var toast: Toast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button("Save") {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) {
                toast = Toast(message: "Saved to Library")
            }
        }
        .toast($toast)
    }
}
```

- A spring (not keyframes, not a fixed curve), so a dismissal that starts mid-entrance reverses from where the
  toast is. `.id(toast.id)` gives a replaced toast a real exit and the new one a real entrance. Both run in the
  caller's 0.4 s entrance transaction, so the old toast leaves at the entrance speed; that shared spring is
  accepted here rather than chaining the two.
- The 4 s default lifetime (a guideline for a new toast; Apple's guidance is only to keep time-limited UI to a
  minimum) pauses while the app is inactive and resumes with the time that was left.
- The overlay respects the safe area, which keeps the toast clear of the Dynamic Island. Don't add
  `.ignoresSafeArea`.
- A toast that carries an action (Undo) stays until it's used or dismissed; drop the timer for that case.
- Swipe-to-dismiss travels toward the same top edge; build the drag with `swift-motion-gestures`.
- **Haptic:** none for a neutral confirmation. If the toast reports an outcome with no other feedback, put
  `.success` / `.error` on the action's state, not on the toast's appearance.
- **Feel-check:** fire two toasts in a row, and background the app mid-display.

---

## 4. Custom menu / popover

**Gate:** occasional, purpose: spatial consistency (the panel visibly comes from its trigger). Use `Menu` or
`.popover` first: they grow from the trigger, handle outside taps, VoiceOver and Reduce Motion, and morph
from their source on iOS 26. Build this only when the design needs a panel those can't show.

```swift
import SwiftUI

enum SortOrder: String, CaseIterable, Identifiable {
    case newest = "Newest", oldest = "Oldest", title = "Title"
    var id: Self { self }
}

struct SortControl: View {
    @Binding var sort: SortOrder
    @State private var isOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { setOpen(!isOpen) } label: {
            Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                .frame(minHeight: 44)
        }
        .overlay(alignment: .topLeading) {
            if isOpen {
                panel
                    .padding(.top, 48)                                    // just below the trigger
                    .fixedSize()
                    .transition(reduceMotion ? AnyTransition.opacity
                                             : .scale(scale: 0.95, anchor: .topLeading).combined(with: .opacity))
            }
        }
        .zIndex(isOpen ? 1 : 0)
        .sensoryFeedback(.selection, trigger: sort)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(SortOrder.allCases) { order in
                Button {
                    sort = order
                    setOpen(false)
                } label: {
                    HStack {
                        Text(order.rawValue)
                        Spacer()
                        if order == sort { Image(systemName: "checkmark") }
                    }
                    .padding(.horizontal, 16)
                    .frame(width: 220, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func setOpen(_ open: Bool) {
        // In at 0.3 s, out faster at 0.2 s; a plain fade under Reduce Motion.
        let animation: Animation = reduceMotion ? .easeOut(duration: 0.2)
                                                : .spring(duration: open ? 0.3 : 0.2, bounce: 0)
        withAnimation(animation) { isOpen = open }
    }
}
```

- The anchor is the corner nearest the trigger. A centred scale makes the panel appear from nowhere; a scale
  from 0 makes it inflate.
- One transition, two springs chosen at the mutation site: in at 0.3 s, out at the faster 0.2 s.
- The rows don't stagger: a menu is opened many times a day, and the panel's entrance carries its content.
- This panel doesn't close on an outside tap; add a full-screen clear layer at the screen root if you need it.
  That gap is one more reason to prefer `Menu`.
- **Haptic:** `.selection` when the value changes, not when the panel opens.
- **Feel-check:** open and immediately close; the close must start from the half-open state.

---

## 5. List insert and remove

**Gate:** occasional, purpose: preventing a jarring change (rows jumping into the gap). The gap closes in the
same transaction as the removal.

```swift
import SwiftUI

struct Tag: Identifiable, Hashable {
    let id = UUID()
    var name: String
}

struct TagEditor: View {
    @State private var tags = [Tag(name: "Design"), Tag(name: "Motion"), Tag(name: "SwiftUI")]
    @State private var draft = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tags) { tag in
                HStack {
                    Text(tag.name)
                    Spacer()
                    Button("Remove \(tag.name)", systemImage: "xmark.circle.fill") { remove(tag) }
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .transition(reduceMotion ? AnyTransition.opacity
                                         : .opacity.combined(with: .scale(scale: 0.95)))
            }
            TextField("Add a tag", text: $draft)
                .onSubmit(add)
        }
        .padding()
    }

    private var change: Animation { reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0) }

    private func add() {
        let name = draft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation(change) { tags.append(Tag(name: name)) }
        draft = ""
    }

    private func remove(_ tag: Tag) {
        withAnimation(change) { tags.removeAll { $0.id == tag.id } }
    }
}
```

- Stable ids stored on the model are what let SwiftUI match rows across the change.
  `ForEach(tags.indices, id: \.self)` would animate the wrong rows.
- In a native `List`, wrapping the mutation in `withAnimation(.spring(duration: 0.3, bounce: 0))` is enough; the system row animations do
  the rest. Never add `onAppear` entrances to lazy rows: they re-fire as rows are reused.
- Siblings reflow while the removed row fades, in one transaction, so there's no pause before the gap closes.
- **Haptic:** none. A tag removal is light and reversible; save `.impact(weight: .medium)` for a destructive
  action that fires.
- **Feel-check:** remove three rows quickly; the rest must slide up without overlapping.

---

## 6. Numeric counter

**A. Stepper with rolling digits**

**Gate:** tens/day for a stepper, purpose: state indication. Animate only changes the user caused; a balance
refreshing from the network changes without motion.

```swift
import SwiftUI

struct QuantityStepper: View {
    @Binding var quantity: Int
    var range: ClosedRange<Int> = 1...99
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Button("Decrease", systemImage: "minus") { change(by: -1) }
                .disabled(quantity <= range.lowerBound)
            Text(quantity, format: .number)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(quantity)))
                .frame(minWidth: 44)
            Button("Increase", systemImage: "plus") { change(by: 1) }
                .disabled(quantity >= range.upperBound)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .sensoryFeedback(.selection, trigger: quantity)
    }

    private func change(by delta: Int) {
        withAnimation(.spring(duration: 0.3, bounce: 0)) { quantity += delta }
    }
}
```

- `.numericText(value:)` uses the value to roll the digits the right way. `.monospacedDigit()` stops the width
  jittering as digits change.
- The spring must be bounce 0: any overshoot rolls the digits back toward the old value.
- A native `Stepper` is simpler when the design allows it.
- **Reduce Motion:** this recipe swaps the roll for a fade; the value still changes in place. The roll is
  small and stays inside the label, so keeping it is also defensible. Pick one and use it app-wide.
- **Haptic:** `.selection`, because the value ticks past a step. On iOS 26 you may add `.selection(.minimum)` /
  `.selection(.maximum)` when the range ends are hit.
- **Feel-check:** tap + rapidly; each tick must retarget smoothly, never queue.

**B. Badge pop with a triggered `phaseAnimator`**

**Gate:** occasional (an item added to the cart from a product page), purpose: feedback that the add landed
somewhere the eye isn't. Use `.symbolEffect(.bounce, value:)` instead when the thing that should pop is an
SF Symbol.

```swift
import SwiftUI

enum BadgePop: CaseIterable {
    case rest, pop
    var scale: CGFloat { self == .pop ? 1.2 : 1 }      // a starting point; tune it on a device
}

struct CartBadgeButton: View {
    let itemCount: Int
    let additions: Int                                 // increments each time the user adds an item
    let open: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pops = !reduceMotion                       // captured here, outside the animator closures
        Button(action: open) {
            Image(systemName: "cart")
                .font(.title2)
                .frame(minWidth: 44, minHeight: 44)
                .overlay(alignment: .topTrailing) {
                    Text(itemCount, format: .number)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(.red, in: Capsule())
                        .phaseAnimator(BadgePop.allCases, trigger: additions) { content, phase in
                            content.scaleEffect(pops ? phase.scale : 1)
                        } animation: { phase in
                            phase == .pop ? .spring(duration: 0.3, bounce: 0) : .spring(duration: 0.2, bounce: 0)
                        }
                }
        }
        .accessibilityLabel("Cart, \(itemCount) items")
    }
}
```

- With `trigger:` the animator plays `rest → pop → rest` once per change and stops. Without it, it loops
  forever, which is never right on idle UI.
- A counter, not a `Bool`, so every addition pops again, including two in quick succession.
- **Reduce Motion:** the scale is pinned to 1; the count still changes.
- **Haptic:** none here; the add button that caused it owns the feedback.
- **Feel-check:** add twice quickly; the second pop must play, not get swallowed.

---

## 7. Error shake

**Gate:** occasional, purpose: feedback (the input was rejected). One-shot keyframes are acceptable here
because a submit can't re-trigger faster than the shake plays. The keyframe values are a starting point that
no source publishes; tune them on a device.

```swift
import SwiftUI

struct PasscodeEntry: View {
    let verify: (String) -> Bool
    let onSuccess: () -> Void

    @State private var code = ""
    @State private var attempts = 0
    @State private var showsError = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shakes = !reduceMotion                     // captured here, outside the keyframe closures
        VStack(spacing: 12) {
            SecureField("Passcode", text: $code)
                .textFieldStyle(.roundedBorder)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.red, lineWidth: showsError ? 1.5 : 0)
                }
                .onSubmit(submit)
                .keyframeAnimator(initialValue: CGFloat.zero, trigger: attempts) { content, x in
                    content.offset(x: shakes ? x : 0)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-8, duration: 0.08)
                        CubicKeyframe(8, duration: 0.08)
                        CubicKeyframe(-5, duration: 0.08)
                        SpringKeyframe(0, duration: 0.16, spring: Spring(duration: 0.16))
                    }
                }

            if showsError {
                Text("Wrong passcode. Try again.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(.error, trigger: attempts)
    }

    private func submit() {
        guard verify(code) else {
            attempts += 1                              // drives the shake and the haptic on the same frame
            withAnimation(.spring(duration: 0.25, bounce: 0)) { showsError = true }
            code = ""
            return
        }
        withAnimation(.spring(duration: 0.25, bounce: 0)) { showsError = false }
        onSuccess()
    }
}
```

- A counter, not a `Bool`, is the trigger, so every wrong attempt shakes again.
- Cubic keyframes pass through −8, 8 and −5 exactly. A `SpringKeyframe` keeps its default 0.5 s spring unless
  you pass `spring:`, and cut off after 0.08 s that spring only reaches about ±2 pt, so the shake barely shows.
- Horizontal offset reads the same in right-to-left layouts, so no mirroring is needed.
- **Reduce Motion:** the offset is pinned to 0; the red outline, the message and the haptic still explain what
  happened.
- For an SF Symbol, `.symbolEffect(.wiggle, value: attempts)` (iOS 18) is the semantic alternative.
- **Feel-check:** the shake and the haptic must land together.

---

## 8. Success check

**A. Everyday save: symbol swap, bounce and a delayed spinner**

**Gate:** occasional, purpose: feedback (the save worked). The spinner appears only if the save takes longer
than 300 ms, so fast saves never flash one; once shown, it stays at least 400 ms.

```swift
import SwiftUI
// Uses: PressScaleStyle from recipe 1.

struct SaveButton: View {
    enum Status { case idle, saving, saved }

    let save: () async -> Bool

    @State private var status: Status = .idle
    @State private var showsSpinner = false
    @State private var spinnerSince: ContinuousClock.Instant?
    @State private var savedCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Task { await run() }
        } label: {
            HStack(spacing: 8) {
                // The image stays in the tree; the spinner sits on top. A view inserted after the spinner
                // would never see `savedCount` change, so the bounce and the symbol swap would be lost.
                Image(systemName: status == .saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: savedCount)
                    .opacity(showsSpinner ? 0 : 1)
                    .overlay {
                        if showsSpinner { ProgressView() }
                    }
                Text(status == .saved ? "Saved" : "Save")
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(status == .saving)                      // prevents a double submit, not an animation lock
        .symbolEffectsRemoved(reduceMotion)
        .sensoryFeedback(.success, trigger: savedCount)
        .task(id: status) {
            guard status == .saving else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, status == .saving else { return }
            spinnerSince = .now
            withAnimation(.easeOut(duration: 0.2)) { showsSpinner = true }
        }
    }

    private func run() async {
        status = .saving
        let ok = await save()
        if let since = spinnerSince {
            let remaining = Duration.milliseconds(400) - (ContinuousClock.now - since)
            if remaining > .zero { try? await Task.sleep(for: remaining) }
        }
        spinnerSince = nil
        withAnimation(.spring(duration: 0.3, bounce: 0)) {
            showsSpinner = false
            status = ok ? .saved : .idle
            if ok { savedCount += 1 }
        }
    }
}
```

- `savedCount` drives the bounce and the haptic together, so they land on the same frame as the check mark,
  on fast and slow saves alike, because the image is never removed while the spinner shows.
- A new save sets `status` back to `.saving`, so the symbol returns to the save glyph before the next success.
- The bounce is one-shot. Never loop a success effect.
- **Reduce Motion:** `.symbolEffectsRemoved` drops the bounce; the `.replace` swap and the haptic stay.
- **Feel-check:** a fast save and a slow (> 300 ms) save; the fast one must never show the spinner.

**B. Rare moment: a drawn check mark**

**Gate:** rare (backup complete, first purchase), purpose: delight within its budget. Cause → effect: the
square draws, and the check starts just before the square finishes, so the two read as one gesture.

```swift
import SwiftUI

struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.66))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.34))
        return path
    }
}

struct BadgeDraw {
    var box: CGFloat = 0
    var check: CGFloat = 0
    var opacity: CGFloat = 1
}

struct BackupCompleteBadge: View {
    let completions: Int                                  // increments when a backup finishes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The line-drawing curve, .timingCurve(0.645, 0.045, 0.355, 1), as a keyframe curve.
    private static let lineDrawing = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.645, y: 0.045),
                                                      endControlPoint: UnitPoint(x: 0.355, y: 1))

    var body: some View {
        let reduce = reduceMotion
        KeyframeAnimator(initialValue: BadgeDraw(), trigger: completions) { value in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .trim(from: 0, to: value.box)
                    .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                CheckMark()
                    .trim(from: 0, to: value.check)
                    .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            .opacity(value.opacity)
        } keyframes: { _ in
            // Each track starts with a MoveKeyframe, so every completion replays from an empty mark.
            // Under Reduce Motion the finished mark appears whole and fades in over a 0.2 s ease-out.
            KeyframeTrack(\.box) {
                if reduce {
                    MoveKeyframe(1)
                } else {
                    MoveKeyframe(0)
                    LinearKeyframe(1, duration: 0.6, timingCurve: Self.lineDrawing)
                }
            }
            KeyframeTrack(\.check) {
                if reduce {
                    MoveKeyframe(1)
                } else {
                    MoveKeyframe(0)
                    LinearKeyframe(0, duration: 0.5)                           // waits for the square
                    LinearKeyframe(1, duration: 0.4, timingCurve: Self.lineDrawing)
                }
            }
            KeyframeTrack(\.opacity) {
                if reduce {
                    MoveKeyframe(0)
                    LinearKeyframe(1, duration: 0.2, timingCurve: .easeOut)
                } else {
                    MoveKeyframe(1)
                }
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityElement()
        .accessibilityLabel("Backup complete")
        .sensoryFeedback(.success, trigger: completions)
    }
}
```

- A triggered `KeyframeAnimator` restarts its tracks on every change of `completions`. Resetting two `@State`
  values to 0 and animating them to 1 in the same handler would not work: SwiftUI sees only the final value,
  so every replay after the first would go from 1 to 1 and draw nothing.
- The square draws over 0.6 s; the check starts at 0.5 s and draws over 0.4 s, so the hand-off overlaps.
- The line-drawing curve is a fixed beat on purpose: it is a rare, one-shot sequence that is never retargeted.
- The haptic fires on the completion itself, the same frame the drawing starts, not when the check lands.
- **Reduce Motion:** the finished mark appears whole and fades in over 0.2 s; the haptic stays.
- For an extra beat in a celebration, a scale-in may use `.bouncy` (0.5 s, bounce 0.3). Keep everyday saves on A.
- **Feel-check:** trigger it twice in a row; the second completion must draw again from empty.

---

## 9. Card expand hero

**Gate:** occasional, purpose: spatial consistency (the detail visibly *is* the card). Choose by what happens next:

- the detail is a **navigation destination** → **A. zoom push** (iOS 18). Interactive, keeps the back swipe,
  needs no state of your own;
- the card **expands in place** on the same screen → **B. `matchedGeometryEffect`**.

**A. Zoom push, iOS 18 with an iOS 17 fallback**

```swift
import SwiftUI
// Uses: PressScaleStyle from recipe 1.

struct Album: Identifiable, Hashable {
    let id: Int
    let title: String
    let color: Color
}

private extension View {
    @ViewBuilder
    func zoomSource<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination<ID: Hashable>(id: ID, in namespace: Namespace.ID, enabled: Bool) -> some View {
        if #available(iOS 18, *), enabled {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

struct AlbumGrid: View {
    let albums: [Album]
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(album.color)
                                .frame(height: 150)
                                .overlay(alignment: .bottomLeading) {
                                    Text(album.title).font(.headline).padding()
                                }
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.97))
                        .zoomSource(id: album.id, in: zoom)
                    }
                }
                .padding()
            }
            .navigationTitle("Albums")
            .navigationDestination(for: Album.self) { album in
                AlbumDetail(album: album)                                   // the destination's root
                    .zoomDestination(id: album.id, in: zoom, enabled: !reduceMotion)
            }
        }
    }
}

struct AlbumDetail: View {
    let album: Album

    var body: some View {
        ScrollView {
            RoundedRectangle(cornerRadius: 24).fill(album.color).frame(height: 320).padding()
        }
        .navigationTitle(album.title)
    }
}
```

- `.navigationTransition` goes on the **root** of the destination. Nested inside a container there, it does
  nothing.
- Never override the timing; the system owns it, including the interactive dismiss. An interrupted zoom is
  never cancelled: it completes instantly and becomes a pop. Don't branch on "in transition", and capture a
  stable model id, not a view.
- Use it from large cells, or when the destination repeats the source's content; in dense rows make the
  thumbnail the source.
- **Reduce Motion:** the zoom is dropped for a plain push, because zoom animates depth. Branch explicitly; don't
  rely on the system adapting the zoom. On iOS 27 `.navigationTransition(.crossFade)` is the other option.

**B. In-place expansion with `matchedGeometryEffect`**

```swift
import SwiftUI
// Uses: PressScaleStyle from recipe 1.

struct Photo: Identifiable {
    let id: Int
    let title: String
    let color: Color
}

private extension View {
    /// Applies the match only when enabled, so Reduce Motion gets a crossfade instead of travel.
    @ViewBuilder
    func heroMatch<ID: Hashable>(_ id: ID, in namespace: Namespace.ID, enabled: Bool) -> some View {
        if enabled { matchedGeometryEffect(id: id, in: namespace) } else { self }
    }
}

struct ExpandingCards: View {
    let photos: [Photo]
    @Namespace private var hero
    @State private var expandedID: Photo.ID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(photos) { photo in
                        if expandedID == photo.id {
                            Color.clear.frame(height: 160)                    // holds the slot while open
                        } else {
                            Button { open(photo.id) } label: {
                                card(photo)
                                    .heroMatch(photo.id, in: hero, enabled: !reduceMotion)
                                    .frame(height: 160)
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                }
                .padding()
            }

            if let photo = photos.first(where: { $0.id == expandedID }) {
                card(photo)
                    .heroMatch(photo.id, in: hero, enabled: !reduceMotion)
                    .overlay(alignment: .topTrailing) {
                        Button("Close", systemImage: "xmark.circle.fill") { close() }
                            .labelStyle(.iconOnly)
                            .font(.title)
                            .frame(minWidth: 44, minHeight: 44)
                            .padding(8)
                    }
                    .padding()
                    .zIndex(1)
                    .transition(.opacity)
            }
        }
    }

    private func card(_ photo: Photo) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(photo.color)
            .overlay(alignment: .bottomLeading) {
                Text(photo.title).font(.headline).padding()
            }
    }

    private func open(_ id: Photo.ID) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) { expandedID = id }
    }

    private func close() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0)) { expandedID = nil }
    }
}
```

- Exactly one view per id exists at a time (the grid card is swapped for a placeholder), so there is one
  source per id and insertion and removal share one transaction.
- Opened by a tap, so bounce 0: in at 0.4 s, out at the faster 0.3 s.
- If you hand-build an App Store-style card, know that one spring on the whole frame looked wrong there:
  position springs while the size expands on its own track. That is a strong reason to use variant A instead.
- **Haptic:** none for either variant; the motion is the feedback.
- **Feel-check:** open and close mid-flight; the card must retarget, not restart.

---

## 10. Staggered first-run entrance

**Gate:** rare / first-time, purpose: explanation (the steps arrive in reading order). Stagger only the first
appearance of a small, rarely seen group: a first-run checklist, an onboarding feature list, an empty state's
first content. Search results fail the 50th-use test, so they fade in as one group; never stagger a list
scrolled all day or anything inside `List` / `LazyVStack`.

```swift
import SwiftUI

struct SetupStep: Identifiable {
    let id: UUID
    let title: String
}

struct WelcomeChecklist: View {
    let loadSteps: () async -> [SetupStep]

    @State private var steps: [SetupStep] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {                // not lazy: rows must not re-fire on reuse
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    Label(step.title, systemImage: "circle")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .transition(entrance(index))
                }
            }
            .padding()
        }
        .task {
            // Insertion driven by real state (the steps loaded), not an onAppear opacity flip.
            let loaded = await loadSteps()
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0)) { steps = loaded }
        }
    }

    private func entrance(_ index: Int) -> AnyTransition {
        if reduceMotion { return .opacity }                            // the group fades in together
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8))
                .animation(.spring(duration: 0.3, bounce: 0).delay(Double(min(index, 6)) * 0.04)),
            removal: .opacity                                          // exits together, no reverse stagger
        )
    }
}
```

- 40 ms steps, index capped at 6, so the last delay is 0.24 s, inside the 0.3 s group span. Item 20 arrives
  with item 6 instead of waiting 20 steps.
- Every row is tappable the moment it appears; nothing waits for the sequence.
- The container doesn't animate its own entrance: one entrance per container.
- **Haptic:** none. An entrance the system produced isn't a user action.
- **Feel-check:** tap the first step while the last ones are still arriving; it must respond at once.

---

## 11. Liquid Glass morph (iOS 26)

**Gate:** occasional, purpose: spatial consistency (the actions grow out of the button that revealed them).
On iOS 26, glass controls already scale, flex and shimmer on touch, so the only custom piece is the state change.

```swift
import SwiftUI

@available(iOS 26, *)
struct EditToolCluster: View {
    @State private var isExpanded = false
    @Namespace private var glass

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                if isExpanded {
                    tool("Crop", systemImage: "crop", id: "crop")
                    tool("Rotate", systemImage: "rotate.right", id: "rotate")
                }
                Button {
                    withAnimation(.smooth) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "slider.horizontal.3")
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive())
                .glassEffectID("toggle", in: glass)
                .accessibilityLabel(isExpanded ? "Close tools" : "Edit tools")
            }
        }
    }

    private func tool(_ title: String, systemImage: String, id: String) -> some View {
        Button {
            // perform the tool
        } label: {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive())
        .glassEffectID(id, in: glass)
        .accessibilityLabel(title)
    }
}
```

- Shapes within the container's `spacing` blend and morph (`.glassEffectTransition(.matchedGeometry)`, the
  default). For elements farther apart, `.glassEffectTransition(.materialize)` makes them appear in place.
- `.smooth` (0.5, bounce 0): the glass provides its own elasticity, so never add bounce on top, and never add a
  press scale to glass.
- Keep glass on the controls layer only; never glass on glass, and tint only primary actions. Limit how many
  glass effects and containers are on screen.
- **Reduce Motion / Reduce Transparency:** the system removes the elasticity and frosts the glass on its own;
  no branch needed.
- **Haptic:** none.
- **Feel-check:** toggle twice fast; the shapes must reverse mid-morph rather than pop.

---

## 12. Segmented indicator pill

**Gate:** tens/day, purpose: spatial consistency. Native `Picker(.segmented)` comes first. If the control is
used constantly, keep the native one.

```swift
import SwiftUI
// Uses: heroMatch from recipe 9B.

struct SegmentedPills<Option: Hashable & Identifiable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option

    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button {
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selection == option ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(.background)
                                    .heroMatch("pill", in: pill, enabled: !reduceMotion)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.quaternary, in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}
```

- The pill is childless, so animating its width is the sanctioned layout exception: scaling it instead would
  smear the capsule's ends.
- Only the colour of the selected label changes (`.primary` against `.secondary`), never its weight: a bolder
  label widens the segment and shifts its neighbours.
- Tens/day, yet a 0.3 s spring: the selection, the label colour and the haptic answer on the first frame, and
  the pill only animates the way there.
- **Haptic:** `.selection` on the tap that changes the value, not when the pill lands.
- **Feel-check:** tap segments rapidly in alternating order; the pill must reverse mid-travel.
