import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import 'constants/routes.dart';
import 'controllers/auth_wrapper.dart';
import 'controllers/setting_controller.dart';

void main() async {
  try{
    WidgetsFlutterBinding.ensureInitialized();
    // It's crucial that controllers are put() before the app runs
    Get.put(AuthController());
    Get.put(SettingsController());
    runApp(const MyApp());
  }catch(err){
    Get.snackbar('Error', 'Please check your internet connection',backgroundColor: Colors.blue);
    throw Exception("Failed to init app");
  }
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

