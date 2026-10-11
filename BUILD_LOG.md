# Build Log — Scam Detection Field

Factual development record for the Grevix AfterCode 24-hour hackathon.
Entries are written as they happen. Nothing here is invented after the fact.

**Legend**

* **AI did** — work performed or proposed by the AI teammate.
* **Builder decided** — the human builder's decision (including decisions
  explicitly delegated to the AI teammate under section 12 of the master
  prompt, and recorded here as such).
* **Rejected** — ideas considered and dropped, with the reason.

---

## 0. Starting state (hackathon start)

* Workspace: `C:\Hack_Projects\Scam Detection Field`
* Contents: a fresh `flutter create` template. `lib/main.dart` was the default
  `Hello World`. No previous implementation of this product existed.
* Environment check: Flutter 3.44.6 stable, Dart 3.12.2, Android SDK 36.0.0
  present but licenses not accepted, Windows + Chrome + Edge devices available.
* A separate training prototype from before the hackathon was **not** opened,
  not copied and not reused. Everything below was written during the hackathon
  period from the current project state.

---

## 1. Initial build

### What was built

A single-flow Flutter app: paste a link or a message → analyse → risk level →
reasons → recommendation → limitation note.

| Area | Built |
| --- | --- |
| Input screen | Link / Message tabs, example presets, validation, error states, "How it works" sheet |
| Result screen | Risk header, signals list, AI card (optional), recommendation, "About this analysis", copy report |
| URL rules | 21 check groups (brand impersonation, homograph, `@` trick, raw IP, shortener, TLD, sub-domains, dashes, digits, `http://`, ports, query credentials, downloads, encoding, length, ...) |
| Message rules | 14 check groups (urgency, threats, secret requests, payment demands, release fees, prizes, impersonation, secrecy, too-good-to-be-true, click pressure, generic greeting, chain forwarding, off-platform contact) |
| Combination rule | link + request for money/information in one message ⇒ strong signal |
| Scoring | warning = 1 pt, critical = 5 pt; any critical ⇒ HIGH; ≥7 ⇒ HIGH; ≥2 ⇒ MEDIUM |
| AI integration | optional OpenAI-compatible explanation with full error/fallback handling |
| Tests | 50 tests: URL rules, message rules, input detection, engine, AI success/error/network/invalid-response paths, UI flow |

> **Correction (added later, during the Arabic work):** the "21 check groups"
> figure for URL rules is inaccurate — counting the rule call sites in
> `url_rules.dart` gives **24**, and with 14 message groups plus 2 indicators
> synthesised by the engine there are **40** indicators in total. The row is
> left unchanged above; the correction is recorded here instead of silently
> editing the original entry.

### Why it was built this way

* **Deterministic rules set the risk level; AI only writes wording.** A judge
  or a user can always see *exactly* which rule produced which reason. An AI
  score would not be reproducible or explainable.
* **No confidence percentage is displayed.** Any number would imply a
  scientific calibration we do not have.
* **The app never opens the link.** Checking the destination would require
  fetching a possibly malicious URL from the user's device.
* **One screen in, one screen out.** The MVP definition in the master prompt
  stops at "user receives a practical recommendation"; no dashboards,
  accounts, onboarding or history were added.

### Important technical decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| State management | plain `StatefulWidget` + injected `AnalysisEngine` | Two screens, no shared state; a state-management package would be dead weight |
| Dependencies | only `http` | Needed solely for the optional AI call; everything else is Flutter built-in |
| Models | pure Dart (no Flutter import) | The whole pipeline is unit-testable without a device |
| AI key | `--dart-define` only | Never appears in source or in the repository |
| Package/folder name | `scam_detection_field`, id `com.grevix.scamdetectionfield` | The default `flutter_application_1` / `com.example.*` looks unfinished in a submission |
| Scoring weights | 1 / 5 with "any critical ⇒ HIGH" | Simple enough to explain in one sentence during a demo |

### What AI did

* Proposed the architecture (models / rules / scorer / engine / services /
  screens / widgets) and the rule catalogue.
* Wrote the implementation, the tests and the documentation.
* Diagnosed and fixed: the `library;` directive placement, raw-string
  apostrophes breaking regular expressions, a nullable-assignment error in the
  navigation call, a nullable IP-parse, an incorrect `copyWith`, and a widget
  test viewport problem.
