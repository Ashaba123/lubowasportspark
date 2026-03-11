# App permissions (Android & iOS)

Track every permission the app needs from the user or the system. When adding a feature that requires a new permission, add it here and implement it for **both** Android and iOS in the same change set.

## Current permissions

| Permission / capability | Purpose | Android | iOS |
|-------------------------|---------|---------|-----|
| **Internet** | API calls, loading content from website | `AndroidManifest.xml`: `<uses-permission android:name="android.permission.INTERNET" />` (normal permission, auto-granted) | No declaration needed; network access is allowed by default. |
| **Photos / storage** | Upload profile avatar from gallery | `AndroidManifest.xml`: `android.permission.READ_MEDIA_IMAGES` (API 33+) or `android.permission.READ_EXTERNAL_STORAGE` (older). Requested at runtime by `image_picker`. | `Info.plist`: `NSPhotoLibraryUsageDescription` explaining why we access photos. |

## Future / planned (add when implementing)

| Permission / capability | Purpose | Android | iOS |
|-------------------------|---------|---------|-----|
| **Camera** | _e.g. profile photo, scan_ | `AndroidManifest.xml`: `android.permission.CAMERA`. Request at runtime if needed. | `Info.plist`: `NSCameraUsageDescription` (required). |
| **Location** | _e.g. find park, check-in_ | `AndroidManifest.xml`: `ACCESS_FINE_LOCATION` and/or `ACCESS_COARSE_LOCATION`. Request at runtime. | `Info.plist`: `NSLocationWhenInUseUsageDescription` (and optionally `NSLocationAlwaysUsageDescription`). |
| **Notifications** | _e.g. event reminders, booking confirmations_ | FCM / Firebase; no extra permission in manifest for basic push. | Enable Push Notifications capability in Xcode; no usage description. |

## How to add a permission

1. Add a row to the table above (Current or Future).
2. **Android**: Add `<uses-permission android:name="android.permission.…" />` in `android/app/src/main/AndroidManifest.xml`. For [dangerous permissions](https://developer.android.com/guide/topics/permissions/requesting), request at runtime (e.g. `permission_handler` or platform APIs).
3. **iOS**: Add the required usage description key(s) in `ios/Runner/Info.plist` (e.g. `NSCameraUsageDescription`). Add capabilities/entitlements in Xcode if needed (e.g. Push).
4. Update [.cursor/rules/flutter-mobile-dev-and-deploy.mdc](.cursor/rules/flutter-mobile-dev-and-deploy.mdc) if the permission list or patterns change.
