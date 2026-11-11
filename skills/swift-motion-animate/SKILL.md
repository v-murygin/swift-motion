---
name: swift-motion-animate
description: "Build an animation in a Swift app (SwiftUI, iOS 17+, iOS 18/26/27 additions marked) with a decision order that ends in working code: whether to animate at all, then purpose, API, spring values, interruption, exit, Reduce Motion and haptics. Use whenever someone wants to add, build, polish or port motion, even if they only say 'animate this', 'add some motion', 'make it feel alive' or 'add a transition'. Covers withAnimation vs .animation(_:value:), springs and bounce, transitions, press-feedback ButtonStyles, toasts, menus and popovers, list insert/remove, numericText counters, symbolEffect, error shake, success checks, matchedGeometryEffect and zoom heroes, PhaseAnimator/KeyframeAnimator, staggered choreography, Liquid Glass morphs, sensoryFeedback, keeping new motion hitch-free, and porting CSS/Framer Motion. For drag, swipe, fling or sheet-drag motion use swift-motion-gestures; to critique, audit or trim existing motion use swift-motion-review; to stress-test layout use swift-motion-break-ui."
---

# swift-motion-animate

Turn a request for motion into an implementation that would pass a strict review the first time. The answer
is code plus a few lines of reasoning, never a menu of options. "This shouldn't animate" is a valid answer,
and zero lines of code is sometimes the right result.

**Hand off instead when:**

- the motion follows a finger (drag, swipe, fling, rubber-banding, custom sheet drag, velocity hand-off,
  interruptible gesture) → `swift-motion-gestures`
- the user wants existing motion critiqued, audited, trimmed or removed, or wants to find places that could
  animate → `swift-motion-review`
- the user wants to see how a view breaks with long text, AX5, RTL, empty or huge data → `swift-motion-break-ui`

A tap-driven animation that ends in a gesture (a toast you can also swipe away) is built here, with the drag
part built per `swift-motion-gestures`.

## The posture

You are building the animation yourself. Three failure modes, the first the worst:

1. **Animating something that shouldn't animate.** Each animation is defensible alone; together they make an
   app feel slow. The gate below exists to produce zero lines of code sometimes. That's a success, not a dodge.
2. **Animating the right thing with the wrong ingredients**: `.easeIn` on an entrance, a scale from 0,
   keyframes on a toast, bounce on a tap-opened panel, a duration that makes a menu feel sluggish.
3. **Changing more than was asked**: new files, app-wide extensions, a lifetime or layout nobody mentioned.

Principles behind the order (each one is why a step exists):

- **Frequency decides.** What people see often should cost them nothing. A 300 ms flourish seen 200 times a
  day is a minute of waiting.
- **Use what the platform already moves.** Push, sheets, menus, alerts, context menus, Liquid Glass controls,
  SF Symbol effects and numeric text carry Apple's tuned timing, Reduce Motion handling, haptics and
  accessibility. Custom motion fills gaps; it never duplicates or replaces system motion.
- **Springs by default.** Only springs keep position and velocity continuous, from rest and from a gesture,
  and retarget mid-flight. On iOS anything can be re-triggered mid-flight, and the system default animation is
  itself a critically damped spring.
- **Bounce means momentum.** Start at zero bounce. Overshoot only when a gesture carried momentum, or in a
  deliberately playful rare moment.
- **Response is immediate.** Feedback starts on touch-down, never on touch-up or after a delay.
- **Everything is interruptible.** Never lock input during an animation. Re-triggering retargets from where
  the eye is; it never restarts from zero.
- **Exit the way you entered**, a little faster. Motion is anchored to its source.
- **Make the call.** Decide, state the reasoning in one line, write the code.
- **Feel is verified on hardware**, not in the Simulator or a Debug build.

**Whose rule is it?** API behaviour is Apple's SDK documentation. Reduce Motion, haptic pairing, system
components first, zero bounce for taps and no motion on frequent interactions are HIG and WWDC guidance. The
tiers, duration ceilings, scale amounts, stagger steps and toast lifetime are this skill's house guidelines,
tuned to work together but not Apple rules; present them to the user as guidelines, with their reason.

## Scope: the smallest change that delivers the feel