* Suggested the honest wording for the fallback and limitation texts.

### What the builder decided

* Approved the product direction given in the master prompt (scam-indicator
  explainability over a "is it a scam" verdict).
* Delegated routine technical decisions (file names, structure, packages, test
  design, minor UI details) to the AI teammate as defined in section 12 of the
  master prompt. No such decision has yet required a product-level question.

### Rejected ideas (initial build)

| Idea | Why rejected |
| --- | --- |
| Machine-learning classifier trained on scam messages | No labelled dataset available in the time window; a small model would be less explainable and less accurate than readable rules |
| Numeric "87% confidence" score | Not honestly derivable; would misrepresent the method |
| Live URL fetching / VirusTotal-style lookup | Would send the user's link to third parties and require an API key and network; contradicts the offline-first, no-link-opening rule |
| Message history, favourites, profiles, auth | No value for the core flow; every minute spent here is a minute not spent on reliability |
| Clipboard "paste" button | Native long-press paste already works; the button would need platform permission handling on Android |
| Grammar/spelling quality scoring | Subjective, noisy, and unfair to non-native English speakers and to short messages |

### Verification performed (initial build)

* `flutter analyze` — **No issues found**.
* `flutter test` — **50/50 passed** (URL rules, message rules, input
  detection, engine, AI success/error/network/invalid-response fallbacks,
  and 6 widget tests covering the full UI flow).
* `flutter build apk --release` — succeeded:
  `build/app/outputs/flutter-apk/app-release.apk` (47.0 MB).
* `flutter build web --release` — succeeded.
* **Live run check** (release web build served locally, opened in a browser):
  * Home screen renders correctly (screenshot taken).
  * Empty input → friendly inline error, no crash.
  * Example link → `HIGH RISK`, "Link analysis", 5 signals, reasons with
    explanations, recommendation, limitation note, "About this analysis".
  * Example message → `HIGH RISK`, "Message analysis", 8 signals
    (3 strong / 5 warnings / 1 context note), reasons mixing message and link
    sources, recommendation mentioning the password request.
  * Navigation back to home works.
  * Console: **no warnings or errors** after a clean reload and a full
    interaction round.
* **Secret scan before publishing**: `sk-`, `api_key`, `token`, `secret`,
  `Bearer`, `ghp_`, private-key markers → only code references, rule keywords
  and the `sk-...` placeholder shown in the README example. No real credential
  is present in the repository.

### Repository

* Repository initialised in `scam_detection_field/`, branch `main`.
* Remote: `https://github.com/hibathafer/Grevix_ScamDetectionField.git`.
* Push verified with `git ls-remote` — remote `refs/heads/main` matches the
  local commit.
* `.gitignore` extended to exclude `android/key.properties`, `*.jks`,
  `*.keystore`, `*.p12`, `.env*` and `.kotlin/`; the Gradle wrapper files are
  committed on purpose so a clean clone can build.

---

## 2. Arabic localisation (العربية)

Added after the MVP was complete and pushed. The English baseline was tagged
first (`mvp-baseline-v1`) so this work is fully revertible.

### What was built

| Area | Built |
| --- | --- |
| String contract | `lib/l10n/app_strings.dart` — abstract `AppStrings` + `EnglishStrings` |
| Arabic strings | `lib/l10n/app_strings_ar.dart` — every user-facing string and all 40 indicator titles/explanations |
| Scope plumbing | `lib/l10n/strings_scope.dart` — `InheritedWidget` carrying the active `AppStrings` |
| Root wiring | `app.dart` holds the locale, `supportedLocales`, `localizationsDelegates`, injectable `initialStrings` for tests |
| Language switcher | app-bar button on the home screen opening a bottom sheet (English / العربية) |
| Engine boundary | `AnalysisEngine` accepts optional `strings` on the constructor and per call; scoring runs on untouched rule output, then indicators are mapped for display |
| Rule params | `_hit()` gained a `params` map; 18 of the 24 URL-rule call sites now pass the values that the Arabic wording interpolates (host, brand, official domain, TLD, port, counts, ...) |
| Coverage caveat | `detectionCoverageNote`, non-null in Arabic only, rendered on the home screen **and** repeated on the result screen |

