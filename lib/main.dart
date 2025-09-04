import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/pages/home_page.dart';
import 'constants/routes.dart';
import 'controllers/setting_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Get.put(SettingsController());
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RxGuardian',
      theme: ThemeData(
        textTheme: GoogleFonts.aBeeZeeTextTheme().apply(
          bodyColor:  kNormalTextColor,  // White text in dark mode
          displayColor:  kBackgroundColor,
        ),

        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          brightness: Brightness.dark , // Dynamic Theme
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),

      // home: const LandingPage(),
      routes: routes,
    );
  }
}
