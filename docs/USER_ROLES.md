# User roles — Lubowa Sports Park (Leagues & Teams)

## Where roles live

- **Identity:** WordPress users (same account for WP admin and app login via JWT).
- **Who can do what:** Stored in **WordPress** (one capability) and in **our DB** (league owner, team leader).

So: **WordPress** = who can log in and who is allowed to create a league. **Our tables** = who “owns” each league and who leads each team.

---

## Roles in practice

| Role | Who | Where set | Can do |
|------|-----|-----------|--------|
| **WordPress Admin** | User with `manage_options` | WordPress → Users | Everything: create/manage any league, any team, any player, scores. |
| **League creator / manager** | User who created the league | Set automatically when creating a league (`created_by` on league) | For **that league only:** create/edit/delete league, teams, players; generate fixtures; update scores; record goals. |
| **Team leader** | User assigned to a team | Set per team in WordPress admin or via API (`leader_user_id` on team) | For **that team only:** add/edit/delete players in that team; record goals for that team in fixtures. |
| **Player** | User linked to a player (`user_id` on player) | When creating/linking player | View “My career goals” (GET /me/player). No league/team management. |

---

## WordPress side

- **Capability (optional):** `create_lubowa_league`  
  - If you add this capability to a role (e.g. a custom “League manager” role), those users can **create** leagues from the app; they become the league’s **creator** for that league.  
  - By default only **Administrator** has full access; you can give “League manager” only this capability so they can create leagues but not touch WP settings.

**How to allow non‑admins to create leagues (optional):**

1. In WordPress: **Users → Add New** (or edit a user).
2. Either assign a role that has `create_lubowa_league`, or use a plugin that lets you add the capability to a role.
3. That user logs in in the app → can create a league → becomes league manager for that league.

If you don’t add the capability, only WordPress admins can create leagues (current behaviour).

---

## Our database (plugin)

- **`leagues.created_by`** (WP user ID, nullable)  
  - Set when a league is created (to the current user).  
  - “League manager” = user where `created_by = user_id`.

- **`teams.leader_user_id`** (WP user ID, nullable)  
  - Set when creating/editing a team (in WP admin or via API).  
  - “Team leader” = user where `leader_user_id = user_id` for that team.

---

## API permission rules (summary)

- **Create league:** Admin **or** user with `create_lubowa_league`. On create, set `created_by = current user`.
- **Manage league (update/delete league, add team, generate fixtures, etc.):** Admin **or** league’s `created_by`.
- **Manage team (update/delete team, add/edit/delete players in that team):** Admin **or** league’s `created_by` **or** team’s `leader_user_id`.
- **Record goals in fixture (POST /fixtures/<id>/goals):** Admin **or** league’s `created_by` **or** team’s `leader_user_id` for the team that scored.
- **List leagues (for “my” management):** Admin sees all; others see leagues where they are `created_by` or where they lead a team (see GET /me/league_roles).

---

## App: how to know what the user can do

- **GET /me/league_roles** (JWT)  
  Returns something like:  
  `{ "can_create_league": true, "managed_league_ids": [1, 2], "led_team_ids": [3, 5] }`  
  - Use `can_create_league` to show/hide “Create league”.  
  - Use `managed_league_ids` to show “Leagues I manage” and allow full management.  
  - Use `led_team_ids` to show “Teams I lead” and allow adding players / recording goals for those teams only.

- **GET /me/player**  
  If the user is linked to a player, show “My career goals”.

---

## Where to assign “team leader” and “league manager”

- **League manager:** No manual assignment. Whoever **creates** the league (in the app or in WP admin) is the league manager for that league. (Admins can still manage any league.)
- **Team leader:** Assigned **per team**:
  - **WordPress admin:** On the league’s “Manage” page, when adding or editing a team, choose a WordPress user as “Team leader” (dropdown). Plugin stores `leader_user_id` on the team.
  - **API:** PATCH `/teams/<id>` with `leader_user_id` (league manager or admin only).

So: **roles are enforced in the API and in the plugin;** the **app** only needs to call the API and optionally use GET /me/league_roles to show the right screens (Create league, Leagues I manage, Teams I lead, My career goals).
