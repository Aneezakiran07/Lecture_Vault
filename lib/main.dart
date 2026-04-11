import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants/colors.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/folder_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/folder_view/folder_view_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/search/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load .env before anything else so api key is available
  await dotenv.load(fileName: '.env');

  // always start at splash which handles the setup check internally
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.headerCard),
        useMaterial3: true,
      ),
      // splash is now the entry point
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/onboarding': (_) => const FolderSetupScreen(),
        '/home': (_) => const HomeScreen(),
        '/upload': (_) => const UploadScreen(),
        '/folder': (_) => const FolderViewScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/search': (_) => const SearchScreen(),
      },
    );
  }
}