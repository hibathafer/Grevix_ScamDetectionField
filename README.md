# Scam Detection Field

**Check a suspicious link or message before you act on it.**

Scam Detection Field is a mobile-first Flutter app that helps ordinary people
answer one question about a digital message they just received:

> **"Why should I be suspicious of this?"**

It does not pretend to know with certainty whether something is a scam. It
shows the *warning signs it actually found*, explains each one in plain
language — English or Arabic — and gives a practical next step.

---

## The problem

Phishing and message scams work because they are designed to make people act
in a hurry: a fake delivery notice, a bank "suspension" warning, a prize, a
password request.

Most people who receive such a message have no safe way to check it. They
either click, or they forward it to a friend and guess. Existing tools tend to
answer "safe / unsafe" with no explanation, which teaches people nothing and
builds false confidence.

## Who it is for

* Everyday smartphone users who receive suspicious SMS, WhatsApp or e-mail
  messages.
* People who are not technical and need a plain-language reason, not a score.
* Anyone who wants a second opinion *before* clicking, paying or replying.

## The solution

1. Paste a **link** or a **message**.
2. The app runs transparent checks against well-known scam patterns.
3. You get:
   * a **risk level** — LOW / MEDIUM / HIGH,
   * **why** — every signal found, with a plain-English explanation,
   * **what to do next** — a practical recommendation,
   * an honest **limitation** note about what the tool can and cannot prove.

---

## Key features

* Link analysis and message analysis in one screen.
* More than 40 transparent checks covering, among others:
  * **Links** — brand impersonation, credential wording inside a domain,
    punycode/homograph characters, text before `@`, raw IP hosts, link
    shorteners, suspicious domain endings, many sub-domains/dashes/digits,
    `http://` connections, unusual ports, credential parameters in the query
    string, executable downloads, heavily encoded addresses.
  * **Messages** — urgency and deadlines, threats, requests for passwords /
    PINs / one-time codes, unusual payment demands (gift cards, crypto or
    tickers such as `0.5 BTC`, wire transfer), "release fee" requests, fake
    prizes, an unsolicited command to claim a stated cash amount, authority
    impersonation, secrecy requests, too-good-to-be-true offers,
    click-and-reply pressure, generic greetings, chain-forwarding,
    off-platform contact.
* A **request is distinguished from a warning.** "Never share your PIN" and
  "Do not send your password to anyone" are security advice and are not
  reported as a request, while "Do not hesitate to provide" and "unless you
  send your PIN" still are.
* **Combination rule** — a link *plus* a genuine request for money or private
  details in the same message is treated as a strong signal. Mentioning a fee
  and including a link is not enough on its own.
* Every signal is shown with its **title, explanation, severity and source**
  (link or message).
* **Advice that fits the input.** The recommendation is assembled from the
  signals that actually fired: a message with no link is never told to leave a
  link alone, an executable link is told not to download or run the file, and
  a URL path such as `verify` is reported as a wording clue rather than as
  proof of what the destination page asks for.
* **Copy report** — the result can be copied as plain text and shared.
* Optional **AI explanation** (see below) that never changes the risk level.
* Works **fully offline** for the core analysis: no network is required to get
  a risk level and reasons.

## How it works

```
user input
   │
   ├── input detection (link vs. message, links inside a message)
   │
   ├── deterministic rules  ── url_rules.dart / message_rules.dart
   │        each match → Indicator {title, explanation, severity, source}
   │
   ├── risk scoring (risk_scorer.dart)
   │        warning = 1 point, critical = 5 points
   │        any critical signal            → HIGH
   │        7+ points from warnings        → HIGH
   │        2–6 points                     → MEDIUM
   │        0–1 points                     → LOW
   │
   ├── recommendation builder (rules + which signals fired)
   │
   └── optional AI step (services/ai_explainer.dart)
            adds a plain-language explanation only
            NEVER changes the risk level
```

The score is intentionally simple so it can be explained. The app does **not**
display a "confidence percentage", because no such number would be honest
here.

## AI usage

AI is used where it genuinely adds value: turning a list of technical signals
into a short explanation an everyday person can follow.

* The AI step sends the input, the risk level and the matched signals to an
  OpenAI-compatible chat-completions endpoint and asks for a short summary.
* **The risk level, the reasons and the recommendation all come from the
  deterministic rules.** AI only adds wording.
* Every response state is handled: not configured, HTTP error, timeout,
  network failure, rate limit, malformed response. In all of those cases the
  app falls back to the built-in explanations and says so in the UI
  ("An AI explanation was requested but could not be completed").
