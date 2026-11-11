# Finding opportunities and removing motion

Modes 3 and 4 are the same judgment run in opposite directions. Both start from the native check and the gates below: a candidate that passes them all becomes a proposal; an existing animation that fails one becomes a removal.

Values are written out (`.spring(duration: 0.3, bounce: 0)`); when the project already has named animation constants, use its names for the nearest value. `PressScaleStyle` is in `standards.md` § Helpers. Frequency tiers, severity and the output columns are defined once in SKILL.md; this file gives the gates, the hunt lists and a worked output for each mode. Checklist IDs and file names in this file are for navigation only: proposals and removal tables the user reads explain the reason in plain words.

## Contents

- [Native check, then the five gates](#native-check-then-the-five-gates)
- [Mode 3: Find opportunities](#mode-3-find-opportunities)
  - [Where to hunt](#where-to-hunt)
  - [Common opportunities with exact values](#common-opportunities-with-exact-values)
  - [Common rejections](#common-rejections)
  - [Output (Mode 3)](#output-mode-3)
- [Mode 4: Remove](#mode-4-remove)
  - [The removal gate](#the-removal-gate)
  - [Reducing](#reducing)
  - [Where to hunt for removals](#where-to-hunt-for-removals)
  - [Keep these](#keep-these)
  - [Removal hazards](#removal-hazards)
  - [Procedure and cleanup](#procedure-and-cleanup)
  - [Output (Mode 4)](#output-mode-4)

---

## Native check, then the five gates

**Step 0, native check.** If a system component does it (`.sheet` + detents, `Menu`, `.popover`, `.contextMenu`, `DisclosureGroup`, `.swipeActions`, `.refreshable`, `Picker(.segmented)`, `.contentTransition`, `.symbolEffect`, zoom transitions **(iOS 18)**), the proposal is the component and the gates stop here. In Remove mode, the same check keeps system motion.

Then ask the gates in order and record each answer; it goes in the report.

| Gate | Question | Passes when | Fails when |
|---|---|---|---|
| **1. Frequency** | How often does the user see this? (tiers: SKILL.md § Ground rules) | Occasional or rare. Tens/day only within its budget (near-imperceptible) | 100+/day, including custom motion on keyboard shortcuts and anything input-rate driven |
| **2. Purpose** | Name it in one word | Feedback, spatial consistency, state indication, preventing a jarring change, explanation; delight in the rare tier only | "Polish", "feels alive", "looks nicer"; delight outside the rare tier |
| **3. Function** | Is this data the user is reading or acting on? | The change is one the user caused (they changed the range, added the item) | Charts, balances, tables or values moving on appear, refresh or mount; anything that delays reading |
| **4. Accessibility** | Can it ship with a Reduce Motion branch, and does a non-motion signal exist? | Travel and scale have an opacity fallback; the state is visible without motion and without haptics | Motion is the only signal; a loop, parallax or depth effect with no stop |
| **5. Performance** | Does it animate cheap properties on a small layer? | `.offset`, `.scaleEffect`, `.rotationEffect`, `.opacity`, `.visualEffect`, or a sanctioned layout exception (pill, progress fill, small accordion) | Layout on a large subtree, animated shadow radius, blur ≥ 20 pt or on materials, per-row animation in a lazy list |

Before proposing anything custom, also weigh **zero motion**: an instant change, a static affordance or a clearer layout can beat any animation. Say so when it does.

The 50th-use test settles close calls: imagine the 50th use today. If you'd skip the animation, reject it.

---

## Mode 3: Find opportunities

Read-only. The goal is the handful of places where a cut is actually confusing, not a list of everywhere motion could go. Cap the output at 5–7 proposals for an app, fewer for one view, ordered by leverage, not by how fun they'd be to build.

Workflow:

1. **Recon.** Stack, deployment target, existing animation constants (proposals use them), personality, frequency map. The recon searches are in `audit-template.md` § Recon.
2. **Sweep** the seams below. Done when every seam class has yielded candidates with `file:line` evidence or been explicitly cleared.
3. **Native check, then gate** every candidate. Be ruthless.
4. **Report** in the format below. If nothing survives, say so plainly: that's a good result.

### Where to hunt

**Feedback gaps**
- Tappable things with no pressed state: `onTapGesture` on button-like views, `.buttonStyle(.plain)` on cards.
- Destructive actions confirmed by a plain tap where a hold-to-confirm would prevent slips.
- Failed submits that only change text.

**Teleporting state**
- Conditional views (`if showX { … }`) toggled without `withAnimation` at the mutation.
- Counters and totals the user changes, rendered with plain `Text`.
- SF Symbols swapped by a ternary (`systemName: isOn ? "a" : "b"`).
- Collection mutations (`append`, `remove`, `insert`) in custom stacks without `withAnimation`, so the gap snaps shut.
- Content replaced in place (a label, a status) with a hard cut.

**Missing spatial story**
- Custom panels, menus and popovers that appear with no connection to their trigger.
- Toasts and banners that enter one way and leave another, or just appear.
- Card → detail navigation where the user loses their place.

**Gesture seams** (hand the build to **swift-motion-gestures**)
- Drags that snap on release with no velocity, distance-only dismissal, hard stops at edges.

**The delight budget**
- Rare, high-emotion moments rendered flat: first run, empty states, purchase success, streaks, backup complete. The only places bounce, generous stagger or a longer beat are welcome.

Searches:

```bash
rg -n --type swift -e '^\s*if (show|is)[A-Z]\w*\s*\{' .            # conditional views: check for withAnimation at the mutation
rg -n --type swift -e '\.toggle\(\)' -e ' = !' .                   # state flips in actions
rg -n --type swift -e 'Text\(\w+, format:' -e 'Text\("\\\(' .     # numbers without a content transition
rg -n --type swift -e 'systemName: \w+ \?' .                       # ternary symbol swaps
rg -n --type swift -e '\.append\(' -e '\.remove\(' -e '\.insert\(' -e 'removeAll' .
rg -n --type swift -e 'onTapGesture' -e 'buttonStyle\(\.plain\)' .
rg -n --type swift -e 'errorMessage' -e 'isInvalid' -e 'didSucceed' -e 'showError' .
```

These are leads, not findings. Open each, find its tier, run the gates.

### Common opportunities with exact values

| Today | Proposal | Exact values | Typical tier · purpose |
|---|---|---|---|
| A count the user changes jumps | `Text(n, format: .number).monospacedDigit().contentTransition(.numericText(value: Double(n)))` | change inside `withAnimation(.spring(duration: 0.3, bounce: 0))` (bounce must stay 0) | Occasional · state indication |
| An SF Symbol swaps with a cut | `.contentTransition(.symbolEffect(.replace))`; `.replace.magic(fallback:)` **(iOS 18)** | change inside `withAnimation(.spring(duration: 0.25, bounce: 0))` (within the tens/day budget) | Tens/day · feedback |
| A label or status is replaced with a cut | `.transition(.blurReplace)` or `.contentTransition(.interpolate)` | `.spring(duration: 0.3, bounce: 0)`; Reduce Motion: `.opacity` | Occasional · preventing a jarring change |
| Tappable with no pressed state | `Button` + `PressScaleStyle` | scale 0.97 (large cards 0.96–0.98), press 0.15 s / release 0.3 s springs, bounce 0. Glass buttons **(iOS 26)**: nothing, they already respond | Tens/day · feedback |
| Items pop in and out of a custom stack; the gap snaps | mutate inside `withAnimation(.spring(duration: 0.3, bounce: 0))` with stable ids | `.transition(.opacity.combined(with: .scale(scale: 0.95)))`; siblings reflow in the same transaction | Occasional · preventing a jarring change |
| A custom panel or menu appears with a cut | native `Menu` / `.popover` first. Custom: `.transition(.scale(scale: 0.95, anchor: <trigger side>).combined(with: .opacity))` | in 0.3 s, out 0.2 s, bounce-0 springs | Occasional · spatial consistency |
| A centred custom modal appears with a cut | card `.transition(.scale(scale: 0.96).combined(with: .opacity))` + backdrop `.opacity`, same transaction | `.spring(duration: 0.35, bounce: 0)`; centred, no anchor | Occasional · state indication |
| A toast or banner just appears | overlay + `.transition(.move(edge: .top).combined(with: .opacity))` (`.bottom` when anchored to a bottom action) | in 0.4 s, out 0.3 s, bounce-0 springs, same edge; lifetime 4 s, paused while `scenePhase != .active`; post an accessibility announcement; a toast with an action stays until acted on or dismissed | Occasional · state indication |
| A custom tab or segment indicator teleports | `Picker(.segmented)` first. Custom: one `Capsule().matchedGeometryEffect(id: "pill", in: ns)` | `.animation(.spring(duration: 0.3, bounce: 0), value: selection)` scoped to the pill, never `withAnimation` around the selection, so tab content stays instant; `.sensoryFeedback(.selection, trigger: selection)`; Reduce Motion: pills crossfade (code: `standards.md` § J8) | Tens/day · spatial consistency |
| A disclosure row expands with a cut | `DisclosureGroup` first. Custom: height change in `.spring(duration: 0.3, bounce: 0)` + `.clipped()` | small subtree only (sanctioned layout exception) | Occasional · preventing a jarring change |
| A failed entry shows only red text | error shake + error haptic (code below) | ≈ 0.4 s keyframes on `offset(x:)`; `.sensoryFeedback(.error, trigger: attempts)`; SF Symbol: `.symbolEffect(.wiggle, value:)` **(iOS 18)**; Reduce Motion: no shake, tint + haptic | Occasional · feedback |
| A destructive action fires on a plain tap | hold-to-confirm (code: `standards.md` § E4) | `.linear(duration: T)` fill while pressed; early release `.spring(duration: 0.2, bounce: 0)` back to 0; `.impact(weight: .medium)` on commit (a destructive action firing; `.success` is for non-destructive task outcomes); T ≈ 1–2 s for destructive actions (0.5 s system default otherwise) | Occasional · feedback |
| A rare success has no confirmation | `.symbolEffect(.bounce, value: n)` + `.sensoryFeedback(.success, trigger: n)` | `.bouncy` (0.5 s, bounce 0.3) if a spring is needed; check-mark draw: square `trim` `.timingCurve(0.645, 0.045, 0.355, 1, duration: 0.6)`, check 0.4 s starting at 0.5 s; one-shot, never looped | Rare · delight |
| A first-run screen pops in all at once | stagger the group once | 100–150 ms steps on 0.5–0.6 s entrances (e.g. 120 ms, 0.6 s, 10 pt rise); still tappable at once; Reduce Motion: fade together | Rare · explanation |
| An occasional small group pops in all at once | stagger | `Double(min(i, 6)) * 0.04` delay (40 ms, capped at index 6, span ≤ 0.3 s), `.spring(duration: 0.3, bounce: 0)`, rise 6–8 pt (code: `standards.md` § G3) | Occasional · preventing a jarring change |
| Card → detail push loses the user's place | `.matchedTransitionSource(id:in:)` on the card + `.navigationTransition(.zoom(sourceID:in:))` on the destination root **(iOS 18)** | system timing; gate with `if #available(iOS 18, *)`, plain push on iOS 17; Reduce Motion: plain push (code: `standards.md` § J8) | Occasional · spatial consistency |
| A spinner flashes on fast loads | not motion: delay the loader | show after 150–300 ms; once shown keep ≥ 300–500 ms (code: `standards.md` § J10) | Any · preventing a jarring change |
| A drag ends with an instant snap | route to **swift-motion-gestures** | release `.spring(duration: 0.3, bounce: 0.2)` (free target with momentum) or `.spring(duration: 0.3, bounce: 0)` (hard edge, snap back); commit at `translation + project(v) > 0.4 × travel`; rubber-band c = 0.55 | Varies · feedback |

The error shake (the keyframe values are a starting point to tune on a device):

```swift
struct CodeField: View {
    @Binding var code: String
    var attempts: Int          // increment on every failed submit
    var isInvalid: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TextField("Code", text: $code)
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isInvalid ? Color.red : Color.secondary))
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: attempts) { [reduceMotion] content, x in
                content.offset(x: reduceMotion ? 0 : x)
            } keyframes: { _ in
                CubicKeyframe(-8, duration: 0.08)
                CubicKeyframe(8, duration: 0.08)
                CubicKeyframe(-5, duration: 0.08)
                SpringKeyframe(0, duration: 0.16, spring: Spring(duration: 0.16))
            }
            .sensoryFeedback(.error, trigger: attempts)
    }
}
```

Keyframes are fine here because the shake is a one-shot that can't be re-triggered faster than it plays. Cubic keyframes pass through −8, 8 and −5 exactly; a `SpringKeyframe` left on its default 0.5 s spring reaches only about ±2 pt in a 0.08 s segment, so the shake barely shows. `offset(x:)` is neutral in right-to-left layouts.

### Common rejections

| Candidate | Gate failed | Why |
|---|---|---|
| Animate tab switches | Frequency | 100+/day, and tabs are peers; a slide implies depth that isn't there |
| Animate the keyboard appearing, or a palette opened by a hardware shortcut | Frequency | Keyboard show/hide is 100+/day; people use shortcuts to go fast, so custom motion on them reads as delay |
| Search results re-animating per keystroke | Frequency | Input-rate motion counts as 100+/day |
| Stagger the main feed's rows on load | Frequency, Performance | Seen all day; lazy rows recycle and re-fire on scroll-back |
| Grow chart bars or count up a balance on appear | Function | Delays the data the user came to read |
| Pulse an idle "new" badge | Purpose, Accessibility | Decoration; a loop with no trigger |
| Bounce on a tap-opened sheet or menu | Purpose | Bounce means momentum; nothing was thrown |
| Custom animation on `Toggle`, `Picker` or the `NavigationStack` push | Native | System components keep their own motion |
| Animate a card's `.shadow(radius:)` on lift | Performance | Expensive per frame; crossfade a static shadow layer |
| Parallax hero image on a frequent screen | Accessibility, Frequency | Depth motion that needs a stop under Reduce Motion, for little purpose |

### Output (Mode 3)

```markdown
**Mode: Find opportunities** · `Features/Cart/` · 2 proposals, 4 rejected

### Proposals
| # | Location | Today | Proposal (API and values) | Tier · Purpose |
|---|---|---|---|---|
| 1 | `CartView.swift:58` | Item count jumps from 2 to 3 | `.monospacedDigit().contentTransition(.numericText(value: Double(count)))`, change in `withAnimation(.spring(duration: 0.3, bounce: 0))`. Reduce Motion: unchanged (no travel). Haptic: none, the add button already confirms | Occasional · state indication |
| 2 | `PromoCodeField.swift:31` | A wrong code only turns the text red | Error shake (keyframes −8/8/−5/0 pt, ≈ 0.4 s) + `.sensoryFeedback(.error, trigger: attempts)`. Reduce Motion: no shake, red stroke + haptic | Occasional · feedback |

### Rejected candidates
| Location | Candidate | Gate failed | Reason |
|---|---|---|---|
| `CartView.swift:22` | Stagger cart rows on appear | Frequency | The cart opens many times a day; rows should already be there |
| `CartTotalChart.swift:14` | Draw the spend chart from zero | Function | The user is reading the numbers |

### Verdict
The cart needs very little motion; it is already close to right. Highest leverage: #1, because the count is the
only confirmation that the add worked. Build it with swift-motion-animate.
```

Every proposal names its Reduce Motion branch and its haptic decision. The rejected list is always present: it is the evidence that the gates ran. When feel can't be judged from code alone, say so.

---

## Mode 4: Remove

This mode edits code, but only by subtracting. The burden of proof is reversed: an animation stays only if it passes the gate. "It's already there" and "it looks nice" are not defenses. Deleting everything is also wrong: motion that bridges a jarring change (a toast that would otherwise teleport in, a gap closing after a delete) earns its place.

### The removal gate

Walk every animation through this tree and record the branch that decided it.

```
Is it custom motion layered on a system component, or the system motion itself?
└── System motion itself → KEEP. Stripping it is a defect, not a cleanup.

Is it custom motion wrapped around a hardware-keyboard action (`.keyboardShortcut`, `onKeyPress`, arrow
keys), driven per keystroke, or animating the keyboard's own show/hide?
└── Yes → DELETE.
    (A surface a shortcut also opens, such as a composer on ⌘N, is judged by how often it opens.
    A system sheet the shortcut presents keeps its motion.)
    (Return on the software keyboard and focus changes are not on this branch: `onSubmit` and
    `@FocusState` motion goes through the frequency question below. A sent message moving into
    the thread is legitimate.)

Is it seen 100+ times a day (tab switches, core-list selection, per-keystroke results, scrolling, launch)?
└── Yes → DELETE. At that frequency any duration reads as delay.

Is it on functional data the user is reading or acting on (charts, tables, balances, dashboards)?
└── Yes → DELETE, unless it shows a real change in value the user caused.
          Re-animating on every appear or refresh is decoration.

Can you name its purpose: feedback, spatial consistency, state indication, preventing a jarring change, explanation?
├── No → Is it a rare, first-time moment (onboarding, empty state, success)?
│        ├── Yes → KEEP. This is the delight budget.
│        └── No → DELETE.
└── Yes → Is it seen tens of times a day (press, row expansion, chips, indicators)?
          ├── Yes → REDUCE: delete the parts over the tens/day budget (see Reducing).
          └── No → Is it over budget (see standards.md C4), or a slide/scale where a fade carries the same meaning?
                   ├── Yes → REDUCE.
                   └── No → KEEP.
```

### Reducing

Reduce is subtraction too: delete parts of the motion and keep the rest exactly as written. It never introduces a new duration, bounce or scale value. When the part that is over budget is a value (a 0.5 s spring, a bounce, a 1.05 scale), leave it and list it for a Review with the reason.

| Today | Reduced to (subtraction) | Listed for a Review |
|---|---|---|
| Press with scale, lift and shadow growth on a frequent card | Delete the lift (`offset`) and the shadow animation; keep the scale | A press scale deeper than 3 % |
| Slide or scale entrance on a frequent surface | Delete the `.move` / `.scale` / `offset` part; keep the opacity (`.move(edge:).combined(with: .opacity)` → `.opacity`) | A duration over the tens/day budget |
| Tens/day spring with bounce, or longer than 0.25 s | Nothing to delete | A swap to `.spring(duration: 0.25, bounce: 0)` |
| Stagger over 80 ms per item, or over 0.3 s total | Delete the per-item `.delay`, so the group enters as one | A smaller step, if the sequence must stay |
| Infinite loop (pulse, shimmer, glow) on a persistent element | Delete the `.repeatForever` / `.repeat` / `isActive` loop and keep the static end state, or the one-shot already tied to its trigger | |

If what survives is too small to carry its purpose, delete it instead.

### Where to hunt for removals

| Target | How to find it | What to remove |
|---|---|---|
| Motion on 100+/day actions | tab selection inside `withAnimation`; `.animation(_, value: searchText)`; scroll-driven `withAnimation` | the `withAnimation` wrapper or the `.animation` modifier; keep the state change |
| Hardware-keyboard and per-keystroke motion | `.keyboardShortcut` and `onKeyPress` actions wrapped in `withAnimation`; `.animation(_, value: text)` on a text field's binding | the animation; keep the action. `onSubmit` and `@FocusState` motion is judged by frequency, not deleted on sight |
| Tab or page slides between peers | `.transition(.move…)` or offset animation keyed to tab selection; `.tabViewStyle(.page)` for app tabs | the transition (and the page style for app tabs) |
| Decorative loops | `repeatForever`, triggerless `phaseAnimator`, `keyframeAnimator(repeating:)`, `.symbolEffect(.pulse / .breathe` **(iOS 18)** `/ .variableColor)` running on idle UI | the loop. A real constant process (recording, live, loading) stays, and so does a coach-mark nudge within the attention-loop budget (first run after ~2.5 s, at most every ~6 s, stops on interaction); both must stop under Reduce Motion |
| Delays before content | `.delay(` outside a stagger; `asyncAfter` or `Task.sleep` before showing content | the delay: content appears at once |
| Staggered menus, popovers, tooltips, coach marks and tab content | per-index `.delay` inside them | the per-item delay; the container's single entrance stays |
| Parent and children both entering | a container transition plus a child stagger | the child stagger |
| Entrances on lists and lazy rows | `onAppear { withAnimation … }` in rows; `appeared` flags; `.transition` on `List` rows | the flip and its state; rows render in place |
| Motion on functional data | charts, totals, balances animating on appear or refresh | the appear/refresh animation; keep animation of changes the user caused |
| Flourishes on frequent cards | scale + lift + shadow growth on press or hover | the lift and the shadow animation (Reducing, above) |
| Spinners and shimmer on fast work | `ProgressView()` or skeleton shimmer for work under 300 ms | the immediate spinner (a delayed one is a Review fix, not a removal) |
| Duplicate or dead haptics | `.sensoryFeedback` on `Toggle`, `Picker`, `Slider`; `.levelChange`, `.start`, `.stop` on iPhone; haptics on launch or uncaused entrances | the extra or dead `.sensoryFeedback` |
| Value-less `.animation(_:)` that only exists to "make things smooth" | `.animation(.default)` high in the tree | the modifier; if a specific change still needs motion, list it for a Review |

### Keep these

- **System motion**: push, sheet, `Menu`, `.popover`, `Toggle`, `TabView`, `.swipeActions`, glass responses.
- **Reduce Motion branches** and the `accessibilityReduceMotion` reads behind them.
- **Haptics that confirm an outcome** (`.success`, `.error`, a detent catching), unless doubled or dead. Removing an animation doesn't remove its haptic; haptics aren't motion.
- **Gesture-release springs.** A spring finishing a drag is the physics, not decoration.
- **Motion that prevents a jarring change**: the gap closing after a row is deleted, a toast entering from its edge, a panel showing where it came from. List these under Kept.
- **Documented decisions.** A comment or design doc that explains why an animation exists: keep it and note it.

### Removal hazards

Check each before deleting. They are why removal isn't find-and-replace.

- **Hidden start states.** `.opacity(appeared ? 1 : 0)`, `.offset(y: appeared ? 0 : 20)` or `.scaleEffect(appeared ? 1 : 0.95)` driven by an `onAppear` flip. Delete the flip without the start state and the view stays invisible or offset forever. Delete the start state, the flip and the `@State` together.
- **Work in completions.** `withAnimation(…) { } completion: { dismiss() }`, or navigation, deletion, focus or an accessibility announcement in the completion. Keep the work and run it directly at the mutation.
- **Timers sized to a duration.** `asyncAfter` or `Task.sleep` waiting for an animation to finish. Delete the wait with the animation, or the UI keeps pausing for motion that no longer exists.
- **Removal transitions delaying disappearance.** A view with a `.transition` stays on screen until its removal finishes; without it, it disappears at once, so anything relying on its `onDisappear` timing now runs earlier. Check it.
- **Animation hiding a layout jump.** `withAnimation` around a layout change can be masking a jump. If removing it reveals the jump, keep the animation and list the jump as a finding: fixing layout is out of scope here.
- **Inert leftovers.** Removing the animation from a `.contentTransition` change leaves the content transition doing nothing: remove it too. Same for a `matchedGeometryEffect` whose animation is gone (remove the modifier and the `@Namespace`).
- **Inherited animation.** If an outer `.animation` or `withAnimation` still reaches the subtree you cleaned, cut it with `.transaction { $0.animation = nil }` rather than restructuring.
- **Tests.** UI tests that `sleep` for a duration or wait on an animation need the same removal.

### Procedure and cleanup

1. **Recon** with the searches in `audit-template.md` § Recon; map each site to its tier.
2. **Gate** each site through the tree; record the deciding branch.
3. **Check hazards** for every Delete and Reduce.
4. **Edit** with the smallest change: delete the `.animation(…)` or `.transition(…)`; unwrap `withAnimation(…) { x = y }` to `x = y`; delete the `.delay(…)` or the `asyncAfter` / sleep wrapper, keeping its body.
5. **Clean up** what your removals orphaned: `@State` flags, `@Namespace`s, one-off private `Animation` constants with no remaining references, empty helper views and imports of animation packages no longer used. Leave a shared motion-constant file intact even if some constants are now unused. Leave pre-existing dead code alone and mention it. If an animation package (Lottie, Rive, a motion library) is no longer imported anywhere, propose removing the dependency; ask before touching `Package.swift` or the project file.
6. **Verify**: build, render the affected `#Preview`s, run the tests, and grep for every removed name to confirm nothing still references it.

```swift
// Before: one bouncy transaction animates the tab content and the indicator together
Button { withAnimation(.bouncy) { tab = .inbox } } label: { Label("Inbox", systemImage: "tray") }
// After: subtraction only; the tab content now switches instantly
Button { tab = .inbox } label: { Label("Inbox", systemImage: "tray") }
```

If the bar has a custom indicator pill, it now jumps too. Moving it on its own scoped `.animation(.spring(duration: 0.3, bounce: 0), value: tab)` would be adding motion, so leave it and list it for a Review instead (`standards.md` § J8 `TabIndicator` has the code).

```swift
// Before: content waits on a timer, then fades in from a hidden start state
Text("Welcome back")
    .opacity(showContent ? 1 : 0)
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { showContent = true } }
    }
// After: the timer, the flip, the start state and the @State are all gone
Text("Welcome back")
```

Never add motion, swap an animation or retune a value in this mode, including inside a Reduced verdict. If an animation should stay but is badly built or over budget by value (`.easeIn` on a toast, a bare `withAnimation`, a bouncy chip), leave it and list it for a Review.

### Output (Mode 4)

```markdown
**Mode: Remove** · `Features/` · 5 deleted, 1 reduced, 3 kept

### Removed and reduced
| # | Location | Was | Verdict | Deciding reason |
|---|---|---|---|---|
| 1 | `TabBar.swift:31` | `withAnimation(.bouncy)` around tab selection | Deleted | 100+/day (tab switch) |
| 2 | `FeedRow.swift:18` | `onAppear` fade flip + `appeared` state | Deleted, start state removed | 100+/day, lazy rows re-fire |
| 3 | `ProjectCard.swift:40` | scale 1.05 + lift + shadow growth on press | Reduced: lift and shadow animation removed; the scale stays as written | Tens/day |

### Kept
- `CartView.swift:72`: `withAnimation(.spring(duration: 0.3, bounce: 0))` on delete. **Kept: closes the gap so the user sees which row left.**
- `Onboarding/Done.swift:30`: `.symbolEffect(.bounce)` + `.success`. **Kept: rare, first-time moment.**
- For a Review: `Toast.swift:12` enters with `.easeIn(duration: 0.4)`, which starts slowly just when the user is looking for it; `ProjectCard.swift:40` grows to 1.05 on press instead of dipping slightly, which reads as the card jumping toward the finger.

### Cleanup and verdict
Removed `@State appeared` (FeedRow), `@Namespace tabNS` (TabBar). No dependency changes.
The tab bar and feed now respond instantly; nothing that explained a change was lost.
**Build:** succeeded · **Previews checked:** `FeedView`, `TabBar` · **Needs a device:** perceived speed of the feed on an older phone.
```
