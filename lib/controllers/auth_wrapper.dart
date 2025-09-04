import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import 'package:rxGuardian/pages/home_page.dart';

import '../constants/colors.dart';
import '../pages/login_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // We use Get.find() because the controller is already put() in main.dart
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    // Use a short delay to ensure the first frame is built before navigating.
    // This prevents potential "setState() or markNeedsBuild() called during build" errors.
    Future.delayed(const Duration(milliseconds: 100), _checkSessionAndNavigate);
  }

  Future<void> _checkSessionAndNavigate() async {
    // Attempt to restore the session using the logic from the previous step
    final bool isSessionRestored = await authController.tryToRestoreSession(context);

    // Navigate based on the result, replacing the navigation stack
    if (isSessionRestored) {
      Get.offAllNamed(HomePage.route_name);
    } else {
      Get.offAllNamed(LoginPage.route_name);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen while the session check is in progress.
    // This is what the user sees for a brief moment on a page refresh.
    return const Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      ),
    );
  }
}
