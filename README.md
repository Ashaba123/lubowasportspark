# Lubowa Sports Park — Mobile Application

Flutter-based Android and iOS app for **Lubowa Sports Park**, integrating with the WordPress backend at [lubowasportspark.com](https://lubowasportspark.com/) via REST APIs. Provides booking, event viewing, and football league management (admin).

---

## System Architecture

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Android & iOS) |
| Backend | WordPress (REST API) |
| Data | JSON over HTTPS |
| Auth | Admin login via secure API endpoint |

## Features

### Booking
- View available futsal time slots
- Submit booking requests from the app
- Booking data sent to WordPress backend
- Admin receives booking request via email (manual confirmation)
- No online payments
- Booking status visible in the app

### Events
- Display upcoming tournaments and promotions
- Fetch event data from WordPress via API
- Show event details, images, and dates
- Auto-update when events are added on the website

### League Management (Admin)
- Admin login required
- Create leagues (unique league names)
- Teams have unique names within a league
- Minimum one player per team; players start with zero goals
- Admin updates match scores and goals
- Automatic fixture generation
- Admin can reset and reshuffle fixtures
- System generates league code for public stats viewing
