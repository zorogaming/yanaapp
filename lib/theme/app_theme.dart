import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  midnight,
  cherryYellow,
  lightTheme,
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
  Color get onAccent =>
      accent.computeLuminance() > 0.45 ? Colors.black : Colors.white;

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
    accent: Color(0xFFC1FF28),
    accentStrong: Color(0xFFAAEB18),
    highlight: Color(0xFFD8FF78),
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

  static const AppThemePalette lightThemePalette = AppThemePalette(
    id: 'light_theme',
    label: 'Light Theme',
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFF1F3EE),
    surfaceSoft: Color(0xFFE8EBE4),
    accent: Color(0xFFB6F21E),
    accentStrong: Color(0xFF8FC900),
    highlight: Color(0xFFD8FF78),
    textPrimary: Color(0xFF11130E),
    textMuted: Color(0xFF62665D),
    border: Color(0xFFE1E5DC),
    heroStart: Color(0xFFFFFFFF),
    heroEnd: Color(0xFFFFFFFF),
    success: Color(0xFF12834B),
  );

  static List<AppThemeMode> get allModes => const <AppThemeMode>[
    AppThemeMode.midnight,
    AppThemeMode.cherryYellow,
    AppThemeMode.lightTheme,
  ];

  static AppThemePalette paletteFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.cherryYellow:
        return cherryYellowPalette;
      case AppThemeMode.midnight:
        return midnightPalette;
      case AppThemeMode.lightTheme:
        return lightThemePalette;
    }
  }

  static String idFor(AppThemeMode mode) => paletteFor(mode).id;

  static AppThemeMode modeFromId(String? id) {
    if (id == 'sandstone') {
      return AppThemeMode.lightTheme;
    }
    return AppThemeMode.values.firstWhere(
      (mode) => paletteFor(mode).id == id,
      orElse: () => AppThemeMode.midnight,
    );
  }

  static ThemeData themeDataFor(AppThemeMode mode) {
    final palette = paletteFor(mode);
    final brightness = switch (mode) {
      AppThemeMode.lightTheme => Brightness.light,
      _ => Brightness.dark,
    };
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: brightness,
          surface: palette.surface,
        ).copyWith(
          primary: palette.accent,
          onPrimary: palette.onAccent,
          secondary: palette.highlight,
          onSecondary: palette.highlight.computeLuminance() > 0.45
              ? Colors.black
              : Colors.white,
          tertiary: palette.accentStrong,
          onTertiary: palette.accentStrong.computeLuminance() > 0.45
              ? Colors.black
              : Colors.white,
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
        bodyLarge: TextStyle(color: palette.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: palette.textMuted, fontSize: 14),
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