When the user hands you code, make *that* feel right; don't reorganise the app around it. Every line outside
the request is one a reviewer has to check, revert or argue about.

- **Stay in the files you were given.** No new source files, no app-wide token types, and no extensions on
  `Animation`, `Color`, `View` or `ButtonStyle` with generic names (`.fade`, `.control`, `.settle`). In a real
  codebase those names collide with existing extensions and packages and quietly become vocabulary the team
  never agreed on. Write values inline; a helper the change genuinely needs (a press `ButtonStyle`, a constant
  used three times) goes in the edited file as `private`.
- **Use what the project already has.** Existing motion constants, press styles or toast presenters win over
  this skill's, even when their values differ a little; mention the difference rather than adding a parallel set.
- **Change the motion and what the motion needs, nothing else.** Transitions, springs, animation scope, a
  cancellable timer in place of `asyncAfter`, the Reduce Motion branch and the haptic are in scope. Lifetimes and
  delays the code already has, copy, colours, layout and sizes, hit targets and accessibility labels are not: if
  one looks wrong (a 2 s toast is short to read), say so in one line as a suggestion and leave the code alone.
- **Prefer a modifier to a new type.** `.transition`, `.symbolEffect`, `.contentTransition` and `.sensoryFeedback`
  usually do the job in a line each. Add a type only when it's the right tool, such as a `ButtonStyle` for
  touch-down feedback.
- Building something new, or asked for app-wide consistency? Then a shared component or the optional token
  block in `references/springs-and-timing.md` is the deliverable.

## The decision order

Work through the steps in order. Steps 0–2 gate everything after them. Steps 8 and 9 ship in the same change
as the animation, never as a follow-up.

### 0. Native check

Does a system component or semantic API already move this? `NavigationStack`, `.sheet` +
`.presentationDetents`, `Menu`, `.popover`, `.contextMenu`, `.swipeActions`, `Toggle`, `Picker`, `Stepper`,
`DisclosureGroup`, `.refreshable`, glass button styles (26), `.symbolEffect`, `.contentTransition`. If yes, use
it and stop. Never re-implement it, and never strip its motion: removing the push, the sheet spring or
`TabView` behaviour is a defect, not a cleanup. When the user already has a custom version of something the
system does better, recommend the system component first, then give the minimal corrected custom version for a
team that has to keep theirs.

### 1. Should it animate at all?

Apple's HIG says not to add motion for its own sake and to keep it off frequent interactions; the tiers and
budgets below are this skill's way of applying that.

| Tier | iOS examples | Decision |
|---|---|---|
| **100+/day** | tab switches, keyboard show/hide, scrolling, per-keystroke updates (search results re-animating on every character), hardware-keyboard shortcuts on iPad, row selection in a core list, settings toggles, feed filter chips | **No custom animation.** Keep the system motion as it is. Stop. |
| **Tens/day** | press feedback, row taps, segmented control, expanding a row, custom tab indicator, chip toggles | Near-imperceptible or nothing: fixed curves ≤ 0.15 s; springs `duration ≤ 0.25`, bounce 0, for the response to a touch; opacity / scale ≤ 3 % |
| **Occasional** | sheets, popovers, toasts, banners, confirmations, detail push, settings panels, onboarding steps | A standard value from step 5: component springs ≤ 0.35, screen / sheet springs ≤ 0.5 |
| **Rare / first-time** | onboarding, first run, empty-state art, purchase success, streak or achievement, backup complete | The delight budget: bounce up to 0.3, generous stagger, a longer beat (up to ~1 s), `.success` haptic. Still interruptible and skippable. |

- **What the tens/day ceiling covers.** It limits the response to a touch: the press-in (0.15) and a small
  state change (0.25). The release of a press, a stepper's digit roll and an indicator pill sliding under a
  segment may run to 0.3, because by then the user already has the answer: the press registered, the value or
  selection changed and the haptic fired. The spring only animates the way there.
- **Input-rate driven is disqualified.** Anything firing per keystroke, per scroll tick or on every launch
  doesn't animate, and neither do hardware-keyboard shortcuts used many times a session (⌘-commands): the user
  is moving faster than the motion. A single Return-to-submit is an ordinary event and goes through the tiers.
