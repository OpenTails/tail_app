import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData buildTheme(Brightness brightness, Color color) {
  if (brightness == Brightness.light) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: color,
        primary: color,
      ),
      appBarTheme: const AppBarTheme(elevation: 2),
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(),
      filledButtonTheme: FilledButtonThemeData(
        style: ElevatedButton.styleFrom(foregroundColor: getTextColor(color)),
      ),
    );
  } else {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: color,
        primary: color,
      ),
      appBarTheme: const AppBarTheme(elevation: 2),
      // We use the nicer Material-3 Typography in both M2 and M3 mode.
      typography: Typography.material2021(),
      filledButtonTheme: FilledButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: getTextColor(color),
          elevation: 1,
        ),
      ),
    );
  }
}

Future<void> setupSystemColor(BuildContext context) async {
  final SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent /*Android=23*/,
    statusBarBrightness: Brightness.light /*iOS*/,
    statusBarIconBrightness: Brightness.dark /*Android=23*/,
    systemStatusBarContrastEnforced: false /*Android=29*/,
    systemNavigationBarColor: Colors.transparent /*Android=27*/,
    systemNavigationBarDividerColor: Colors.transparent.withAlpha(
      1,
    ) /*Android=28,不能用全透明 */,
    systemNavigationBarIconBrightness: Brightness.dark /*Android=27*/,
    systemNavigationBarContrastEnforced: false /*Android=29*/,
  );

  final SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // 23
    statusBarIconBrightness: Brightness.dark,
    // 23
    systemNavigationBarColor: Colors.transparent,
    // 27
    systemStatusBarContrastEnforced: false /*Android=29*/,
    systemNavigationBarDividerColor: Colors.transparent.withAlpha(
      1,
    ) /* 不能用全透明 */,
    // 28
    systemNavigationBarIconBrightness: Brightness.dark,
    // 27
    systemNavigationBarContrastEnforced: false, // 29
  );
  if (Theme.of(context).colorScheme.brightness == Brightness.light) {
    SystemChrome.setSystemUIOverlayStyle(light);
  } else {
    SystemChrome.setSystemUIOverlayStyle(dark);
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

/// Chooses the light or dark text color based on the supplied background color
/// Used in places where the UI color can be set by the user
Color getTextColor(Color color) {
  // Counting the perceptive luminance - human eye favors green color...
  // Does not work with r/g/b double values
  double luminance = color.computeLuminance();
  if (luminance > 0.7) {
    return Typography.material2021().black.labelLarge!.color!;
  } else {
    return Typography.material2021().white.labelLarge!.color!;
  }
}
