import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import '../network/network_constants.dart';

// --- DATA MODEL ---
class EmployablePharmacist {
  final int pharmacistId;
  final String name;
  final String email;
  final num prevSalary;
  final String experience;

  EmployablePharmacist({
    required this.pharmacistId,
    required this.name,
    required this.email,
    required this.prevSalary,
    required this.experience,
  });

  factory EmployablePharmacist.fromJson(Map<String, dynamic> json) {
    return EmployablePharmacist(
      pharmacistId: json['pharmacist_id'],
      name: json['name'],
      email: json['email'],
      prevSalary: json['prev_salary'],
      experience: json['experience'],
    );
  }
}

// --- DATA CONTROLLER (Handles API Logic) ---
class HiringDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<List<dynamic>> getEmployablePharmacists(
      Map<String, String> queryParams) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/manager/getAllEmployables', queryParams);

    try {
      var res = await http.get(url, headers: {
        'authorization': 'Bearer $accessToken',
      });

      if (res.statusCode == 200) {
        final decodedBody = jsonDecode(res.body);
        return decodedBody['data'];
      } else {
        final errorBody = jsonDecode(res.body);
        throw Exception(
            'Failed to load data: ${errorBody['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }

  // API call to hire a pharmacist
  Future<void> hirePharmacist(int pharmacistId) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/manager/hirePharmacist');
    try {
      var res = await http.patch(
        url,
        headers: {
          'authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pharmacist_id': pharmacistId}),
      );
      if (res.statusCode != 200) {
        final errorBody = jsonDecode(res.body);
        throw Exception(
            'Failed to hire pharmacist: ${errorBody['message'] ?? 'Server error'}');
      }
    } catch (e) {
      throw Exception('An error occurred while hiring: ${e.toString()}');
    }
  }
}

// --- UI STATE CONTROLLER ---
class HiringUIController extends GetxController {
  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var pharmacistList = <EmployablePharmacist>[].obs;

  final HiringDataController _dataController = Get.put(HiringDataController());

  var pageNumber = 1;
  var hasMoreData = true;
  final scrollController = ScrollController();
  final nameSearchController = TextEditingController();
  final idSearchController = TextEditingController();
  final emailSearchController = TextEditingController();
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchPharmacistData();
    scrollController.addListener(() {
      if (scrollController.position.maxScrollExtent == scrollController.offset) {
        fetchPharmacistData();
      }
    });
    nameSearchController.addListener(_onSearchChanged);
    idSearchController.addListener(_onSearchChanged);
    emailSearchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    scrollController.dispose();
    nameSearchController.dispose();
    idSearchController.dispose();
    emailSearchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> fetchPharmacistData({bool isSearch = false}) async {
    if (isLoadingMore.value || (!hasMoreData && !isSearch)) return;

    if (isSearch) {
      pageNumber = 1;
      hasMoreData = true;
      pharmacistList.clear();
      isLoading(true);
    } else {
      isLoadingMore(true);
    }

    try {
      final queryParams = {
        'pgNo': pageNumber.toString(),
        if (nameSearchController.text.isNotEmpty)
          'searchPharmacistByName': nameSearchController.text,
        if (idSearchController.text.isNotEmpty)
          'searchPharmacistById': idSearchController.text,
        if (emailSearchController.text.isNotEmpty)
          'searchPharmacistByEmail': emailSearchController.text,
      };

      final List<dynamic> data =
      await _dataController.getEmployablePharmacists(queryParams);
      final newData =
      data.map((item) => EmployablePharmacist.fromJson(item)).toList();

      if (newData.isEmpty) {
        hasMoreData = false;
        if (pageNumber > 1) {
          Get.snackbar("Notice", "You've reached the end of the list.",
              backgroundColor: kWarningColor, colorText: Colors.white);
        }
      } else {
        pharmacistList.addAll(newData);
        pageNumber++;
      }
    } catch (err) {
      Get.snackbar('Error', err.toString().replaceAll('Exception: ', ''),
          backgroundColor: kErrorColor, colorText: Colors.white);
      hasMoreData = false;
    } finally {
      isLoading(false);
      isLoadingMore(false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      fetchPharmacistData(isSearch: true);
    });
  }

