import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';

import '../network/network_constants.dart'; // Assuming main_uri is here

// --- DATA MODEL ---
class ManufacturerPerformance {
  final String manufacturerName;
  final String drugType;
  final double avgSellingPrice;
  final double avgProfitPercent;
  final String avgSoldPerMonth;
  final String avgSoldPerYear;

  ManufacturerPerformance({
    required this.manufacturerName,
    required this.drugType,
    required this.avgSellingPrice,
    required this.avgProfitPercent,
    required this.avgSoldPerMonth,
    required this.avgSoldPerYear,
  });

  factory ManufacturerPerformance.fromJson(Map<String, dynamic> json) {
    return ManufacturerPerformance(
      manufacturerName: json['manufacturer_name'],
      drugType: json['drug_type'],
      avgSellingPrice: (json['avg_selling_price'] as num).toDouble(),
      avgProfitPercent: (json['avg_profit_percent'] as num).toDouble(),
      avgSoldPerMonth: json['avg_sold_per_month'],
      avgSoldPerYear: json['avg_sold_per_year'],
    );
  }
}

// --- GetX CONTROLLER ---
// Manages state and logic, now with two search controllers.
class ShopPurchaseAnalysisController extends GetxController {
  // --- STATE VARIABLES ---
  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var performanceData = <ManufacturerPerformance>[].obs;

  // --- PAGINATION & SEARCH ---
  var pageNumber = 1;
  var hasMoreData = true;
  final scrollController = ScrollController();
  final manufacturerSearchController = TextEditingController();
  final drugTypeSearchController = TextEditingController(); // New controller for drug type
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchPerformanceData();
    scrollController.addListener(() {
      if (scrollController.position.maxScrollExtent == scrollController.offset) {
        fetchPerformanceData();
      }
    });
    // Listen to changes on both search fields
    manufacturerSearchController.addListener(_onSearchChanged);
    drugTypeSearchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    scrollController.dispose();
    manufacturerSearchController.dispose();
    drugTypeSearchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  // --- API CALL LOGIC ---
  Future<void> fetchPerformanceData({bool isSearch = false}) async {
    if (isLoadingMore.value || (!hasMoreData && !isSearch)) return;

    if (isSearch) {
      pageNumber = 1;
      hasMoreData = true;
      performanceData.clear();
      isLoading(true);
    } else {
      isLoadingMore(true);
    }

    try {
      final authController = Get.find<AuthController>();
      final accessToken = authController.accessToken;

      // Build query parameters with both search fields
      final queryParams = {
        'pgNo': pageNumber.toString(),
        if (manufacturerSearchController.text.isNotEmpty)
          'searchManufacturer': manufacturerSearchController.text,
        if (drugTypeSearchController.text.isNotEmpty)
          'searchDrugType': drugTypeSearchController.text,
      };

      var url = Uri.http(main_uri, '/shop/getMyShopAnalysis', queryParams);
      var res = await http.get(url, headers: {
        'authorization': 'Bearer $accessToken',
      });

      if (res.statusCode == 200) {
        final decodedBody = jsonDecode(res.body);
        final List<dynamic> data = decodedBody['data'];
        final newData = data.map((item) => ManufacturerPerformance.fromJson(item)).toList();

        if (newData.isEmpty) {
          hasMoreData = false;
        } else {
          performanceData.addAll(newData);
          pageNumber++;
        }
      } else {
        Get.snackbar('Notice', 'Could not fetch data or end of list reached.',
            backgroundColor: kWarningColor, colorText: Colors.white);
        hasMoreData = false;
      }
    } catch (err) {
      Get.snackbar('Error', "An exception occurred: ${err.toString()}",
          backgroundColor: kErrorColor, colorText: Colors.white);
      hasMoreData = false;
    } finally {
      isLoading(false);
      isLoadingMore(false);
    }
  }

  // --- SEARCH DEBOUNCING ---
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      fetchPerformanceData(isSearch: true);
    });
  }
}

// --- UI WIDGET ---
class ShopPurchaseAnalysisPage extends StatelessWidget {
  const ShopPurchaseAnalysisPage({super.key});
  static const route_name = shop_purchase_analysis_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShopPurchaseAnalysisController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Pharmacy purchase analysis', style: theme.textTheme.titleLarge),
        // Use the 'bottom' property for a dedicated filter section
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // Manufacturer Search Field
                _SearchTextField(
                  controller: controller.manufacturerSearchController,
                  hintText: 'Search by Manufacturer...',
                  icon: Icons.factory_outlined,
                ),
                const SizedBox(height: 8),
                // Drug Type Search Field
                _SearchTextField(
                  controller: controller.drugTypeSearchController,
                  hintText: 'Search by Drug Type...',
                  icon: Icons.medication_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        }
        if (controller.performanceData.isEmpty) {
          return Center(child: Text("No data found.", style: TextStyle(color: theme.hintColor)));
        }
        return ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.all(16.0),
          itemCount: controller.performanceData.length + (controller.isLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == controller.performanceData.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }
            final item = controller.performanceData[index];
            return _ManufacturerStatCard(performance: item);
          },
        );
      }),
    );
  }
}

// --- Helper widget for a consistent search text field style ---
class _SearchTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  const _SearchTextField({required this.controller, required this.hintText, required this.icon});

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
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}


// --- THEME-AWARE CARD AND STAT WIDGETS ---
// (These widgets remain the same as they are already theme-aware)

class _ManufacturerStatCard extends StatelessWidget {
  final ManufacturerPerformance performance;
  const _ManufacturerStatCard({required this.performance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                backgroundColor: kPrimaryColor.withOpacity(0.1),
                child: const Icon(Icons.factory_outlined, color: kPrimaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      performance.manufacturerName,
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleMedium?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Drug Type: ${performance.drugType}',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(color: theme.dividerColor, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                icon: Icons.price_change_outlined,
                label: 'Avg. Price',
                value: '₹${performance.avgSellingPrice.toStringAsFixed(2)}',
                iconColor: Colors.blue.shade300,
              ),
              _StatItem(
                icon: Icons.trending_up_rounded,
                label: 'Avg. Profit',
                value: '${performance.avgProfitPercent.toStringAsFixed(2)}%',
                iconColor: kPrimaryColor,
              ),
              _StatItem(
                icon: Icons.shopping_cart_checkout_rounded,
                label: 'Monthly Sales',
                value: performance.avgSoldPerMonth,
                iconColor: Colors.orange.shade300,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = kPrimaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: theme.textTheme.bodySmall?.color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

