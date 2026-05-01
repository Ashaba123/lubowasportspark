# Lubowa Sports Park — Mobile Application

Flutter-based Android and iOS app for **Lubowa Sports Park**, Kampala. Integrates with the WordPress backend at [lubowasportspark.com](https://lubowasportspark.com/) via REST APIs. Provides booking, event viewing, and football league management.

---

## System Architecture

| Layer      | Technology                                      |
| ---------- | ----------------------------------------------- |
| Frontend   | Flutter (Android & iOS)                         |
| Backend    | WordPress REST API + custom Lubowa API plugin   |
| Data       | JSON over HTTPS                                 |
| Auth       | JWT via WordPress (`jwt-auth/v1`)               |
| Storage    | SharedPreferences (JWT + user cache)            |

---

## Features

### Booking

- View available futsal time slots per day
- Submit booking requests from the app
- Booking confirmation screen with **Share** button and **Add to Calendar**
- Admin receives requests under WordPress → Lubowa → App Bookings

### Events

- Fetch events (WordPress posts) — images, dates, full detail
- **Upcoming / Past filter** tabs on events screen
- Empty state when no events available
- Pull-to-refresh

### League Management

- Any logged-in user can **create a league**
- League creators: add teams, players, generate fixtures, record scores and goals
- Team leaders: manage players and record goals for their team
- Public stats view: enter league code → see standings, fixtures, top scorers (no login)
- Public league entry shows **league name + team count preview** before confirming
- **Contact the organizer** WhatsApp button on league entry screen

### Profile & Auth

- **Profile gate**: tapping Profile shows a loading skeleton while checking JWT, then navigates to profile (logged in) or login screen (not logged in)
- Profile shows career goals, leagues managed, teams led
- Send Feedback dialog in Settings (emails `info@lubowasportspark.com`)

---

## Design

Material 3, green theme — no blue anywhere.

| Token               | Value                       |
| ------------------- | --------------------------- |
| Primary             | `#2E7D32`                   |
| Primary container   | `#4CAF50`                   |
| Secondary           | `#00897B`                   |
| Secondary container | `#A5D6A7` (light green)     |
| Background          | `#F5F5F5`                   |

Typography: Poppins via `google_fonts`.

---

## Development

```bash
flutter run                      # run on device
flutter build apk                # debug APK
flutter build appbundle          # release AAB for Play Store
flutter analyze                  # lint
flutter test                     # unit/widget tests
dart run flutter_launcher_icons  # regenerate app icon
```

- **API contract:** [docs/API_REQUIREMENTS.md](docs/API_REQUIREMENTS.md)
- **Build tasks:** [docs/BUILD_TASKS.md](docs/BUILD_TASKS.md)
- **Design system:** [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md)
- **User roles:** [docs/USER_ROLES.md](docs/USER_ROLES.md)
- **Play Store campaign:** [14day_task_plan.md](14day_task_plan.md)
- **Tester feedback:** [tester_feedback.md](tester_feedback.md)

Signing config is in `android/app/build.gradle` — do not modify without the keystore.
