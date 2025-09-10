import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../network/network_constants.dart';

// --- ENUMS AND DATA MODELS ---
enum PerformanceFilterType { Day, Month, Year }

extension PerformanceFilterTypeExtension on PerformanceFilterType {
  String get titleName {
    switch (this) {
      case PerformanceFilterType.Day:
        return 'Daily';
      case PerformanceFilterType.Month:
        return 'Monthly';
      case PerformanceFilterType.Year:
        return 'Yearly';
    }
  }
}

class RevenueData {
  final dynamic xValue;
  final double netRevenue;
  RevenueData(this.xValue, this.netRevenue);
}

class SalesActivityData {
  final dynamic xValue;
  final int salesCount;
  final int customerCount;
  SalesActivityData(this.xValue, this.salesCount, this.customerCount);
}

// --- NEW Data Models ---
class TopSellingDrug {
  final String name;
  final int totalSold;
  TopSellingDrug({required this.name, required this.totalSold});
}

class TopRevenueDrug {
  final String name;
  final double revenue;
  TopRevenueDrug({required this.name, required this.revenue});
}

class NewVsReturningCustomers {
  final int newCustomers;
  final int returningCustomers;
  NewVsReturningCustomers({required this.newCustomers, required this.returningCustomers});
}

class CustomerFrequency {
  final String visitCount;
  final int customerCount;
  CustomerFrequency({required this.visitCount, required this.customerCount});
}

class DiscountUsage {
  final String discount;
  final int nSales;
  final double revenue;
  DiscountUsage({required this.discount, required this.nSales, required this.revenue});
}
// --- END NEW Data Models ---


// --- DATA CONTROLLER (API Logic) ---
class PerformanceDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<dynamic> _fetchData(String endpoint, Map<String, String> queryParams) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, endpoint, queryParams);
    try {
      var res = await http.get(url, headers: {'authorization': 'Bearer $accessToken'});
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data'];
      } else {
        throw Exception('Failed to load data from $endpoint: ${jsonDecode(res.body)['message']}');
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }

  // Existing methods
  Future<List<dynamic>> getDateVsRevenue(Map<String, String> queryParams) async => await _fetchData('/sale/getDateVsRevenue', queryParams);
  Future<List<dynamic>> getDateVsSale(Map<String, String> queryParams) async => await _fetchData('/sale/getDateVsSale', queryParams);

  // --- NEW API Call Methods ---
  Future<List<dynamic>> getTopSellingDrugs(Map<String, String> queryParams) async => await _fetchData('/drug/topSelling', queryParams);
  Future<List<dynamic>> getTopRevenueDrugs(Map<String, String> queryParams) async => await _fetchData('/drug/topRevenue', queryParams);
  Future<Map<String, dynamic>> getAvgBasketSize(Map<String, String> queryParams) async => await _fetchData('/customer/avgBasketSize', queryParams);
  Future<Map<String, dynamic>> getAvgItemsPerSale(Map<String, String> queryParams) async => await _fetchData('/customer/avgItemsPerSale', queryParams);
  Future<Map<String, dynamic>> getNewVsReturning(Map<String, String> queryParams) async => await _fetchData('/customer/newVsReturning', queryParams);
  Future<List<dynamic>> getCustomerFrequency(Map<String, String> queryParams) async => await _fetchData('/customer/customerFrequencyDistribution', queryParams);
  Future<List<dynamic>> getDiscountUsage(Map<String, String> queryParams) async => await _fetchData('/sale/discountUsage', queryParams);
  Future<List<dynamic>> getAvgDaysBetweenPurchases(Map<String, String> queryParams) async => await _fetchData('/customer/avgDaysBetweenCustomerPurchase', queryParams);
// --- END NEW API Call Methods ---
}


// --- UI STATE CONTROLLER ---
class PerformanceUIController extends GetxController {
  final PerformanceDataController _dataController = Get.put(PerformanceDataController());

  var isLoading = true.obs;
  var selectedDate = DateTime.now().obs;
  var filterType = PerformanceFilterType.Day.obs;

  // Existing state
  var revenueData = <RevenueData>[].obs;
  var salesActivityData = <SalesActivityData>[].obs;

