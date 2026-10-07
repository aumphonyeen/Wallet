import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

import 'data/wallet_repository.dart';
import 'screens/wallet_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
  await initializeDateFormatting('th_TH');
  runApp(const SmartWalletApp());
}

class SmartWalletApp extends StatefulWidget {
  const SmartWalletApp({super.key});

  @override
  State<SmartWalletApp> createState() => _SmartWalletAppState();
}

class _SmartWalletAppState extends State<SmartWalletApp> {
  final WalletController _controller = WalletController(WalletRepository());
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF087F70);
    return MaterialApp(
      title: 'Smart Wallet',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          surface: const Color(0xFFF7F9F8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F9F8),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F7F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final isCompact = MediaQuery.sizeOf(context).width < 400;
          return Theme(
            data: theme.copyWith(
              textTheme: theme.textTheme.apply(
                fontSizeFactor: isCompact ? .85 : 1,
              ),
              primaryTextTheme: theme.primaryTextTheme.apply(
                fontSizeFactor: isCompact ? .85 : 1,
              ),
            ),
            child: WalletShell(
              controller: _controller,
              isDark: _isDark,
              onThemeChanged: (value) => setState(() => _isDark = value),
            ),
          );
        },
      ),
    );
  }
}