- **Tab switches never slide.** Tabs are peers; a slide implies depth that isn't there. Don't wrap tab
  selection in `withAnimation`, and don't use `.tabViewStyle(.page)` for app tabs.
- **Functional data doesn't move for style.** Charts don't redraw from zero on appear; balances don't count up
  on load. Animate a value only when it changes because of a user action.
- **The 50th-use test.** Imagine the 50th use today. If you'd skip the animation, cut it.

If the request fails this step, say so plainly, offer the non-motion alternative (an instant change, a static
affordance), and write no motion code.

### 2. Purpose

Name it in one word: **feedback**, **spatial consistency**, **state indication**, **preventing a jarring
change**, **explanation**, or **delight** (rare tier only). Can't name it? Don't build it. "It looks cool" on
a frequent element means stop.

### 3. Tool: the cheapest rung that fits

1. Native component with built-in motion.
2. Semantic effects: `.contentTransition(...)`, `.symbolEffect(...)`, `.sensoryFeedback`, glass styles (26).
3. Scoped implicit animation: `.animation(_:value:)`, or `.animation(_:body:)` to scope to specific modifiers.
4. Explicit: `withAnimation(_:_:)` + `.transition(...)`; `withAnimation(_:completionCriteria:_:completion:)`.
5. Spatial continuity: `matchedGeometryEffect`; `.navigationTransition(.zoom(sourceID:in:))` +
   `.matchedTransitionSource(id:in:)` (18); `.scrollTransition` / `.visualEffect`.
6. Predetermined multi-step: `phaseAnimator` / `keyframeAnimator`. One-shot, non-rapid only.
7. Gesture-driven → `swift-motion-gestures`.
8. Last resort: `TimelineView` + `Canvas`, `CustomAnimation`, shaders (`.layerEffect` etc.);
   `UIView.animate(_: SwiftUI.Animation)` bridge (18); Core Animation. Lottie / Rive only for authored
   illustration, never for UI state.

### 4. Properties

Animate `.offset`, `.scaleEffect`, `.rotationEffect`, `.opacity` and `.visualEffect` first: they don't re-run
layout. Animating `.frame`, `.padding`, stack spacing, `Spacer` length, font size or `.position` re-lays out
the subtree every frame and needs a stated reason. The sanctioned exceptions are a childless pill or progress
fill (scaling would smear its corners) and an accordion with a small subtree.

- **Text height:** don't "fix" it with `scaleEffect`, which distorts the glyphs. Use a fixed container,
  translate the content inside it and add `.clipped()`.
- **Never enter from nothing.** Start at 0.9–0.97 scale plus opacity; `.transition(.scale)` scales from 0.
- **Anchor to the trigger.** A popover or menu grows from its button: `.scale(scale: 0.95, anchor: .topLeading)`.
  Centred modals are exempt.
- **Move by the view's own size** with `.move(edge:)`, never a hard-coded `offset(y: 300)`.

### 5. Spring values

Pick the value from this table and write it inline, `.spring(duration: 0.3, bounce: 0)`, or as a `private`
constant when one value repeats in the file. If the project already has motion constants, use those. Never
invent a near-miss like `.spring(response: 0.34, dampingFraction: 0.82)`; a bare `withAnimation {}` means nobody
chose. The values are house guidelines tuned to work together, so keep to them and tune on a device.

| For | Value |
|---|---|
| button press in / release | spring 0.15 / 0.3, bounce 0 |
| toggle, chip, small state | spring 0.25, bounce 0 |
| popover, menu, list change, numbers: in / out | spring 0.3 / 0.2, bounce 0 |
| custom sheet, toast: in / out | spring 0.4 / 0.3, bounce 0 |
| centred modal card | spring 0.35, bounce 0 |
| gesture releases (`swift-motion-gestures`) | settle 0.3 b0, fling 0.3 b0.2, reposition 0.4 b0 |
| Reduce Motion substitute, opacity | `.easeOut(duration: 0.2)`; crossfade `.easeInOut(duration: 0.2)` |
| rare tier only | `.bouncy` (0.5, bounce 0.3) |

