# Gesture recipes

Complete SwiftUI recipes. Read only the one you need. Each block is a single-file drop-in that typechecks for an
iOS 17 deployment target unless it is marked **(iOS 18)** or **(iOS 27)**. Helpers live in a `private extension`
at the bottom of each file, so pasting a recipe adds no module-wide names (the math behind them is in
`physics.md`).

When you adapt a recipe to the user's file, keep their type names, layout values and behaviour; take only the
gesture. The host views (`ShareHost`, `ToastHost`, ...) only show how to call each recipe.

The recipes share one skeleton. Learn it once:

- **State.** `@State` holds the dragged value. `dragStart` (or a `tracking` Bool) marks the tracking phase.
  An `@GestureState isDragging` exists only to catch a cancel, because `onEnded` doesn't run on cancel.
- **Tracking strip.** `.transaction { if dragStart != nil { $0.animation = nil } }` keeps tracking 1:1 even
  under an ancestor's implicit animation. `onEnded` clears the flag in the same update as the release, so the
  release animation passes through.
- **Release.** `release(spring, velocity:from:to:)` starts the spring at the finger's speed: `settle` for commits
  and snap-backs, `fling` for a free target reached with momentum, `reposition` for a throw across the screen, and
  `settle` for every release under Reduce Motion.
- **Haptics** go on derived state through `.sensoryFeedback`, never inside `onChanged`.
- **Accessibility.** A visible control or an accessibility action mirrors every gesture.

## Contents

