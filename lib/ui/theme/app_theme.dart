import 'package:flutter/material.dart';

/// Centralized theme: colors, spacing, phone dimensions.
/// Palette: White, White Smoke, Brilliant Azure, Prussian Blue, Ink Black.
class AppTheme {
  AppTheme._();

  // Palette (from design)
  static const Color white = Color(0xFFFFFFFF);
  static const Color whiteSmoke = Color(0xFFF5F4F6);
  static const Color brilliantAzure = Color(0xFF098DF1);
  static const Color prussianBlue = Color(0xFF161B33);
  static const Color inkBlack = Color(0xFF0D0C1D);

  // Phone frame (default aspect ratio ~9:19.5)
  static const double phoneMaxWidth = 400;
  static const double phoneAspectRatio = 9 / 19.5;
  static const double phoneBorderRadius = 40;
  static const double phoneDefaultHeight = phoneMaxWidth / phoneAspectRatio;

  // Spacing
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // Semantic colors (from palette)
  static const Color background = whiteSmoke;
  static const Color surface = white;
  static const Color primary = brilliantAzure;
  static const Color primaryDark = Color(0xFF0670C4);
  static const Color labelPrimary = inkBlack;
  static const Color labelSecondary = Color(0xFF4A4D5C);
  static const Color labelTertiary = Color(0xFF6B6B7A);

  // App accents
  static const Color messagesAccent = brilliantAzure;
  static const Color galleryAccent = Color(0xFF7B5FB8);
  static const Color settingsAccent = Color(0xFFE68A00);

  // Chat bubbles
  static const Color bubbleSelf = brilliantAzure;
  static const Color bubbleOther = white;
  static const Color bubbleOtherBorder = Color(0xFFE0E0E5);

  // Legacy aliases
  static const Color tintBlue = primary;
  static const Color backgroundGrey = background;
  static const Color navBarBackground = surface;
}
