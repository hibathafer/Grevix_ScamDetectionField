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
that the response parses. **No live Gemini call was made in this round**: no
key exists in
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
* **Retrying the AI call automatically.** Rejected for this phase: a *blind*
  retry lengthens the wait for a result the user does not need, since the
  rule-based answer is already complete when the call is made. A later round
  replaced this blanket rejection with a single, deliberately narrow fallback
  to Google's own native endpoint — see *Google AI Studio fallback* below. It
  is not a retry loop: it runs at most once per analysis, never for a 429, and
  never without a configured key.
* **A local proxy/backend to hold the key server-side.** Rejected for this
  phase: it cannot be deployed and verified inside the hackathon window, and
  an unverified deployment would be a worse claim than no deployment.

### Honesty of the claim

| Category | Item |
| --- | --- |
| **Implemented and tested** | Deterministic analysis for links and messages; AI failure → unchanged rule-based result; classification of timeout / network / 429 / HTTP error / unreadable body / unrecognised; the reason rendered on screen and in the copied report, in English and Arabic |
| **Implemented but not live-verified** | The AI request itself, on both endpoints. Every test drives a `MockClient`, so **the automated suite makes no live call at all**. The builder separately reports local runs with their own key (see *Google AI Studio fallback* below); the maintainer's environment has no key and no device, so no live call was reproduced there, and **the Google AI Studio fallback has never been exercised against a live service** |
| **Simulated in tests** | Every provider answer: a 429, a 500, a timeout, an offline socket, malformed JSON, an empty `choices[]`, empty assistant text, and valid JSON in the wrong shape — now on the primary path *and* on the native fallback path |
| **Not implemented** | Coding-assistant functionality; a backend proxy; blind automatic retries or a retry loop; **any second AI provider** — the fallback is Google's own native endpoint reached with the same key, not a different vendor |

### Security note on the key

The key is still read only through `String.fromEnvironment('AI_API_KEY')` and
is still absent from this repository, the source, and every build artifact on
disk. The new failure reporting was designed so it cannot change that: an
`AiException` carries a fixed enum plus at most a status code or a transport
message, and a test asserts that the configured key never appears in it.
Compile-time embedding is **not** secure storage for a distributed binary, so
the submitted APK stays rules-only.

---

### Gemini verification round

The Phase 2 work proved the *fallback*. This round checked whether the AI path
itself would actually work against Gemini if a key were supplied, without
making a live call.

**What was checked, and against what.** Google's own pages — *OpenAI
compatibility* (`ai.google.dev/gemini-api/docs/openai`, retrieved 11 October
2026, page last updated 2 September 2026) and *Deprecations* (`…/deprecations`,
last updated 9 October 2026).

**Confirmed correct, so left alone.** The implementation already matches the
documented contract exactly:

| Contract element | Google documents | This project |
| --- | --- | --- |
| Base URL | `https://generativelanguage.googleapis.com/v1beta/openai/` | same |
| Path | `POST …/chat/completions` | same, built by stripping the trailing slash and appending the segment |
| Auth | `Authorization: Bearer <key>` | same (not `x-goog-api-key`, which belongs to the native API) |
| Request body | `{"model": …, "messages": [{role, content}]}` | same, plus `temperature` and `max_tokens` |
| Response | `choices[0].message.content` | same |

Both the link path and the message path reach it: `AnalysisEngine.analyze`
calls the explainer once per submission, whatever the `InputKind`.

**What was genuinely broken, and was fixed.**

1. **The documented model was dead.** The README told users to run
   `--dart-define=AI_MODEL=gemini-2.0-flash`. Google's deprecation table shows
   `gemini-2.0-flash` shut down on **1 June 2026** — before this round. Anyone
   following the README today would have got an error and a silent fallback,
   and would reasonably have concluded the integration was broken. The README
   and the test fixture now use `gemini-3.8-flash`, the model Google's current
   examples use, which has no announced shutdown date.
2. **The output budget could starve the answer.** Gemini 3.x models think by
   default and Google states reasoning counts towards the same output budget.
   At `max_tokens: 400` a thinking model could spend the whole budget on
   reasoning and return an empty `content`, which this project treats as a
   failed reply. Raised to 1024. The reply stays short regardless, because the
   prompt asks for 2-3 sentences and at most 3 observations. **This is a
   precaution taken from Google's documented behaviour, not a measured result.**

