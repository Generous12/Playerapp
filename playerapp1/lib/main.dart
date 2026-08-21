import 'package:flutter/material.dart';
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

  await DatabaseHelper.instance.database;

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.playerapp.audio',
    androidNotificationChannelName: 'Music Playback',
    androidNotificationOngoing: true,
  );

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

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
      title: 'PlayerApp',

      theme: ThemeData(
        fontFamily: 'Afacad',
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        colorScheme: ColorScheme.light(
          primary: themeProvider.palette.primary,
          secondary: themeProvider.palette.accent,
          surface: Colors.white,
          onSurface: const Color(0xFF0C101A),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        splashFactory: InkSparkle.splashFactory,
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
        splashFactory: InkSparkle.splashFactory,
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
