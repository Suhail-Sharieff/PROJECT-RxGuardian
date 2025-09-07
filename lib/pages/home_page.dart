import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:highlight/languages/http.dart';
import 'package:http/http.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import 'package:rxGuardian/pages/verify_email_page.dart';
import 'package:rxGuardian/widgets/app_bar.dart';
import 'package:rxGuardian/widgets/feature_card.dart';
import 'package:rxGuardian/widgets/show_toast.dart';
import '../constants/routes.dart';

// Import pages to navigate to

import '../controllers/setting_controller.dart';
import '../network/network_constants.dart';
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
      appBar: myAppBar(context), // CORRECTION: Closed the AppBar properly
      // CORRECTION: The 'body' must be a direct property of the Scaffold, not inside the AppBar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16.0, // Horizontal space between cards
          runSpacing: 16.0, // Vertical space between cards
          children: [
            FeatureCard(
              icon: Icons.inventory_2_outlined,
              title: 'Inventory',
              description:
                  'Manage drug stock, view expiry dates, and handle inventory.',
              onTap: () {
                // TODO: Navigate to Inventory Page
                Navigator.of(context).pushNamed(drug_stock_details_route);
              },
            ),
            FeatureCard(
              icon: Icons.point_of_sale_outlined,
              title: 'Billing Console',
              description:
                  'Process customer sales, generate invoices, and manage transactions.',
              onTap: () {
                // TODO: Navigate to Billing/POS Page
                Navigator.of(context).pushNamed(billing_console_route);
              },
            ),
            FeatureCard(
              icon: Icons.analytics_outlined,
              title: 'Pharmacy Purchase Analysis',
              description:
                  'View sales reports with manufacturers , track revenue, and analyze performance.',
              onTap: () {
                // TODO: Navigate to Analytics Page
                Navigator.of(context).pushNamed(shop_purchase_analysis_route);
              },
            ),
            FeatureCard(
              icon: Icons.people_outline,
              title: 'Manager Console',
              description:
                  'View employee roster and manage staff details',
              onTap: () async{
                // TODO: Navigate to Staff Management Page
                var res=await contr.verifyManagerAccess();
                if(res) {
                  Navigator.of(context).pushNamed(manager_console_route);
                } else {
                  showToast(context, "You dont have access to this console only your manager does!", ToastType.WARNING);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW REUSABLE WIDGET FOR FEATURE CARDS ---
