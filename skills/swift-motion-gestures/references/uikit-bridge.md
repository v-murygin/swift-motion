# UIKit bridge

SwiftUI covers almost every gesture this skill builds. Reach for UIKit only for the four jobs below, and say
which one you're doing. Each block is self-contained: the helpers it needs are private to it, so it drops into one
file without adding module-wide names.

| Job | Why SwiftUI can't | Tool | iOS |
|---|---|---|---|
| **A.** Catch an in-flight animation exactly where it is on screen | `@State` holds the target value; SwiftUI exposes no presentation value | `UIViewPropertyAnimator` + `stopAnimation(true)` | 17 |
| **B.** A UIKit view's release spring seeded with the finger's velocity | UIKit has no automatic velocity tracking | `UIView.animate(springDuration:bounce:initialSpringVelocity:...)`, `UISpringTimingParameters(duration:bounce:initialVelocity:)` | 17 |
| **C.** The same motion values on SwiftUI and UIKit screens | The frameworks animate separately | `UIView.animate(_:changes:completion:)` with a SwiftUI `Animation` | **18** |
| **D.** Real delegate gating against a `ScrollView` | `.simultaneousGesture` + axis lock still lets the scroll view see the touch | `UIGestureRecognizerRepresentable` | **18** |

The spring model is the same in both frameworks: `duration` and `bounce` mean the same thing in
`UISpringTimingParameters(duration:bounce:)`, `UIView.animate(springDuration:bounce:...)` and
`Animation.spring(duration:bounce:)`. Use the same numbers as the SwiftUI side.

A SwiftUI `Animation` run through `UIView.animate(_:changes:completion:)` creates no `CAAnimation`, so it doesn't
mix with `UIViewPropertyAnimator` or UIView keyframe animations on the same property. When retargeted, it carries
the previous animation's velocity, as it does in SwiftUI. Pick property animators for job A and SwiftUI
animations for job C; don't combine them on one property.

## Contents