Bounce 0 is the default; 0.2 only for a gesture release with momentum; 0.3 only in the rare tier; never above
0.4. `.default` is `spring(response: 0.55, dampingFraction: 1.0)` and `.snappy` carries bounce 0.15: neither
replaces a chosen value. Never `.easeIn` on any appearance, press or response: it starts slowly, delaying the
moment the user is watching. `references/springs-and-timing.md` has the per-interaction preset table, API facts,
fixed curves, duration ceilings, conversions and the optional shared token block.

### 6. Interruption

Ask what happens on a re-tap, a reversal or a catch mid-flight.

- A new `spring` on the same property **replaces** the running one and **carries its velocity**, so springs
  retarget smoothly. `interpolatingSpring`s **add**; timing curves combine additively with no velocity.
- No `phaseAnimator`, `keyframeAnimator` or `repeatForever` on anything that can be triggered twice a second
  or touched (toggles, toasts, draggables): keyframes restart instead of retargeting.
- No `.allowsHitTesting(false)` or `.disabled` to lock input during motion without a stated reason.
- Chain steps with the completion form of `withAnimation` or a cancellable `.task(id:)`, never
  `DispatchQueue.main.asyncAfter` sized to a duration. Completions fire at the perceptual end; never wait for
  a spring to "really" settle.

### 7. Exit

- Exit along the entry path, faster: popover 0.3 → 0.2, sheet / toast 0.4 → 0.3. A symmetric path tells
  people where the thing went and makes swipe-to-dismiss obvious; a faster exit respects that they've decided.
- Slow where the user decides, fast where the system responds (a hold-to-confirm fills slowly, cancels fast).
- Groups exit simultaneously, with no reverse stagger. Use `.asymmetric(insertion:removal:)` only on purpose.

### 8. Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

The system doesn't tone down custom motion, so each animation gets a branch. Fewer and gentler, not zero:
replace entrance travel, scale-in, depth, zoom and loops with opacity (a 0.2 s ease-out); set any bounce to 0;
keep in-place feedback (a press dip, a thumb inside its track), colour and opacity changes, the state change
itself, gesture tracking (still 1:1) and haptics. Swapping only the curve while the view still travels doesn't
count. Read `references/reduce-motion-and-haptics.md` for the replacement table.

### 9. Haptic pairing

One `.sensoryFeedback` per causal commit, snap or outcome, on the same trigger as the visual, so it lands on
the same frame. Never from a completion handler, never per frame, never on a system control that already plays
one, never as the only feedback. "None" is a valid answer; say why in one line.

```swift
.sensoryFeedback(.success, trigger: savedCount)                                   // outcome
.sensoryFeedback(.impact(weight: .light), trigger: isArmed) { _, new in new }     // one direction only
```

`.levelChange` and `.start` / `.stop` are silent on iPhone, and Apple lists `.increase` / `.decrease` for watchOS
and visionOS only, so don't use them for iPhone UI. Read `references/reduce-motion-and-haptics.md` for the full
event → feedback map, including iOS 26 `.press` / `.release` / `.selection(_:)`.

## Scoping: `withAnimation` vs `.animation(_:value:)`

Most "it animates the wrong thing" bugs are scoping bugs.

- **`withAnimation(.spring(duration: 0.3, bounce: 0)) { state = x }`** at the mutation site animates every view that depends on what
  changed in that transaction. Use it for event-caused changes (a tap, a load finishing) and for insertions /
  removals, because the transition runs in that transaction. Never call it inside `body`.
- **`.animation(.spring(duration: 0.25, bounce: 0), value: x)`** animates changes in its subtree only when `x` changes. Put it on the
  smallest subtree that should move; high in the tree it catches unrelated changes. A nearer
  `.animation(_:value:)` overrides an outer `withAnimation` for its subtree.
- **`.animation(.spring(duration: 0.25, bounce: 0)) { $0.scaleEffect(s) }`** (17) animates only the modifiers inside the closure; use it in
  containers.
- **Opt out** with `.transaction(value:_:)` (17) or `withTransaction(\.disablesAnimations, true)`, for example
  text that must update instantly inside an animated container.
- Never the value-less `.animation(_:)` (deprecated in iOS 15): it animates every change, forever.
- An `.animation` attached inside an `if` is destroyed with the view, so its removal never animates. Put it on
  a surviving parent, or use `withAnimation`.

