import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'firebase_options.dart';
import 'services/local_database.dart';
import 'view/home.dart';

/// Native Firebase setup and application entry are kept outside main.dart.
Future<void> startFitpick() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase web options are not configured; web uses the FastAPI storefront.
  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkMode = false;
  double _fontScale = 1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (kIsWeb) return;
    try {
      final rows = await LocalDatabase.instance.queryRecords(
        LocalDatabase.appSettings,
      );
      final values = {
        for (final row in rows)
          '${row['setting_key']}': '${row['setting_value']}',
      };
      if (!mounted) return;
      setState(() {
        _darkMode = values['dark_mode'] == 'true';
        _fontScale =
            (double.tryParse(values['font_scale'] ?? '1')?.clamp(0.85, 1.25) ??
                    1)
                .toDouble();
      });
    } catch (_) {
      // 앱을 처음 설치한 경우 기본 설정으로 시작한다.
    }
  }

  Future<void> _saveSettings(bool darkMode, double fontScale) async {
    setState(() {
      _darkMode = darkMode;
      _fontScale = fontScale;
    });
    if (kIsWeb) return;
    try {
      final db = LocalDatabase.instance;
      await db.insertRecord(LocalDatabase.appSettings, {
        'setting_key': 'dark_mode',
        'setting_value': '$darkMode',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insertRecord(LocalDatabase.appSettings, {
        'setting_key': 'font_scale',
        'setting_value': '$fontScale',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      // 저장 실패 시 현재 실행 중에는 설정을 유지한다.
    }
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D2B2F),
      brightness: brightness,
      surface: dark ? const Color(0xFF151A1B) : const Color(0xFFF7F8F7),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF222829) : Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: dark ? const Color(0xFF353D3E) : const Color(0xFFE8ECE9),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark
              ? const Color(0xFFE1E9E6)
              : const Color(0xFF1D2B2F),
          foregroundColor: dark ? const Color(0xFF1D2B2F) : Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF222829) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF353D3E) : const Color(0xFFE5E9E6),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF1D2324) : Colors.white,
        indicatorColor: dark
            ? const Color(0xFF33403C)
            : const Color(0xFFEAF1EC),
        height: 68,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FITPICK',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(_fontScale)),
        child: child!,
      ),
      home: Home(
        darkMode: _darkMode,
        fontScale: _fontScale,
        onSettingsChanged: _saveSettings,
      ),
    );
  }
}
