import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import 'package:rxGuardian/widgets/show_toast.dart';

import '../constants/colors.dart';
import '../pages/shop_registeration.dart'; // Assuming this contains your color constants

// --- DATA MODEL ---
class PharmacistProfile {
  final int empId;
  final int pharmacistId;
  final int? shopId;
  final String pharmacistName;
  final String? shopName;
  final String? managerName;
  final int salary;
  final String role;

  PharmacistProfile({
    required this.empId,
    required this.pharmacistId,
    this.shopId,
    required this.pharmacistName,
    this.shopName,
    this.managerName,
    required this.salary,
    required this.role,
  });

  factory PharmacistProfile.fromJson(Map<String, dynamic> json) {
    return PharmacistProfile(
      empId: json['emp_id'],
      pharmacistId: json['pharmacist_id'],
      shopId: json['shop_id'],
      pharmacistName: json['pharmacist_name'],
      shopName: json['shop_name'],
      managerName: json['manager_name'],
      salary: json['salary'],
      role: json['role'],
    );
  }

  String get initials {
    if (pharmacistName.isEmpty) return '?';
    List<String> parts = pharmacistName.split(' ');
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
    } else {
      return pharmacistName[0].toUpperCase();
    }
  }
}

// --- UI WIDGET ---
class PharmacistProfileScreen extends StatefulWidget {
  const PharmacistProfileScreen({super.key});
  static const route_name = profile_route;
  @override
  State<PharmacistProfileScreen> createState() =>
      _PharmacistProfileScreenState();
}

class _PharmacistProfileScreenState extends State<PharmacistProfileScreen> {
  PharmacistProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final profileData =
      await Get.find<AuthController>().getCurrPharmacistProfile(context);
      if (mounted) {
        setState(() {
          _profile = PharmacistProfile.fromJson(profileData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showToast(context, "Failed to load profile data: ${e.toString()}",
            ToastType.ERROR);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        title: Text('Pharmacist Profile', style: GoogleFonts.poppins()),
        centerTitle: true,
        iconTheme: theme.iconTheme,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _profile == null
          ? const Center(
          child: Text(
            "Could not load profile. Please try again.",
            style: TextStyle(fontSize: 16),
          ))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 16),
                    _buildStatusChip(),
                    const SizedBox(height: 24),
                    Divider(height: 1, color: theme.dividerColor),
                    const SizedBox(height: 24),
                    _buildInfoSection(context),
                    // UPDATED: Conditionally show the "Become a Manager" button
                    if (_profile!.role.toLowerCase() != 'manager') ...[
                      const SizedBox(height: 32),
                      _buildBecomeManagerButton(context),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          child: Text(
            _profile!.initials,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _profile!.pharmacistName,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    bool isEmployed = _profile!.shopName != null;
    final color = isEmployed ? kPrimaryColor : kWarningColor;
    return Chip(
      label: Text(
        _profile!.role,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: color,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      children: [
        _buildInfoRow(
          context,
          icon: Icons.badge_outlined,
          label: 'Employee ID',
          value: _profile!.empId.toString(),
        ),
        _buildInfoRow(
          context,
          icon: Icons.person_pin_outlined,
          label: 'Pharmacist ID',
          value: _profile!.pharmacistId.toString(),
        ),
        _buildInfoRow(
          context,
          icon: Icons.store_outlined,
          label: 'Shop Name',
          value: _profile!.shopName ?? 'Not Assigned',
        ),
        _buildInfoRow(
          context,
          icon: Icons.supervisor_account_outlined,
          label: 'Manager Name',
          value: _profile!.managerName ?? 'N/A',
        ),
        _buildInfoRow(
          context,
          icon: Icons.wallet_outlined,
          label: 'Salary',
          value: _profile!.salary == 0 ? 'N/A' : '₹${_profile!.salary}',
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: theme.iconTheme.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW WIDGET: Button to navigate to the shop registration page.
  Widget _buildBecomeManagerButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        // Navigate to the ShopRegistrationPage
        Navigator.of(context).pushNamed(ShopRegistrationPage.route_name);
      },
      icon: const Icon(Icons.add_business_outlined),
      label: const Text('Become a Manager / Register Shop'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