**What was added.**

* `env.ai.example.ps1` — a committed template with an **empty** key line. Copy
  it to `env.ai.ps1`, paste the key, run it. Typing `--dart-define` by hand
  puts the key in shell history; the script avoids that.
* `env.ai.ps1` added to `.gitignore`, verified with `git check-ignore`.
* A test asserts the committed template contains no key-shaped string, that
  its key line is empty, and that `.gitignore` really covers `env.ai.ps1`.

**What remains unverified.**

**No live Gemini request has been made from this environment.** There is no
API key here, and none of the automated tests opens a socket. Everything above
is a contract check against Google's documentation plus deterministic tests
with a mock client. A live call is a manual step for the person holding the
key, using `env.ai.ps1`; the builder reports having run the app that way on
their own machine, which is recorded below as **user-reported development
testing** and not as a result of this suite.

---

### Google AI Studio fallback round

Two pieces of work are recorded together because they sit in the same
uncommitted working tree: the **debug diagnostic** that names the failure
reason, and the **Google AI Studio fallback** that gives the AI step a second
way to reach Gemini.

**Why.** Challenge Card #1 asks for a Google AI Studio fallback. The
interpretation chosen at the start of section 4 still stands — this product is
not a coding assistant — but the engineering half of the card is now
implemented literally rather than only argued for: when the OpenAI-compatible
request fails, the app tries Google's own native `generateContent` endpoint
once before it gives up on the explanation.

**What changed.**

| File | Change | Why |
| --- | --- | --- |
| `lib/services/ai_explainer.dart` | `explain()` split into an orchestrator plus `_explainPrimary`, `_explainNative`, `_postJson`, `_shouldFallBack` and `_nativeEndpoint` | The two paths share one prompt builder and one failure translator, so their error handling cannot drift apart |
| `lib/services/ai_explainer.dart` | The native endpoint is derived from the configured base URL and built **only** for `generativelanguage.googleapis.com`, with the `/openai` suffix stripped | A non-Google OpenAI-compatible provider must never receive a Gemini-shaped request |
| `lib/models/analysis_result.dart` | New nullable `aiFailureDetail` field beside `aiFailure` | The fixed enum cannot carry the detail a developer needs, e.g. `HTTP 404` |
| `lib/screens/result_screen.dart` | An `AI diagnostic: …` line rendered only when `kDebugMode` is true, and never added to `buildReport` | Developers get the exact reason; nobody can copy a diagnostic into a shared report |
| `lib/analysis/analysis_engine.dart` | Fills `aiFailureDetail` in both catch branches | The detail belongs where the exception is already classified |
| `env.ai.example.ps1` | `-Device` default changed from `chrome` to empty, plus runtime selection of the first supported Android device via `flutter devices --machine`, falling back to `chrome` with a warning | The old default pinned every run to the browser even with a phone attached |

**How the fallback is selected.**

1. AI not configured → `explain()` returns before any socket is opened, so
   **neither request is made.**
2. The primary runs first and always: `POST {base}/chat/completions`.
3. If it succeeds, nothing else happens — the fallback is never attempted.
4. If it fails, the failure category decides: `timeout`, `network`, `apiError`
   (any status other than 200 and 429) and `badResponse` allow **one** native
   attempt; `rateLimited` and `unknown` allow **none**. A 429 belongs to the
   credential, so the same key would only be refused again, and retrying an
   unclassified error is a guess.
5. The native attempt runs at most once per analysis, strictly after the
   primary, never in parallel, and only when the endpoint could be derived.
6. If it also fails, the **primary's** failure is the one reported — it is the
   configured path and the reason the fallback ran at all.
7. In every case the engine returns the rule-based result unchanged.

The native request carries the key in an `x-goog-api-key` **header**, never in
the query string, so a transport error that quotes a URL cannot leak it.

**What stayed unchanged.** Every rule, every threshold, the scoring order
(level computed before the AI block), the recommendation, the 20-second
per-request timeout, the `--dart-define` configuration, and `http` as the only
third-party dependency. **No second AI provider was added** — both paths are
Google's, reached with the same key and the same model.

**Tests added** — seven, in `test/analysis_engine_test.dart`, all against
`MockClient`, none opening a socket:

