import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

// Import app screens
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/job_openings_page.dart';
import 'screens/profile_page.dart';
import 'screens/resume_builder_page.dart';
import 'screens/resume_preview_page.dart';
import 'screens/roadmap_result_page.dart';
import 'screens/career_roadmap_page.dart';
import 'screens/course_roadmap_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional)
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyD4Lr2kUI_N5v0IUThepI-lD-Wx7AruESw",
      appId: "1:1010983621398:android:23a3169c27f4da4adff637",
      messagingSenderId: "1010983621398",
      projectId: "ai-career-road-map",
      storageBucket: "ai-career-road-map.firebasestorage.app",
    ),
  );

  runApp(const CareerNavigatorApp());
}

class CareerNavigatorApp extends StatelessWidget {
  const CareerNavigatorApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Career Navigator',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          primary: Colors.blueAccent,
          background: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[50],
          foregroundColor: Colors.blue,
          iconTheme: const IconThemeData(color: Colors.blue),
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const MaterialStatePropertyAll(Colors.blueAccent),
            foregroundColor: const MaterialStatePropertyAll(Colors.white),
            shape: const MaterialStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            textStyle: const MaterialStatePropertyAll(
              TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            padding: const MaterialStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => RegisterPage(),
        '/career_roadmap': (context) => const CourseRoadmapPage(),
        '/course_roadmap': (context) => const CareerRoadmapPage(),
        '/job_openings': (context) => JobOpeningsPage(),
        '/profile': (context) => const ProfilePage(),
        '/resume_builder': (context) => ResumeBuilderPage(),
        '/resume_preview': (context) => const Placeholder(),
        '/roadmap_result': (context) => RoadmapResultPage(),
        '/': (context) => const DashboardPage(),
      },
    );
  }
}
