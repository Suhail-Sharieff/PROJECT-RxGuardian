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

/// Model for the main list of sales transactions.
class ShopSale {
  final int saleId;
  final int shopId;
  final num? total;
  final num discount;
  final num? grandTotal;
  final int pharmacistId;
  final String soldBy;
  final DateTime soldOn;
  final String customerName;
  final String customerPhone;

  ShopSale({
    required this.saleId,
    required this.shopId,
    this.total,
    required this.discount,
    this.grandTotal,
    required this.pharmacistId,
    required this.soldBy,
    required this.customerName,
    required this.customerPhone,
    required this.soldOn,
  });

  factory ShopSale.fromJson(Map<String, dynamic> json) {
    return ShopSale(
      saleId: json['sale_id'],
      shopId: json['shop_id'],
      total: json['total'],
      discount: json['discount'],
      grandTotal: json['grand_total'],
      pharmacistId: json['pharmacist_id'],
      soldBy: json['sold_by'],
      soldOn: DateTime.parse(json['sold_on']),
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
    );
  }
}

/// Model for the items within a single sale, for the details view.
class SaleItemDetail {
  final int drugId;
  final String name;
  final num sellingPrice;
  final int quantity;

  SaleItemDetail({
    required this.drugId,
    required this.name,
    required this.sellingPrice,
    required this.quantity,
  });

  factory SaleItemDetail.fromJson(Map<String, dynamic> json) {
    return SaleItemDetail(
      drugId: json['drug_id'],
      name: json['name'],
      sellingPrice: json['selling_price'],
      quantity: json['quantity'],
    );
  }
}

