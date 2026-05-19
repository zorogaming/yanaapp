import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  midnight,
  cherryRed,
  cherryBlue,
  facebookBlue,
  cherryGreen,
  cherryYellow,
  cherryPink,
  blushRed,
  skyBlue,
  mintGreen,
  rosePink,
  white,
}

class AppThemePalette extends ThemeExtension<AppThemePalette> {
  const AppThemePalette({
    required this.id,
    required this.label,
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.surfaceSoft,
    required this.accent,
    required this.accentStrong,
    required this.highlight,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.heroStart,
    required this.heroEnd,
    required this.success,
  });

  final String id;
  final String label;
  final Color background;
  final Color surface;
  final Color surfaceStrong;
  final Color surfaceSoft;
  final Color accent;
  final Color accentStrong;
  final Color highlight;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color heroStart;
  final Color heroEnd;
  final Color success;
  
  bool get isLight => background.computeLuminance() > 0.5;
  Color get onAccent => accent.computeLuminance() > 0.45 ? Colors.black : Colors.white;

  @override
  AppThemePalette copyWith({
    String? id,
    String? label,
    Color? background,
    Color? surface,
    Color? surfaceStrong,
    Color? surfaceSoft,
    Color? accent,
    Color? accentStrong,
    Color? highlight,
    Color? textPrimary,
    Color? textMuted,
    Color? border,
    Color? heroStart,
    Color? heroEnd,
    Color? success,
  }) {
    return AppThemePalette(
      id: id ?? this.id,
      label: label ?? this.label,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      highlight: highlight ?? this.highlight,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      success: success ?? this.success,
    );
  }

  @override
  AppThemePalette lerp(ThemeExtension<AppThemePalette>? other, double t) {
    if (other is! AppThemePalette) {
      return this;
    }
    return AppThemePalette(
      id: t < 0.5 ? id : other.id,
      label: t < 0.5 ? label : other.label,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceStrong:
          Color.lerp(surfaceStrong, other.surfaceStrong, t) ?? surfaceStrong,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t) ?? surfaceSoft,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentStrong:
          Color.lerp(accentStrong, other.accentStrong, t) ?? accentStrong,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      heroStart: Color.lerp(heroStart, other.heroStart, t) ?? heroStart,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t) ?? heroEnd,
      success: Color.lerp(success, other.success, t) ?? success,
    );
  }
}

class AppThemeController extends ChangeNotifier {
  static const String _preferenceKey = 'selected_app_theme';

  AppThemeMode _mode = AppThemeMode.midnight;

  AppThemeMode get mode => _mode;

  String get currentThemeLabel => AppThemes.paletteFor(_mode).label;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_preferenceKey);
    _mode = AppThemes.modeFromId(savedValue);
    notifyListeners();
  }

  Future<void> setTheme(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, AppThemes.idFor(mode));
  }
}