  // --- NEW State Variables ---
  var topSellingDrugs = <TopSellingDrug>[].obs;
  var topRevenueDrugs = <TopRevenueDrug>[].obs;
  var avgBasketSize = 0.0.obs;
  var avgItemsPerSale = 0.0.obs;
  var newVsReturning = NewVsReturningCustomers(newCustomers: 0, returningCustomers: 0).obs;
  var customerFrequency = <CustomerFrequency>[].obs;
  var discountUsage = <DiscountUsage>[].obs;
  var avgDaysBetweenPurchases = 0.0.obs;
  // --- END NEW State Variables ---

  double get totalRevenue => revenueData.fold(0.0, (sum, item) => sum + item.netRevenue);
  int get totalSales => salesActivityData.fold(0, (sum, item) => sum + item.salesCount);

  @override
  void onInit() {
    super.onInit();
    fetchPerformanceData();
  }

  // --- NEW: Helper to get date range for APIs that need it ---
  Map<String, String> _getDateQueryParams() {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    DateTime startDate;
    DateTime endDate;

    switch (filterType.value) {
      case PerformanceFilterType.Day:
        startDate = selectedDate.value;
        endDate = selectedDate.value;
        break;
      case PerformanceFilterType.Month:
        final year = selectedDate.value.year;
        final month = selectedDate.value.month;
        startDate = DateTime(year, month, 1);
        endDate = DateTime(year, month + 1, 0); // Last day of the month
        break;
      case PerformanceFilterType.Year:
        final year = selectedDate.value.year;
        startDate = DateTime(year, 1, 1);
        endDate = DateTime(year, 12, 31);
        break;
    }
    return {
      'startDate': formatter.format(startDate),
      'endDate': formatter.format(endDate),
      'limit': '10' // For top N lists
    };
  }


