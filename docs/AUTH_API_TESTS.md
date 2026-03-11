# Auth API manual test scripts

Use these quick commands or Postman to verify the Lubowa auth endpoints.

## 1. Email/password signup

- **Endpoint**: `POST /lubowa/v1/signup`
- **Request (JSON)**:
  - Success:
    - `{"email":"testsignup@example.com","password":"password123","name":"Test User"}`
  - Duplicate email:
    - repeat the same email → expect `409` with `error.code = "email_in_use"`.
  - Weak password:
    - `{"email":"weak@example.com","password":"short","name":"Weak"}` → expect `422` with `error.code = "weak_password"`.
- **Expected**:
  - `201 Created`
  - Body contains:
    - `token` (JWT string or `null` if JWT plugin unreachable)
    - `user.id`, `user.email`, `user.username`, `user.name`, `user.roles` including `lubowa_app_user`.

## 2. Google login

- **Endpoint**: `POST /lubowa/v1/google_login`
- **Request (JSON)**:
  - `{"id_token":"<paste valid Google ID token>","display_name":"Test Google User"}`
- **Expected**:
  - `200 OK`
  - Body contains:
    - non-empty `token` (JWT string)
    - `user.id`, `user.email`, `user.username`, `user.name`, `user.roles` including `lubowa_app_user`.

### Error cases

- Invalid token (`id_token` corrupted):
  - Expect `401` with `error.code = "google_token_invalid"`.
- Email not verified:
  - Expect `401` with `error.code = "google_email_unverified"` if Google returns `email_verified = false`.

## 3. League permissions as app user

1. Use the token from either signup or Google login.
2. Call `GET /lubowa/v1/leagues` with `Authorization: Bearer <token>`.
   - Expect `200` and an empty or populated list (no 403).
3. Call `POST /lubowa/v1/leagues` with a simple body (`{"name":"Test League","legs":1}`).
   - Expect `201 Created` when using a `lubowa_app_user` or admin token.