* **No API key is stored in this repository.** The key is passed at build or
  run time with `--dart-define`.

Enable it:

```bash
flutter run \
  --dart-define=AI_API_KEY=sk-... \
  --dart-define=AI_BASE_URL=https://api.openai.com/v1 \
  --dart-define=AI_MODEL=gpt-4o-mini
```

`AI_BASE_URL` accepts any OpenAI-compatible endpoint, so local or alternative
providers can be used — including Gemini through Google's OpenAI-compatible
surface:

```bash
flutter run \
  --dart-define=AI_API_KEY=<your-key> \
  --dart-define=AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/ \
  --dart-define=AI_MODEL=gemini-2.0-flash
```

Without these values the app runs on rules only, which is the default, the
mode used in the submitted APK, and the only mode that has been verified end to
end here. **The Gemini path is wired and covered by a test that checks the
request shape against a mock client, but no live Gemini call has been made** —
no key is stored in this repository, in the source, or in any build artifact,
and verifying a live call would mean embedding a key in a distributed APK,
which is extractable. Treat the rule-based analysis as the product and AI as
an optional wording layer.

### When AI is unavailable

The deterministic analysis is computed **before** the AI step is attempted,
so the risk level, the reasons and the recommendation already exist by the
time the request goes out. If AI cannot be used, the app returns that same
rule-based result **unchanged** — nothing is invented, nothing is dropped,
and the analysis never fails or hangs because of it.

| Situation | Mode shown on the result | What happens |
| --- | --- | --- |
| No `AI_API_KEY` in this build | `rulesOnly` | No request is made at all |
| AI answered and the wording was usable | `rulesAndAi` | AI wording is added; the risk level is untouched |
| AI failed, timed out, was rate limited, or answered badly | `rulesWithAiFallback` | The rule-based result is returned as-is |

The "About this analysis" card always states which of the three applied. A
fallback additionally adds one line naming the reason in plain language: a
timeout, an unreachable service, too many requests, an error status, or a
reply the app could not read. The same note is included when the report is
copied, so a shared or screenshotted result never hides a fallback.

A failure carries only that fixed category. It never carries the key, the
request URL, or a raw provider response. In debug builds the category is also
written to the developer console, which is enough to tell a quota problem
from an outage.

The request times out after 20 seconds, so the user is never left waiting
indefinitely.

## Architecture

```
lib/
├── main.dart / app.dart            app entry, theme wiring, locale state
├── l10n/
│   ├── app_strings.dart            AppStrings contract + EnglishStrings
│   ├── app_strings_ar.dart         ArabicStrings (UI text + 41 indicators)
│   └── strings_scope.dart          InheritedWidget carrying AppStrings
├── theme/app_theme.dart            colours, risk styling
├── models/analysis_result.dart     Indicator, AnalysisResult, enums (pure Dart)
├── analysis/
│   ├── input_classifier.dart       link vs message, link extraction
│   ├── url_rules.dart              deterministic URL checks
│   ├── message_rules.dart          deterministic message checks
│   ├── risk_scorer.dart            signals → LOW/MEDIUM/HIGH
│   └── analysis_engine.dart        orchestration, recommendation, l10n mapping
├── services/ai_explainer.dart      optional AI explanation (dart-define)
├── screens/
│   ├── home_screen.dart            paste → analyse
│   └── result_screen.dart          risk, reasons, advice, copy report
└── widgets/                        risk header, indicator tile, section card
```

Models are pure Dart, so the whole analysis pipeline is unit-testable without
a device.

## Tech stack

