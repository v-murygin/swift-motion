# Web motion vocabulary → SwiftUI

Read this when the request arrives in web terms (CSS, Motion / Framer Motion, React Native, a spec written for
the web), or when porting an existing web animation. Translate the **intent**, then snap the values to the
values in `springs-and-timing.md`. Don't port web numbers blindly: several web conventions exist to work around
browser limits iOS doesn't have, and a web ease-out duration is not a spring duration.

## The two conversions that matter most

- **A web ease-out of duration T → a spring with `duration ≈ 1.5 × T`, bounce 0.** A critically damped spring is
  90 % done at 0.62 of its duration, so `.spring(duration: 0.3, bounce: 0)` looks like a 200 ms ease-out. Feel-check.
- **Web timing curves become springs** for anything that can be re-triggered mid-flight. On iOS almost
  everything can, springs are native and cheap, and only springs carry velocity through an interruption. Keep a
  curve only for opacity-only changes, constant processes, UIKit / Core Animation parity, or a fixed one-shot beat.

## Mapping table

| Web term / value | SwiftUI equivalent | iOS |
|---|---|---|
| `transition: transform 160ms ease-out` on `:active` | `ButtonStyle` + `configuration.isPressed`, springs 0.15 in / 0.3 out, bounce 0 (recipe 1) | 17 |
| `transform: scale(0.97)` | `.scaleEffect(0.97)` | 17 |
| `transform-origin: var(--transform-origin)` | `anchor:` on `.scaleEffect` / `.scale(scale:anchor:)`; native `Menu` / `.popover(attachmentAnchor:)` are origin-aware already | 17 |
| `translateY(100%)` (own size) | `.transition(.move(edge: .bottom))`; `.visualEffect { content, proxy in content.offset(y: proxy.size.height) }`. A hard-coded `offset(y: 300)` is a defect. | 17 |
| `opacity` fade | `.transition(.opacity)`, `.contentTransition(.opacity)` | 17 |
| `@starting-style` / a `useEffect` mount flag | conditional insertion (`if show { X.transition(...) }`) changed inside `withAnimation`, not an `onAppear` flip | 17 |
| `AnimatePresence` exit | a removal `.transition` (the view stays alive until it finishes) | 17 |
| `AnimatePresence mode="wait"` | two-phase state with `withAnimation(_:completionCriteria:_:completion:)` | 17 |
| `popLayout` | the default: siblings reflow while the removal plays | 17 |
| Motion `layout` / FLIP | a layout change inside `withAnimation`; `matchedGeometryEffect`; `geometryGroup()` | 17 |
| `layoutId` shared element | `matchedGeometryEffect(id:in:)`; `.navigationTransition(.zoom)` + `.matchedTransitionSource` | 17 / 18 |
| `cubic-bezier(a,b,c,d)` + `ms` | `.timingCurve(a, b, c, d, duration: s)`, in **seconds** | 17 |
| `{ type: "spring", duration, bounce }` | `.spring(duration:bounce:)`, the same model | 17 |
| `{ stiffness, damping, mass }` | `.spring(Spring(mass:stiffness:damping:))`, which replaces and carries velocity on a re-trigger like a web spring retargeting; `.interpolatingSpring(mass:stiffness:damping:initialVelocity:)` only when overlapping runs should add. Check ζ = damping / (2√(k·m)) | 17 |
| `velocity` (px/s) on a spring | relative `initialVelocity = v / (target − current)`, guarded and capped; build it with `swift-motion-gestures` | 17 |
| `@keyframes` | `keyframeAnimator` (it restarts, it doesn't retarget, so one-shot only) | 17 |
| a multi-step `animate()` / sequence | `phaseAnimator`; a `Task` + `withAnimation(completion:)` | 17 |
| `staggerChildren` / `stagger()` | a per-index `.delay(Double(min(i, 6)) * 0.04)` (see the numbers in `choreography.md`); there is no native stagger modifier | 17 |
| `transition: all` (always a defect) | its SwiftUI forms: the value-less `.animation(_:)`, an `.animation` high in the tree, a broad `withAnimation`. Fix with `.animation(_:value:)` on the smallest subtree. | — |
| `will-change` | nothing for render-only modifiers; `drawingGroup()` only after measuring | 17 |
| `filter: blur(2px)` crossfade mask | `.transition(.blurReplace)`, `.contentTransition(.interpolate)`, `.blur(radius: 2)` | 17 |
| `clip-path: inset()` reveal | `.mask { Rectangle().frame(width:) }` / `.clipShape` with an animatable `Shape` | 17 |
| scroll-driven / `IntersectionObserver` reveal | `.scrollTransition` (17), `onScrollVisibilityChange` (18), `.visualEffect` (17) | 17 / 18 |
| `useTransform(y, [0, h], [1, 0])` | derive it in `body` from the same value | 17 |
| `useSpring(mouseX)` | `onContinuousHover` (iPad pointer), decoration only | 17 |
| `@media (hover: hover) and (pointer: fine)` | `.hoverEffect(...)` (fires only with a pointer) | 17 |
| `prefers-reduced-motion` | `\.accessibilityReduceMotion` | 17 |
| `touch-action: pan-y` | axis lock + `.simultaneousGesture`; `GestureMask`; `UIGestureRecognizerRepresentable` (18) | 17 |
| pointer capture | native: `DragGesture` keeps tracking outside the view | 17 |
| `hitSlop` | `.contentShape(Rectangle())` + padding, or `.frame(minWidth: 44, minHeight: 44)` | 17 |
| `dragElastic` | a rubber-band function with c = 0.55 (`swift-motion-gestures`) | 17 |
| Vaul / a drawer library | `.sheet` + `.presentationDetents` | 17 |
| Sonner / a toast library | an overlay + `.transition(.move(edge:).combined(with: .opacity))` + springs 0.4 in / 0.3 out, bounce 0 (recipe 3) | 17 |
| expo-haptics / Vibration API | `.sensoryFeedback` (`reduce-motion-and-haptics.md`) | 17 |
| a `requestAnimationFrame` loop | `TimelineView(.animation)`, only when declarative won't do | 17 |
| Lighthouse / DevTools performance | Instruments SwiftUI + Animation Hitches templates, on a device | — |
| 200 % browser zoom | Dynamic Type AX5 | 17 |
| `dir="rtl"` | `.environment(\.layoutDirection, .rightToLeft)`; `.move(edge: .leading)` flips, `offset(x:)` does not | 17 |

## Web rules that don't apply natively

Don't port these; they solve browser problems:

- the CSS-vs-JS main-thread split, WAAPI, and library hardware-acceleration caveats;
- `@starting-style`;
- `-webkit-tap-highlight-color` and sticky `:hover`;
- `100vh` / `dvh`, `env(safe-area-inset-*)`: SwiftUI respects the safe area by default;
- the 16 px input auto-zoom and the 300 ms click delay;
- `overscroll-behavior`, `user-select`, `theme-color` and PWA metas;
- the tooltip skip-delay (there are no tooltips on iPhone);
- mouse-tracking springs on iPhone;
- the web "iOS drawer" curve `cubic-bezier(0.32, 0.72, 0, 1)`: use the real sheet;
- sourcing curves from easing catalogue sites: use the values in `springs-and-timing.md`.

## Porting checklist

1. Name the interaction's intent (press, enter, exit, move, morph) and find its row in the preset table of
   `springs-and-timing.md` (the preset table by interaction).
2. Before porting, ask whether a native component already does it (`.sheet`, `Menu`, `.popover`, `Toggle`,
   `NavigationStack`). If so, use it and drop the web animation.
3. Replace the curve or spring with the matching value from that table. Keep a custom value only as a deliberate one-off, and say why.
4. Replace mount logic with a conditional view + `.transition` inside `withAnimation`.
5. Replace pointer logic with a `ButtonStyle` (press) or hand the drag to `swift-motion-gestures`.
6. Add the Reduce Motion branch and decide the haptic; the web version never had either.