### Why it was built this way

* **Translate at display time, never at rule time.** Rules keep emitting
  their English result with a stable `id` and `severity`; `AppStrings`
  localises only the wording. This makes it structurally impossible for the
  language setting to move a risk level.
* **`EnglishStrings` is byte-identical to the previous hard-coded text**, so
  the 50 existing tests stayed valid unchanged — no regression was papered
  over by editing assertions.
* **`flutter_localizations` (first-party SDK) over a hand-rolled
  `Directionality` wrapper**, so Material's own widgets and built-in strings
  (dialogs, tooltips, semantics labels) come out in Arabic too.

### Important technical decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Localisation mechanism | hand-written `AppStrings` classes, not `.arb` + `gen-l10n` | Two languages, one file each, no codegen step or build-time tooling |
| RTL mechanism | `flutter_localizations` → pulls in `intl` | Only package added; first-party SDK, and Material widgets then get correct RTL for free |
| Language persistence | **none** — session only | Persisting would require `shared_preferences`, a third-party dependency, for one preference |
| Arabic detection | **not implemented**, and stated in the UI | Honest about the rules still matching English only |
| Brand name | stays Latin in both languages | Proper noun, as is normal in Arabic apps |
| AI prompt | stays English | AI is disabled in the default build; translating the prompt without Arabic rules would overstate support |

### What AI did

* Wrote the `AppStrings` contract, both string classes, the `StringsScope`
  widget and the engine/display boundary.
* Rewrote `home_screen`, `result_screen`, `risk_header` and `indicator_tile`
  to read every user-facing string from the scope.
* Handled Arabic count agreement explicitly (singular / dual / paucal 3–10 /
  plural 11+) via a `_count` helper, and switched list separators to the
  Arabic comma.
* Wrote the 31 localisation tests.
* Fixed its own errors during the work: a missing `import 'app_strings.dart'`
  that produced 70 analyzer findings, a `const RegExp` misuse, an
  interpolated-string lint, nine `test(` calls that needed to be
  `testWidgets(`, and one wrong test assertion (`verify-account.xyz` where
  the rule actually supplies `paypal.com`) — the app was correct, the test
  was not.
* Reviewed the Arabic copy afterwards and corrected three grammar slips
  (a missing `هو`/`ما` in two disclaimers, and an awkward numeral-agreement
  phrase in `analysedAt`, rewritten to avoid agreement entirely).

### What the builder decided

* Accepted the honest trade-off: no persisted language choice, Latin brand
  name, English AI prompt — in exchange for keeping the dependency footprint
  at one first-party SDK package plus its transitive `intl`.
* Required that Arabic detection **not** be claimed anywhere, and that the
  limitation appear inside the app in Arabic rather than only in the docs.
* Required the baseline to be recoverable before any code was touched.

### Rejected ideas (localisation)

| Idea | Why rejected |
| --- | --- |
| `shared_preferences` to remember the language | A third-party dependency and a storage permission surface for one preference; restart-to-English is documented instead |
| Claiming Arabic scam detection | No Arabic rules exist. Claiming support the product does not have is worse than admitting the gap in the UI |
| Writing Arabic detection rules as part of this task | Out of scope, untestable in the time available, and unreviewable for correctness; would also have changed detection behaviour, which had to stay frozen |
| `easy_localization` / GetX / other l10n packages | Two languages do not justify a third-party framework |
| Rewriting the AI prompt per language | AI is disabled by default; translating a prompt without Arabic rules would overstate capability |

### Verification performed (localisation)

* `flutter analyze` — **No issues found**.
* `flutter test` — **81/81 passed** (the original 50 unchanged, plus 31
  localisation tests).
* `flutter build web --release` — succeeded.
* **Live run check** (release web build, opened in a browser):
  * Language button → bottom sheet with *English* and *العربية*.
  * Selecting العربية switches immediately: hero, tabs, field labels,
    buttons, disclaimer and the coverage note all render in Arabic, the
    English hero disappears, `document.documentElement.lang` becomes `ar`,
    and Material's own dialog label becomes Arabic.
  * **RTL verified geometrically**, not just by text: on an 800 px viewport
    the two header buttons sit at `x=720` / `x=760` (right edge) in English
    and at `x=0` / `x=40` (left edge) in Arabic — an exact mirror.
  * A full analysis run in Arabic: risk label *مخاطر عالية*, `8 إشارات`,
    correct count agreement (`3 إشارات قوية` / `5 تحذيرات` /
    `ملاحظة سياقية واحدة`), Arabic section titles, and the coverage note
    repeated on the result screen.
  * Switching back to English restores the original text and the LTR
    layout.
  * Console: **no warnings or errors** at any point.
