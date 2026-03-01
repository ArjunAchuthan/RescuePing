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
    );

    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Rescue Mesh',
        theme: ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          visualDensity: VisualDensity.standard,
          scaffoldBackgroundColor: scheme.surface,
          appBarTheme: AppBarTheme(
            centerTitle: false,
            scrolledUnderElevation: 0,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
          ),
          cardTheme: CardThemeData(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          listTileTheme: ListTileThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
          ),
          dividerTheme: const DividerThemeData(thickness: 1, space: 1),
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
