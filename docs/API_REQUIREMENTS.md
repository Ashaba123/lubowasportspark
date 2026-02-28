# API Requirements — Lubowa Sports Park Mobile App

Backend: **WordPress REST API** at `https://lubowasportspark.com`

- **Base URL:** `https://lubowasportspark.com/wp-json`
- **Auth:** Bearer JWT for protected routes. Send header: `Authorization: Bearer <token>`
- **Content-Type:** `application/json` for request bodies

**Data sources (MVP):**
- **Bookings & Leagues** — custom **Lubowa API** (same plugin: `lubowa/v1`). Bookings and all league/team/fixture/player endpoints live in this API.
- **Events** — WordPress **posts** (`wp/v2/posts`). The **website events page** uses this endpoint; events are regular posts; list/detail via WP REST.
- **Home, Activities, About, Contact** — WordPress **pages** (`wp/v2/pages`). App fetches by slug so content matches the website; slugs are configured in the app (e.g. `home`, `activities`, `about`, `contact`).

---

## Required for MVP

### 1. Authentication (existing)

| Item | Value |
|------|--------|
| **Namespace** | `jwt-auth/v1` |
| **Login** | POST `/jwt-auth/v1/token` |
| **Request** | `Content-Type: application/json`; body: `{ "username": "<string>", "password": "<string>" }` |
| **Response** | `{ "token": "<jwt>", ... }` — app stores token and sends as Bearer on subsequent requests |
| **Who** | Admin login for league management |

**Confirmed.** On 401, app should clear token and redirect to login.

---

### 2. Events (website events page)

The **website** has an events page; data comes from WordPress **posts**. Same endpoint is used by the app for events.

| Item | Value |
|------|--------|
| **Namespace** | `wp/v2` |
| **List** | GET `/wp/v2/posts` |
| **Query** | Optional: `?per_page=20`, `?page=1`, `?categories=<id>` if events use a specific category |
| **Single** | GET `/wp/v2/posts/<id>` |
| **Response** | Standard WP Post: `id`, `title` (object with `rendered`), `content` (object with `rendered`), `date`, `featured_media` (id for image), `excerpt` |
| **Image** | GET `/wp/v2/media/<id>` for featured image URL, or use `_embedded["wp:featuredmedia"]` if available |
| **Who** | Public (no auth) |

**Open point:** If the events page filters by category or custom post type, document the category ID or CPT slug and add to query params here.

---

### 2b. Pages (Home, Activities, About, Contact)

App screens that mirror the website use the same WordPress **pages** as the site.

| Item | Value |
|------|--------|
| **Namespace** | `wp/v2` |
| **By slug** | GET `/wp/v2/pages?slug=<slug>&_embed=1` |
| **Response** | Same as post: `id`, `title` (object with `rendered`), `content` (object with `rendered`), `featured_media`, `_embedded["wp:featuredmedia"]` for image URL |
| **Who** | Public (no auth) |

**App slugs** (match site): `home` (front page, /), `activities` (/activities/), `events1` (/events1/), `about-us` (/about-us/), `contact` (/contact/). App Events tab uses wp/v2/posts for the event list; optional: show intro/header from page `events1` above the list.

---

### 3. Bookings (Lubowa API — same plugin as leagues)

**Pitch bookings** can come from two places: (1) **Amelia plugin** on the website (calendar/website bookings), or (2) **Lubowa API** from the mobile app (POST `/lubowa/v1/bookings`). Admin may see website bookings in Amelia and app bookings under **Lubowa → App Bookings**. There should be a **link between booking the futsal pitch and creating a league**: when someone has booked the pitch (via Amelia or via the app), they can create a league (e.g. in the app) and optionally associate that league with their booking so the sports park ties the league to that pitch session. Backend may support an optional `booking_id` on league create (for Lubowa app bookings); Amelia bookings could use a reference field or remain linked by date/contact only.