1. [System sheet (try this first)](#1-system-sheet-try-this-first)
2. [Drag-to-dismiss card](#2-drag-to-dismiss-card)
3. [Custom drawer with detents](#3-custom-drawer-with-detents)
4. [Swipe-to-dismiss toast](#4-swipe-to-dismiss-toast)
5. [Photos-style pull-to-dismiss viewer](#5-photos-style-pull-to-dismiss-viewer)
6. [Swipe card (2D throw)](#6-swipe-card-2d-throw)
7. [Throw to a corner (PiP)](#7-throw-to-a-corner-pip)
8. [Hold to confirm](#8-hold-to-confirm)
9. [Drag to reorder](#9-drag-to-reorder)
10. [Swipe to reveal and full-swipe delete](#10-swipe-to-reveal-and-full-swipe-delete)
11. [Softening a grab mid-settle](#11-softening-a-grab-mid-settle)
12. [Transient drag with `@GestureState`](#12-transient-drag-with-gesturestate)
13. [Device feel-check list](#13-device-feel-check-list)

---

## 1. System sheet (try this first)

The system sheet already gives you 1:1 tracking, velocity-aware detent snapping, resistance past the largest
detent, interruptible presentation, scroll-to-expand hand-off, VoiceOver escape, Reduce Motion handling and the
iOS 26 glass treatment. If a design can be expressed as a sheet, use one.

```swift
import SwiftUI

struct FiltersHost: View {
    @State private var showFilters = false
    @State private var detent: PresentationDetent = .medium
    @State private var hasUnsavedChanges = false

    var body: some View {
        Button("Filters") { showFilters = true }
            .sheet(isPresented: $showFilters) {
                FiltersView(hasUnsavedChanges: $hasUnsavedChanges)
                    .presentationDetents([.medium, .large], selection: $detent)
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .interactiveDismissDisabled(hasUnsavedChanges)
            }
    }
}

struct FiltersView: View {
    @Binding var hasUnsavedChanges: Bool
    var body: some View {
        Toggle("Only open now", isOn: $hasUnsavedChanges).padding()
    }
}
```

- `.presentationBackgroundInteraction(.enabled(upThrough: .medium))` keeps the screen behind live below the
  medium detent (the Maps / Find My pattern).
- By default, swiping on scrollable content first grows the sheet to the next detent, then scrolls. Add
  `.presentationContentInteraction(.scrolls)` when the content should scroll first.
- `.interactiveDismissDisabled(_:)` blocks an accidental swipe that would lose work.
- Don't add haptics to a system sheet's detents; it already handles them, and yours would double up.
- On iOS 26, remove a custom `presentationBackground` so the sheet gets the system glass.
- Card → detail: `.navigationTransition(.zoom(sourceID:in:))` **(iOS 18)** is interactive and swipe-to-dismiss
  out of the box. Use it instead of rebuilding an App Store-style card expansion.
- **Zoom lessons** (from Apple's WWDC24 guidance). Key the source with a stable model ID, never a view. Don't branch
  on "in transition": an interrupted push is never cancelled; it completes and becomes a pop. It reads best from
  large cells, or when the destination repeats the source's content; in dense rows, make the thumbnail the source.
- **Zoom under Reduce Motion.** Whether the system zoom adapts on its own isn't documented. Check on a device; if it
  still zooms, fall back to the default push, or `.navigationTransition(.crossFade)` **(iOS 27)**.

**Build a custom version only when** the surface isn't a presentation: a card inside a screen region, a viewer
you pull down to dismiss on iOS 17, a drawer embedded in a map screen. Say in one line why the sheet didn't fit.
If the user keeps a custom one anyway, fix it with the recipes below rather than only recommending the sheet.

---

## 2. Drag-to-dismiss card

A bottom card dismissed by dragging down. Downward travel is 1:1, upward travel rubber-bands, the scrim derives
from the same offset, a light haptic marks the distance threshold, and the commit uses the projected rule. Both the
commit and the snap-back start at the finger's speed.

```swift
import SwiftUI

struct DismissableCard<Card: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var card: Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var offset: CGFloat = 0          // 0 = resting, positive = pulled down
    @State private var dragStart: CGFloat?
    @State private var armed = false
    @State private var cardHeight: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let travel = cardHeight                    // the card extends under the home indicator
            ZStack(alignment: .bottom) {
                if isPresented {
                    Color.black.opacity(0.4 * (1 - dragProgress(offset, over: travel)))
                        .onTapGesture { close() }
                        .accessibilityHidden(true)
                        .transition(.opacity)

                    card
                        .padding(.bottom, proxy.safeAreaInsets.bottom)   // content stays above the home indicator
                        .frame(maxWidth: .infinity)
                        .background(sizeReader { cardHeight = max($0.height, 1) })
                        .background(alignment: .top) {
                            // Extends below the card, so an upward rubber-band never shows a gap.
                            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                                .fill(.background)
                                .frame(height: cardHeight * 2)
                        }
                        .offset(y: offset)
                        .transaction { if dragStart != nil { $0.animation = nil } }   // 1:1 while tracking
                        .gesture(drag(travel: travel))
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape) { close() }                 // VoiceOver two-finger Z scrub
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new }
        .onChange(of: isDragging) { _, dragging in
            // @GestureState also resets on cancel; onEnded doesn't run then. Settle home.
            if !dragging, dragStart != nil {
                dragStart = nil
                armed = false
                withAnimation(.spring(settle)) { offset = 0 }
            }
        }
    }

    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(coordinateSpace: .global)          // the dragged view moves: measure in a stable space
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                let start = dragStart ?? offset
                dragStart = start
                let raw = start + value.translation.height
                offset = raw >= 0 ? raw : rubberband(raw, dimension: travel)   // 1:1 down, resistance up
                armed = isArmed(offset, threshold: 0.4 * travel, wasArmed: armed)
            }
            .onEnded { value in
                dragStart = nil
                armed = false
                let velocity = value.velocity.height
                if shouldCommit(translation: offset, velocity: velocity, travel: travel) {
                    withAnimation(release(settle, velocity: velocity, from: offset, to: travel)) {
                        offset = travel                     // continues the throw off-screen
                    } completion: {
                        var instant = Transaction()
                        instant.disablesAnimations = true
                        withTransaction(instant) { isPresented = false; offset = 0 }
                    }
                } else {
                    withAnimation(release(settle, velocity: velocity, from: offset, to: 0)) { offset = 0 }
                }
            }
    }

    /// Scrim tap, escape or a button: no momentum, so no bounce. Reduce Motion fades in place.
    private func close() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0)) {
            isPresented = false
        }
    }
}

private extension DismissableCard {
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }

    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }

    func shouldCommit(translation: CGFloat, velocity: CGFloat, travel: CGFloat) -> Bool {
        translation + (velocity / 1000) * 0.998 / (1 - 0.998) > 0.4 * travel   // projected end past 40 %
    }

    func rubberband(_ x: CGFloat, dimension d: CGFloat) -> CGFloat {
        let m = abs(x), c: CGFloat = 0.55
        return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)
    }

    func isArmed(_ value: CGFloat, threshold: CGFloat, wasArmed: Bool) -> Bool {
        wasArmed ? value > threshold - 20 : value >= threshold
    }

    func dragProgress(_ value: CGFloat, over distance: CGFloat) -> CGFloat {
        min(max(value / max(distance, 1), 0), 1)
    }

    func sizeReader(_ action: @escaping (CGSize) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear.onChange(of: proxy.size, initial: true) { _, size in action(size) }
        }
    }
}

struct ShareHost: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCard = false

    var body: some View {
        Button("Share") {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) {
                showCard = true                                   // tap: bounce 0
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            DismissableCard(isPresented: $showCard) {
                VStack(spacing: 16) {
                    Text("Share to…").font(.headline)
                    Button("Close") {                             // the visible non-gesture path
                        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0)) {
                            showCard = false
                        }
                    }
                }
                .padding(24)
            }
        }
    }
}
```

**Why it's built this way:**

- **The card extends under the home indicator** (its content is padded instead), so `.move(edge: .bottom)` and
  `offset = travel` both take it fully off-screen.
- **Scrim and card are separate views with their own transitions**, changed in one transaction. A single
  `.move` on a parent would slide the scrim along with the card.
- **The release velocity is passed explicitly.** The spring leaves the finger at the speed it was moving, for the
  commit and the snap-back alike; the scrim, derived from the same offset, follows in step.
- **Commit is `settle`.** Overshoot happens off-screen, where it's invisible. The removal then runs without
  animation.
- **Snap-back is `settle`, not `fling`.** Returning past rest toward the top would read as the card trying to
  re-open, and a slow snap-back feels like the UI disagreeing with the user.
- **The background extends below the card**, so a rubber-band upward or a fast snap-back never shows a gap.
- **Cancel safety.** If the system cancels the drag (an incoming call, Notification Center), `onEnded` never
  runs; the `isDragging` flip settles the card home. This relies on `onEnded` clearing `dragStart` before the
  `onChange` observer sees the reset, an order Apple doesn't document. If a normal release ever snaps home instead
  of committing on a device, defer the check one turn so `onEnded` always gets there first:

  ```swift
  // Replaces the body of .onChange(of: isDragging) in DismissableCard.
  if !dragging {
      Task { @MainActor in
          guard dragStart != nil else { return }      // onEnded already ran: a normal release
          dragStart = nil
          armed = false
          withAnimation(.spring(settle)) { offset = 0 }
      }
  }
  ```

  The same change applies to every recipe below that uses the `isDragging` flip.
- **Reduce Motion.** Presenting and closing by button fade in place. A drag release still moves (with `settle`),
  because the user produced that motion.

---

## 3. Custom drawer with detents

Only when the system sheet doesn't fit, such as a drawer embedded in a map screen that isn't a presentation.
It snaps by projection between three stops, rubber-bands past the end stops, plays a haptic when a new detent
catches, and its grabber is a button with an adjustable action.

```swift
import SwiftUI

struct SnapDrawer<Content: View>: View {
    enum Detent: Int, CaseIterable {
        case peek, half, full

        var label: LocalizedStringResource {        // what VoiceOver reads as the grabber's value
            switch self {
            case .peek: "Collapsed"
            case .half: "Half height"
            case .full: "Full height"
            }
        }
    }

    @Binding var detent: Detent
    var peekHeight: CGFloat = 120
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var position: CGFloat?           // nil = resting at `detent`
    @State private var dragStart: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let stops = stops(in: height)
            let rest = stops[detent] ?? 0

            VStack(spacing: 0) {
                grabber
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .offset(y: position ?? rest)
            .transaction { if dragStart != nil { $0.animation = nil } }
            .gesture(drag(stops: stops, height: height, rest: rest))
            .onChange(of: isDragging) { _, dragging in
                if !dragging, dragStart != nil {            // cancelled
                    dragStart = nil
                    withAnimation(.spring(settle)) { position = rest }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sensoryFeedback(.impact(weight: .light), trigger: detent)   // fires when a new detent catches
    }

    private var grabber: some View {
        Button { step(by: detent == .full ? -2 : 1) } label: {
            Capsule().fill(.secondary).frame(width: 36, height: 5)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Drawer")
        .accessibilityValue(Text(detent.label))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private func stops(in height: CGFloat) -> [Detent: CGFloat] {
        [.full: height * 0.08, .half: height * 0.5, .peek: height - peekHeight]
    }

    private func drag(stops: [Detent: CGFloat], height: CGFloat, rest: CGFloat) -> some Gesture {
        let top = stops[.full] ?? 0
        let bottom = stops[.peek] ?? height
        return DragGesture(coordinateSpace: .global)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                let start = dragStart ?? (position ?? rest)
                dragStart = start
                position = rubberbanded(start + value.translation.height, in: top...bottom, dimension: height)
            }
            .onEnded { value in
                dragStart = nil
                let current = position ?? rest
                let velocity = value.velocity.height
                let target = snapTarget(from: current, velocity: velocity, points: Array(stops.values))
                let next = stops.first { $0.value == target }?.key ?? detent
                // Back from a rubber-banded overdrag to that end stop: no bounce, or it re-enters the overdrag.
                let overdragged = (current < top && target == top) || (current > bottom && target == bottom)
                let spring = reduceMotion || overdragged ? settle : fling   // free target: a little overshoot
                withAnimation(release(spring, velocity: velocity, from: current, to: target)) {
                    detent = next
                    position = target
                } completion: {
                    if dragStart == nil { position = nil }           // hand control back to `detent`
                }
            }
    }

    /// Grabber tap or VoiceOver adjust: a tap carries no momentum, so no bounce.
    private func step(by delta: Int) {
        let all = Detent.allCases
        let next = all[min(max(detent.rawValue + delta, 0), all.count - 1)]
        // Reduce Motion: the same motion, shortened to 0.15 s, because a fade can't show a detent change.
        withAnimation(reduceMotion ? .spring(duration: 0.15, bounce: 0) : .spring(duration: 0.4, bounce: 0)) {
            detent = next
            position = nil
        }
    }
}

private extension SnapDrawer {
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }
    var fling: Spring { Spring(duration: 0.3, bounce: 0.2) }

    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }

    func snapTarget(from position: CGFloat, velocity: CGFloat, points: [CGFloat]) -> CGFloat {
        let projected = position + (velocity / 1000) * 0.998 / (1 - 0.998)   // where the throw would come to rest
        return points.min { abs($0 - projected) < abs($1 - projected) } ?? position
    }

    func rubberbanded(_ value: CGFloat, in range: ClosedRange<CGFloat>, dimension d: CGFloat) -> CGFloat {
        func band(_ x: CGFloat) -> CGFloat {
            let m = abs(x), c: CGFloat = 0.55
            return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)
        }
        if value < range.lowerBound { return range.lowerBound + band(value - range.lowerBound) }
        if value > range.upperBound { return range.upperBound + band(value - range.upperBound) }
        return value
    }
}
```

**Notes:**

- **`position` is non-nil only while dragging or settling.** At rest, `detent` drives the layout, so rotation and
  container resizes re-flow. The completion hands control back only if no new drag started.
- **`fling` for a free detent, `settle` back from an overdrag.** A release past the top or bottom stop toward
  that stop uses `settle`: a bounce would carry it back into the overdrag zone.
- **The drawer is as tall as its container**, so a `fling` overshoot at the top never lifts its bottom edge into
  view.
- **The haptic is attached to `detent`**, which changes in `onEnded`: the frame the stop catches, not 0.3 s
  later. A snap back to the same detent doesn't fire it.
- **The stop fractions (8 %, 50 %, peek 120 pt) are layout inputs.** Set them from your design.
- **Scrollable content inside the drawer** is the hard part the system sheet solves for you: the drawer must
  grow first and scroll only at the top detent, and a drag should be ignored for ~100 ms after the content
  scrolls back to the top, or the end of a fast scroll turns into an accidental collapse. Reconsider `.sheet`
  first; if the drawer must stay embedded, see the hand-off signals below.

**Scroll hand-off (iOS 18).** `onScrollGeometryChange` and `onScrollPhaseChange` give the two signals the hand-off
needs: is the content at its top, and has scrolling come to rest. Scroll only at the top detent, and let a drag
collapse the drawer only once the content is idle at its top for ~100 ms:

```swift
import SwiftUI

/// (iOS 18) Scrollable drawer content that reports when a downward drag may move the drawer instead.
@available(iOS 18, *)
struct DrawerScrollContent<Content: View>: View {
    let isFull: Bool                          // the drawer rests at its top detent
    @Binding var canCollapse: Bool
    @ViewBuilder var content: Content

    @State private var atTop = true
    @State private var phase: ScrollPhase = .idle

    var body: some View {
        ScrollView { content }
            .scrollDisabled(!isFull)              // below the top detent, every drag moves the drawer
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y <= -geometry.contentInsets.top
            } action: { _, top in
                atTop = top
            }
            .onScrollPhaseChange { _, new in phase = new }
            .task(id: atTop && phase == .idle) {
                canCollapse = false
                guard atTop, phase == .idle else { return }
                try? await Task.sleep(for: .milliseconds(100))   // the end of a fast scroll isn't a collapse
                if !Task.isCancelled { canCollapse = true }
            }
    }
}
```

Pass `isFull: detent == .full` and gate the drawer's drag with `.gesture(drag(...), isEnabled: detent != .full ||
canCollapse)`. The scroll view still owns its own pan at the top detent, so check on a device that a downward drag
from the top moves the drawer rather than stretching the content; if the two fight, that is the point to go back to
the system sheet.

---

## 4. Swipe-to-dismiss toast

The toast's entrance and exit belong to the presenter (swift-motion-animate): `.move(edge: .top)` combined
with `.opacity`, a 0.4 s spring in, a 0.3 s spring out, `.opacity` under Reduce Motion. This recipe adds the
swipe. It dismisses toward the edge it came from (exit the way you entered), rubber-bands the other way, fades as
it is pushed out (a linked value), and pauses its timer while dragged or while the app isn't active.

**Adding a swipe to an existing toast?** Take only the gesture. Keep the toast's lifetime, layout and
announcement as they are; if they differ from the guidance below (4 s, paused while inactive), suggest the change
in your reply instead of making it.

```swift
import SwiftUI

struct SwipeableToast: View {
    let message: LocalizedStringResource
    var autoDismiss = true                   // false when the toast carries an action: it stays until handled
    let onDismiss: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var isDragging = false
    @State private var offset: CGFloat = 0   // negative = pushed up, toward the edge it came from
    @State private var tracking = false
    @State private var height: CGFloat = 1

    var body: some View {
        Text(message)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(.regularMaterial, in: .capsule)
            .background(sizeReader { height = max($0.height, 1) })
            .offset(y: offset)
            .opacity(1 - dragProgress(-offset, over: height))   // fades out as it leaves
            .transaction { if tracking { $0.animation = nil } }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        tracking = true
                        let raw = value.translation.height
                        offset = raw <= 0 ? raw : rubberband(raw, dimension: height)
                    }
                    .onEnded { value in
                        tracking = false
                        let velocity = value.velocity.height
                        // "Toward the edge" is negative y: flip both signs.
                        if shouldCommit(translation: -offset, velocity: -velocity, travel: height) {
                            withAnimation(release(settle, velocity: velocity, from: offset, to: -height)) {
                                offset = -height
                            } completion: { onDismiss() }
                        } else {
                            withAnimation(release(settle, velocity: velocity, from: offset, to: 0)) { offset = 0 }
                        }
                    }
            )
            .onChange(of: isDragging) { _, dragging in
                if !dragging, tracking {                     // cancelled
                    tracking = false
                    withAnimation(.spring(settle)) { offset = 0 }
                }
            }
            .accessibilityAction(named: "Dismiss") { onDismiss() }
            .onAppear {
                AccessibilityNotification.Announcement(String(localized: message)).post()
            }
            // Restarts whenever a pause input changes; sleeps only while idle and visible.
            .task(id: isDragging || scenePhase != .active) {
                guard autoDismiss, !isDragging, scenePhase == .active else { return }
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                onDismiss()                                  // the presenter's exit transition runs
            }
    }
}

private extension SwipeableToast {
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }

    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }

    func shouldCommit(translation: CGFloat, velocity: CGFloat, travel: CGFloat) -> Bool {
        translation + (velocity / 1000) * 0.998 / (1 - 0.998) > 0.4 * travel
    }

    func rubberband(_ x: CGFloat, dimension d: CGFloat) -> CGFloat {
        let m = abs(x), c: CGFloat = 0.55
        return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)
    }

    func dragProgress(_ value: CGFloat, over distance: CGFloat) -> CGFloat {
        min(max(value / max(distance, 1), 0), 1)
    }

    func sizeReader(_ action: @escaping (CGSize) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear.onChange(of: proxy.size, initial: true) { _, size in action(size) }
        }
    }
}

struct ToastHost: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toast: LocalizedStringResource?

    var body: some View {
        Button("Save") {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0)) {
                toast = "Saved"
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let toast {
                SwipeableToast(message: toast) {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0)) {
                        self.toast = nil
                    }
                }
                .padding(.top, 8)                            // inside the safe area
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
```

- **A swipe commit finishes with `settle`** at the finger's speed, already invisible at `-height`, then
  `onDismiss` removes it; the removal transition plays on an invisible view.
- **The timer and the accessibility action call `onDismiss` directly**, so a non-gesture dismissal gets the
  presenter's exit, not a fake throw.
- **Lifetime 4 s**, restarted after each drag, paused while the app is inactive. A toast with an action stays
  until it's acted on or dismissed. Apple's guidance is to keep time-boxed UI to a minimum; the 4 s is a house
  value.

---

## 5. Photos-style pull-to-dismiss viewer

**Prefer the system first.** On iOS 18+, push or present the viewer with `.navigationTransition(.zoom(sourceID:in:))`
from a thumbnail marked `.matchedTransitionSource(id:in:)`. The zoom transition is already pull-to-dismiss,
interruptible and tuned. Build this for an iOS 17 target or an inline viewer.

The photo follows the finger in 2D; pulling down dismisses, pulling up rubber-bands. The backdrop fades
progressively over **half the container height** and the photo shrinks slightly with it, so the dismissal is
visible as it builds; the close button gets out of the way over the first 50 pt. Commit uses the full-screen media
pair: **velocity down > ~1000 pt/s, or distance > ¼ of the height**, unless the user flicks back hard. Every release
starts at the finger's speed, per axis.

```swift
import SwiftUI

struct PhotoViewer: View {
    let image: Image
    var isZoomed = false                      // pass true while pinch-zoomed: panning wins then
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var x: CGFloat = 0
    @State private var y: CGFloat = 0         // positive = pulled down, toward dismissal
    @State private var tracking = false

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let progress = dragProgress(y, over: height / 2)          // 0 at rest, 1 at half the height

            ZStack(alignment: .topTrailing) {
                Color.black
                    .opacity(1 - progress)
                    .ignoresSafeArea()

                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(reduceMotion ? 1 : 1 - 0.14 * progress)   // a depth cue: off under Reduce Motion
                    .offset(x: x)
                    .offset(y: y)                     // two modifiers: each axis gets its own velocity
                    .transaction { if tracking { $0.animation = nil } }
                    .gesture(drag(height: height), isEnabled: !isZoomed)
                    .accessibilityAction(.escape) { onDismiss() }

                Button("Close", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .padding()
                    .opacity(1 - dragProgress(abs(y), over: 50))
                    .zIndex(1)                        // stays above the photo while it moves
            }
        }
        .onChange(of: isDragging) { _, dragging in
            if !dragging, tracking {                 // cancelled
                tracking = false
                withAnimation(.spring(settle)) { x = 0 }
                withAnimation(.spring(settle)) { y = 0 }
            }
        }
    }

    private func drag(height: CGFloat) -> some Gesture {
        DragGesture(coordinateSpace: .global)         // the photo moves: measure in a stable space
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                tracking = true
                x = value.translation.width
                let raw = value.translation.height
                y = raw >= 0 ? raw : rubberband(raw, dimension: height)   // up isn't a dismissal: resist
            }
            .onEnded { value in
                tracking = false
                let vx = value.velocity.width
                let vy = value.velocity.height
                if vy > 1000 || (y > height / 4 && vy > -1000) {
                    withAnimation(release(settle, velocity: vy, from: y, to: height)) {
                        y = height
                    } completion: { onDismiss() }
                } else {
                    withAnimation(release(settle, velocity: vx, from: x, to: 0)) { x = 0 }   // snap back: bounce 0
                    withAnimation(release(settle, velocity: vy, from: y, to: 0)) { y = 0 }
                }
            }
    }
}

private extension PhotoViewer {
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }

    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }

    func rubberband(_ x: CGFloat, dimension d: CGFloat) -> CGFloat {
        let m = abs(x), c: CGFloat = 0.55
        return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)
    }

    func dragProgress(_ value: CGFloat, over distance: CGFloat) -> CGFloat {
        min(max(value / max(distance, 1), 0), 1)
    }
}
```

- **Why not 40 %?** Dragging a photo 40 % of the screen is a long way. The ~1000 pt/s or ¼-height pair is a
  reference from a well-known messaging app's media viewer, not an Apple value; tune it on a device.
- **Why fade over half the height?** At the ¼-height commit point the backdrop is half gone, so the user sees the
  dismissal building and can judge it. A backdrop that is fully black-to-clear within 80 pt reads as a switch. The
  0.86 end scale is a design value; drop it if the photo should stay full size.
- **The dismissal starts at the finger's speed** and finishes off the bottom edge, where overshoot is invisible;
  the backdrop and scale, derived from `y`, follow it in step.
- **Embedded in an existing screen?** If the viewer shares a `ZStack` with other content, give it `.zIndex(1)` so
  the moving photo isn't drawn under a sibling added later.
- **`.gesture(_:isEnabled:)`** disables the dismiss drag while zoomed without changing the view's structure
  mid-gesture.
- **The screen underneath** can restore (scale, dim) over the same drag. Pass the progress out through a binding
  and derive it there; never run a separate animation.
- **Reduce Motion:** tracking stays 1:1, every release is already `settle`, and the scale is dropped. The backdrop
  fade stays, because it explains what is happening.

---

## 6. Swipe card (2D throw)

A deck card thrown left or right. `x` and `y` are separate `@State` values with separate `withAnimation` calls, so
each axis starts at its own velocity: a diagonal throw has a different relative velocity on each axis. The decision
uses the signed projected rule on x. Visible Like and Skip buttons reach the card through the `request` binding.

```swift
import SwiftUI

struct SwipeCard<Content: View>: View {
    /// Set to true (Like) or false (Skip) from visible buttons; the card throws itself and clears it.
    @Binding var request: Bool?
    let onDecide: (_ liked: Bool) -> Void
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var x: CGFloat = 0
    @State private var y: CGFloat = 0
    @State private var tracking = false
    @State private var width: CGFloat = 1
    @State private var armed = false
    @State private var faded = false

    var body: some View {
        content
            .background(sizeReader { width = max($0.width, 1) })
            .offset(x: x)
            .offset(y: y)
            .opacity(faded ? 0 : 1)
            .transaction { if tracking { $0.animation = nil } }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        tracking = true
                        x = value.translation.width
                        y = value.translation.height
                        armed = isArmed(abs(x), threshold: 0.4 * width, wasArmed: armed)
                    }
                    .onEnded { value in
                        tracking = false
                        armed = false
                        let vx = value.velocity.width, vy = value.velocity.height
                        let side: CGFloat = x + project(vx) >= 0 ? 1 : -1
                        if shouldCommit(translation: side * x, velocity: side * vx, travel: width) {
                            throwAway(liked: side > 0, vx: vx, vy: vy)
                        } else {
                            let spring = reduceMotion ? settle : fling     // free target, momentum
                            withAnimation(release(spring, velocity: vx, from: x, to: 0)) { x = 0 }
                            withAnimation(release(spring, velocity: vy, from: y, to: 0)) { y = 0 }
                        }
                    }
            )
            .onChange(of: isDragging) { _, dragging in
                if !dragging, tracking {                     // cancelled
                    tracking = false
                    armed = false
                    withAnimation(.spring(settle)) { x = 0 }
                    withAnimation(.spring(settle)) { y = 0 }
                }
            }
            .onChange(of: request) { _, new in
                guard let liked = new else { return }
                request = nil
                decide(liked: liked)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new }
            .accessibilityAction(named: "Like") { decide(liked: true) }
            .accessibilityAction(named: "Skip") { decide(liked: false) }
    }

    /// The non-gesture path: visible buttons (through `request`) and the accessibility actions.
    private func decide(liked: Bool) {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { faded = true } completion: { onDecide(liked) }
        } else {
            throwAway(liked: liked, vx: 0, vy: 0)
        }
    }

    /// Commit: continue along the throw, two card widths off-centre.
    private func throwAway(liked: Bool, vx: CGFloat, vy: CGFloat) {
        let targetX = (liked ? 1 : -1) * 2 * width
        let targetY = y + project(vy)
        withAnimation(release(settle, velocity: vy, from: y, to: targetY)) { y = targetY }
        withAnimation(release(settle, velocity: vx, from: x, to: targetX)) {
            x = targetX
        } completion: {
            onDecide(liked)
        }
    }
}

