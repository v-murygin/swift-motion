# Preview harness

Reusable `#Preview` code for stress-testing a view. Copy the parts you need into the file that owns the view. Use a separate file only when the user asks for one or the project already keeps its previews or fixtures in their own files; then follow that convention. Everything here is iOS 17+ (Xcode 15+) unless marked.

The preview helpers (`DynamicTypeSweep`, `StressGallery`, `StressVariant`) are `private`, so each view file can carry the ones it uses without clashing with another file's copy.

**Keep fixtures and the previews that use them under the same `#if DEBUG`.** `#Preview` bodies are still compiled in Release builds, so a preview that references a DEBUG-only fixture breaks the Release build. The previews below are shown without the wrapper for readability; wrap them.

The example subject is a `ContactRow` showing a `Contact`, plus a `ContactList` and a `ContactListScreen`. Their hardened versions are in [fixes.md §12](fixes.md#12-worked-example-a-hardened-row) (`ContactRow`, which also needs the private `Avatar` from [fixes.md §8](fixes.md#8-images) and `nonBlank` from [fixes.md §7](fixes.md#7-optional-nil-and-empty-fields) in its file) and [fixes.md §9](fixes.md#9-empty-loading-error-and-offline-states) (`LoadState`, `ContactList`, `ContactListScreen`). Swap in your own view and model; keep the structure.

## Contents

1. [Fixtures enum](#1-fixtures-enum)
2. [Named previews: the test plan](#2-named-previews-the-test-plan)
3. [Dynamic Type sweep](#3-dynamic-type-sweep)
4. [Variant gallery](#4-variant-gallery)
5. [Fixture switcher with `@Previewable`](#5-fixture-switcher-with-previewable)
6. [Shared variants with `PreviewModifier` (iOS 18)](#6-shared-variants-with-previewmodifier-ios-18)
7. [State previews: loading, error, empty](#7-state-previews-loading-error-empty)
8. [What previews can't set, and where to test it instead](#8-what-previews-cant-set-and-where-to-test-it-instead)

---

## 1. Fixtures enum

Fixtures enter through the same initializer as the demo data. The different failures are spread across the first rows of `worstCase`, so they're on screen at once, as real data would be.

```swift
import Foundation

struct Contact: Identifiable, Hashable {
    let id: Int
    var name: String
    var email: String?
    var avatarURL: URL?
    var unreadCount: Int
    var balance: Decimal
    var lastSeen: Date?
}

#if DEBUG
enum ContactFixtures {
    static let demo = Contact(
        id: 0, name: "Anna Weber", email: "anna@example.com", avatarURL: nil,
        unreadCount: 3, balance: Decimal(string: "42.50")!, lastSeen: .now
    )

    /// A small, kind, realistic list: the baseline every fix is re-checked against.
    static let demoList = [
        demo,
        Contact(id: 10, name: "Ben Carter", email: "ben@example.com", avatarURL: nil,
                unreadCount: 0, balance: Decimal(string: "18.00")!, lastSeen: .now),
        Contact(id: 11, name: "Chiara Rossi", email: "chiara@example.com", avatarURL: nil,
                unreadCount: 12, balance: Decimal(string: "-7.25")!, lastSeen: nil),
        Contact(id: 12, name: "David Kim", email: nil, avatarURL: nil,
                unreadCount: 1, balance: 250, lastSeen: .now),
    ]

    static let longEverything = Contact(
        id: 1,
        name: "Aleksandra Wiśniewska-Kowalczyk",
        email: "bartholomew.fitzgerald@northwind-industries-holdings.example.com",
        avatarURL: URL(string: "https://example.com/missing.jpg"),     // 404
        unreadCount: 12_345,
        balance: Decimal(string: "-1234567.89")!,
        lastSeen: Date(timeIntervalSince1970: 0)
    )

    static let minimal = Contact(
        id: 2, name: "Jo", email: nil, avatarURL: nil,
        unreadCount: 0, balance: 0, lastSeen: nil
    )

    static let blank = Contact(
        id: 3, name: "   ", email: "", avatarURL: nil,
        unreadCount: 1, balance: 0, lastSeen: nil
    )

    static let arabic = Contact(
        id: 4, name: "محمد بن عبد الله العتيبي", email: "m.alotaibi@example.com", avatarURL: nil,
        unreadCount: 7, balance: Decimal(string: "1500")!,
        lastSeen: Calendar.current.date(byAdding: .day, value: -1, to: .now)
    )

    static let scripts = Contact(
        id: 5, name: "👩🏽‍💻 Đặng Thị Ngọc Hân", email: "first.last+billing-notifications@example.com",
        avatarURL: nil, unreadCount: 100, balance: Decimal(string: "0.000123")!,
        lastSeen: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2099, month: 12, day: 31))
    )

    static let cjk = Contact(
        id: 6, name: "王秀英", email: "a@b.co", avatarURL: nil,
        unreadCount: 9, balance: Decimal(string: "12345678.9")!, lastSeen: .now
    )

    /// Values that come from bugs and bad actors, not typing: combining-mark name,
    /// a URL that returns a web page instead of an image, a count gone negative.
    static let hostile = Contact(
        id: 7,
        name: "Z\u{0337}\u{0322}\u{031B}\u{0356}a\u{0334}\u{0359}\u{035D}l\u{0336}\u{0330}\u{033E}g\u{0337}\u{0331}\u{0308}o\u{0335}\u{032A}\u{035D}",
        email: nil,
        avatarURL: URL(string: "https://example.com/"),                // HTML, status 200
        unreadCount: -3, balance: Decimal(string: "-0.001")!, lastSeen: nil
    )

    /// Different failures in the first rows, so the preview shows them without scrolling.
    static let worstCase = [longEverything, minimal, blank, arabic, scripts, cjk, hostile]

    /// Deterministic, not random: cycles through the worst cases with unique ids.
    static func many(_ count: Int) -> [Contact] {
        (0..<count).map { i in
            let base = worstCase[i % worstCase.count]
            return Contact(
                id: 1_000 + i, name: base.name, email: base.email, avatarURL: base.avatarURL,
                unreadCount: base.unreadCount, balance: base.balance, lastSeen: base.lastSeen
            )
        }
    }
}
#endif
```

**A fixture that crashes the view** (a `nil` behind a force unwrap) still belongs in the set. Give it its own named preview, `"nil bio (crashes until fixed)"`, so the other previews keep rendering and the crash is visible as a regression test. Report it from the code as well, because a crashed preview shows a diagnostic, not the layout.

## 2. Named previews: the test plan

Named previews make the canvas read as a test plan (Xcode 15+). Keep `"Demo"` first so the normal case is always one click away; every fix is re-checked against it.

```swift
import SwiftUI

#Preview("Demo", traits: .sizeThatFitsLayout) {
    ContactRow(contact: ContactFixtures.demo)
        .padding()
}

#Preview("Worst case") {
    List(ContactFixtures.worstCase) { ContactRow(contact: $0) }
}

#Preview("Empty") {
    NavigationStack { ContactList(contacts: []) }
}

#Preview("One") {
    NavigationStack { ContactList(contacts: [ContactFixtures.demo]) }
}

#Preview("10,000 rows") {
    NavigationStack { ContactList(contacts: ContactFixtures.many(10_000)) }
}

#Preview("AX5 at 320 pt", traits: .fixedLayout(width: 320, height: 900)) {
    List(ContactFixtures.worstCase) { ContactRow(contact: $0) }
        .dynamicTypeSize(.accessibility5)
}

#Preview("RTL Arabic", traits: .sizeThatFitsLayout) {
    ContactRow(contact: ContactFixtures.arabic)
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
}

#Preview("de_DE amounts", traits: .sizeThatFitsLayout) {
    ContactRow(contact: ContactFixtures.longEverything)
        .padding()
        .environment(\.locale, Locale(identifier: "de_DE"))
}

#Preview("Dark + Bold Text") {
    List(ContactFixtures.worstCase) { ContactRow(contact: $0) }
        .environment(\.legibilityWeight, .bold)
        .preferredColorScheme(.dark)
}

#Preview("iPhone SE size", traits: .fixedLayout(width: 375, height: 667)) {
    NavigationStack { ContactList(contacts: ContactFixtures.worstCase) }
}

#Preview("Landscape", traits: .landscapeLeft) {
    NavigationStack { ContactList(contacts: ContactFixtures.worstCase) }
}

#Preview("iPad split column", traits: .fixedLayout(width: 320, height: 800)) {
    NavigationStack { ContactList(contacts: ContactFixtures.worstCase) }
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("Far time zone", traits: .sizeThatFitsLayout) {
    ContactRow(contact: ContactFixtures.longEverything)
        .padding()
        .environment(\.timeZone, TimeZone(identifier: "Pacific/Kiritimati")!)   // UTC+14
}
```

Xcode's canvas also has a **Variants** mode (Color Scheme, Orientation and Dynamic Type variants) that renders one preview under every value at once. Use it for a quick sweep; keep the named previews as the record.

## 3. Dynamic Type sweep

Every size from `.xSmall` to `.accessibility5`, stacked, at one width. A faint border shows the view's real bounds, so clipping and overflow are visible. Self-contained.

```swift
#if DEBUG
import SwiftUI

private struct DynamicTypeSweep<Content: View>: View {
    var width: CGFloat = 375
    var sizes: [DynamicTypeSize] = DynamicTypeSize.allCases
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(sizes, id: \.self) { size in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "\(size) · \(Int(width)) pt")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .dynamicTypeSize(.large)            // label stays readable
                        content
                            .frame(width: width, alignment: .leading)
                            .dynamicTypeSize(size)
                            .border(Color.red.opacity(0.4))
                    }
                }
            }
            .padding()
        }
    }
}
#endif
```

```swift
// Same file as DynamicTypeSweep (block above). Needs ContactFixtures (§1), ContactRow (fixes.md §12).
#Preview("Type sweep · 320 pt") {
    DynamicTypeSweep(width: 320) {
        ContactRow(contact: ContactFixtures.longEverything)
    }
}
```

## 4. Variant gallery

One preview that stacks the same view under every environment, each with a label. Labels sit outside the stressed environment so they stay readable. Self-contained.

```swift
#if DEBUG
import SwiftUI

private enum StressVariant: String, CaseIterable, Identifiable {
    case standard = "Large (default)"
    case xSmall = "xSmall"
    case xxxLarge = "xxxLarge"
    case accessibility5 = "accessibility5"
    case boldText = "Bold Text"
    case dark = "Dark"
    case rightToLeft = "RTL (ar)"
    case german = "de_DE"

    var id: Self { self }
}

private struct StressVariantModifier: ViewModifier {
    let variant: StressVariant

    @ViewBuilder
    func body(content: Content) -> some View {
        switch variant {
        case .standard:
            content
        case .xSmall:
            content.dynamicTypeSize(.xSmall)
        case .xxxLarge:
            content.dynamicTypeSize(.xxxLarge)
        case .accessibility5:
            content.dynamicTypeSize(.accessibility5)
        case .boldText:
            content.environment(\.legibilityWeight, .bold)
        case .dark:
            content.environment(\.colorScheme, .dark)
        case .rightToLeft:
            content
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
        case .german:
            content.environment(\.locale, Locale(identifier: "de_DE"))
        }
    }
}

private struct StressGallery<Content: View>: View {
    var width: CGFloat = 375
    var variants: [StressVariant] = StressVariant.allCases
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(variants) { variant in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "\(variant.rawValue) · \(Int(width)) pt")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        content
                            .frame(width: width, alignment: .leading)
                            // Keep .background inside the variant modifier so it resolves in the
                            // stressed environment; outside it, Dark draws white text on white.
                            .background(.background)
                            .modifier(StressVariantModifier(variant: variant))
                            .border(Color.red.opacity(0.4))
                    }
                }
            }
            .padding()
        }
    }
}
#endif
```

```swift
// Same file as StressGallery (block above). Needs ContactFixtures (§1), ContactRow (fixes.md §12).
#Preview("Gallery · long contact") {
    StressGallery {
        ContactRow(contact: ContactFixtures.longEverything)
    }
}

#Preview("Gallery · 320 pt, type sizes only") {
    StressGallery(width: 320, variants: [.standard, .xxxLarge, .accessibility5]) {
        ContactRow(contact: ContactFixtures.longEverything)
    }
}
```

The RTL variant only mirrors layout. Pair it with an RTL fixture (`ContactFixtures.arabic`) to also test the strings.

## 5. Fixture switcher with `@Previewable`

The dev-only **Demo / Worst case** toggle: a segmented picker in the live canvas that swaps the dataset at the data boundary, with extra segments for Empty, One and 10,000 rows. It lives in a preview, so it can never ship. `@Previewable` needs Xcode 16; it works with an iOS 17 deployment target.

Switching is instant: animation is turned off so each switch shows the final layout, not a transition that hides a jump.

```swift
// Needs ContactFixtures (§1), ContactList (fixes.md §9), ContactRow (fixes.md §12).
#if DEBUG
import SwiftUI

enum ContactDataset: String, CaseIterable, Identifiable {
    case demo = "Demo"
    case worst = "Worst case"
    case empty = "Empty"
    case one = "One"
    case huge = "10,000"

    var id: Self { self }

    var contacts: [Contact] {
        switch self {
        case .demo: ContactFixtures.demoList
        case .worst: ContactFixtures.worstCase
        case .empty: []
        case .one: [ContactFixtures.demo]
        case .huge: ContactFixtures.many(10_000)
        }
    }
}

#Preview("Switcher") {
    @Previewable @State var dataset: ContactDataset = .worst
    NavigationStack {
        ContactList(contacts: dataset.contacts)
            .safeAreaInset(edge: .bottom) {
                Picker("Dataset", selection: $dataset) {
                    ForEach(ContactDataset.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(.bar)
            }
    }
    .transaction { $0.animation = nil }
}
#endif
```

## 6. Shared variants with `PreviewModifier` (iOS 18)

A `PreviewModifier` packages an environment once and applies it as a trait, so every view in the project reuses the same worst case. It's project-wide by design, so add it when the project already shares preview setup or the user wants it; otherwise the per-file previews above do the same job. With an iOS 18+ deployment target, drop the `@available` lines.

```swift
// Needs ContactFixtures (§1), ContactRow (fixes.md §12).
#if DEBUG
import SwiftUI

@available(iOS 18.0, *)
struct AccessibilityWorstCase: PreviewModifier {
    func body(content: Content, context: Void) -> some View {
        content
            .dynamicTypeSize(.accessibility5)
            .environment(\.legibilityWeight, .bold)
    }
}

@available(iOS 18.0, *)
struct RightToLeftArabic: PreviewModifier {
    func body(content: Content, context: Void) -> some View {
        content
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
    }
}

@available(iOS 18.0, *)
extension PreviewTrait where T == Preview.ViewTraits {
    static var accessibilityWorstCase: Self { .modifier(AccessibilityWorstCase()) }
    static var rightToLeftArabic: Self { .modifier(RightToLeftArabic()) }
}

@available(iOS 18.0, *)
#Preview("AX5 + Bold", traits: .accessibilityWorstCase) {
    List(ContactFixtures.worstCase) { ContactRow(contact: $0) }
}

@available(iOS 18.0, *)
#Preview("RTL", traits: .rightToLeftArabic, .sizeThatFitsLayout) {
    ContactRow(contact: ContactFixtures.arabic).padding()
}
#endif
```

The trait properties are computed (`{ … }`) rather than stored, which keeps Swift 6 strict concurrency quiet about global mutable state.

## 7. State previews: loading, error, empty

Drive states through the same model the screen uses, never through flags added to the view for previews (that tests a different view).

```swift
// Needs LoadState and ContactListScreen (fixes.md §9), ContactFixtures (§1).
import SwiftUI

#Preview("Loading") {
    NavigationStack { ContactListScreen(state: .loading) }
}

#Preview("Failed · offline") {
    NavigationStack {
        ContactListScreen(state: .failed("You're offline. Check your connection and try again."))
    }
}

#Preview("Loaded · empty") {
    NavigationStack { ContactListScreen(state: .loaded([])) }
}

#Preview("Loaded · worst case") {
    NavigationStack { ContactListScreen(state: .loaded(ContactFixtures.worstCase)) }
}
```

## 8. What previews can't set, and where to test it instead

| Setting | In `#Preview` | Otherwise |
|---|---|---|
| Dynamic Type | `.dynamicTypeSize(.accessibility5)`, also `.xSmall`, `.xxxLarge` | Canvas Device Settings; `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large` |
| Bold Text | `.environment(\.legibilityWeight, .bold)` | Environment Overrides while running |
| Dark mode | `.preferredColorScheme(.dark)` | `xcrun simctl ui booted appearance dark` |
| RTL layout | `.environment(\.layoutDirection, .rightToLeft)` | Scheme ▸ App Language ▸ Right-to-Left Pseudolanguage |
| Locale (formatters) | `.environment(\.locale, Locale(identifier: "de_DE"))` | Scheme ▸ App Region; launch argument `-AppleLocale de_DE` |
| Time zone | `.environment(\.timeZone, TimeZone(identifier: "Pacific/Kiritimati")!)` | Simulator follows the Mac's time zone |
| Width / orientation | `traits: .fixedLayout(width:height:)`, `.landscapeLeft`, `.sizeThatFitsLayout` | Canvas device picker |
| Size class | `.environment(\.horizontalSizeClass, .compact)` | iPad Split View in the Simulator |
| Increase Contrast | **Not settable**: `colorSchemeContrast` is read-only | `xcrun simctl ui booted increase_contrast enabled`; Environment Overrides |
| Reduce Transparency | **Not settable**: `accessibilityReduceTransparency` is read-only | Environment Overrides; Simulator Settings ▸ Accessibility |
| Keyboard up | Not reliable | Simulator, I/O ▸ Keyboard ▸ Toggle Software Keyboard (⌘K) |
| Translated strings | Translated literals in fixtures; `Text("key")` follows `\.locale` | Scheme ▸ App Language; launch arguments `-AppleLanguages "(de)"`, `-NSDoubleLocalizedStrings YES` |
| Real Split View, Slide Over, free window resizing (iPadOS 26) | Approximate with `.fixedLayout(width: 320, …)` + compact size class | iPad Simulator |
| iPhone Duo poses (iOS 27.1) | Approximate the inner display with `.environment(\.horizontalSizeClass, .regular)` at a tablet-like width; the fold can't be previewed | iPhone Duo simulator posed closed, open and partly folded (Device Hub in Xcode); fold and unfold while the app runs |
| Always-On (widgets, Live Activities) | `.environment(\.isLuminanceReduced, true)` | Widget and Live Activity previews; a device with Always-On |
| Scrolling 10,000 rows | Shows that it renders, not that it scrolls smoothly | A device, release build; Instruments' SwiftUI template |

When a view branches on a read-only setting (`colorSchemeContrast == .increased`), the branch can still be previewed by passing the flag into a small subview as a parameter; the environment read stays in the parent.

Launch arguments go after the bundle id: `xcrun simctl launch booted com.example.app -AppleLanguages "(de)" -AppleLocale de_DE`.