  Future<void> fetchPerformanceData() async {
    isLoading.value = true;
    try {
      // --- UPDATED: Use specific query params for different APIs ---
      final legacyQueryParams = <String, String>{};
      if (filterType.value == PerformanceFilterType.Day) {
        legacyQueryParams['day'] = selectedDate.value.day.toString();
        legacyQueryParams['month'] = selectedDate.value.month.toString();
        legacyQueryParams['year'] = selectedDate.value.year.toString();
      } else if (filterType.value == PerformanceFilterType.Month) {
        legacyQueryParams['month'] = selectedDate.value.month.toString();
        legacyQueryParams['year'] = selectedDate.value.year.toString();
      } else {
        legacyQueryParams['year'] = selectedDate.value.year.toString();
      }

      final dateRangeParams = _getDateQueryParams();

      // --- NEW: Fetch all data in parallel ---
      final results = await Future.wait([
        _dataController.getDateVsRevenue(legacyQueryParams),
        _dataController.getDateVsSale(legacyQueryParams),
        _dataController.getTopSellingDrugs(dateRangeParams),
        _dataController.getTopRevenueDrugs(dateRangeParams),
        _dataController.getAvgBasketSize(dateRangeParams),
        _dataController.getAvgItemsPerSale(dateRangeParams),
        _dataController.getNewVsReturning(dateRangeParams),
        _dataController.getCustomerFrequency(const {}), // No params for this one
        _dataController.getDiscountUsage(dateRangeParams),
        _dataController.getAvgDaysBetweenPurchases(const {}), // No params for this one
      ]);

      // Process original chart data
      _processChartData(results[0] as List, results[1] as List);

      // --- NEW: Process all new data with safety checks ---
      topSellingDrugs.value = (results[2] as List)
          .map((item) => TopSellingDrug(name: item['name'], totalSold: int.tryParse(item['totalSold'] ?? '0') ?? 0))
          .toList();

      topRevenueDrugs.value = (results[3] as List)
          .map((item) => TopRevenueDrug(name: item['name'], revenue: (item['revenue'] as num? ?? 0).toDouble()))
          .toList();

      avgBasketSize.value = (results[4] as Map)['avgOrderValue'] as double? ?? 0.0;
      avgItemsPerSale.value = double.tryParse((results[5] as Map)['avgItemsPerSale'] ?? '0.0') ?? 0.0;

      final newVsReturningData = results[6] as Map;
      newVsReturning.value = NewVsReturningCustomers(
        newCustomers: int.tryParse(newVsReturningData['newCustomers'] ?? '0') ?? 0,
        returningCustomers: int.tryParse(newVsReturningData['returningCustomers'] ?? '0') ?? 0,
      );

      customerFrequency.value = (results[7] as List)
          .map((item) => CustomerFrequency(visitCount: '${item['visit_count']}+ Visits', customerCount: item['nCustomers']))
          .toList();

      discountUsage.value = (results[8] as List)
          .map((item) => DiscountUsage(
          discount: '${item['discount']}%',
          nSales: item['nSales'],
          revenue: (item['revenue'] as num? ?? 0).toDouble()
      )).toList();

      final avgDaysData = results[9] as List;
      if (avgDaysData.isNotEmpty) {
        avgDaysBetweenPurchases.value = double.tryParse(avgDaysData.first['avg'] ?? '0.0') ?? 0.0;
      }
      // --- END NEW ---

    } catch (err) {
      Get.snackbar('Error', err.toString().replaceAll('Exception: ', ''), backgroundColor: kErrorColor, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  void _processChartData(List<dynamic> revenueResult, List<dynamic> salesActivityResult) {
    // [This method remains unchanged from your original code]
    switch (filterType.value) {
      case PerformanceFilterType.Day:
        final DateTime sel = selectedDate.value;
        final DateTime startWindow = DateTime(sel.year, sel.month, sel.day, sel.hour).subtract(const Duration(hours: 5));
        final DateTime endWindow = startWindow.add(const Duration(hours: 11));
        final Map<DateTime, double> hourlyRevenue = {};
        for (int i = 0; i < 12; i++) {
          final dt = startWindow.add(Duration(hours: i));
          hourlyRevenue[DateTime(dt.year, dt.month, dt.day, dt.hour)] = 0.0;
        }
        for (var item in revenueResult) {
          final DateTime dt = DateTime.parse(item['date']).toLocal();
          if (!dt.isBefore(startWindow) && !dt.isAfter(endWindow.add(const Duration(hours: 1)))) {
            final bucket = DateTime(dt.year, dt.month, dt.day, dt.hour);
            if (hourlyRevenue.containsKey(bucket)) {
              hourlyRevenue[bucket] = (hourlyRevenue[bucket] ?? 0) + (item['net_revenue'] as num).toDouble();
            }
          }
        }
        final sortedHourlyKeys = hourlyRevenue.keys.toList()..sort();
        revenueData.value = sortedHourlyKeys.map((k) => RevenueData(k, hourlyRevenue[k]!)).toList();
        final Map<int, SalesActivityData> hourlyData = {};
        for (var item in salesActivityResult) {
          final hour = item['sale_hour'] as int;
          final sales = item['nSales'] as int;
          final customers = item['nCustomers'] as int;
          if (hourlyData.containsKey(hour)) {
            hourlyData[hour] = SalesActivityData('${hour.toString().padLeft(2, '0')}:00', hourlyData[hour]!.salesCount + sales, hourlyData[hour]!.customerCount + customers);
          } else {
            hourlyData[hour] = SalesActivityData('${hour.toString().padLeft(2, '0')}:00', sales, customers);
          }
        }
        var sortedHours = hourlyData.keys.toList()..sort();
        salesActivityData.value = sortedHours.map((hour) => hourlyData[hour]!).toList();
        break;
      case PerformanceFilterType.Month:
        final Map<int, double> dailyRevenue = {};
        for (var item in revenueResult) {
          final day = DateTime.parse(item['date']).day;
          final revenue = (item['net_revenue'] as num).toDouble();
          dailyRevenue[day] = (dailyRevenue[day] ?? 0) + revenue;
        }
        var sortedRevenueDays = dailyRevenue.keys.toList()..sort();
        revenueData.value = sortedRevenueDays.map((day) => RevenueData(day.toString(), dailyRevenue[day]!)).toList();
        final Map<int, Map<String, int>> dailySales = {};
        for (var item in salesActivityResult) {
          final day = DateTime.parse(item['sale_date']).day;
          if (!dailySales.containsKey(day)) {
            dailySales[day] = {'nSales': 0, 'nCustomers': 0};
          }
          dailySales[day]!['nSales'] = dailySales[day]!['nSales']! + (item['nSales'] as int);
          dailySales[day]!['nCustomers'] = dailySales[day]!['nCustomers']! + (item['nCustomers'] as int);
        }
        var sortedSalesDays = dailySales.keys.toList()..sort();
        salesActivityData.value = sortedSalesDays.map((day) => SalesActivityData(day.toString(), dailySales[day]!['nSales']!, dailySales[day]!['nCustomers']!)).toList();
        break;
      case PerformanceFilterType.Year:
        final Map<int, double> monthlyRevenue = {};
        for (var item in revenueResult) {
          final month = DateTime.parse(item['date']).month;
          final revenue = (item['net_revenue'] as num).toDouble();
          monthlyRevenue[month] = (monthlyRevenue[month] ?? 0) + revenue;
        }
        var sortedRevenueMonths = monthlyRevenue.keys.toList()..sort();
        revenueData.value = sortedRevenueMonths.map((month) => RevenueData(DateFormat.MMM().format(DateTime(0, month)), monthlyRevenue[month]!)).toList();
        final Map<int, Map<String, int>> monthlySales = {};
        for (var item in salesActivityResult) {
          final month = DateTime.parse(item['sale_date']).month;
          if (!monthlySales.containsKey(month)) {
            monthlySales[month] = {'nSales': 0, 'nCustomers': 0};
          }
          monthlySales[month]!['nSales'] = monthlySales[month]!['nSales']! + (item['nSales'] as int);
          monthlySales[month]!['nCustomers'] = monthlySales[month]!['nCustomers']! + (item['nCustomers'] as int);
        }
        var sortedSalesMonths = monthlySales.keys.toList()..sort();
        salesActivityData.value = sortedSalesMonths.map((month) => SalesActivityData(DateFormat.MMM().format(DateTime(0, month)), monthlySales[month]!['nSales']!, monthlySales[month]!['nCustomers']!)).toList();
        break;
    }
  }

  void changeFilterType(PerformanceFilterType newFilter) {
    filterType.value = newFilter;
    fetchPerformanceData();
  }

  void pickDate(BuildContext context) async {
    final newDate = await showDatePicker(
        context: context,
        initialDate: selectedDate.value,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDatePickerMode: filterType.value == PerformanceFilterType.Year ? DatePickerMode.year : DatePickerMode.day
    );
    if (newDate != null && newDate != selectedDate.value) {
      selectedDate.value = newDate;
      fetchPerformanceData();
    }
  }
}

// --- UI WIDGET ---
class PerformanceAnalysisPage extends StatelessWidget {
  const PerformanceAnalysisPage({super.key});
  static const route_name = performance_analysis_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PerformanceUIController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Performance Analysis', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => controller.pickDate(context),
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _FilterAndSummarySection(),
              const SizedBox(height: 24),
              // --- NEW: Key Metrics section ---
              _KeyMetricsSection(),
              const SizedBox(height: 16),
              // --- END NEW ---
              _ChartCard(
                title: '${controller.filterType.value.titleName} Revenue',
                child: _RevenueChart(
                  data: controller.revenueData,
                  filterType: controller.filterType.value,
                  selectedDate: controller.selectedDate.value,
                ),
              ),
              const SizedBox(height: 16),
              _ChartCard(
                title: '${controller.filterType.value.titleName} Sales Activity',
                child: _SalesActivityChart(data: controller.salesActivityData, filterType: controller.filterType.value),
              ),
              // --- NEW: Add new UI cards ---
              const SizedBox(height: 16),
              _TopProductsCard(),
              const SizedBox(height: 16),
              _CustomerInsightsCard(),
              const SizedBox(height: 16),
              _DiscountAnalysisCard(),
              // --- END NEW ---
            ],
          ),
        );
      }),
    );
  }
}

