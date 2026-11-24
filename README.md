# zing

MARKETING MASTRY

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Secrets / API keys

API keys are kept out of source control in a git-ignored `.env` file at the
project root.

1. `cp .env.example .env` and fill in the values.
2. Run Flutter with the file: `flutter run --dart-define-from-file=.env`
   (the VS Code "ZING" launch configs already pass this flag).
3. Android reads `.env` automatically during the Gradle build.
4. iOS: run `pod install` in `ios/` after editing `.env`; it generates the
   git-ignored `ios/Flutter/Secrets.xcconfig` used by `Info.plist`.

Never commit `.env`. `google-services.json` and `GoogleService-Info.plist` are
Firebase client config files and stay in the repo.

## Database migrations

SQL lives in `supabase/migrations` and is applied in order:

| File | Adds |
|---|---|
| `0001_schema.sql` | Tables, Row Level Security, storage buckets |
| `0002_recommendations.sql` | `recommend_products()` |
| `0003_order_delivery.sql` | Delivery fee/address, storage policies |
| `0004_order_rules.sql` | `place_order()`, order status rules and history, stock reservation, order notifications, store opening hours |
| `0005_store_expiry.sql` | `expire_store_access()` (daily, pg_cron) and re-activation on payment |

Apply one with the Supabase CLI, or `node server/scripts/db-apply.js supabase/migrations/0004_order_rules.sql`.

Orders are created only through `place_order()`: the database prices the items,
checks and reserves stock and adds the delivery fee, so the app cannot set a
price. A customer can cancel only a Pending order; the store moves it one step
at a time or cancels it, and cancelling puts the stock back.

Notifications reach the app through Supabase Realtime. Phone push notifications
while the app is closed are not built yet (they need an FCM/APNs sender such as
an Edge Function that reads a device-token table).
