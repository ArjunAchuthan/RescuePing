import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/bootstrap_screen.dart';
import 'services/app_state.dart';

void main() {
  runApp(const RescueMeshApp());
}

class RescueMeshApp extends StatelessWidget {
  const RescueMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE65100), // Emergency orange
      brightness: Brightness.dark,
      surface: const Color(0xFF0A0E17), // Deep bluish-black
      onSurface: const Color(0xFFE2E8F0),
      surfaceContainerHighest: const Color(0xFF161C24),
    );

    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'RescuePing',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          fontFamily: 'Inter', // Try to use a clean modern font if available
          scaffoldBackgroundColor: scheme.surface,
          appBarTheme: AppBarTheme(
            centerTitle: false,
            scrolledUnderElevation: 0,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: Colors.white,
            ),
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          listTileTheme: ListTileThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
          ),
          dividerTheme: DividerThemeData(
            thickness: 1, 
            space: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 120),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: scheme.surface,
            indicatorColor: scheme.primaryContainer,
          ),
        ),
        home: const BootstrapScreen(),
      ),
    );
  }
}
