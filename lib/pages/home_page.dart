import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import 'package:rxGuardian/pages/verify_email_page.dart';
import 'package:rxGuardian/widgets/pharmacist_profile.dart';

// Import your enhanced pages
import '../constants/colors.dart';
import '../constants/routes.dart';

// Import pages to navigate to

import '../controllers/setting_controller.dart';
import 'login_page.dart';




class HomePage extends StatelessWidget {
  static const route_name = home_route; // Your route name
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a single StreamBuilder to handle all auth states. This is the recommended approach.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading indicator while waiting for the auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // If user is not logged in, show the login page
        if (user == null) {
          return const LoginPage();
        }

        // If user is logged in but email is not verified, show the verify email page
        if (!user.emailVerified) {
          return const VerifyEmailPage();
        }

        // If user is logged in and verified, show the main home page content
        return _HomePageContent();
      },
    );
  }
}
enum ProfileMenuAction { profile, logout, toggleBg}

// The actual UI for the home page, separated for clarity
class _HomePageContent extends StatelessWidget {
  // We remove the constructor with the 'user' parameter.
  // This widget should be self-contained and get its state from the controller.
  _HomePageContent();

  // Find the AuthController instance using GetX
  final AuthController contr = Get.find<AuthController>();
  final SettingsController sc = Get.find();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'RxGuardian',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        // The back button is unconventional for a main dashboard.
        // It's better to remove it to prevent confusing navigation loops.
        // The user should explicitly log out to leave this screen.
        automaticallyImplyLeading: false,
        actions: [
          // Obx widget to reactively display the user's name
          Obx(() {
            final user = contr.user.value;
            // Only show the greeting if the user and their name are available
            if (user != null && user.name != null && user.name!.isNotEmpty) {
              final firstName = user.name!.split(' ').first;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    'Hi, $firstName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }
            // If there's no user, return an empty widget
            return const SizedBox.shrink();
          }),

          // This button handles the profile icon and its dropdown menu
          PopupMenuButton<ProfileMenuAction>(
            icon: const Icon(Icons.account_circle, size: 28),
            onSelected: (value) {
              switch (value) {
                case ProfileMenuAction.profile:
                  Navigator.of(context).pushNamed(PharmacistProfileScreen.route_name);
                  break;
                case ProfileMenuAction.toggleBg:
                  sc.changeMode();
                  break;
                case ProfileMenuAction.logout:
                // Call the logout method from the controller
                  contr.logout(context: context);
                  break;
              }
            },
            // This builds the list of items in the dropdown menu
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ProfileMenuAction>>[
              const PopupMenuItem<ProfileMenuAction>(
                value: ProfileMenuAction.profile,
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                ),
              ),
              const PopupMenuItem<ProfileMenuAction>(
                value: ProfileMenuAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
              PopupMenuItem<ProfileMenuAction>(
                value: ProfileMenuAction.toggleBg,
                child: ListTile(
                  leading: Icon(sc.darkMode.value
                      ? Icons.mode_night_rounded
                      : Icons.wb_sunny),
                  title: const Text('Toggle bg'),
                ),
              ),
            ], // CORRECTION: Closed the itemBuilder list properly
          ),
          const SizedBox(width: 8), // This now correctly sits within the actions list
        ],
      ), // CORRECTION: Closed the AppBar properly
      // CORRECTION: The 'body' must be a direct property of the Scaffold, not inside the AppBar
      body: const Center(
        child: Text(
          "Hello World",
          style: TextStyle( fontSize: 24),
        ),
      ),
    );
  }
}