- [A. Catch mid-flight with UIViewPropertyAnimator](#a-catch-mid-flight-with-uiviewpropertyanimator)
- [B. UIKit springs with initial velocity](#b-uikit-springs-with-initial-velocity)
- [C. Sharing motion values with UIKit (iOS 18)](#c-sharing-motion-values-with-uikit-ios-18)
- [D. UIGestureRecognizerRepresentable for scroll-view gating (iOS 18)](#d-uigesturerecognizerrepresentable-for-scroll-view-gating-ios-18)

---

## A. Catch mid-flight with UIViewPropertyAnimator

A drawer that can be grabbed during its settle with no jump. `stopAnimation(true)` removes the running
animation and leaves the animated properties at their *current* values, so the model value becomes what the eye
sees and the next pan starts from there.

```swift
import SwiftUI
import UIKit

final class DrawerController: UIViewController {
    private let drawer = UIView()
    private var animator: UIViewPropertyAnimator?
    private var isPanning = false
    private var isOpen = false                        // the resting detent, re-applied on layout
    private var startY: CGFloat = 0
    private var openY: CGFloat { view.bounds.height * 0.3 }
    private var closedY: CGFloat { view.bounds.height - 120 }

    override func viewDidLoad() {
        super.viewDidLoad()
        drawer.backgroundColor = .secondarySystemBackground
        drawer.layer.cornerRadius = 16
        view.addSubview(drawer)
        drawer.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Rotation, keyboard or trait changes re-place the drawer at its resting detent,
        // but never under the finger or mid-settle.
        drawer.frame.size = view.bounds.size
        guard !isPanning, animator == nil else { return }
        drawer.frame.origin = CGPoint(x: 0, y: isOpen ? openY : closedY)
    }

    @objc private func pan(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            // Commits the on-screen value: the drawer stays under the finger instead of jumping to the old target.
            animator?.stopAnimation(true)
            animator = nil
            isPanning = true
            startY = drawer.frame.minY
        case .changed:
            let raw = startY + g.translation(in: view).y
            drawer.frame.origin.y = rubberbanded(raw, in: openY...closedY, dimension: view.bounds.height)
        case .ended, .cancelled:
            isPanning = false
            let current = drawer.frame.minY
            let velocity = g.state == .cancelled ? 0 : g.velocity(in: view).y
            let target = snapTarget(from: current, velocity: velocity, points: [openY, closedY])
            isOpen = target == openY
            let relative = relativeVelocity(velocity, from: current, to: target)   // never raw pt/s
            // Back from an overdrag past the stop it's heading to: no bounce, or it re-enters the overdrag.
            let overdragged = (current < openY && target == openY) || (current > closedY && target == closedY)
            let settle = UIAccessibility.isReduceMotionEnabled || overdragged
            let bounce: CGFloat = settle ? 0 : 0.2           // settle / fling
            let spring = UISpringTimingParameters(duration: 0.3, bounce: bounce,
                                                  initialVelocity: CGVector(dx: 0, dy: relative))
            let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: spring)
            animator.isUserInteractionEnabled = true
            animator.addAnimations { self.drawer.frame.origin.y = target }
            animator.addCompletion { [weak self] _ in self?.animator = nil }
            animator.startAnimation()
            self.animator = animator
        default:
            break
        }
    }

    // MARK: - Drag helpers (private to this controller)

    /// pt/s → a fraction of the remaining distance per second; guarded near the target, capped at 30.
    private func relativeVelocity(_ v: CGFloat, from current: CGFloat, to target: CGFloat) -> CGFloat {
        let distance = target - current
        guard abs(distance) >= 1 else { return 0 }
        return min(max(v / distance, -30), 30)
    }

    /// The stop nearest to where the throw would come to rest (UIScrollView-like 0.998 deceleration).
    private func snapTarget(from position: CGFloat, velocity: CGFloat, points: [CGFloat]) -> CGFloat {
        let projected = position + (velocity / 1000) * 0.998 / (1 - 0.998)
        return points.min { abs($0 - projected) < abs($1 - projected) } ?? position
    }

    /// 1:1 inside `range`, UIScrollView-style resistance outside it (c = 0.55).
    private func rubberbanded(_ value: CGFloat, in range: ClosedRange<CGFloat>, dimension d: CGFloat) -> CGFloat {
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

- **Same values as SwiftUI.** The release is duration 0.3 with bounce 0.2 (a free detent reached with
  momentum), and bounce 0 under Reduce Motion or when returning from a rubber-banded overdrag.
  Snapping uses projection; edges rubber-band.
- **Layout keeps the resting detent.** `viewDidLayoutSubviews` re-applies `isOpen`'s position only while no pan or
  settle is running, so a rotation never snaps an open drawer closed or yanks it from under the finger.
- **`initialVelocity` is a `CGVector` of relative velocities**: pt/s divided by the remaining distance on that
  axis. `relativeVelocity` guards near zero and caps at 30.
- **`stopAnimation(true)` skips completion handlers**, so the `animator = nil` cleanup runs only for animations
  that really finished.
- **Pass the same 0.3 to the animator** as to the spring parameters, so the two never disagree.
- **Host it in SwiftUI** with `UIViewControllerRepresentable` when the rest of the screen is SwiftUI.

---

## B. UIKit springs with initial velocity

For a one-off UIKit release with no catching, the `UIView` spring API takes the same duration and bounce
vocabulary as the SwiftUI springs:

```swift
import SwiftUI
import UIKit

@MainActor
func settleCard(_ card: UIView, to target: CGFloat, velocity: CGFloat) {
    // pt/s → a fraction of the remaining distance per second; guarded near the target, capped at 30.
    let distance = target - card.center.y
    let relative = abs(distance) < 1 ? 0 : min(max(velocity / distance, -30), 30)
    let reduceMotion = UIAccessibility.isReduceMotionEnabled
    UIView.animate(springDuration: 0.3, bounce: reduceMotion ? 0 : 0.2, initialSpringVelocity: relative,
                   delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
        card.center.y = target
    }
}
```

- `.allowUserInteraction` keeps the view grabbable during the settle, so the motion stays interruptible.
- `.beginFromCurrentState` starts from the on-screen value if another animation is in flight.
- Bounce 0.2 only for a free target reached with momentum. A commit to a hard edge or a snap-back uses 0.

---

## C. Sharing motion values with UIKit (iOS 18)

`UIView.animate(_:changes:completion:)` takes a SwiftUI `Animation`, so a UIKit banner can use the exact springs a
SwiftUI toast uses (0.4 s in, 0.3 s out, bounce 0), and both feel identical. If the project has shared motion
tokens, pass those instead:

```swift
import SwiftUI
import UIKit

@available(iOS 18, *)
@MainActor
func showBanner(_ banner: UIView, shown: Bool) {
    let reduceMotion = UIAccessibility.isReduceMotionEnabled
    let hiddenTransform = reduceMotion ? .identity : CGAffineTransform(translationX: 0, y: -banner.bounds.height)
    let animation: Animation = reduceMotion ? .easeOut(duration: 0.2)
        : shown ? .spring(duration: 0.4, bounce: 0) : .spring(duration: 0.3, bounce: 0)
    if shown { banner.isHidden = false }
    UIView.animate(animation) {
        banner.transform = shown ? .identity : hiddenTransform
        banner.alpha = shown ? 1 : 0
    } completion: {
        if !shown { banner.isHidden = true }
    }
}
```

- This API has **no initial-velocity input.** For a release that should inherit a finger's velocity, use job B
  or job A.
- Retargeting mid-flight carries velocity, as `withAnimation` does in SwiftUI.
- Reduce Motion still needs your branch: travel becomes an alpha change.

---

## D. UIGestureRecognizerRepresentable for scroll-view gating (iOS 18)

**When:** a horizontal swipe inside a vertical `ScrollView`, built with `.simultaneousGesture` + axis lock, still
makes the scroll view twitch, or the swipe starts during a vertical scroll. With a real `UIPanGestureRecognizer`,
the delegate can refuse to *begin* unless the pan is horizontal, so the scroll view never sees a competitor.

```swift
import SwiftUI
import UIKit

@available(iOS 18, *)
struct HorizontalPan: UIGestureRecognizerRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // .global, not the local space: the row this is attached to moves with the drag.
        let translation = context.converter.translation(in: .global)?.x ?? 0
        switch recognizer.state {
        case .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation, context.converter.velocity(in: .global)?.x ?? 0)
        case .cancelled, .failed:
            onEnded(0, 0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        // Begin only for a horizontal pan, so vertical scrolling never sees a competitor.
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }
    }
}

@available(iOS 18, *)
struct BridgedSwipeRow: View {
    let onDelete: () -> Void
    @State private var x: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var width: CGFloat = 1
    private let revealWidth: CGFloat = 88

    var body: some View {
        Text("Row")
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(.background)
            .background(GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size.width, initial: true) { _, w in width = max(w, 1) }
            })
            .offset(x: x)
            .transaction { if dragStart != nil { $0.animation = nil } }
            .background {                                    // stays in place while the row slides
                HStack {
                    Spacer()
                    Button("Delete", role: .destructive, action: onDelete)
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                }
                .foregroundStyle(.white)
                .background(.red)
                .opacity(x < 0 ? 1 : 0)
                .accessibilityHidden(true)                   // reachable through the row's action instead
            }
            .gesture(HorizontalPan { translation in
                let start = dragStart ?? x
                dragStart = start
                x = rubberbanded(start + translation, in: -revealWidth...0, dimension: width)
            } onEnded: { _, velocity in
                dragStart = nil
                let target = snapTarget(from: x, velocity: velocity, points: [-revealWidth, 0])
                withAnimation(release(velocity: velocity, from: x, to: target)) { x = target }
            })
            .accessibilityAction(named: "Delete") { onDelete() }
    }
}