private extension SwipeCard {
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }
    var fling: Spring { Spring(duration: 0.3, bounce: 0.2) }

    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }

    func project(_ velocity: CGFloat) -> CGFloat {
        (velocity / 1000) * 0.998 / (1 - 0.998)
    }

    func shouldCommit(translation: CGFloat, velocity: CGFloat, travel: CGFloat) -> Bool {
        translation + project(velocity) > 0.4 * travel
    }

    func isArmed(_ value: CGFloat, threshold: CGFloat, wasArmed: Bool) -> Bool {
        wasArmed ? value > threshold - 20 : value >= threshold
    }

    func sizeReader(_ action: @escaping (CGSize) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear.onChange(of: proxy.size, initial: true) { _, size in action(size) }
        }
    }
}

struct DeckHost: View {
    @State private var cards = ["Lisbon", "Kyoto", "Oslo"]
    @State private var request: Bool?

    var body: some View {
        VStack(spacing: 24) {
            if let card = cards.last {
                SwipeCard(request: $request) { _ in
                    cards.removeLast()
                } content: {
                    Text(card)
                        .font(.title)
                        .frame(width: 280, height: 380)
                        .background(.background, in: .rect(cornerRadius: 24))
                }
                .id(card)                                   // fresh drag state for each card
                .zIndex(1)                                  // the thrown card stays above the buttons
            }
            HStack(spacing: 32) {
                Button("Skip") { request = false }
                Button("Like") { request = true }
            }
            .disabled(cards.isEmpty)
        }
    }
}
```

- **Ship visible Like and Skip buttons.** The swipe is the shortcut, not the only way. A parent can't call a
  method on the card (it only holds a copy of the struct), so the buttons set `request` and the card reacts.
- **The card is a free target**, floating mid-screen with no edge behind it, so the snap-back may overshoot a
  little (`fling`). A dismissable surface resting against an edge snaps back with `settle` instead.
- **Tilt**, if the design wants it, derives from `x` in `body` (`.rotationEffect(.degrees(Double(x / width) * maxTilt))`)
  and is dropped under Reduce Motion. The angle is a design value, not a motion value.

---

## 7. Throw to a corner (PiP)

A floating player thrown into the corner nearest its **projected** resting point, not the corner nearest the
release, as Apple's Picture in Picture does. Critically damped, 0.4 s, each axis released at its own velocity.

```swift
import SwiftUI