// --- DATA CONTROLLER (API Logic) ---
class SaleDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<List<dynamic>> getOverallSales(Map<String, String> queryParams) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/sale/getOverallSales', queryParams);
    try {
      var res = await http.get(
        url,
        headers: {'authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data'];
      } else {
        throw Exception(
          'Failed to load sales: ${jsonDecode(res.body)['message']}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }

  Future<List<dynamic>> getDetailsOfSale(int saleId) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/sale/getDetailsOfSale/$saleId');
    try {
      var res = await http.get(
        url,
        headers: {'authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data'];
      } else {
        throw Exception(
          'Failed to load sale details: ${jsonDecode(res.body)['message']}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }
}

// --- UI STATE CONTROLLER ---
class SaleUIController extends GetxController {
  final SaleDataController _dataController = Get.put(SaleDataController());

  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var salesList = <ShopSale>[].obs;

  var pageNumber = 1;
  var hasMoreData = true;
  final scrollController = ScrollController();
  final nameSearchController = TextEditingController();
  final saleIdSearchController = TextEditingController();
  final pharmacistIdSearchController = TextEditingController();
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchSalesData();
    scrollController.addListener(() {
      if (scrollController.position.maxScrollExtent ==
          scrollController.offset) {
        fetchSalesData();
      }
    });
    nameSearchController.addListener(_onSearchChanged);
    saleIdSearchController.addListener(_onSearchChanged);
    pharmacistIdSearchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    scrollController.dispose();
    nameSearchController.dispose();
    saleIdSearchController.dispose();
    pharmacistIdSearchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> fetchSalesData({bool isSearch = false}) async {
    if (isLoadingMore.value || (!hasMoreData && !isSearch)) return;

    if (isSearch) {
      pageNumber = 1;
      hasMoreData = true;
      salesList.clear();
      isLoading(true);
    } else {
      isLoadingMore(true);
    }

    try {
      final queryParams = {
        'pgNo': pageNumber.toString(),
        if (nameSearchController.text.isNotEmpty)
          'searchByName': nameSearchController.text,
        if (saleIdSearchController.text.isNotEmpty)
          'searchBySaleId': saleIdSearchController.text,
        if (pharmacistIdSearchController.text.isNotEmpty)
          'searchByPharmacistId': pharmacistIdSearchController.text,
      };

      final List<dynamic> data = await _dataController.getOverallSales(
        queryParams,
      );
      // log(data.toString());
      final newData = data.map((item) => ShopSale.fromJson(item)).toList();

      if (newData.isEmpty) {
        hasMoreData = false;
        if (pageNumber > 1) {
          Get.snackbar(
            "Notice",
            "You've reached the end of the list.",
            backgroundColor: kWarningColor,
            colorText: Colors.white,
          );
        }
      } else {
        salesList.addAll(newData);
        pageNumber++;
      }
    } catch (err) {
      Get.snackbar(
        'Error',
        err.toString().replaceAll('Exception: ', ''),
        backgroundColor: kErrorColor,
        colorText: Colors.white,
      );
      hasMoreData = false;
    } finally {
      isLoading(false);
      isLoadingMore(false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      fetchSalesData(isSearch: true);
    });
  }

  Future<void> viewSaleDetails(ShopSale sale) async {
    try {
      final List<dynamic> data = await _dataController.getDetailsOfSale(
        sale.saleId,
      );
      final items = data.map((item) => SaleItemDetail.fromJson(item)).toList();
      Get.dialog(_SaleDetailsDialog(sale: sale, items: items));
    } catch (err) {
      Get.snackbar(
        'Error',
        err.toString().replaceAll('Exception: ', ''),
        backgroundColor: kErrorColor,
        colorText: Colors.white,
      );
    }
  }
}

// --- UI WIDGET ---
class ShopSaleDetailsPage extends StatelessWidget {
  const ShopSaleDetailsPage({super.key});
  static const route_name = sale_details_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SaleUIController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Shop Sales Details', style: theme.textTheme.titleLarge),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(180.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              children: [
                _SearchTextField(
                  controller: controller.nameSearchController,
                  hintText: 'Search by Pharmacist Name...',
                  icon: Icons.person_search_outlined,
                ),
                const SizedBox(height: 8),
                _SearchTextField(
                  controller: controller.saleIdSearchController,
                  hintText: 'Search by Sale ID...',
                  icon: Icons.receipt_long_outlined,
                ),
                const SizedBox(height: 8),
                _SearchTextField(
                  controller: controller.pharmacistIdSearchController,
                  hintText: 'Search by Pharmacist ID...',
                  icon: Icons.badge_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }
        if (controller.salesList.isEmpty) {
          return Center(
            child: Text(
              "No sales data found.",
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }
        return ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.all(16.0),
          itemCount:
              controller.salesList.length +
              (controller.isLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == controller.salesList.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: CircularProgressIndicator(color: kPrimaryColor),
                ),
              );
            }
            final item = controller.salesList[index];
            return _SaleCard(sale: item);
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

  const _SearchTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
  });

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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 12.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// --- THEME-AWARE SALE CARD WIDGET ---
class _SaleCard extends StatelessWidget {
  final ShopSale sale;
  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<SaleUIController>();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sale #${sale.saleId}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${(sale.grandTotal ?? 0).toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.person_outline,
            text: 'Sold by: ${sale.soldBy} (ID: ${sale.pharmacistId})',
          ),
          const SizedBox(height: 4),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            text:
                'Sold on: ${DateFormat('d MMM yyyy, h:mm a').format(sale.soldOn)}',
          ),
          _InfoRow(
            icon: Icons.person,
            text:
                'Purchased By: ${sale.customerName}',
          ),
          _InfoRow(
            icon: Icons.phone,
            text:
            'Customer Ph: ${sale.customerPhone}',
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subtotal: ₹${(sale.total ?? 0).toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Discount: - ₹${sale.discount.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => controller.viewSaleDetails(sale),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.iconTheme.color?.withOpacity(0.7), size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

// --- DIALOG FOR SALE DETAILS ---
class _SaleDetailsDialog extends StatelessWidget {
  final ShopSale sale;
  final List<SaleItemDetail> items;
  const _SaleDetailsDialog({required this.sale, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(
        'Details for Sale #${sale.saleId}',
        style: theme.textTheme.titleLarge,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            if (items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No item details available.'),
                ),
              )
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(4),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    children: [
                      Text('Item', style: theme.textTheme.bodySmall),
                      Text(
                        'Qty',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Price',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const TableRow(
                    children: [
                      SizedBox(height: 8),
                      SizedBox(height: 8),
                      SizedBox(height: 8),
                    ],
                  ),
                  ...items
                      .map(
                        (item) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Text(item.name),
                            ),
                            Text(
                              item.quantity.toString(),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '₹${item.sellingPrice.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ],
              ),
            const Divider(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Close')),
      ],
    );
  }
}
