import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tail_app/constants.dart';

// ── Brand palette ─────────────────────────────────────────────────────────────
// Source: Brand Guide v3 / Tail Company Design System
const Color tcBlue = Color(0xFF0275D8); // primary interactive
const Color tcOrange = Color(0xFFE46E26); // signature — use sparingly
const Color tcTeal = Color(0xFF21A58F); // secondary / positive
const Color tcNavy = Color(0xFF14374A); // ink / dark surface
const Color tcYellow = Color(0xFFF4CC48); // warm accent / glow

// Extended ramps used in theming
const Color _blue500 = Color(0xFF0961B2);
const Color _blue600 = Color(0xFF0A4D8B);
const Color _teal500 = Color(0xFF198573);
const Color _teal100 = Color(0xFFC0E9DF);
const Color _teal800 = Color(0xFF146658);
const Color _orange100 = Color(0xFFFADCC4);
const Color _orange600 = Color(0xFFA2480F);
const Color _gray0 = Colors.white;
const Color _gray25 = Color(0xFFFAFBFC);
const Color _gray50 = Color(0xFFF4F6F8);
const Color _gray100 = Color(0xFFE9EDF1);
const Color _gray200 = Color(0xFFD7DEE4);
const Color _gray400 = Color(0xFF8C99A4);
const Color _gray700 = Color(0xFF313B42);

// Dark surfaces
const Color _dark0 = Color(0xFF0A1219);
const Color _dark1 = Color(0xFF0E1A22);
const Color _dark2 = Color(0xFF131F28);
const Color _dark3 = Color(0xFF162633);
const Color _dark4 = Color(0xFF1A2B37);
const Color _dark5 = Color(0xFF213444);
const Color _dark6 = Color(0xFF2A3F50);

// ── Radii ─────────────────────────────────────────────────────────────────────
const double radiusSm = 10.0; // inputs, small chips
const double radiusMd = 14.0; // dialogs, list tiles
const double radiusLg = 20.0; // cards
const double radiusXl = 28.0; // bottom sheets, large panels
const double radiusPill = 64.0; // buttons (pill shape)

// Fonts
const String titleFont = "Fredoka";
const String bodyFont = "HankenGrotesk";

// Border thickness
const double standardBorderWidth = 1.5;
const double thickBorderWidth = 2;

final ValueNotifier<DynamicSchemeVariant> dynamicSchemeVariant = ValueNotifier(
  DynamicSchemeVariant.tonalSpot,
);
final ValueNotifier<double> luminanceThreshold = ValueNotifier(0.6);

