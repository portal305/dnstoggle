import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'services/services.dart';
import 'screens/screens.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DnsToggleApp());
}

class DnsToggleApp extends StatelessWidget {
  const DnsToggleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(
        storageService: StorageService(),
        dnsService: DnsService(),
        shizukuService: ShizukuService(),
      )..init(),
      child: MaterialApp(
        title: 'DNS Toggle',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: Brightness.light,
            surface: const Color(0xFFF7F2FA),
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F2FA),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 4,
            backgroundColor: Color(0xFFF7F2FA),
            titleTextStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1B20),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            elevation: 0,
            hoverElevation: 2,
            focusElevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(width: 2, color: Color(0xFF6750A4)),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            showDragHandle: true,
            dragHandleSize: Size(32, 4),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
          ),
          switchTheme: SwitchThemeData(
            thumbIcon: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Icon(Icons.check, size: 16);
              }
              return const Icon(Icons.close, size: 16);
            }),
            trackOutlineWidth: const WidgetStatePropertyAll(0),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD0BCFF),
            brightness: Brightness.dark,
            surface: const Color(0xFF1C1B1F),
          ),
          scaffoldBackgroundColor: const Color(0xFF141318),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 4,
            backgroundColor: Color(0xFF141318),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: const Color(0xFF1C1B1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            showDragHandle: true,
            dragHandleSize: Size(32, 4),
            backgroundColor: Color(0xFF1C1B1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
          ),
          switchTheme: SwitchThemeData(
            thumbIcon: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Icon(Icons.check, size: 16);
              }
              return const Icon(Icons.close, size: 16);
            }),
            trackOutlineWidth: const WidgetStatePropertyAll(0),
          ),
        ),
        themeMode: ThemeMode.system,
        home: Consumer<AppState>(
          builder: (context, appState, child) {
            if (!appState.settings.onboardingCompleted && !appState.isLoading) {
              return const OnboardingScreen();
            }
            return const HomeScreen();
          },
        ),
      ),
    );
  }
}
