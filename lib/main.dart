// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';                 // for ThemeNotifier

import 'services/story_service.dart';                   // to update last access date
import 'theme/theme_notifier.dart';                      // your new theme provider
import 'feature_screens/login_screens/main_splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Wrap the app in a ThemeNotifier provider so all pages can react to theme changes
  runApp(
    ChangeNotifierProvider<ThemeNotifier>(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'VersaTale',
          theme: themeNotifier.theme,                        // apply user’s palette & font
          home: const MainSplashScreen(),                    // still your splash/login logic
        );
      },
    );
  }
}