| Item | Value |
|------|--------|
| **Submit** | POST `/lubowa/v1/bookings` |
| **Request body** | `{ "date": "YYYY-MM-DD", "time_slot": "...", "contact_name": "...", "contact_phone": "...", "contact_email": "...", "notes": "..." }` |
| **Response** | 201 + `{ "id": <int>, "status": "pending" }` |
| **List my bookings** | GET `/lubowa/v1/bookings?contact_email=<email>` — returns user’s `[{ id, date, time_slot, contact_name, status, created_at }, ...]` (no auth) |
| **Who** | Submit: public. List: public (by contact) or optional simple auth |

Bookings are submitted from the mobile app; admin sees them under **Lubowa → App Bookings** in WordPress. (My bookings: GET with contact_email; “My bookings” see table above.)

---

### 4. Leagues (Lubowa API — same plugin as bookings)

**Booking–league link:** Leagues are created by people who have (or will) use the futsal pitch. Pitch is booked via **Amelia** (website) or **Lubowa app** (POST `/bookings`). When someone has a booking, they can create a league in the app; optionally the league can be linked to that booking (e.g. `booking_id` when creating a league for Lubowa app bookings) so the park sees which session the league is for.

**User roles:** See [docs/USER_ROLES.md](USER_ROLES.md). In short: **League creator** = user who created the league (`created_by`). **Team leader** = user set per team (`leader_user_id`). Only admins or league creator can manage that league; only admin, league creator, or team leader can manage that team / record goals for it. **Who can create a league:** WordPress admin or any user with capability `create_lubowa_league` (assign in WordPress → Users).

**League rules (futsal):**
- **Minimum 2 teams** per league (required to generate fixtures).
- **Players per team:** minimum 1, maximum **8** (5 on pitch + 3 substitutes). Admin or team leader can add (new player joins), edit (name/goals), or delete (player leaves) at any time.
- **Legs:** number of fixtures per pair. 1 leg = one fixture per pair (3 teams → 3 fixtures: A vs B, A vs C, B vs C). 2 legs = two per pair (2 teams → A vs B, B vs A). Count = n×(n−1)/2 × legs.

**Scenario (Saturday flow):** Two groups (~10 people) come to the sports park. On the **app** they create a league, add 2 teams (e.g. 5v5 + subs, max 8 per team), add players. **Admin** (sports park) in WordPress generates fixtures; they start games, record goals/scorers, mark full time. **Next Saturday** they return and must see the same league and teams: they **log in with the same WordPress account** → GET `/leagues` returns leagues they created or lead a team in → they open the league → GET `/leagues/<id>/teams` shows their teams. Backend supports this; app League screen must implement login, list leagues, list teams, create league/teams/players (Phase B).

**League/team management (JWT — admin or league creator or team leader as per rules):**

| Operation | Method | Path (suggested) | Request / Response |
|-----------|--------|------------------|----------------------|
| Create league | POST | `/lubowa/v1/leagues` | Body: `{ "name": "...", "legs": 1, "booking_id": null }` → 201 + league. Optional `legs` (1–10). Optional `booking_id` (Lubowa app booking id) to link league to a pitch booking. Permission: admin or `create_lubowa_league`. |
| List leagues | GET | `/lubowa/v1/leagues` | → Leagues where current user is **creator** (`created_by`) or **team leader** (any team in league). Use so returning players see "their" league next week (same login). `{ id, name, code, legs, created_by, created_at }`. |
| List teams in league | GET | `/lubowa/v1/leagues/<id>/teams` | → `[{ id, name, leader_user_id }]`. Permission: league creator or team leader in that league. |
| Add team | POST | `/lubowa/v1/leagues/<id>/teams` | Body: `{ "name": "Team A", "leader_user_id": null }` — optional `leader_user_id` (WP user ID) = team leader. Permission: league creator or admin. |
| Add player | POST | `/lubowa/v1/teams/<id>/players` | Body: `{ "name": "...", "goals": 0, "user_id": null }`. **Max 8 per team** (5 + 3 subs); 400 if full. Optional `user_id` to link app user. When someone new joins, add here. |
| List team players | GET | `/lubowa/v1/teams/<id>/players` | → `[{ id, name, goals }]` — JWT required (for team leader to pick scorer) |
| Edit player | PATCH | `/lubowa/v1/players/<id>` | Body: `{ "name", "goals", "user_id" }`. Admin or team leader for that team. |
| Delete player | DELETE | `/lubowa/v1/players/<id>` | Remove player (e.g. left the team). Admin or team leader for that team. |
| Generate fixtures | POST | e.g. `/lubowa/v1/leagues/<id>/fixtures/generate` | Requires **at least 2 teams**. Uses league `legs` to create (double round-robin) × legs fixtures. → list of fixtures. |
| Update match score / date / start | PATCH | `/lubowa/v1/fixtures/<id>` | Body: `{ "home_goals", "away_goals", "result_confirmed", "match_date", "match_time", "started_at" }`. **match_date**: `YYYY-MM-DD`. **match_time**: e.g. `14:00`. **started_at**: `true` to set “kick-off” time. Set **result_confirmed: 1** to mark “Full time” (score locked for standings). **After full time:** score and result cannot be changed or cleared. Flow: Pending → **Start** (set started_at) → record goals (scorer required per goal) → **Full time** (result_confirmed: 1). |
| Record goal(s) in fixture | POST | `/lubowa/v1/fixtures/<id>/goals` | Body: `{ "player_id": <int>, "goals": <int> }`. **Required:** fixture must be started (`started_at` set); **blocked** after full time (`result_confirmed`). Each goal (or batch) must specify the **scorer** (`player_id`). Player must be in that fixture’s home or away team. JWT (admin / team leader). |
| Reset/reshuffle fixtures | POST | e.g. `/lubowa/v1/leagues/<id>/fixtures/reset` | — |
| Get league code | GET league | Included in league object | `code` used for public stats |