## Transitions

- A transition runs only when the insertion or removal happens inside an animated transaction.
- `.scale(scale: 0.95).combined(with: .opacity)` instead of `.scale`; `.move(edge:).combined(with: .opacity)` for
  surfaces; `.blurReplace` or `.contentTransition(.interpolate)` to swap content in place.
- Enter and exit are one path: the same transition both ways, with the faster exit spring chosen at the
  mutation site. `.asymmetric` is for deliberate differences such as a staggered entrance with a plain exit.
- Spell ternaries as `reduceMotion ? AnyTransition.opacity : .move(edge: .bottom)` so both branches are one type.
- Changing `.id()` destroys the view: you get a crossfade, not a morph. A "morph" between two exclusive
  `if/else` views is a cut; animate one persistent view instead, unless the two are joined with
  `matchedGeometryEffect` (one source per id, insertion and removal in one transaction).

## Building blocks

**Press feedback** is a `ButtonStyle` reading `configuration.isPressed` (true on touch-down): `scaleEffect(0.97)`
(0.96–0.98 for large cards, never below 0.95), a 0.15 s spring in and 0.3 s out, `opacity(0.85)` only for
glyph-only buttons. Declare it `private` in the edited file unless the project already has one. Use a real
`Button`, never `onTapGesture` or `DragGesture(minimumDistance: 0)`. Skip it on `.buttonStyle(.glass)` /
`.glassProminent` (26), which already respond. Recipe 1.

**Hero: `matchedGeometryEffect` or zoom?** Card → detail as a navigation destination: `.matchedTransitionSource`
on the card and `.navigationTransition(.zoom(sourceID:in:))` on the **root** of the destination (18; iOS 17 gets
the plain push). It's interactive, keeps the back swipe and needs no state. Same screen, A becomes B in place
(an indicator pill, a card expanding over its grid): `matchedGeometryEffect`, one source per id, insertion and
removal in one transaction. Under Reduce Motion drop the match (crossfade) or the zoom (plain push). Recipe 9.

**`phaseAnimator` / `keyframeAnimator`** run their content closure every frame, so keep it small. Use them for
one-shot, triggered motion (an error, a success), driven by a counter so a second trigger plays again. A
triggered animator replays its phases or keyframes on every change (start each keyframe track with a
`MoveKeyframe` to replay from a fixed value); resetting `@State` and animating it again inside one handler
can't do that, because SwiftUI only sees the final value. Never the triggerless form on idle UI: it loops forever. The error shake:
−8, 8, −5 pt as `CubicKeyframe`s of 0.08 s each, then a 0.16 s `SpringKeyframe` back to 0 with a matching
`spring:`, plus `.sensoryFeedback(.error, trigger: attempts)` (recipe 7). A `SpringKeyframe` with the default
0.5 s spring barely moves in a 0.08 s segment. Triggered phases: recipe 6B; a drawn check: recipe 8B.

**Numbers:** `Text(n, format: .number).monospacedDigit().contentTransition(.numericText(value: Double(n)))`,
changed inside `withAnimation(.spring(duration: 0.3, bounce: 0))`. Inert without an animation in the
transaction; the spring must be bounce 0, or the digits roll back. Recipe 6.

**Symbols:** `.contentTransition(.symbolEffect(.replace))` (17), `.replace.magic(fallback:)` (18);
`.symbolEffect(.bounce, value:)` for one-shot feedback, `.wiggle` (18) for error or attention. Indefinite
effects (`.pulse`, `.breathe` (18), `.variableColor`) only while something real is ongoing, removed with
`.symbolEffectsRemoved(reduceMotion)`.

**Liquid Glass morph (26):** `GlassEffectContainer(spacing:)` + `.glassEffectID(id, in: ns)`, state change in
`withAnimation(.smooth)`. The glass brings its own elasticity and adapts to Reduce Motion by itself, so never
add bounce or a press scale on top. Recipe 11.

**Loading:** no spinner for an operation under 300 ms; show one only after a 150–300 ms delay and keep it up at
least 300–500 ms once shown. Recipe 8A. A skeleton must match the real layout; `.redacted(reason: .placeholder)`
on the real view gives you that for free.

