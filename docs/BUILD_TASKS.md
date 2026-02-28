# Build task list — Lubowa Sports Park Flutter app

Tracks progress against the [Flutter App & CI/CD Plan](.cursor/plans/). Update checkboxes as you complete work.

---

## Phase A — API doc + project bootstrap

- [x] Create `docs/API_REQUIREMENTS.md` (endpoints, auth, MVP vs full app)
- [x] Create `docs/DESIGN_SYSTEM.md` (colors, typography, logo)
- [x] New Flutter project in repo; structure `lib/core`, `lib/features/*`, `lib/shared`
- [x] API client (Dio) + JWT interceptor + 401 handling
- [x] Token storage abstraction (in-memory for bootstrap)
- [x] App theme from design system
- [x] Shield logo in `assets/logo.png`; in-app logo widget; app icon sets (Android/iOS) via `flutter_launcher_icons`
- [x] Main shell: Home (logo + tagline), Events, Book, League tabs
- [x] CI: `.github/workflows/ci.yml` (analyze, test, debug APK, iOS build — no codesign)
- [x] Release: `.github/workflows/release-android.yml` (AAB on tag/manual)

**Phase A status: Done**

---

## Phase B — MVP (client presentation)

### Events

- [ ] Fetch events from `wp/v2/posts` (list)
- [ ] Event detail screen (title, content, image, date)
- [ ] Pull-to-refresh on events list
- [ ] Optional: filter by category if backend uses one (document in API_REQUIREMENTS)

### Booking

- [ ] Booking form: date, time slot, contact (name, phone, email), notes
- [ ] Submit to backend (custom endpoint when available)
- [ ] Show “request sent” / success state
- [ ] Optional: “My bookings” or status list if API supports it

### League (admin)

- [ ] Admin login screen (username/password → JWT via `jwt-auth/v1`)
- [ ] After login: create league (unique name)
- [ ] Add teams (unique names within league)
- [ ] Add players (min 1 per team, goals start at 0)
- [ ] Generate fixtures
- [ ] Enter/update match scores (and player goals if needed)
- [ ] Reset / reshuffle fixtures
- [ ] Copy or display league code for public stats

### League (public)

- [ ] Screen to enter league code
- [ ] View standings and results (read-only) using public endpoint

**Phase B status: Not started** (screens are placeholders until endpoints/contract confirmed)

---

## Phase C — Client review

- [ ] Present MVP build to client
- [ ] Capture feedback and change list for Phase D

---

## Phase D — Full app

- [ ] Implement MVP feedback from client review
- [ ] Remaining polish (UX, error handling, empty states)
- [ ] Store metadata: listing copy, screenshots; prepare for release

---

## Phase E — Deploy Android

- [ ] Version bump in `pubspec.yaml`; build number increasing
- [ ] Build release AAB (CI or local)
- [ ] Google Play Console: store listing, content rating, target audience
- [ ] Upload AAB; internal/closed/production track as needed

---

## Phase F — Publish iOS (App Store)

iOS is built in CI from Phase A; this phase is about **publishing** to the App Store.

- [ ] iOS signing: certificates, provisioning profile (secrets in CI)
- [ ] Build IPA (CI or Xcode)
- [ ] App Store Connect: metadata, screenshots
- [ ] Submit for review
- [x] Add iOS job to CI workflows (done: `build-ios` in `ci.yml`)

---

## Open / blocked

- **Booking & league endpoints:** Confirm or provide exact paths and request/response shapes; update `docs/API_REQUIREMENTS.md`. App will wire to them once agreed.
- **Event taxonomy:** Document whether events = all posts or a category/CPT; use same in app.
- **League code:** Document who generates it (backend vs app) and format in API_REQUIREMENTS.
