import 'package:flutter/material.dart';

import 'models/auth_session.dart';
import 'pages/device_list_page.dart';
import 'pages/login_page.dart';
import 'services/api_client.dart';
import 'widgets/dashboard_chrome.dart';

void main() => runApp(const IoTApp());

class IoTApp extends StatelessWidget {
  const IoTApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoTapp',
      theme: base.copyWith(
        scaffoldBackgroundColor: AppPalette.midnight,
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.cyan,
          secondary: AppPalette.violet,
          surface: AppPalette.panel,
          onPrimary: AppPalette.midnight,
          onSurface: Colors.white,
          error: AppPalette.danger,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF101D35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF10233D),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.36)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: AppPalette.cyan),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppPalette.cyan,
            foregroundColor: AppPalette.midnight,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.cyan,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppPalette.cyan,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF101D35),
          modalBackgroundColor: Color(0xFF101D35),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ApiClient _api = ApiClient();
  AuthSession? _session;

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return LoginPage(
        api: _api,
        onLoggedIn: (session) {
          _api.applySession(session);
          setState(() => _session = session);
        },
      );
    }

    return DeviceListPage(
      api: _api,
      session: _session!,
      onLogout: () async {
        try {
          await _api.logout();
        } catch (_) {
          _api.clearSession();
        }
        if (mounted) {
          setState(() => _session = null);
        }
      },
    );
  }
}
