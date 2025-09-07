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

/// Represents a drug found via the search API, now with more details.
class DrugSearchResult {
  final int drugId;
  final String drugName;
  final String drugType;
  final String manufacturer;
  final String expiryStatus;
  final num sellingPrice;
  final int stockRemaining;

  DrugSearchResult({
    required this.drugId,
    required this.drugName,
    required this.drugType,
    required this.manufacturer,
    required this.expiryStatus,
    required this.sellingPrice,
    required this.stockRemaining,
  });

  factory DrugSearchResult.fromJson(Map<String, dynamic> json) {
    return DrugSearchResult(
      drugId: json['drug_id'],
      drugName: json['drug_name'],
      drugType: json['drug_type'],
      manufacturer: json['manufacturer'],
      expiryStatus: json['expiry_status'],
      sellingPrice: json['selling_price'] ?? json['cost'] ?? 0,
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

  num get itemSubtotal => drug.sellingPrice * quantity.value;
  double get totalItemPrice => itemSubtotal - discount.value;
}

// --- DATA CONTROLLER (API Logic) ---
class BillingDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<List<dynamic>> searchDrugs(Map<String, String> queryParams) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/shop/getMyShopDrugStock', queryParams);
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

  final nameSearchController = TextEditingController();
  final manufacturerSearchController = TextEditingController();
  final drugTypeSearchController = TextEditingController();
  final barcodeSearchController = TextEditingController();

  var finalDiscount = 0.0.obs;
  // ADDED: GST Rate constant. Could be fetched from settings.
  final double gstRate = 18.0; // Example: 18% GST

  // Computed properties for the bill summary
  double get subtotal => cartItems.fold(0, (sum, item) => sum + item.itemSubtotal);
  double get totalItemDiscount => cartItems.fold(0, (sum, item) => sum + item.discount.value);
  // ADDED: New computed properties for GST calculation
  double get totalAfterItemDiscounts => subtotal - totalItemDiscount;
  double get gstAmount => totalAfterItemDiscounts > 0 ? totalAfterItemDiscounts * (gstRate / 100) : 0;
  // UPDATED: Grand total now includes GST
  double get grandTotal => totalAfterItemDiscounts + gstAmount - finalDiscount.value;

  @override
  void onInit() {
    super.onInit();
    nameSearchController.addListener(_onSearchChanged);
    manufacturerSearchController.addListener(_onSearchChanged);
    drugTypeSearchController.addListener(_onSearchChanged);
    barcodeSearchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    _debounce?.cancel();
    nameSearchController.dispose();
    manufacturerSearchController.dispose();
    drugTypeSearchController.dispose();
    barcodeSearchController.dispose();
    super.onClose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    isSearching.value = true;
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      if (nameSearchController.text.isNotEmpty ||
          manufacturerSearchController.text.isNotEmpty ||
          drugTypeSearchController.text.isNotEmpty ||
          barcodeSearchController.text.isNotEmpty) {
        try {
          final queryParams = {
            if (nameSearchController.text.isNotEmpty) 'searchByName': nameSearchController.text,
            if (manufacturerSearchController.text.isNotEmpty) 'searchManufacturer': manufacturerSearchController.text,
            if (drugTypeSearchController.text.isNotEmpty) 'searchDrugType': drugTypeSearchController.text,
            if (barcodeSearchController.text.isNotEmpty) 'searchBarcodeType': barcodeSearchController.text,
          };

          final data = await _dataController.searchDrugs(queryParams);
          searchResults.value = data.map((item) => DrugSearchResult.fromJson(item)).toList();
        } catch (e) {
          Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''), backgroundColor: kErrorColor, colorText: Colors.white);
        } finally {
          isSearching.value = false;
        }
      } else {
        searchResults.clear();
        isSearching.value = false;
      }
    });
  }

  void addItemToCart(DrugSearchResult drug) {
    var existingItem = cartItems.firstWhereOrNull((item) => item.drug.drugId == drug.drugId);
    if (existingItem != null) {
      existingItem.quantity.value++;
    } else {
      cartItems.add(CartItem(drug: drug));
    }
    searchResults.clear();
    nameSearchController.clear();
    manufacturerSearchController.clear();
    drugTypeSearchController.clear();
    barcodeSearchController.clear();
  }

  void clearCart() {
    cartItems.clear();
    finalDiscount.value = 0.0;
  }

  Future<void> finalizeSale() async {
    if (cartItems.isEmpty) {
      Get.snackbar('Warning', 'Cannot finalize an empty bill.', backgroundColor: kWarningColor, colorText: Colors.white);
      return;
    }
    try {
      final double preFinalDiscountTotal = subtotal - totalItemDiscount;

      final saleItems = cartItems.map((item) {
        double proportionalDiscount = 0.0;
        if (preFinalDiscountTotal > 0) {
          proportionalDiscount = (item.totalItemPrice / preFinalDiscountTotal) * finalDiscount.value;
        }
        return {
          'drug_id': item.drug.drugId,
          'quantity': item.quantity.value,
          'discount': item.discount.value + proportionalDiscount,
        };
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
    Get.put(BillingUIController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Billing Console', style: theme.textTheme.titleLarge),
      ),
      // UPDATED: Body is now wrapped in a SingleChildScrollView to prevent overflow
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _DrugSearchSection(),
            const SizedBox(height: 16),
            // UPDATED: _CurrentBillSection is no longer wrapped in Expanded
            _CurrentBillSection(),
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
        _SearchField(
            controller: controller.nameSearchController,
            hintText: 'Search by Name...',
            icon: Icons.abc
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Advanced Filters', style: theme.textTheme.bodySmall),
          children: [
            const SizedBox(height: 8),
            _SearchField(
              controller: controller.manufacturerSearchController,
              hintText: 'Filter by Manufacturer...',
              icon: Icons.factory_outlined,
            ),
            const SizedBox(height: 8),
            _SearchField(
              controller: controller.drugTypeSearchController,
              hintText: 'Filter by Drug Type...',
              icon: Icons.category_outlined,
            ),
            const SizedBox(height: 8),
            _SearchField(
              controller: controller.barcodeSearchController,
              hintText: 'Filter by Barcode...',
              icon: Icons.qr_code_scanner_outlined,
            ),
          ],
        ),
        Obx(() {
          if (controller.searchResults.isNotEmpty) {
            return Container(
              decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)) ]
              ),
              height: 250,
              child: ListView.separated(
                itemCount: controller.searchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final drug = controller.searchResults[index];
                  return _SearchResultCard(drug: drug);
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  const _SearchField({required this.controller, required this.hintText, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.hintColor),
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: theme.dividerColor.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final DrugSearchResult drug;
  const _SearchResultCard({required this.drug});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<BillingUIController>();

    return InkWell(
      onTap: () => controller.addItemToCart(drug),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(drug.drugName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text(drug.manufacturer, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('₹${drug.sellingPrice}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: kPrimaryColor)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(label: 'Stock: ${drug.stockRemaining}', color: Colors.blueGrey),
                const SizedBox(width: 8),
                _InfoChip(label: drug.drugType, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(child: _InfoChip(label: drug.expiryStatus, color: Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
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
          // UPDATED: ListView is no longer in an Expanded widget
          Obx(() {
            if (controller.cartItems.isEmpty) {
              return const SizedBox(
                  height: 100, // Give it a minimum height when empty
                  child: Center(child: Text('No items added yet.'))
              );
            }
            return ListView.builder(
              // UPDATED: Added shrinkWrap and physics for nested scrolling
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.cartItems.length,
              itemBuilder: (context, index) {
                final item = controller.cartItems[index];
                return _CartItemTile(item: item);
              },
            );
          }),
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
                child: Text(item.drug.drugName,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Obx(() => Text('₹${item.totalItemPrice.toStringAsFixed(2)}', style: theme.textTheme.bodyLarge)),
              IconButton(onPressed: () => Get.find<BillingUIController>().cartItems.remove(item), icon: const Icon(Icons.close, size: 18, color: kErrorColor))
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Qty:'),
              SizedBox(
                width: 40,
                child: Obx(() => TextField(
                  controller: TextEditingController(text: item.quantity.value.toString()),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => item.quantity.value = int.tryParse(val) ?? 1,
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                )),
              ),
              const SizedBox(width: 16),
              const Text('Discount (₹):'),
              SizedBox(
                width: 60,
                child: Obx(() => TextField(
                  controller: TextEditingController(text: item.discount.value.toString()),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => item.discount.value = double.tryParse(val) ?? 0.0,
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
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
  void _showFinalDiscountDialog(BuildContext context, BillingUIController controller) {
    final discountController = TextEditingController(text: controller.finalDiscount.value > 0 ? controller.finalDiscount.value.toString() : '');
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Apply Final Discount', style: theme.textTheme.titleLarge),
          content: TextField(
            controller: discountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              labelText: 'Discount Amount (₹)',
              labelStyle: TextStyle(color: theme.hintColor),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                controller.finalDiscount.value = double.tryParse(discountController.text) ?? 0.0;
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BillingUIController>();
    return Column(
      children: [
        Obx(() => Column(
          children: [
            _SummaryRow(label: 'Subtotal', value: '₹${controller.subtotal.toStringAsFixed(2)}'),
            _SummaryRow(label: 'Item Discounts', value: '- ₹${controller.totalItemDiscount.toStringAsFixed(2)}'),
            // ADDED: Row to display GST amount
            _SummaryRow(label: 'GST (${controller.gstRate}%)', value: '+ ₹${controller.gstAmount.toStringAsFixed(2)}'),
            _SummaryRow(
              label: 'Final Discount',
              value: '- ₹${controller.finalDiscount.value.toStringAsFixed(2)}',
              onTap: () => _showFinalDiscountDialog(context, controller),
            ),
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
  final VoidCallback? onTap;

  const _SummaryRow({required this.label, required this.value, this.isTotal = false, this.onTap});

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
          Row(
            children: [
              Text(label, style: style),
              if (onTap != null)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 16, color: kPrimaryColor),
                  onPressed: onTap,
                  tooltip: 'Add/Edit Discount',
                )
            ],
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