| Test | What it pins down |
| --- | --- |
| primary HTTP failure rescued by the native fallback | exactly 2 requests, the OpenAI path then `…/models/<model>:generateContent`, `rulesAndAi`, `Authorization` on the primary, `x-goog-api-key` and an empty query string on the fallback |
| transport failure on the primary is rescued as well | a thrown `ClientException` reaches the fallback too |
| both the primary and the fallback fail | exactly 2 requests, `rulesWithAiFallback`, `HTTP 503` reported, level / indicators / recommendation identical to a no-AI run |
| HTTP 429 never triggers the fallback | exactly **1** request, `rateLimited` |
| missing configuration makes neither request | **0** requests, `rulesOnly`, no failure recorded |
| the rules never change whatever the AI outcome is | level, indicators, advice and headline identical across primary success, fallback success, both failing, 429, and both timing out |
| no failure detail from either path can carry the key | six failure shapes; the detail never contains the key, `Bearer`, `Authorization` or `goog-api-key` |

**User-reported development testing — not automated, not reproduced here.**
The builder reports having performed AI explanation tests on a physical
Android phone (A201XM, Android 14, reached over wireless ADB) through
`env.ai.ps1`, and separately in a browser. Earlier in the same work the builder
also reported a timeout on that device and an error status in the browser,
which is what motivated the failure classification and the debug diagnostic
above. This is recorded **on the builder's report** and is kept strictly apart
from the test suite: it needs a key and a device the repository does not carry,
it is not reproducible from the repository alone, no log from it is quoted as
a test result, and the maintainer's environment — which has neither a key nor
an Android device — could not reproduce it.

**What is still not verified.**

* **The Google AI Studio fallback has never been called against the live
  service.** Only its `MockClient` tests exist. The native request and response
  shape was written from Google's published `generateContent` documentation,
  not measured against the API, and no test in this repository consumes quota.
* No Android device or emulator exists in the maintainer's environment, so no
  device testing is claimed for the automated evidence.
* The submitted APK is unchanged: **built without `--dart-define`, it carries
  no embedded API key and AI explanations are not configured in it** — it runs
  `rulesOnly`.

---

## 5. Challenge Card #2 — tester feedback round

### What arrived

Not a written card this time, but two genuine technical reports from people
who used the app. Both are recorded verbatim-by-paraphrase in
[`feedback/README.md`](feedback/README.md), with the commenters' names
withheld.

| # | Reported by | The report |
| --- | --- | --- |
| A | A tester studying cybersecurity | Pasting random text into the **Link** tab returned **LOW RISK** instead of an invalid-input error |
| B | A website owner | A reassuring result on his own websites read as *"free of any vulnerabilities"*; he also asked whether the scan really takes only a few seconds |

Both reports were correct. Neither was a style complaint.

### Feedback A — invalid input was being scored

**The defect.** `AnalysisEngine.analyze` called `analyzeLink(text)` for
whatever the Link tab held. Free text produced zero indicators, zero points
and therefore **LOW RISK** — a clean bill of health for a check that had
never run. The old test at `analysis_engine_test.dart` even pinned this as
intended behaviour (`a non-URL pasted into the link analysis still returns a
result`); that test was **replaced**, not deleted, because it was asserting
the bug.

**What changed.**

| File | Change |
| --- | --- |
| `lib/analysis/input_classifier.dart` | New `validateLink()` returning `null` or a `UrlRejection` (`hasSpaces`, `unsupportedScheme`, `missingHost`, `malformed`). Pure parsing; **never opens the address** |
| `lib/models/analysis_result.dart` | New `InvalidUrlException`, documented as producing no risk level |
| `lib/analysis/analysis_engine.dart` | Validates **before** `analyzeLink()`, so the scorer is never reached with an invalid address |
| `lib/screens/home_screen.dart` | Pre-checks with the same validator so the message appears without waiting, and offers the existing **Switch to Message** action. The typed text is left in the field, so the user can correct and retry |
| `lib/l10n/app_strings.dart`, `app_strings_ar.dart` | New `errorInvalidUrl` in both languages: *"Invalid URL — Please enter a valid website link to analyze."* |
| `test/url_validation_test.dart` | **New file**, 14 tests |
| `test/app_test.dart` | +3 widget tests, including the correct-and-retry flow |