  // Method to handle the hiring logic
  Future<void> handleHirePharmacist(int pharmacistId) async {
    try {
      await _dataController.hirePharmacist(pharmacistId);
      // Remove from the list locally for instant UI feedback
      pharmacistList.removeWhere((p) => p.pharmacistId == pharmacistId);
      Get.snackbar('Success', 'Pharmacist hired successfully!',
          backgroundColor: kPrimaryColor, colorText: Colors.white);
    } catch (err) {
      Get.snackbar('Error', err.toString().replaceAll('Exception: ', ''),
          backgroundColor: kErrorColor, colorText: Colors.white);
    }
  }
}

// --- UI WIDGET ---
class HiringConsolePage extends StatelessWidget {
  const HiringConsolePage({super.key});
  static const route_name = hiring_console_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HiringUIController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Hiring Console', style: theme.textTheme.titleLarge),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(180.0),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                _SearchTextField(
                  controller: controller.nameSearchController,
                  hintText: 'Search by Name...',
                  icon: Icons.person_search_outlined,
                ),
                const SizedBox(height: 8),
                _SearchTextField(
                  controller: controller.idSearchController,
                  hintText: 'Search by ID...',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 8),
                _SearchTextField(
                  controller: controller.emailSearchController,
                  hintText: 'Search by Email...',
                  icon: Icons.alternate_email_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor));
        }
        if (controller.pharmacistList.isEmpty) {
          return Center(
              child: Text("No candidates found.",
                  style: TextStyle(color: theme.hintColor)));
        }
        return ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.all(16.0),
          itemCount: controller.pharmacistList.length +
              (controller.isLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == controller.pharmacistList.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                    child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }
            final item = controller.pharmacistList[index];
            return _PharmacistCard(pharmacist: item);
          },
        );
      }),
    );
  }
}

// --- Helper for Search Fields ---
class _SearchTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  const _SearchTextField(
      {required this.controller, required this.hintText, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.hintColor),
        prefixIcon: Icon(icon, color: theme.hintColor, size: 20),
        filled: true,
        fillColor: theme.dividerColor.withOpacity(0.1),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// --- THEME-AWARE PHARMACIST CARD WIDGET ---
class _PharmacistCard extends StatelessWidget {
  final EmployablePharmacist pharmacist;
  const _PharmacistCard({required this.pharmacist});

  void _showConfirmationDialog(BuildContext context, HiringUIController controller) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Confirm Hire', style: theme.textTheme.titleLarge),
          content: Text(
              'Are you sure you want to hire ${pharmacist.name} for your shop?',
              style: theme.textTheme.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              onPressed: () async {
                await controller.handleHirePharmacist(pharmacist.pharmacistId);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text('Confirm', style: TextStyle(color: theme.colorScheme.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<HiringUIController>();

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                child: Icon(Icons.person_add_alt_1_outlined,
                    color: theme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pharmacist.name ,
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleMedium?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      pharmacist.email,
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(color: theme.dividerColor, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                  label: 'Contact',
                  value: pharmacist.email,
                  icon: Icons.alternate_email),
              _StatItem(
                  label: 'Experience',
                  value: pharmacist.experience,
                  icon: Icons.work_history_outlined),
              _StatItem(
                  label: 'Previous Salary',
                  value: '₹${pharmacist.prevSalary}',
                  icon: Icons.wallet_outlined),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Hire This Pharmacist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor.withOpacity(0.8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _showConfirmationDialog(context, controller);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: theme.textTheme.bodySmall?.color,
            fontSize: 12,
          ),
        ),
        Row(
          children: [
            Icon(icon, color: theme.iconTheme.color?.withOpacity(0.7), size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
