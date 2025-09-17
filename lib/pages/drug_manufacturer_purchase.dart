import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/widgets/show_toast.dart';

import '../controllers/auth_controller.dart';
import '../network/network_constants.dart';

// --- 1. DATA MODEL ---
// Represents a single drug item from the API response.
class DrugAndManufacturer {
  final int drugId;
  final String type;
  final String barcode;
  final String drugName;
  final String manufacturerName;
  final double costPrice;
  final double sellingPrice;
  final num currStock;

  DrugAndManufacturer({
    required this.drugId,
    required this.type,
    required this.barcode,
    required this.drugName,
    required this.manufacturerName,
    required this.costPrice,
    required this.sellingPrice,
    required this.currStock,
  });
  DrugAndManufacturer copyWith({
    int? drugId,
    String? type,
    String? barcode,
    String? drugName,
    String? manufacturerName,
    double? costPrice,
    double? sellingPrice,
    num? currStock,
  }) {
    return DrugAndManufacturer(
      drugId: drugId ?? this.drugId,
      type: type ?? this.type,
      barcode: barcode ?? this.barcode,
      drugName: drugName ?? this.drugName,
      manufacturerName: manufacturerName ?? this.manufacturerName,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currStock: currStock ?? this.currStock,
    );
  }
  factory DrugAndManufacturer.fromJson(Map<String, dynamic> json) {
    return DrugAndManufacturer(
      drugId: json['drug_id'],
      type: json['type'],
      barcode: json['barcode'],
      drugName: json['drug_name'],
      manufacturerName: json['manufacturer_name'],
      costPrice: json['cost_price'] ?? 0,
      sellingPrice: json['selling_price'] ?? 0,
      currStock: json['curr_stock'] ?? 0,
    );
  }
}

// --- 2. DATA CONTROLLER ---
// Handles the logic for fetching data from the API.
class DrugDataController extends GetxController {
  // Assuming AuthController is already put in memory by GetX
  final authController = Get.find<AuthController>();

