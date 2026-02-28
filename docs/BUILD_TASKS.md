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
- [x] Activities screen (align with website; list offerings e.g. Futsal, Car Wash)
- [x] About Us screen (logo, short copy — sports, fitness, community)
- [x] Contact screen (link to website contact / open in browser)
- [x] CI: `.github/workflows/ci.yml` (analyze, test, debug APK, iOS build — no codesign)
- [x] Release: `.github/workflows/release-android.yml` (AAB on tag/manual)
- [x] Glass UI (glassmorphism): shared widget; bottom nav bar and home card; performance-conscious (BackdropFilter in few places only)

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

### League (roles & management)

- [ ] **User roles:** Backend supports league creator (`created_by`), team leader (`leader_user_id`). See [docs/USER_ROLES.md](USER_ROLES.md). Optional: in WordPress assign `create_lubowa_league` to a role so non-admins can create leagues.
- [ ] Login (JWT); GET `/me/league_roles` → show “Create league” if `can_create_league`; “Leagues I manage” and “Teams I lead”.
- [ ] Create league (if allowed) → user becomes league manager for that league
- [ ] Add teams (optional: set team leader via API or WordPress admin)
- [ ] Add players (league manager or team leader for that team)
- [ ] Generate fixtures / enter scores (league manager or admin)
- [ ] Record goals in fixture (league manager or team leader for that team)
- [ ] Mark fixture **Full time** (PATCH `result_confirmed: 1`) so result counts for points (W=3, D=1, L=0); standings rank by points
- [ ] Reset fixtures; copy league code for public stats

### League (player goals / career)
- [ ] Link logged-in user to player: set `user_id` when creating player (POST with `user_id`) or PATCH `/lubowa/v1/players/<id>` with `{ "user_id": <mine> }` to claim existing player
- [ ] GET `/lubowa/v1/me/player` (JWT): show “My career goals” for logged-in player
- [ ] Team leader flow: list team players (GET `/lubowa/v1/teams/<id>/players`), then POST `/lubowa/v1/fixtures/<id>/goals` (player_id, goals) for a player in that fixture

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
- **User roles:** Implemented in plugin (league creator, team leader). Assign team leader in WordPress admin (Leagues → Manage → team “Team leader” dropdown) or via API PATCH `/teams/<id>` with `leader_user_id`. To let non-admins create leagues, add capability `create_lubowa_league` to a role (e.g. custom “League manager”) in WordPress.
- **Leaderboard page (WordPress):** Create a page and add shortcode `[lubowa_leaderboard]` to show top leagues (standings with points, W/D/L), top teams per league, and top scorers (per league + “all leagues”). API: GET `/lubowa/v1/public/leaderboard`.
