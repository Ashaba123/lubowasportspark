# API Requirements — Lubowa Sports Park Mobile App

Backend: **WordPress REST API** at `https://lubowasportspark.com`

- **Base URL:** `https://lubowasportspark.com/wp-json`
- **Auth:** Bearer JWT for protected routes. Send header: `Authorization: Bearer <token>`
- **Content-Type:** `application/json` for request bodies

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

### 2. Events (existing)

| Item | Value |
|------|--------|
| **Namespace** | `wp/v2` |
| **List** | GET `/wp/v2/posts` |
| **Query** | Optional: `?per_page=20`, `?page=1`, `?categories=<id>` if events use a specific category |
| **Single** | GET `/wp/v2/posts/<id>` |
| **Response** | Standard WP Post: `id`, `title` (object with `rendered`), `content` (object with `rendered`), `date`, `featured_media` (id for image), `excerpt` |
| **Image** | GET `/wp/v2/media/<id>` for featured image URL, or use `_embedded["wp:featuredmedia"]` if available |
| **Who** | Public (no auth) |

**Open point:** Event taxonomy — all posts vs. specific category/custom post type. If filtered, document category ID or CPT slug and add to query params here.

---

### 3. Bookings (custom — to be confirmed)

| Item | Value |
|------|--------|
| **Purpose** | Submit futsal booking request; optionally list user bookings and status |
| **Submit** | POST `<custom path>` e.g. `/bookings` or `/lubowa/v1/bookings` |
| **Request body (suggested)** | `{ "date": "YYYY-MM-DD", "time_slot": "...", "contact_name": "...", "contact_phone": "...", "contact_email": "...", "notes": "..." }` |
| **Response** | 201 + `{ "id": ..., "status": "pending" }` or similar; backend triggers email to admin |
| **List/status (optional for MVP)** | GET `<custom path>` e.g. GET `/bookings?contact_email=...` or by session — returns list of user’s bookings with status |
| **Who** | Submit: public. List: public (by contact) or optional simple auth |

**Action:** Confirm path, request/response shape, and whether “My bookings” is in scope for MVP. Add exact paths and JSON once provided.

---

### 4. Leagues (custom — to be confirmed)

**User roles:** See [docs/USER_ROLES.md](USER_ROLES.md). In short: **League creator** = user who created the league (`created_by`). **Team leader** = user set per team (`leader_user_id`). Only admins or league creator can manage that league; only admin, league creator, or team leader can manage that team / record goals for it. **Who can create a league:** WordPress admin or any user with capability `create_lubowa_league` (assign in WordPress → Users).

**League/team management (JWT — admin or league creator or team leader as per rules):**

| Operation | Method | Path (suggested) | Request / Response |
|-----------|--------|------------------|----------------------|
| Create league | POST | `/lubowa/v1/leagues` | Body: `{ "name": "..." }` → 201 + league with `id`, `name`, `code`, `created_by` (current user). Permission: admin or `create_lubowa_league`. |
| List leagues | GET | `/lubowa/v1/leagues` | → Leagues user can manage (admin: all; else: where `created_by` = me or I lead a team). `{ id, name, code, created_by, created_at }`. |
| Add team | POST | `/lubowa/v1/leagues/<id>/teams` | Body: `{ "name": "Team A", "leader_user_id": null }` — optional `leader_user_id` (WP user ID) = team leader. Permission: league creator or admin. |
| Add player | POST | `/lubowa/v1/teams/<id>/players` | Body: `{ "name": "...", "goals": 0, "user_id": null }` — optional `user_id` (WP user ID) to link app user to player for “my career goals” |
| List team players | GET | `/lubowa/v1/teams/<id>/players` | → `[{ id, name, goals }]` — JWT required (for team leader to pick scorer) |
| Generate fixtures | POST | e.g. `/lubowa/v1/leagues/<id>/fixtures/generate` | → list of fixtures |
| Update match score | PATCH | `/lubowa/v1/fixtures/<id>` | Body: `{ "home_goals", "away_goals", "result_confirmed" }`. Set **result_confirmed: 1** to mark “Full time” (score then counts for points: win=3, draw=1, loss=0). |
| Record goal(s) in fixture | POST | `/lubowa/v1/fixtures/<id>/goals` | Body: `{ "player_id": <int>, "goals": <int> }` — player must be in that fixture’s home or away team; increments player’s career goals and fixture score. JWT (admin / team leader) |
| Reset/reshuffle fixtures | POST | e.g. `/lubowa/v1/leagues/<id>/fixtures/reset` | — |
| Get league code | GET league | Included in league object | `code` used for public stats |

**Public (no auth):**

| Operation | Method | Path (suggested) | Request / Response |
|-----------|--------|------------------|----------------------|
| Stats by league code | GET | `GET /lubowa/v1/public/leagues/<code>` | → `{ league, standings, fixtures, top_scorers }`. **Standings** include `points`, `played`, `won`, `drawn`, `lost`, `goals_for`, `goals_against` (from **confirmed** results only). **Fixtures** include `result_confirmed` (0/1). |
| Leaderboard (all leagues) | GET | `GET /lubowa/v1/public/leaderboard` | → `{ leagues: [{ id, name, code, standings, top_scorers }], top_scorers_all }` for website display. |

**Player goal tracking (JWT):**

| Operation | Method | Path | Request / Response |
|-----------|--------|------|----------------------|
| My player (career goals) | GET | `/lubowa/v1/me/player` | → `{ id, name, team_id, goals, team_name, league_id, league_name }` or 404 if no player linked. Requires JWT. |
| Link player to user | POST | `/lubowa/v1/teams/<id>/players` | When creating player, pass `user_id` (WP user ID) to link. |
| Link existing player to (my) account | PATCH | `/lubowa/v1/players/<id>` | Body: `{ "user_id": <wp_user_id> }`. Non-admin can only set `user_id` to own id (claim player). |
| My league/team roles | GET | `/lubowa/v1/me/league_roles` | → `{ can_create_league: bool, managed_league_ids: [], led_team_ids: [] }`. Use in app to show “Create league”, “Leagues I manage”, “Teams I lead”. |

**Action:** Confirm paths, request/response shapes, and whether league code is generated by backend or app. Document here once provided.

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

1. Confirm or provide exact base path and routes for **bookings** and **leagues** (e.g. namespace and path for each action).
2. Confirm **event taxonomy** (all posts vs. category/CPT) and document query params in this file.
3. Confirm **league code** format and who generates it (backend vs. app).
4. After confirmation, update this doc with final paths and JSON; app will use it as single source of truth for integration.
