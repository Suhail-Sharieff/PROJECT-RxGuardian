import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxGuardian/pages/verify_email_page.dart';

// Import your enhanced pages
import '../constants/colors.dart';
import '../constants/routes.dart';

// Import pages to navigate to

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
            backgroundColor: kBackgroundColor,
            body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
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
        return _HomePageContent(user: user);
      },
    );
  }
}

// The actual UI for the home page, separated for clarity
class _HomePageContent extends StatelessWidget {
  final User user;
  const _HomePageContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
      backgroundColor: kBackgroundColor,
      elevation: 0,
      title: Text(
        'RxGuardian',
        style: GoogleFonts.poppins(
          // Add this line to make the text visible
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kSecondaryTextColor),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70), // Also good to set icon color explicitly
          tooltip: 'Logout',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
        ),
        const SizedBox(width: 8),
      ],
    ),
      body:Center(child: Text("Hello Worild"),)
    );
  }



}