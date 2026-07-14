// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'repositories/bird_repository.dart';
import 'repositories/incubation_repository.dart';
import 'repositories/task_repository.dart';
import 'screens/root_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization info/error: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Repositories are provided once at the app root so every screen
      // shares the same Firestore streams instead of each screen opening
      // its own duplicate query.
      providers: [
        Provider<BirdRepository>(create: (_) => BirdRepository()),
        Provider<IncubationRepository>(create: (_) => IncubationRepository()),
        Provider<TaskRepository>(create: (_) => TaskRepository()),
      ],
      child: MaterialApp(
        title: 'TCG Farms',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return const RootShell();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