* **Not verified on Android:** there is **no Android device or emulator**
  connected in this environment, so the APK was not installed or run. RTL on
  a real Android device is unverified. Screenshots were also unavailable —
  the browser is headless and `browser.screenshot` requires a visible tab —
  so the RTL evidence above is DOM/geometry based, plus the widget tests
  that assert `Directionality.of(context)`.

### Baseline safety

* Tag `mvp-baseline-v1` created before this work started. No tag was
  overwritten (the repository had none before).

---

## 3. Independent code review and targeted fixes

Received after the Arabic localisation work. An external review listed
potential bugs in the then-uncommitted changes. The instruction was: fix only
**confirmed** issues, keep the changes minimal, preserve the Arabic work and
every existing test, and do not refactor.

Nothing was changed on the strength of the review's description alone. Each
item was reproduced in Dart first, and every fix is pinned by a regression
test.

### What was confirmed

| # | Reported suspicion | Reproduced? | What actually happened |
| --- | --- | --- | --- |
| 1 | `Never share your PIN…` flagged as a request | No (already guarded) | The existing guard was correct |
| 2 | `Don't share your PIN…` with a curly apostrophe | **Yes** | The guard listed `don't` and `dont` but not `don’t`, so the negation was missed |
| 3 | `Your OTP: 482913. Do not share it…` | **Yes — HIGH** | The bare `code: 1234` pattern fired on a code being *delivered to* the user |
| 4 | `Please reply with\nyour OTP.` | **Yes — not detected** | Clauses were split on `\n`, breaking the request across two clauses |
| 5 | `Don't forget to share your verification code…` | **Yes — suppressed** | Treated `don't … share` as a prohibition |
| 6 | `Do not hesitate to provide your bank details.` | **Yes — suppressed** | Treated `do not … provide` as a prohibition |
| 7 | `…unless you send your PIN.` / `…until you send your OTP.` | **Yes — suppressed** | `cannot` / `until` matched the prohibition window |
| 8 | `Do not delay and send your password now.` | **Yes — suppressed** | `do not … send` matched |
| 9 | `securepaypal.com` / `paypalsecure-login.com` missed | **Yes** | Label-exact brand matching no longer saw a brand in those labels |
| 10 | `?q=update+account` raised a path checkpoint | **Yes** | Checkpoint wording was read from path *and* query |
| 11 | Private IP then public IP in one message | **Yes — critical hidden** | Deduplication kept the *first* indicator per `id`, so an early warning hid a later critical |
| 12 | `Pay a small fee…` + a link scored HIGH | **Yes** | `combined_link_request` escalated on **any** `fee_request` plus **any** URL |
| 13 | `Congratulations on the new job!` scored HIGH | **Yes — CRITICAL** | `\bcongratulations\b` on its own was a fake-prize signal |

### What was fixed

Each fix is a local change; no rule, screen or scoring weight was redesigned.

* **Negation vs. pressure.** The prohibition test now requires the negation to
  govern the request verb directly, and a small pressure vocabulary (`forget`,
  `hesitate`, `unless`, `until`, `delay`) marks a sentence as an instruction to
  disclose rather than a warning. Curly and straight apostrophes are both
  accepted.
* **Line breaks.** Newlines are treated as spaces before the message is split
  into clauses, so a request cannot be hidden by a wrap.
* **A bare `code: 1234` is no longer sufficient.** It counts as a request only
  when the message also asks for something without prohibiting it. Codes
  delivered to the user stay clean; codes handed over with a request stay
  critical.
* **`congratulations` now needs a prize context** before it is a fake-prize
  signal.
* **Credential wording glued to a brand label** (`securepaypal`, `paypalsecure`)
  is stripped from the label edge and then matched exactly. Only the known
  credential vocabulary is stripped, and a meaningful remainder must survive —
  so `pineapple` and `purchase` are unaffected and raw substring matching was
  **not** restored.
