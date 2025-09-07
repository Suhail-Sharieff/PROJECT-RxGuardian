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

// --- DATA MODELS ---

/// Represents a drug found via the search API.
class DrugSearchResult {
  final int drugId;
  final String name;
  final num sellingPrice;
  final int stockRemaining;

  DrugSearchResult({
    required this.drugId,
    required this.name,
    required this.sellingPrice,
    required this.stockRemaining,
  });

  factory DrugSearchResult.fromJson(Map<String, dynamic> json) {
    return DrugSearchResult(
      drugId: json['drug_id'],
      name: json['name'],
      sellingPrice: json['selling_price'],
      stockRemaining: json['stock_remaining'],
    );
  }
}

/// Represents an item added to the billing cart.
class CartItem {
  final DrugSearchResult drug;
  RxInt quantity;
  RxDouble discount;

  CartItem({required this.drug, int quantity = 1, double discount = 0.0})
      : quantity = quantity.obs,
        discount = discount.obs;

  double get totalPrice => (drug.sellingPrice * quantity.value) - discount.value;
}

// --- DATA CONTROLLER (API Logic) ---
class BillingDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<List<dynamic>> searchDrugs(String searchTerm) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/sale/searchDrug', {'search': searchTerm});

    try {
      var res = await http.get(url, headers: {'authorization': 'Bearer $accessToken'});
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data'];
      } else {
        throw Exception('Failed to search drugs: ${jsonDecode(res.body)['message']}');
      }
    } catch (e) {
      throw Exception('An error occurred while searching: ${e.toString()}');
    }
  }

  Future<void> createSale(List<Map<String, dynamic>> saleItems) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/sale/create');
    try {
      var res = await http.post(
        url,
        headers: {
          'authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'items': saleItems}),
      );
      if (res.statusCode != 201) {
        throw Exception('Failed to create sale: ${jsonDecode(res.body)['message']}');
      }
    } catch (e) {
      throw Exception('An error occurred during sale creation: ${e.toString()}');
    }
  }
}

// --- UI STATE CONTROLLER ---
class BillingUIController extends GetxController {
  final BillingDataController _dataController = Get.put(BillingDataController());

  var searchResults = <DrugSearchResult>[].obs;
  var isSearching = false.obs;
  var cartItems = <CartItem>[].obs;
  Timer? _debounce;
  final searchController = TextEditingController();

  // Computed properties for the bill summary
  double get subtotal => cartItems.fold(0, (sum, item) => sum + (item.drug.sellingPrice * item.quantity.value));
  double get totalDiscount => cartItems.fold(0, (sum, item) => sum + item.discount.value);
  double get grandTotal => subtotal - totalDiscount;

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
    super.onClose();
  }

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    isSearching.value = true;
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (query.length < 2) {
        searchResults.clear();
        isSearching.value = false;
        return;
      }
      try {
        final data = await _dataController.searchDrugs(query);
        searchResults.value = data.map((item) => DrugSearchResult.fromJson(item)).toList();
      } catch (e) {
        Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''), backgroundColor: kErrorColor, colorText: Colors.white);
      } finally {
        isSearching.value = false;
      }
    });
  }

  void addItemToCart(DrugSearchResult drug) {
    // Check if item already exists in cart
    var existingItem = cartItems.firstWhereOrNull((item) => item.drug.drugId == drug.drugId);
    if (existingItem != null) {
      // If it exists, just increment quantity
      existingItem.quantity.value++;
    } else {
      // Otherwise, add new item
      cartItems.add(CartItem(drug: drug));
    }
    searchController.clear();
    searchResults.clear();
  }

  void clearCart() {
    cartItems.clear();
  }

  Future<void> finalizeSale() async {
    if (cartItems.isEmpty) {
      Get.snackbar('Warning', 'Cannot finalize an empty bill.', backgroundColor: kWarningColor, colorText: Colors.white);
      return;
    }
    try {
      final saleItems = cartItems.map((item) => {
        'drug_id': item.drug.drugId,
        'quantity': item.quantity.value,
        'discount': item.discount.value
      }).toList();

      await _dataController.createSale(saleItems);
      Get.snackbar('Success', 'Sale created successfully!', backgroundColor: kPrimaryColor, colorText: Colors.white);
      clearCart();

    } catch(e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''), backgroundColor: kErrorColor, colorText: Colors.white);
    }
  }
}

