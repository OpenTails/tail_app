import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Brand palette ─────────────────────────────────────────────────────────────
// Source: Brand Guide v3 / Tail Company Design System
const Color tcBlue   = Color(0xFF0275D8); // primary interactive
const Color tcOrange = Color(0xFFE46E26); // signature — use sparingly
const Color tcTeal   = Color(0xFF21A58F); // secondary / positive
const Color tcNavy   = Color(0xFF14374A); // ink / dark surface
const Color tcYellow = Color(0xFFF4CC48); // warm accent / glow

// Extended ramps used in theming
const Color _blue500  = Color(0xFF0961B2);
const Color _blue600  = Color(0xFF0A4D8B);
const Color _teal500  = Color(0xFF198573);
const Color _teal100  = Color(0xFFC0E9DF);
const Color _teal800  = Color(0xFF146658);
const Color _orange100= Color(0xFFFADCC4);
const Color _orange600= Color(0xFFA2480F);
const Color _gray0    = Color(0xFFFFFFFF);
const Color _gray25   = Color(0xFFFAFBFC);
const Color _gray50   = Color(0xFFF4F6F8);
const Color _gray100  = Color(0xFFE9EDF1);
const Color _gray200  = Color(0xFFD7DEE4);
const Color _gray400  = Color(0xFF8C99A4);
const Color _gray700  = Color(0xFF313B42);
const Color _gray800  = Color(0xFF1E262C);
const Color _navy900  = Color(0xFF0C232F);

// Dark surfaces
const Color _dark0  = Color(0xFF0A1219);
const Color _dark1  = Color(0xFF0E1A22);
const Color _dark2  = Color(0xFF131F28);
const Color _dark3  = Color(0xFF162633);
const Color _dark4  = Color(0xFF1A2B37);
const Color _dark5  = Color(0xFF213444);
const Color _dark6  = Color(0xFF2A3F50);

// ── Radii ─────────────────────────────────────────────────────────────────────
const double _radiusSm   = 10.0;  // inputs, small chips
const double _radiusMd   = 14.0;  // dialogs, list tiles
const double _radiusLg   = 20.0;  // cards
const double _radiusXl   = 28.0;  // bottom sheets, large panels
const double _radiusPill = 64.0;  // buttons (pill shape)

ThemeData buildTheme(Brightness brightness, Color seedColor) {
  final bool isLight = brightness == Brightness.light;

  final ColorScheme base = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: seedColor,
  );

  // Override with fixed brand secondaries/tertiaries; tonal surfaces use navy.
  final ColorScheme colorScheme = base.copyWith(
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
    surfaceContainerLow:    isLight ? _gray25 : _dark1,
    surfaceContainer:       isLight ? _gray50 : _dark2,
    surfaceContainerHigh:   isLight ? _gray100 : _dark4,
    surfaceContainerHighest:isLight ? _gray200 : _dark5,
    outline:        isLight ? _gray200 : _dark6,
    outlineVariant: isLight ? _gray100 : _dark4,
    error: isLight ? const Color(0xFFD84545) : const Color(0xFFFF6B6B),
    onError: _gray0,
  );

  final TextTheme textTheme = _buildTextTheme();

  return ThemeData(
    colorScheme: colorScheme,
    typography: Typography.material2021(),
    textTheme: textTheme,
    // ── App bar ───────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Fredoka',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    ),
    // ── Cards ─────────────────────────────────────────────────────────────────
    // White surface, 1.5px border, soft warm-tinted shadow (no heavy elevation)
    cardTheme: CardThemeData(
      elevation: 0,
      color: isLight ? _gray0 : _dark3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLg),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shadowColor: tcNavy.withAlpha(26),
    ),
    // ── Buttons ───────────────────────────────────────────────────────────────
    // Pill-shaped, Fredoka font. Blue for primary, teal/orange via colorScheme.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusPill)),
        textStyle: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600, fontSize: 16),
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusPill)),
        textStyle: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600, fontSize: 16),
        elevation: 1,
        shadowColor: tcNavy.withAlpha(46),
        foregroundColor: getTextColor(seedColor),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusPill)),
        textStyle: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600, fontSize: 16),
        side: BorderSide(color: colorScheme.outline, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusPill)),
        textStyle: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    // ── Inputs ────────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? _gray0 : _dark3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(color: colorScheme.outline, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(color: colorScheme.outline, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      labelStyle: TextStyle(fontFamily: 'HankenGrotesk', fontWeight: FontWeight.w500),
      hintStyle: TextStyle(fontFamily: 'HankenGrotesk', fontWeight: FontWeight.w500, color: _gray400),
    ),
    // ── Dialogs ───────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusLg)),
      elevation: 8,
      shadowColor: tcNavy.withAlpha(46),
      backgroundColor: isLight ? _gray0 : _dark3,
      titleTextStyle: TextStyle(
        fontFamily: 'Fredoka',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'HankenGrotesk',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    // ── Bottom sheets ────────────────────────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_radiusXl),
          topRight: Radius.circular(_radiusXl),
        ),
      ),
    ),
    // ── Navigation bar ───────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primary.withAlpha(31),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontFamily: 'HankenGrotesk', fontWeight: FontWeight.w600, fontSize: 12),
      ),
    ),
    // ── Chips ────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
      labelStyle: TextStyle(fontFamily: 'HankenGrotesk', fontWeight: FontWeight.w600, fontSize: 13),
      side: BorderSide(color: colorScheme.outline, width: 1.5),
    ),
    // ── Snack bars ───────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
      backgroundColor: tcNavy,
      contentTextStyle: TextStyle(fontFamily: 'HankenGrotesk', fontWeight: FontWeight.w500, color: _gray0),
      actionTextColor: tcYellow,
    ),
    // ── List tiles ───────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(fontFamily: 'HankenGrotesk', fontWeight: FontWeight.w600, fontSize: 15, color: colorScheme.onSurface),
      subtitleTextStyle: TextStyle(fontFamily: 'HankenGrotesk', fontWeight: FontWeight.w500, fontSize: 13, color: colorScheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
    ),
    // ── Switch ───────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _gray0;
        return null;
      }),
    ),
    // ── Divider ──────────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 1),
  );
}

