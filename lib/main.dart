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
      seedColor: const Color(0xFF00BCD4), // Electric Cyan
      brightness: Brightness.dark,
      surface: const Color(0xFF000000), // Pure AMOLED black
      onSurface: const Color(0xFFE0E0E0),
      surfaceContainerHighest: const Color(0xFF111111), // Subtle dark gray
    );

    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'RescuePing',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.black,
            foregroundColor: Color(0xFFE0E0E0),
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            margin: EdgeInsets.zero,
            color: const Color(0xFF111111),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
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
            elevation: 0,
          ),
          dividerTheme: DividerThemeData(
            thickness: 1,
            space: 1,
            color: Colors.white.withValues(alpha: 0.04),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF111111),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.black,
            indicatorColor: scheme.primaryContainer,
            surfaceTintColor: Colors.transparent,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFF111111),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF111111),
          ),
          popupMenuTheme: const PopupMenuThemeData(
            color: Color(0xFF111111),
          ),
        ),
        home: const BootstrapScreen(),
      ),
    );
  }
}