// --- UI WIDGET ---
class BillingConsolePage extends StatelessWidget {
  const BillingConsolePage({super.key});
  static const route_name = billing_console_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BillingUIController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Billing Console', style: theme.textTheme.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _DrugSearchSection(),
            const SizedBox(height: 16),
            Expanded(child: _CurrentBillSection()),
            const SizedBox(height: 16),
            _BillSummarySection(),
          ],
        ),
      ),
    );
  }
}

class _DrugSearchSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BillingUIController>();
    final theme = Theme.of(context);
    return Column(
      children: [
        TextField(
          controller: controller.searchController,
          onChanged: controller.onSearchChanged,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: 'Search for drugs by name or barcode...',
            hintStyle: TextStyle(color: theme.hintColor),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: Obx(() => controller.isSearching.value ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
            filled: true,
            fillColor: theme.dividerColor.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        Obx(() {
          if (controller.searchResults.isNotEmpty) {
            return SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: controller.searchResults.length,
                itemBuilder: (context, index) {
                  final drug = controller.searchResults[index];
                  return ListTile(
                    title: Text(drug.name, style: theme.textTheme.bodyMedium),
                    subtitle: Text('Stock: ${drug.stockRemaining} | Price: ₹${drug.sellingPrice}', style: theme.textTheme.bodySmall),
                    onTap: () => controller.addItemToCart(drug),
                  );
                },
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}

class _CurrentBillSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BillingUIController>();
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Bill', style: theme.textTheme.titleMedium),
                TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  onPressed: controller.clearCart,
                  style: TextButton.styleFrom(foregroundColor: kErrorColor),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (controller.cartItems.isEmpty) {
                return const Center(child: Text('No items added yet.'));
              }
              return ListView.builder(
                itemCount: controller.cartItems.length,
                itemBuilder: (context, index) {
                  final item = controller.cartItems[index];
                  return _CartItemTile(item: item);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.drug.name,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Obx(() => Text('₹${item.totalPrice.toStringAsFixed(2)}', style: theme.textTheme.bodyLarge)),
              IconButton(onPressed: () => Get.find<BillingUIController>().cartItems.remove(item), icon: const Icon(Icons.close, size: 18, color: kErrorColor))
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Quantity Control
              const Text('Qty:'),
              SizedBox(
                width: 30,
                child: Obx(() => TextField(
                  controller: TextEditingController(text: item.quantity.value.toString()),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => item.quantity.value = int.tryParse(val) ?? 1,
                  decoration: const InputDecoration(border: InputBorder.none),
                )),
              ),
              const SizedBox(width: 16),
              // Discount Control
              const Text('Discount (₹):'),
              SizedBox(
                width: 50,
                child: Obx(() => TextField(
                  controller: TextEditingController(text: item.discount.value.toString()),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => item.discount.value = double.tryParse(val) ?? 0.0,
                  decoration: const InputDecoration(border: InputBorder.none),
                )),
              )
            ],
          )
        ],
      ),
    );
  }
}

class _BillSummarySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BillingUIController>();
    final theme = Theme.of(context);
    return Column(
      children: [
        Obx(() => Column(
          children: [
            _SummaryRow(label: 'Subtotal', value: '₹${controller.subtotal.toStringAsFixed(2)}'),
            _SummaryRow(label: 'Total Discount', value: '- ₹${controller.totalDiscount.toStringAsFixed(2)}'),
            const Divider(),
            _SummaryRow(label: 'Grand Total', value: '₹${controller.grandTotal.toStringAsFixed(2)}', isTotal: true),
          ],
        )),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: controller.finalizeSale,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            child: const Text('Finalize Sale'),
          ),
        )
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = isTotal
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
