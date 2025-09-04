import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import 'package:rxGuardian/pages/home_page.dart';
import 'package:rxGuardian/pages/login_page.dart';
import 'package:rxGuardian/pages/signup_page.dart';
import 'package:rxGuardian/pages/verify_email_page.dart';
import 'constants/routes.dart';
import 'controllers/auth_wrapper.dart';
import 'controllers/setting_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // It's crucial that controllers are put() before the app runs
  Get.put(AuthController());
  Get.put(SettingsController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController sc = Get.find();
    return Obx(
          () => GetMaterialApp(
        title: 'RxGuardian',
        theme: ThemeData(
          textTheme: GoogleFonts.poppinsTextTheme().apply( // Using Poppins for a modern look
            bodyColor: sc.darkMode.value ? kNormalTextColor : Colors.black,
            displayColor: sc.darkMode.value ? kNormalTextColor : Colors.black,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: kPrimaryColor, // Use your primary color for a consistent theme
            brightness: sc.darkMode.value ? Brightness.dark : Brightness.light,
          ),
          useMaterial3: true,
        ),

        // --- KEY CHANGE ---
        // The AuthWrapper is now the entry point. It decides where to go next.
        home: const AuthWrapper(),

        // Using getPages is the recommended GetX pattern for named routes
        getPages: AppPages.pages,
      ),
    );
  }
}

