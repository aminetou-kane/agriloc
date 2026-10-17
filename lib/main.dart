import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AgriLocApp());
}

class AgriLocApp extends StatelessWidget {
  const AgriLocApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgriLoc',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        scaffoldBackgroundColor: const Color(0xFFF7F9F7),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: green,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(elevation: 2, margin: EdgeInsets.zero),
      ),
      home: const SplashScreen(),
    );
  }
}
