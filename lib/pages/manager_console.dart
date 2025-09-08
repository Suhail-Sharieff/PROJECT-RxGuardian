import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/pages/hiring_console.dart';

import '../widgets/feature_card.dart';
import 'employee_details.dart';

// --- UI WIDGET FOR MANAGER CONSOLE ---
class ManagerConsolePage extends StatelessWidget {
  const ManagerConsolePage({super.key});
  static const route_name = manager_console_route; // Define a route name

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Manager Console', style: theme.textTheme.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16.0, // Horizontal space between cards
          runSpacing: 16.0, // Vertical space between cards
          alignment: WrapAlignment.center,
          children: [
            // Card to navigate to the Employee Details Page
            FeatureCard(
              icon: Icons.people_alt_outlined,
              title: 'Manage Employees',
              description:
              'View, search, and manage employee details for your shop.',
              onTap: () {
                // Navigate to the existing EmployeeDetailPage
                Navigator.of(context).pushNamed(EmployeeDetailPage.route_name);
              },
            ),
            // Placeholder for another manager feature
            FeatureCard(
              icon: Icons.analytics_outlined,
              title: 'Hire Pharmacists',
              description:
              'Hire talent pool in community across world',
              onTap: () {
                // TODO: Navigate to Shop Analysis Page
                Navigator.of(context).pushNamed(HiringConsolePage.route_name);
              },
            ),
            // Placeholder for another manager feature
            FeatureCard(
              icon: Icons.receipt_long_outlined,
              title: 'Pharmacy Purchases',
              description: 'Generate and view detailed stock purchase reports.',
              onTap: () {
                // TODO: Navigate to Sales Reports Page
                Navigator.of(context).pushNamed(shop_purchase_analysis_route);
              },
            ),
            // Placeholder for another manager feature

          ],
        ),
      ),
    );
  }
}