  Future<List<DrugAndManufacturer>> fetchDrugs({
    String? searchDrug,
    String? searchManufacturer,
    String? searchDrugType,
    String? searchBarcode,
    int pgNo = 1,
  }) async {
    final accessToken = authController.accessToken;
    final queryParams = {
      'pgNo': pgNo.toString(),
      if (searchDrug != null && searchDrug.isNotEmpty) 'searchDrug': searchDrug,
      if (searchManufacturer != null && searchManufacturer.isNotEmpty)
        'searchManufacturer': searchManufacturer,
      if (searchDrugType != null && searchDrugType.isNotEmpty)
        'searchDrugType': searchDrugType,
      if (searchBarcode != null && searchBarcode.isNotEmpty)
        'searchBarcode': searchBarcode,
    };

    var url = Uri.http(main_uri, '/drug/getDrugAndManufacturer', queryParams);

    try {
      var res = await http.get(
        url,
        headers: {'authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        final decodedBody = jsonDecode(res.body);
        final List<dynamic> data = decodedBody['data'];
        return data.map((item) => DrugAndManufacturer.fromJson(item)).toList();
      } else {
        throw Exception(
          'Failed to load drugs: ${jsonDecode(res.body)['message']}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }

}

// --- 3. UI STATE CONTROLLER ---
// --- 3. UI STATE CONTROLLER (WITH PAGINATION) ---
class DrugAndManufacturerController extends GetxController {
  final DrugDataController _dataController = Get.put(DrugDataController());

  // --- NEW: State variables for pagination ---
  var isLoading = true.obs; // Initially true to load first page
  var isLoadingMore = false.obs; // For the bottom loading indicator
  var drugs = <DrugAndManufacturer>[].obs;
  var currentPage = 1.obs;
  var hasMoreData = true.obs;
  final scrollController = ScrollController();
  Timer? _debounce;

  // Filter Controllers
  final drugSearchController = TextEditingController();
  final manufacturerSearchController = TextEditingController();
  final drugTypeSearchController = TextEditingController();
  final barcodeSearchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Add listeners to trigger search on text change
    drugSearchController.addListener(_onSearchChanged);
    manufacturerSearchController.addListener(_onSearchChanged);
    drugTypeSearchController.addListener(_onSearchChanged);
    barcodeSearchController.addListener(_onSearchChanged);

    // --- NEW: Listen to scroll events for pagination ---
    scrollController.addListener(_scrollListener);

    // Initial fetch
    fetchInitialDrugs();
  }

  @override
  void onClose() {
    // Dispose controllers and cancel timers to prevent memory leaks
    _debounce?.cancel();
    scrollController.dispose(); // --- NEW: Dispose scroll controller
    drugSearchController.dispose();
    manufacturerSearchController.dispose();
    drugTypeSearchController.dispose();
    barcodeSearchController.dispose();
    super.onClose();
  }

  // --- NEW: Listener for the scroll controller ---
  void _scrollListener() {
    // If user scrolls to the bottom of the list, load more
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      if (hasMoreData.value && !isLoadingMore.value && !isLoading.value) {
        loadMoreDrugs();
      }
    }
  }

  Future<void> buyStock(int drugId, int quantity) async {
    final accessToken = Get.find<AuthController>().accessToken;
    var url = Uri.http(main_uri, '/drug/addDrugToStock');

    try {
      var res = await http.put(
        url,
        headers: {
          'authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'drug_id': drugId,
          'quantity': quantity,
        }),
      );
      int idx=drugs.indexWhere((e)=>e.drugId==drugId);
      log('Total for ${quantity} =${quantity*(drugs[idx].sellingPrice-drugs[idx].costPrice)}');
      if (res.statusCode == 200) {
        // --- REPLACEMENT LOGIC ---
        // 1. Find the index of the drug to update.
        final int index = drugs.indexWhere((d) => d.drugId == drugId);

        // 2. If it exists, create a new object and replace the old one.
        if (index != -1) {
          final oldDrug = drugs[index];
          final newDrug = oldDrug.copyWith(
            currStock: oldDrug.currStock + quantity,
          );
          // 3. This assignment triggers GetX to update the UI.
          drugs[index] = newDrug;
        }

        return;
        // --- END REPLACEMENT LOGIC ---
      } else {
        throw Exception(
          'Failed to load drugs: ${jsonDecode(res.body)['message']}',
        );
      }



    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }


  void _onSearchChanged() {
    // Debounce to avoid excessive API calls while typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      fetchInitialDrugs(); // A search change should reset and fetch page 1
    });
  }

  // --- MODIFIED: Fetches the very first page or a new search ---
  Future<void> fetchInitialDrugs() async {
    isLoading.value = true;
    currentPage.value = 1; // Reset to page 1
    hasMoreData.value = true; // Assume there's more data for a new search

    try {
      final result = await _dataController.fetchDrugs(
        pgNo: currentPage.value,
        searchDrug: drugSearchController.text,
        searchManufacturer: manufacturerSearchController.text,
        searchDrugType: drugTypeSearchController.text,
        searchBarcode: barcodeSearchController.text,
      );
      drugs.value = result; // Replace the list with new search results
      if (result.isNotEmpty) {
        currentPage.value++;
      } else {
        hasMoreData.value = false;
      }
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoading.value = false;
    }
  }

  // --- NEW: Fetches the next page and appends to the list ---
  Future<void> loadMoreDrugs() async {
    isLoadingMore.value = true;
    try {
      final result = await _dataController.fetchDrugs(
        pgNo: currentPage.value,
        searchDrug: drugSearchController.text,
        searchManufacturer: manufacturerSearchController.text,
        searchDrugType: drugTypeSearchController.text,
        searchBarcode: barcodeSearchController.text,
      );

      if (result.isNotEmpty) {
        drugs.addAll(result); // Append new items to the list
        currentPage.value++;
      } else {
        // No more data from the server
        hasMoreData.value = false;
      }
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoadingMore.value = false;
    }
  }

  // Keep the dialog logic the same
  void showBuyStockDialog(DrugAndManufacturer drug) {
    // ... (This function remains unchanged)
    final quantityController = TextEditingController();
    final totalCost = 0.0.obs;

    quantityController.addListener(() {
      final quantity = int.tryParse(quantityController.text) ?? 0;
      totalCost.value = quantity * drug.costPrice;
    });

    Get.dialog(
      AlertDialog(
        title: Text('Buy Stock for ${drug.drugName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cost Price: ₹${drug.costPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Enter Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => Text(
                'Total Cost: ₹${totalCost.value.toStringAsFixed(2)}',
                style: Get.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                // 1. Get the quantity as a string from the controller
                final String quantityString = quantityController.text;

                // 2. Safely parse the string into an integer
                final int? quantity = int.tryParse(quantityString);

                // 3. Validate the quantity before proceeding
                if (quantity == null || quantity <= 0) {
                  Get.snackbar(
                    'Invalid Input',
                    'Please enter a valid, positive quantity.',
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white,
                  );
                  return; // Stop execution if input is invalid
                }

                // Close the dialog
                Get.back();

                try {
                  // 4. Call buyStock with the CORRECT quantity variable
                  await buyStock(drug.drugId, quantity);

                  // Show success message ONLY after the API call succeeds
                  Get.snackbar(
                    'Success',
                    'Purchase for $quantity units of ${drug.drugName} logged.',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                  Get.snackbar('NOTE', "Details will be updated within a minute...",backgroundColor: Colors.orangeAccent);
                } catch (e) {
                  // Show an error if the API call fails
                  Get.snackbar(
                    'Error',
                    e.toString().replaceAll('Exception: ', ''),
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white,
                  );
                }
              },
            child: const Text('Confirm Purchase'),
          ),
        ],
      ),
    );
  }
}

