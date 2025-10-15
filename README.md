# Stuffbi — Personal Inventory Management (Flutter)

Stuffbi is a clean, feature-first Flutter app for managing your personal inventory: bundles (bags/contexts), items, and quick checklists. This repo is set up for fast iteration, testing, and future sync (Firebase/Supabase).

---

## ✨ Current Status

- ✅ Splash screen → Login → Bundles (placeholder) flow with `go_router`
- ✅ Material 3 theming (brand blue: `Color.fromARGB(255, 0, 133, 250)`)
- ✅ “Under Development” reusable widget with asset image
- 🔜 Bundles grid (v1), Items checklist, Profile tab, local persistence, cloud sync

---

## 🚀 Quick Start

```bash
# Check your Flutter install (3.22+ recommended for .withValues())
flutter doctor

# Get deps
flutter pub get

# Run on device/emulator
flutter run -d <device_id>

# Common dev actions (in the running terminal)
r  # Hot reload
R  # Hot restart (back to first screen)
q  # Quit
```

---

## 📦 Project Structure

```
stuffbi/
├─ android/ ios/ web/ macos/ linux/ windows/
├─ assets/
│  ├─ images/
│  │  ├─ logo_stuffbi.png
│  │  └─ under_development.png
├─ lib/
│  ├─ app/
│  │  ├─ app.dart
│  │  ├─ router.dart
│  │  └─ theme/theme.dart
│  ├─ core/
│  │  └─ widgets/
│  │     └─ under_development.dart
│  ├─ features/
│  │  ├─ splash/presentation/splash_screen.dart
│  │  ├─ auth/presentation/login_screen.dart
│  │  ├─ bundles/presentation/bundles_screen.dart
│  │  └─ dev/presentation/under_development_screen.dart
│  └─ main.dart
├─ pubspec.yaml
└─ test/
```

---

## 🧭 Routing

Using `go_router`:

- `/splash` → Initial screen with logo + Start
- `/login` → Email/password form, “Continue as Guest”
- `/bundles` → Placeholder (will host Bundles grid)
- `/dev` → Under Development screen

Navigation examples:

```dart
context.go('/login');   // replace current
context.push('/dev');   // push onto stack (enables back)
context.pop();          // go back
```

---

## 🎨 Theming

**Brand color** is applied globally:

```dart
// lib/app/theme/theme.dart
const kBrandBlue = Color.fromARGB(255, 0, 133, 250);

final scheme = ColorScheme.fromSeed(
  seedColor: kBrandBlue,
  brightness: Brightness.light,
).copyWith(primary: kBrandBlue);

return ThemeData(
  useMaterial3: true,
  colorScheme: scheme,
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(kBrandBlue),
      foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
    ),
  ),
  // ... outlined/text/elevated button themes similarly
);
```

> Note: Code uses Material 3 surface containers (`surfaceContainerHigh`, etc.) and `.withValues(alpha: …)`. Use Flutter **3.22+**. If you’re on an older Flutter, temporarily replace `.withValues(alpha: 0.6)` with `.withOpacity(0.6)` (you’ll see a deprecation warning until you upgrade).

---

## 🖼️ Assets

Declare in `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

Place images here:

- `assets/images/logo_stuffbi.png`
- `assets/images/under_development.png`

After adding/changing assets:

```bash
flutter clean
flutter pub get
# then hot restart (R) or re-run
```

---

## 🔐 Auth (stub)

`LoginScreen` validates email/password locally and navigates to `/bundles`. Replace the TODO with your real auth (Firebase Auth / Supabase / custom API) under `features/auth/data/…` when ready.

---

## 🧩 Under Development Widget

Reusable component with asset image and smart back behavior.

```dart
UnderDevelopment(
  imageAsset: 'assets/images/under_development.png',
  title: 'Under Development',
  message: 'We’re crafting this feature for the next release.',
  primaryLabel: 'Back',
  onPrimary: () {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    else context.go('/bundles');
  },
);
```

Open it from Bundles with:

```dart
context.push('/dev');
```

---

## 🧪 Testing

Scaffold is ready for unit/widget tests:

```bash
flutter test
```

Add tests under `test/unit/` and `test/widget/`. For UI stability, consider golden tests in `test/golden/`.

---

## 🛠️ Troubleshooting

- **Asset not found**

  - Check exact file path & case (`assets/images/under_development.png`)
  - Ensure `pubspec.yaml` indentation (2 spaces)
  - `flutter clean && flutter pub get` then Hot Restart

- **`withValues` not found**

  - Upgrade Flutter: `flutter upgrade`
  - Temporary fallback: `.withOpacity(0.6)`

- **`context.go` not found**

  - Ensure `go_router` is installed and imported:

    - `flutter pub add go_router`
    - `import 'package:go_router/go_router.dart';`

- **Start from first screen**

  - Use **Hot Restart** (`R`) to reset app state

---

## 🗺️ Roadmap

- [ ] Bundles v1: search, sort, 2-column grid, edit actions
- [ ] Items list: checklist per bundle, filters
- [ ] Bottom navigation shell: Bundles / Items / Profile
- [ ] Local persistence (SharedPreferences/SQLite)
- [ ] Cloud sync (Firebase/Supabase), social login
- [ ] Theming: dark mode & accessibility pass
- [ ] Integration tests (goldens & flows)

---

## 🤝 Contributing

1. Create a feature branch
2. Keep changes feature-scoped (`features/<feature>/…`)
3. Add tests for non-trivial logic
4. Open a PR with screenshots/GIFs for UI updates

---

## 📄 License

MIT — do what you want, attribution appreciated.

---

## 🙌 Credits

Designed and built by the **Nova** group (UoM) — Stuffbi, a personal inventory manager.
