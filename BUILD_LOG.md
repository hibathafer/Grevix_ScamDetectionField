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

---

## 2. Challenge Card #1

*Not yet received.*

When received this section will record: what the card literally asked, the
intended goal, the interpretation chosen, what changed, what stayed, what was
added or removed, what AI suggested, what the builder decided, and what was
rejected.

---

## 3. Challenge Card #2

*Not yet received.*

---

## 4. Finalization

*Pending: final testing, bug fixes, APK generation, documentation check,
security review of the public repository, submission package.*