* **Checkpoint wording is read from the path only.** Query text such as
  `?q=update+account` is a search string, not a page the link points at. Brand
  mentions inside a path are now matched as whole tokens too, so
  `/purchase/confirm` is not read as `chase`.
* **Deduplication keeps the most severe finding** per indicator id instead of
  the first, so a critical signal can no longer be hidden by an earlier
  warning of the same kind.
* **`fee_request` alone no longer escalates `combined_link_request`.** Only a
  genuine request for money or private details plus a link does, so ordinary
  delivery-shaped messages no longer jump to HIGH.

### An error the AI made and caught itself

While writing the negation fix, a `RegExp` was written inside a **non-raw**
Dart string, where `\b` is the backspace escape (U+0008) rather than a word
boundary. It would have silently disabled the guard. Caught before the tests
were run and corrected to a raw string; noted here rather than left out.

### Final refinement: `money_claim`

Follow-up task, deliberately narrow. `Claim your 500 USD reward.` previously
produced no signal at all. The distinguishing feature against benign wording is
an **imperative `claim` together with a concrete money amount**, so the rule
requires `claim (your|this|a)` followed by a number **and** a currency marker.
This takes the indicator catalogue from 40 to **41** (24 URL groups, 15 message
groups, 2 synthesised by the engine).

| Input | Result |
| --- | --- |
| `Claim your 500 USD reward.` | `money_claim`, **warning**, **LOW** |
| `Claim your 250 EUR prize.` / `1,000 dollars` / `5000 IQD bonus` | detected, LOW |
| `Congratulations on your new job!` | no signal |
| `You earned a reward for completing your training.` | no signal |
| `Claim your 10% discount at checkout.` | no signal — no currency marker |
| `Claim your 500 points before they expire.` | no signal — loyalty points, not money |

The indicator is translated into Arabic like every other one, and its title and
explanation name the actual trigger rather than restating a severity.

### Final bug-fix pass before submission

A hand test against the **committed** build reported four further failures.
Three of them had already been fixed in the uncommitted working tree and are
pinned by tests here for the first time; the fourth was a genuine defect that
had not been looked at before.

| Reported by hand | State of the working tree | Action |
| --- | --- | --- |
| `Your OTP: 482913. Do not share it with anyone.` → HIGH | Already **LOW** | Regression test added |
| `Congratulations on your new job!` → HIGH | Already **LOW**, no signals | Regression test added |
| `https://example.com/page?ref=site.com` → "downloads a .com program" | Already clean, **LOW** | Regression test added |
| `Claim your 500 USD reward.` → "No warning signs matched" | Already **LOW** with `money_claim` | Regression test added |
| Advice mentions a link the input does not contain | **Confirmed defect** | Fixed |
| Executable link not told not to download the file | **Confirmed defect** | Fixed |
| `verify` path described as proof of the page's content | **Confirmed defect** | Fixed |

> The manual test was run against the committed build (`8f5aa52`), not against
> the working tree. This is recorded rather than quietly re-tested, because the
> first four items were not defects at the time of reporting.

The three defects that were real:

* **The recommendation ignored whether a link existed.** The HIGH branch
  opened with a hard-coded "Do not open the link", so a message such as
  *"Your account will be suspended today. Send us your password and OTP…"*
  told the user to leave a link that was never in the message. The engine now
  passes `hasLink` and the wording adapts; a message with no link gets "Do not
  reply or send anything" instead. The same applied in Arabic.
* **No advice about the actual threat on an executable link.** For
  `…/download/report.exe` the critical signal is a program, but the advice
  only said not to type details into a page. A `hasDownload` flag was added to
  the `AppStrings.recommendation` contract (optional, defaults to `false`, so
  existing call sites are unaffected) and now says *"Do not download or run the
  file this link points to."*, replacing the generic page advice.
* **`checkpoint_path` asserted what a page it never opened contains.** The
  explanation read *"…which is where scammers ask people to confirm account
  details."* It now states the wording found in the path and says plainly that
  the page was never opened, so this is not evidence of what it asks for.