struct FloatingPlayer<Content: View>: View {
    enum Corner: Int, CaseIterable { case topLeading, topTrailing, bottomLeading, bottomTrailing }

    var size = CGSize(width: 160, height: 90)
    var margin: CGFloat = 16
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var corner = Corner.bottomTrailing
    @State private var x: CGFloat = 0                  // top-leading origin of the player
    @State private var y: CGFloat = 0
    @State private var dragStart: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let container = proxy.size
            content
                .frame(width: size.width, height: size.height)
                .clipShape(.rect(cornerRadius: 12))
                .offset(x: x)
                .offset(y: y)
                .transaction { if dragStart != nil { $0.animation = nil } }
                .gesture(drag(in: container))
                .onChange(of: container, initial: true) { _, new in
                    let origin = origin(of: corner, in: new)       // place without animation
                    x = origin.x
                    y = origin.y
                }
                .onChange(of: isDragging) { _, dragging in
                    if !dragging, dragStart != nil {               // cancelled
                        dragStart = nil
                        move(to: corner, in: container, velocity: .zero)
                    }
                }
                .accessibilityAction(named: "Move to next corner") {
                    let all = Corner.allCases
                    move(to: all[(corner.rawValue + 1) % all.count], in: container, velocity: .zero)
                }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: corner)   // snaps into a new corner
    }

    private func drag(in container: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                let start = dragStart ?? CGPoint(x: x, y: y)
                dragStart = start
                x = start.x + value.translation.width              // 1:1, keeping the grab offset
                y = start.y + value.translation.height
            }
            .onEnded { value in
                dragStart = nil
                let projected = CGPoint(x: x + project(value.velocity.width),
                                        y: y + project(value.velocity.height))
                let nearest = Corner.allCases.min { a, b in
                    distance(origin(of: a, in: container), projected) < distance(origin(of: b, in: container), projected)
                } ?? corner
                move(to: nearest, in: container, velocity: value.velocity)
            }
    }

    private func move(to target: Corner, in container: CGSize, velocity: CGSize) {
        corner = target
        let origin = origin(of: target, in: container)
        let spring = reduceMotion ? settle : reposition
        withAnimation(release(spring, velocity: velocity.width, from: x, to: origin.x)) { x = origin.x }
        withAnimation(release(spring, velocity: velocity.height, from: y, to: origin.y)) { y = origin.y }
    }

    private func origin(of corner: Corner, in container: CGSize) -> CGPoint {
        let left = margin, right = container.width - size.width - margin
        let top = margin, bottom = container.height - size.height - margin
        switch corner {
        case .topLeading: return CGPoint(x: left, y: top)
        case .topTrailing: return CGPoint(x: right, y: top)
        case .bottomLeading: return CGPoint(x: left, y: bottom)
        case .bottomTrailing: return CGPoint(x: right, y: bottom)
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

private extension FloatingPlayer {
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }
    var reposition: Spring { Spring(duration: 0.4, bounce: 0) }

    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }

    func project(_ velocity: CGFloat) -> CGFloat {
        (velocity / 1000) * 0.998 / (1 - 0.998)
    }
}
```

- **Projection does the work.** A gentle push from the bottom-right toward the left still lands bottom-left;
  a hard diagonal throw crosses the screen.
- **Bounce 0**: a corner is a hard edge, and a throw across the screen reads better without wobble.
- **Hit target:** the player is far above 44 × 44 pt. A smaller floating element needs `.contentShape` padding.

---

## 8. Hold to confirm

A deliberate hold. The fill runs `.linear(duration: T)` during the hold: the animation visualizes time passing, and
time passes linearly; any other curve lies about how long is left. Releasing early rewinds fast with a 0.2 s spring.
Completion plays `.success` (`.impact(weight: .medium)` when the action is destructive). The deliberate phase is
slow and honest; the cancel is instant. Symmetric timing here is a bug.

```swift
import SwiftUI

