import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import '../network/network_constants.dart';

// --- DATA MODELS ---
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

class Customer {
  final int customerId;
  final String name;
  final String phone;

  Customer({required this.customerId, required this.name, required this.phone});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['customer_id'],
      name: json['name'],
      phone: json['phone'],
    );
  }
}


// --- DATA CONTROLLERS ---
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

  Future<Map<String, dynamic>> initSale(List<Map<String, dynamic>> saleItems, double totalDiscount, int customerId) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/sale/initSale');
    try {
      var res = await http.post(
        url,
        headers: {
          'authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'items': saleItems,
          'discount': totalDiscount,
          'customer_id': customerId,
        }),
      );
      final decodedBody = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception('Failed to create sale: ${decodedBody['message']}');
      }
      return decodedBody['data'];
    } catch (e) {
      throw Exception('An error occurred during sale creation: ${e.toString()}');
    }
  }
}

class CustomerDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<List<Customer>> getCustomerByPhone(String phone) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/customer/getCutomerByPhone', {'searchByPhone': phone});
    try {
      var res = await http.get(url, headers: {'authorization': 'Bearer $accessToken'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as List;
        return data.map((item) => Customer.fromJson(item)).toList();
      } else {
        throw Exception('Failed to find customer');
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }

  // UPDATED: This function now correctly handles the new API response.
  Future<Customer> createCustomer(String name, String phone) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/customer/createCustomer');
    try {
      var res = await http.post(
        url,
        headers: {
          'authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'name': name, 'phone': phone}),
      );
      final decodedBody = jsonDecode(res.body);
      // The status code can be 200 or 201 for success
      if (res.statusCode == 200 || res.statusCode == 201) {
        final insertId = decodedBody['data']['insertId'];
        if (insertId != null) {
          // Manually construct the Customer object since the API doesn't return it
          return Customer(customerId: insertId, name: name, phone: phone);
        } else {
          throw Exception('API did not return an insertId for the new customer.');
        }
      } else {
        throw Exception('Failed to create customer: ${decodedBody['message']}');
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }
}


// --- UI STATE CONTROLLER ---
class BillingUIController extends GetxController {
  final BillingDataController _billingDataController = Get.put(BillingDataController());
  final CustomerDataController _customerDataController = Get.put(CustomerDataController());

  var searchResults = <DrugSearchResult>[].obs;
  var isSearchingDrugs = false.obs;
  var cartItems = <CartItem>[].obs;
  Timer? _drugSearchDebounce;

  final nameSearchController = TextEditingController();
  final manufacturerSearchController = TextEditingController();
  final drugTypeSearchController = TextEditingController();
  final barcodeSearchController = TextEditingController();
  final customerPhoneController = TextEditingController();


  var finalDiscountPercent = 0.0.obs;
  var gstRatePercent = 18.0.obs;
  var showAvailableOnly = true.obs;
  var lastSaleDetails = Rx<Map<String, dynamic>?>(null);

  var selectedCustomer = Rx<Customer?>(null);
  var isSearchingCustomer = false.obs;
  var customerNotFound = false.obs;
  var customerSearchResults = <Customer>[].obs;
  Timer? _customerSearchDebounce;


  double get subtotal => cartItems.fold(0, (sum, item) => sum + item.itemSubtotal);
  double get totalItemDiscount => cartItems.fold(0, (sum, item) => sum + item.discount.value);
  double get totalAfterItemDiscounts => subtotal - totalItemDiscount;
  double get gstAmount => totalAfterItemDiscounts > 0 ? totalAfterItemDiscounts * (gstRatePercent.value / 100) : 0;
  double get finalDiscountAmount => totalAfterItemDiscounts > 0 ? totalAfterItemDiscounts * (finalDiscountPercent.value / 100) : 0;
  double get grandTotal => totalAfterItemDiscounts + gstAmount - finalDiscountAmount;
  double get totalDiscountForAPI => totalItemDiscount + finalDiscountAmount;

  @override
  void onInit() {
    super.onInit();
    nameSearchController.addListener(_onDrugSearchChanged);
    manufacturerSearchController.addListener(_onDrugSearchChanged);
    drugTypeSearchController.addListener(_onDrugSearchChanged);
    barcodeSearchController.addListener(_onDrugSearchChanged);
    showAvailableOnly.listen((_) => _onDrugSearchChanged());
    customerPhoneController.addListener(_onCustomerSearchChanged);
  }

  @override
  void onClose() {
    _drugSearchDebounce?.cancel();
    _customerSearchDebounce?.cancel();
    nameSearchController.dispose();
    manufacturerSearchController.dispose();
    drugTypeSearchController.dispose();
    barcodeSearchController.dispose();
    customerPhoneController.dispose();
    super.onClose();
  }

  void _onDrugSearchChanged() {
    if (_drugSearchDebounce?.isActive ?? false) _drugSearchDebounce!.cancel();
    isSearchingDrugs.value = true;
    _drugSearchDebounce = Timer(const Duration(milliseconds: 700), () async {
      final hasSearchText = nameSearchController.text.isNotEmpty ||
          manufacturerSearchController.text.isNotEmpty ||
          drugTypeSearchController.text.isNotEmpty ||
          barcodeSearchController.text.isNotEmpty;

      if (hasSearchText) {
        try {
          final queryParams = {
            if (nameSearchController.text.isNotEmpty) 'searchByName': nameSearchController.text,
            if (manufacturerSearchController.text.isNotEmpty) 'searchManufacturer': manufacturerSearchController.text,
            if (drugTypeSearchController.text.isNotEmpty) 'searchDrugType': drugTypeSearchController.text,
            if (barcodeSearchController.text.isNotEmpty) 'searchBarcodeType': barcodeSearchController.text,
            'availableOnly': showAvailableOnly.value.toString(),
          };

          final data = await _billingDataController.searchDrugs(queryParams);
          searchResults.value = data.map((item) => DrugSearchResult.fromJson(item)).toList();
        } catch (e) {
          Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''), backgroundColor: kErrorColor, colorText: Colors.white);
        } finally {
          isSearchingDrugs.value = false;
        }
      } else {
        searchResults.clear();
        isSearchingDrugs.value = false;
      }
    });
  }

  void addItemToCart(DrugSearchResult drug, {int quantity = 1}) {
    if (quantity <= 0) return;

    var existingItem = cartItems.firstWhereOrNull((item) => item.drug.drugId == drug.drugId);

    if (existingItem != null) {
      int newQuantity = existingItem.quantity.value + quantity;
      if (newQuantity > drug.stockRemaining) {
        Get.snackbar('Warning', 'Cannot add more than available stock.', backgroundColor: kWarningColor, colorText: Colors.white);
        return;
      }
      existingItem.quantity.value = newQuantity;
    } else {
      if (quantity > drug.stockRemaining) {
        Get.snackbar('Warning', 'Cannot add more than available stock.', backgroundColor: kWarningColor, colorText: Colors.white);
        return;
      }
      cartItems.add(CartItem(drug: drug, quantity: quantity));
    }

    searchResults.clear();
    nameSearchController.clear();
    manufacturerSearchController.clear();
    drugTypeSearchController.clear();
    barcodeSearchController.clear();
  }

  void clearCart() {
    cartItems.clear();
    finalDiscountPercent.value = 0.0;
    lastSaleDetails.value = null;
    selectedCustomer.value = null;
    customerPhoneController.clear();
    customerSearchResults.clear();
    customerNotFound.value = false;
  }

  void _onCustomerSearchChanged() {
    if (_customerSearchDebounce?.isActive ?? false) _customerSearchDebounce!.cancel();
    isSearchingCustomer.value = true;
    customerNotFound.value = false;
    _customerSearchDebounce = Timer(const Duration(milliseconds: 600), () async {
      final phone = customerPhoneController.text;
      if (phone.length < 3) {
        customerSearchResults.clear();
        isSearchingCustomer.value = false;
        return;
      }
      try {
        final customers = await _customerDataController.getCustomerByPhone(phone);
        if (customers.isNotEmpty) {
          customerSearchResults.value = customers;
        } else {
          customerSearchResults.clear();
          customerNotFound.value = true;
        }
      } catch(e) {
        Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''), backgroundColor: kErrorColor, colorText: Colors.white);
      } finally {
        isSearchingCustomer.value = false;
      }
    });
  }

  void selectCustomer(Customer customer) {
    selectedCustomer.value = customer;
    customerSearchResults.clear();
    customerPhoneController.text = customer.phone;
    customerNotFound.value = false;
  }

  void showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: customerPhoneController.text);
    Get.dialog(
        AlertDialog(
          title: const Text('Add New Customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
            ],
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('Cancel')),
            ElevatedButton(onPressed: () => _createCustomer(nameCtrl.text, phoneCtrl.text), child: const Text('Create')),
          ],
        )
    );
  }

  Future<void> _createCustomer(String name, String phone) async {
    if (name.isEmpty || phone.isEmpty) {
      Get.snackbar('Warning', 'Both name and phone are required.', backgroundColor: kWarningColor, colorText: Colors.white);
      return;
    }
    Get.back();
    try {
      final newCustomer = await _customerDataController.createCustomer(name, phone);
      selectCustomer(newCustomer);
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''), backgroundColor: kErrorColor, colorText: Colors.white);
    }
  }

  Future<void> finalizeSale() async {
    if (selectedCustomer.value == null) {
      Get.snackbar('Error', 'Please select a customer before finalizing the sale.', backgroundColor: kErrorColor, colorText: Colors.white);
      return;
    }
    if (cartItems.isEmpty) {
      Get.snackbar('Warning', 'Cannot finalize an empty bill.', backgroundColor: kWarningColor, colorText: Colors.white);
      return;
    }
    try {
      final saleItems = cartItems.map((item) => {
        'drug_id': item.drug.drugId,
        'quantity': item.quantity.value,
      }).toList();

      final saleData = await _billingDataController.initSale(saleItems, totalDiscountForAPI, selectedCustomer.value!.customerId);
      final authController = Get.find<AuthController>();
      final shopName = await authController.shopname();

      lastSaleDetails.value = {
        'sale_id': saleData['sale_id'],
        'shop_name': shopName,
        'customer_name': selectedCustomer.value!.name,
        'items': List<CartItem>.from(cartItems),
        'subtotal': subtotal,
        'item_discounts': totalItemDiscount,
        'gst_rate': gstRatePercent.value,
        'gst_amount': gstAmount,
        'final_discount': finalDiscountAmount,
        'grand_total': grandTotal,
        'date': DateTime.now()
      };

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
      body: Obx(() {
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _CustomerSection(),
                  const SizedBox(height: 16),
                  if (controller.selectedCustomer.value != null) ...[
                    _DrugSearchSection(),
                    const SizedBox(height: 16),
                    _CurrentBillSection(),
                    const SizedBox(height: 16),
                    _BillSummarySection(),
                  ]
                ],
              ),
            ),
            if (controller.lastSaleDetails.value != null)
              _InvoiceView(saleDetails: controller.lastSaleDetails.value!),
          ],
        );
      }),
    );
  }
}