// --- 4. UI WIDGET (THE PAGE) ---
class DrugAndManufacturerPage extends StatelessWidget {
  const DrugAndManufacturerPage({super.key});
  final route_name = drug_And_Manufacturer_route;
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DrugAndManufacturerController());
    return Scaffold(
      appBar: AppBar(title: const Text('Drug & Manufacturer Stock')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilterSection(controller),
            const SizedBox(height: 16),
            Expanded(child: _buildResultsList(controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(DrugAndManufacturerController controller) {
    // This widget remains unchanged
    return Column(
      children: [
        TextField(
          controller: controller.drugSearchController,
          decoration: const InputDecoration(
            labelText: 'Search Drug Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.medication),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.manufacturerSearchController,
                decoration: const InputDecoration(
                  labelText: 'Manufacturer',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.factory),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller.drugTypeSearchController,
                decoration: const InputDecoration(
                  labelText: 'Type (e.g., Tablet)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- MODIFIED: This widget now handles the scroll controller and loading indicator ---
  Widget _buildResultsList(DrugAndManufacturerController controller) {
    return Obx(() {
      // Show main loader only on the initial load
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.drugs.isEmpty) {
        return const Center(
          child: Text('No drugs found. Try adjusting your filters.'),
        );
      }
      // Use the ListView.builder for the main list
      return ListView.builder(
        // --- NEW: Attach the scroll controller ---
        controller: controller.scrollController,

        // --- MODIFIED: Add 1 to item count for the loading indicator at the bottom ---
        itemCount:
            controller.drugs.length + (controller.isLoadingMore.value ? 1 : 0),

        itemBuilder: (context, index) {
          // --- NEW: If it's the last item and we are loading, show a spinner ---
          if (index == controller.drugs.length) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // Otherwise, build the drug card
          final drug = controller.drugs[index];
          return _DrugCard(
            drug: drug,
            onBuyStock: () => controller.showBuyStockDialog(drug),
          );
        },
      );
    });
  }
}

class _DrugCard extends StatelessWidget {
  final DrugAndManufacturer drug;
  final VoidCallback onBuyStock;

  const _DrugCard({required this.drug, required this.onBuyStock});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              drug.drugName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              drug.manufacturerName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Stock: ${drug.currStock}',
                      style: const TextStyle(color: Colors.green),
                    ),
                    Text(
                      'Cost: ${currencyFormat.format(drug.costPrice)}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    Text(
                      'Selling: ${currencyFormat.format(drug.sellingPrice)}',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
                Text(
                  'Type: ${drug.type}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBuyStock,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Buy Stock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
