import 'package:flutter/material.dart';

const recenterTeal = Color(0xFF0F766E);

ThemeData recenterTheme() => _theme(Brightness.light);

ThemeData recenterDarkTheme() => _theme(Brightness.dark);

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: recenterTeal,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
  );
}
