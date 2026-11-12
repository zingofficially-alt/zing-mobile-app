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