## Choreography (several elements, one event)

- One entrance per container. If the panel slides in, its content is already there.
- Stagger step 40 ms (allowed 30–80), index capped at 6 (`Double(min(i, 6)) * 0.04`, at most 0.24 s), total
  span ≤ 0.3 s. Rare-tier entrances may use 100–150 ms steps.
- Vary the treatment by role: Lead travels 12 pt, Support 6–8 pt, Decoration fades in place, Static doesn't move.
- Never stagger high-frequency surfaces (menus, tab content, `List` / `LazyVStack` rows). Never block taps
  while a sequence plays. Exits are simultaneous. Under Reduce Motion the group fades in together, and a group
  gets at most one haptic.

Read `references/choreography.md` before building any group: roles, relationships, stagger patterns,
direction, cancellable sequences, the timeline format.

## Performance

- Render-only modifiers by default; layout animation only with a reason (step 4).
- Keep per-frame values in the leaf view. A per-frame value in an `@Observable` property or environment value
  read by many views gets slower as content grows.
- Things that run `body`-like work every frame: custom `Animatable` / `@Animatable` (Xcode 26 macro) bodies,
  `TimelineView(.animation)`, `keyframeAnimator` content, geometry or scroll readers writing `@State`. Keep them
  in leaf views; convert `onScrollGeometryChange` (18) output to a coarse `Bool` first.
- Animated blur stays under 20 pt (prefer `.blurReplace`). Never animate `.shadow` or `.blur` radius on large
  views or materials: crossfade a static pre-shadowed layer; `.compositingGroup()` before a container shadow.
- Custom `CADisplayLink` animation needs `CADisableMinimumFrameDurationOnPhone` = YES to run above 60 Hz on
  iPhone. `drawingGroup()` only after measuring (it renders `TextField` and `Map` as placeholders);
  `geometryGroup()` when children fly in from the wrong place.
- Keep the main thread free during motion (decode, fetch and sort before or after). Lazy containers: stable ids,
  no `onAppear` entrances on rows, no `AnyView` in hot rows. Limit glass effects on screen.
- Budget 8.3 ms per frame at 120 Hz (16.7 ms at 60 Hz). Verify with the Instruments SwiftUI and Animation
  Hitches templates on a mid-range device, Release build, also in Low Power Mode. Say which claims are from code
  and which need a device recording.

## Lessons from acclaimed apps

- **Music, Now Playing:** opened by a tap with no bounce, dismissed by a swipe with a little squish. The
  trigger picks the damping, not the component.
- **Calculator:** buttons highlight instantly on touch-down and animate only the release. Respond instantly,
  animate the way back.
- **Flashlight button:** a light tap bounces as a hint that a firmer press is needed. Bounce can carry information.
- **App launch:** several springs with staggered starts and ends; properties finishing at different times is the
  point. **Zoom transition (18):** grabbable at any moment; an interrupted push completes and becomes a pop.
- **iOS 26 menus and popovers** morph out of the control that presented them. A sheet morphs from its source
  only when you wire it: `.matchedTransitionSource(id:in:)` on the source (toolbar items included) and
  `.navigationTransition(.zoom(sourceID:in:))` on the sheet's content. Don't fight either with a custom
  `presentationBackground` or your own transition.
- **Keyboard:** never imitate it with the notification's 0.25 s and a timing curve. Follow its real position
  with the safe-area avoidance SwiftUI gives you, `.safeAreaInset(edge: .bottom)`, or UIKit's `keyboardLayoutGuide`.
- **Live Activities and widgets:** animations capped at 2 s, none in Always-On, numbers via `.numericText`.
- **Family:** simplicity, then fluidity, then delight. **(Not Boring) Habits** gives its most frequent action
  the most feel only because the action *is* the product. **Flighty** stays quiet until something goes wrong.
  **Duolingo** lands haptic, sound and visual on one beat. Delight is the sum of craft, not confetti.

Don't invent values for system motion nobody has published (system sheet spring, Dynamic Island morph,
context-menu lift scale). Use the system component instead.

## Never ship