@available(iOS 18, *)
private extension BridgedSwipeRow {
    /// Critically damped 0.3 s spring that starts at the finger's speed (relative velocity, capped at 30).
    func release(velocity: CGFloat, from current: CGFloat, to target: CGFloat) -> Animation {
        let spring = Spring(duration: 0.3, bounce: 0)
        let distance = target - current
        guard abs(distance) >= 1 else { return .spring(spring) }
        return .interpolatingSpring(spring, initialVelocity: Double(min(max(velocity / distance, -30), 30)))
    }

    func snapTarget(from position: CGFloat, velocity: CGFloat, points: [CGFloat]) -> CGFloat {
        let projected = position + (velocity / 1000) * 0.998 / (1 - 0.998)
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

- **`gestureRecognizerShouldBegin`** reads the pan's velocity at the moment it would begin. That is already past
  UIKit's own slop, so the axis decision uses real movement.
- **Coordinates.** Read `translation(in: .global)` and `velocity(in: .global)`, or a named space on an ancestor
  that doesn't move. `localTranslation` and `localVelocity` are in the attached view's space, which here moves with
  `.offset(x:)` and would feed back on itself and jitter, as `DragGesture` in local space does.
- **The row only reveals.** This bridge demonstrates the gating; full-swipe delete and its haptics are in
  `recipes.md` §10 and port across unchanged.
- **The release passes the recognizer's velocity explicitly**, as every SwiftUI recipe does. Nothing here depends
  on SwiftUI tracking velocity for state written from a representable recognizer, which Apple doesn't document.
- **Accessibility.** A UIKit recognizer doesn't change the rule: keep the row's `.accessibilityAction(named:)`.
- **Attach it** with `.gesture(_:)`, which accepts a `UIGestureRecognizerRepresentable` directly.