class _FilterAndSummarySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PerformanceUIController>();
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Column(
      children: [
        Obx(() => SegmentedButton<PerformanceFilterType>(
          segments: const [
            ButtonSegment(value: PerformanceFilterType.Day, label: Text('Day')),
            ButtonSegment(value: PerformanceFilterType.Month, label: Text('Month')),
            ButtonSegment(value: PerformanceFilterType.Year, label: Text('Year')),
          ],
          selected: {controller.filterType.value},
          onSelectionChanged: (newSelection) {
            controller.changeFilterType(newSelection.first);
          },
        )),
        const SizedBox(height: 16),
        Obx(() {
          String formattedDate;
          switch(controller.filterType.value) {
            case PerformanceFilterType.Day:
              formattedDate = DateFormat('EEEE, d MMMM yyyy').format(controller.selectedDate.value);
              break;
            case PerformanceFilterType.Month:
              formattedDate = DateFormat('MMMM yyyy').format(controller.selectedDate.value);
              break;
            case PerformanceFilterType.Year:
              formattedDate = DateFormat('yyyy').format(controller.selectedDate.value);
              break;
          }
          return Text(formattedDate, style: theme.textTheme.headlineSmall);
        }),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.wallet_outlined,
                label: 'Total Revenue',
                value: currencyFormatter.format(controller.totalRevenue),
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.receipt_long_outlined,
                label: 'Total Sales',
                value: controller.totalSales.toString(),
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- NEW: Key Metrics Widget ---
class _KeyMetricsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PerformanceUIController>();
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Obx(() => Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.shopping_basket_outlined,
                label: 'Avg. Basket Size',
                value: currencyFormatter.format(controller.avgBasketSize.value),
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.add_shopping_cart_rounded,
                label: 'Avg. Items / Sale',
                value: controller.avgItemsPerSale.value.toStringAsFixed(2),
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StatCard(
          icon: Icons.repeat_rounded,
          label: 'Avg. Days Between Purchases',
          value: '${controller.avgDaysBetweenPurchases.value.toStringAsFixed(1)} Days',
          color: Colors.blueAccent,
        )
      ],
    ));
  }
}
// --- END NEW ---

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}