class _CustomerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BillingUIController>();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Obx(() {
        if (controller.selectedCustomer.value != null) {
          final customer = controller.selectedCustomer.value!;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CUSTOMER', style: theme.textTheme.labelSmall),
                  Text(customer.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(customer.phone, style: theme.textTheme.bodyMedium),
                ],
              ),
              TextButton(onPressed: () {
                controller.selectedCustomer.value = null;
                controller.customerPhoneController.clear();
              }, child: const Text('Change'))
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Find or Create a Customer', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: controller.customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: 'Enter Customer Phone Number',
                  border: const OutlineInputBorder(),
                  suffixIcon: Obx(() => controller.isSearchingCustomer.value
                      ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 2)))
                      : const Icon(Icons.search)
                  )
              ),
            ),
            Obx(() {
              if (controller.customerSearchResults.isNotEmpty) {
                return Container(
                  decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
                  ),
                  height: 150,
                  child: ListView.builder(
                    itemCount: controller.customerSearchResults.length,
                    itemBuilder: (context, index) {
                      final customer = controller.customerSearchResults[index];
                      return ListTile(
                        title: Text(customer.name),
                        subtitle: Text(customer.phone),
                        onTap: () => controller.selectCustomer(customer),
                      );
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            if(controller.customerNotFound.value)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: controller.showAddCustomerDialog,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Add New Customer'),
                  ),
                ),
              ),
          ],
        );
      }),
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
          icon: Icons.abc,
          isSearching: controller.isSearchingDrugs,
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
            const SizedBox(height: 8),
            Obx(() => SwitchListTile.adaptive(
              title: Text("Only show available stock", style: theme.textTheme.bodyMedium),
              value: controller.showAvailableOnly.value,
              onChanged: (val) => controller.showAvailableOnly.value = val,
              dense: true,
            )),
          ],
        ),
        Obx(() {
          if (controller.searchResults.isNotEmpty) {
            return Container(
              decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.98),
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
  final RxBool? isSearching;

  const _SearchField({required this.controller, required this.hintText, required this.icon, this.isSearching});

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
        suffixIcon: Obx(() {
          if (isSearching?.value ?? false) {
            return const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return const SizedBox.shrink();
        }),
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
    final controller = Get.find<BillingUIController>();

    return InkWell(
      onTap: () => controller.addItemToCart(drug, quantity: 1),
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
                      Text(drug.drugName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text(drug.manufacturer, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('₹${drug.sellingPrice}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: kPrimaryColor)),
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
          Obx(() {
            if (controller.cartItems.isEmpty) {
              return const SizedBox(
                  height: 100,
                  child: Center(child: Text('No items added yet.'))
              );
            }
            return ListView.builder(
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
                  onChanged: (val) {
                    final newQty = int.tryParse(val) ?? 1;
                    if (newQty > item.drug.stockRemaining) {
                      Get.snackbar('Warning', 'Quantity cannot exceed available stock.', backgroundColor: kWarningColor, colorText: Colors.white);
                      item.quantity.value = item.drug.stockRemaining;
                    } else {
                      item.quantity.value = newQty;
                    }
                  },
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
  void _showPercentageInputDialog(BuildContext context, String title, RxDouble valueHolder) {
    final textController = TextEditingController(text: valueHolder.value > 0 ? valueHolder.value.toString() : '');
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Set $title', style: theme.textTheme.titleLarge),
          content: TextField(
            controller: textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              labelText: '$title (%)',
              labelStyle: TextStyle(color: theme.hintColor),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                valueHolder.value = double.tryParse(textController.text) ?? 0.0;
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
            _SummaryRow(
              label: 'GST (${controller.gstRatePercent.value}%)',
              value: '+ ₹${controller.gstAmount.toStringAsFixed(2)}',
              onTap: () => _showPercentageInputDialog(context, 'GST Rate', controller.gstRatePercent),
            ),
            _SummaryRow(
              label: 'Final Discount (${controller.finalDiscountPercent.value}%)',
              value: '- ₹${controller.finalDiscountAmount.toStringAsFixed(2)}',
              onTap: () => _showPercentageInputDialog(context, 'Final Discount', controller.finalDiscountPercent),
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
                  icon: const Icon(Icons.settings_outlined, size: 16, color: kPrimaryColor),
                  onPressed: onTap,
                  tooltip: 'Set Value',
                )
            ],
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _InvoiceView extends StatelessWidget {
  final Map<String, dynamic> saleDetails;
  const _InvoiceView({required this.saleDetails});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<BillingUIController>();

    return Material(
      color: theme.scaffoldBackgroundColor.withOpacity(0.95),
      child: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(saleDetails['shop_name'] ?? 'My Pharmacy', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('SALE INVOICE', style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 2)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Sale ID: ${saleDetails['sale_id']}'),
                Text(DateFormat('d MMM yyyy, h:mm a').format(saleDetails['date'])),
              ]),
              const Divider(height: 24),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Billed To: ${saleDetails['customer_name']}', style: theme.textTheme.bodyMedium)),
              const Divider(height: 24),
              Table(
                columnWidths: const {0: FlexColumnWidth(4), 1: FlexColumnWidth(1), 2: FlexColumnWidth(2)},
                children: [
                  TableRow(children: [
                    Text('Item', style: theme.textTheme.bodySmall),
                    Text('Qty', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                    Text('Amount', textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
                  ]),
                  const TableRow(children: [SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8)]),
                  ...(saleDetails['items'] as List<CartItem>).map((item) => TableRow(
                      children: [
                        Text(item.drug.drugName),
                        Text(item.quantity.value.toString(), textAlign: TextAlign.center),
                        Text('₹${item.totalItemPrice.toStringAsFixed(2)}', textAlign: TextAlign.right),
                      ]
                  )).toList()
                ],
              ),
              const Divider(height: 24),
              _SummaryRow(label: 'Subtotal', value: '₹${saleDetails['subtotal'].toStringAsFixed(2)}'),
              _SummaryRow(label: 'Item Discounts', value: '- ₹${saleDetails['item_discounts'].toStringAsFixed(2)}'),
              _SummaryRow(label: 'GST (${saleDetails['gst_rate']}%)', value: '+ ₹${saleDetails['gst_amount'].toStringAsFixed(2)}'),
              _SummaryRow(label: 'Final Discount', value: '- ₹${saleDetails['final_discount'].toStringAsFixed(2)}'),
              const Divider(),
              _SummaryRow(label: 'GRAND TOTAL', value: '₹${saleDetails['grand_total'].toStringAsFixed(2)}', isTotal: true),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: (){}, icon: const Icon(Icons.print_outlined), label: const Text('Print'))),
                  const SizedBox(width: 16),
                  Expanded(child: ElevatedButton.icon(onPressed: controller.clearCart, icon: const Icon(Icons.add), label: const Text('New Sale'))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