class AppThemes {
  static const AppThemePalette midnightPalette = AppThemePalette(
    id: 'midnight',
    label: 'Shop Lime',
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF141414),
    surfaceStrong: Color(0xFF1C1C1C),
    surfaceSoft: Color(0xFF232323),
    accent: Color(0xFFD7FC70),
    accentStrong: Color(0xFFC5F45A),
    highlight: Color(0xFFD7FC70),
    textPrimary: Colors.white,
    textMuted: Color(0xFF9A9A9A),
    border: Color(0x26FFFFFF),
    heroStart: Color(0xFF111111),
    heroEnd: Color(0xFF0D0D0D),
    success: Color(0xFF25D366),
  );

  static const AppThemePalette cherryRedPalette = AppThemePalette(
    id: 'cherry_red',
    label: 'Cherry Red',
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF141414),
    surfaceStrong: Color(0xFF1C1C1C),
    surfaceSoft: Color(0xFF232323),
    accent: Color(0xFFE53935),
    accentStrong: Color(0xFFC62828),
    highlight: Color(0xFFFF6B6B),
    textPrimary: Colors.white,
    textMuted: Color(0xFF9A9A9A),
    border: Color(0x26FFFFFF),
    heroStart: Color(0xFF111111),
    heroEnd: Color(0xFF0D0D0D),
    success: Color(0xFF25D366),
  );

  static const AppThemePalette cherryBluePalette = AppThemePalette(
    id: 'cherry_blue',
    label: 'Cherry Blue',
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF141414),
    surfaceStrong: Color(0xFF1C1C1C),
    surfaceSoft: Color(0xFF232323),
    accent: Color(0xFF3B82F6),
    accentStrong: Color(0xFF2563EB),
    highlight: Color(0xFF60A5FA),
    textPrimary: Colors.white,
    textMuted: Color(0xFF9A9A9A),
    border: Color(0x26FFFFFF),
    heroStart: Color(0xFF111111),
    heroEnd: Color(0xFF0D0D0D),
    success: Color(0xFF25D366),
  );

  static const AppThemePalette facebookBluePalette = AppThemePalette(
    id: 'facebook_blue',
    label: 'Facebook Blue',
    background: Color(0xFF162033),
    surface: Color(0xFF1C2942),
    surfaceStrong: Color(0xFF243552),
    surfaceSoft: Color(0xFF304566),
    accent: Color(0xFF1877F2),
    accentStrong: Color(0xFF166FE5),
    highlight: Color(0xFF6BA8FF),
    textPrimary: Colors.white,
    textMuted: Color(0xFFBDCAE0),
    border: Color(0x2EFFFFFF),
    heroStart: Color(0xFF27406A),
    heroEnd: Color(0xFF162033),
    success: Color(0xFF25D366),
  );

  static const AppThemePalette cherryGreenPalette = AppThemePalette(
    id: 'cherry_green',
    label: 'Cherry Green',
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF141414),
    surfaceStrong: Color(0xFF1C1C1C),
    surfaceSoft: Color(0xFF232323),
    accent: Color(0xFF22C55E),
    accentStrong: Color(0xFF16A34A),
    highlight: Color(0xFF4ADE80),
    textPrimary: Colors.white,
    textMuted: Color(0xFF9A9A9A),
    border: Color(0x26FFFFFF),
    heroStart: Color(0xFF111111),
    heroEnd: Color(0xFF0D0D0D),
    success: Color(0xFF25D366),
  );

  static const AppThemePalette cherryYellowPalette = AppThemePalette(
    id: 'cherry_yellow',
    label: 'Cherry Yellow',
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF141414),
    surfaceStrong: Color(0xFF1C1C1C),
    surfaceSoft: Color(0xFF232323),
    accent: Color(0xFFFACC15),
    accentStrong: Color(0xFFEAB308),
    highlight: Color(0xFFFDE047),
    textPrimary: Colors.white,
    textMuted: Color(0xFF9A9A9A),
    border: Color(0x26FFFFFF),
    heroStart: Color(0xFF111111),
    heroEnd: Color(0xFF0D0D0D),
    success: Color(0xFF25D366),
  );

  static const AppThemePalette cherryPinkPalette = AppThemePalette(
    id: 'cherry_pink',
    label: 'Cherry Pink',
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF141414),
    surfaceStrong: Color(0xFF1C1C1C),
    surfaceSoft: Color(0xFF232323),
    accent: Color(0xFFEC4899),
    accentStrong: Color(0xFFDB2777),
    highlight: Color(0xFFF472B6),
    textPrimary: Colors.white,
    textMuted: Color(0xFF9A9A9A),
    border: Color(0x26FFFFFF),
    heroStart: Color(0xFF111111),
    heroEnd: Color(0xFF0D0D0D),
    success: Color(0xFF25D366),
  );

  static const AppThemePalette blushRedPalette = AppThemePalette(
    id: 'blush_red',
    label: 'Blush Red',
    background: Color(0xFFFFF5F5),
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFFFE8E8),
    surfaceSoft: Color(0xFFFFDCDC),
    accent: Color(0xFFE35D5B),
    accentStrong: Color(0xFFC74643),
    highlight: Color(0xFFFF8A80),
    textPrimary: Color(0xFF2A1616),
    textMuted: Color(0xFF7E5A5A),
    border: Color(0xFFF1CACA),
    heroStart: Color(0xFFFFFFFF),
    heroEnd: Color(0xFFFFEBEB),
    success: Color(0xFF0F9F6E),
  );

  static const AppThemePalette skyBluePalette = AppThemePalette(
    id: 'sky_blue',
    label: 'Sky Blue',
    background: Color(0xFFF4F9FF),
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFE8F2FF),
    surfaceSoft: Color(0xFFDDEBFF),
    accent: Color(0xFF4A90FF),
    accentStrong: Color(0xFF2F76E6),
    highlight: Color(0xFF7BB5FF),
    textPrimary: Color(0xFF10233D),
    textMuted: Color(0xFF5E7692),
    border: Color(0xFFD3E3FA),
    heroStart: Color(0xFFFFFFFF),
    heroEnd: Color(0xFFEAF4FF),
    success: Color(0xFF0F9F6E),
  );

  static const AppThemePalette mintGreenPalette = AppThemePalette(
    id: 'mint_green',
    label: 'Mint Green',
    background: Color(0xFFF4FFF8),
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFE6F8EC),
    surfaceSoft: Color(0xFFD8F1E2),
    accent: Color(0xFF34C97B),
    accentStrong: Color(0xFF20A964),
    highlight: Color(0xFF72E2A4),
    textPrimary: Color(0xFF11251A),
    textMuted: Color(0xFF5D7867),
    border: Color(0xFFCFE8D8),
    heroStart: Color(0xFFFFFFFF),
    heroEnd: Color(0xFFE8FAEF),
    success: Color(0xFF0F9F6E),
  );

  static const AppThemePalette rosePinkPalette = AppThemePalette(
    id: 'rose_pink',
    label: 'Rose Pink',
    background: Color(0xFFFFF6FB),
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFFDEAF4),
    surfaceSoft: Color(0xFFF9DCEA),
    accent: Color(0xFFEA5FA1),
    accentStrong: Color(0xFFD63D88),
    highlight: Color(0xFFF59AC5),
    textPrimary: Color(0xFF2C1522),
    textMuted: Color(0xFF7D6070),
    border: Color(0xFFF0D2E0),
    heroStart: Color(0xFFFFFFFF),
    heroEnd: Color(0xFFFDECF5),
    success: Color(0xFF0F9F6E),
  );

  static const AppThemePalette whitePalette = AppThemePalette(
    id: 'white',
    label: 'White',
    background: Color(0xFFF5F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFEEF3FB),
    surfaceSoft: Color(0xFFE8EFFA),
    accent: Color(0xFFC88A3D),
    accentStrong: Color(0xFFAF6F25),
    highlight: Color(0xFFFFA24C),
    textPrimary: Color(0xFF101828),
    textMuted: Color(0xFF5F6C7B),
    border: Color(0xFFD7E0EC),
    heroStart: Color(0xFFFFFFFF),
    heroEnd: Color(0xFFEEF4FF),
    success: Color(0xFF0F9F6E),
  );

  static List<AppThemeMode> get allModes => const <AppThemeMode>[
    AppThemeMode.midnight,
    AppThemeMode.cherryRed,
    AppThemeMode.cherryBlue,
    AppThemeMode.facebookBlue,
    AppThemeMode.cherryGreen,
    AppThemeMode.cherryYellow,
    AppThemeMode.cherryPink,
    AppThemeMode.blushRed,
    AppThemeMode.skyBlue,
    AppThemeMode.mintGreen,
    AppThemeMode.rosePink,
    AppThemeMode.white,
  ];

  static AppThemePalette paletteFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.facebookBlue:
        return facebookBluePalette;
      case AppThemeMode.cherryBlue:
        return cherryBluePalette;
      case AppThemeMode.cherryGreen:
        return cherryGreenPalette;
      case AppThemeMode.cherryYellow:
        return cherryYellowPalette;
      case AppThemeMode.cherryPink:
        return cherryPinkPalette;
      case AppThemeMode.blushRed:
        return blushRedPalette;
      case AppThemeMode.skyBlue:
        return skyBluePalette;
      case AppThemeMode.mintGreen:
        return mintGreenPalette;
      case AppThemeMode.rosePink:
        return rosePinkPalette;
      case AppThemeMode.cherryRed:
        return cherryRedPalette;
      case AppThemeMode.white:
        return whitePalette;
      case AppThemeMode.midnight:
        return midnightPalette;
    }
  }

  static String idFor(AppThemeMode mode) => paletteFor(mode).id;

  static AppThemeMode modeFromId(String? id) {
    if (id == 'sandstone') {
      return AppThemeMode.white;
    }
    return AppThemeMode.values.firstWhere(
      (mode) => paletteFor(mode).id == id,
      orElse: () => AppThemeMode.midnight,
    );
  }

  static ThemeData themeDataFor(AppThemeMode mode) {
    final palette = paletteFor(mode);
    final brightness = switch (mode) {
      AppThemeMode.white ||
      AppThemeMode.blushRed ||
      AppThemeMode.skyBlue ||
      AppThemeMode.mintGreen ||
      AppThemeMode.rosePink => Brightness.light,
      _ => Brightness.dark,
    };
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: palette.surface,
    ).copyWith(
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.highlight,
      onSecondary:
          palette.highlight.computeLuminance() > 0.45 ? Colors.black : Colors.white,
      tertiary: palette.accentStrong,
      onTertiary:
          palette.accentStrong.computeLuminance() > 0.45 ? Colors.black : Colors.white,
      outline: palette.border,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      primaryColor: palette.accent,
      dividerColor: palette.border,
      splashColor: palette.accent.withOpacity(0.08),
      highlightColor: palette.highlight.withOpacity(0.08),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: palette.textPrimary,
        iconTheme: IconThemeData(color: palette.textPrimary),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: palette.textMuted,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: palette.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: TextStyle(color: palette.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.accent),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.success,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceStrong,
        selectedColor: palette.accent,
        disabledColor: palette.surfaceSoft,
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(color: palette.textPrimary),
        secondaryLabelStyle: TextStyle(color: palette.onAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return palette.surface;
        }),
        checkColor: WidgetStateProperty.all(palette.onAccent),
        side: BorderSide(color: palette.border),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return palette.textMuted;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.onAccent;
          return palette.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return palette.surfaceSoft;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceStrong,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        actionTextColor: palette.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.surfaceSoft,
        circularTrackColor: palette.surfaceSoft,
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textPrimary,
        textColor: palette.textPrimary,
        tileColor: palette.surface,
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemePalette get appPalette =>
      Theme.of(this).extension<AppThemePalette>() ?? AppThemes.midnightPalette;
}