class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height; // --- NEW: Allow custom height ---
  const _ChartCard({required this.title, required this.child, this.height = 250});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}
class _RevenueChart extends StatelessWidget {
  final List<RevenueData> data;
  final PerformanceFilterType filterType;
  final DateTime selectedDate;

  const _RevenueChart({
    required this.data,
    required this.filterType,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const Center(child: Text("No revenue data available."));

    if (filterType == PerformanceFilterType.Day) {
      final DateTime startWindow = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedDate.hour)
          .subtract(const Duration(hours: 5));
      final DateTime endWindow = startWindow.add(const Duration(hours: 11));

      return SfCartesianChart(
        primaryXAxis: DateTimeAxis(
          edgeLabelPlacement: EdgeLabelPlacement.shift,
          dateFormat: DateFormat.Hm(),
          intervalType: DateTimeIntervalType.hours,
          interval: 1,
          initialVisibleMinimum: startWindow,
          initialVisibleMaximum: endWindow,
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: theme.textTheme.bodySmall,
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹'),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelStyle: theme.textTheme.bodySmall,
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<RevenueData, DateTime>>[
          SplineSeries<RevenueData, DateTime>(
            dataSource: data,
            xValueMapper: (RevenueData sales, _) => sales.xValue as DateTime,
            yValueMapper: (RevenueData sales, _) => sales.netRevenue,
            name: 'Revenue',
            markerSettings: const MarkerSettings(isVisible: true),
          )
        ],
      );
    } else {
      return SfCartesianChart(
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: theme.textTheme.bodySmall,
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹'),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelStyle: theme.textTheme.bodySmall,
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<RevenueData, dynamic>>[
          SplineSeries<RevenueData, dynamic>(
            dataSource: data,
            xValueMapper: (RevenueData sales, _) => sales.xValue,
            yValueMapper: (RevenueData sales, _) => sales.netRevenue,
            name: 'Revenue',
            markerSettings: const MarkerSettings(isVisible: true),
          ),
        ],
      );
    }
  }
}

class _SalesActivityChart extends StatelessWidget {
  final List<SalesActivityData> data;
  final PerformanceFilterType filterType;
  const _SalesActivityChart({required this.data, required this.filterType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const Center(child: Text("No sales activity available."));

    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        labelStyle: theme.textTheme.bodySmall,
      ),
      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: theme.textTheme.bodySmall,
      ),
      tooltipBehavior: TooltipBehavior(enable: true, shared: true),
      legend: Legend(isVisible: true, position: LegendPosition.bottom),
      series: <CartesianSeries<SalesActivityData, dynamic>>[
        ColumnSeries<SalesActivityData, dynamic>(
          dataSource: data,
          xValueMapper: (SalesActivityData sales, _) => sales.xValue.toString(),
          yValueMapper: (SalesActivityData sales, _) => sales.salesCount,
          name: 'Sales',
        ),
        ColumnSeries<SalesActivityData, dynamic>(
          dataSource: data,
          xValueMapper: (SalesActivityData sales, _) => sales.xValue.toString(),
          yValueMapper: (SalesActivityData sales, _) => sales.customerCount,
          name: 'Customers',
          color: Colors.orange,
        )
      ],
    );
  }
}

// --- NEW WIDGETS ---

