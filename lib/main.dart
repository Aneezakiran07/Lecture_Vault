import 'package:flutter/material.dart';
import 'screens/onboarding/folder_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/folder_view/folder_view_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  runApp(const LectureVaultApp());
}

class LectureVaultApp extends StatelessWidget {
  const LectureVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LectureVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF035955),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (_) => const FolderSetupScreen(),
        '/home': (_) => const HomeScreen(),
        '/upload': (_) => const UploadScreen(),
        '/folder': (_) => const FolderViewScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}