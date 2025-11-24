import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';

import '../network/network_constants.dart'; // Assuming main_uri is here

// --- DATA MODEL ---
class DrugStockDetails {
  final int drugId;
  final String drugName;
  final String drugType;
  final String barcode;
  final num dose;
  final String? code;
  final num cost;
  final int stockRemaining;
  final DateTime expiryDate;
  final String manufacturer;
  final String stockAvailabilityStatus;
  final String expiryStatus;

  DrugStockDetails({
    required this.drugId,
    required this.drugName,
    required this.drugType,
    required this.barcode,
    required this.dose,
    this.code,
    required this.cost,
    required this.stockRemaining,
    required this.expiryDate,
    required this.manufacturer,
    required this.stockAvailabilityStatus,
    required this.expiryStatus,
  });

  factory DrugStockDetails.fromJson(Map<String, dynamic> json) {
    return DrugStockDetails(
      drugId: json['drug_id'],
      drugName: json['drug_name'],
      drugType: json['drug_type'],
      barcode: json['barcode'],
      dose: json['dose'],
      code: json['code'],
      cost: json['cost'],
      stockRemaining: json['stock_remaining'],
      expiryDate: DateTime.parse(json['expiry_date']),
      manufacturer: json['manufacturer'],
      stockAvailabilityStatus: json['stock_availability_status'],
      expiryStatus: json['expiry_status'],
    );
  }
}

// --- NEW DATA CONTROLLER (Handles API Logic) ---
class PharmacyDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<List<dynamic>> getPharmacyDrugStockDetails(
      Map<String, String> queryParams) async {
    final accessToken = authController.accessToken;
    // UPDATED: Endpoint changed to match the backend route
    var url = Uri.http(main_uri, '/shop/getMyShopDrugStock', queryParams);

    try {
      var res = await http.get(url, headers: {
        'authorization': 'Bearer $accessToken',
      });

      if (res.statusCode == 200) {
        final decodedBody = jsonDecode(res.body);
        return decodedBody['data']; // Return just the list of data
      } else {
        // Throw an exception with the status code and message
        final errorBody = jsonDecode(res.body);
        throw Exception(
            'Failed to load data: ${errorBody['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Rethrow the exception to be caught by the UI controller
      throw Exception('An error occurred: ${e.toString()}');
    }
  }
}


// --- UI STATE CONTROLLER (Handles UI Logic) ---
class DrugStockController extends GetxController {
  // --- STATE VARIABLES ---
  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var drugStockList = <DrugStockDetails>[].obs;

  // --- DEPENDENCIES ---
  final PharmacyDataController _dataController = Get.put(PharmacyDataController());

  // --- PAGINATION & SEARCH ---
  var pageNumber = 1;
  var hasMoreData = true;
  final scrollController = ScrollController();
  // UPDATED: Replaced drugNameSearchController with barcodeSearchController
  final barcodeSearchController = TextEditingController();
  final drugTypeSearchController = TextEditingController();
  final manufacturerSearchController = TextEditingController();
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchDrugStockData();
    scrollController.addListener(() {
      if (scrollController.position.maxScrollExtent ==
          scrollController.offset) {
        fetchDrugStockData();
      }
    });
    // UPDATED: Listener changed to the new controller
    barcodeSearchController.addListener(_onSearchChanged);
    drugTypeSearchController.addListener(_onSearchChanged);
    manufacturerSearchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    scrollController.dispose();
    // UPDATED: Dispose the new controller
    barcodeSearchController.dispose();
    drugTypeSearchController.dispose();
    manufacturerSearchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  // --- REFACTORED DATA FETCHING METHOD ---
  Future<void> fetchDrugStockData({bool isSearch = false}) async {
    if (isLoadingMore.value || (!hasMoreData && !isSearch)) return;

    if (isSearch) {
      pageNumber = 1;
      hasMoreData = true;
      drugStockList.clear();
      isLoading(true);
    } else {
      isLoadingMore(true);
    }

    try {
      final queryParams = {
        'pgNo': pageNumber.toString(),
        // UPDATED: Query parameter changed from searchDrugName to searchBarcode
        if (barcodeSearchController.text.isNotEmpty)
          'searchBarcode': barcodeSearchController.text,
        if (drugTypeSearchController.text.isNotEmpty)
          'searchDrugType': drugTypeSearchController.text,
        if (manufacturerSearchController.text.isNotEmpty)
          'searchManufacturer': manufacturerSearchController.text,
      };

      // Call the dedicated data controller
      final List<dynamic> data =
      await _dataController.getPharmacyDrugStockDetails(queryParams);

      final newData =
      data.map((item) => DrugStockDetails.fromJson(item)).toList();

      if (newData.isEmpty) {
        hasMoreData = false;
      } else {
        drugStockList.addAll(newData);
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
      fetchDrugStockData(isSearch: true);
    });
  }
}

// --- UI WIDGET ---
class PharmacyDrugStockDetailsPage extends StatelessWidget {
  const PharmacyDrugStockDetailsPage({super.key});
  static const route_name = drug_stock_details_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DrugStockController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Drug Stock Details', style: theme.textTheme.titleLarge),
        // UPDATED: Increased height to accommodate the third search field
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(180.0),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // UPDATED: Search field changed to Barcode
                _SearchTextField(
                  controller: controller.barcodeSearchController,
                  hintText: 'Search by Barcode...',
                  icon: Icons.qr_code_scanner,
                ),
                const SizedBox(height: 8),
                _SearchTextField(
                  controller: controller.drugTypeSearchController,
                  hintText: 'Search by Drug Type...',
                  icon: Icons.category_outlined,
                ),
                const SizedBox(height: 8),
                _SearchTextField(
                  controller: controller.manufacturerSearchController,
                  hintText: 'Search by Manufacturer...',
                  icon: Icons.factory_outlined,
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
        if (controller.drugStockList.isEmpty) {
          return Center(
              child: Text("No stock data found.",
                  style: TextStyle(color: theme.hintColor)));
        }
        return ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.all(16.0),
          itemCount: controller.drugStockList.length +
              (controller.isLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == controller.drugStockList.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                    child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }
            final item = controller.drugStockList[index];
            return _DrugStockCard(details: item);
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

// --- THEME-AWARE CARD WIDGET ---
class _DrugStockCard extends StatelessWidget {
  final DrugStockDetails details;
  const _DrugStockCard({required this.details});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'very low':
        return Colors.orange;
      case 'out of stock':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiryColor =
    details.expiryStatus.toLowerCase().contains("expired")
        ? Colors.red
        : Colors.blueGrey;

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
          Text(
            details.drugName,
            style: TextStyle(
              color: theme.textTheme.titleMedium?.color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            details.manufacturer,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              _StatusChip(
                label: details.stockAvailabilityStatus,
                color: _getStatusColor(details.stockAvailabilityStatus),
              ),
              _StatusChip(
                label: details.expiryStatus,
                color: expiryColor,
                icon: Icons.calendar_today_outlined,
              ),
            ],
          ),
          Divider(color: theme.dividerColor, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailItem(
                  label: 'Stock', value: details.stockRemaining.toString()),
              _DetailItem(
                  label: 'Cost', value: '₹${details.cost.toStringAsFixed(2)}'),
              _DetailItem(label: 'Type', value: details.drugType),
              _DetailItem(label: 'Barcode', value: details.barcode),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon != null ? Icon(icon, color: color, size: 16) : null,
      label: Text(label),
      labelStyle:
      TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      backgroundColor: color.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