class _TopProductsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PerformanceUIController>();
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return _ChartCard(
      title: 'Top Products',
      height: 300, // Adjusted height for tabs
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [Tab(text: 'By Units Sold'), Tab(text: 'By Revenue')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // By Units Sold
                  Obx(() {
                    if (controller.topSellingDrugs.isEmpty) {
                      return const Center(child: Text("No product data available."));
                    }
                    return ListView.builder(
                      itemCount: controller.topSellingDrugs.length,
                      itemBuilder: (context, index) {
                        final product = controller.topSellingDrugs[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(product.name),
                          trailing: Text('${product.totalSold} units', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                        );
                      },
                    );
                  }),
                  // By Revenue
                  Obx(() {
                    if (controller.topRevenueDrugs.isEmpty) {
                      return const Center(child: Text("No product data available."));
                    }
                    return ListView.builder(
                      itemCount: controller.topRevenueDrugs.length,
                      itemBuilder: (context, index) {
                        final product = controller.topRevenueDrugs[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(product.name),
                          trailing: Text(currencyFormatter.format(product.revenue), style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerInsightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PerformanceUIController>();
    final theme = Theme.of(context);

    return _ChartCard(
        title: 'Customer Insights',
        child: Row(
          children: [
            // Pie Chart for New vs Returning
            Expanded(
              flex: 2,
              child: Obx(() {
                final data = controller.newVsReturning.value;
                final pieData = [
                  {'type': 'New', 'count': data.newCustomers},
                  {'type': 'Returning', 'count': data.returningCustomers}
                ];
                if (data.newCustomers == 0 && data.returningCustomers == 0) {
                  return const Center(child: Text("No customer data."));
                }

                return SfCircularChart(
                  title: ChartTitle(text: 'New vs Returning', textStyle: theme.textTheme.labelMedium),
                  legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                  series: <CircularSeries>[
                    PieSeries<Map, String>(
                        dataSource: pieData,
                        xValueMapper: (d, _) => d['type'],
                        yValueMapper: (d, _) => d['count'],
                        dataLabelSettings: const DataLabelSettings(isVisible: true)
                    )
                  ],
                );
              }),
            ),
            // Bar chart for Frequency
            Expanded(
              flex: 3,
              child: Obx(() {
                if (controller.customerFrequency.isEmpty) {
                  return const Center(child: Text("No frequency data."));
                }
                return SfCartesianChart(
                  title: ChartTitle(text: 'Visit Frequency', textStyle: theme.textTheme.labelMedium),
                  primaryXAxis: CategoryAxis(majorGridLines: const MajorGridLines(width: 0)),
                  primaryYAxis: NumericAxis(isVisible: false),
                  series: <CartesianSeries>[
                    BarSeries<CustomerFrequency, String>(
                        dataSource: controller.customerFrequency,
                        xValueMapper: (d, _) => d.visitCount,
                        yValueMapper: (d, _) => d.customerCount,
                        dataLabelSettings: const DataLabelSettings(isVisible: true),
                        name: 'Customers'
                    )
                  ],
                );
              }),
            )
          ],
        )
    );
  }
}

class _DiscountAnalysisCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PerformanceUIController>();
    final theme = Theme.of(context);

    return _ChartCard(
      title: 'Discount Analysis',
      child: Obx(() {
        if (controller.discountUsage.isEmpty) {
          return const Center(child: Text("No discount data available."));
        }
        return SfCartesianChart(
          primaryXAxis: CategoryAxis(majorGridLines: const MajorGridLines(width: 0)),
          primaryYAxis: NumericAxis(
              numberFormat: NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹'),
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0)
          ),
          tooltipBehavior: TooltipBehavior(enable: true, shared: true),
          legend: Legend(isVisible: true, position: LegendPosition.bottom),
          series: <CartesianSeries>[
            ColumnSeries<DiscountUsage, String>(
              dataSource: controller.discountUsage,
              xValueMapper: (d, _) => d.discount,
              yValueMapper: (d, _) => d.nSales,
              name: 'Sales Count',
            ),
            SplineSeries<DiscountUsage, String>(
                dataSource: controller.discountUsage,
                xValueMapper: (d, _) => d.discount,
                yValueMapper: (d, _) => d.revenue,
                name: 'Revenue',
                markerSettings: const MarkerSettings(isVisible: true)
            )
          ],
        );
      }),
    );
  }
}