struct HoldToConfirmButton: View {
    let title: LocalizedStringKey
    /// 0.5 s (the system long-press default). For a destructive action, the fill itself is the safety:
    /// use ~1–2 s and tune on a device, and play `.impact(weight: .medium)` on commit instead of `.success`.
    var holdDuration: Double = 0.5
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var pressStart: Date?
    @State private var confirmations = 0

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                Rectangle()
                    .fill(.red.opacity(0.35))
                    .scaleEffect(x: progress, y: 1, anchor: .leading)   // render-only; the capsule clip keeps the shape
            }
            .background(.quaternary)
            .clipShape(.capsule)
            .contentShape(.capsule)
            .onLongPressGesture(minimumDuration: holdDuration) {
                commit()
            } onPressingChanged: { pressing in
                if pressing {
                    pressStart = .now
                    withAnimation(.linear(duration: holdDuration)) { progress = 1 }
                } else if let start = pressStart, Date.now.timeIntervalSince(start) < holdDuration {
                    pressStart = nil
                    withAnimation(.spring(duration: 0.2, bounce: 0)) { progress = 0 }   // early release: fast
                }
            }
            .sensoryFeedback(.success, trigger: confirmations)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { commit() }       // VoiceOver's double-tap is already deliberate
    }

    private func commit() {
        pressStart = nil
        confirmations += 1
        action()
        withAnimation(.spring(duration: 0.2, bounce: 0)) { progress = 0 }
    }
}
```

- **The early-release check compares elapsed time**, so it's correct whichever order SwiftUI calls `perform` and
  `onPressingChanged(false)` in.
- **Drifting more than 10 pt** (the default `maximumDistance`) fails the press, and the fill rewinds.
- **The fill is `scaleEffect(x:anchor:)` on a plain rectangle under a capsule clip**: render-only, and nothing is
  smeared because the rectangle has no corners of its own.
- **Accessibility:** the default action commits. For an irreversible action, route it through a
  `confirmationDialog` instead.
- **Reduce Motion:** keep the fill. It's a progress indicator, not travel.

---

## 9. Drag to reorder

Prefer the system, in this order.

**a. `List` + `onMove`.** The system lift, gap, autoscroll and haptics come free. `EditButton` is the visible,
accessible path.

```swift
import SwiftUI