**Accepted.** `http`/`https`, a bare domain, `www.`, an optional port, a raw
IPv4 host and `localhost`. **Refused.** Free text, `ftp:`, `file:`,
`javascript:`, `mailto:`, `data:` and `ws:`, an address with no host, and
anything whose last label cannot be a TLD (`3.14`, `a.b`, `999.1.1.1`).

**What stayed unchanged, on purpose.**

* Every rule, threshold and the scoring order. Validation is a *gate*, not a
  rule.
* `https://example.com` is still **LOW RISK**. That result was never evidence
  of a defect, and valid behaviour was not altered to make a test differ.
* Raw IP hosts such as `192.168.0.1` stay valid — the rules flag them on
  purpose, and refusing them first would hide that signal.
* Message analysis is independent of URL validation and is unaffected.

**`errorLinkContainsSpaces` was removed**, not merely superseded: one message
for every invalid link is clearer than three, and the Message tab is still
offered by the error box. This is a **breaking change to the `AppStrings`
interface** — any future third language must supply `errorInvalidUrl`.

**Recorded limitation.** The validator is deliberately stricter than a
browser. A gTLD outside `[a-z]{2,63}`, or an internationalised domain typed
in Unicode rather than punycode, is refused as malformed. Refusing a rare
valid address is the safer of the two errors; the alternative is scoring
random text as a link.

### Feedback B — a link result was read as a security scan

**The defect.** Not a code defect but a communication one. The app never
opens the site, yet the only thing standing between a LOW RISK result and
"my website is clean" was a generic line saying the result "cannot prove that
something is safe". Nothing said what *was* checked. The speed was itself the
clue — there is no scan — and that went unexplained.

**What changed.** A new `linkScanScopeNote`, in both languages, rendered only
for a **link** result, in the "About this analysis" card and in the copied
plain-text report:

> This is not a security scan. The app reads the web address only and never
> opens or tests the website, so LOW RISK means no common warning signs were
> found in the link - not that the site is safe or free of vulnerabilities.

Message results do not show it, because they make no website claim.

**What deliberately did *not* change.**

* The scan was **not slowed down**. Speed was never the problem, and adding
  an artificial delay would have been theatre.
* **No vulnerability scanning was added, and none is claimed.** The app still
  performs no network request against the address.

### Honest status of this round

| Category | Item |
| --- | --- |
| **Implemented and tested** | URL validation gate (14 unit tests + 3 widget tests); the refusal message in English and Arabic; the correct-and-retry flow; the link-scope note on screen and in the copied report |
| **Implemented but not live-verified** | Nothing in this round makes a network request at all, so there is no live-service claim to make |
| **Simulated in tests** | Every invalid shape: free text, malformed addresses, missing hosts, five unsupported schemes, and the port/host ambiguity (`localhost:8080`) |
| **Not implemented** | Website or vulnerability scanning of any kind; a browser-grade URL parser; any new detection rule |

### Documentation and artefacts

* `feedback/README.md` — both items, what changed, what did not, and the
  privacy policy. Commenters are not named.
* `feedback/screenshots/` — **six screenshots supplied by the builder are
  listed but not committed.** They could not be written into the repository by
  the tooling used, and must be added by hand, with each commenter's consent
  confirmed first.
* README: the input-validation step added to the *How it works* diagram, an
  explicit "a link result is not a security scan" paragraph, a new *Feedback*
  section, a URL-validator entry under *Known limitations*, and the test count
  corrected to 205.