ThemeData buildTheme(Brightness brightness, Color seedColor) {
  final bool isLight = brightness == Brightness.light;
  final bool isCustomColor = seedColor == Color(appColorDefault);
  // Prevent colors that are too light or dark
  HSLColor hslColor = HSLColor.fromColor(seedColor);
  HSLColor newHslColor = HSLColor.fromAHSL(
    hslColor.alpha,
    hslColor.hue,
    hslColor.saturation.clamp(0.4, 1),
    hslColor.lightness.clamp(0.3, 0.7),
  );

  final ColorScheme base = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: newHslColor.toColor(),
    dynamicSchemeVariant: dynamicSchemeVariant.value,
  );

  // Override with fixed brand secondaries/tertiaries; tonal surfaces use navy.
  final ColorScheme colorScheme = isCustomColor
      ? base.copyWith(
          secondary: tcTeal,
          onSecondary: _gray0,
          secondaryContainer: _teal100,
          onSecondaryContainer: _teal800,
          tertiary: tcOrange,
          onTertiary: _gray0,
          tertiaryContainer: _orange100,
          onTertiaryContainer: _orange600,
          surface: isLight ? _gray25 : _dark1,
          onSurface: isLight ? _gray700 : _gray100,
          surfaceContainerLowest: isLight ? _gray0 : _dark0,
          surfaceContainerLow: isLight ? _gray25 : _dark1,
          surfaceContainer: isLight ? _gray50 : _dark2,
          surfaceContainerHigh: isLight ? _gray100 : _dark4,
          surfaceContainerHighest: isLight ? _gray200 : _dark5,
          outline: isLight ? _gray200 : _dark6,
          outlineVariant: isLight ? _gray100 : _dark4,
          error: isLight ? const Color(0xFFD84545) : const Color(0xFFFF6B6B),
          onError: _gray0,
        )
      : base.copyWith(primary: newHslColor.toColor());

  final TextTheme textTheme = _buildTextTheme();
  final TextStyle buttonTextStyle = TextStyle(
    fontFamily: titleFont,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  return ThemeData(
    colorScheme: colorScheme,
    typography: Typography.material2021(),
    textTheme: textTheme,
    // ── App bar ───────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(
        fontFamily: titleFont,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    ),
    // ── Icons ───────────────────────────────────────────────────────
    iconTheme: IconThemeData(weight: 150, color: colorScheme.onSurface),
    // ── Cards ─────────────────────────────────────────────────────────────────
    // White surface, 1.5px border, soft warm-tinted shadow (no heavy elevation)
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: standardBorderWidth,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shadowColor: tcNavy.withAlpha(26),
    ),
    // ── Buttons ───────────────────────────────────────────────────────────────
    // Pill-shaped, Fredoka font. Blue for primary, teal/orange via colorScheme.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        textStyle: buttonTextStyle,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        textStyle: buttonTextStyle,
        elevation: 1,
        shadowColor: tcNavy.withAlpha(46),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        textStyle: buttonTextStyle,
        side: BorderSide(
          color: colorScheme.outline,
          width: standardBorderWidth,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        textStyle: buttonTextStyle,
      ),
    ),
    // ── Inputs ────────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(
          color: colorScheme.outline,
          width: standardBorderWidth,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(
          color: colorScheme.outline,
          width: standardBorderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: thickBorderWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(
          color: colorScheme.error,
          width: standardBorderWidth,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(
          color: colorScheme.error,
          width: thickBorderWidth,
        ),
      ),
    ),
    // ── Dialogs ───────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
      elevation: 8,
      shadowColor: tcNavy.withAlpha(46),
      backgroundColor: colorScheme.surfaceContainerLowest,
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),

    // ── Navigation bar ───────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primary.withAlpha(31),
      labelTextStyle: WidgetStateProperty.all(textTheme.labelMedium),
    ),
    navigationRailTheme: NavigationRailThemeData(
      indicatorColor: colorScheme.primary.withAlpha(31),
    ),

    // ── Chips ────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      labelStyle: TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: colorScheme.onSurfaceVariant,
      ),
      side: BorderSide(color: colorScheme.outline, width: standardBorderWidth),
    ),
    // ── Snack bars ───────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      backgroundColor: tcNavy,
      contentTextStyle: TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w500,
        color: _gray0,
      ),
      actionTextColor: tcYellow,
    ),
    // ── List tiles ───────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: colorScheme.onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: colorScheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    ),
    // ── Switch ───────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _gray0;
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        return _gray400;
      }),
    ),
    // ── Divider ──────────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
    ),
  );
}

/// Typography: Fredoka for display/headlines, Hanken Grotesk (500+) for body/UI.
/// Colors are intentionally unset — Material derives them from colorScheme at render time.
TextTheme _buildTextTheme() {
  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: titleFont,
      fontSize: 52,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontFamily: titleFont,
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    displaySmall: TextStyle(
      fontFamily: titleFont,
      fontSize: 32,
      fontWeight: FontWeight.w600,
    ),
    headlineLarge: TextStyle(
      fontFamily: titleFont,
      fontSize: 28,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      fontFamily: titleFont,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      fontFamily: titleFont,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontFamily: titleFont,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontFamily: bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    bodyLarge: TextStyle(
      fontFamily: bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: TextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodySmall: TextStyle(
      fontFamily: bodyFont,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontFamily: bodyFont,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontFamily: bodyFont,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
}

Future<void> setupSystemColor(BuildContext context) async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

/// Chooses the light or dark text color based on the supplied background color.
Color getTextColor({
  required Color color,
  required BuildContext context,
  bool invert = false,
}) {
  ColorScheme colorScheme = ColorScheme.of(context);
  double luminance = color.computeLuminance();

  bool isLight = colorScheme.brightness == Brightness.light && !invert;
  if (luminance > luminanceThreshold.value) {
    return isLight ? colorScheme.onSurface : colorScheme.surface;
  } else {
    return isLight ? colorScheme.surface : colorScheme.onSurface;
  }
}