struct Chore: Identifiable, Hashable { let id: UUID; var title: String }

struct ChoresList: View {
    @State private var chores: [Chore] = []
    var body: some View {
        List {
            ForEach(chores) { Text($0.title) }
                .onMove { chores.move(fromOffsets: $0, toOffset: $1) }
        }
        .toolbar { EditButton() }
    }
}
```

**b. Stacks, grids and custom layouts (iOS 27):** `.reorderable()` on the `ForEach` and
`.reorderContainer(for:isEnabled:move:)` on the container. Apply the `ReorderDifference` to your array.

```swift
import SwiftUI

// Uses `Chore` from block a.
@available(iOS 27, *)
struct ChoresStack: View {
    @State private var chores: [Chore] = []
    var isSaving = false

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(chores) { Text($0.title) }
                    .reorderable()
            }
            .reorderContainer(for: Chore.self, isEnabled: !isSaving) { difference in
                apply(difference)
            }
        }
    }

    private func apply(_ difference: ReorderDifference<Chore.ID, ReorderableSingleCollectionIdentifier>) {
        let moving = chores.filter { difference.sources.contains($0.id) }
        chores.removeAll { difference.sources.contains($0.id) }
        switch difference.destination.position {
        case .before(let id):
            let index = chores.firstIndex { $0.id == id } ?? chores.endIndex
            chores.insert(contentsOf: moving, at: index)
        case .end:
            chores.append(contentsOf: moving)
        }
    }
}
```

Use `.reorderable(collectionID:)` with `reorderContainer(for:in:isEnabled:move:)` to move items between
sections.

**c. A custom stack for iOS 17–26**, when the rows aren't in a `List`. A long press lifts the row (sequencing it
before the drag keeps scrolling working) with a light impact, a slight scale and a shadow; the lifted row tracks
1:1, neighbours make room with a 0.3 s spring, `.selection` plays on each slot crossed, and a light impact plays
when the row drops into place.

```swift
import SwiftUI

// Uses `Chore` from block a.
struct ReorderStack: View {
    @Binding var chores: [Chore]
    var rowHeight: CGFloat = 56              // fixed-height rows keep the slot math simple

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isReordering = false
    @State private var dragged: Chore.ID?
    @State private var startIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var slot = 0
    @State private var crossings = 0                 // counts slot changes only, so the lift doesn't tick

    private let reflow = Animation.spring(duration: 0.3, bounce: 0)   // neighbours making room

