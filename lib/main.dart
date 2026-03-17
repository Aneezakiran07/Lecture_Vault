import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants/colors.dart';
import 'screens/onboarding/folder_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/folder_view/folder_view_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load .env before anything else so api key is available
  await dotenv.load(fileName: '.env');

  // check if user already completed onboarding
  final setupDone = await StorageService.isSetupDone();

  runApp(LectureVaultApp(
    startRoute: setupDone ? '/home' : '/onboarding',
  ));
}

class LectureVaultApp extends StatelessWidget {
  final String startRoute;
  const LectureVaultApp({super.key, required this.startRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LectureVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.headerCard),
        useMaterial3: true,
      ),
      initialRoute: startRoute,
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