One further inconsistency was fixed while checking the advice: a message that
asks only for a password was told *"Do not transfer money or pay any fee"*,
because `wantsMoney` was fed by the same set that includes `sensitive_request`.
Money advice is now driven by a money-specific set (`payment_demand`,
`fee_request`, `combined_link_request`).

**Scoring was not touched.** No severity changed, no indicator was added or
removed, and no rule was weakened — only wording and the advice assembled from
signals that already fired.

*Verification:* `flutter analyze` — **No issues found**; `flutter test` —
**145/145 passed** (the 132 tests above plus 13 new ones covering the four
reported cases, the three recommendation defects, the preserved cases and the
Arabic advice).

### Audit round: wording accuracy and one real detection gap

A second hand test confirmed six cases behaved correctly. Two explanations
were then reviewed for factual accuracy, and a battery of benign and hostile
inputs was run to look for high-impact problems.

**Wording fixed (no rule or severity changed)**

* `sensitive_words` read *"Mentions private account information"* and told the
  user to treat it as suspicious. For a message that explicitly warns against
  sharing an OTP, that is an accusation the rule cannot support. The title now
  names what was actually matched ("a password, PIN or verification code") and
  the explanation states that mentioning one is **not a request** and that the
  message may simply be a warning.
* `money_claim` said the amount was one *"you did not earn"* and that the
  message asks for a payment *"next"*. The app can know neither. It now says
  only that the shape is a common lure and advises checking the sender.
  Arabic wording was rewritten to carry the same caveats.

**A confirmed detection gap, fixed**

The battery included `Send 0.5 BTC to this wallet to release your parcel.`
It returned **LOW with no signals at all**. The payment rule only matched the
full words `bitcoin`, `crypto` and `usdt`, so the form these demands actually
take — a transfer verb, an amount and a ticker — was invisible to it.

The fix requires a transfer verb, an amount and a ticker together, so it does
not fire on `I hold 3 ETH in my portfolio.` or `We send daily reports at 5pm.`

| Input | Before | After |
| --- | --- | --- |
| `Send 0.5 BTC to this wallet to release your parcel.` | **LOW, no signals** | **HIGH**, `payment_demand` |
| `Pay 250 USDT now to unlock your account.` | **LOW, no signals** | **HIGH**, `payment_demand` |
| `Transfer 0.05 ETH within 1 hour…` | LOW | HIGH |
| `Deposit 1,000 USDT to claim your prize.` | LOW | HIGH |
| `I hold 3 ETH in my portfolio.` | LOW | LOW ✅ unchanged |
| `We send daily reports at 5pm.` | LOW | LOW ✅ unchanged |
| `Buy gift cards and send me the codes now.` | HIGH | HIGH ✅ unchanged |

**Also checked and deliberately left alone**

* Trailing punctuation is stripped correctly (`…/pay.` → `…/pay`).
* `wikipedia.org/wiki/PayPal` raises a low `brand_in_path`; a raw IP host and
  `?token=abc123` score HIGH. These are defensible and were not weakened.
* `dl?f=setup.exe` is not treated as a download — extensions are read from the
  path only, which is a documented trade-off from the earlier round.

**Gemini**

The AI layer already speaks the OpenAI protocol, and Google exposes an
OpenAI-compatible surface, so **no code change was required**. A test was added
that drives a mock client with Gemini's base URL and model and asserts the
request lands on `…/v1beta/openai/chat/completions` with the right model and
that the response parses. **No live Gemini call was made**: no key exists in
the repository or in any build, and verifying one end to end would mean
embedding a key in a distributed APK, which is extractable. The rule-based
analysis is the product; AI remains an optional wording layer that never sets
a risk level.



### Rejected ideas (code review)

| Idea | Why rejected |
| --- | --- |
| Broad "any negation word means the message is safe" rule | Exactly the failure mode the review warned about; would have suppressed the pressure cases above |
| A large official-domain allowlist to fix lookalikes | Substitutes a longer list for a correct matching rule, and is unbounded work |
| Restoring substring matching for brand detection | Re-opens `pineapple` → Apple and `purchase` → Chase; the whole point of the review |
| Blanket severity downgrades for query parameters such as `token`, `secret`, `pin` | Not examined as a class, and not applied — no change was made to those rules |
| A narrow rule for `Claim your 500 USD reward.` at review time | Deferred; applied only after a separate, focused investigation showed a safe rule was possible |
| Catching `appleid-verify.xyz` / `amazonsupport.top` as brand matches | Requires substring-style matching; left as a documented limitation |
| Any redesign, new abstraction or performance work | Out of scope for a time-limited fix round |