/// Typography: Fredoka for display/headlines, Hanken Grotesk (500+) for body/UI.
/// Colors are intentionally unset — Material derives them from colorScheme at render time.
TextTheme _buildTextTheme() {
  return TextTheme(
    displayLarge:  TextStyle(fontFamily: 'Fredoka', fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    displayMedium: TextStyle(fontFamily: 'Fredoka', fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    displaySmall:  TextStyle(fontFamily: 'Fredoka', fontSize: 32, fontWeight: FontWeight.w600),
    headlineLarge: TextStyle(fontFamily: 'Fredoka', fontSize: 28, fontWeight: FontWeight.w600),
    headlineMedium:TextStyle(fontFamily: 'Fredoka', fontSize: 24, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontFamily: 'Fredoka', fontSize: 20, fontWeight: FontWeight.w600),
    titleLarge:    TextStyle(fontFamily: 'Fredoka', fontSize: 20, fontWeight: FontWeight.w600),
    titleMedium:   TextStyle(fontFamily: 'HankenGrotesk', fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall:    TextStyle(fontFamily: 'HankenGrotesk', fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    bodyLarge:     TextStyle(fontFamily: 'HankenGrotesk', fontSize: 16, fontWeight: FontWeight.w500),
    bodyMedium:    TextStyle(fontFamily: 'HankenGrotesk', fontSize: 14, fontWeight: FontWeight.w500),
    bodySmall:     TextStyle(fontFamily: 'HankenGrotesk', fontSize: 12, fontWeight: FontWeight.w500),
    labelLarge:    TextStyle(fontFamily: 'HankenGrotesk', fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium:   TextStyle(fontFamily: 'HankenGrotesk', fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall:    TextStyle(fontFamily: 'HankenGrotesk', fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
  );
}

Future<void> setupSystemColor(BuildContext context) async {
  final SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent.withAlpha(1),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  final SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarDividerColor: Colors.transparent.withAlpha(1),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
  if (Theme.of(context).colorScheme.brightness == Brightness.light) {
    SystemChrome.setSystemUIOverlayStyle(light);
  } else {
    SystemChrome.setSystemUIOverlayStyle(dark);
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

/// Chooses the light or dark text color based on the supplied background color.
Color getTextColor(Color color) {
  double luminance = color.computeLuminance();
  if (luminance > 0.7) {
    return Typography.material2021().black.labelLarge!.color!;
  } else {
    return Typography.material2021().white.labelLarge!.color!;
  }
}
