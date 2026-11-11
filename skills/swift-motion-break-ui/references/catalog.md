# Worst-case catalog

Realistic values that break SwiftUI views, grouped by what kind of value the view renders, then the environments to render them in. Use the rows that apply to the fields in your surface map (SKILL.md, step 1). Each value is something a real user could produce, or the longest value a backend would plausibly accept; the note says what it tends to break.

Use `example.com`, `example.org` or `.test` domains for emails and URLs, so the fixture never points at a real inbox or site.

Every Swift string below is also collected in the paste-ready `StressStrings` / `StressNumbers` / `StressDates` / `StressImages` block in [section 20](#20-fixture-constants).

## Contents

**Data**

1. [People and names](#1-people-and-names)
2. [Emails, URLs, identifiers (unbreakable strings)](#2-emails-urls-identifiers-unbreakable-strings)
3. [Labels, titles and copy from data](#3-labels-titles-and-copy-from-data)
4. [Optional, nil and empty fields](#4-optional-nil-and-empty-fields)
5. [Numbers](#5-numbers)
6. [Currency and locale formatting](#6-currency-and-locale-formatting)
7. [Pluralization](#7-pluralization)
8. [Collections](#8-collections)
9. [Dates and times](#9-dates-and-times)
10. [Images and media](#10-images-and-media)
11. [Emoji and complex scripts](#11-emoji-and-complex-scripts)
12. [States: loading, error, offline, partial](#12-states-loading-error-offline-partial)

**Environments**

13. [Localization expansion](#13-localization-expansion)
14. [Right-to-left](#14-right-to-left)
15. [Dynamic Type](#15-dynamic-type)
16. [Appearance and accessibility settings](#16-appearance-and-accessibility-settings)
17. [Device sizes, orientation, multitasking](#17-device-sizes-orientation-multitasking)
18. [Keyboard](#18-keyboard)
19. [Interaction edge cases](#19-interaction-edge-cases)
20. [Fixture constants](#20-fixture-constants)

---

## 1. People and names

| Value | Breaks |
|---|---|
| `Aleksandra Wiśniewska-Kowalczyk` | Long, hyphenated, diacritics; wraps to two lines, and the hyphen is a line-break point |
| `Christopher Alexander Montgomery III` | Long with a suffix; naive first + last initials give `CI` |
| `Konstantin Oberhauser-Wettstein` | Long and compound; overflows single-line rows |
| `Maximiliane Alexandra Oberhauser-Wittgensteiner` | 47 characters; pushes timestamps, badges and chevrons out of an `HStack` |
| `Jo` | Two letters; leaves the name column mostly empty. One initial (`J`) is correct; check the avatar still looks deliberate with one letter |
| `J` | One letter; single-character initials, a tiny tap target if the name itself is the button |
| `Ólafur Darri Ólafsson` | Leading accented capital; uppercase/sort logic, initials `ÓÓ` |
| `Đặng Thị Ngọc Hân` | Stacked Vietnamese diacritics; clipped by a fixed `.frame(height:)` or `.clipped()` |
| `王秀英` | CJK, no spaces; "first + last word" initials logic finds one word, and CJK breaks anywhere |
| `نور الهدى عبد الرحمن` | RTL; initials logic, and icons drawn at hard-coded x positions land on the wrong side |
| `Seán O'Brien-Ó Súilleabháin` | Apostrophe and accents; initials, search, escaping |
| `María José de la Cruz y Fernández` | Lowercase particles; naive initials give `Md` or `MF`, `PersonNameComponents` gives `MD`; sorting by "last name" |
| `dana` | All lowercase; initials should still be uppercase |
| `🦊 Fox` | Emoji first; `name.prefix(1)` gives `🦊` as the "initial", and `(name as NSString).substring(to: 1)` gives half a surrogate pair (`�`) |
| `👩🏽‍💻 Priya` | ZWJ emoji sequence; `utf16.count` is 7+ for one visible character, UTF-16 slicing breaks it into pieces |
| `"  Sam   Lee "` | Leading, trailing, and repeated spaces; initials from empty words, odd gaps |
| `ㅤ` (U+3164 Hangul Filler) | An "invisible" name people pick on purpose. It's classed as a letter, so whitespace trimming keeps it and the row shows a blank name |
| `Z̷̢̛͖a̴͙͝l̶̰̾g̷̱̈o̵̪͝` | Stacked combining marks ("Zalgo"), pasted into display names. Five characters, 21 scalars, 37 UTF-8 bytes; the marks draw over the rows above and below, and a `.clipped()` that hides them also clips real Vietnamese |
| *(missing)* | No name at all, only an email; the view must fall back to something |

## 2. Emails, URLs, identifiers (unbreakable strings)

They have no spaces, so SwiftUI has nowhere to wrap them at a word boundary: it breaks them mid-token when they don't fit, or `lineLimit(1)` cuts off the end, which is usually the part that differs.

| Value | Breaks |
|---|---|
| `bartholomew.fitzgerald@northwind-industries-holdings.example.com` | The classic. Pushes every sibling off the row unless the text column can shrink and truncate |
| `a@b.co` | Shortest realistic; layout that assumed a long email looks empty |
| `first.last+billing-notifications@example.com` | Plus-addressing; validation that rejects `+`, display that truncates the meaningful part |
| `ops@sub.department.region.example.co.uk` | Many subdomains, two-part TLD; "domain" extraction logic |
| `https://example.com/workspaces/acme/projects/q3-launch/docs/9f8e7d6c5b4a?tab=comments&filter=unresolved` | Long URL; overflow, and end-truncation hides the part that differs |
| `9f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7e6f` | UUID; monospace width, middle-truncation candidate |
| `Q3 Board Deck — FINAL (revised) v12 [approved by legal].pdf` | File name; end-truncation hides the version and extension |
| `IMG_20250914_183022_HDR_portrait_edited_edited.HEIC` | Camera file name; unbreakable, uppercase extension |
| `"invoice\u{202E}fdp.exe"` | A right-to-left override character: it displays as `invoiceexe.pdf`. A view that lets the visible ending stand for the file type misleads |
| `ORD-2026-11-000184729-DE-BER-EXPRESS` | Order/tracking ID; users compare the last digits |
| `@a` / `@thisisaverylongusernamethatisallowed` | Handle extremes |
| `Benachrichtigungseinstellungen` | German compound (30 characters, no spaces); a label or button breaks it mid-word |
| `Tietosuojaseloste` / `Käyttöoikeusasetukset` | Finnish compounds; same failure, often in segmented controls and tab labels |

Look for: is the meaningful end visible (domain, extension, last digits)? Can the user copy it (`.textSelection(.enabled)`)?

## 3. Labels, titles and copy from data

| Value | Breaks |
|---|---|
| `Senior Product Design Engineer, Platform Infrastructure` | Long job title; wraps to three lines in a secondary slot |
| `Quarterly Planning Review and Budget Reconciliation for the Northern Region` | Navigation titles (large title truncates, inline title truncates harder), card titles, section headers |
| `Invitation expired 12 days ago` | Long status badge; badge wraps or squeezes the name column |
| `Paramètres de confidentialité et de sécurité` | French for "Privacy & security"; UI copy runs ~30 % longer in translation |
| Twelve tags on one item: `design`, `frontend`, `q3`, `urgent`, `needs-review`, … | Tag rows that wrap into a wall; needs a `+8` overflow |
| A tag named `customer-feedback-from-enterprise-onboarding` | One tag wider than its container |
| `Untitled` / `""` / `"   "` | Title missing; collapsed heading, zero-height row |
| `**bold**`, `[tap here](https://example.com)`, `<b>`, `&amp;` | Markdown from user content is parsed if it reaches `Text(LocalizedStringKey(…))` or `AttributedString(markdown:)`; must render literally |
| `"Line one\nLine two"` | Newline in a single-line field; doubles row height or is silently dropped |
| A 2,000-character pasted description | Clamps, "Show more", `TextField(axis: .vertical)` growth |

## 4. Optional, nil and empty fields

Set every optional to `nil`, one at a time and then all together. Then set the strings to `""` and `"   "`, because servers send those instead of `nil`.

| Case | Value | What to look for |
|---|---|---|
| Force unwrap | `bio: nil` where the view says `user.bio!` | **Crash.** The preview for that fixture fails to render; in the app it's a launch-to-crash on that profile. Severity Broken, always |
| Implicitly unwrapped / `as!` / `[0]` | `nil`, wrong type, empty array | Same crash class; `items[0]` and `items.first!` on an empty list |
| Missing subtitle | `email: nil` | Row height changes; leftover spacing; `"Optional(…)"` or `"nil"` in text |
| Missing date | `lastSeen: nil` | `"Last seen "` with nothing after it |
| Missing image URL | `avatarURL: nil` | `AsyncImage(url: nil)` stays in its placeholder forever (an endless `ProgressView`) |
| Everything optional missing | all `nil` | The row still makes sense and keeps a reasonable height |
| Empty instead of `nil` | `email: ""` | A separator (`" · yesterday"`) or a blank line still shows |
| Whitespace only | `name: "   "` | Passes `isEmpty`, shows nothing |
| Partial row in a list | half the rows have an avatar and a subtitle, half don't | Misaligned columns, rows of different heights |

## 5. Numbers

Each of these must stay fully readable (numbers are never truncated; see [Fix order in SKILL.md](../SKILL.md#fix-order)).

Interpolation behaves differently depending on where the string is built. In a `Text` literal (`Text("\(n)")`) an `Int` is grouped by the environment locale, a `Double` shows six decimals, and a `Decimal` comes out raw. A `String` built first (`"\(n)"`, `String(n)`, `Text(verbatim:)`) isn't localized at all.

| Value | Breaks |
|---|---|
| `0` | Zero states: "0 members", empty progress bar, division by zero in percentages |
| `1` | Plurals: "1 members", "1 days ago" ([section 7](#7-pluralization)) |
| `1284` | Needs a grouping separator: `1,284`. Breaks when the value is stringified before `Text` (`String(count)`, a stored `"\(count)"`, `Text(verbatim:)`) and shows `1284`. `Text("\(count)")` already groups |
| `2026` as a year, `184729` as an order number, `10115` as a zip code | The opposite break: `Text("\(year)")` groups it to `2,026`, `184,729`. Use `Text(verbatim: String(year))` or `.number.grouping(.never)` |
| `48_300_000` followers, `1_234_567_890` views | Width of a fixed-width stat column; use compact notation `48M`, `1.2B` where precision doesn't matter |
| `Decimal(string: "12345678.9")!` as currency | `$12,345,678.90`; overflows totals columns |
| `-42.5`, `Decimal(string: "-1234567.89")!` | Negative sign, red colour logic, accounting parentheses in some locales |
| `0.1 + 0.2` as `Double` | `Text("\(x)")` shows `0.300000` (six decimals, always); a pre-built `String` shows `0.30000000000000004` |
| `0.000123` | Crypto and scientific amounts; a formatter with 2 fraction digits shows `0.00` |
| `1.42` / `-0.03` as a fraction | Progress bars and gauges past their bounds (`142%`, `-3%`); `ProgressView(value:)` clamps silently, custom bars don't |
| `0.999` as a percent | Hand-rounded "100%" for something not finished |
| Badge counts `0`, `9`, `99`, `100`, `12_345` | Badge width; does "99+" or compact notation kick in? |
| `-1` sentinel from the server ("hidden") | Shown as "-1 followers" when the type allows it |
| `-3` as an unread count | Happens after a race between "mark read" and a sync. "-3 unread", a badge reading `-3`, a progress bar running backwards |
| `Int.max` (`9,223,372,036,854,775,807`) | A corrupted or sentinel counter. 25 characters grouped, `9,223,372T` compact; `count + 1` traps on overflow |
| `Decimal(string: "-0.001")!` as currency, `-0.0` as a percent | `-€0.00` and `-0%`: a negative sign (and red colour) for a value that displays as zero |
| `Double.nan`, `Double.infinity` | Rendered as `nan` / `inf`; `.frame(width: .nan)` logs an invalid frame and lays out wrong; `Int(value)` crashes |
| A value that changes live (`99` → `100`) | Width jump and jitter without `.monospacedDigit()` |

## 6. Currency and locale formatting

Set `.environment(\.locale, Locale(identifier: …))` and format with `Text(amount, format: .currency(code: …))`. `Text("\(amount)")` with a `Decimal` amount and `Text(amount.formatted())` don't follow the environment locale, which is why they're findings: the first never localizes (`1234567.89` in every locale), the second uses the device locale instead of the one the view is given. An `Int` or `Double` interpolated into a `Text` literal does follow the locale, but without a currency symbol or precision control.

| Locale | What changes |
|---|---|
| `en_US` | Baseline: `$1,234.56` |
| `de_DE` | Decimal comma, period grouping, symbol after the amount: `1.234,56 €` |
| `fr_FR` | Narrow space as the grouping separator, symbol after: `1 234,56 €` |
| `de_CH` | Apostrophe grouping: `1’234.56` |
| `hi_IN` | Lakh grouping: `12,34,567` |
| `ar_EG` | Some Arabic locales use Eastern Arabic digits (`١٢٣`); sign and symbol placement change |
| `ja_JP` with `JPY` | Yen has no fractional digits; a hardcoded `.precision(.fractionLength(2))` is wrong |

Also try: a currency that isn't the locale's own (`EUR` shown to an `en_US` user), negative amounts in every locale, and the amount inside a sentence (`Text("Balance: \(balance, format: .currency(code: "EUR"))")`).

## 7. Pluralization

| Value | Breaks |
|---|---|
| `count = 1` | "1 followers", "1 items", "1 days ago" from a hardcoded plural |
| `count = 0` | "0 messages" where a designed "No messages" reads better |
| `count = 2…4` in Polish, Czech, Russian | A plural rule with more forms than English `one`/`other` (Polish: 1 plik, 2 pliki, 5 plików) |
| `count = 21` in Russian | Back to the singular form (`21 файл`); proves hand-rolled `count == 1 ? … : …` is wrong |
| Label separated from its number | `Text("\(n)")` above `Text("followers")`: the label can't agree with a number it doesn't see |

Fix with String Catalog plural variants, or automatic grammar agreement `Text("^[\(count) follower](inflect: true)")` for the languages it supports. See [fixes.md §6](fixes.md#6-numbers-amounts-plurals-and-dates).

## 8. Collections

| Value | Breaks |
|---|---|
| 0 items | The empty state, and whether one exists at all |
| 1 item | Grids that look broken with one card; "1 of 1"; a "See all" link to a list of one |
| 2 items | Joining: "Anna and Ben", not "Anna, Ben" (`.formatted(.list(type: .and))`) |
| Exactly page size, and page size + 1 | Off-by-one in "Showing 40 of 40", an empty page 2 |
| 10,000 items, unpaginated | `ScrollView { VStack { ForEach } }` builds every row at once; sorting or formatting in `body`; "Showing 40 of 10,000" copy |
| One item 10× the size of the others | Grid rows stretching to the tallest item |
| Items with identical names | Lists where the name is the only distinguishing field |
| Duplicate or unstable ids | `ForEach` warnings, rows swapping content, wrong row deleted |
| Count changes `0 → 1 → 0` | Empty state flicker, selection pointing at a deleted item |
| A stored count that disagrees with the items ("12 members" above an empty list) | Header and list read from different sources; which one the view trusts |
| 200 rows that each show a full-size photo | Each 12 MP photo decodes to ~48 MB; memory climbs and scrolling hitches, though the list itself is lazy |

## 9. Dates and times

Format with `Text(date, format: …)` and `Text(date, style: .relative)`, never hand-built strings.

| Value | Breaks |
|---|---|
| Now | "0 seconds ago" instead of "now"; `RelativeDateTimeFormatter` / `.relative(presentation: .named)` handles it |
| 12 days ago, 11 months ago, 3 years ago | Relative-time thresholds; a reasonable guideline is to switch to an absolute date after a week or so |
| A future date | "in 3 days" vs "-3 days ago" |
| `Date(timeIntervalSince1970: 0)` | A zero timestamp shown as a real date: Dec 31, 1969 in time zones west of UTC |
| 1900-01-01 (birth date) | Age or relative text ("126 years ago") |
| 2099-12-31 (expiry) | "in 73 years", year width |
| `Date.distantFuture` as "never" | Shows the year 4001; model "never" as `nil` |
| 2025-12-31 23:30 in UTC−8 | A different calendar day in UTC and in the user's time zone; grouping by day. Preview with `.environment(\.timeZone, …)` |
| Feb 29, a DST change day | Day arithmetic with `+ 86_400` instead of `Calendar` |
| 12 vs 24 hour | `en_US` "11:45 PM" vs `de_DE` "23:45"; fixed-width time columns |
| Very long duration (`1,284 hours`) | Duration formatting that never rolls up to days (`Duration.formatted(.units(allowed: [.days, .hours]))`) |

## 10. Images and media

| Value | Breaks |
|---|---|
| Avatar URL that 404s: `https://example.com/missing.jpg` | `AsyncImage(url:content:placeholder:)` shows the placeholder forever; no fallback to initials |
| `nil` URL | Same, from the start |
| Never loads: `https://example.test/slow.jpg` | Placeholder must be designed, not a blank square or an endless spinner |
| Not an image: `https://example.com/` (an HTML page with status 200) | What a captive portal, an expired CDN link or a login redirect returns. `AsyncImage` fails to decode it; the `content:placeholder:` form shows its placeholder forever |
| An SVG or an animated GIF URL | `Image` and `AsyncImage` don't render SVG data; a GIF shows only its first frame |
| No avatar at all | The fallback itself: initials, colour, size parity with real avatars |
| 4000×200 panorama as avatar or cover | `.resizable()` without `scaledToFill()` squashes it into the frame |
| 200×4000 tall image | Same, other axis; can also blow out a card's height when only the width is fixed |
| 16×16 image in a hero | Blurry upscale |
| 8000×8000 user upload in a list row | Decodes to ~256 MB however small it's drawn; memory spike, slow scrolling. Downsample before display and cache the thumbnail |
| Transparent PNG logo, dark logo in dark mode | Invisible on the background |
| Image that arrives after the text | Layout jump when it appears, if the frame depends on the image |

## 11. Emoji and complex scripts

| Value | Breaks |
|---|---|
| `👩🏽‍💻`, `👨‍👩‍👧‍👦` | Initials or character limits that split a sequence (counting UTF-16 instead of `Character`) |
| `🇩🇪🇫🇷🇯🇵` | Same; each flag is two scalars |
| `👩🏽‍💻 Dev Team` | Initials taken from the emoji |
| `東京都渋谷区神南一丁目二十三番十号` | CJK: line breaking anywhere; fallback fonts with taller line height clip in fixed-height rows |
| `ผู้ใหญ่บ้านน้ำใจดี` | Thai: marks above and below the line clipped by a fixed-height row or `.clipped()` |
| `Nguyễn Thị Ánh Tuyết` | Vietnamese: stacked diacritics clipped at the top |
| `नमस्ते दुनिया` | Devanagari: tall glyphs and conjuncts clipped |
| `Z̷̢̛͖a̴͙͝l̶̰̾g̷̱̈o̵̪͝` (combining-mark stacks) | Marks drawn over neighbouring rows; character, scalar and byte counts disagree (5, 21, 37), so length limits differ between client and server |
| User content in a script the UI language doesn't expect (Thai in an English app) | Line height chosen for Latin; fix with `.typesettingLanguage(_:)` ([fixes.md §15](fixes.md#15-emoji-and-complex-scripts)) |

## 12. States: loading, error, offline, partial

| State | Breaks |
|---|---|
| Loading under ~150–300 ms | A spinner that flashes. A common guideline: show a loader only after a 150–300 ms delay, and once shown keep it at least 300–500 ms |
| Loading longer | A skeleton that doesn't match the final layout; use the real rows with `.redacted(reason: .placeholder)` |
| Error from the API | No error state, or a raw message (`The operation couldn't be completed. (NSURLErrorDomain error -1009.)`) |
| Offline | An error page replacing content that was already cached |
| Partial data | Some sections loaded, others failed |
| Every status at once | All enum values in one list (`active`, `invited`, `expired`, `suspended`); badge widths vary |
| No permission | Disabled actions; does the row still lay out the same? |
| The current user in the list | "You" labels, actions that shouldn't apply to yourself |
| Retry while loading | Double requests, duplicate rows |

---

## 13. Localization expansion

As a rule of thumb, translations of UI copy run about 30–35 % longer than English on average (German ~35 %), and short labels grow far more: "Save" → "Speichern" is +125 %. German and Finnish are the usual worst cases.

| Key | English | German | Finnish |
|---|---|---|---|
| Save button | `Save` | `Speichern` | `Tallenna` |
| Settings | `Settings` | `Einstellungen` | `Asetukset` |
| Notifications | `Notifications` | `Benachrichtigungen` | `Ilmoitukset` |
| Notification settings | `Notification Settings` | `Benachrichtigungseinstellungen` | `Ilmoitusasetukset` |
| Add to cart | `Add to Cart` | `In den Warenkorb legen` | `Lisää ostoskoriin` |
| Sign out | `Sign Out` | `Abmelden` | `Kirjaudu ulos` |
| Mark all as read | `Mark All as Read` | `Alle als gelesen markieren` | `Merkitse kaikki luetuiksi` |
| Unread | `3 unread` | `3 ungelesene Nachrichten` | `3 lukematonta viestiä` |

How to get translated text into the view:

- **Fixtures:** put the translated strings straight into the fixture (they are data). Works everywhere.
- **Preview:** `Text("Save")` (a `LocalizedStringKey`) is looked up in the environment locale, so `.environment(\.locale, Locale(identifier: "de"))` shows the German String Catalog entry if one exists. Strings resolved earlier with `String(localized:)` in a model use the process language and don't follow the preview's environment.
- **Scheme ▸ Run ▸ Options ▸ App Language:** the real thing, plus the pseudolanguages:
  - **Double-Length Pseudolanguage**: every string twice as long.
  - **Accented Pseudolanguage**: tall accented glyphs; finds clipped line heights.
  - **Bounded String Pseudolanguage**: brackets around each string; finds concatenated and unlocalized strings.
  - **Right-to-Left Pseudolanguage**: RTL layout with your English strings.

## 14. Right-to-left

Apply `.environment(\.layoutDirection, .rightToLeft)` together with an RTL locale (`.environment(\.locale, Locale(identifier: "ar"))`) **and** RTL strings. Flipping the layout with English strings only finds half the bugs.

| Value | Breaks |
|---|---|
| `محمد بن عبد الله العتيبي` (Arabic name) | Alignment, initials |
| `נועה בן־דוד` (Hebrew name) | Same, plus the Hebrew hyphen (maqaf) |
| `تم إرسال رسالتك بنجاح` (Arabic sentence) | Text forced left-to-right (a hardcoded `.leftToRight` layout direction, `.left` in a bridged UIKit label) |
| `طلب رقم ORD-2026-000184` (Arabic with a Latin ID) | Mixed-direction ordering |
| `+49 30 1234567` in an Arabic layout | Phone numbers and IDs must stay left-to-right |

Look for: hard-coded `.offset(x:)`, `.position(x:)` and `GeometryReader` x math (it doesn't flip; `.move(edge: .leading)` does), custom arrow images that don't flip, progress bars filling from the wrong side, swipe actions on the wrong edge, `Canvas`/`Path` drawing that assumes left-to-right, `.left`/`NSTextAlignment.left` in bridged UIKit views. SwiftUI's own `.leading`/`.trailing` already flip.

## 15. Dynamic Type

Set per preview with `.dynamicTypeSize(.accessibility5)`. Body text is 17 pt at the default `.large` and 53 pt at `.accessibility5`, about 3.1×; `.xSmall` body is 14 pt.

| Size | Why test it |
|---|---|
| `.xSmall` | Tiny text next to fixed-size icons looks broken; minimum heights become obvious |
| `.large` | Default; the baseline |
| `.xxxLarge` | Largest non-accessibility size; most `HStack` rows start to fight here |
| `.accessibility1` | First accessibility size; where layouts usually switch from row to stack |
| `.accessibility5` | Largest; everything that can break does |

Look for: `.font(.system(size:))` that doesn't scale, icons that stay small next to huge text, fixed heights that clip, `HStack` rows that should stack, screens that run off the bottom with no `ScrollView`, buttons that become unreachable, and a root-level Dynamic Type cap. Combine `.accessibility5` with the narrowest width ([section 17](#17-device-sizes-orientation-multitasking)); that pair finds most layout bugs at once.

## 16. Appearance and accessibility settings

| Setting | How to apply | What breaks |
|---|---|---|
| Dark mode | `.preferredColorScheme(.dark)` | Hardcoded `.white`/`.black`, shadows that vanish, dark logos on transparency |
| Bold Text | `.environment(\.legibilityWeight, .bold)` | Wider text truncating in tight rows; custom fonts that ignore it; a selected tab whose weight change widens it |
| Increase Contrast | Read-only in SwiftUI (`colorSchemeContrast`): Simulator or Environment Overrides ([preview-harness.md §8](preview-harness.md#8-what-previews-cant-set-and-where-to-test-it-instead)) | `.secondary`/`.tertiary` text on tinted backgrounds, hairline separators, custom colours without a high-contrast variant |
| Reduce Transparency | Read-only (`accessibilityReduceTransparency`): same | Custom translucent overlays (`Color.black.opacity(0.3)`) the system can't make solid |
| Liquid Glass content **(iOS 26)** | Dark + light wallpaper behind it, Increase Contrast, Reduce Transparency | System glass adapts on its own; custom tints, text and icons you layered on it don't. Glass on glass |
| Smart Invert | Simulator Accessibility settings | Photos and avatars inverted; mark them `.accessibilityIgnoresInvertColors()` |
| Button Shapes | Simulator Accessibility settings | Custom plain-text buttons with no visible affordance |
| Always-On (widgets, Live Activities) | `.environment(\.isLuminanceReduced, true)` | Dimmed rendering with no animation; thin or low-contrast text and bright fills that need a stroked or dimmer variant |

**System chrome (iOS 26).** The system bars are glass and adapt on their own; what you feed them doesn't. Render each with German or Finnish strings at `.accessibility3` and above:

- **Toolbar titles and buttons:** a long `.navigationTitle` plus `.navigationSubtitle` truncates; text buttons crowd out icon buttons or drop into overflow. Give each item an icon and a title.
- **Tab bar:** long tab labels (`Benachrichtigungen`) truncate, and a minimized tab bar (`tabBarMinimizeBehavior`) shows only icons, so every tab needs a clear symbol.
- **Bottom accessory** (`tabViewBottomAccessory`): worst-case text at AX5, in both the expanded and the inline (collapsed tab bar) placement.
- **Scroll edge effect:** the first and last rows of custom content that ignores the safe area sit under the bar's blur; check they're still readable and tappable.

Motion settings (Reduce Motion, Prefer Cross-Fade Transitions) belong to swift-motion-review.

## 17. Device sizes, orientation, multitasking

| Width × height (pt) | Where it happens |
|---|---|
| The real container | Sidebar column, sheet detent, popover, widget family: test this first. An iOS 26 partial-height sheet is inset glass, narrower than the screen, and resizes as it's dragged; drop a custom `presentationBackground` |
| 320 wide | Narrowest iPad Split View / Slide Over column; also old 4-inch iPhones |
| 375 × 667 | iPhone SE class: narrow **and** short, so bottom content and keyboards collide first |
| 440 × 956 | Pro Max class slab iPhone: the widest compact-width layout |
| iPhone landscape | Short height, side safe areas; a non-scrolling form doesn't fit |
| iPad full width (1024+ wide) | Lines too long to read, content stranded on one side, phone layouts stretched edge to edge |
| iPad Split View / Stage Manager | Compact horizontal size class on an iPad; layouts that branch on `UIDevice.current.userInterfaceIdiom` instead of size class |
| Freely resized window **(iPadOS 26)** | Any width between the extremes, changing live; layouts that only handled the fixed split fractions |
| iPhone Duo inner display **(iOS 27.1)** | Regular width on an iPhone; layouts that branch on `userInterfaceIdiom` or orientation, or assume a compact iPhone, stretch or break |
| iPhone Duo folding, unfolding, partly folded **(iOS 27.1)** | The app moves between the outer and inner display while running; bars move to a vertical side position; a partly folded hinge is a division `ReservedRegion` that rows, grids and custom overlays mustn't straddle. System containers (split views, sheets, tab bars, `ArrangementView`) adapt on their own; custom edge-to-edge chrome must read `GeometryProxy.reservedRegions(kind:)` |

Preview with `traits: .fixedLayout(width: 320, height: 700)`, `.landscapeLeft`, and `.environment(\.horizontalSizeClass, .compact)` for an iPad split column. Pick a real device in the canvas device picker for safe areas. For iPhone Duo, run the Duo simulator and pose it folded, open and partly folded ([preview-harness.md §8](preview-harness.md#8-what-previews-cant-set-and-where-to-test-it-instead)).

## 18. Keyboard

Previews don't reliably show the software keyboard, so run these in the Simulator with I/O ▸ Keyboard ▸ Toggle Software Keyboard (⌘K).

| Case | What breaks |
|---|---|
| Focus the last field in a long form | Field hidden behind the keyboard |
| Bottom-pinned primary button | Covered, or floats in the wrong place |
| `.ignoresSafeArea()` on the content | Content stops avoiding the keyboard |
| iPhone SE height or landscape with the keyboard up | Almost no space left; is the focused field still visible? |
| Dismissal | Can the user dismiss the keyboard without submitting? |
| iPad hardware keyboard / floating keyboard | Layout that assumed the keyboard always covers the bottom |

## 19. Interaction edge cases

| Case | What breaks |
|---|---|
| Double-tap a submit button | Duplicate action; disable while in flight |
| Very long `TextField` input | Field grows or scrolls sensibly; a character counter counts `Character`s, not UTF-16 |
| Paste a multi-line string into a single-line field | Newlines kept or stripped on purpose |
| Copy an ID, email or address | `.textSelection(.enabled)` where users will want it |
| Tap target at AX5 or with a one-letter label | Still at least 44×44 pt (Apple's HIG minimum) and not overlapping its neighbour |
| Truncated text | Is the full value reachable somewhere (detail screen, expansion)? VoiceOver reads the full string, sighted users can't |

## 20. Fixture constants

Take only the constants the view needs and paste them into the `#if DEBUG` block that holds its previews, in the view's own file. They're `private` so two files can each carry a copy without clashing; drop `private` only if the project already has a shared fixtures file to put them in. Self-contained; Foundation only.

```swift
#if DEBUG
import Foundation

private enum StressStrings {
    // People
    static let longName = "Aleksandra Wiśniewska-Kowalczyk"
    static let longerName = "Maximiliane Alexandra Oberhauser-Wittgensteiner"
    static let suffixName = "Christopher Alexander Montgomery III"
    static let twoLetters = "Jo"
    static let oneLetter = "J"
    static let particles = "María José de la Cruz y Fernández"
    static let lowercase = "dana"
    static let spaces = "  Sam   Lee "
    static let emojiFirst = "🦊 Fox"
    static let zwjName = "👩🏽‍💻 Priya"
    static let invisibleName = "\u{3164}"                       // Hangul Filler: survives trimming
    static let zalgo = "Z\u{0337}\u{0322}\u{031B}\u{0356}a\u{0334}\u{0359}\u{035D}l\u{0336}\u{0330}\u{033E}g\u{0337}\u{0331}\u{0308}o\u{0335}\u{032A}\u{035D}"

    // Unbreakable
    static let email = "bartholomew.fitzgerald@northwind-industries-holdings.example.com"
    static let shortEmail = "a@b.co"
    static let plusEmail = "first.last+billing-notifications@example.com"
    static let url = "https://example.com/workspaces/acme/projects/q3-launch/docs/9f8e7d6c5b4a?tab=comments&filter=unresolved"
    static let uuid = "9f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7e6f"
    static let fileName = "Q3 Board Deck — FINAL (revised) v12 [approved by legal].pdf"
    static let orderID = "ORD-2026-11-000184729-DE-BER-EXPRESS"
    static let germanCompound = "Benachrichtigungseinstellungen"
    static let finnishCompound = "Käyttöoikeusasetukset"
    static let bidiOverrideFile = "invoice\u{202E}fdp.exe"       // displays as "invoiceexe.pdf"

    // Copy from data
    static let jobTitle = "Senior Product Design Engineer, Platform Infrastructure"
    static let longTitle = "Quarterly Planning Review and Budget Reconciliation for the Northern Region"
    static let statusBadge = "Invitation expired 12 days ago"
    static let french = "Paramètres de confidentialité et de sécurité"
    static let markdown = "**bold** and [tap here](https://example.com)"
    static let newline = "Line one\nLine two"
    static let empty = ""
    static let whitespace = "   "

    // RTL
    static let arabicName = "محمد بن عبد الله العتيبي"
    static let hebrewName = "נועה בן־דוד"
    static let arabicSentence = "تم إرسال رسالتك بنجاح"
    static let mixedDirection = "طلب رقم ORD-2026-000184"

    // Scripts and emoji
    static let family = "👨‍👩‍👧‍👦"
    static let flags = "🇩🇪🇫🇷🇯🇵"
    static let cjkName = "王秀英"
    static let cjkAddress = "東京都渋谷区神南一丁目二十三番十号"
    static let thai = "ผู้ใหญ่บ้านน้ำใจดี"
    static let vietnamese = "Đặng Thị Ngọc Hân"
    static let devanagari = "नमस्ते दुनिया"
}

private enum StressNumbers {
    static let counts = [0, 1, 2, 1_284, 10_000]
    static let badges = [0, 9, 99, 100, 12_345]
    static let followers = 48_300_000
    static let views = 1_234_567_890
    static let bigAmount = Decimal(string: "12345678.9")!
    static let negativeAmount = Decimal(string: "-1234567.89")!
    static let tinyAmount = Decimal(string: "0.000123")!
    static let floatNoise = 0.1 + 0.2
    static let negativeCount = -3
    static let hugeCount = Int.max
    static let negativeZeroAmount = Decimal(string: "-0.001")!   // "-€0.00"
    static let nonFinite: [Double] = [.nan, .infinity, -.infinity]
    static let fractions: [Double] = [-0.03, 0.999, 1.42]
    static let locales = ["en_US", "de_DE", "fr_FR", "de_CH", "hi_IN", "ar_EG", "ja_JP"]
        .map(Locale.init(identifier:))
}

private enum StressDates {
    private static let calendar = Calendar(identifier: .gregorian)
    static let epoch = Date(timeIntervalSince1970: 0)
    static let farPast = calendar.date(from: DateComponents(year: 1900, month: 1, day: 1))!
    static let farFuture = calendar.date(from: DateComponents(year: 2099, month: 12, day: 31))!
    static let justNow = Date.now.addingTimeInterval(-5)
    static let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!   // not -86_400: DST
    static let timeZones = ["Pacific/Pago_Pago", "UTC", "Pacific/Kiritimati"]   // UTC−11, 0, +14
        .compactMap(TimeZone.init(identifier:))
}

private enum StressImages {
    static let missing = URL(string: "https://example.com/missing.jpg")
    static let neverLoads = URL(string: "https://example.test/slow.jpg")
    static let notAnImage = URL(string: "https://example.com/")     // an HTML page, status 200
}
#endif
```
