# zenpose

ZenPose is a Flutter app for posture/pose training with optional Supabase-backed
auth and sync.

## Environment Setup

This project reads Supabase config from compile-time Dart defines:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Use a local `.env` file in the repo root:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
```

To start quickly:

1. Copy `.env.example` to `.env`.
2. Fill in your real Supabase project URL and anon key.

If `.env` is missing or empty, the app still runs, but auth/sync remain
unconfigured by design.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

## Build

Use the same env file for builds:

```bash
# Android APK
flutter build apk --dart-define-from-file=.env

# Android App Bundle
flutter build appbundle --dart-define-from-file=.env

# iOS (macOS only)
flutter build ios --dart-define-from-file=.env

# Web
flutter build web --dart-define-from-file=.env
```

## Test

```bash
flutter test
```

You can also run tests with the env file explicitly:

```bash
flutter test --dart-define-from-file=.env
```