* Historical test counts in earlier rounds were **left as they were** — 177,
  176 and 153 are accurate for the rounds they belong to.

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
* `flutter test` — **176/176 passed** (up from 164; +12 tests: 6 in
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

**State at the end of the Gemini verification round**

* `flutter analyze` — **No issues found**.
* `flutter test` — **177/177 passed** (+1: a test guarding the committed
  AI config template against carrying a secret).
* The integration contract was checked against Google's published *OpenAI
  compatibility* and *Deprecations* pages on 11 October 2026. The endpoint,
  auth scheme, request body and response parsing were already correct and were
  left unchanged. Two things were wrong and were fixed: the README recommended
  `gemini-2.0-flash`, shut down on 1 June 2026, and `max_tokens: 400` was too
  small for Gemini 3.x thinking models.
* Added `env.ai.example.ps1` (committed, empty key line) and git-ignored
  `env.ai.ps1`, so a key can be supplied locally without reaching shell
  history, a commit, or this log.
* **No live Gemini request was made.** Still no API key in this environment.
  Nothing in this round is claimed to have been tested against the real API.
* No new dependency. No rule, threshold or fallback behaviour was modified.

**State at the end of the debug-diagnostic and Google AI Studio fallback
round**

* `flutter analyze` — **No issues found.**
* `flutter test` — **188/188 passed** (up from 177; +11 tests: 4 for the debug
  diagnostic — 2 in `analysis_engine_test.dart`, 2 in `l10n_test.dart` — and 7
  for the Google AI Studio fallback in `analysis_engine_test.dart`). The
  earlier `177/177` above is the historical count of the round it belongs to;
  this line is the current one.
* Test files now stand at `analysis_engine_test.dart` **30**,
  `l10n_test.dart` **44**.
* The whole suite is deterministic. **No test opens a network connection and no
  test uses a real key** — every answer on both AI paths is a `MockClient`, so
  no API quota is consumed.
* Working tree: the change is complete and verified but **not committed**, and
  nothing is staged. `HEAD` and the remote `main` both remain at `a8421bf`.
  Seven files are modified: `env.ai.example.ps1`,
  `lib/analysis/analysis_engine.dart`, `lib/models/analysis_result.dart`,
  `lib/screens/result_screen.dart`, `lib/services/ai_explainer.dart`,
  `test/analysis_engine_test.dart`, `test/l10n_test.dart`.
* Rollback tag `mvp-baseline-v1` still points at `8f5aa52` and was not
  overwritten.
* No new dependency. No rule, no threshold and no scoring order was modified;
  the level is still computed before the AI block runs.
* **No API key is present** in the source, in the repository, in the committed
  `env.ai.example.ps1`, or in this log. `env.ai.ps1` stays untracked.
* **The fallback is not live-verified.** Its evidence is seven mock tests and
  `flutter analyze` only. See *Google AI Studio fallback round* above.
* **No Android device or emulator was available** in this environment, so
  device testing is not claimed. The builder's phone runs are recorded as
  user-reported development testing, not as automated results.

**State at the end of the tester-feedback (Challenge Card #2) round**

* `flutter analyze` — **No issues found.**
* `flutter test` — **205/205 passed** (up from 188; +17: a new
  `test/url_validation_test.dart` with 14 tests, and +3 widget tests in
  `test/app_test.dart`). One pre-existing test was **replaced**, not deleted:
  `a non-URL pasted into the link analysis still returns a result` was
  asserting the defect the tester reported.
* Test files now stand at `analysis_engine_test.dart` **30**,
  `url_validation_test.dart` **14**, `l10n_test.dart` **44**,
  `app_test.dart` **9** (6 `testWidgets`), `message_rules_test.dart` **25**,
  `url_rules_test.dart` **18**, `review_regressions_test.dart` **62
  statements / 65 cases** (one is inside a four-entry loop).
* **No test opens a network connection.** `validateLink` parses an address
  with `Uri` and a regex; it never fetches it, and no AI call is involved in
  this round.
* **Breaking change to the `AppStrings` interface:** `errorLinkContainsSpaces`
  was removed and `errorInvalidUrl` and `linkScanScopeNote` were added. A
  future third language must supply all three.
* No rule, threshold or scoring order was modified. Validation is a gate in
  front of `analyzeLink`, not a detection rule, and it only runs for
  `InputKind.link`.
* The Google AI Studio fallback from the previous round is **untouched**.
* Working tree: complete and verified but **not committed**, nothing staged.
  `HEAD` and the remote `main` both remain at `a8421bf`.
* Rollback tag `mvp-baseline-v1` still points at `8f5aa52` and was not
  overwritten.
* No new dependency. No API key anywhere in the source, repository, committed
  template or this log; `env.ai.ps1` stays untracked.
* **Six feedback screenshots are listed but not committed** — see
  `feedback/README.md`. They must be added by hand, with each commenter's
  consent confirmed first.
* **No Android device or emulator was available**, so device testing is not
  claimed for this round either. Nothing in this round needed a device: the
  change is pure Dart plus widget tests.