| Never | Instead | Because |
|---|---|---|
| value-less `.animation(_:)`, or `.animation` high in the tree | `.animation(_:value:)` on the smallest subtree | it animates unrelated changes |
| `.transition(.scale)` / `.scaleEffect(show ? 1 : 0)` | `.scale(scale: 0.95).combined(with: .opacity)` | nothing real appears from nothing |
| `.easeIn` on UI | a spring from step 5 (or strong ease-out `.timingCurve(0.23, 1, 0.32, 1, duration:)` when a curve is required) | it delays the moment the user watches |
| bounce on a tap-opened panel (`withAnimation(.bouncy)`) | `.spring(duration: 0.3–0.4, bounce: 0)` | a tap carries no momentum |
| a bare `withAnimation {}` or an invented spring | a value from step 5 | nobody chose the value |
| a new file, token set or generic `Animation` / `View` extension in an edit to one view | inline values, `private` helpers in that file | names collide and become app vocabulary nobody chose |
| changing a lifetime, size, copy or layout nobody asked about | a one-line suggestion | the request was about motion |
| `asyncAfter` sized to a duration | the completion form of `withAnimation`, or a cancellable `.task(id:)` | it drifts and can't be cancelled |
| an `onAppear` opacity flip entrance | conditional insertion driven by real state, or no entrance | it re-fires and hides content |
| keyframes / `repeatForever` on a toggle, toast or draggable | a spring | keyframes restart instead of retargeting |
| a hand-rolled sheet, menu, alert or push | the native component | it loses system timing and accessibility |
| `onTapGesture` for a button | `Button` + `ButtonStyle` | no pressed state, no traits |
| a second press effect on a glass button | nothing: glass already responds | two responses fight |
| `.navigationTransition(.zoom)` nested inside the destination | on the destination's root | nested, it does nothing |
| stagger on `List` rows or a menu | no stagger | seen too often; lazy rows re-fire |
| `TabView` selection in `withAnimation` | no animation | tabs are peers, not depth |
| `.sensoryFeedback(.warning, trigger: flag)` firing both ways | the condition form `{ _, new in new }` | the dismiss buzzes too |
| a missing Reduce Motion branch | a gentler variant, not zero | the system won't adapt custom motion |

## Output

Write the code first. Then, in at most a few lines:

1. **Gate:** how often it's seen and what the motion is for, plus anything you rejected and why.
2. **Ingredients:** tool, animated properties, spring or curve, where the animation is scoped, the Reduce
   Motion branch, and the haptic (or "none" and why).
3. **Device feel-check:** flick it, interrupt it, reverse it, and run it on the slowest supported device in a
   Release build with Reduce Motion on and off. Name the one or two things code can't prove (a crossfade's
   balance, a spring's tail, haptic sync), and look again the next day with fresh eyes.
4. **Suggestions**, only if you noticed something outside the request: one line each, left unchanged in code.

The explanation is for the user, so write it in their terms. Give each choice with its reason ("a 0.3 s spring
with no bounce, so it can turn around mid-way without a wobble"), and never mention this skill's internals:
reference file names, recipe or section numbers, rule labels, or "the skill's standard". Say whose guidance it
is: Apple's documentation, HIG and WWDC can be cited as Apple's; a tier, ceiling, scale or lifetime from this
skill is "a guideline" or simply the reason. Don't pad this into a report. If step 1 says no, the whole answer
is the reason and the non-motion alternative.

## References

| Read | When |
|---|---|
| `references/recipes.md` | The request matches a press button, toggle or morphing button, toast, custom menu / popover, list insert / remove, numeric counter or badge pop, error shake, success check, card expand hero / zoom, staggered first-run entrance, Liquid Glass morph, or segmented pill. Build from the recipe; when editing, carry over its pattern, not its scaffolding. |
| `references/springs-and-timing.md` | You need an exact value for an interaction, an API fact, a duration ceiling, a conversion, or (only when asked for an app-wide motion system) the shared token block |
| `references/choreography.md` | More than one element moves for the same event |
| `references/reduce-motion-and-haptics.md` | Writing the Reduce Motion branch or choosing a haptic (every animation) |
| `references/web-to-swiftui.md` | The request uses CSS, Motion / Framer Motion, React Native or other web terms, or you're porting web motion |