    var body: some View {
        VStack(spacing: 0) {
            ForEach(chores) { chore in
                let isDragged = dragged == chore.id
                Text(chore.title)
                    .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
                    .padding(.horizontal)
                    .background(isDragged ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.background))
                    .offset(y: isDragged ? dragOffset : 0)
                    .transaction { if isDragged { $0.animation = nil } }   // the lifted row tracks 1:1
                    // Outside the strip, so the lift and the drop animate. No scale under Reduce Motion.
                    .scaleEffect(isDragged && !reduceMotion ? 1.03 : 1)
                    .shadow(color: .black.opacity(isDragged ? 0.15 : 0), radius: 8, y: 4)
                    .zIndex(isDragged ? 1 : 0)
                    .gesture(reorder(chore))
                    .accessibilityAction(named: "Move up") { move(chore, by: -1) }
                    .accessibilityAction(named: "Move down") { move(chore, by: 1) }
            }
        }
        .onChange(of: isReordering) { _, active in
            if !active, dragged != nil {                   // cancelled: drop in place
                withAnimation(.spring(duration: 0.3, bounce: 0)) { dragOffset = 0; dragged = nil }
            }
        }
        .sensoryFeedback(.selection, trigger: crossings)                                      // each slot crossed
        .sensoryFeedback(.impact(weight: .light), trigger: dragged == nil)                    // lift and drop
    }

    private func reorder(_ chore: Chore) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(coordinateSpace: .global))
            .updating($isReordering) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if dragged == nil, let index = chores.firstIndex(of: chore) {
                    startIndex = index
                    slot = index
                    withAnimation(reflow) { dragged = chore.id }   // lift: scale and shadow only
                }
                let translation = drag?.translation.height ?? 0
                let proposed = min(max(startIndex + Int((translation / rowHeight).rounded()), 0), chores.count - 1)
                if proposed != slot, let from = chores.firstIndex(of: chore) {
                    withAnimation(reflow) {
                        chores.move(fromOffsets: [from], toOffset: proposed > from ? proposed + 1 : proposed)
                    }
                    slot = proposed
                    crossings += 1
                }
                dragOffset = translation - CGFloat(slot - startIndex) * rowHeight
            }
            .onEnded { value in
                var velocity: CGFloat = 0
                if case .second(true, let drag?) = value { velocity = drag.velocity.height }
                withAnimation(release(Spring(duration: 0.3, bounce: 0), velocity: velocity, from: dragOffset, to: 0)) {
                    dragOffset = 0
                    dragged = nil
                }
            }
    }

    private func move(_ chore: Chore, by delta: Int) {
        guard let from = chores.firstIndex(of: chore) else { return }
        let to = min(max(from + delta, 0), chores.count - 1)
        guard to != from else { return }
        withAnimation(reflow) {
            chores.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        }
    }
}

private extension ReorderStack {
    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }
}
```

- **Fixed row height** makes the slot a division. For variable heights, collect row frames with a size reader and
  find the slot by midpoint.
- **The lifted row's transaction strip** keeps it glued to the finger while the array move animates the others.
  On a device, a lifted row that lags by a frame on a swap means the strip isn't reaching it.
- **A cancelled sequence** (the long press fails, or the system interrupts) drops the row in place through the
  `isReordering` flip.

---

## 10. Swipe to reveal and full-swipe delete

Prefer `.swipeActions` in a `List`. On **iOS 27** it also works in a `ScrollView` / `LazyVStack`, coordinated by
`.swipeActionsContainer()` (one row open at a time, scrolling closes it):

```swift
import SwiftUI

// Uses `Chore` from the reorder recipe (block a).
@available(iOS 27, *)
struct ChoresFeed: View {
    @State private var chores: [Chore] = []
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(chores) { chore in
                    Text(chore.title)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                withAnimation(.spring(duration: 0.3, bounce: 0)) {
                                    chores.removeAll { $0.id == chore.id }
                                }
                            }
                        }
                }
            }
        }
        .swipeActionsContainer()
    }
}
```

Build it by hand only below iOS 27 outside a `List`. The axis locks on the first change; the gesture claims only
the horizontal axis through `.simultaneousGesture`, so vertical scrolling keeps working. It snaps by projection
between open and closed. Only a long swipe deletes: the finger must cross 40 % of the row, because a projected
rule alone would turn an ordinary reveal flick into a delete. Haptics follow the two-stage pattern: light when the
full swipe arms, medium when the delete fires.

```swift
import SwiftUI

struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void                 // remove the item; called inside an animation
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var horizontal: Bool?     // the axis, decided on the first change
    @State private var x: CGFloat = 0        // 0 = closed, -revealWidth = open
    @State private var dragStart: CGFloat?
    @State private var width: CGFloat = 1
    @State private var armed = false
    @State private var deletions = 0
    private let revealWidth: CGFloat = 88

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(.background)
            .background(sizeReader { width = max($0.width, 1) })
            .offset(x: x)
            .transaction { if dragStart != nil { $0.animation = nil } }
            .background {                                    // stays in place while the row slides
                HStack {
                    Spacer()
                    Button("Delete", role: .destructive) { delete(velocity: 0) }
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                }
                .foregroundStyle(.white)
                .background(.red)
                .opacity(x < 0 ? 1 : 0)
                .accessibilityHidden(true)                   // reachable through the row's action instead
            }
            .simultaneousGesture(
                DragGesture(coordinateSpace: .global)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        if horizontal == nil { horizontal = isHorizontal(value.translation) }
                        guard horizontal == true else { return }   // vertical: the ScrollView keeps it
                        let start = dragStart ?? x
                        dragStart = start
                        x = rubberbanded(start + value.translation.width, in: -width...0, dimension: width)
                        armed = isArmed(-x, threshold: 0.4 * width, wasArmed: armed)
                    }
                    .onEnded { value in
                        defer { horizontal = nil; dragStart = nil; armed = false }
                        guard horizontal == true else { return }
                        let velocity = value.velocity.width
                        // Destructive: the finger itself crossed the threshold (armed); a flick back still cancels.
                        if armed, shouldCommit(translation: -x, velocity: -velocity, travel: width) {
                            delete(velocity: velocity)
                        } else {
                            let target = snapTarget(from: x, velocity: velocity, points: [-revealWidth, 0])
                            withAnimation(release(settle, velocity: velocity, from: x, to: target)) { x = target }
                        }
                    }
            )
            .onChange(of: isDragging) { _, dragging in
                if !dragging, dragStart != nil {             // cancelled
                    dragStart = nil
                    horizontal = nil
                    armed = false
                    withAnimation(.spring(settle)) { x = 0 }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, new in new }
            .sensoryFeedback(.impact(weight: .medium), trigger: deletions)
            .accessibilityAction(named: "Delete") { delete(velocity: 0) }
    }

    private func delete(velocity: CGFloat) {
        deletions += 1
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { onDelete() }
            return
        }
        // Slide out at the finger's speed, then let the list close the gap.
        withAnimation(release(Spring(duration: 0.25, bounce: 0), velocity: velocity, from: x, to: -width)) {
            x = -width
        } completion: {
            withAnimation(.spring(duration: 0.3, bounce: 0)) { onDelete() }
        }
    }
}

private extension SwipeToDeleteRow {
    var settle: Spring { Spring(duration: 0.3, bounce: 0) }

    func release(_ spring: Spring, velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }

    func project(_ velocity: CGFloat) -> CGFloat {
        (velocity / 1000) * 0.998 / (1 - 0.998)
    }

    func snapTarget(from position: CGFloat, velocity: CGFloat, points: [CGFloat]) -> CGFloat {
        let projected = position + project(velocity)
        return points.min { abs($0 - projected) < abs($1 - projected) } ?? position
    }

    func shouldCommit(translation: CGFloat, velocity: CGFloat, travel: CGFloat) -> Bool {
        translation + project(velocity) > 0.4 * travel
    }

    func rubberbanded(_ value: CGFloat, in range: ClosedRange<CGFloat>, dimension d: CGFloat) -> CGFloat {
        func band(_ x: CGFloat) -> CGFloat {
            let m = abs(x), c: CGFloat = 0.55
            return (m * d * c) / (d + c * m) * (x < 0 ? -1 : 1)
        }
        if value < range.lowerBound { return range.lowerBound + band(value - range.lowerBound) }
        if value > range.upperBound { return range.upperBound + band(value - range.upperBound) }
        return value
    }