**Public (no auth):**

| Operation | Method | Path (suggested) | Request / Response |
|-----------|--------|------------------|----------------------|
| Stats by league code | GET | `GET /lubowa/v1/public/leagues/<code>` | → `{ league, standings, fixtures, top_scorers }`. **Standings** from confirmed results. **Fixtures** include `match_date`, `match_time`, `started_at`, `result_confirmed` (0/1); ordered by match_date then sort_order. |
| Results for a day | GET | `GET /lubowa/v1/public/leagues/<code>/results?date=YYYY-MM-DD` | → `{ league, date, results }`. **results**: confirmed fixtures for that date (default today). Use for “Results” / “Today’s results” page. |
| Leaderboard (all leagues) | GET | `GET /lubowa/v1/public/leaderboard` | → `{ leagues: [{ id, name, code, standings, top_scorers }], top_scorers_all }` for website display. |

**Player goal tracking (JWT):**

| Operation | Method | Path | Request / Response |
|-----------|--------|------|----------------------|
| My player (career goals) | GET | `/lubowa/v1/me/player` | → `{ id, name, team_id, goals, team_name, league_id, league_name }` or 404 if no player linked. Requires JWT. |
| Link player to user | POST | `/lubowa/v1/teams/<id>/players` | When creating player, pass `user_id` (WP user ID) to link. |
| Link existing player to (my) account | PATCH | `/lubowa/v1/players/<id>` | Body: `{ "user_id": <wp_user_id> }`. Non-admin can only set `user_id` to own id (claim player). |
| My league/team roles | GET | `/lubowa/v1/me/league_roles` | → `{ can_create_league: bool, managed_league_ids: [], led_team_ids: [] }`. Use in app to show “Create league”, “Leagues I manage”, “Teams I lead”. |

League code is generated by the backend when a league is created.

---

## Required for full app (post-MVP)

- Same as above; no additional endpoints strictly required. Optional: push notification endpoint, webhook for booking status updates, or richer league/player stats — to be added here when agreed.

---

## Summary table

| Area | Endpoint type | MVP | Auth |
|------|----------------|-----|------|
| Auth | `jwt-auth/v1` | Yes | — |
| Events | `wp/v2/posts` | Yes | No |
| Bookings | Custom | Yes (submit; list optional) | No (or by contact) |
| Leagues (admin) | Custom | Yes | Bearer JWT |
| Leagues (public) | Custom | Yes | No |

---

## Next steps

1. **Event taxonomy** (optional): If events use a specific category or custom post type, document the category ID or CPT slug and query params in §2 (Events).
2. App integration: Use this doc as the single source of truth for base URL, paths, and request/response shapes.
