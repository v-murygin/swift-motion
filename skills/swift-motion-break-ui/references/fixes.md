# Breaks and their fixes

Each section names a break, shows the code that causes it, and gives the fix. iOS 17+ unless marked. Try the fix order from SKILL.md first: wrap, change the layout, decide who gives way, clamp prose, and only then scale down.

Model types used here (`Contact`) are defined in [preview-harness.md §1](preview-harness.md#1-fixtures-enum). Helpers are defined once and named where they're reused.

Helpers here (`nonBlank`, `Avatar`, `InitialsAvatar`, `UnreadBadge`) are `private`: when you fix a user's view, copy the ones it needs into that view's file rather than adding a shared file or a project-wide extension. If the project already has an equivalent (its own avatar view, a blank-string helper), use that instead. `ContactRow`, `ContactList` and `ContactListScreen` stand in for the user's own views and stay internal.

These sections are for you. In the report, explain a fix in plain words with its reason; don't cite section numbers or file names from this skill.

## Contents

0. [Failure signatures: what you see → section](#0-failure-signatures-what-you-see--section)
1. [Text pushes siblings off-screen](#1-text-pushes-siblings-off-screen)
2. [Truncate, wrap or clamp](#2-truncate-wrap-or-clamp)
3. [Fixed heights that clip, screens that don't scroll](#3-fixed-heights-that-clip-screens-that-dont-scroll)
4. [Layout that should change at large sizes](#4-layout-that-should-change-at-large-sizes)
5. [Fonts and icons that don't scale](#5-fonts-and-icons-that-dont-scale)
6. [Numbers, amounts, plurals and dates](#6-numbers-amounts-plurals-and-dates)
7. [Optional, nil and empty fields](#7-optional-nil-and-empty-fields)
8. [Images](#8-images)
9. [Empty, loading, error and offline states](#9-empty-loading-error-and-offline-states)
10. [Right-to-left](#10-right-to-left)
11. [Dark mode, contrast, transparency and Bold Text](#11-dark-mode-contrast-transparency-and-bold-text)
12. [Worked example: a hardened row](#12-worked-example-a-hardened-row)
13. [Keyboard](#13-keyboard)
14. [Large collections](#14-large-collections)
15. [Emoji and complex scripts](#15-emoji-and-complex-scripts)
16. [User content rendered as markup](#16-user-content-rendered-as-markup)
17. [Tap targets](#17-tap-targets)
18. [`minimumScaleFactor`, the last resort](#18-minimumscalefactor-the-last-resort)

---

## 0. Failure signatures: what you see → section

Each of these shows up in a rendered preview. The cause in the middle column is almost always it.

| What you see | Cause | Fix (section) |
|---|---|---|
| Crash, or the preview won't render for one fixture | `!`, `as!`, `items[0]`, `.first!` on missing data | Optional binding, designed fallback ([§7](#7-optional-nil-and-empty-fields)) |
| Trailing chevron, badge or button pushed off the row | `.fixedSize()` on user text, or a sibling that won't shrink | `.layoutPriority(1)` on the text, `.fixedSize()` only on short values ([§1](#1-text-pushes-siblings-off-screen)) |
| Every email at one company reads the same `bartholomew.fitzger…` | Default tail truncation | `.truncationMode(.middle)` ([§2](#2-truncate-wrap-or-clamp)) |
| German label broken mid-word: `Benachrichtigungseinstellu` / `ngen` | Fixed width; no room for an unbreakable word | Width from content, `ViewThatFits` ([§4](#4-layout-that-should-change-at-large-sizes)) |
| Glyphs cut through at the top or bottom (Thai, Vietnamese, AX sizes) | `.frame(height:)` or `.clipped()` around text | `minHeight`, no clip on text ([§3](#3-fixed-heights-that-clip-screens-that-dont-scroll), [§15](#15-emoji-and-complex-scripts)) |
| Content runs off the bottom at AX5 | Screen content in a plain `VStack` | `ScrollView` ([§3](#3-fixed-heights-that-clip-screens-that-dont-scroll)) |
| One word per line at `.xxxLarge`+ | `HStack` that should stack | `AnyLayout` switch or `ViewThatFits` ([§4](#4-layout-that-should-change-at-large-sizes)) |
| 17 pt text or a 24 pt icon next to 53 pt text | `.font(.system(size:))`, fixed icon frame | Text styles, `@ScaledMetric` ([§5](#5-fonts-and-icons-that-dont-scale)) |
| `1234567`, `0.30000000000000004`, `Optional(…)`, `nil` | A `String` built before it reaches `Text` (`"\(x)"` stored as a `String`, `String(x)`, `Text(verbatim:)`) | `Text(value, format:)`, optional binding ([§6](#6-numbers-amounts-plurals-and-dates), [§7](#7-optional-nil-and-empty-fields)) |
| `0.300000`; `1234567.89 €` in every locale | A `Double` (six decimals) or a `Decimal` (raw) interpolated into a `Text` literal | `Text(value, format:)` ([§6](#6-numbers-amounts-plurals-and-dates)) |
| A year, ID or zip code with a separator: `2,026`, `Order 18,472` | An `Int` interpolated into a `Text` literal is grouped by locale | `Text(verbatim: String(year))` or `.number.grouping(.never)` ([§6](#6-numbers-amounts-plurals-and-dates)) |
| `12345…` in a stat column | Fixed `.frame(width:)` around a number | Compact notation, flexible width ([§6](#6-numbers-amounts-plurals-and-dates)) |
| "1 followers" | Hardcoded plural | Grammar agreement or String Catalog plurals ([§6](#6-numbers-amounts-plurals-and-dates)) |
| "-3 unread", a badge reading `-3`, `-€0.00`, `-0%` | Display trusts raw data; sign or colour taken from the unrounded value | Clamp counts that can't be negative, decide sign after rounding ([§6](#6-numbers-amounts-plurals-and-dates)) |
| Crash on `nan`, infinity or a huge count | `Int(double)`, `count + 1` overflow | Check `isFinite`, use `&+` or saturating logic, format the `Double` directly ([§6](#6-numbers-amounts-plurals-and-dates)) |
| Digits jitter as a value updates; columns misalign | Proportional digits | `.monospacedDigit()` ([§6](#6-numbers-amounts-plurals-and-dates)) |
| Orphaned `·` or a blank line where a field was | Concatenating an empty optional | Join only non-blank parts ([§7](#7-optional-nil-and-empty-fields)) |
| Endless spinner or grey square where an avatar should be | `AsyncImage(url:content:placeholder:)` with no failure path; `nil` URL | Phase-based `AsyncImage` + initials fallback ([§8](#8-images)) |
| Avatar squashed into an oval | `.resizable()` without `scaledToFill()` | `scaledToFill()` + fixed frame + clip ([§8](#8-images)) |
| A photo list hitches while scrolling, memory climbs into the hundreds of MB | Full-size images decoded per row, reloaded when rows come back | Downsample to display size, cache the thumbnail ([§8](#8-images)) |
| Wrong initials: `CI` for "… Montgomery III", `🦊`, `�`, lowercase `d` for "dana" | `prefix(1)` / split-by-space / `NSString` logic | `PersonNameComponents` abbreviated, symbol fallback ([§8](#8-images)). One letter for a one-word name ("Jo" → `J`) is correct |
| Avatar centred against a three-line name looks adrift | `HStack(alignment: .center)` with wrapping text | `.top` alignment once text can wrap ([§12](#12-worked-example-a-hardened-row)) |
| Blank screen for an empty list | No empty state | `ContentUnavailableView` ([§9](#9-empty-loading-error-and-offline-states)) |
| Spinner flashes on fast loads; skeleton doesn't match | Immediate `ProgressView`; bespoke skeleton | Delayed spinner; `.redacted(reason: .placeholder)` on real rows ([§9](#9-empty-loading-error-and-offline-states)) |
| Mirrored layout with arrows pointing backwards, a panel sliding from the wrong side | Custom arrow images, `.offset(x:)`, `.position(x:)`, forced `.leftToRight` | `chevron.forward`, `flipsForRightToLeftLayoutDirection`, `.move(edge: .leading)` ([§10](#10-right-to-left)) |
| Text or icons invisible in dark mode / with Increase Contrast | Hardcoded colours, translucent custom fills | Semantic styles, asset variants ([§11](#11-dark-mode-contrast-transparency-and-bold-text)) |
| Selected tab or chip widens when selected | Bold weight on selection | Colour/opacity only, or a fixed width ([§11](#11-dark-mode-contrast-transparency-and-bold-text)) |
| Field or primary button under the keyboard | `.ignoresSafeArea()` on content, non-scrolling form | `ScrollView` + `safeAreaInset` ([§13](#13-keyboard)) |
| 10,000 rows stall the preview or scroll badly | Non-lazy stack, work in `body` | `List` / `LazyVStack`, precompute ([§14](#14-large-collections)) |
| `**bold**` from a user turns bold, links become tappable | User string passed through `LocalizedStringKey` or Markdown parsing | `Text(verbatim:)` ([§16](#16-user-content-rendered-as-markup)) |
| Tap target shrinks to the size of `J` | Hit area = visual | `minWidth/minHeight: 44` + `.contentShape` ([§17](#17-tap-targets)) |
| Diacritics from a "Zalgo" name drawn over the rows above and below | Stacked combining marks extend past the line box | Leave the text unclipped; limit marks at input if it matters ([§15](#15-emoji-and-complex-scripts)) |

---

## 1. Text pushes siblings off-screen

**Break:** a long name in an `HStack` squeezes the timestamp into "1…" or pushes the chevron out. `.fixedSize()` on a user string makes it ignore the screen width entirely.

```swift
// Before
HStack {
    Text(contact.name).fixedSize()          // ignores the available width
    Spacer()
    Text(lastSeen, format: .dateTime.hour().minute())
}
```

**Fix:** let the important text take the space first, and make short values that must stay whole fixed-size. `.fixedSize()` belongs on values whose length you control, never on user-generated strings.

```swift
// After
HStack(alignment: .firstTextBaseline) {
    Text(contact.name)
        .lineLimit(2)
        .layoutPriority(1)                  // gets space before the timestamp
    Spacer(minLength: 8)
    Text(lastSeen, format: .dateTime.hour().minute())
        .foregroundStyle(.secondary)
        .fixedSize()                        // a time is short and must never truncate
}
```

## 2. Truncate, wrap or clamp

Every long string forces this choice. Make it per field, not globally.

- **Wrap** text the user needs in full to identify something: names, titles in a detail view. Two lines is usually fine; four is a sign the column is too narrow.
- **Truncate at the end** (`.truncationMode(.tail)`, the default) for secondary metadata where the start carries the meaning: role, description, last-message preview. Pair it with a way to see the full value (detail screen, expansion).
- **Truncate in the middle** (`.truncationMode(.middle)`) when items differ at the *end*: file names, emails sharing a long domain, URLs, paths, hashes, order IDs. End truncation makes them identical.
- **Clamp** (`.lineLimit(2, reservesSpace: true)`) for multi-line previews in cards, so card heights stay predictable.
- **Never truncate** numbers, amounts, dates, or anything the user compares. Give them the room ([§6](#6-numbers-amounts-plurals-and-dates)).

```swift
// Emails, file names, URLs, IDs: the end carries meaning
Text(email)
    .lineLimit(1)
    .truncationMode(.middle)
    .textSelection(.enabled)                // let users copy it

// Prose in a card: clamp, and keep the card height stable
Text(post.summary)
    .lineLimit(3, reservesSpace: true)
```

## 3. Fixed heights that clip, screens that don't scroll

**Break:** `.frame(height: 44)` fits English at `.large`. At AX5, or with Thai or Vietnamese stacked marks, glyphs are cut off.

```swift
// Before
Text(title).frame(height: 44)
```

**Fix:** let text decide its height; keep the minimum for the tap target. Remove `.clipped()` from containers that hold text, unless the clipping is the point.

```swift
// After
Text(title)
    .padding(.vertical, 12)
    .frame(minHeight: 44)
```

**Break:** a screen built as a plain `VStack` fits at `.large` on an iPhone 16 and runs off the bottom at AX5 or on an iPhone SE, with no way to reach the button.

**Fix:** put screen content in a `ScrollView`. `.scrollBounceBehavior(.basedOnSize)` keeps it from bouncing when everything fits, so the normal case feels unchanged.

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 16) {
        header
        details
    }
    .padding()
}
.scrollBounceBehavior(.basedOnSize)
```

## 4. Layout that should change at large sizes

**Break:** at `.xxxLarge` and above, an avatar + name + amount `HStack` leaves the name one word per line.

**Fix A: switch stacks at accessibility sizes.** `AnyLayout` keeps view identity, so state and focus survive the switch.

```swift
import SwiftUI

struct ProfileHeader: View {
    let name: String
    let avatar: Image
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        layout {
            avatar
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(.circle)
            Text(name)
                .font(.title2.bold())
        }
    }
}
```

**Fix B: `ViewThatFits`.** Offer arrangements from widest to narrowest; SwiftUI picks the first whose ideal size fits. Good for button pairs and label–value rows, where the answer depends on the actual text length (a German label breaks at `.large`), not only on the size category.

```swift
ViewThatFits(in: .horizontal) {
    HStack(spacing: 12) {
        Button("Abbrechen", role: .cancel) { cancel() }
        Button("In den Warenkorb legen") { add() }.buttonStyle(.borderedProminent)
    }
    VStack(spacing: 8) {
        Button("In den Warenkorb legen") { add() }.buttonStyle(.borderedProminent)
        Button("Abbrechen", role: .cancel) { cancel() }
    }
}
```

Don't cap Dynamic Type at the root (see the override rules under Fix order in SKILL.md). If one piece of chrome truly can't grow, cap that piece leniently:

```swift
TabBarLabel(title: title)
    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
```

## 5. Fonts and icons that don't scale

**Break:** `.font(.system(size: 17))` stays 17 pt at AX5 while everything else grows. An icon in a fixed 24 pt frame looks tiny next to 53 pt text.

```swift
// Before
Text(title).font(.system(size: 17, weight: .semibold))
Image("pin").resizable().frame(width: 24, height: 24)
```

**Fix:** use text styles; give custom fonts a `relativeTo:` style; scale non-text sizes with `@ScaledMetric`.

```swift
// After
import SwiftUI

struct PlaceRow: View {
    let title: String
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24

    var body: some View {
        HStack(spacing: 8) {
            Image("pin")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)                                     // system text style
            // or: .font(.custom("BrandSans-Semibold", size: 17, relativeTo: .headline))
        }
    }
}
```

SF Symbols placed with `Image(systemName:)` or `Label` scale with the surrounding font already; they need no `@ScaledMetric`.

## 6. Numbers, amounts, plurals and dates

**Break:** interpolation is not a format style. Inside a `Text` literal, `Text("\(followers)")` is grouped by the locale (`48,300,000`, `48.300.000` in de_DE) but can't use compact notation, so a fixed 70 pt stat column truncates it to `48,3…`. A `Double` always shows six decimals (`Text("\(0.1 + 0.2)")` → `0.300000`), and a `Decimal` isn't localized at all (`Text("\(balance) €")` → `1234567.89 €` in every locale; the current SDK flags that interpolation as deprecated). The same grouping hits numbers that must not be grouped: `Text("Since \(year)")` → "Since 2,026". A string built before it reaches `Text` (`"\(count)"` stored as a `String`, `Text(verbatim:)`) gets no locale at all: `1284`, `0.30000000000000004`. "1 followers" appears. Digits that change width make a counter jitter. A "never" date shows the year 4001.

```swift
// Before
VStack {
    Text("\(followers)").font(.headline)
    Text("followers").font(.caption)
}
.frame(width: 70)
Text("\(balance) €")                         // balance: Decimal → "1234567.89 €" everywhere
Text("Since \(year)")                        // year: Int → "Since 2,026"
Text("Expires \(expiry.description)")       // expiry = .distantFuture means "never"
```

**Fix:** format with `Text(value, format:)` (it uses the view's environment locale), use grammar agreement or String Catalog plurals, give numbers their room, and model "never" as `nil`.

```swift
// After
Text(followers, format: .number.notation(.compactName))         // 48,300,000 → "48M"
    .font(.headline.monospacedDigit())
    .fixedSize()                                                // never truncated
    .accessibilityLabel(Text("^[\(followers) follower](inflect: true)"))

Text("^[\(followers) follower](inflect: true)")                 // "1 follower", "1,284 followers"

Text(balance, format: .currency(code: "EUR"))                   // "1.234,56 €" in de_DE
    .monospacedDigit()

Text("Balance: \(balance, format: .currency(code: "EUR"))")     // formatted inside a sentence

Text("Since \(year, format: .number.grouping(.never))")        // "Since 2026"; or Text(verbatim: String(year))

if let expiry {                                                 // expiry: Date?
    Text("Expires \(expiry, format: .dateTime.day().month().year())")
} else {
    Text("Never expires")
}

Text(lastSeen, format: .relative(presentation: .named))         // "yesterday", "in 2 days"
```

Rules:

- **Numbers that don't fit** follow the never-truncate rule in [SKILL.md (Fix order)](../SKILL.md#fix-order): compact notation, a stacked layout, or a smaller text style via `ViewThatFits` ([§18](#18-minimumscalefactor-the-last-resort)). Compact notation drops precision, so use it for counts, not money.
- **Plurals.** `^[…](inflect: true)` (automatic grammar agreement) handles English and the other languages Foundation supports for it; String Catalog plural variants handle every language, including Polish and Russian with more than two forms. If the design stacks the number over a separate label, pass the count to the label's String Catalog entry and vary it by plural; a label that never sees the number can't agree with it.
- **Percentages:** `.percent` so `0.999` becomes "99.9%" by the locale's rules, not a hand-rounded "100%". Clamp custom progress fills to `0...1` before drawing.
- **Badges:** cap the display ("99+") or use compact notation, and give VoiceOver the full count with `.accessibilityLabel`.
- **Counts that can't be negative** (`unread: -3` after a race, a `-1` "hidden" sentinel): a negative count is a data bug. Hide the badge or clamp the display (`max(count, 0)`), model "hidden" as `nil`, and report the source.
- **Huge and non-finite values.** `Int.max` formats as `9,223,372,036,854,775,807` (25 characters) or, compact, `9,223,372T`, so check the widest column still holds it. `count + 1` traps at `Int.max`, and `Int(value)` traps on `nan`, infinity and anything out of range; format the `Double` directly, or guard with `value.isFinite` first.
- **Signs after rounding.** A balance of `-0.001` formats as `-€0.00`, and `-0.0` as a percent as `-0%`. Choose the colour and sign from the value as displayed (rounded to the currency's digits), not the raw value; `ContactRow` in [§12](#12-worked-example-a-hardened-row) does this with `NSDecimalRound`.
- **Animated number changes** (`.contentTransition(.numericText(value:))`) are a motion decision: use swift-motion-animate.

## 7. Optional, nil and empty fields

**Break:** a force unwrap crashes on `nil`; `"Optional(\"anna@example.com\")"`, `"nil"`, a dangling `" · yesterday"`, or a blank line that keeps its spacing.

```swift
// Before
Text(user.bio!)                                  // crashes when bio is nil
Text("\(contact.email ?? "") · \(lastSeenText)")   // lastSeenText: String
```

**Fix:** bind optionals; treat `""` and whitespace like `nil`; join only the parts that exist.

```swift
// After — defines String?.nonBlank (reused in §12). private: lives in the file being fixed.
import Foundation

private extension Optional where Wrapped == String {
    /// nil, "", and whitespace-only all count as missing.
    var nonBlank: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
```

```swift
// Needs nonBlank (block above).
if let bio = user.bio.nonBlank {
    Text(bio).font(.footnote)
}

// lastSeenText is a plain String; wrap it to reuse nonBlank.
let details = [contact.email.nonBlank, Optional(lastSeenText).nonBlank].compactMap { $0 }
if !details.isEmpty {
    Text(details.joined(separator: " · "))
        .foregroundStyle(.secondary)
}
```

Trimming catches spaces, tabs, newlines and zero-width spaces, but not invisible fillers that Unicode classes as letters, such as `ㅤ` (U+3164 Hangul Filler), a common trick for a "blank" display name. Catch those where names are validated (server or sign-up form), not in every view; in the report, list the field as Fragile.

For a missing name, show a designed fallback ("Unnamed contact") rather than an empty row, and keep the row's height consistent with its neighbours. Replace `items[0]` / `items.first!` with `if let first = items.first`.

## 8. Images

**Break:** `AsyncImage(url:content:placeholder:)` keeps showing its placeholder after a 404, for a `nil` URL, and when the server answers with something that isn't an image (an HTML error or captive-portal page with status 200, an SVG), so a `ProgressView` placeholder spins forever; `.resizable()` alone squashes a panorama into a circle; a late image makes the row jump.

```swift
// Before
AsyncImage(url: user.avatarURL) { image in
    image.resizable()
} placeholder: {
    ProgressView()
}
.frame(width: 64, height: 64)
.clipShape(Circle())
```

**Fix:** a fixed frame that doesn't depend on the image, every phase handled, initials as the fallback, and `nil` handled before `AsyncImage`. A non-image response lands in `.failure` like a 404. Defines `Avatar` and `InitialsAvatar` (reused in [§12](#12-worked-example-a-hardened-row)); both are `private`, so paste them into the file of the row being fixed.

```swift
import SwiftUI

private struct Avatar: View {
    let name: String
    let url: URL?
    let size: CGFloat

    var body: some View {
        Color.clear
            .frame(width: size, height: size)          // layout never depends on the image
            .overlay { content }
            .clipShape(.circle)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()   // fills, then gets clipped: no squashing
                case .empty:
                    Circle().fill(.quaternary)
                case .failure:
                    InitialsAvatar(name: name)
                @unknown default:
                    InitialsAvatar(name: name)
                }
            }
        } else {
            InitialsAvatar(name: name)
        }
    }
}

private struct InitialsAvatar: View {
    let name: String

    var body: some View {
        ZStack {
            Circle().fill(.tint.opacity(0.2))
            if let initials {
                Text(initials).font(.headline).lineLimit(1).minimumScaleFactor(0.5)
            } else {
                Image(systemName: "person.fill").font(.headline)
            }
        }
        .foregroundStyle(.tint)
    }

    /// Grapheme-safe initials from the person-name parser; nil falls back to a symbol.
    private var initials: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.first?.isLetter == true,
              let components = PersonNameComponentsFormatter().personNameComponents(from: trimmed)
        else { return nil }
        let result = components.formatted(.name(style: .abbreviated))
        return result.isEmpty ? nil : result
    }
}
```

The `minimumScaleFactor` on initials is one of its few legitimate uses: two decorative letters inside a fixed circle ([§18](#18-minimumscalefactor-the-last-resort)). What this produces for the catalog names: "Christopher Alexander Montgomery III" → `CM`, "dana" → `D`, "Jo" → `J` (one letter for a one-word name is correct), "María José de la Cruz y Fernández" → `MD` (decide whether that's acceptable for your users). A name that starts with an emoji or symbol, and Arabic and Hebrew names, get the person symbol instead of initials.

More image fixes:

- **Image decode cost in lists.** An image is decoded to a bitmap of width × height × 4 bytes, whatever its file size: a 12 MP camera photo (4032×3024) is about 48 MB in memory, even when it's shown in a 44 pt circle. Twenty of those in a list is close to a gigabyte, and each decode can drop frames while scrolling. Downsample to the display size before showing it, for example `await image.byPreparingThumbnail(ofSize:)`, which does the work off the main thread, and keep the thumbnails in a small cache (`NSCache`) so rows that scroll back don't decode again. `AsyncImage` never downsamples. Before iOS 27, don't count on it to cache for list performance; from iOS 27 it caches downloaded data following HTTP caching rules, and you can set the policy through `AsyncImage(request:)` or pass a session with `.asyncImageURLSession(_:)` **(iOS 27)**. Caching the data still leaves the decode on every display.
- **Animated GIFs** show only their first frame in `Image` and `AsyncImage`; if animation matters, that is a decision for the user, not a layout fix.
- **Dark artwork on transparency:** a template image with `.foregroundStyle(.primary)`, a dark-appearance asset, or a contrasting plate.
- **Photos under Smart Invert:** `.accessibilityIgnoresInvertColors()`.

## 9. Empty, loading, error and offline states

**Break:** an empty list is a blank screen; a fast load flashes a spinner; an error shows nothing and offers no way out.

**Fix:** design every state and drive them from the model. Defines `LoadState`, `Contact.placeholders`, `ContactList`, `ContactListScreen`, `DelayedLoading`. Needs `Contact` ([preview-harness.md §1](preview-harness.md#1-fixtures-enum)) and `ContactRow` ([§12](#12-worked-example-a-hardened-row)).

```swift
import SwiftUI

enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed(String)
}

extension Contact {
    /// Shapes for the redacted loading state: the same rows as real data.
    static let placeholders: [Contact] = (0..<6).map { i in
        Contact(id: -1 - i, name: "Placeholder Name", email: "placeholder@example.com",
                avatarURL: nil, unreadCount: 0, balance: 0, lastSeen: nil)
    }
}

struct ContactList: View {
    let contacts: [Contact]

    var body: some View {
        if contacts.isEmpty {
            ContentUnavailableView(
                "No Contacts",
                systemImage: "person.2",
                description: Text("Contacts you add appear here.")
            )
        } else {
            List(contacts) { ContactRow(contact: $0) }
        }
    }
}

struct ContactListScreen: View {
    let state: LoadState<[Contact]>
    var retry: () async -> Void = {}

    var body: some View {
        switch state {
        case .loading:
            List(Contact.placeholders) { ContactRow(contact: $0) }
                .redacted(reason: .placeholder)        // same shape as the loaded layout
                .disabled(true)
        case .failed(let message):
            ContentUnavailableView {
                Label("Can't Load Contacts", systemImage: "wifi.slash")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await retry() } }
            }
        case .loaded(let contacts):
            ContactList(contacts: contacts)
        }
    }
}

/// For waits whose result layout isn't known. The spinner appears only after `delay`,
/// so fast loads never flash one; once shown it stays at least `minimumVisible`,
/// so it never blinks on and off. Content shows once loading ends and the hold is over.
struct DelayedLoading<Content: View>: View {
    let isLoading: Bool
    var delay: Duration = .milliseconds(300)
    var minimumVisible: Duration = .milliseconds(400)
    @ViewBuilder var content: Content

    @State private var showsSpinner = false
    @State private var spinnerSince: ContinuousClock.Instant?

    var body: some View {
        Group {
            if showsSpinner {
                ProgressView()
            } else if isLoading {
                Color.clear                            // the delay: nothing yet
            } else {
                content
            }
        }
        .task(id: isLoading) {
            do {
                if isLoading {
                    try await Task.sleep(for: delay)
                    showsSpinner = true
                    spinnerSince = .now
                } else if let since = spinnerSince {
                    try await Task.sleep(until: since + minimumVisible)
                    showsSpinner = false
                    spinnerSince = nil
                }
            } catch {}                                 // cancelled: isLoading changed again
        }
    }
}
```

- Delay a spinner by 150–300 ms, and once it's visible keep it up for at least 300–500 ms, so it doesn't blink on and off. `DelayedLoading` does both (300 ms, 400 ms). These numbers are a widely used guideline, not an Apple rule; cite them as such.
- `ContentUnavailableView` is usually the best fix for a hand-built empty or error view: it handles Dynamic Type, dark mode and VoiceOver. Recommend it, and also give the minimal fix for teams that keep their own view: show it for every empty and failed case, put it in a `ScrollView` so it stays reachable at AX5, and give it the action the system view would have ("Try Again", "Add Contact").
- For search, use `ContentUnavailableView.search(text: query)`.
- Show a human error message, never `error.localizedDescription` from a networking layer verbatim.
- Offline: keep showing cached content with a small, clear indication (a banner or a footer line) instead of replacing the screen with an error.
- On retry, disable the button while the request is in flight, so a double tap doesn't send two.
- How the states animate into each other is a motion question: swift-motion-animate.

## 10. Right-to-left

**Break:** chevrons point the wrong way; a custom arrow image doesn't flip; a panel slides in from the wrong edge; a view pinned with `.position(x:)` stays on the left. SwiftUI's `.leading`/`.trailing` alignment and padding already flip; absolute x values and artwork don't.

```swift
// Before
Image(systemName: "chevron.right")
Image("arrow-right")
panel.offset(x: isOpen ? 0 : -320)
```

```swift
// After
Image(systemName: "chevron.forward")                  // directional symbols flip automatically
Image("arrow-forward")
    .flipsForRightToLeftLayoutDirection(true)          // custom directional artwork
panel.transition(.move(edge: .leading))               // .move(edge:) flips; .offset(x:) doesn't
```

Text stuck to the left in Arabic means something forced the direction: an `.environment(\.layoutDirection, .leftToRight)` higher up, or `.left` / `NSTextAlignment.left` in a bridged UIKit view. Use natural alignment there.

Also check:

- Remaining `.offset(x:)` values and custom drawing (`Path`, `Canvas`): decide whether each should follow the reading direction, then confirm in the RTL preview.
- Images that must **not** flip (logos, photos, a clock, media playback controls) stay unflipped.
- Mixed-direction strings (an Arabic sentence containing an order ID, a phone number) still read correctly. Test with real RTL fixtures, not only the flipped layout.

## 11. Dark mode, contrast, transparency and Bold Text

**Dark mode.** Hardcoded colours are the usual cause.

```swift
// Before
.foregroundStyle(Color.black)
.background(Color.white)

// After
.foregroundStyle(.primary)
.background(.background)
```

For brand colours, add a Dark appearance in the asset catalog rather than branching in code.

**Increase Contrast.** `.secondary`/`.tertiary` text on a tinted background and hairline separators fade out. Add High Contrast appearances to custom colours in the asset catalog. For custom strokes, read the setting:

```swift
@Environment(\.colorSchemeContrast) private var contrast

RoundedRectangle(cornerRadius: 12)
    .strokeBorder(.separator, lineWidth: contrast == .increased ? 2 : 1)
```

**Reduce Transparency.** System materials turn solid on their own; your custom translucent colours stay translucent. Make them solid when the setting is on:

```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

Text(caption)
    .foregroundStyle(.white)
    .padding(8)
    .background(Color.black.opacity(reduceTransparency ? 1 : 0.45))
```

**Liquid Glass (iOS 26).** Standard glass adapts to Reduce Transparency and Increase Contrast by itself. What you put on it doesn't: check custom tints, secondary text and thin icons over both light and dark content, don't stack glass on glass, and tint only primary actions.

**Bold Text.** System text styles become bold on their own; the wider text can truncate in tight rows, so re-run the worst-case preview with `.environment(\.legibilityWeight, .bold)`. Custom fonts need an explicit switch:

```swift
@Environment(\.legibilityWeight) private var legibilityWeight

Text(title)
    .font(.custom(legibilityWeight == .bold ? "BrandSans-Bold" : "BrandSans-Regular",
                  size: 17, relativeTo: .body))
```

**Selection that changes width.** A tab, chip or segment that turns bold when selected widens and shoves its neighbours. Show selection with colour or opacity only, or give the item a fixed width; put badges in an `.overlay` so they don't take layout space.

## 12. Worked example: a hardened row

The `ContactRow` the harness previews. It survives every fixture in `ContactFixtures.worstCase`: long and blank names, unbreakable emails, failing images (including a URL that returns a web page), negative millions, a five-digit badge, a negative unread count, a combining-mark name, RTL, and AX5 at 320 pt. Needs `Contact` ([preview-harness.md §1](preview-harness.md#1-fixtures-enum)) and, in the same file because they're `private`, `Avatar` and `InitialsAvatar` ([§8](#8-images)) and `String?.nonBlank` ([§7](#7-optional-nil-and-empty-fields)).

```swift
import SwiftUI

struct ContactRow: View {
    let contact: Contact
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 44

    var body: some View {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize
        let layout = isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))   // top: names may wrap

        layout {
            Avatar(name: contact.name, url: contact.avatarURL, size: avatarSize)

            VStack(alignment: .leading, spacing: 2) {
                displayName
                    .font(.headline)
                    .lineLimit(2)
                if let email = contact.email.nonBlank {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .layoutPriority(1)

            if !isAccessibilitySize {
                Spacer(minLength: 8)
            }

            VStack(alignment: isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                Text(displayedBalance, format: .currency(code: "EUR"))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(displayedBalance < 0 ? Color.red : Color.primary)
                    // Whole in a row; allowed to wrap when stacked. Never truncated.
                    .fixedSize(horizontal: !isAccessibilitySize, vertical: false)
                if contact.unreadCount > 0 {           // a negative count is a data bug: no badge
                    UnreadBadge(count: contact.unreadCount)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// Rounded to cents before formatting and colouring, so -0.001 reads "€0.00", not a red "-€0.00".
    private var displayedBalance: Decimal {
        var raw = contact.balance
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .plain)
        return rounded
    }

    /// A Text, not a String: the literal fallback is a LocalizedStringKey, so it
    /// follows `\.locale` in previews; `String(localized:)` would use the process language.
    private var displayName: Text {
        if let name = Optional(contact.name).nonBlank {
            Text(name)                                 // user data: verbatim
        } else {
            Text("Unnamed contact")
        }
    }
}

private struct UnreadBadge: View {
    let count: Int

    var body: some View {
        Text(count, format: .number.notation(.compactName))   // 12,345 → "12K"
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.tint, in: .capsule)
            .fixedSize()
            .accessibilityLabel(Text("^[\(count) unread message](inflect: true)"))
    }
}
```

## 13. Keyboard

**Break:** the focused field or the primary button sits behind the keyboard; `.ignoresSafeArea()` on the container stops keyboard avoidance.

```swift
// Before
VStack {
    form
    Spacer()
    Button("Continue") { submit() }
}
.ignoresSafeArea()
```

**Fix:** put the form in a `ScrollView`, pin the button with `safeAreaInset` so it rides above the keyboard, and let only the background ignore the safe area.

```swift
// After
ScrollView {
    form.padding()
}
.scrollDismissesKeyboard(.interactively)
.safeAreaInset(edge: .bottom) {
    Button { submit() } label: {
        Text("Continue").frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .padding()
    .background(.bar)
}
.background { BrandGradient().ignoresSafeArea() }     // decoration only
```

Use `@FocusState` with `.onSubmit` to move focus to the next field, so the user is never stuck behind the keyboard. Don't imitate the keyboard's motion with notifications and a timing curve; let safe-area avoidance follow the real keyboard.

## 14. Large collections

**Break:** 10,000 items in `ScrollView { VStack { ForEach } }` build every row up front; sorting or formatting inside `body` runs on every update.

```swift
// Before
ScrollView {
    VStack {
        ForEach(items.sorted { $0.date > $1.date }) { ItemRow(item: $0) }
    }
}
```

**Fix:** a lazy container, sorted once outside `body`, stable ids.

```swift
// After
List(sortedItems) { ItemRow(item: $0) }               // or ScrollView { LazyVStack { … } }
```

`sortedItems` is computed when the data changes (in the model), not in `body`. No `.onAppear` entrance animations on rows, no `AnyView` in hot rows. A preview shows that 10,000 rows render, not that they scroll smoothly: check on a device in a release build, and profile with Instruments' SwiftUI template when it stutters. Decide whether the list paginates or just stays lazy, and say which.

## 15. Emoji and complex scripts

**Break:** initials or character limits split "👩🏽‍💻" into broken pieces, because the code counts UTF-16 units instead of characters.

```swift
// Before
let initial = (name as NSString).substring(to: 1)     // splits a ZWJ sequence or a flag
if (text as NSString).length > 40 { trim() }
```

**Fix:** use `Character`-based APIs, which work on user-perceived characters.

```swift
// After
let initial = name.first.map(String.init) ?? ""

TextField("Display name", text: $displayName)
    .onChange(of: displayName) { _, newValue in
        if newValue.count > 40 {
            displayName = String(newValue.prefix(40))
        }
    }
```

If a server limit is in bytes or UTF-16 units, enforce that unit in validation, but show the user a count in characters.

**Thai, Vietnamese, Devanagari, Arabic, CJK:** marks above and below the line need vertical room. Remove fixed heights and `.clipped()` from text containers ([§3](#3-fixed-heights-that-clip-screens-that-dont-scroll)), and don't tighten line spacing below the default. When user content is in a script the UI language doesn't expect (Thai names in an English app), tell the text which language it is, so line height and breaking fit it:

```swift
Text(contact.name)
    .typesettingLanguage(Locale.Language(identifier: "th"))   // iOS 17
```

**Stacked combining marks ("Zalgo" text).** Users paste names like `Z̷̢̛͖a̴͙͝l̶̰̾g̷̱̈o̵̪͝` into display-name fields: five characters, 21 Unicode scalars, 37 UTF-8 bytes. The marks draw far above and below the line and over neighbouring rows. Don't clip text to contain them, because the same clip cuts real Thai and Vietnamese. Leave the row unclipped, check that the overdraw doesn't cover a control, and if it does, limit combining marks per character where the name is validated. A length limit counted in characters lets 37 bytes through as "5"; one counted in bytes rejects a short Vietnamese name, so decide which the server enforces.

**Direction-override characters.** A file name such as `"invoice\u{202E}fdp.exe"` displays as `invoiceexe.pdf`. Where users trust a name to tell them what a file is, show the real type separately (an icon or label from the actual extension's `UTType`) rather than relying on how the name appears to end.

## 16. User content rendered as markup

**Break:** a user-supplied string reaches `Text(LocalizedStringKey(userString))` or `AttributedString(markdown:)`, so `**bold**` turns bold, `[tap here](https://…)` becomes a tappable link, and the string is looked up as a localization key.

**Fix:** render user content verbatim. `Text(someString)` with a `String` variable is already verbatim; `Text(verbatim:)` makes it explicit. Keep `LocalizedStringKey` for your own localized copy.

```swift
Text(verbatim: comment.body)
```

## 17. Tap targets

**Break:** the name "J" is the only tappable part of a row; an icon button at `.xSmall` shrinks below a usable size; at AX5 two buttons overlap.

**Fix:** keep every target at least 44×44 pt, enlarge the hit area with `.contentShape`, not the visual, and let rows stack before buttons collide ([§4](#4-layout-that-should-change-at-large-sizes)).

```swift
Button { toggleFavorite() } label: {
    Image(systemName: isFavorite ? "star.fill" : "star")
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
}
.accessibilityLabel(Text("Favorite"))
```

## 18. `minimumScaleFactor`, the last resort

It shrinks text exactly when the user has asked for it to be bigger, so try a layout change first. For a hero amount, step down through text styles with `ViewThatFits`; each option still follows Dynamic Type:

```swift
ViewThatFits(in: .horizontal) {
    Text(total, format: .currency(code: "EUR")).font(.largeTitle.bold())
    Text(total, format: .currency(code: "EUR")).font(.title.bold())
    Text(total, format: .currency(code: "EUR")).font(.title3.bold())   // last option wraps if it must
}
.monospacedDigit()
```

Use `minimumScaleFactor` only on a single short line where shrinking can't hide meaning, such as initials in a fixed circle or a decorative word in a fixed-size chip, and keep the factor mild:

```swift
Text(chipTitle)
    .lineLimit(1)
    .minimumScaleFactor(0.8)   // never on numbers, amounts or body text
```