### Known limitations recorded during this round

* Brand detection is **label-based on purpose**. `appleid-verify.xyz` and
  `amazonsupport.top` are not reported as Apple/Amazon impersonation; they are
  still reported through the generic wording and TLD rules where those apply.
  No heuristic can prove a domain safe or hostile from text alone.
* `/purchase/confirm` still raises a low `checkpoint_path` warning from the
  word `confirm`. That behaviour predates this round and is defensible for
  checkout paths; it was left unchanged.
* The rules match English text only, as stated in the UI and the README.
* **No Android device or emulator was available**, so nothing in this round was
  verified on a device. All evidence is unit tests and `flutter analyze`.

### Verification performed (code review round)

* `flutter analyze` — **No issues found**.
* `flutter test` — **132/132 passed**. The 50 original tests and the 36
  localisation tests were preserved unchanged except for one URL test whose
  assertion had encoded the double-reporting bug that was being fixed; that
  change is itself a regression test.
* The temporary scratch files used while reproducing the bugs were deleted
  before the final run.
* A non-Latin-character scan of `lib/` and `test/` confirms no stray text
  leaked into code outside the Arabic string file.

---

## 4. Challenge Card #1

### What the card asked for, and the organiser's clarification

The card describes a coding-assistant platform that relies on Gemini APIs and
requests a Google AI Studio fallback. The organiser clarified that the existing
project should be **adapted** to the challenge rather than have its core
purpose replaced, and that the aim is to show adaptability and creativity.

### Interpretation chosen

Scam Detection Field keeps its purpose: explain *why* a link or message may be
suspicious. The nearest honest equivalent of "keep working when the AI service
is unavailable" in this product is:

> the application must still produce a complete, useful risk assessment when
> the AI service cannot be reached.

That is what was built. **This is not a coding assistant and no claim is made
that it is.** No coding-assistant functionality was implemented, because
adding one would have replaced the product instead of adapting it.

### What the Phase 2 submission claimed

> The app continues to use rule-based analysis if AI becomes unavailable, so
> risk levels, explanations and recommendations remain available.

### Was that claim already true?

**Mostly yes.** `AnalysisEngine` has always computed the indicators, the risk
level and the recommendation *before* the AI block runs, so an AI failure
could never remove them. That part was preserved rather than duplicated.

**What was genuinely missing** was that a failure carried no information at
all. `catch (_)` discarded the reason, `explain()` returned a bare `null` for
a timeout and for a quota limit and for a broken body alike, and nothing in
the result or the UI could tell the three apart. So the fallback worked but
was invisible and undebuggable. This round made the *existing* fallback
observable and diagnosable.

### What changed

| File | Change | Why |
| --- | --- | --- |
| `lib/models/analysis_result.dart` | New `AiFailure` enum (`timeout`, `network`, `rateLimited`, `apiError`, `badResponse`, `unknown`) and a nullable `aiFailure` field on `AnalysisResult` | A fixed, secret-free category instead of an unexplained blank |
| `lib/services/ai_explainer.dart` | Failures now throw a typed `AiException` instead of returning `null`. Transport errors, 429, other error statuses and four unreadable-body shapes are classified separately | A quota problem is not an outage; the two must not look identical |
| `lib/analysis/analysis_engine.dart` | `on AiException` sets the category, a broad `catch` still falls back as `unknown`, and `debugPrint` writes the category | Diagnostics for developers without surfacing anything to the user |
| `lib/l10n/app_strings.dart`, `app_strings_ar.dart` | New `aiFailureNote(AiFailure)` and `errorUnexpected`, in both languages | The reason must be readable, and must be translated like everything else |
| `lib/screens/result_screen.dart` | The reason is shown under the fallback note, and is added to the copied report | A shared or screenshotted result must not hide the fallback |
| `lib/screens/home_screen.dart` | The generic catch no longer reports `errorEmptyInput` | Telling a user "type something first" for a defect they did not cause is a false message |