    func isArmed(_ value: CGFloat, threshold: CGFloat, wasArmed: Bool) -> Bool {
        wasArmed ? value > threshold - 20 : value >= threshold
    }

    func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }

    func sizeReader(_ action: @escaping (CGSize) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear.onChange(of: proxy.size, initial: true) { _, size in action(size) }
        }
    }
}
```

- **`.simultaneousGesture` + axis lock** lets the `ScrollView` keep its pan. Without the lock, the row wobbles
  during a vertical scroll.
- **If the scroll view still jitters** during a horizontal swipe, gate the recognizer itself with
  `UIGestureRecognizerRepresentable` **(iOS 18)**; see `uikit-bridge.md` §D.
- **Don't reach for `.highPriorityGesture`** here; it takes scrolling away from the whole row.
- **Open/closed snaps use `settle`**: the closed position has the row's leading edge right behind it.
- **The delete commits only on release**, so the user can still drag back.
- **A reveal flick opens, never deletes.** 40 pt at 600 pt/s projects to 339 pt, past 40 % of a 390 pt row; the
  `armed` gate is what keeps it a reveal. Add that case to your device feel-check.

---

## 11. Softening a grab mid-settle

`@State` holds an animation's *target*, not the on-screen value. A drag that grabs a view mid-settle reads `y`
(where the view was heading), so a plain 1:1 write can jump the view to old target + finger delta. Writing in
`onChanged` through `withAnimation(.interactiveSpring())` hides that jump: each change retargets the running spring
from the on-screen value, so the view glides there in about 0.15 s instead of teleporting.

This is **not a catch.** The grab is still measured from the old target, so a card grabbed halfway through a
settle keeps travelling to where it was heading, offset by the finger's movement, rather than staying under the
finger. Use it where settles are short and the gap is a few points. When people really grab a surface mid-flight
(a large drawer, a long settle), use the UIKit catch in `uikit-bridge.md` §A.

```swift
import SwiftUI

struct CatchableCard: View {
    var stops: [CGFloat] = [0, -320]         // layout inputs: rest and raised

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var y: CGFloat = 0
    @State private var dragStart: CGFloat?

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.tint)
            .frame(width: 160, height: 160)
            .offset(y: y)
            // No transaction strip here: the interactive spring is the point.
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStart ?? y
                        dragStart = start
                        withAnimation(.interactiveSpring()) { y = start + value.translation.height }
                    }
                    .onEnded { value in
                        dragStart = nil
                        let target = snapTarget(from: y, velocity: value.velocity.height, points: stops)
                        // A plain spring here, on purpose: it replaces the running interactive spring and
                        // keeps that spring's velocity (Apple-documented retargeting), which already follows the finger.
                        let spring = reduceMotion ? Spring(duration: 0.3, bounce: 0) : Spring(duration: 0.3, bounce: 0.2)
                        withAnimation(.spring(spring)) { y = target }
                    }
            )
            .accessibilityAction(named: "Raise or lower") {
                let next = y == stops[0] ? stops[1] : stops[0]
                // Reduce Motion: the same motion shortened to 0.15 s, bounce 0.
                withAnimation(reduceMotion ? .spring(duration: 0.15, bounce: 0) : .spring(duration: 0.4, bounce: 0)) {
                    y = next
                }
            }
    }
}

private extension CatchableCard {
    func snapTarget(from position: CGFloat, velocity: CGFloat, points: [CGFloat]) -> CGFloat {
        let projected = position + (velocity / 1000) * 0.998 / (1 - 0.998)
        return points.min { abs($0 - projected) < abs($1 - projected) } ?? position
    }
}
```

- **The one release without an explicit velocity.** Here the velocity lives in the interactive spring that
  `onChanged` keeps retargeting, and a `spring` release takes it over. An `interpolatingSpring` with the gesture's
  velocity would *add* to that motion and push twice.
- **The trade:** the view also trails the finger slightly during ordinary drags (the interactive spring is 0.15 s).
  For most drags the plain 1:1 write is better.
- **For an exact catch**, UIKit's `UIViewPropertyAnimator.stopAnimation(true)` commits the on-screen value, so the
  next pan starts exactly where the eye sees the view. See `uikit-bridge.md` §A.

---

## 12. Transient drag with `@GestureState`

For a value that should simply spring home when the finger lifts *or* the gesture is cancelled, with no target to
choose:

```swift
import SwiftUI

struct PeekImage: View {
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.3, bounce: 0)))
    private var pull: CGSize = .zero

    var body: some View {
        Image(systemName: "photo")
            .font(.largeTitle)
            .frame(minWidth: 44, minHeight: 44)
            .offset(pull)
            .gesture(DragGesture(coordinateSpace: .global).updating($pull) { value, state, _ in state = value.translation })
    }
}
```

- `resetTransaction` animates the reset, on release and on cancel alike. No `onEnded` needed.
- **The return can't take the release velocity**: the reset animation is fixed before the gesture ends, and
  automatic tracking isn't something to count on. That's fine for a peek that just springs home. When the return
  should keep the throw, move the value to `@State` and use the skeleton above.
- `.global`, because the image itself moves with `pull`.
- Switch to `@State` as soon as the release has to choose between targets.

---

## 13. Device feel-check list

Code can't prove feel. Before calling a gesture done, run it on a physical device in a Release build, ideally a
120 Hz one and a 60 Hz one, plus the slowest device you support, at 1× and in slow motion:

- **Slow drag vs quick flick:** both commit or snap the way the projected rule predicts.
- **The release keeps the finger's speed:** a fast flick leaves fast, with no stall at the moment of lift. A stall
  means the velocity isn't reaching the spring; a jolt means it's in the wrong units.
- **Reversal at release** (drag far, flick back): snaps home, doesn't commit.
- **Re-grab mid-settle:** continues from where the view appears. A jump means you need the UIKit catch, or §11 to
  soften it.
- **A quick flick on a swipe-to-delete row** reveals it; only a long swipe deletes.
- **A drag that starts inside a `ScrollView`**, diagonally and vertically: scrolling still wins vertically.
- **Cancel mid-drag** (pull down Notification Center): the view settles home instead of staying stranded.
- **Reduce Motion on:** tracking stays 1:1, releases have no overshoot, button-driven presentations fade.
- **Haptics:** exactly one per moment, on the frame the visual catches, never while hovering on a threshold.
- **VoiceOver / Voice Control:** every gesture has its action or a visible control.
- **A completion-driven dismissal** on a screen whose parent rebuilds often: if a parent rebuild cuts off the
  closing animation, bind the animation to the value on the view itself.

Look at it again with fresh eyes the next day. When it still feels wrong: a "weird" spring is usually fixed by
more damping (less bounce). A gesture that stutters is a performance problem (see swift-motion-animate's
performance rules). To diagnose a feeling you can't name, record the screen and scrub it frame by frame.
