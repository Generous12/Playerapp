import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:playerapp1/database/playerdb.dart';
import 'package:playerapp1/services/musicprovider.dart';
import 'package:playerapp1/services/theme_provider.dart';
import 'package:playerapp1/vista/mainscreen.dart';
import 'package:playerapp1/widgets/diseños/theme_reveal.dart';
import 'package:provider/provider.dart';

import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint("Error al inicializar la base de datos: $e");
  }

  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint("Error al configurar AudioSession: $e");
  }

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.playerapp.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint("Error al inicializar JustAudioBackground: $e");
  }

  final themeProvider = ThemeProvider();
  try {
    await themeProvider.loadTheme();
  } catch (e) {
    debugPrint("Error al cargar tema: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VibePlus',

      theme: ThemeData(
        fontFamily: 'Afacad',
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3F5FA),
        colorScheme: ColorScheme.light(
          primary: themeProvider.palette.primary,
          secondary: themeProvider.palette.accent,
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF131722),
          surfaceContainerHighest: const Color(0xFFEAEEF6),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFF3F5FA),
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        splashFactory: InkRipple.splashFactory,
      ),

      darkTheme: ThemeData(
        fontFamily: 'Afacad',
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08090D),
        colorScheme: ColorScheme.dark(
          primary: themeProvider.palette.primary,
          secondary: themeProvider.palette.accent,
          surface: const Color(0xFF11131B),
          onSurface: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        splashFactory: InkRipple.splashFactory,
      ),

      themeMode: themeProvider.themeMode,

      builder: (context, child) {
        return ThemeReveal(
          child: child ?? const MainScreen(),
        );
      },

      home: const MainScreen(),
    );
  }
}
