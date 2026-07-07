# Firebase Cloud Messaging setup

Cashier accounts are **Windows and Linux desktop only**. Visit billing alerts use **local desktop notifications** (polling every 45s while the app is open). FCM is optional for future Windows push; Linux relies on polling.

## Cashier desktop

- Supported: **Windows**, **Linux** (`.deb` build)
- Not supported: Android, iOS, macOS, web
- Login on unsupported devices shows **Cashier desktop only** and signs out

## Doctor completes visit → cashier notified

1. Doctor taps **Complete** on a visit with billable items (products linked).
2. On the **same branch**, cashier desktop app polls `/visits?status=completed` and shows a system notification.
3. Cashier taps notification → visit detail → **Bill**.

## Optional FCM (Windows desktop background)

1. Create a Firebase project and run `flutterfire configure` from `mobile/`.
2. Backend `.env`:
   ```env
   FCM_ENABLED=true
   FCM_PROJECT_ID=your-firebase-project-id
   FCM_CREDENTIALS=/absolute/path/to/firebase-service-account.json
   ```
3. Register tokens only from `windows` or `linux` platform (enforced by API for cashiers).
4. Run `php artisan queue:work`.

## Re-seed roles after updates

```bash
cd backend && php artisan db:seed --class=RolePermissionSeeder
```
