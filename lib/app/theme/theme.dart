import 'package:flutter/material.dart';

const kBrandBlue = Color.fromARGB(255, 0, 133, 250); // #0085FA

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: kBrandBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: kBrandBlue, // ensure primary = exact brand blue
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,

    // Buttons pick from the scheme; force exact brand where needed:
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(kBrandBlue),
        foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? kBrandBlue.withValues(alpha: 0.12)
              : null,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(kBrandBlue),
        side: WidgetStatePropertyAll(BorderSide(color: kBrandBlue)),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? kBrandBlue.withValues(alpha: 0.06)
              : null,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(kBrandBlue),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? kBrandBlue.withValues(alpha: 0.08)
              : null,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(kBrandBlue),
        foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
        shadowColor: WidgetStatePropertyAll(kBrandBlue.withValues(alpha: 0.25)),
        elevation: const WidgetStatePropertyAll(1),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
  );
}
