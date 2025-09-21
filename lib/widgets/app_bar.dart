import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxGuardian/widgets/notification.dart';
import 'package:rxGuardian/widgets/pharmacist_profile.dart';

import '../controllers/auth_controller.dart';
import '../controllers/setting_controller.dart';

enum ProfileMenuAction { profile, logout, toggleBg }

PreferredSizeWidget myAppBar(BuildContext context) {
  final AuthController contr = Get.find<AuthController>();
  final SettingsController sc = Get.find();
  return AppBar(
    elevation: 0,
    title: Text(
      'RxGuardian',
      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
    ),
    // The back button is unconventional for a main dashboard.
    // It's better to remove it to prevent confusing navigation loops.
    // The user should explicitly log out to leave this screen.
    automaticallyImplyLeading: false,
    actions: [
      NotificationIcon(),
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
              Navigator.of(
                context,
              ).pushNamed(PharmacistProfileScreen.route_name);
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
        itemBuilder:
            (BuildContext context) => <PopupMenuEntry<ProfileMenuAction>>[
              const PopupMenuItem<ProfileMenuAction>(
                value: ProfileMenuAction.profile,
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                ),
              ),
              PopupMenuItem<ProfileMenuAction>(
                value: ProfileMenuAction.toggleBg,
                child: ListTile(
                  leading: Icon(
                    sc.darkMode.value
                        ? Icons.mode_night_rounded
                        : Icons.wb_sunny,
                  ),
                  title: const Text('Toggle bg'),
                ),
              ),
              const PopupMenuItem<ProfileMenuAction>(
                value: ProfileMenuAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ], // CORRECTION: Closed the itemBuilder list properly
      ),
      const SizedBox(
        width: 8,
      ), // This now correctly sits within the actions list
    ],
  );
}