### What stayed unchanged

* Every detection rule, every threshold, and every earlier bug fix.
* The order of operations: rules → level → recommendation → *then* AI wording.
  The AI step still cannot change a risk level, an indicator, or the advice.
* The OpenAI-compatible client, the 20-second timeout, and the `--dart-define`
  configuration mechanism.
* No new dependency was added. `http` remains the only third-party package.
* No additional AI provider was introduced, so no second fallback provider is
  being claimed.

### What was rejected

* **A second AI provider as a "fallback provider".** Rejected: it would burn
  quota, add surface area, and manufacture a fallback claim the product does
  not need. The real fallback here is the deterministic analyzer.
* **Showing the raw provider response or the exception message to the user.**
  Rejected: it is confusing to a non-technical reader and is an unnecessary
  disclosure path.
* **Retrying the AI call automatically.** Rejected for this phase: a retry
  lengthens the wait for a result the user does not need, since the rule-based
  answer is already complete when the call is made.
* **A local proxy/backend to hold the key server-side.** Rejected for this
  phase: it cannot be deployed and verified inside the hackathon window, and
  an unverified deployment would be a worse claim than no deployment.

### Honesty of the claim

| Category | Item |
| --- | --- |
| **Implemented and tested** | Deterministic analysis for links and messages; AI failure → unchanged rule-based result; classification of timeout / network / 429 / HTTP error / unreadable body / unrecognised; the reason rendered on screen and in the copied report, in English and Arabic |
| **Implemented but not live-verified** | The AI request itself. It is exercised only through `MockClient`; **no live Gemini or OpenAI call has ever been made from this project** |
| **Simulated in tests** | Every provider answer: a 429, a 500, a timeout, an offline socket, malformed JSON, an empty `choices[]`, empty assistant text, and valid JSON in the wrong shape |
| **Not implemented** | Coding-assistant functionality; a backend proxy; automatic retries; any second AI provider |

### Security note on the key

The key is still read only through `String.fromEnvironment('AI_API_KEY')` and
is still absent from this repository, the source, and every build artifact on
disk. The new failure reporting was designed so it cannot change that: an
`AiException` carries a fixed enum plus at most a status code or a transport
message, and a test asserts that the configured key never appears in it.
Compile-time embedding is **not** secure storage for a distributed binary, so
the submitted APK stays rules-only.

---

## 5. Challenge Card #2

*Not yet received.*

---

## 6. Finalization

*Pending: final testing, bug fixes, APK generation, documentation check,
security review of the public repository, submission package.*

**State at the end of the audit round**

* `flutter analyze` — **No issues found**.
* `flutter test` — **153/153 passed** (52 base rule/engine/UI + 36
  localisation + 65 code-review, bug-pass and audit regression tests).
* Working tree: Arabic localisation, the review fixes and the final bug pass
  are complete but **not committed**. `HEAD` and the remote `main` both remain
  at `8f5aa52`.
* Rollback tag `mvp-baseline-v1` still points at `8f5aa52` and was not
  overwritten.
* No API key, keystore or temporary file is present in the working tree; the
  release APK from the initial build was never rebuilt with new credentials.

**State at the end of the Phase 2 (AI resilience) round**

* `flutter analyze` — **No issues found**.
* `flutter test` — **176/176 passed** (up from 164; +12 tests: 8 in
  `analysis_engine_test.dart` for failure classification, fallback parity and
  key non-disclosure, and 6 in `l10n_test.dart` for the localised reason, the
  on-screen rendering and the copied report).
* The whole suite is deterministic. **No test opens a network connection and no
  test uses a real key** — every provider answer is a `MockClient`, so no API
  quota is consumed.
* Working tree at the time of writing: the change is complete and verified but
  **not committed**. The last commit is `534d0fc`, which matches the remote.
* Rollback tag `mvp-baseline-v1` still points at `8f5aa52` and was not
  overwritten.
* No new dependency was added. No rule, threshold or earlier bug fix was
  modified.
* **No Android device or emulator was available**, so device testing was not
  performed and is not claimed. Evidence is unit tests, widget tests and
  `flutter analyze`.
* **Live Gemini integration was not verified**, because no key exists in this
  environment and no live call was made. See Challenge Card #1 above.