* Flutter 3.44.6 / Dart 3.12.2
* Material 3
* [`http`](https://pub.dev/packages/http) — the only third-party dependency,
  used solely for the optional AI call
* `flutter_localizations` (SDK, first-party) — Arabic Material widgets and
  built-in strings. It pulls in [`intl`](https://pub.dev/packages/intl)
  transitively, which is the only package added to `pubspec.lock`; no
  third-party package was added for localisation
* Flutter built-in test framework - 176 tests

## Setup

```bash
flutter pub get
```

Run:

```bash
flutter run                 # any connected device
flutter run -d chrome       # quick check in the browser
```

Test:

```bash
flutter analyze             # static checks
flutter test                # 176 tests (rules, engine, AI fallback, UI, l10n)
```

Build the release APK:

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Arabic (العربية) support

The interface is available in **English and Arabic**, switchable at runtime
from the language button in the app bar.

* **English is the default.** The choice is **not persisted** — it lasts for
  the session and the next launch starts in English again. Persisting it
  would have meant adding `shared_preferences`, which was not worth one
  feature.
* **The switch is immediate** — no restart and no re-open. Tapping
  *العربية* rebuilds the app under `Directionality.rtl` with the Arabic
  strings.
* **Arabic is display-only. It does not add Arabic detection.** The rule
  catalogue still matches English text, so an Arabic-only scam message will
  *not* be flagged. The app says so explicitly in the UI
  (`ArabicStrings.detectionCoverageNote`), shown on both the home screen and
  the result screen, so a shared or screenshotted result is never read out of
  context.
* **Detection output is identical in both languages.** Rules emit their
  English result with a stable `id` and `severity`; only wording is
  localised at display time. Switching language can never change a risk
  level, and tests assert this.
* Facts inside prose keep their original form: hostnames, brand names,
  `paypal.com`, `xyz` and the URL the user typed are reproduced verbatim in
  the Arabic copy — including the copy report, whose headings follow the
  selected language while the user's own input stays untouched.
* The brand name **"Scam Detection Field"** stays in Latin script in both
  languages, as is normal for app names.
* The optional AI prompt stays English (AI is disabled in the default build).

### Verification

* `flutter test` — 36 localisation tests covering: the default language,
  Arabic strings being genuinely Arabic, Arabic count agreement
  (`1 إشارة واحدة`, `2 إشارتان`, `5 إشارات`), `Directionality` being RTL in
  Arabic and LTR in English, runtime switching in both directions without a
  restart, identical `RiskLevel` / indicator `id` / `severity` across both
  languages, the coverage note appearing only in Arabic, copy-report
  contents, and no layout overflow on a 360×640 phone in either language.
* `flutter build web --release` opened in a browser: switching to العربية
  flips the layout — the two header buttons move from the right edge
  (`x=720`, `x=760` on an 800 px viewport) to the left edge (`x=0`,
  `x=40`), `document.documentElement.lang` becomes `ar`, Material's own
  built-in strings become Arabic, and the console stays clean.
* **Not verified on a device:** screenshots were unavailable because the
  browser runs headless (`browser.screenshot` needs a visible tab), and
  there is **no Android device or emulator** connected in this environment.
  RTL was therefore verified on web and by widget tests only.

## Known limitations

* The analysis is **pattern based**. A brand-new scam that uses none of the
  listed patterns can be scored LOW. The result is a set of reasons, not a
  guarantee.
* The app **never opens, visits or downloads** the link, so it performs no
  real-time domain-reputation or malware check. This is deliberate: the app
  must not put the user's device at risk.
* Brand impersonation uses a **fixed list of common brands** and matches on
  whole labels in the hostname, so `pineapple.com` is not mistaken for Apple.
  The trade-off is that creative spellings the rules do not strip are missed:
  `appleid-verify.xyz` and `amazonsupport.top` are **not** reported as
  Apple/Amazon impersonation. They are still reported through the generic
  domain-word and suspicious-ending checks where those apply, but no
  heuristic can prove a domain safe or hostile from its text alone.
* The **warning-versus-request distinction is heuristic.** Security advice
  such as "never share your PIN" is deliberately not treated as a request, but
  an unusual phrasing that mixes both could be read either way. When in
  doubt the app reports the signal rather than staying silent.
* The **detection rules match English text only.** The interface is
  translated into Arabic, but Arabic *content* is not analysed — an Arabic
  scam message can pass unflagged, and the app states this limitation
  directly in the UI rather than hiding it.
* The AI explanation requires network access and a configured key; it is not
  part of the default build.
* Built and tested on Windows: the APK is produced and verified; the iOS
  bundle was not built in this environment.
* The release APK is signed with the default debug keystore (Flutter
  template default), which installs and runs normally. A dedicated release
  keystore would be needed only for store-grade publishing, and would be kept
  out of version control.

## Challenge evolution

Recorded in [BUILD_LOG.md](BUILD_LOG.md) as each hackathon challenge card is
received (what was asked, the interpretation chosen, what changed and why).

## Demo script

1. **Problem** — show a realistic scam message (urgency + password + link).
2. **Input** — paste it in the app (or tap *Try a suspicious message*).
3. **Analysis** — tap *Analyse it*.
4. **Result** — HIGH RISK, then read 2–3 of the reasons out loud.
5. **Advice** — the "What you should do" box.
6. **Honesty** — point at the limitation note and the "About this analysis"
   section: the app never claims certainty.
7. **Evolution** — *(challenge-specific step added in the build log)*.

## License

Provided for the hackathon submission. Third-party packages keep their own
licenses (see `pubspec.yaml` and `pubspec.lock`).
