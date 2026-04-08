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

If you run from Android Studio/IntelliJ, add this in **Additional run args**:

```bash
--dart-define-from-file=.env
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

## Pose Template Training + Evaluation

`generate_pose_templates.py` now includes a full evaluation pipeline so you can
validate accuracy before adopting new templates into the app.

It will:

1. Split dataset into `train / validation / test` (default `70/15/15`).
2. Train class templates from `train` only.
3. Evaluate on held-out `validation` and `test` using Euclidean-distance
   nearest-template classification (same style used in-app).
4. Save metrics + confusion matrix + pass/fail gate results.

### Run

```bash
python generate_pose_templates.py
```

### Outputs

- `assets/pose_templates.json` (templates used by Flutter app)
- `build/pose_eval/split_manifest.json` (split IDs for reproducibility)
- `build/pose_eval/evaluation_report.json` (accuracy, macro F1, per-class metrics, confusion matrix, gate result)

### Quality Gate (default)

The pipeline blocks adoption (non-zero exit code) if any fail:

- Validation macro F1 `< 0.80`
- Test accuracy `< 0.85`
- Test macro F1 `< 0.85`

Tune thresholds if needed:

```bash
python generate_pose_templates.py \
  --min-val-macro-f1 0.85 \
  --min-test-accuracy 0.90 \
  --min-test-macro-f1 0.90
```

Disable gate if you only want a report:

```bash
python generate_pose_templates.py --disable-gate
```
